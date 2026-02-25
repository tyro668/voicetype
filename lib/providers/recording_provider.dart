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
import '../services/token_stats_service.dart';
import '../services/vad_service.dart';

enum RecordingState { idle, recording, transcribing }

class RecordingProvider extends ChangeNotifier {
  final AudioRecorderService _recorder = AudioRecorderService();
  final HistoryDb _historyDb = HistoryDb.instance;

  RecordingState _state = RecordingState.idle;
  bool _busy = false;
  String _transcribedText = '';
  String _error = '';
  DateTime? _recordingStartTime;
  Duration _recordingDuration = Duration.zero;
  Timer? _durationTimer;
  Timer? _healthTimer;
  StreamSubscription<double>? _amplitudeSub;
  final List<Transcription> _history = [];
  Completer<void>? _stopCompleter;
  VadService? _vadService;
  StreamSubscription<void>? _vadSub;
  // VAD auto-stop callback — set by the screen that owns the provider
  void Function()? onVadTriggered;
  String _startingLabel = 'Starting';
  String _recordingLabel = 'Recording';
  String _transcribingLabel = 'Transcribing';
  String _enhancingLabel = 'Enhancing';
  String _transcribeFailedLabel = 'Transcribe failed';

  RecordingProvider() {
    _loadHistory();
  }

  RecordingState get state => _state;
  bool get busy => _busy;
  String get transcribedText => _transcribedText;
  String get error => _error;
  Duration get recordingDuration => _recordingDuration;
  List<Transcription> get history => List.unmodifiable(_history);
  Stream<double> get amplitudeStream => _recorder.amplitudeStream;

