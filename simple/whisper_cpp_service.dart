import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 可下载的模型定义
class WhisperModel {
  final String fileName;
  final String url;
  final String description;
  final int approximateSizeMB;
  final WhisperModelType modelType;

  const WhisperModel({
    required this.fileName,
    required this.url,
    required this.description,
    required this.approximateSizeMB,
    required this.modelType,
  });
}

/// 模型类型枚举
enum WhisperModelType { tiny, base, small }

/// 预定义可下载模型列表（精简版不支持本地模型，保留空列表）
const kWhisperModels = <WhisperModel>[];

/// 精简版 WhisperCppService — 不支持本地语音模型
class WhisperCppService {
  final String modelPath;

  WhisperCppService({
    String executablePath = '',
    required this.modelPath,
  });

  static Future<String> get defaultModelDir async {
    final appDir = await getApplicationSupportDirectory();
    return p.join(appDir.path, 'models');
  }

  static Future<bool> isModelDownloaded(String fileName) async => false;

  static Future<String> modelFilePath(String fileName) async {
    final dir = await defaultModelDir;
    return p.join(dir, fileName);
  }

  static Future<void> downloadModel(
    WhisperModel model, {
    required void Function(double progress) onProgress,
    void Function(String message)? onStatus,
  }) async {
    throw WhisperCppException('精简版不支持本地语音模型，请使用云端语音服务');
  }

  static Future<void> deleteModel(String fileName) async {}

  Future<String> transcribe(String audioPath) async {
    throw WhisperCppException('精简版不支持本地语音模型，请使用云端语音服务');
  }

  Future<WhisperCppCheckResult> checkAvailability() async {
    return const WhisperCppCheckResult(
      ok: false,
      message: '精简版不支持本地语音模型',
    );
  }
}

class WhisperCppCheckResult {
  final bool ok;
  final String message;
  const WhisperCppCheckResult({required this.ok, required this.message});
}

class WhisperCppException implements Exception {
  final String message;
  WhisperCppException(this.message);

  @override
  String toString() => message;
}
