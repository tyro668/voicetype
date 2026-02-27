import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../database/app_database.dart';
import '../models/meeting.dart';
import '../models/merged_note.dart';
import '../models/provider_config.dart';
import '../models/ai_enhance_config.dart';
import '../services/meeting_recording_service.dart';
import '../services/meeting_export_service.dart';
import '../services/ai_enhance_service.dart';
import '../services/overlay_service.dart';
import '../services/log_service.dart';
import '../services/token_stats_service.dart';
import '../services/pinyin_matcher.dart';

/// 会议记录状态管理
class MeetingProvider extends ChangeNotifier {
  final MeetingRecordingService _recordingService = MeetingRecordingService();

  /// 所有会议记录列表
  List<MeetingRecord> _meetings = [];
  List<MeetingRecord> get meetings => List.unmodifiable(_meetings);

  /// 当前录制会议的分段列表
  List<MeetingSegment> _currentSegments = [];
  List<MeetingSegment> get currentSegments =>
      List.unmodifiable(_currentSegments);

  /// 录制状态
  bool get isRecording => _recordingService.isRecording;
  bool get isPaused => _recordingService.isPaused;
  MeetingRecord? get currentMeeting => _recordingService.currentMeeting;
  Duration get recordingDuration => _recordingService.recordingDuration;

  /// 状态标识
  String _status = 'idle'; // idle, recording, paused, processing, completed
  String get status => _status;
  String _error = '';
  String get error => _error;

  /// 合并纪要状态字段
  String _mergedNote = '';
  String _streamingText = '';
  bool _isStreamingMerge = false;

  /// 流式中返回 _streamingText，否则返回 _mergedNote
  String get mergedNoteContent =>
      _isStreamingMerge ? _streamingText : _mergedNote;

  /// 是否正在流式合并
  bool get isStreamingMerge => _isStreamingMerge;

  /// Overlay 状态标签（国际化）
  String _startingLabel = '准备中';
  String _recordingLabel = '会议录音中';
  String _processingLabel = '处理中';

  /// 振幅监听
  StreamSubscription<double>? _amplitudeSub;

  /// AI 增强配置（会议期间保留，用于结束时合并整理）
  AiEnhanceConfig? _aiConfig;
  bool _aiEnhanceEnabled = false;

  /// 词典提示词后缀（会议期间保留，追加到各专用 prompt 后）
  String _dictionarySuffix = '';

  /// 事件流订阅
  StreamSubscription<MeetingSegment>? _segmentReadySub;
  StreamSubscription<MeetingSegment>? _segmentUpdatedSub;
  StreamSubscription<String>? _statusSub;
  StreamSubscription<Duration>? _durationSub;

  /// 合并器事件流订阅
  StreamSubscription<MergedNote>? _mergeCompletedSub;
  StreamSubscription<MergeStreamEvent>? _streamChunkSub;

  /// 音频波形流
  Stream<double> get amplitudeStream => _recordingService.amplitudeStream;

  /// 设置 Overlay 状态标签（国际化）
  void setOverlayStateLabels({
    required String starting,
    required String recording,
    required String processing,
  }) {
    _startingLabel = starting;
    _recordingLabel = recording;
    _processingLabel = processing;
  }

  String get _durationStr {
    final m = recordingDuration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final s = recordingDuration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$m:$s';
  }

  MeetingProvider() {
    _loadMeetings();
    _setupListeners();
  }

  void _setupListeners() {
    _segmentReadySub = _recordingService.onSegmentReady.listen((segment) {
      _currentSegments.add(segment);
      notifyListeners();
    });

    _segmentUpdatedSub = _recordingService.onSegmentUpdated.listen((segment) {
      final idx = _currentSegments.indexWhere((s) => s.id == segment.id);
      if (idx >= 0) {
        _currentSegments[idx] = segment;
      }
      notifyListeners();
    });

    _statusSub = _recordingService.onStatusChanged.listen((status) {
      _status = status;
      notifyListeners();
    });

    _durationSub = _recordingService.onDurationChanged.listen((_) {
      notifyListeners();
    });
  }

  /// 监听合并器的 onStreamChunk 和 onMergeCompleted 事件流
  void _setupMergerListeners() {
    // 先取消旧的订阅
    _mergeCompletedSub?.cancel();
    _streamChunkSub?.cancel();

    final merger = _recordingService.merger;
    if (merger == null) return;

    _streamChunkSub = merger.onStreamChunk.listen((event) {
      if (!event.isComplete) {
        _streamingText += event.chunk;
        _isStreamingMerge = true;
        notifyListeners();
      } else {
        _isStreamingMerge = false;
        notifyListeners();
      }
    });

    _mergeCompletedSub = merger.onMergeCompleted.listen((note) {
      _mergedNote = note.content;
      _streamingText = '';
      _isStreamingMerge = false;
      notifyListeners();
    });
  }

