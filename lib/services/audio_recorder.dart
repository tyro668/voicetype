import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

class AudioRecorderService {
  AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;
  final _amplitudeController = StreamController<double>.broadcast();

  Stream<double> get amplitudeStream => _amplitudeController.stream;
  String? get currentPath => _currentPath;
  Timer? _amplitudeTimer;

  Future<bool> hasPermission() async {
    final granted = await _recorder.hasPermission();
    return granted;
  }

  Future<void> start() async {
    await _startInternal();
  }

  Future<void> startWithTimeout(Duration timeout) async {
    await _startInternal().timeout(timeout);
  }

  Future<void> _startInternal() async {
    debugPrint('[recorder] start internal');
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    final dir = await getApplicationSupportDirectory();
    final recordingsDir = Directory(path.join(dir.path, 'recordings'));
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    _currentPath = path.join(recordingsDir.path, '${const Uuid().v4()}.wav');

    final file = File(_currentPath!);
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    debugPrint('[recorder] output path: $_currentPath');

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 128000,
      ),
      path: _currentPath!,
    );

    debugPrint('[recorder] started: $_currentPath');

    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (
      _,
    ) async {
      final amp = await _recorder.getAmplitude();
      // 归一化到 0~1
      final normalized = ((amp.current + 50) / 50).clamp(0.0, 1.0);
      _amplitudeController.add(normalized);
    });
  }

  Future<String?> stop() async {
    debugPrint('[recorder] stop');
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    final path = await _recorder.stop();
    debugPrint('[recorder] stop result: $path');
    return path;
  }

  Future<String?> stopWithTimeout(Duration timeout) async {
    debugPrint('[recorder] stopWithTimeout');
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    try {
      final path = await _recorder.stop().timeout(
        timeout,
        onTimeout: () => null,
      );
      debugPrint('[recorder] stopWithTimeout result: $path');
      return path;
    } catch (_) {
      debugPrint('[recorder] stopWithTimeout error');
      return null;
    }
  }

  Future<void> reset() async {
    debugPrint('[recorder] reset');
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    try {
      await _recorder.stop().timeout(
        const Duration(seconds: 1),
        onTimeout: () => null,
      );
    } catch (_) {}
    _recorder.dispose();
    _recorder = AudioRecorder();
    debugPrint('[recorder] reset complete');
  }

  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  Future<int?> currentFileSize() async {
    final path = _currentPath;
    if (path == null) return null;
    final file = File(path);
    if (await file.exists()) {
      return await file.length();
    }
    return null;
  }

  /// 列出所有可用的音频输入设备
  Future<List<InputDevice>> listInputDevices() async {
    return await _recorder.listInputDevices();
  }

  void dispose() {
    _amplitudeTimer?.cancel();
    _amplitudeController.close();
    _recorder.dispose();
  }
}
