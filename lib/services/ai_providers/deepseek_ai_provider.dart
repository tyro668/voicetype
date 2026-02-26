import 'openai_compatible_ai_provider.dart';

/// DeepSeek AI Provider。
///
/// 完全兼容 OpenAI `/chat/completions` 协议。
class DeepSeekAiProvider extends OpenAiCompatibleAiProvider {
  DeepSeekAiProvider(super.config);
}
