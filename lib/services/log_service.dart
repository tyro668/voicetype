import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class LogService {
  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
  static String _threeDigits(int value) => value.toString().padLeft(3, '0');

  static String _formatLocalTimestamp24h(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = _twoDigits(local.month);
    final d = _twoDigits(local.day);
    final hh = _twoDigits(local.hour);
    final mm = _twoDigits(local.minute);
    final ss = _twoDigits(local.second);
    final ms = _threeDigits(local.millisecond);
    return '$y-$m-$d $hh:$mm:$ss.$ms';
  }

  static Future<String> get logDirectoryPath async {
    if (Platform.isMacOS) {
      final libraryDir = await getLibraryDirectory();
      final logsDir = Directory(
        path.join(libraryDir.path, 'Logs', 'voicetype'),
      );
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }
      return logsDir.path;
    }

    final dir = await getApplicationSupportDirectory();
    return dir.path;
  }

  static Future<String> get logFilePath async {
    final dir = await logDirectoryPath;
    return path.join(dir, 'voicetype.log');
  }

  static Future<bool> logFileExists() async {
    final logPath = await logFilePath;
    final file = File(logPath);
    return await file.exists();
  }

  static Future<int?> getLogFileSize() async {
    try {
      final logPath = await logFilePath;
      final file = File(logPath);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (_) {}
    return null;
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static Future<void> appendLog(
    String message, {
    String level = 'INFO',
    String tag = 'APP',
  }) async {
    try {
      final logPath = await logFilePath;
      final file = File(logPath);
      if (!await file.exists()) {
        await file.create(recursive: true);
      }

      final ts = _formatLocalTimestamp24h(DateTime.now());
      final line = '[$ts][$level][$tag] $message\n';
      await file.writeAsString(line, mode: FileMode.append, flush: true);
    } catch (_) {
      // ignore logging failures
    }
  }

  static Future<void> info(String tag, String message) async {
    await appendLog(message, level: 'INFO', tag: tag);
  }

  static Future<void> warn(String tag, String message) async {
    await appendLog(message, level: 'WARN', tag: tag);
  }

  static Future<void> error(String tag, String message) async {
    await appendLog(message, level: 'ERROR', tag: tag);
  }
}
