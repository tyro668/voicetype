import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/meeting.dart';
import '../models/merged_note.dart';
import '../models/provider_config.dart';
import '../models/ai_enhance_config.dart';
import 'audio_recorder.dart';
import 'stt_service.dart';
import 'ai_enhance_service.dart';
import 'log_service.dart';
import 'sliding_window_merger.dart';
import 'token_stats_service.dart';
import 'correction_service.dart';
import 'correction_context.dart';
import 'pinyin_matcher.dart';

/// 会议录音服务 — 管理分段录音与自动转文字流水线
class MeetingRecordingService {
  static const _uuid = Uuid();

  final AudioRecorderService _recorder = AudioRecorderService();

  /// 分段时长（秒），默认 30 秒
  int segmentDurationSeconds = 30;

  /// 当前会议记录
  MeetingRecord? _currentMeeting;

  /// 当前分段索引
  int _segmentIndex = 0;

  /// 录音状态
  bool _isRecording = false;
  bool _isPaused = false;
  bool _segmentSwitching = false;
  bool _stopping = false;

  /// 计时器
  Timer? _segmentTimer;
  Timer? _durationTimer;
  DateTime? _recordingStartTime;
  Duration _recordingDuration = Duration.zero;
  Duration _pausedDuration = Duration.zero;
  DateTime? _pauseStartTime;

  /// 事件流
  final StreamController<MeetingSegment> _onSegmentReady =
      StreamController<MeetingSegment>.broadcast();
  final StreamController<MeetingSegment> _onSegmentUpdated =
      StreamController<MeetingSegment>.broadcast();
  final StreamController<String> _onStatusChanged =
      StreamController<String>.broadcast();
  final StreamController<Duration> _onDurationChanged =
      StreamController<Duration>.broadcast();

  Stream<MeetingSegment> get onSegmentReady => _onSegmentReady.stream;
  Stream<MeetingSegment> get onSegmentUpdated => _onSegmentUpdated.stream;
  Stream<String> get onStatusChanged => _onStatusChanged.stream;
  Stream<Duration> get onDurationChanged => _onDurationChanged.stream;
  Stream<double> get amplitudeStream => _recorder.amplitudeStream;

  /// 当前会议
  MeetingRecord? get currentMeeting => _currentMeeting;
  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  Duration get recordingDuration => _recordingDuration;

  /// 待处理分段队列
  final List<_PendingSegment> _processingQueue = [];
  bool _processingWorkerRunning = false;

  /// STT 和 AI 增强配置（由外部传入）
  SttProviderConfig? _sttConfig;
  AiEnhanceConfig? _aiConfig;
  bool _aiEnhanceEnabled = false;

  /// 滑动窗口合并器
  SlidingWindowMerger? _merger;

  /// 暴露合并器实例，供 MeetingProvider 监听其事件流
  SlidingWindowMerger? get merger => _merger;

  /// 纠错服务
  CorrectionService? _correctionService;
  final CorrectionContext _correctionContext = CorrectionContext();

