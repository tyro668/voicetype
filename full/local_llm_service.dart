import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:llamadart/llamadart.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:voicetype/services/log_service.dart';

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

/// 模型下载镜像源（国内镜像优先）
const _kLlmModelHosts = [
  'https://hf-mirror.com/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main',
  'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main',
];

/// 预定义可下载模型列表
const kLocalLlmModels = [
  LocalLlmModel(
    fileName: 'qwen2.5-0.5b-instruct-q5_k_m.gguf',
    description: 'Qwen2.5 0.5B Q5_K_M (~400MB) - 推荐，质量与速度平衡',
    approximateSizeMB: 400,
  ),
  LocalLlmModel(
    fileName: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
    description: 'Qwen2.5 0.5B Q4_K_M (~350MB) - 更小更快',
    approximateSizeMB: 350,
  ),
];

/// 本地 LLM 服务（通过 llamadart FFI 直接调用 llama.cpp）
class LocalLlmService {
  static LlamaEngine? _engine;
  static String? _currentModel;

  /// 获取应用数据根目录
  static Future<String> get _appDataDir async {
    final appDir = await getApplicationSupportDirectory();
    return appDir.path;
  }

  /// 获取 LLM 模型目录
  static Future<String> get defaultModelDir async {
    final root = await _appDataDir;
    return p.join(root, 'llm-models');
  }

  /// 检查模型文件是否已下载
  static Future<bool> isModelDownloaded(String fileName) async {
    final dir = await defaultModelDir;
    return File(p.join(dir, fileName)).exists();
  }

  /// 获取模型文件完整路径
  static Future<String> modelFilePath(String fileName) async {
    final dir = await defaultModelDir;
    return p.join(dir, fileName);
  }

  /// 检查引擎是否已加载
  static bool get isEngineLoaded => _engine != null;

  /// 本地模型专用提示词（针对小模型优化，简洁直接）
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

  /// 下载 LLM 模型文件（带镜像切换）
  static Future<void> downloadModel(
    LocalLlmModel model, {
    required void Function(double progress) onProgress,
    void Function(String message)? onStatus,
  }) async {
    final dir = await defaultModelDir;
    await Directory(dir).create(recursive: true);
    final filePath = p.join(dir, model.fileName);
    final tmpPath = '$filePath.tmp';

    String? lastError;

    for (var i = 0; i < _kLlmModelHosts.length; i++) {
      final host = _kLlmModelHosts[i];
      final url = '$host/${model.fileName}';
      final hostLabel = Uri.parse(host).host;

      await LogService.info(
        'LOCAL_LLM',
        'trying mirror ${i + 1}/${_kLlmModelHosts.length}: $url',
      );
      onStatus?.call('正在连接 $hostLabel ...');

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);

      try {
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close().timeout(
          const Duration(seconds: 30),
        );

        if (response.statusCode != 200) {
          await response.drain<void>();
          lastError = 'HTTP ${response.statusCode} from $hostLabel';
          client.close();
          continue;
        }

        onStatus?.call('正在从 $hostLabel 下载...');
        final totalBytes = response.contentLength;
        var receivedBytes = 0;
        final sink = File(tmpPath).openWrite();

        try {
          await for (final chunk in response) {
            sink.add(chunk);
            receivedBytes += chunk.length;
            if (totalBytes > 0) {
              onProgress(receivedBytes / totalBytes);
            }
          }
          await sink.flush();
          await sink.close();
        } catch (e) {
          await sink.close();
          try {
            await File(tmpPath).delete();
          } catch (_) {}
          lastError = '$hostLabel: $e';
          client.close();
          continue;
        }

        await File(tmpPath).rename(filePath);
        await LogService.info(
          'LOCAL_LLM',
          'download complete: $filePath ($receivedBytes bytes)',
        );
        client.close();
        return;
      } on TimeoutException {
        lastError = '$hostLabel 连接超时';
        client.close();
        continue;
      } on SocketException catch (e) {
        lastError = '$hostLabel 网络错误: ${e.message}';
        client.close();
        continue;
      } catch (e) {
        lastError = '$hostLabel: $e';
        client.close();
        continue;
      }
    }

    try {
      await File(tmpPath).delete();
    } catch (_) {}
    throw LocalLlmException('所有下载源均失败，请检查网络连接\n最后错误: $lastError');
  }

  /// 删除已下载的模型文件
  static Future<void> deleteModel(String fileName) async {
    final dir = await defaultModelDir;
    final file = File(p.join(dir, fileName));
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 加载模型到引擎（如果尚未加载或模型不同）
  static Future<void> loadModel(String modelFileName) async {
    if (_engine != null && _currentModel == modelFileName) {
      return;
    }
    await unloadModel();

    final modelPath = await modelFilePath(modelFileName);
    if (!await File(modelPath).exists()) {
      throw LocalLlmException('模型文件不存在: $modelFileName\n请先下载模型');
    }

    await LogService.info('LOCAL_LLM', 'loading model: $modelPath');

    _engine = LlamaEngine(LlamaBackend());
    await _engine!.loadModel(
      modelPath,
      modelParams: const ModelParams(
        contextSize: 2048,
        gpuLayers: ModelParams.maxGpuLayers,
      ),
    );
    _currentModel = modelFileName;

    await LogService.info('LOCAL_LLM', 'model loaded: $modelFileName');
  }

  /// 卸载当前模型，释放资源
  static Future<void> unloadModel() async {
    if (_engine != null) {
      await _engine!.dispose();
      _engine = null;
      _currentModel = null;
      await LogService.info('LOCAL_LLM', 'model unloaded');
    }
  }

  /// 使用本地模型进行文本增强（chat completion）
  static Future<String> enhance({
    required String modelFileName,
    required String systemPrompt,
    required String userMessage,
  }) async {
    await loadModel(modelFileName);

    final session = ChatSession(_engine!, systemPrompt: systemPrompt);

    final buffer = StringBuffer();
    await for (final chunk in session.create([LlamaTextContent(userMessage)])) {
      final content = chunk.choices.first.delta.content;
      if (content != null) {
        buffer.write(content);
      }
    }

    return buffer.toString().trim();
  }

  /// 检查本地模型可用性
  static Future<LocalLlmCheckResult> checkAvailability(
    String modelFileName,
  ) async {
    try {
      final modelPath = await modelFilePath(modelFileName);
      if (!await File(modelPath).exists()) {
        return LocalLlmCheckResult(
          ok: false,
          message: '模型文件不存在: $modelFileName\n请在设置中下载模型',
        );
      }

      return LocalLlmCheckResult(ok: true, message: '本地模型就绪 ($modelFileName)');
    } catch (e) {
      return LocalLlmCheckResult(ok: false, message: '检查失败: $e');
    }
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
