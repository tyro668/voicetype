import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/transcription.dart';
import '../models/ai_enhance_config.dart';
import '../models/provider_config.dart';
import '../services/audio_recorder.dart';
import '../services/ai_enhance_service.dart';
import '../services/history_db.dart';
import '../services/stt_service.dart';
import '../services/overlay_service.dart';

enum RecordingState { idle, recording, transcribing }

class RecordingProvider extends ChangeNotifier {
  final AudioRecorderService _recorder = AudioRecorderService();
  final HistoryDb _historyDb = HistoryDb.instance;

  RecordingState _state = RecordingState.idle;
  String _transcribedText = '';
  String _error = '';
  DateTime? _recordingStartTime;
  Duration _recordingDuration = Duration.zero;
  Timer? _durationTimer;
  Timer? _healthTimer;
  StreamSubscription<double>? _amplitudeSub;
  double _lastAmplitude = 0.0;
  final List<Transcription> _history = [];

  RecordingProvider() {
    _loadHistory();
  }

  RecordingState get state => _state;
  String get transcribedText => _transcribedText;
  String get error => _error;
  Duration get recordingDuration => _recordingDuration;
  List<Transcription> get history => List.unmodifiable(_history);
  Stream<double> get amplitudeStream => _recorder.amplitudeStream;