  /// 开始新的会议录音
  Future<MeetingRecord> startMeeting({
    String? title,
    required SttProviderConfig sttConfig,
    AiEnhanceConfig? aiConfig,
    bool aiEnhanceEnabled = false,
    int? segmentSeconds,
    int windowSize = 5,
    PinyinMatcher? pinyinMatcher,
    String? correctionPrompt,
  }) async {
    if (_isRecording) {
      throw MeetingRecordingException('已有会议正在录制中');
    }

    _sttConfig = sttConfig;
    _aiConfig = aiConfig;
    _aiEnhanceEnabled = aiEnhanceEnabled;
    if (segmentSeconds != null) segmentDurationSeconds = segmentSeconds;

    // 初始化纠错服务
    _correctionContext.reset();
    if (pinyinMatcher != null &&
        aiConfig != null &&
        correctionPrompt != null &&
        correctionPrompt.isNotEmpty) {
      _correctionService = CorrectionService(
        matcher: pinyinMatcher,
        context: _correctionContext,
        aiConfig: aiConfig,
        correctionPrompt: correctionPrompt,
      );
    } else {
      _correctionService = null;
    }

    // 创建滑动窗口合并器（需要 AI 配置）
    if (_aiConfig != null) {
      final clampedWindowSize = clampWindowSize(windowSize);
      _merger = SlidingWindowMerger(
        windowSize: clampedWindowSize,
        aiConfig: _aiConfig!,
      );
    }

    final now = DateTime.now();
    final meeting = MeetingRecord(
      id: _uuid.v4(),
      title:
          title ??
          '会议 ${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      createdAt: now,
      updatedAt: now,
      status: MeetingStatus.recording,
    );

    // 持久化
    final db = AppDatabase.instance;
    await db.insertMeeting(meeting);

    _currentMeeting = meeting;
    _segmentIndex = 0;
    _recordingDuration = Duration.zero;
    _pausedDuration = Duration.zero;
    _stopping = false;

    await LogService.info('MEETING', 'starting meeting: ${meeting.id}');

    // 开始第一段录音（如果失败则清理数据库中的会议记录）
    try {
      await _startSegmentRecording();
    } catch (e) {
      // 录音启动失败，清理已写入的会议记录
      await db.deleteMeetingById(meeting.id);
      _currentMeeting = null;
      await LogService.error(
        'MEETING',
        'start recording failed, cleaned up: $e',
      );
      rethrow;
    }

    // 启动计时器
    _recordingStartTime = now;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) {
        _recordingDuration =
            DateTime.now().difference(_recordingStartTime!) - _pausedDuration;
        _onDurationChanged.add(_recordingDuration);
      }
    });

    // 启动分段计时器
    _segmentTimer = Timer.periodic(
      Duration(seconds: segmentDurationSeconds),
      (_) => _handleSegmentTick(),
    );

    _isRecording = true;
    _isPaused = false;
    _onStatusChanged.add('recording');

    return meeting;
  }

  /// 暂停会议录音
  Future<void> pause() async {
    if (!_isRecording || _isPaused) return;

    _isPaused = true;
    _pauseStartTime = DateTime.now();
    _segmentTimer?.cancel();
    _segmentTimer = null;

    // 停止当前录音段并保存
    await _finalizeCurrentSegment();

    _merger?.pause();

    _onStatusChanged.add('paused');
    await LogService.info('MEETING', 'meeting paused');
  }

  /// 恢复会议录音
  Future<void> resume() async {
    if (!_isRecording || !_isPaused) return;

    if (_pauseStartTime != null) {
      _pausedDuration += DateTime.now().difference(_pauseStartTime!);
      _pauseStartTime = null;
    }

    _isPaused = false;

    _merger?.resume();

    // 开始新的录音段
    await _startSegmentRecording();

    // 重新启动分段计时器
    _segmentTimer = Timer.periodic(
      Duration(seconds: segmentDurationSeconds),
      (_) => _handleSegmentTick(),
    );

    _onStatusChanged.add('recording');
    await LogService.info('MEETING', 'meeting resumed');
  }

  /// 结束会议录音
  Future<MeetingRecord> stopMeeting() async {
    if (!_isRecording || _currentMeeting == null) {
      throw MeetingRecordingException('没有正在录制的会议');
    }

    _stopping = true;
    _segmentTimer?.cancel();
    _segmentTimer = null;
    _durationTimer?.cancel();
    _durationTimer = null;

    // 停止当前录音段
    if (!_isPaused) {
      await _finalizeCurrentSegment();
    }

    // 等待所有分段处理完成
    _onStatusChanged.add('processing');
    await _waitForProcessingComplete();

    // 等待当前合并任务完成
    if (_merger != null) {
      await _waitForMergerComplete();
    }

    // 更新会议状态
    final meeting = _currentMeeting!;
    meeting.status = MeetingStatus.completed;
    meeting.updatedAt = DateTime.now();
    meeting.totalDuration = _recordingDuration;
    await AppDatabase.instance.updateMeeting(meeting);

    _isRecording = false;
    _isPaused = false;
    _onStatusChanged.add('completed');

    await LogService.info(
      'MEETING',
      'meeting completed: ${meeting.id}, duration: ${meeting.formattedDuration}',
    );

    final result = meeting;
    _currentMeeting = null;
    return result;
  }

  /// 取消并丢弃当前会议
  Future<void> cancelMeeting() async {
    if (!_isRecording && _currentMeeting == null) return;

    _stopping = true;
    _segmentTimer?.cancel();
    _segmentTimer = null;
    _durationTimer?.cancel();
    _durationTimer = null;

    try {
      await _recorder.stop();
    } catch (_) {}

    if (_currentMeeting != null) {
      await AppDatabase.instance.deleteMeetingById(_currentMeeting!.id);
    }

    _isRecording = false;
    _isPaused = false;
    _currentMeeting = null;
    _processingQueue.clear();
    _onStatusChanged.add('cancelled');

    await LogService.info('MEETING', 'meeting cancelled');
  }

  /// 开始一个新的录音分段
  Future<void> _startSegmentRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw MeetingRecordingException('需要麦克风权限');
    }

    try {
      await _recorder.start();
      await LogService.info(
        'MEETING',
        'segment ${_segmentIndex + 1} recording started',
      );
    } catch (e) {
      // 重试一次
      try {
        await _recorder.reset();
        await _recorder.start();
      } catch (e2) {
        throw MeetingRecordingException('录音启动失败: $e2');
      }
    }
  }

  /// 处理分段计时器到期
  Future<void> _handleSegmentTick() async {
    if (!_isRecording || _isPaused || _stopping) return;
    if (_segmentSwitching) return;

    _segmentSwitching = true;
    try {
      await _finalizeCurrentSegment();
      await _startSegmentRecording();
    } catch (e) {
      await LogService.error('MEETING', 'segment rotation failed: $e');
    } finally {
      _segmentSwitching = false;
    }
  }

  /// 结束当前录音分段并提交处理队列
  Future<void> _finalizeCurrentSegment() async {
    final audioPath = await _recorder.stop();
    if (audioPath == null) return;

    // 检查文件是否存在且大小合理
    final file = File(audioPath);
    if (!await file.exists()) return;
    final fileSize = await file.length();
    if (fileSize < 1000) {
      // 文件太小，可能是空录音
      await LogService.info(
        'MEETING',
        'segment audio too small ($fileSize bytes), skipping',
      );
      return;
    }

    final now = DateTime.now();
    final segment = MeetingSegment(
      id: _uuid.v4(),
      meetingId: _currentMeeting!.id,
      segmentIndex: _segmentIndex,
      startTime: now.subtract(Duration(seconds: segmentDurationSeconds)),
      duration: Duration(seconds: segmentDurationSeconds),
      audioFilePath: audioPath,
      status: SegmentStatus.pending,
    );

    _segmentIndex++;

    // 持久化
    await AppDatabase.instance.insertMeetingSegment(segment);

    // 通知 UI 新分段已就绪（状态 pending）
    _onSegmentReady.add(segment);

    // 加入处理队列
    _processingQueue.add(
      _PendingSegment(segment: segment, audioPath: audioPath),
    );
    _startProcessingWorker();

    await LogService.info(
      'MEETING',
      'segment ${segment.segmentIndex} finalized: $audioPath ($fileSize bytes)',
    );
  }

  /// 启动处理工作线程（如果尚未运行）
  void _startProcessingWorker() {
    if (_processingWorkerRunning) return;
    _processingWorkerRunning = true;
    _runProcessingWorker();
  }

  /// 处理队列中的分段
  Future<void> _runProcessingWorker() async {
    while (_processingQueue.isNotEmpty) {
      final pending = _processingQueue.removeAt(0);
      await _processSegment(pending);
    }
    _processingWorkerRunning = false;
  }

  /// 对一个分段执行 STT + AI 增强
  Future<void> _processSegment(_PendingSegment pending) async {
    final segment = pending.segment;
    final db = AppDatabase.instance;

    try {
      // 1. 语音转文字
      segment.status = SegmentStatus.transcribing;
      await db.updateMeetingSegment(segment);
      _onSegmentUpdated.add(segment);

      if (_sttConfig == null) {
        throw MeetingRecordingException('未配置语音转文字服务');
      }

      final sttService = SttService(_sttConfig!);
      final rawText = await sttService.transcribe(pending.audioPath);

      if (rawText.trim().isEmpty) {
        segment.status = SegmentStatus.done;
        segment.transcription = '';
        await db.updateMeetingSegment(segment);
        _onSegmentUpdated.add(segment);
        return;
      }

      segment.transcription = rawText;

      // 1.5 纠错：拼音匹配 + LLM 同音字纠正
      if (_correctionService != null) {
        try {
          final corrResult = await _correctionService!.correct(rawText);
          if (corrResult.text.trim().isNotEmpty) {
            segment.transcription = corrResult.text;
          }
        } catch (e) {
          await LogService.error(
            'MEETING',
            'correction failed for segment ${segment.segmentIndex}: $e',
          );
          // 纠错失败不影响主流程
        }
      }

      // 2. AI 文字增强（如果启用）
      if (_aiEnhanceEnabled && _aiConfig != null) {
        segment.status = SegmentStatus.enhancing;
        await db.updateMeetingSegment(segment);
        _onSegmentUpdated.add(segment);

        try {
          final enhancer = AiEnhanceService(_aiConfig!);
          final result = await enhancer.enhance(rawText);
          segment.enhancedText = result.text;

          // 记录会议 AI 增强 token 用量
          if (result.promptTokens > 0 || result.completionTokens > 0) {
            await TokenStatsService.instance.addMeetingTokens(
              promptTokens: result.promptTokens,
              completionTokens: result.completionTokens,
            );
          }
        } catch (e) {
          await LogService.error(
            'MEETING',
            'AI enhance failed for segment ${segment.segmentIndex}: $e',
          );
          // 增强失败不影响转写结果
        }
      }

      segment.status = SegmentStatus.done;
      await db.updateMeetingSegment(segment);
      _onSegmentUpdated.add(segment);

      // 分段 STT 完成且转写非空时，通知合并器触发窗口合并
      if (segment.transcription != null &&
          segment.transcription!.trim().isNotEmpty) {
        _notifyMerger();
      }

      await LogService.info(
        'MEETING',
        'segment ${segment.segmentIndex} processed: ${rawText.length} chars',
      );
    } catch (e) {
      segment.status = SegmentStatus.error;
      segment.errorMessage = e.toString();
      await db.updateMeetingSegment(segment);
      _onSegmentUpdated.add(segment);
      await LogService.error(
        'MEETING',
        'segment ${segment.segmentIndex} processing failed: $e',
      );
    }
  }

  /// 等待所有分段处理完成
  Future<void> _waitForProcessingComplete() async {
    while (_processingWorkerRunning || _processingQueue.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  /// 重新处理失败的分段
  Future<void> retrySegment(MeetingSegment segment) async {
    if (segment.audioFilePath == null) return;
    final file = File(segment.audioFilePath!);
    if (!await file.exists()) return;

    segment.status = SegmentStatus.pending;
    segment.errorMessage = null;
    await AppDatabase.instance.updateMeetingSegment(segment);
    _onSegmentUpdated.add(segment);

    _processingQueue.add(
      _PendingSegment(segment: segment, audioPath: segment.audioFilePath!),
    );
    _startProcessingWorker();
  }

  /// 通知合并器有新分段完成，传入当前会议的所有分段
  void _notifyMerger() {
    if (_merger == null || _currentMeeting == null) return;

    // 从数据库异步获取所有分段并通知合并器
    AppDatabase.instance
        .getMeetingSegments(_currentMeeting!.id)
        .then((segments) {
          _merger?.onSegmentCompleted(segments);
        })
        .catchError((e) {
          LogService.error(
            'MEETING',
            'failed to fetch segments for merger: $e',
          );
        });
  }

  /// 等待合并器当前任务完成
  Future<void> _waitForMergerComplete() async {
    if (_merger == null) return;
    // 轮询等待合并器完成当前任务
    while (_merger!.isMerging) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  void dispose() {
    _segmentTimer?.cancel();
    _durationTimer?.cancel();
    _merger?.dispose();
    _merger = null;
    _onSegmentReady.close();
    _onSegmentUpdated.close();
    _onStatusChanged.close();
    _onDurationChanged.close();
    _recorder.dispose();
  }
}

/// 待处理分段
class _PendingSegment {
  final MeetingSegment segment;
  final String audioPath;

  _PendingSegment({required this.segment, required this.audioPath});
}

class MeetingRecordingException implements Exception {
  final String message;
  MeetingRecordingException(this.message);

  @override
  String toString() => message;
}
