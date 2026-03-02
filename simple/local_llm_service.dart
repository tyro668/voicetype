import 'package:flutter/services.dart';

/// 可下载的本地 LLM 模型定义
class LocalLlmModel {
  final String fileName;
  final String description;
  final int approximateSizeMB;

  const LocalLlmModel({
    required this.fileName,
    required this.description,
    required this.approximateSizeMB,
  });
}

class LocalMachineSpec {
  final int cpuCores;
  final double? totalMemoryGB;

  const LocalMachineSpec({required this.cpuCores, required this.totalMemoryGB});
}

class LocalModelRecommendation {
  final Set<String> recommendedModelFileNames;
  final String summary;

  const LocalModelRecommendation({
    required this.recommendedModelFileNames,
    required this.summary,
  });
}

/// 预定义可下载模型列表（精简版不支持本地模型，保留空列表）
const kLocalLlmModels = <LocalLlmModel>[];

/// 精简版 LocalLlmService — 不支持本地文本模型
class LocalLlmService {
  static bool get isEngineLoaded => false;

  static String? _localPromptCache;

  static Future<String> get localPrompt async {
    if (_localPromptCache != null) return _localPromptCache!;
    try {
      _localPromptCache = await rootBundle.loadString(
        'assets/prompts/local_model_prompt.md',
      );
    } catch (_) {
      _localPromptCache = '你是文字编辑助手。清理语音转文字文本：删除语气词和重复词，修正标点，保持原意。直接输出结果。';
    }
    return _localPromptCache!;
  }

  static Future<String> get defaultModelDir async => '';

  static Future<bool> isModelDownloaded(String fileName) async => false;

  static Future<String> modelFilePath(String fileName) async => '';

  static Future<LocalMachineSpec> detectMachineSpec() async {
    return const LocalMachineSpec(cpuCores: 0, totalMemoryGB: null);
  }

  static Future<LocalModelRecommendation>
  recommendModelsForCurrentMachine() async {
    return const LocalModelRecommendation(
      recommendedModelFileNames: <String>{},
      summary: '精简版不支持本地文本模型推荐，请使用云端 AI 服务。',
    );
  }

  static Future<void> downloadModel(
    LocalLlmModel model, {
    required void Function(double progress) onProgress,
    void Function(String message)? onStatus,
  }) async {
    throw LocalLlmException('精简版不支持本地文本模型，请使用云端 AI 服务');
  }

  static Future<void> deleteModel(String fileName) async {}

  static Future<void> loadModel(String modelFileName) async {
    throw LocalLlmException('精简版不支持本地文本模型');
  }

  static Future<void> unloadModel() async {}

  static Future<String> enhance({
    required String modelFileName,
    required String systemPrompt,
    required String userMessage,
  }) async {
    throw LocalLlmException('精简版不支持本地文本模型，请使用云端 AI 服务');
  }

  static Stream<String> enhanceStream({
    required String modelFileName,
    required String systemPrompt,
    required String userMessage,
  }) async* {
    throw LocalLlmException('精简版不支持本地文本模型，请使用云端 AI 服务');
  }

  static Future<LocalLlmCheckResult> checkAvailability(
    String modelFileName,
  ) async {
    return const LocalLlmCheckResult(ok: false, message: '精简版不支持本地文本模型');
  }
}

class LocalLlmCheckResult {
  final bool ok;
  final String message;
  const LocalLlmCheckResult({required this.ok, required this.message});
}

class LocalLlmException implements Exception {
  final String message;
  LocalLlmException(this.message);

  @override
  String toString() => message;
}
