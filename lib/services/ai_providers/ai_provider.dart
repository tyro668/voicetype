import '../../models/ai_enhance_config.dart';

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

/// AI 服务连接检查结果
class AiConnectionCheckResult {
  final bool ok;
  final String message;

  const AiConnectionCheckResult({required this.ok, required this.message});
}

/// AI 增强服务异常
class AiEnhanceException implements Exception {
  final String message;
  AiEnhanceException(this.message);

  @override
  String toString() => message;
}

/// AI Provider 抽象基类。
///
/// 每个厂商实现自己的 [enhance] / [enhanceStream] / [checkAvailabilityDetailed]。
abstract class AiProvider {
  final AiEnhanceConfig config;

  AiProvider(this.config);

  /// 批量增强文本。
  Future<AiEnhanceResult> enhance(String text, {Duration? timeout});

  /// 流式增强文本（SSE）。
  Stream<String> enhanceStream(String text, {Duration? timeout});

  /// 检查服务是否可用（详细版本）。
  Future<AiConnectionCheckResult> checkAvailabilityDetailed();

  // ─── 共享工具方法 ───

  /// 去除尾部斜杠的标准化 baseUrl。
  String normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  /// 构建认证 headers。
  Map<String, String> buildHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final apiKey = config.apiKey.trim();
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    return headers;
  }

  /// 校验 API Key，返回 null 表示通过。
  String? apiKeyValidationMessage() {
    final apiKey = config.apiKey.trim();
    if (apiKey.isEmpty) {
      return 'API密钥为空，请先填写 API Key';
    }
    if (apiKey.startsWith('ENC:')) {
      return 'API密钥解密失败，请重新输入 API Key';
    }
    return null;
  }

  /// 解析有效的 prompt（空则用默认值），并替换 agentName 占位符。
  String resolvePrompt() {
    return (config.prompt.trim().isEmpty
            ? AiEnhanceConfig.defaultPrompt
            : config.prompt)
        .replaceAll('{agentName}', config.agentName);
  }

  /// 构建用于 AI 增强的 user message。
  String buildEnhanceUserMessage(String text) {
    return '''
请严格根据 system 提示词对以下文本做优化。
仅输出优化后的文本本身，不要添加解释、前后缀或引号。

<source>
$text
</source>
''';
  }

  /// 过滤通用/无意义的回复（如"谢谢"、"ok"）。
  String sanitizeEnhancedText(String text) {
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

  /// 校验 baseUrl 是否为有效的 http/https URL。
  bool isValidBaseUrl(String baseUrl) {
    try {
      final uri = Uri.parse(baseUrl);
      return (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// 从 OpenAI 格式的 JSON 响应中提取 content 文本。
  String extractContentFromJson(
    Map<String, dynamic> jsonBody,
    String fallbackText,
  ) {
    final choices = jsonBody['choices'] as List<dynamic>?;
    if (choices != null && choices.isNotEmpty) {
      final message = choices.first['message'] as Map<String, dynamic>?;
      final content = _readMessageContent(message?['content']);
      if (content.isEmpty) return fallbackText;
      final cleaned = sanitizeEnhancedText(content);
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
}
