import 'openai_stt_provider.dart';

/// Z.AI（智谱）STT Provider。
///
/// Z.AI 完全兼容 OpenAI /audio/transcriptions 标准接口。
class ZaiSttProvider extends OpenAiSttProvider {
  ZaiSttProvider(super.config);
}
