import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/app_database.dart';
import '../models/meeting.dart';
import '../models/provider_config.dart';
import '../models/ai_enhance_config.dart';
import '../services/meeting_recording_service.dart';
import '../services/meeting_export_service.dart';
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

  /// 事件流订阅
  StreamSubscription<MeetingSegment>? _segmentReadySub;
  StreamSubscription<MeetingSegment>? _segmentUpdatedSub;
  StreamSubscription<String>? _statusSub;
  StreamSubscription<Duration>? _durationSub;

  /// 音频波形流
  Stream<double> get amplitudeStream => _recordingService.amplitudeStream;

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
      final meeting = await _recordingService.startMeeting(
        title: title,
        sttConfig: sttConfig,
        aiConfig: aiConfig,
        aiEnhanceEnabled: aiEnhanceEnabled,
        segmentSeconds: segmentSeconds,
      );

      await _loadMeetings();
      notifyListeners();
      return meeting;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 暂停录音
  Future<void> pauseMeeting() async {
    try {
      await _recordingService.pause();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// 恢复录音
  Future<void> resumeMeeting() async {
    try {
      await _recordingService.resume();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// 结束录音
  Future<MeetingRecord> stopMeeting() async {
    try {
      final meeting = await _recordingService.stopMeeting();
      await _loadMeetings();
      return meeting;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 取消录音
  Future<void> cancelMeeting() async {
    try {
      await _recordingService.cancelMeeting();
      _currentSegments = [];
      await _loadMeetings();
      notifyListeners();
    } catch (e) {
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
    _recordingService.dispose();
    super.dispose();
  }
}
