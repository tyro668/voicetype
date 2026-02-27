import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

class AudioRecorderService {
  AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;
  DateTime? _recordingStartedAt;
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
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    final dir = await getApplicationSupportDirectory();
    final recordingsDir = Directory(path.join(dir.path, 'recordings'));
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    final now = DateTime.now();
    _recordingStartedAt = now;
    final ts =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final shortId = const Uuid().v4().substring(0, 6);
    _currentPath = path.join(recordingsDir.path, '${ts}-$shortId.wav');

    final file = File(_currentPath!);
    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 128000,
      ),
      path: _currentPath!,
    );

    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (
      _,
    ) async {
      final amp = await _recorder.getAmplitude();
      final normalized = ((amp.current + 50) / 50).clamp(0.0, 1.0);
      _amplitudeController.add(normalized);
    });
  }

  /// 停止后将文件重命名为「日期时间-6位uuid-录音秒数.wav」
  Future<String?> _renameWithDuration(String? rawPath) async {
    if (rawPath == null) return null;
    final file = File(rawPath);
    if (!await file.exists()) return rawPath;

    final durationSecs = _recordingStartedAt != null
        ? DateTime.now().difference(_recordingStartedAt!).inSeconds
        : 0;
    _recordingStartedAt = null;

    // 原文件名: 20260227143000-a1b2c3.wav → 20260227143000-a1b2c3-25.wav
    final dir = path.dirname(rawPath);
    final basename = path.basenameWithoutExtension(rawPath);
    final ext = path.extension(rawPath);
    final newName = '$basename-${durationSecs}s$ext';
    final newPath = path.join(dir, newName);

    try {
      final renamed = await file.rename(newPath);
      _currentPath = renamed.path;
      return renamed.path;
    } catch (_) {
      // 重命名失败则保留原路径
      return rawPath;
    }
  }

  Future<String?> stop() async {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    final rawPath = await _recorder.stop();
    return await _renameWithDuration(rawPath);
  }

  Future<String?> stopWithTimeout(Duration timeout) async {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    try {
      final rawPath = await _recorder.stop().timeout(
        timeout,
        onTimeout: () => null,
      );
      return await _renameWithDuration(rawPath);
    } catch (_) {
      return null;
    }
  }

  Future<void> reset() async {
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
