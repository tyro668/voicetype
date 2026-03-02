import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:llamadart/llamadart.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'log_service.dart';

/// 可下载的本地 LLM 模型定义
class LocalLlmModel {
  final String fileName;
  final String description;
  final int approximateSizeMB;
  final List<String>? downloadHosts;

  const LocalLlmModel({
    required this.fileName,
    required this.description,
    required this.approximateSizeMB,
    this.downloadHosts,
  });
}

/// 模型下载镜像源（国内镜像优先）
const _kDefaultLlmModelHosts = [
  'https://hf-mirror.com/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main',
  'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main',
];

/// 预定义可下载模型列表
const kLocalLlmModels = [
  LocalLlmModel(
    fileName: 'Qwen2.5-7B-Instruct-Q4_K_M.gguf',
    description: 'Qwen2.5 7B Q4_K_M (~4.7GB) - 最推荐',
    approximateSizeMB: 4700,
    downloadHosts: [
      'https://hf-mirror.com/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main',
      'https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main',
    ],
  ),
  LocalLlmModel(
    fileName: 'qwen2.5-0.5b-instruct-q5_k_m.gguf',
    description: 'Qwen2.5 0.5B Q5_K_M (~400MB) - 推荐，质量与速度平衡',
    approximateSizeMB: 400,
  ),
  LocalLlmModel(
    fileName: 'Qwen2.5-14B-Instruct-Q4_K_M.gguf',
    description: 'Qwen2.5 14B Q4_K_M (~8.9GB) - 高质量（需更高内存）',
    approximateSizeMB: 8900,
    downloadHosts: [
      'https://hf-mirror.com/bartowski/Qwen2.5-14B-Instruct-GGUF/resolve/main',
      'https://huggingface.co/bartowski/Qwen2.5-14B-Instruct-GGUF/resolve/main',
    ],
  ),
  LocalLlmModel(
    fileName: 'DeepSeek-V2-Lite-Chat-Q4_K_M.gguf',
    description: 'DeepSeek-V2-Lite (16B) Q4_K_M (~9.8GB) - 12G 显存可跑',
    approximateSizeMB: 9800,
    downloadHosts: [
      'https://hf-mirror.com/bartowski/DeepSeek-V2-Lite-Chat-GGUF/resolve/main',
      'https://huggingface.co/bartowski/DeepSeek-V2-Lite-Chat-GGUF/resolve/main',
    ],
  ),
];

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

/// 本地 LLM 服务（通过 llamadart FFI 直接调用 llama.cpp）
class LocalLlmService {
  static LlamaEngine? _engine;
  static String? _currentModel;

  static bool get isEngineLoaded => _engine != null;

  static const _kModelQwen05Q5 = 'qwen2.5-0.5b-instruct-q5_k_m.gguf';
  static const _kModelQwen7BQ4 = 'Qwen2.5-7B-Instruct-Q4_K_M.gguf';
  static const _kModelQwen14BQ4 = 'Qwen2.5-14B-Instruct-Q4_K_M.gguf';
  static const _kModelDeepSeekLite = 'DeepSeek-V2-Lite-Chat-Q4_K_M.gguf';

  /// 获取应用数据根目录
  static Future<String> get _appDataDir async {
    final appDir = await getApplicationSupportDirectory();
    return appDir.path;
  }

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

  static Future<String> get defaultModelDir async {
    final root = await _appDataDir;
    return p.join(root, 'llm-models');
  }

  static Future<bool> isModelDownloaded(String fileName) async {
    final dir = await defaultModelDir;
    return File(p.join(dir, fileName)).exists();
  }

  static Future<String> modelFilePath(String fileName) async {
    final dir = await defaultModelDir;
    return p.join(dir, fileName);
  }

  static Future<LocalMachineSpec> detectMachineSpec() async {
    final cpuCores = Platform.numberOfProcessors;
    final memoryBytes = await _detectTotalMemoryBytes();
    final memoryGb = memoryBytes != null
        ? memoryBytes / (1024 * 1024 * 1024)
        : null;
    return LocalMachineSpec(cpuCores: cpuCores, totalMemoryGB: memoryGb);
  }

