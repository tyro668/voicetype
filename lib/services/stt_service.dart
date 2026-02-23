import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/provider_config.dart';
import 'log_service.dart';
import 'network_client_service.dart';

class SttService {
  final SttProviderConfig config;

  SttService(this.config);

  String? _apiKeyValidationMessage() {
    final apiKey = config.apiKey.trim();
    if (apiKey.isEmpty) {
      return 'API密钥为空，请先填写 API Key';
    }
    if (apiKey.startsWith('ENC:')) {
      return 'API密钥解密失败，请重新输入 API Key';
    }
    return null;
  }

  String _resolvedModel() {
    final model = config.model.trim();
    if (!_isAliyunCompatibleMode()) {
      return model;
    }

    final canonical = model.toLowerCase().replaceAll('_', '-');
    switch (canonical) {
      case 'qwen3-asr-flash':
      case 'qwen-asr-flash':
      case 'qwen3asrflash':
        return 'qwen3-asr-flash';
      default:
        return canonical;
    }
  }

  /// 使用 OpenAI 兼容的 /audio/transcriptions 接口
  /// 与 Z.ai 保持一致，所有云端模型都走标准 OpenAI 接口
  Future<String> transcribe(String audioPath) async {
    final resolvedModel = _resolvedModel();
    await LogService.info(
      'STT',
      'start transcribe provider=${config.name} model=${config.model} resolvedModel=$resolvedModel baseUrl=${config.baseUrl} file=$audioPath',
    );

    final apiKeyError = _apiKeyValidationMessage();
    if (apiKeyError != null) {
      await LogService.error('STT', 'api key validation failed: $apiKeyError');
      throw SttException(apiKeyError);
    }

    // 所有云端服务统一走标准 OpenAI 接口
    return _transcribeOpenAI(audioPath, resolvedModel);
  }

  /// 标准 OpenAI /audio/transcriptions 接口
  Future<String> _transcribeOpenAI(String audioPath, String model) async {
    final uri = Uri.parse('${config.baseUrl}/audio/transcriptions');
    await LogService.info('STT', 'POST $uri');

    final request = http.MultipartRequest('POST', uri);

    if (config.apiKey.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${config.apiKey}';
    }

    request.fields['model'] = model;
    request.fields['response_format'] = 'json';

    request.files.add(await http.MultipartFile.fromPath('file', audioPath));

    http.Response response;
    final client = NetworkClientService.createClient();
    try {
      final streamedResponse = await client
          .send(request)
          .timeout(const Duration(seconds: 120));
      response = await http.Response.fromStream(streamedResponse);
    } on TimeoutException {
      client.close();
      if (_isAliyunCompatibleMode()) {
        await LogService.info(
          'STT',
          'fallback to aliyun chat/completions because /audio/transcriptions timeout',
        );
        return _transcribeAliyunCompatibleFallback(audioPath);
      }
      rethrow;
    } on SocketException catch (e) {
      client.close();
      if (_isAliyunCompatibleMode()) {
        await LogService.info(
          'STT',
          'fallback to aliyun chat/completions because /audio/transcriptions socket error: ${e.message}',
        );
        return _transcribeAliyunCompatibleFallback(audioPath);
      }
      rethrow;
    } on http.ClientException catch (e) {
      client.close();
      if (_isAliyunCompatibleMode()) {
        await LogService.info(
          'STT',
          'fallback to aliyun chat/completions because /audio/transcriptions client error: ${e.message}',
        );
        return _transcribeAliyunCompatibleFallback(audioPath);
      }
      rethrow;
    } finally {
      client.close();
    }

    await LogService.info(
      'STT',
      'transcribe response status=${response.statusCode} bodyLength=${response.body.length}',
    );

    if (response.statusCode == 200) {
      final text = _extractTranscriptionText(response.body);
      await LogService.info(
        'STT',
        'transcribe success textLength=${text.length}',
      );
      return text;
    } else if (response.statusCode == 404 && _isAliyunCompatibleMode()) {
      await LogService.info(
        'STT',
        'fallback to aliyun chat/completions because /audio/transcriptions returns 404',
      );
      return _transcribeAliyunCompatibleFallback(audioPath);
    } else if (response.statusCode >= 500 && _isAliyunCompatibleMode()) {
      await LogService.info(
        'STT',
        'fallback to aliyun chat/completions because /audio/transcriptions returns ${response.statusCode}',
      );
      return _transcribeAliyunCompatibleFallback(audioPath);
    } else {
      final message = _buildTranscribeErrorMessage(
        response.statusCode,
        response.body,
      );
      await LogService.error('STT', message);
      throw SttException(message);
    }
  }

  bool _isAliyunCompatibleMode() {
    final baseUrl = config.baseUrl.toLowerCase();
    return baseUrl.contains('dashscope.aliyuncs.com/compatible-mode/v1') ||
        baseUrl.contains('dashscope-intl.aliyuncs.com/compatible-mode/v1') ||
        baseUrl.contains('dashscope-us.aliyuncs.com/compatible-mode/v1');
  }