  String get _durationStr {
    final m = _recordingDuration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final s = _recordingDuration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> startRecording() async {
    try {
      debugPrint('[recording] startRecording requested');
      _error = '';
      _amplitudeSub?.cancel();
      _amplitudeSub = null;
      if (await _recorder.isRecording()) {
        debugPrint('[recording] recorder still active, resetting');
        await _recorder.reset();
      }
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _error = '需要麦克风权限才能录音';
        debugPrint('[recording] mic permission denied');
        notifyListeners();
        return;
      }

      OverlayService.showOverlay(
        state: 'starting',
        duration: '00:00',
        level: 0.0,
      );

      try {
        debugPrint('[recording] startWithTimeout');
        await _recorder.startWithTimeout(const Duration(seconds: 2));
      } catch (_) {
        debugPrint('[recording] start failed, resetting and retrying');
        await _recorder.reset();
        await _recorder.startWithTimeout(const Duration(seconds: 2));
      }
      _state = RecordingState.recording;
      _recordingStartTime = DateTime.now();
      _recordingDuration = Duration.zero;

      OverlayService.showOverlay(
        state: 'recording',
        duration: '00:00',
        level: 0.0,
      );

      _amplitudeSub = _recorder.amplitudeStream.listen((level) {
        _lastAmplitude = level;
        OverlayService.updateOverlay(
          state: 'recording',
          duration: _durationStr,
          level: level,
        );
      });

      _healthTimer?.cancel();
      _healthTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        final isRec = await _recorder.isRecording();
        final size = await _recorder.currentFileSize();
        debugPrint(
          '[recording] health recording=$isRec fileSize=${size ?? -1} amp=${_lastAmplitude.toStringAsFixed(2)}',
        );
      });

      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _recordingDuration = DateTime.now().difference(_recordingStartTime!);
        notifyListeners();
      });

      debugPrint('[recording] started');
      notifyListeners();
    } catch (e) {
      _error = '录音启动失败: $e';
      debugPrint('[recording] start failed: $e');
      _state = RecordingState.idle;
      OverlayService.hideOverlay();
      notifyListeners();
    }
  }

  Future<void> stopAndTranscribe(
    SttProviderConfig config, {
    bool aiEnhanceEnabled = false,
    AiEnhanceConfig? aiEnhanceConfig,
  }) async {
    try {
      debugPrint('[recording] stop requested');
      _durationTimer?.cancel();
      _durationTimer = null;
      _healthTimer?.cancel();
      _healthTimer = null;
      _amplitudeSub?.cancel();
      _amplitudeSub = null;

      final duration = _recordingDuration;
      // 转写中提示，直到任务完成再关闭 overlay
      OverlayService.showOverlay(state: 'transcribing');
      _state = RecordingState.idle;
      notifyListeners();

      // 后台执行 stop + 转录，避免阻塞快捷键
      unawaited(
        _stopAndTranscribeInBackground(
          config,
          duration,
          aiEnhanceEnabled: aiEnhanceEnabled,
          aiEnhanceConfig: aiEnhanceConfig,
        ),
      );
    } catch (e) {
      _error = '停止录音失败: $e';
      debugPrint('[recording] stop failed: $e');
      _state = RecordingState.idle;
      OverlayService.hideOverlay();
      _amplitudeSub?.cancel();
      _amplitudeSub = null;
      notifyListeners();
    }
  }

  Future<void> _stopAndTranscribeInBackground(
    SttProviderConfig config,
    Duration duration, {
    required bool aiEnhanceEnabled,
    required AiEnhanceConfig? aiEnhanceConfig,
  }) async {
    try {
      debugPrint('[recording] stopInBackground');
      final stopFuture = _recorder.stop();
      stopFuture.then(
        (value) => debugPrint('[recording] stop future completed: $value'),
      );
      final fallbackPath = _recorder.currentPath;

      var path = await stopFuture.timeout(
        const Duration(seconds: 20),
        onTimeout: () => null,
      );

      if (path == null && fallbackPath != null) {
        debugPrint('[recording] stop timeout, poll file');
        path = await _waitForFileReady(
          fallbackPath,
          const Duration(seconds: 20),
        );
      }

      if (path == null) {
        debugPrint('[recording] fallback missing, wait stop completion');
        path = await stopFuture.timeout(
          const Duration(seconds: 10),
          onTimeout: () => null,
        );
      }

      if (path == null) {
        _error = '录音文件获取失败';
        debugPrint('[recording] stop failed, no fallback file');
        await _recorder.reset();
        OverlayService.hideOverlay();
        notifyListeners();
        return;
      }

      debugPrint('[recording] stop ok, transcribing');
      _transcribeInBackground(
        path,
        config,
        duration,
        aiEnhanceEnabled: aiEnhanceEnabled,
        aiEnhanceConfig: aiEnhanceConfig,
      );
    } catch (e) {
      _error = '停止录音失败: $e';
      debugPrint('[recording] stop background failed: $e');
      await _recorder.reset();
      OverlayService.hideOverlay();
      notifyListeners();
    }
  }

  Future<String?> _waitForFileReady(String filePath, Duration timeout) async {
    final maxTicks = timeout.inMilliseconds ~/ 200;
    for (var i = 0; i < maxTicks; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      final file = File(filePath);
      if (await file.exists()) {
        final size = await file.length();
        if (size > 0) {
          return filePath;
        }
      }
    }

    return null;
  }

  /// 后台转录，不影响录音状态
  void _transcribeInBackground(
    String path,
    SttProviderConfig config,
    Duration duration, {
    required bool aiEnhanceEnabled,
    required AiEnhanceConfig? aiEnhanceConfig,
  }) async {
    try {
      debugPrint('[recording] transcribe start: $path');
      final sttService = SttService(config);
      final rawText = await sttService.transcribe(path);
      debugPrint('[recording] transcribe raw length=${rawText.length}');
      var finalText = rawText;

      if (aiEnhanceEnabled && aiEnhanceConfig != null) {
        try {
          OverlayService.showOverlay(state: 'enhancing');
          debugPrint('[recording] ai enhance start');
          final enhancer = AiEnhanceService(aiEnhanceConfig);
          finalText = await enhancer.enhance(rawText);
          debugPrint('[recording] ai enhance length=${finalText.length}');
        } catch (e) {
          debugPrint('[recording] ai enhance failed: $e');
          finalText = rawText;
        }
      }

      _transcribedText = finalText;

      if (finalText.isNotEmpty) {
        final safeConfig = config.copyWith(apiKey: '');
        final item = Transcription(
          id: const Uuid().v4(),
          text: finalText,
          createdAt: DateTime.now(),
          duration: duration,
          provider: config.name,
          model: config.model,
          providerConfigJson: json.encode(safeConfig.toJson()),
        );
        _history.insert(0, item);
        try {
          await _historyDb.insert(item);
          debugPrint('[recording] history saved');
        } catch (e) {
          debugPrint('[recording] history save failed: $e');
        }
        try {
          await OverlayService.insertText(finalText);

          OverlayService.hideOverlay();
          debugPrint('[recording] insert text ok');
        } catch (e) {
          debugPrint('[recording] insert text failed: $e');
        }
        OverlayService.hideOverlay();
      } else {
        _error = '转录结果为空';
        debugPrint('[recording] transcribe empty result');
        await _showTranscribeFailedOverlay();
      }

      notifyListeners();
    } catch (e) {
      _error = '转录失败: $e';
      debugPrint('[recording] transcribe failed: $e');
      await _showTranscribeFailedOverlay();
      notifyListeners();
    }
  }

  Future<void> _showTranscribeFailedOverlay() async {
    try {
      await OverlayService.showOverlay(state: 'transcribe_failed');
      await Future.delayed(const Duration(seconds: 3));
      await OverlayService.hideOverlay();
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    try {
      final items = await _historyDb.getAll();
      _history
        ..clear()
        ..addAll(items);
      notifyListeners();
    } catch (e) {
      debugPrint('[recording] load history failed: $e');
    }
  }

  void clearText() {
    _transcribedText = '';
    notifyListeners();
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }

  void removeHistory(int index) {
    final item = _history.removeAt(index);
    _historyDb.deleteById(item.id);
    notifyListeners();
  }

  void clearAllHistory() {
    _history.clear();
    _historyDb.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _healthTimer?.cancel();
    _amplitudeSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