  void setOverlayStateLabels({
    required String starting,
    required String recording,
    required String transcribing,
    required String enhancing,
    required String transcribeFailed,
  }) {
    _startingLabel = starting;
    _recordingLabel = recording;
    _transcribingLabel = transcribing;
    _enhancingLabel = enhancing;
    _transcribeFailedLabel = transcribeFailed;
  }

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
    if (_busy) return;
    _busy = true;
    try {
      await _startRecordingInternal().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          LogService.error('RECORDING', 'startRecording timed out after 15s');
          _state = RecordingState.idle;
          unawaited(OverlayService.hideOverlay());
          notifyListeners();
        },
      );
    } catch (e) {
      _error = '录音启动失败: $e';
      _state = RecordingState.idle;
      unawaited(OverlayService.hideOverlay());
      notifyListeners();
    } finally {
      _busy = false;
    }
  }

  Future<void> _startRecordingInternal() async {
    // 等待上一次 stop 操作完成，避免竞态
    if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
      await LogService.info('RECORDING', 'waiting for stopCompleter');
      await _stopCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {},
      );
    }
    _error = '';
    _amplitudeSub?.cancel();
    _amplitudeSub = null;

    // 无论当前状态如何，都先 reset recorder，确保干净状态
    await LogService.info('RECORDING', 'resetting recorder');
    try {
      await _recorder.reset().timeout(const Duration(seconds: 3));
    } catch (_) {
      // reset 超时也继续尝试录音
      await LogService.info('RECORDING', 'reset timeout, continuing');
    }
    await LogService.info('RECORDING', 'checking permission');
    final hasPermission = await _recorder.hasPermission()
        .timeout(const Duration(seconds: 3), onTimeout: () => false);
    if (!hasPermission) {
      _error = '需要麦克风权限才能录音';
      notifyListeners();
      return;
    }

    await LogService.info('RECORDING', 'showing starting overlay');
    // 不 await overlay 调用，避免阻塞录音流程
    unawaited(OverlayService.showOverlay(
      state: 'starting',
      duration: '00:00',
      level: 0.0,
      stateLabel: _startingLabel,
    ));

    await LogService.info('RECORDING', 'starting recorder');
    try {
      await _recorder.startWithTimeout(const Duration(seconds: 2));
    } catch (e) {
      await LogService.info('RECORDING', 'start failed ($e), resetting and retrying');
      try {
        await _recorder.reset().timeout(const Duration(seconds: 3));
      } catch (_) {}
      await _recorder.startWithTimeout(const Duration(seconds: 2));
    }
    await LogService.info('RECORDING', 'recorder started successfully');
    _state = RecordingState.recording;
    _recordingStartTime = DateTime.now();
    _recordingDuration = Duration.zero;

    unawaited(OverlayService.showOverlay(
      state: 'recording',
      duration: '00:00',
      level: 0.0,
      stateLabel: _recordingLabel,
    ));

    _amplitudeSub = _recorder.amplitudeStream.listen((level) {
      OverlayService.updateOverlay(
        state: 'recording',
        duration: _durationStr,
        level: level,
        stateLabel: _recordingLabel,
      );
    });

    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        await _recorder.isRecording();
        await _recorder.currentFileSize();
      } catch (_) {}
    });

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _recordingDuration = DateTime.now().difference(_recordingStartTime!);
      notifyListeners();
    });

    notifyListeners();
  }

  /// Start VAD monitoring. Call after startRecording().
  void startVad({
    double silenceThreshold = 0.05,
    int silenceDurationSeconds = 3,
    int minRecordingSeconds = 3,
  }) {
    stopVad();
    _vadService = VadService(
      silenceThreshold: silenceThreshold,
      silenceDuration: Duration(seconds: silenceDurationSeconds),
      minRecordingDuration: Duration(seconds: minRecordingSeconds),
    );
    _vadSub = _vadService!.onSilenceDetected.listen((_) {
      LogService.info('VAD', 'silence detected, triggering auto-stop');
      onVadTriggered?.call();
    });
    _vadService!.start(_recorder.amplitudeStream);
  }

  /// Stop VAD monitoring.
  void stopVad() {
    _vadSub?.cancel();
    _vadSub = null;
    _vadService?.dispose();
    _vadService = null;
  }

  Future<void> stopAndTranscribe(
    SttProviderConfig config, {
    bool aiEnhanceEnabled = false,
    AiEnhanceConfig? aiEnhanceConfig,
    int minRecordingSeconds = 3,
    bool useStreaming = false,
  }) async {
    if (_busy) return;
    _busy = true;
    stopVad();
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
        unawaited(OverlayService.hideOverlay());
        _stopCompleter = Completer<void>();
        _recorder.stop().then((_) => _recorder.reset()).whenComplete(() {
          if (!_stopCompleter!.isCompleted) _stopCompleter!.complete();
        });
        notifyListeners();
        return;
      }

      unawaited(OverlayService.showOverlay(
        state: 'transcribing',
        stateLabel: _transcribingLabel,
      ));
      _state = RecordingState.idle;
      notifyListeners();

      _stopCompleter = Completer<void>();
      unawaited(
        _stopAndTranscribeInBackground(
          config,
          duration,
          aiEnhanceEnabled: aiEnhanceEnabled,
          aiEnhanceConfig: aiEnhanceConfig,
          useStreaming: useStreaming,
        ),
      );
    } catch (e) {
      _error = '停止录音失败: $e';
      _state = RecordingState.idle;
      unawaited(OverlayService.hideOverlay());
      _amplitudeSub?.cancel();
      _amplitudeSub = null;
      if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
        _stopCompleter!.complete();
      }
      notifyListeners();
    } finally {
      _busy = false;
    }
  }

  Future<void> _stopAndTranscribeInBackground(
    SttProviderConfig config,
    Duration duration, {
    required bool aiEnhanceEnabled,
    required AiEnhanceConfig? aiEnhanceConfig,
    bool useStreaming = false,
  }) async {
    final sw = Stopwatch()..start();
    try {
      await LogService.info('TRANSCRIBE', 'step1: stopping recorder...');
      final stopFuture = _recorder.stop();
      final fallbackPath = _recorder.currentPath;

      var path = await stopFuture.timeout(
        const Duration(seconds: 20),
        onTimeout: () => null,
      );
      await LogService.info('TRANSCRIBE', 'step1 done: recorder.stop() ${sw.elapsedMilliseconds}ms, path=${path != null}');

      if (path == null && fallbackPath != null) {
        await LogService.info('TRANSCRIBE', 'step2: waiting for file ready fallbackPath=$fallbackPath');
        path = await _waitForFileReady(
          fallbackPath,
          const Duration(seconds: 20),
        );
        await LogService.info('TRANSCRIBE', 'step2 done: ${sw.elapsedMilliseconds}ms, path=${path != null}');
      }

      if (path == null) {
        await LogService.info('TRANSCRIBE', 'step3: retry stop...');
        path = await stopFuture.timeout(
          const Duration(seconds: 10),
          onTimeout: () => null,
        );
        await LogService.info('TRANSCRIBE', 'step3 done: ${sw.elapsedMilliseconds}ms, path=${path != null}');
      }

      // recorder 已停止，允许下一次录音
      if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
        _stopCompleter!.complete();
      }

      if (path == null) {
        _error = '录音文件获取失败';
        await LogService.error('TRANSCRIBE', 'no audio file after ${sw.elapsedMilliseconds}ms');
        await _recorder.reset();
        unawaited(OverlayService.hideOverlay());
        notifyListeners();
        return;
      }

      // 检查文件大小
      final file = File(path);
      final fileSize = await file.exists() ? await file.length() : -1;
      await LogService.info('TRANSCRIBE', 'audio file ready: size=${fileSize}bytes, elapsed=${sw.elapsedMilliseconds}ms');

      _transcribeInBackground(
        path,
        config,
        duration,
        aiEnhanceEnabled: aiEnhanceEnabled,
        aiEnhanceConfig: aiEnhanceConfig,
        useStreaming: useStreaming,
      );
    } catch (e) {
      _error = '停止录音失败: $e';
      await LogService.error('TRANSCRIBE', 'stop failed after ${sw.elapsedMilliseconds}ms: $e');
      if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
        _stopCompleter!.complete();
      }
      await _recorder.reset();
      unawaited(OverlayService.hideOverlay());
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
    bool useStreaming = false,
  }) async {
    final sw = Stopwatch()..start();
    try {
      await LogService.info('TRANSCRIBE', 'stt start: provider=${config.name} model=${config.model} baseUrl=${config.baseUrl}');
      final sttService = SttService(config);
      final rawText = await sttService.transcribe(path);
      await LogService.info('TRANSCRIBE', 'stt done: ${sw.elapsedMilliseconds}ms, textLength=${rawText.length}, text="${rawText.length > 50 ? rawText.substring(0, 50) : rawText}"');
      var finalText = rawText;

      if (aiEnhanceEnabled && aiEnhanceConfig != null) {
        try {
          await LogService.info('TRANSCRIBE', 'ai enhance start...');
          unawaited(OverlayService.showOverlay(
            state: 'enhancing',
            stateLabel: _enhancingLabel,
          ));
          final enhancer = AiEnhanceService(aiEnhanceConfig);

          if (useStreaming) {
            // Streaming mode: show text in real-time on overlay
            final buffer = StringBuffer();
            try {
              await for (final chunk in enhancer.enhanceStream(rawText)) {
                buffer.write(chunk);
                unawaited(OverlayService.updateOverlayText(
                  buffer.toString(),
                ));
              }
              finalText = buffer.toString().trim();
              if (finalText.isEmpty) finalText = rawText;
            } catch (e) {
              await LogService.error('TRANSCRIBE', 'streaming enhance failed: $e, falling back to batch');
              // Fallback to batch mode
              final enhanceResult = await enhancer.enhance(rawText);
              finalText = enhanceResult.text;
              if (enhanceResult.totalTokens > 0) {
                try {
                  await TokenStatsService.instance.addTokens(
                    promptTokens: enhanceResult.promptTokens,
                    completionTokens: enhanceResult.completionTokens,
                  );
                } catch (_) {}
              }
            }
          } else {
            // Batch mode (original)
            final enhanceResult = await enhancer.enhance(rawText);
            finalText = enhanceResult.text;
            // 累计 token 用量
            if (enhanceResult.totalTokens > 0) {
              try {
                await TokenStatsService.instance.addTokens(
                  promptTokens: enhanceResult.promptTokens,
                  completionTokens: enhanceResult.completionTokens,
                );
              } catch (_) {}
            }
          }
          await LogService.info('TRANSCRIBE', 'ai enhance done: ${sw.elapsedMilliseconds}ms');
        } catch (e) {
          await LogService.error('TRANSCRIBE', 'ai enhance failed: $e');
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
          await LogService.info('TRANSCRIBE', 'inserting text...');
          await OverlayService.insertText(finalText);
          await LogService.info('TRANSCRIBE', 'insertText done: ${sw.elapsedMilliseconds}ms');
        } catch (e) {
          await LogService.error('TRANSCRIBE', 'insertText failed: $e');
        }
        unawaited(OverlayService.hideOverlay());
        await LogService.info('TRANSCRIBE', 'complete success: total ${sw.elapsedMilliseconds}ms');
      } else {
        _error = '转录结果为空';
        await LogService.error('TRANSCRIBE', 'empty result after ${sw.elapsedMilliseconds}ms');
        _showTranscribeFailedOverlay();
      }

      notifyListeners();
    } catch (e) {
      _error = '转录失败: $e';
      await LogService.error('TRANSCRIBE', 'failed after ${sw.elapsedMilliseconds}ms: $e');
      _showTranscribeFailedOverlay();
      notifyListeners();
    }
  }

  void _showTranscribeFailedOverlay() {
    // 不 await overlay 调用，避免 MethodChannel 阻塞后续录音
    OverlayService.showOverlay(
      state: 'transcribe_failed',
      stateLabel: _transcribeFailedLabel,
    ).catchError((_) {});
    Future.delayed(const Duration(seconds: 3), () {
      OverlayService.hideOverlay().catchError((_) {});
    });
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
    stopVad();
    _recorder.dispose();
    super.dispose();
  }
}
