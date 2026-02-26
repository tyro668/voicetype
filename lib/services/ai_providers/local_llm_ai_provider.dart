import '../local_llm_service.dart';
import '../log_service.dart';
import 'ai_provider.dart';

/// 本地 LLM AI Provider。
///
/// 通过 llamadart FFI 进行本地推理，不需要网络连接和 API Key。
class LocalLlmAiProvider extends AiProvider {
  LocalLlmAiProvider(super.config);

  @override
  Future<AiEnhanceResult> enhance(String text, {Duration? timeout}) async {
    if (text.trim().isEmpty) return AiEnhanceResult(text: text);

    await LogService.info(
      'AI',
      'start local enhance model=${config.model} textLength=${text.length}',
    );

    // 本地小模型使用专用的简洁提示词
    final localPrompt = await LocalLlmService.localPrompt;

    try {
      final result = await LocalLlmService.enhance(
        modelFileName: config.model,
        systemPrompt: localPrompt,
        userMessage: text,
      );

      final cleaned = sanitizeEnhancedText(result);
      final content = cleaned.isEmpty ? text : cleaned;

      await LogService.info(
        'AI',
        'local enhance success textLength=${content.length}',
      );

      return AiEnhanceResult(text: content);
    } catch (e) {
      await LogService.error('AI', 'local enhance failed: $e');
      throw AiEnhanceException('AI增强失败 (本地模型): $e');
    }
  }

  @override
  Stream<String> enhanceStream(String text, {Duration? timeout}) async* {
    // 本地模型不支持流式，回退到批量
    final result = await enhance(text, timeout: timeout);
    yield result.text;
  }

  @override
  Future<AiConnectionCheckResult> checkAvailabilityDetailed() async {
    await LogService.info(
      'AI',
      'checkAvailability local model=${config.model}',
    );
    final result = await LocalLlmService.checkAvailability(config.model);
    return AiConnectionCheckResult(ok: result.ok, message: result.message);
  }
}
