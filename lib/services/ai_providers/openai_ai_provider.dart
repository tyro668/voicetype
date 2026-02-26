import 'openai_compatible_ai_provider.dart';

/// OpenAI AI Provider。
///
/// 使用原生 OpenAI `/chat/completions` 接口。
class OpenAiAiProvider extends OpenAiCompatibleAiProvider {
  OpenAiAiProvider(super.config);
}
