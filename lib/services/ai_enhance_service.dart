import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import '../models/ai_enhance_config.dart';
import 'local_llm_service.dart';
import 'log_service.dart';
import 'network_client_service.dart';

class AiEnhanceService {
  static const _timeout = Duration(seconds: 30);
  static const _streamTimeout = Duration(seconds: 60);

  final AiEnhanceConfig config;

  AiEnhanceService(this.config);

  /// Whether this config represents a local model (empty baseUrl + empty apiKey).
  bool get _isLocalModel => config.baseUrl.trim().isEmpty && config.apiKey.trim().isEmpty;

  String? _apiKeyValidationMessage() {
    if (_isLocalModel) return null; // local model doesn't need API key
    final apiKey = config.apiKey.trim();
    if (apiKey.isEmpty) {
      return 'API密钥为空，请先填写 API Key';
    }
    if (apiKey.startsWith('ENC:')) {
      return 'API密钥解密失败，请重新输入 API Key';
    }
    return null;
  }

  Future<AiEnhanceResult> enhance(String text) async {
    if (text.trim().isEmpty) return AiEnhanceResult(text: text);

    // 本地模型：直接通过 FFI 调用 llamadart
    if (_isLocalModel) {
      return _enhanceLocal(text);
    }

    await LogService.info(
      'AI',
      'start enhance model=${config.model} baseUrl=${config.baseUrl} textLength=${text.length}',
    );

    final apiKeyError = _apiKeyValidationMessage();
    if (apiKeyError != null) {
      await LogService.error('AI', 'api key validation failed: $apiKeyError');
      throw AiEnhanceException('AI增强失败: $apiKeyError');
    }

    final resolvedPrompt =
        (config.prompt.trim().isEmpty
                ? AiEnhanceConfig.defaultPrompt
                : config.prompt)
            .replaceAll('{agentName}', config.agentName);

    final headers = _buildHeaders();
    final body = json.encode({
      'model': config.model,
      'temperature': 0.2,
      'messages': [
        {'role': 'system', 'content': resolvedPrompt},
        {'role': 'user', 'content': _buildEnhanceUserMessage(text)},
      ],
    });

    final uri = Uri.parse(
      '${_normalizeBaseUrl(config.baseUrl)}/chat/completions',
    );

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw AiEnhanceException('AI增强失败: 无效的端点 URL');
    }

