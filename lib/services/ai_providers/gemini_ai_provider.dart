import 'openai_compatible_ai_provider.dart';

/// Google Gemini AI Provider。
///
/// baseUrl 为 Gemini 原生端点 `/v1beta`，内部拼接 `/openai` 走 OpenAI 兼容层。
/// 未来可 override [enhance] / [enhanceStream] 切换为原生 `generateContent` API。
class GeminiAiProvider extends OpenAiCompatibleAiProvider {
  GeminiAiProvider(super.config);

  /// 获取 OpenAI 兼容层的 baseUrl。
  /// 如果用户配置的 baseUrl 已经以 /openai 结尾，直接使用；
  /// 否则自动追加 /openai。
  String get _openAiBaseUrl {
    final base = normalizeBaseUrl(config.baseUrl);
    if (base.endsWith('/openai')) return base;
    return '$base/openai';
  }

  @override
  String get chatCompletionsUrl => '$_openAiBaseUrl/chat/completions';

  @override
  String get modelsUrl => '$_openAiBaseUrl/models';
}