  static Future<LocalModelRecommendation>
  recommendModelsForCurrentMachine() async {
    final spec = await detectMachineSpec();
    final recommended = <String>{};

    final memoryGb = spec.totalMemoryGB;
    final cores = spec.cpuCores;

    if (memoryGb != null) {
      if (memoryGb >= 128 && cores >= 16) {
        recommended
          ..add(_kModelDeepSeekLite)
          ..add(_kModelQwen14BQ4)
          ..add(_kModelQwen7BQ4)
          ..add(_kModelQwen05Q5);
      } else if (memoryGb >= 48) {
        recommended
          ..add(_kModelQwen14BQ4)
          ..add(_kModelQwen7BQ4)
          ..add(_kModelQwen05Q5);
      } else if (memoryGb >= 24) {
        recommended
          ..add(_kModelQwen7BQ4)
          ..add(_kModelQwen05Q5);
      } else {
        recommended..add(_kModelQwen05Q5);
      }
    } else {
      if (cores >= 16) {
        recommended
          ..add(_kModelQwen14BQ4)
          ..add(_kModelQwen7BQ4)
          ..add(_kModelQwen05Q5);
      } else if (cores >= 8) {
        recommended
          ..add(_kModelQwen7BQ4)
          ..add(_kModelQwen05Q5);
      } else {
        recommended..add(_kModelQwen05Q5);
      }
    }

    final memoryText = memoryGb != null
        ? '${memoryGb.toStringAsFixed(0)}GB 内存'
        : '内存未知';
    final summary = '检测到约 $memoryText / ${spec.cpuCores} 核 CPU，已为你标记推荐模型。';

    return LocalModelRecommendation(
      recommendedModelFileNames: recommended,
      summary: summary,
    );
  }

  static Future<int?> _detectTotalMemoryBytes() async {
    try {
      if (Platform.isMacOS) {
        final result = await Process.run('sysctl', ['-n', 'hw.memsize']);
        if (result.exitCode == 0) {
          final raw = result.stdout.toString().trim();
          return int.tryParse(raw);
        }
      }

      if (Platform.isLinux || Platform.isAndroid) {
        final memInfo = File('/proc/meminfo');
        if (await memInfo.exists()) {
          final content = await memInfo.readAsString();
          final match = RegExp(
            r'^MemTotal:\s+(\d+)\s+kB',
            multiLine: true,
          ).firstMatch(content);
          if (match != null) {
            final kb = int.tryParse(match.group(1)!);
            if (kb != null) return kb * 1024;
          }
        }
      }

      if (Platform.isWindows) {
        final result = await Process.run('wmic', [
          'computersystem',
          'get',
          'TotalPhysicalMemory',
          '/value',
        ]);
        if (result.exitCode == 0) {
          final out = result.stdout.toString();
          final match = RegExp(r'TotalPhysicalMemory=(\d+)').firstMatch(out);
          if (match != null) {
            return int.tryParse(match.group(1)!);
          }
        }
      }
    } catch (_) {}
    return null;
  }

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

    final hosts = model.downloadHosts ?? _kDefaultLlmModelHosts;

    for (var i = 0; i < hosts.length; i++) {
      final host = hosts[i];
      final url = '$host/${model.fileName}';
      final hostLabel = Uri.parse(host).host;

      await LogService.info(
        'LOCAL_LLM',
        'trying mirror ${i + 1}/${hosts.length}: $url',
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

  static Future<void> deleteModel(String fileName) async {
    final dir = await defaultModelDir;
    final file = File(p.join(dir, fileName));
    if (await file.exists()) {
      await file.delete();
    }
  }

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

    final gpuLayers = _resolveGpuLayers(modelFileName);
    await LogService.info(
      'LOCAL_LLM',
      'model params: contextSize=2048 gpuLayers=$gpuLayers',
    );

    _engine = LlamaEngine(LlamaBackend());
    await _engine!.loadModel(
      modelPath,
      modelParams: ModelParams(contextSize: 2048, gpuLayers: gpuLayers),
    );
    _currentModel = modelFileName;

    await LogService.info('LOCAL_LLM', 'model loaded: $modelFileName');
  }

  static int _resolveGpuLayers(String modelFileName) {
    final lower = modelFileName.toLowerCase();
    // 16B 本地模型默认采用保守的部分 GPU offload，避免 12G 显存设备 OOM。
    if (lower.contains('deepseek-v2-lite')) {
      return 20;
    }
    return ModelParams.maxGpuLayers;
  }

  static Future<void> unloadModel() async {
    if (_engine != null) {
      await _engine!.dispose();
      _engine = null;
      _currentModel = null;
      await LogService.info('LOCAL_LLM', 'model unloaded');
    }
  }

  static Future<String> enhance({
    required String modelFileName,
    required String systemPrompt,
    required String userMessage,
  }) async {
    final buffer = StringBuffer();
    await for (final chunk in enhanceStream(
      modelFileName: modelFileName,
      systemPrompt: systemPrompt,
      userMessage: userMessage,
    )) {
      buffer.write(chunk);
    }

    return buffer.toString().trim();
  }

  static Stream<String> enhanceStream({
    required String modelFileName,
    required String systemPrompt,
    required String userMessage,
  }) async* {
    await loadModel(modelFileName);

    final session = ChatSession(_engine!, systemPrompt: systemPrompt);
    await for (final chunk in session.create([LlamaTextContent(userMessage)])) {
      final content = chunk.choices.first.delta.content;
      if (content != null && content.isNotEmpty) {
        yield content;
      }
    }
  }

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
