import 'openai_compatible_ai_provider.dart';

/// Z.AI（智谱）AI Provider。
///
/// 完全兼容 OpenAI `/chat/completions` 协议。
class ZaiAiProvider extends OpenAiCompatibleAiProvider {
  ZaiAiProvider(super.config);
}
