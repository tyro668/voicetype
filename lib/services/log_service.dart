import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class LogService {
  static Future<String> get logDirectoryPath async {
    if (Platform.isMacOS) {
      final libraryDir = await getLibraryDirectory();
      final logsDir = Directory(path.join(libraryDir.path, 'Logs'));
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
}