  Future<String> _transcribeAliyunCompatibleFallback(String audioPath) async {
    final uri = Uri.parse('${config.baseUrl}/chat/completions');
    await LogService.info('STT', 'POST $uri (aliyun fallback)');

    final bytes = await File(audioPath).readAsBytes();
    final base64Audio = base64Encode(bytes);

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (config.apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${config.apiKey}';
    }

    final body = json.encode({
      'model': _resolvedModel(),
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

    final client = NetworkClientService.createClient();
    final response = await client
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 120));
    client.close();

    await LogService.info(
      'STT',
      'aliyun fallback response status=${response.statusCode} bodyLength=${response.body.length}',
    );

    if (response.statusCode != 200) {
      final message = _buildTranscribeErrorMessage(
        response.statusCode,
        response.body,
      );
      await LogService.error('STT', message);
      throw SttException(message);
    }

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
          if (text != null && text.trim().isNotEmpty) {
            return text.trim();
          }
        }
      }
    }

    return '';
  }

  String _extractTranscriptionText(String responseBody) {
    try {
      final body = json.decode(responseBody);
      if (body is Map<String, dynamic>) {
        final text = body['text']?.toString();
        if (text != null && text.trim().isNotEmpty) {
          return text.trim();
        }

        final transcript = body['transcript']?.toString();
        if (transcript != null && transcript.trim().isNotEmpty) {
          return transcript.trim();
        }

        final result = body['result'];
        if (result is String && result.trim().isNotEmpty) {
          return result.trim();
        }
      }
    } catch (_) {}

    return '';
  }

  String _buildTranscribeErrorMessage(int statusCode, String responseBody) {
    try {
      final body = json.decode(responseBody);
      if (body is Map<String, dynamic>) {
        final error = body['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message']?.toString();
          if (message != null && message.isNotEmpty) {
            return '转录失败 ($statusCode): $message';
          }
        }

        final message = body['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return '转录失败 ($statusCode): $message';
        }
      }
    } catch (_) {}

    return '转录失败 ($statusCode): $responseBody';
  }

  /// 检查服务是否可用（简单版本）
  Future<bool> checkAvailability() async {
    final result = await checkAvailabilityDetailed();
    return result.ok;
  }

  /// 检查服务是否可用（详细版本，返回错误信息）
  /// 所有接口统一使用 /models GET 端点检查连通性和认证
  Future<SttConnectionCheckResult> checkAvailabilityDetailed() async {
    await LogService.info(
      'STT',
      'checkAvailability provider=${config.name} model=${config.model} baseUrl=${config.baseUrl}',
    );

    final apiKeyError = _apiKeyValidationMessage();
    if (apiKeyError != null) {
      await LogService.error('STT', 'checkAvailability failed: $apiKeyError');
      return SttConnectionCheckResult(ok: false, message: apiKeyError);
    }

    try {
      return await _checkModelsEndpoint();
    } on TimeoutException {
      await LogService.error('STT', 'checkAvailability timeout');
      return const SttConnectionCheckResult(ok: false, message: '请求超时，请检查网络连接');
    } on SocketException catch (e) {
      await LogService.error(
        'STT',
        'checkAvailability socket error: ${e.message}',
      );
      return SttConnectionCheckResult(
        ok: false,
        message: '网络连接失败: ${e.message}',
      );
    } catch (e) {
      await LogService.error('STT', 'checkAvailability error: $e');
      return SttConnectionCheckResult(ok: false, message: '连接失败: $e');
    }
  }

  /// 使用 /models 端点检查连通性（轻量级 GET 请求，不触发模型推理）
  Future<SttConnectionCheckResult> _checkModelsEndpoint() async {
    final uri = Uri.parse('${config.baseUrl}/models');
    await LogService.info('STT', 'GET $uri');
    final client = NetworkClientService.createClient();
    final response = await client
        .get(
          uri,
          headers: config.apiKey.isNotEmpty
              ? {'Authorization': 'Bearer ${config.apiKey}'}
              : null,
        )
        .timeout(const Duration(seconds: 15));
    client.close();

    await LogService.info(
      'STT',
      '/models response status=${response.statusCode} bodyLength=${response.body.length}',
    );

    if (response.statusCode == 200) {
      return SttConnectionCheckResult(ok: true, message: '连接成功 (${uri.host})');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      // 尝试解析详细错误信息
      try {
        final jsonBody = json.decode(response.body) as Map<String, dynamic>;
        final error = jsonBody['error'] as Map<String, dynamic>?;
        final errorMsg =
            error?['message'] as String? ??
            jsonBody['message'] as String? ??
            '认证失败';
        return SttConnectionCheckResult(
          ok: false,
          message: 'API密钥无效: $errorMsg',
        );
      } catch (_) {
        return SttConnectionCheckResult(
          ok: false,
          message: 'API密钥无效 (${response.statusCode})',
        );
      }
    }

    // 404/405 说明服务端可达但不支持 /models 端点，仍视为连接成功
    if (response.statusCode == 404 || response.statusCode == 405) {
      return SttConnectionCheckResult(ok: true, message: '连接成功 (${uri.host})');
    }

    return SttConnectionCheckResult(
      ok: false,
      message: '接口返回错误 ${response.statusCode}',
    );
  }
}

/// STT 服务连接检查结果
class SttConnectionCheckResult {
  final bool ok;
  final String message;

  const SttConnectionCheckResult({required this.ok, required this.message});
}

class SttException implements Exception {
  final String message;
  SttException(this.message);

  @override
  String toString() => message;
}
