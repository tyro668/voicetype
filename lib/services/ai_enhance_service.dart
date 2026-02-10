import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ai_enhance_config.dart';

class AiEnhanceService {
  static const _timeout = Duration(seconds: 15);

  final AiEnhanceConfig config;

  AiEnhanceService(this.config);

  Future<String> enhance(String text) async {
    if (text.trim().isEmpty) return text;

    final resolvedPrompt = config.prompt.replaceAll(
      '{agentName}',
      config.agentName,
    );
    final uri = Uri.parse('${config.baseUrl}/chat/completions');
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw AiEnhanceException('AI增强失败: 无效的端点 URL');
    }
    debugPrint(
      '[ai-enhance] request start url=${uri.host} model=${config.model}',
    );
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (config.apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${config.apiKey}';
    }

    final body = json.encode({
      'model': config.model,
      'temperature': 0.2,
      'messages': [
        {'role': 'system', 'content': resolvedPrompt},
        {'role': 'user', 'content': text},
      ],
    });

    // Use a dedicated client so we can force-close the underlying socket on
    // timeout instead of leaving a dangling connection.
    final client = http.Client();
    http.Response response;
    try {
      response = await client
          .post(uri, headers: headers, body: body)
          .timeout(_timeout);
    } on TimeoutException {
      client.close();
      debugPrint('[ai-enhance] timeout after ${_timeout.inSeconds}s');
      throw AiEnhanceException('AI增强失败: 请求超时');
    } catch (e) {
      client.close();
      debugPrint('[ai-enhance] request failed: $e');
      throw AiEnhanceException('AI增强失败: $e');
    } finally {
      client.close();
    }
    debugPrint('[ai-enhance] response status=${response.statusCode}');

    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body) as Map<String, dynamic>;
      final choices = jsonBody['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        final message = choices.first['message'] as Map<String, dynamic>?;
        final content = message?['content'] as String?;
        return content?.trim().isNotEmpty == true ? content!.trim() : text;
      }
      return text;
    }

    throw AiEnhanceException(
      'AI增强失败 (${response.statusCode}): ${response.body}',
    );
  }
}

class AiEnhanceException implements Exception {
  final String message;
  AiEnhanceException(this.message);

  @override
  String toString() => message;
}
