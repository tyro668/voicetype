import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/ai_enhance_config.dart';

class AiEnhanceService {
  static const _timeout = Duration(seconds: 30);

  final AiEnhanceConfig config;

  AiEnhanceService(this.config);

  Future<String> enhance(String text) async {
    if (text.trim().isEmpty) return text;

    final resolvedPrompt = config.prompt.replaceAll(
      '{agentName}',
      config.agentName,
    );

    final headers = _buildHeaders();
    final body = json.encode({
      'model': config.model,
      'temperature': 0.2,
      'messages': [
        {'role': 'system', 'content': resolvedPrompt},
        {'role': 'user', 'content': text},
      ],
    });

    final uri = Uri.parse(
      '${_normalizeBaseUrl(config.baseUrl)}/chat/completions',
    );

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw AiEnhanceException('AI增强失败: 无效的端点 URL');
    }

    final client = http.Client();
    try {
      final response = await client
          .post(uri, headers: headers, body: body)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return _extractContent(response.body, text);
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

      throw AiEnhanceException(errorMsg);
    } on TimeoutException {
      throw AiEnhanceException('AI增强失败: 请求超时');
    } on SocketException catch (e) {
      throw AiEnhanceException('AI增强失败: 网络连接错误 - ${e.message}');
    } catch (e) {
      if (e is AiEnhanceException) rethrow;
      throw AiEnhanceException('AI增强失败: $e');
    } finally {
      client.close();
    }
  }

  /// 检查文本模型服务是否可用
  Future<bool> checkAvailability() async {
    final result = await checkAvailabilityDetailed();
    return result.ok;
  }

  Future<AiConnectionCheckResult> checkAvailabilityDetailed() async {
    final normalizedBase = _normalizeBaseUrl(config.baseUrl);
    developer.log('检查连接 - 基础URL: $normalizedBase', name: 'AiEnhanceService');

    if (!_isValidBaseUrl(normalizedBase)) {
      return const AiConnectionCheckResult(ok: false, message: '端点 URL 无效');
    }

    final uri = Uri.parse('$normalizedBase/chat/completions');
    developer.log('检查连接 - 完整URI: $uri', name: 'AiEnhanceService');

    final headers = _buildHeaders();
    developer.log('检查连接 - 请求头已构建', name: 'AiEnhanceService');

    final body = json.encode({
      'model': config.model,
      'max_tokens': 5,
      'temperature': 0,
      'stream': false,
      'messages': [
        {'role': 'user', 'content': 'Hi'},
      ],
    });

    // 尝试连接，带重试机制
    for (int attempt = 1; attempt <= 2; attempt++) {
      developer.log('检查连接 - 第 $attempt 次尝试', name: 'AiEnhanceService');

      final client = http.Client();
      try {
        developer.log('检查连接 - 开始发送请求...', name: 'AiEnhanceService');

        final stopwatch = Stopwatch()..start();
        final response = await client
            .post(uri, headers: headers, body: body)
            .timeout(_timeout);
        stopwatch.stop();

        developer.log(
          '检查连接 - 收到响应: ${response.statusCode}, 耗时: ${stopwatch.elapsedMilliseconds}ms',
          name: 'AiEnhanceService',
        );
        developer.log(
          '检查连接 - 响应体长度: ${response.body.length}',
          name: 'AiEnhanceService',
        );

        // 解析响应
        final jsonBody = json.decode(response.body) as Map<String, dynamic>;

        if (response.statusCode == 200) {
          final choices = jsonBody['choices'] as List<dynamic>?;
          if (choices != null && choices.isNotEmpty) {
            return AiConnectionCheckResult(
              ok: true,
              message: '连接成功 (${uri.host})',
            );
          }
          return const AiConnectionCheckResult(
            ok: false,
            message: '接口返回异常：未找到choices',
          );
        }

        // 处理错误响应
        final error = jsonBody['error'] as Map<String, dynamic>?;
        if (error != null) {
          final errorMsg = error['message'] as String? ?? '未知错误';
          final errorCode = error['code'] as String?;

          if (response.statusCode == 401 || errorCode == 'invalid_api_key') {
            return AiConnectionCheckResult(
              ok: false,
              message: 'API密钥无效: $errorMsg',
            );
          }

          return AiConnectionCheckResult(
            ok: false,
            message: 'API错误: $errorMsg',
          );
        }

        final message = jsonBody['message'] as String?;
        if (message != null) {
          return AiConnectionCheckResult(
            ok: false,
            message: message,
          );
        }

        return AiConnectionCheckResult(
          ok: false,
          message: '接口返回错误 ${response.statusCode}',
        );
      } on TimeoutException catch (e) {
        developer.log('检查连接 - 第 $attempt 次超时: $e', name: 'AiEnhanceService');
        if (attempt == 2) {
          return AiConnectionCheckResult(
            ok: false,
            message: '请求超时 (${_timeout.inSeconds}秒)，请检查：\n'
                '1. 网络连接是否正常\n'
                '2. API端点是否正确\n'
                '3. 是否使用了代理/VPN',
          );
        }
        // 重试前等待
        await Future.delayed(const Duration(seconds: 1));
      } on SocketException catch (e) {
        developer.log('检查连接 - 网络错误: $e', name: 'AiEnhanceService');
        return AiConnectionCheckResult(
          ok: false,
          message: '网络连接失败: ${e.message}\n'
              '请检查网络连接和DNS设置',
        );
      } on FormatException catch (e) {
        developer.log('检查连接 - 格式异常: $e', name: 'AiEnhanceService');
        return AiConnectionCheckResult(
          ok: false,
          message: '响应解析失败: $e',
        );
      } catch (e) {
        developer.log('检查连接 - 其他异常: $e', name: 'AiEnhanceService');
        if (attempt == 2) {
          return AiConnectionCheckResult(
            ok: false,
            message: '连接失败: $e',
          );
        }
        // 重试前等待
        await Future.delayed(const Duration(seconds: 1));
      } finally {
        client.close();
      }
    }

    return const AiConnectionCheckResult(
      ok: false,
      message: '连接失败：所有重试都失败了',
    );
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
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    final apiKey = config.apiKey.trim();
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    return headers;
  }

  String _extractContent(String responseBody, String fallbackText) {
    final jsonBody = json.decode(responseBody) as Map<String, dynamic>;

    final choices = jsonBody['choices'] as List<dynamic>?;
    if (choices != null && choices.isNotEmpty) {
      final message = choices.first['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;
      return content?.trim().isNotEmpty == true
          ? content!.trim()
          : fallbackText;
    }

    return fallbackText;
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
