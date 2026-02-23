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
import '../services/log_service.dart';

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
      _error = '';
      _amplitudeSub?.cancel();
      _amplitudeSub = null;
      if (await _recorder.isRecording()) {
        await _recorder.reset();
      }
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _error = '需要麦克风权限才能录音';
        notifyListeners();
        return;
      }

      OverlayService.showOverlay(
        state: 'starting',
        duration: '00:00',
        level: 0.0,
      );

      try {
        await _recorder.startWithTimeout(const Duration(seconds: 2));
      } catch (_) {
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
        OverlayService.updateOverlay(
          state: 'recording',
          duration: _durationStr,
          level: level,
        );
      });

      _healthTimer?.cancel();
      _healthTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        await _recorder.isRecording();
        await _recorder.currentFileSize();
      });

      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _recordingDuration = DateTime.now().difference(_recordingStartTime!);
        notifyListeners();
      });

      notifyListeners();
    } catch (e) {
      _error = '录音启动失败: $e';
      _state = RecordingState.idle;
      OverlayService.hideOverlay();
      notifyListeners();
    }
  }

  Future<void> stopAndTranscribe(
    SttProviderConfig config, {
    bool aiEnhanceEnabled = false,
    AiEnhanceConfig? aiEnhanceConfig,
    int minRecordingSeconds = 3,
  }) async {
    try {
      _durationTimer?.cancel();
      _durationTimer = null;
      _healthTimer?.cancel();
      _healthTimer = null;
      _amplitudeSub?.cancel();
      _amplitudeSub = null;

      final duration = _recordingDuration;

      // 录音时长不足，忽略本次输入
      if (duration.inSeconds < minRecordingSeconds) {
        _state = RecordingState.idle;
        OverlayService.hideOverlay();
        _recorder.stop().then((_) => _recorder.reset());
        notifyListeners();
        return;
      }

      OverlayService.showOverlay(state: 'transcribing');
      _state = RecordingState.idle;
      notifyListeners();

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
      final stopFuture = _recorder.stop();
      final fallbackPath = _recorder.currentPath;

      var path = await stopFuture.timeout(
        const Duration(seconds: 20),
        onTimeout: () => null,
      );

      if (path == null && fallbackPath != null) {
        path = await _waitForFileReady(
          fallbackPath,
          const Duration(seconds: 20),
        );
      }

      if (path == null) {
        path = await stopFuture.timeout(
          const Duration(seconds: 10),
          onTimeout: () => null,
        );
      }

      if (path == null) {
        _error = '录音文件获取失败';
        await _recorder.reset();
        OverlayService.hideOverlay();
        notifyListeners();
        return;
      }

      _transcribeInBackground(
        path,
        config,
        duration,
        aiEnhanceEnabled: aiEnhanceEnabled,
        aiEnhanceConfig: aiEnhanceConfig,
      );
    } catch (e) {
      _error = '停止录音失败: $e';
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

  void _transcribeInBackground(
    String path,
    SttProviderConfig config,
    Duration duration, {
    required bool aiEnhanceEnabled,
    required AiEnhanceConfig? aiEnhanceConfig,
  }) async {
    try {
      final sttService = SttService(config);
      final rawText = await sttService.transcribe(path);
      var finalText = rawText;

      if (aiEnhanceEnabled && aiEnhanceConfig != null) {
        try {
          OverlayService.showOverlay(state: 'enhancing');
          final enhancer = AiEnhanceService(aiEnhanceConfig);
          finalText = await enhancer.enhance(rawText);
        } catch (e) {
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
        } catch (e) {
          // ignore
        }
        try {
          await OverlayService.insertText(finalText);
          OverlayService.hideOverlay();
        } catch (e) {
          // ignore
        }
        OverlayService.hideOverlay();
      } else {
        _error = '转录结果为空';
        await _showTranscribeFailedOverlay();
      }

      notifyListeners();
    } catch (e) {
      _error = '转录失败: $e';
      await LogService.error('RECORDING', _error);
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
      // ignore
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
