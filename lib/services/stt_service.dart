import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/provider_config.dart';

class SttService {
  final SttProviderConfig config;

  SttService(this.config);

  /// 使用 OpenAI 兼容的 /audio/transcriptions 接口
  Future<String> transcribe(String audioPath) async {
    final uri = Uri.parse('${config.baseUrl}/audio/transcriptions');

    final request = http.MultipartRequest('POST', uri);

    if (config.apiKey.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${config.apiKey}';
    }

    request.fields['model'] = config.model;
    request.fields['response_format'] = 'json';
    request.fields['language'] = 'zh';

    request.files.add(
      await http.MultipartFile.fromPath('file', audioPath),
    );

    final streamedResponse = await request.send().timeout(
          const Duration(seconds: 120),
        );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      return body['text'] ?? '';
    } else {
      throw SttException(
        '转录失败 (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// 检查服务是否可用
  Future<bool> checkAvailability() async {
    try {
      final uri = Uri.parse('${config.baseUrl}/models');
      final response = await http.get(
        uri,
        headers: config.apiKey.isNotEmpty
            ? {'Authorization': 'Bearer ${config.apiKey}'}
            : null,
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class SttException implements Exception {
  final String message;
  SttException(this.message);

  @override
  String toString() => message;
}
