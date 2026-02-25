import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/app_database.dart';
import '../models/meeting.dart';
import '../models/provider_config.dart';
import '../models/ai_enhance_config.dart';
import '../services/meeting_recording_service.dart';
import '../services/meeting_export_service.dart';
import '../services/overlay_service.dart';
import '../services/log_service.dart';

/// 会议记录状态管理
class MeetingProvider extends ChangeNotifier {
  final MeetingRecordingService _recordingService = MeetingRecordingService();

  /// 所有会议记录列表
  List<MeetingRecord> _meetings = [];
  List<MeetingRecord> get meetings => List.unmodifiable(_meetings);

  /// 当前录制会议的分段列表
  List<MeetingSegment> _currentSegments = [];
  List<MeetingSegment> get currentSegments => List.unmodifiable(_currentSegments);

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

  /// Overlay 状态标签（国际化）
  String _startingLabel = '准备中';
  String _recordingLabel = '会议录音中';
  String _processingLabel = '处理中';

  /// 振幅监听
  StreamSubscription<double>? _amplitudeSub;

  /// 事件流订阅
  StreamSubscription<MeetingSegment>? _segmentReadySub;
  StreamSubscription<MeetingSegment>? _segmentUpdatedSub;
  StreamSubscription<String>? _statusSub;
  StreamSubscription<Duration>? _durationSub;

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

  /// 加载所有会议记录
  Future<void> _loadMeetings() async {
    try {
      _meetings = await AppDatabase.instance.getAllMeetings();
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
  }) async {
    _error = '';
    _currentSegments = [];

    try {
      // 显示 overlay — starting 状态
      unawaited(OverlayService.showOverlay(
        state: 'starting',
        duration: '00:00',
        level: 0.0,
        stateLabel: _startingLabel,
      ));

      final meeting = await _recordingService.startMeeting(
        title: title,
        sttConfig: sttConfig,
        aiConfig: aiConfig,
        aiEnhanceEnabled: aiEnhanceEnabled,
        segmentSeconds: segmentSeconds,
      );

      // 切换到 recording 状态
      unawaited(OverlayService.showOverlay(
        state: 'recording',
        duration: '00:00',
        level: 0.0,
        stateLabel: _recordingLabel,
      ));

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
      unawaited(OverlayService.showOverlay(
        state: 'recording',
        duration: _durationStr,
        level: 0.0,
        stateLabel: _recordingLabel,
      ));
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
      // 切换到处理中状态
      unawaited(OverlayService.showOverlay(
        state: 'transcribing',
        duration: _durationStr,
        level: 0.0,
        stateLabel: _processingLabel,
      ));

      final meeting = await _recordingService.stopMeeting();

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

  /// 取消录音
  Future<void> cancelMeeting() async {
    try {
      _amplitudeSub?.cancel();
      _amplitudeSub = null;
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

  /// 删除会议
  Future<void> deleteMeeting(String meetingId) async {
    await AppDatabase.instance.deleteMeetingById(meetingId);
    await _loadMeetings();
  }

  /// 导出会议为纯文本
  Future<String> exportAsText(String meetingId) async {
    final meeting = await AppDatabase.instance.getMeetingById(meetingId);
    if (meeting == null) return '';
    final segments = await AppDatabase.instance.getMeetingSegments(meetingId);
    return MeetingExportService.exportAsText(meeting, segments);
  }

  /// 导出会议为 Markdown
  Future<String> exportAsMarkdown(String meetingId) async {
    final meeting = await AppDatabase.instance.getMeetingById(meetingId);
    if (meeting == null) return '';
    final segments = await AppDatabase.instance.getMeetingSegments(meetingId);
    return MeetingExportService.exportAsMarkdown(meeting, segments);
  }

  /// 复制会议全文到剪贴板
  Future<void> copyFullText(String meetingId) async {
    final segments = await AppDatabase.instance.getMeetingSegments(meetingId);
    final text = MeetingExportService.getFullText(segments);
    await MeetingExportService.copyToClipboard(text);
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
    _recordingService.dispose();
    super.dispose();
  }
}