    final client = NetworkClientService.createClient();
    try {
      final response = await client
          .post(uri, headers: headers, body: body)
          .timeout(_timeout);

      await LogService.info(
        'AI',
        'enhance response status=${response.statusCode} bodyLength=${response.body.length}',
      );

      if (response.statusCode == 200) {
        final jsonBody = json.decode(response.body) as Map<String, dynamic>;
        final content = _extractContentFromJson(jsonBody, text);
        final usage = jsonBody['usage'] as Map<String, dynamic>?;
        final promptTokens = (usage?['prompt_tokens'] as int?) ?? 0;
        final completionTokens = (usage?['completion_tokens'] as int?) ?? 0;
        await LogService.info(
          'AI',
          'enhance success textLength=${content.length} promptTokens=$promptTokens completionTokens=$completionTokens',
        );
        return AiEnhanceResult(
          text: content,
          promptTokens: promptTokens,
          completionTokens: completionTokens,
        );
      }

      // 尝试解析错误信息
      String errorMsg = 'AI增强失败 (${response.statusCode})';
      try {
        final jsonBody = json.decode(response.body) as Map<String, dynamic>;
        final error = jsonBody['error'] as Map<String, dynamic>?;
        if (error != null) {
          errorMsg = 'AI增强失败: ${error['message'] ?? response.body}';
        } else if (jsonBody['message'] != null) {
          errorMsg = 'AI增强失败: ${jsonBody['message']}';
        }
      } catch (_) {
        errorMsg = 'AI增强失败 (${response.statusCode}): ${response.body}';
      }

      await LogService.error('AI', errorMsg);
      throw AiEnhanceException(errorMsg);
    } on TimeoutException {
      await LogService.error('AI', 'AI增强失败: 请求超时');
      throw AiEnhanceException('AI增强失败: 请求超时');
    } on SocketException catch (e) {
      await LogService.error('AI', 'AI增强失败: 网络连接错误 - ${e.message}');
      throw AiEnhanceException('AI增强失败: 网络连接错误 - ${e.message}');
    } catch (e) {
      if (e is AiEnhanceException) rethrow;
      await LogService.error('AI', 'AI增强失败: $e');
      throw AiEnhanceException('AI增强失败: $e');
    } finally {
      client.close();
    }
  }

  /// 本地模型增强：通过 llamadart FFI 直接推理
  Future<AiEnhanceResult> _enhanceLocal(String text) async {
    await LogService.info(
      'AI',
      'start local enhance model=${config.model} textLength=${text.length}',
    );

    // 本地小模型使用专用的简洁提示词
    final localPrompt = await LocalLlmService.localPrompt;

    try {
      final result = await LocalLlmService.enhance(
        modelFileName: config.model,
        systemPrompt: localPrompt,
        userMessage: text,
      );

      final cleaned = _sanitizeEnhancedText(result);
      final content = cleaned.isEmpty ? text : cleaned;

      await LogService.info(
        'AI',
        'local enhance success textLength=${content.length}',
      );

      return AiEnhanceResult(text: content);
    } catch (e) {
      await LogService.error('AI', 'local enhance failed: $e');
      throw AiEnhanceException('AI增强失败 (本地模型): $e');
    }
  }

  /// Streaming AI enhance using SSE (Server-Sent Events).
  /// Yields text chunks as they arrive.
  Stream<String> enhanceStream(String text) async* {
    if (text.trim().isEmpty) {
      yield text;
      return;
    }

    // Local model: fall back to batch
    if (_isLocalModel) {
      final result = await _enhanceLocal(text);
      yield result.text;
      return;
    }

    await LogService.info(
      'AI',
      'start streaming enhance model=${config.model} baseUrl=${config.baseUrl}',
    );

    final apiKeyError = _apiKeyValidationMessage();
    if (apiKeyError != null) {
      await LogService.error('AI', 'api key validation failed: $apiKeyError');
      throw AiEnhanceException('AI增强失败: $apiKeyError');
    }

    final resolvedPrompt =
        (config.prompt.trim().isEmpty
                ? AiEnhanceConfig.defaultPrompt
                : config.prompt)
            .replaceAll('{agentName}', config.agentName);

    final uri = Uri.parse(
      '${_normalizeBaseUrl(config.baseUrl)}/chat/completions',
    );

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw AiEnhanceException('AI增强失败: 无效的端点 URL');
    }

    final bodyMap = {
      'model': config.model,
      'temperature': 0.2,
      'stream': true,
      'messages': [
        {'role': 'system', 'content': resolvedPrompt},
        {'role': 'user', 'content': _buildEnhanceUserMessage(text)},
      ],
    };

    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await httpClient.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      final apiKey = config.apiKey.trim();
      if (apiKey.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $apiKey');
      }
      request.write(json.encode(bodyMap));

      final response = await request.close().timeout(_streamTimeout);

      if (response.statusCode != 200) {
        final body = await response.transform(utf8.decoder).join();
        await LogService.error('AI', 'streaming enhance failed: ${response.statusCode} $body');
        throw AiEnhanceException('AI增强失败 (${response.statusCode})');
      }

      // Parse SSE stream
      await for (final chunk in response.transform(utf8.decoder)) {
        final lines = chunk.split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed == 'data: [DONE]') continue;
          if (!trimmed.startsWith('data: ')) continue;

          final jsonStr = trimmed.substring(6);
          try {
            final jsonData = json.decode(jsonStr) as Map<String, dynamic>;
            final choices = jsonData['choices'] as List<dynamic>?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices.first['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) {
                yield content;
              }
            }
          } catch (_) {
            // Skip malformed SSE data lines
          }
        }
      }

      await LogService.info('AI', 'streaming enhance complete');
    } on TimeoutException {
      await LogService.error('AI', 'streaming enhance timeout');
      throw AiEnhanceException('AI增强失败: 流式请求超时');
    } on SocketException catch (e) {
      await LogService.error('AI', 'streaming enhance socket error: ${e.message}');
      throw AiEnhanceException('AI增强失败: 网络连接错误 - ${e.message}');
    } catch (e) {
      if (e is AiEnhanceException) rethrow;
      await LogService.error('AI', 'streaming enhance error: $e');
      throw AiEnhanceException('AI增强失败: $e');
    } finally {
      httpClient.close();
    }
  }

  String _buildEnhanceUserMessage(String text) {
    return '''
请严格根据 system 提示词对以下文本做优化。
仅输出优化后的文本本身，不要添加解释、前后缀或引号。

<source>
$text
</source>
''';
  }

  /// 检查文本模型服务是否可用
  Future<bool> checkAvailability() async {
    final result = await checkAvailabilityDetailed();
    return result.ok;
  }

  Future<AiConnectionCheckResult> checkAvailabilityDetailed() async {
    // 本地模型：检查模型文件是否就绪
    if (_isLocalModel) {
      final result = await LocalLlmService.checkAvailability(config.model);
      return AiConnectionCheckResult(ok: result.ok, message: result.message);
    }

    await LogService.info(
      'AI',
      'checkAvailability model=${config.model} baseUrl=${config.baseUrl}',
    );

    final apiKeyError = _apiKeyValidationMessage();
    if (apiKeyError != null) {
      await LogService.error('AI', 'checkAvailability failed: $apiKeyError');
      return AiConnectionCheckResult(ok: false, message: apiKeyError);
    }

    final normalizedBase = _normalizeBaseUrl(config.baseUrl);
    developer.log('检查连接 - 基础URL: $normalizedBase', name: 'AiEnhanceService');

    if (!_isValidBaseUrl(normalizedBase)) {
      return const AiConnectionCheckResult(ok: false, message: '端点 URL 无效');
    }

    final headers = _buildHeaders();

    // 与 Z.ai 保持一致：测试连接统一使用 /models 端点
    return _checkModelsEndpoint(normalizedBase, headers);
  }

  /// 用 /models 端点快速检查连接和认证
  Future<AiConnectionCheckResult> _checkModelsEndpoint(
    String normalizedBase,
    Map<String, String> headers,
  ) async {
    final uri = Uri.parse('$normalizedBase/models');
    developer.log('检查连接 - 尝试 /models: $uri', name: 'AiEnhanceService');

    final client = NetworkClientService.createClient();
    try {
      final stopwatch = Stopwatch()..start();
      final response = await client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
      stopwatch.stop();

      developer.log(
        '检查连接 - /models 响应: ${response.statusCode}, 耗时: ${stopwatch.elapsedMilliseconds}ms',
        name: 'AiEnhanceService',
      );

      if (response.statusCode == 200) {
        await LogService.info('AI', '/models check success (${uri.host})');
        return AiConnectionCheckResult(ok: true, message: '连接成功 (${uri.host})');
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        // 尝试解析错误信息
        try {
          final jsonBody = json.decode(response.body) as Map<String, dynamic>;
          final error = jsonBody['error'] as Map<String, dynamic>?;
          final errorMsg =
              error?['message'] as String? ??
              jsonBody['message'] as String? ??
              '认证失败';
          return AiConnectionCheckResult(
            ok: false,
            message: 'API密钥无效: $errorMsg',
          );
        } catch (_) {
          return AiConnectionCheckResult(
            ok: false,
            message: 'API密钥无效 (${response.statusCode})',
          );
        }
      }

      // 404/405 表示服务可达但不支持该端点，仍视为连接成功
      if (response.statusCode == 404 || response.statusCode == 405) {
        return AiConnectionCheckResult(ok: true, message: '连接成功 (${uri.host})');
      }

      // 其他状态码（如 429 限流），服务端可达但有问题
      // 仍然视为连接成功（能收到响应说明服务可达）
      return AiConnectionCheckResult(ok: true, message: '连接成功 (${uri.host})');
    } on TimeoutException {
      developer.log('检查连接 - /models 超时', name: 'AiEnhanceService');
      await LogService.error('AI', 'checkAvailability timeout');
      return const AiConnectionCheckResult(ok: false, message: '请求超时，请检查网络连接');
    } on SocketException catch (e) {
      await LogService.error(
        'AI',
        'checkAvailability socket error: ${e.message}',
      );
      return AiConnectionCheckResult(
        ok: false,
        message: '网络连接失败: ${e.message}\n请检查网络连接和DNS设置',
      );
    } catch (e) {
      developer.log('检查连接 - /models 异常: $e', name: 'AiEnhanceService');
      await LogService.error('AI', 'checkAvailability error: $e');
      return AiConnectionCheckResult(ok: false, message: '连接失败: $e');
    } finally {
      client.close();
    }
  }

  bool _isValidBaseUrl(String baseUrl) {
    try {
      final uri = Uri.parse(baseUrl);
      return (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};

    final apiKey = config.apiKey.trim();
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    return headers;
  }

  String _extractContentFromJson(Map<String, dynamic> jsonBody, String fallbackText) {
    final choices = jsonBody['choices'] as List<dynamic>?;
    if (choices != null && choices.isNotEmpty) {
      final message = choices.first['message'] as Map<String, dynamic>?;
      final content = _readMessageContent(message?['content']);
      if (content.isEmpty) return fallbackText;
      final cleaned = _sanitizeEnhancedText(content);
      return cleaned.isEmpty ? fallbackText : cleaned;
    }
    return fallbackText;
  }

  String _readMessageContent(dynamic content) {
    if (content is String) return content.trim();
    if (content is List) {
      final buffer = StringBuffer();
      for (final item in content) {
        if (item is Map<String, dynamic>) {
          final text = item['text'];
          if (text is String && text.trim().isNotEmpty) {
            if (buffer.isNotEmpty) buffer.writeln();
            buffer.write(text.trim());
          }
        }
      }
      return buffer.toString().trim();
    }
    return '';
  }

  String _sanitizeEnhancedText(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return cleaned;
    final normalized = cleaned.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    const genericReplies = <String>{
      '谢谢',
      '谢谢你',
      'thanks',
      'thankyou',
      '好的',
      'ok',
    };
    if (genericReplies.contains(normalized)) {
      return '';
    }
    return cleaned;
  }

  String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}

class AiEnhanceException implements Exception {
  final String message;
  AiEnhanceException(this.message);

  @override
  String toString() => message;
}

class AiConnectionCheckResult {
  final bool ok;
  final String message;

  const AiConnectionCheckResult({required this.ok, required this.message});
}

/// AI 增强结果，包含增强后的文本和 token 用量。
class AiEnhanceResult {
  final String text;
  final int promptTokens;
  final int completionTokens;

  const AiEnhanceResult({
    required this.text,
    this.promptTokens = 0,
    this.completionTokens = 0,
  });

  int get totalTokens => promptTokens + completionTokens;
}

