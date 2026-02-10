import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/provider_config.dart';

class SttService {
  final SttProviderConfig config;

  SttService(this.config);

  /// 使用 OpenAI 兼容的 /audio/transcriptions 接口
  Future<String> transcribe(String audioPath) async {
    if (_isDashscopeCompatible()) {
      return _transcribeDashscope(audioPath);
    }
    if (_isDashscopeNative()) {
      return _transcribeDashscopeSync(audioPath);
    }
    final uri = Uri.parse('${config.baseUrl}/audio/transcriptions');

    final request = http.MultipartRequest('POST', uri);

    if (config.apiKey.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${config.apiKey}';
    }

    request.fields['model'] = config.model;
    request.fields['response_format'] = 'json';
    request.fields['language'] = 'zh';

    request.files.add(await http.MultipartFile.fromPath('file', audioPath));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 120),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      return body['text'] ?? '';
    } else {
      throw SttException('转录失败 (${response.statusCode}): ${response.body}');
    }
  }

  bool _isDashscopeCompatible() {
    return config.baseUrl.contains(
          'dashscope.aliyuncs.com/compatible-mode/v1',
        ) ||
        config.baseUrl.contains(
          'dashscope-intl.aliyuncs.com/compatible-mode/v1',
        ) ||
        config.baseUrl.contains('dashscope-us.aliyuncs.com/compatible-mode/v1');
  }

  bool _isDashscopeNative() {
    return config.baseUrl.contains('dashscope.aliyuncs.com/api/v1') ||
        config.baseUrl.contains('dashscope-intl.aliyuncs.com/api/v1') ||
        config.baseUrl.contains('dashscope-us.aliyuncs.com/api/v1');
  }

  Future<String> _transcribeDashscope(String audioPath) async {
    final uri = Uri.parse('${config.baseUrl}/chat/completions');
    final bytes = await File(audioPath).readAsBytes();
    final base64Audio = base64Encode(bytes);

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (config.apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${config.apiKey}';
    }

    final body = json.encode({
      'model': config.model,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'input_audio',
              'input_audio': {'data': 'data:audio/wav;base64,$base64Audio'},
            },
          ],
        },
      ],
      'stream': false,
      'asr_options': {'enable_itn': false},
    });

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 120));

    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body) as Map<String, dynamic>;
      final choices = jsonBody['choices'] as List<dynamic>?;
      final message = choices?.isNotEmpty == true
          ? choices!.first['message'] as Map<String, dynamic>?
          : null;
      final content = message?['content'];

      if (content is String) {
        return content.trim();
      }

      if (content is List) {
        for (final item in content) {
          if (item is Map<String, dynamic> && item['type'] == 'text') {
            final text = item['text']?.toString();
            if (text != null) {
              return text.trim();
            }
          }
        }
      }

      return '';
    }

    throw SttException('转录失败 (${response.statusCode}): ${response.body}');
  }

  String _dashscopeApiBaseUrl() {
    if (config.baseUrl.contains('/compatible-mode/v1')) {
      return config.baseUrl.replaceFirst('/compatible-mode/v1', '/api/v1');
    }
    return config.baseUrl;
  }

  Future<String> _transcribeDashscopeSync(String audioPath) async {
    final uri = Uri.parse(
      '${_dashscopeApiBaseUrl()}/services/aigc/multimodal-generation/generation',
    );
    final bytes = await File(audioPath).readAsBytes();
    final base64Audio = base64Encode(bytes);
    final format = _inferAudioFormat(audioPath);

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (config.apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${config.apiKey}';
    }

    final parameters = <String, dynamic>{'result_format': 'message'};
    if (config.model == 'qwen3-asr-flash') {
      parameters['asr_options'] = {'enable_itn': false};
    }

    final body = json.encode({
      'model': config.model,
      'input': {
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'audio': {
                  'data': base64Audio,
                  if (format.isNotEmpty) 'format': format,
                },
              },
            ],
          },
        ],
      },
      'parameters': parameters,
    });

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 120));

    if (response.statusCode == 200) {
      final jsonBody = json.decode(response.body) as Map<String, dynamic>;
      final output = jsonBody['output'] as Map<String, dynamic>?;
      final choices = output?['choices'] as List<dynamic>?;
      final message = choices?.isNotEmpty == true
          ? choices!.first['message'] as Map<String, dynamic>?
          : null;
      return _extractDashscopeContent(message?['content']);
    }

    throw SttException('转录失败 (${response.statusCode}): ${response.body}');
  }

  String _extractDashscopeContent(dynamic content) {
    if (content is String) {
      return content.trim();
    }
    if (content is List) {
      for (final item in content) {
        if (item is Map<String, dynamic> && item['text'] != null) {
          return item['text'].toString().trim();
        }
      }
    }
    return '';
  }

  String _inferAudioFormat(String audioPath) {
    final lower = audioPath.toLowerCase();
    final extIndex = lower.lastIndexOf('.');
    if (extIndex == -1) return '';
    final ext = lower.substring(extIndex + 1);
    if (ext == 'm4a' || ext == 'mp3' || ext == 'wav' || ext == 'flac') {
      return ext;
    }
    return '';
  }

  /// 检查服务是否可用
  Future<bool> checkAvailability() async {
    try {
      if (_isDashscopeCompatible() || _isDashscopeNative()) {
        final primaryUri = _isDashscopeCompatible()
            ? Uri.parse('${config.baseUrl}/models')
            : Uri.parse('${_dashscopeApiBaseUrl()}/models');
        final fallbackUri = _isDashscopeCompatible()
            ? Uri.parse('${_dashscopeApiBaseUrl()}/models')
            : Uri.parse('${config.baseUrl}/models');
        final headers = config.apiKey.isNotEmpty
            ? {'Authorization': 'Bearer ${config.apiKey}'}
            : null;
        final response = await _checkDashscopeEndpoint(primaryUri, headers);
        if (response != null) {
          return response;
        }
        final fallbackResponse = await _checkDashscopeEndpoint(
          fallbackUri,
          headers,
        );
        return fallbackResponse ?? false;
      }
      final uri = Uri.parse('${config.baseUrl}/models');
      debugPrint('[stt] check url=$uri');
      final response = await http
          .get(
            uri,
            headers: config.apiKey.isNotEmpty
                ? {'Authorization': 'Bearer ${config.apiKey}'}
                : null,
          )
          .timeout(const Duration(seconds: 5));
      debugPrint(
        '[stt] check status=${response.statusCode} body=${response.body}',
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[stt] check failed: $e');
      return false;
    }
  }

  Future<bool?> _checkDashscopeEndpoint(
    Uri uri,
    Map<String, String>? headers,
  ) async {
    debugPrint('[stt] dashscope check url=$uri');
    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));
      debugPrint(
        '[stt] dashscope check status=${response.statusCode} body=${response.body}',
      );
      return response.statusCode == 200 ||
          response.statusCode == 401 ||
          response.statusCode == 403 ||
          response.statusCode == 404 ||
          response.statusCode == 405;
    } on TimeoutException catch (e) {
      debugPrint('[stt] dashscope check timeout: $e');
      return null;
    }
  }
}

class SttException implements Exception {
  final String message;
  SttException(this.message);

  @override
  String toString() => message;
}
