import 'openai_compatible_ai_provider.dart';

/// Aliyun DashScope AI Provider。
///
/// 使用阿里云 `/compatible-mode/v1` 兼容层，完全兼容 OpenAI 协议。
class AliyunAiProvider extends OpenAiCompatibleAiProvider {
  AliyunAiProvider(super.config);
}
