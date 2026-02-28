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
  String? _currentShortId;
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
    _currentShortId = shortId;
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

  /// 停止后将文件重命名为「xx年xx月xx日xx时xx分xx秒-6位uuid-录音时长xx秒.wav」
  Future<String?> _renameWithDuration(String? rawPath) async {
    if (rawPath == null) return null;
    final file = File(rawPath);
    if (!await file.exists()) return rawPath;

    final startedAt = _recordingStartedAt;
    final durationSecs = startedAt != null
        ? DateTime.now().difference(startedAt).inSeconds
        : 0;
    final shortId = _currentShortId ?? _extractShortId(rawPath);

    _recordingStartedAt = null;
    _currentShortId = null;

    final dir = path.dirname(rawPath);
    final ext = path.extension(rawPath);
    final dateText = _formatDateTimeForName(startedAt ?? DateTime.now());
    final durationText = _formatDurationForName(durationSecs);
    final newName = '$dateText-$shortId-$durationText$ext';
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

  String _formatDateTimeForName(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '${dt.year}年${mm}月${dd}日${hh}时${mi}分${ss}秒';
  }

  String _formatDurationForName(int seconds) {
    if (seconds <= 0) return '0秒';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}时${m}分${s}秒';
    if (m > 0) return '${m}分${s}秒';
    return '${s}秒';
  }

  String _extractShortId(String rawPath) {
    final base = path.basenameWithoutExtension(rawPath);
    final parts = base.split('-');
    if (parts.length >= 2) {
      final candidate = parts[1].trim();
      if (candidate.length == 6) return candidate;
    }
    return const Uuid().v4().substring(0, 6);
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