  /// 取消合并器事件流订阅
  void _cancelMergerListeners() {
    _mergeCompletedSub?.cancel();
    _mergeCompletedSub = null;
    _streamChunkSub?.cancel();
    _streamChunkSub = null;
  }

  /// 加载所有会议记录
  Future<void> _loadMeetings() async {
    try {
      _meetings = await AppDatabase.instance.getAllMeetings();
      // 修复因崩溃/异常导致的残留 recording/paused 状态
      final activeId = _recordingService.currentMeeting?.id;
      for (final m in _meetings) {
        if (m.status != MeetingStatus.completed && m.id != activeId) {
          m.status = MeetingStatus.completed;
          await AppDatabase.instance.updateMeeting(m);
        }
      }
      notifyListeners();
    } catch (e) {
      await LogService.error('MEETING_PROVIDER', 'load meetings failed: $e');
    }
  }

  /// 刷新会议列表
  Future<void> refreshMeetings() async {
    await _loadMeetings();
  }

  /// 开始新会议
  Future<MeetingRecord> startMeeting({
    String? title,
    required SttProviderConfig sttConfig,
    AiEnhanceConfig? aiConfig,
    bool aiEnhanceEnabled = false,
    int segmentSeconds = 30,
    int windowSize = 5,
    String dictionarySuffix = '',
    PinyinMatcher? pinyinMatcher,
    String? correctionPrompt,
  }) async {
    _error = '';
    _currentSegments = [];
    _aiConfig = aiConfig;
    _aiEnhanceEnabled = aiEnhanceEnabled;
    _dictionarySuffix = dictionarySuffix;

    // 重置合并纪要状态
    _mergedNote = '';
    _streamingText = '';
    _isStreamingMerge = false;

    try {
      // 显示 overlay — starting 状态
      unawaited(
        OverlayService.showOverlay(
          state: 'starting',
          duration: '00:00',
          level: 0.0,
          stateLabel: _startingLabel,
        ),
      );

      final meeting = await _recordingService.startMeeting(
        title: title,
        sttConfig: sttConfig,
        aiConfig: aiConfig,
        aiEnhanceEnabled: aiEnhanceEnabled,
        segmentSeconds: segmentSeconds,
        windowSize: windowSize,
        pinyinMatcher: pinyinMatcher,
        correctionPrompt: correctionPrompt,
      );

      // 监听合并器事件流
      _setupMergerListeners();

      // 切换到 recording 状态
      unawaited(
        OverlayService.showOverlay(
          state: 'recording',
          duration: '00:00',
          level: 0.0,
          stateLabel: _recordingLabel,
        ),
      );

      // 监听音频振幅，实时更新 overlay
      _amplitudeSub?.cancel();
      _amplitudeSub = _recordingService.amplitudeStream.listen((level) {
        OverlayService.updateOverlay(
          state: 'recording',
          duration: _durationStr,
          level: level,
          stateLabel: _recordingLabel,
        );
      });

      await _loadMeetings();
      notifyListeners();
      return meeting;
    } catch (e) {
      unawaited(OverlayService.hideOverlay());
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 暂停录音
  Future<void> pauseMeeting() async {
    try {
      await _recordingService.pause();
      _amplitudeSub?.cancel();
      _amplitudeSub = null;
      // 暂停时隐藏 overlay
      unawaited(OverlayService.hideOverlay());
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// 恢复录音
  Future<void> resumeMeeting() async {
    try {
      await _recordingService.resume();
      // 恢复时重新显示 overlay
      unawaited(
        OverlayService.showOverlay(
          state: 'recording',
          duration: _durationStr,
          level: 0.0,
          stateLabel: _recordingLabel,
        ),
      );
      // 重新监听振幅
      _amplitudeSub?.cancel();
      _amplitudeSub = _recordingService.amplitudeStream.listen((level) {
        OverlayService.updateOverlay(
          state: 'recording',
          duration: _durationStr,
          level: level,
          stateLabel: _recordingLabel,
        );
      });
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// 结束录音
  Future<MeetingRecord> stopMeeting() async {
    try {
      _amplitudeSub?.cancel();
      _amplitudeSub = null;
      _cancelMergerListeners();
      // 切换到处理中状态
      unawaited(
        OverlayService.showOverlay(
          state: 'transcribing',
          duration: _durationStr,
          level: 0.0,
          stateLabel: _processingLabel,
        ),
      );

      final meeting = await _recordingService.stopMeeting();

      // 合并所有分段文字为完整文稿
      final segments = await AppDatabase.instance.getMeetingSegments(
        meeting.id,
      );
      segments.sort((a, b) => a.segmentIndex.compareTo(b.segmentIndex));

      final buffer = StringBuffer();
      for (final seg in segments) {
        final text = (seg.enhancedText ?? seg.transcription ?? '').trim();
        if (text.isNotEmpty) {
          buffer.writeln(text);
        }
      }

      final mergedText = buffer.toString().trim();
      if (mergedText.isNotEmpty) {
        // 使用大模型对合并文本进行整理
        final polished = await _polishMergedText(mergedText);
        meeting.fullTranscription = polished;

        // 自动生成会议总结
        final summary = await _generateSummary(polished);
        if (summary.isNotEmpty) {
          meeting.summary = summary;
        }

        // 如果标题仍是默认标题，则根据内容自动生成
        if (_isDefaultTitle(meeting.title)) {
          final autoTitle = await _generateTitle(polished);
          if (autoTitle.isNotEmpty) {
            meeting.title = autoTitle;
          }
        }

        await AppDatabase.instance.updateMeeting(meeting);
      }

      // 处理完成，隐藏 overlay
      unawaited(OverlayService.hideOverlay());
      await _loadMeetings();
      return meeting;
    } catch (e) {
      unawaited(OverlayService.hideOverlay());
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 使用大模型整理合并后的会议文稿
  Future<String> _polishMergedText(String rawText) async {
    if (!_aiEnhanceEnabled || _aiConfig == null) {
      return rawText;
    }

    try {
      await LogService.info(
        'MEETING',
        'polishing merged text with LLM, length=${rawText.length}',
      );

      // 加载会议合并专用提示词
      final mergePrompt = await rootBundle.loadString(
        'assets/prompts/meeting_merge_prompt.md',
      );

      // 使用会议合并提示词覆盖默认提示词，并追加词典后缀
      final mergeConfig = _aiConfig!.copyWith(
        prompt: mergePrompt + _dictionarySuffix,
      );
      final enhancer = AiEnhanceService(mergeConfig);
      final result = await enhancer.enhance(
        rawText,
        timeout: const Duration(seconds: 120),
      );

      // 记录 token 用量
      if (result.promptTokens > 0 || result.completionTokens > 0) {
        await TokenStatsService.instance.addMeetingTokens(
          promptTokens: result.promptTokens,
          completionTokens: result.completionTokens,
        );
      }

      await LogService.info(
        'MEETING',
        'polish complete, result length=${result.text.length}',
      );

      // 如果 LLM 返回了有效内容则使用，否则回退到原始合并文本
      return result.text.trim().isNotEmpty ? result.text.trim() : rawText;
    } catch (e) {
      await LogService.error('MEETING', 'polish merged text failed: $e');
      // 整理失败不影响基本功能，回退到原始合并文本
      return rawText;
    }
  }

  /// 使用大模型生成会议总结
  Future<String> _generateSummary(String content) async {
    if (!_aiEnhanceEnabled || _aiConfig == null) return '';

    try {
      await LogService.info(
        'MEETING',
        'generating summary from content, length=${content.length}',
      );

      // 加载会议总结专用提示词
      final summaryPrompt = await rootBundle.loadString(
        'assets/prompts/meeting_summary_prompt.md',
      );

      final summaryConfig = _aiConfig!.copyWith(
        prompt: summaryPrompt + _dictionarySuffix,
      );
      final enhancer = AiEnhanceService(summaryConfig);
      final result = await enhancer.enhance(
        content,
        timeout: const Duration(seconds: 120),
      );

      // 记录 token 用量
      if (result.promptTokens > 0 || result.completionTokens > 0) {
        await TokenStatsService.instance.addMeetingTokens(
          promptTokens: result.promptTokens,
          completionTokens: result.completionTokens,
        );
      }

      await LogService.info(
        'MEETING',
        'summary generated, length=${result.text.length}',
      );
      return result.text.trim();
    } catch (e) {
      await LogService.error('MEETING', 'generate summary failed: $e');
      return '';
    }
  }

  /// 重新生成会议总结（供外部调用）
  Future<void> regenerateSummary(String meetingId) async {
    await regenerateSummaryByContent(meetingId);
  }

  /// 基于指定会议纪要内容重新生成会议总结。
  ///
  /// 当 [content] 为空时，将回退到数据库中该会议的 fullTranscription。
  /// 返回值表示是否成功生成并更新了总结。
  Future<bool> regenerateSummaryByContent(
    String meetingId, {
    String? content,
    AiEnhanceConfig? aiConfig,
    String dictionarySuffix = '',
  }) async {
    final meeting = await AppDatabase.instance.getMeetingById(meetingId);
    if (meeting == null) return false;

    final mergedContent = (content ?? meeting.fullTranscription ?? '').trim();
    if (mergedContent.isEmpty) return false;

    // 优先使用显式传入的 AI 配置，避免依赖会话态配置
    final config = aiConfig ?? _aiConfig;
    if (config == null) return false;

    final oldEnabled = _aiEnhanceEnabled;
    final oldConfig = _aiConfig;
    final oldDictSuffix = _dictionarySuffix;
    try {
      _aiEnhanceEnabled = true;
      _aiConfig = config;
      _dictionarySuffix = dictionarySuffix;

      final summary = await _generateSummary(mergedContent);
      if (summary.isEmpty) return false;

      meeting.summary = summary;
      meeting.fullTranscription = mergedContent;
      meeting.updatedAt = DateTime.now();
      await AppDatabase.instance.updateMeeting(meeting);
      await _loadMeetings();
      return true;
    } finally {
      _aiEnhanceEnabled = oldEnabled;
      _aiConfig = oldConfig;
      _dictionarySuffix = oldDictSuffix;
    }
  }

  /// 流式重新生成会议总结，逐块返回文本
  Stream<String> regenerateSummaryStream(
    String meetingId, {
    required AiEnhanceConfig aiConfig,
    String dictionarySuffix = '',
  }) async* {
    final meeting = await AppDatabase.instance.getMeetingById(meetingId);
    if (meeting == null) return;

    final content = (meeting.fullTranscription ?? '').trim();
    if (content.isEmpty) return;

    await LogService.info(
      'MEETING',
      'streaming summary regeneration, content length=${content.length}',
    );

    final summaryPrompt = await rootBundle.loadString(
      'assets/prompts/meeting_summary_prompt.md',
    );

    final summaryConfig = aiConfig.copyWith(
      prompt: summaryPrompt + dictionarySuffix,
    );
    final enhancer = AiEnhanceService(summaryConfig);

    final buffer = StringBuffer();
    await for (final chunk in enhancer.enhanceStream(
      content,
      timeout: const Duration(seconds: 120),
    )) {
      buffer.write(chunk);
      yield chunk;
    }

    // 流式结束后持久化
    final fullSummary = buffer.toString().trim();
    if (fullSummary.isNotEmpty) {
      meeting.summary = fullSummary;
      meeting.updatedAt = DateTime.now();
      await AppDatabase.instance.updateMeeting(meeting);
      await _loadMeetings();
    }

    await LogService.info(
      'MEETING',
      'streaming summary complete, length=${fullSummary.length}',
    );
  }

  /// 判断标题是否为系统默认生成的标题（格式：会议 M/D HH:mm）
  bool _isDefaultTitle(String title) {
    return RegExp(r'^会议 \d{1,2}/\d{1,2} \d{1,2}:\d{2}$').hasMatch(title.trim());
  }

  /// 使用大模型根据会议内容生成简短标题
  Future<String> _generateTitle(String content) async {
    if (!_aiEnhanceEnabled || _aiConfig == null) return '';

    try {
      await LogService.info('MEETING', 'generating title from content');

      const titlePrompt =
          '你是一个会议标题生成助手。根据用户提供的会议内容，生成一个简洁的会议标题。\n\n'
          '## 规则\n'
          '- 标题应概括会议的核心主题，不超过20个字\n'
          '- 只输出标题本身，不要添加引号、书名号、前后缀或任何解释\n'
          '- 使用与内容相同的语言';

      final titleConfig = _aiConfig!.copyWith(prompt: titlePrompt);
      final enhancer = AiEnhanceService(titleConfig);

      // 只取前1500字作为上下文，避免 token 浪费
      final snippet = content.length > 1500
          ? content.substring(0, 1500)
          : content;
      final result = await enhancer.enhance(
        snippet,
        timeout: const Duration(seconds: 15),
      );

      final title = result.text
          .trim()
          .replaceAll(RegExp(r'^["""「」『』《》【】]+'), '')
          .replaceAll(RegExp(r'["""「」『』《》【】]+$'), '')
          .trim();

      if (result.promptTokens > 0 || result.completionTokens > 0) {
        await TokenStatsService.instance.addMeetingTokens(
          promptTokens: result.promptTokens,
          completionTokens: result.completionTokens,
        );
      }

      await LogService.info('MEETING', 'generated title: $title');
      return title.length > 50 ? title.substring(0, 50) : title;
    } catch (e) {
      await LogService.error('MEETING', 'generate title failed: $e');
      return '';
    }
  }

  /// 取消录音
  Future<void> cancelMeeting() async {
    try {
      _amplitudeSub?.cancel();
      _amplitudeSub = null;
      _cancelMergerListeners();
      await _recordingService.cancelMeeting();
      unawaited(OverlayService.hideOverlay());
      _currentSegments = [];
      await _loadMeetings();
      notifyListeners();
    } catch (e) {
      unawaited(OverlayService.hideOverlay());
      _error = e.toString();
      notifyListeners();
    }
  }

  /// 获取指定会议的分段列表
  Future<List<MeetingSegment>> getSegments(String meetingId) async {
    return await AppDatabase.instance.getMeetingSegments(meetingId);
  }

  /// 更新会议标题
  Future<void> updateMeetingTitle(String meetingId, String title) async {
    final meeting = await AppDatabase.instance.getMeetingById(meetingId);
    if (meeting == null) return;

    meeting.title = title;
    meeting.updatedAt = DateTime.now();
    await AppDatabase.instance.updateMeeting(meeting);
    await _loadMeetings();
  }

  /// 更新会议摘要
  Future<void> updateMeetingSummary(String meetingId, String summary) async {
    final meeting = await AppDatabase.instance.getMeetingById(meetingId);
    if (meeting == null) return;

    meeting.summary = summary;
    meeting.updatedAt = DateTime.now();
    await AppDatabase.instance.updateMeeting(meeting);
    await _loadMeetings();
  }

  /// 更新会议完整文稿
  Future<void> updateMeetingFullTranscription(
    String meetingId,
    String text,
  ) async {
    final meeting = await AppDatabase.instance.getMeetingById(meetingId);
    if (meeting == null) return;

    meeting.fullTranscription = text;
    meeting.updatedAt = DateTime.now();
    await AppDatabase.instance.updateMeeting(meeting);
    await _loadMeetings();
  }

  /// 删除会议
  Future<void> deleteMeeting(String meetingId) async {
    await AppDatabase.instance.deleteMeetingById(meetingId);
    await _loadMeetings();
  }

  /// 导出会议为纯文本
  Future<String> exportAsText(String meetingId) async {
    final meeting = await AppDatabase.instance.getMeetingById(meetingId);
    if (meeting == null) return '';
    return MeetingExportService.exportAsText(meeting);
  }

  /// 导出会议为 Markdown
  Future<String> exportAsMarkdown(String meetingId) async {
    final meeting = await AppDatabase.instance.getMeetingById(meetingId);
    if (meeting == null) return '';
    return MeetingExportService.exportAsMarkdown(meeting);
  }

  /// 复制会议全文到剪贴板
  Future<void> copyFullText(String meetingId) async {
    final meeting = await AppDatabase.instance.getMeetingById(meetingId);
    if (meeting == null) return;
    await MeetingExportService.copyToClipboard(meeting.fullTranscription ?? '');
  }

  /// 重试失败的分段
  Future<void> retrySegment(MeetingSegment segment) async {
    await _recordingService.retrySegment(segment);
  }

  /// 更新分段文本（手动编辑）
  Future<void> updateSegmentText(String segmentId, String newText) async {
    final db = AppDatabase.instance;
    // We need to find and update the segment
    // Since we have the segment in _currentSegments or can get from DB
    for (var i = 0; i < _currentSegments.length; i++) {
      if (_currentSegments[i].id == segmentId) {
        _currentSegments[i].enhancedText = newText;
        await db.updateMeetingSegment(_currentSegments[i]);
        notifyListeners();
        return;
      }
    }
  }

  @override
  void dispose() {
    _segmentReadySub?.cancel();
    _segmentUpdatedSub?.cancel();
    _statusSub?.cancel();
    _durationSub?.cancel();
    _amplitudeSub?.cancel();
    _cancelMergerListeners();
    _recordingService.dispose();
    super.dispose();
  }
}
