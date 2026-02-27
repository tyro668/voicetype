import '../models/ai_enhance_config.dart';
import '../models/dictionary_entry.dart';
import 'ai_enhance_service.dart';
import 'correction_context.dart';
import 'log_service.dart';
import 'pinyin_matcher.dart';
import 'token_stats_service.dart';

/// 纠错结果
class CorrectionResult {
  /// 纠错后的文本
  final String text;

  /// 是否实际调用了 LLM（false 表示跳过纠错直接返回原文）
  final bool llmInvoked;

  /// LLM 消耗的 token 数量
  final int promptTokens;
  final int completionTokens;

  const CorrectionResult({
    required this.text,
    this.llmInvoked = false,
    this.promptTokens = 0,
    this.completionTokens = 0,
  });

  int get totalTokens => promptTokens + completionTokens;
}

/// 语音输入纠错服务。
///
/// 核心流程：
/// 1. 对 ASR 原始文本用 [PinyinMatcher] 检索匹配的词典条目
/// 2. 若无匹配 → 跳过 LLM，Token 消耗 = 0
/// 3. 若有匹配 → 构建 #R/#I/#C 符号化协议，调用 LLM 进行纠错
/// 4. 更新 [CorrectionContext] 上下文窗口
class CorrectionService {
  final PinyinMatcher matcher;
  final CorrectionContext context;
  final AiEnhanceConfig aiConfig;
  final String correctionPrompt;

  CorrectionService({
    required this.matcher,
    required this.context,
    required this.aiConfig,
    required this.correctionPrompt,
  });

  /// 对 ASR 原始文本执行纠错。
  ///
  /// 若词典中无匹配条目，直接返回原文不调用 LLM。
  Future<CorrectionResult> correct(String rawSttText) async {
    if (rawSttText.trim().isEmpty) {
      return CorrectionResult(text: rawSttText);
    }

    try {
      // 1. 拼音模糊匹配
      final matches = matcher.findMatches(rawSttText);

      if (matches.isEmpty) {
        // 无匹配 → 跳过 LLM，直接输出
        await LogService.info(
          'CORRECTION',
          'no dictionary matches, skipping LLM',
        );
        context.addSegment(rawSttText);
        return CorrectionResult(text: rawSttText);
      }

      await LogService.info(
        'CORRECTION',
        'found ${matches.length} dictionary matches',
      );

      // 2. 构建 #R 引用表
      final referenceStr = _buildReferenceString(matches);

      // 3. 构建完整 prompt 消息
      final userMessage = _buildUserMessage(
        reference: referenceStr,
        input: rawSttText,
        contextStr: context.getContextString(),
      );

      // 4. 调用 LLM
      final correctionConfig = aiConfig.copyWith(prompt: correctionPrompt);
      final enhancer = AiEnhanceService(correctionConfig);

      final result = await enhancer.enhance(userMessage);
      var correctedText = result.text.trim();

      // 安全校验：若 LLM 返回空，退回原文
      if (correctedText.isEmpty) {
        correctedText = rawSttText;
      }

      // 5. 记录 Token 消耗
      if (result.totalTokens > 0) {
        try {
          await TokenStatsService.instance.addTokens(
            promptTokens: result.promptTokens,
            completionTokens: result.completionTokens,
          );
        } catch (_) {}
      }

      // 6. 更新上下文
      context.addSegment(correctedText);

      await LogService.info(
        'CORRECTION',
        'corrected: ${rawSttText.length} → ${correctedText.length} chars, '
            'tokens: ${result.totalTokens}',
      );

      return CorrectionResult(
        text: correctedText,
        llmInvoked: true,
        promptTokens: result.promptTokens,
        completionTokens: result.completionTokens,
      );
    } catch (e) {
      await LogService.error('CORRECTION', 'correction failed: $e');
      // 纠错失败不影响主流程，退回原文
      context.addSegment(rawSttText);
      return CorrectionResult(text: rawSttText);
    }
  }

  /// 构建 #R 引用表字符串。
  ///
  /// 格式：`错词->正词|错词2->正词2`
  /// - correction 类型：`original->corrected`
  /// - preserve 类型：`original->original`（保持原样）
  String _buildReferenceString(List<DictionaryEntry> matches) {
    final parts = <String>[];
    for (final entry in matches) {
      if (entry.type == DictionaryEntryType.correction) {
        parts.add('${entry.original}->${entry.corrected}');
      } else {
        // preserve 类型：告知 LLM 保持原样
        parts.add('${entry.original}->${entry.original}');
      }
    }
    return parts.join('|');
  }

  /// 构建用于纠错的 user message（#R/#I/#C 符号化协议）。
  String _buildUserMessage({
    required String reference,
    required String input,
    required String contextStr,
  }) {
    final buf = StringBuffer();
    buf.writeln('#R: $reference');
    if (contextStr.isNotEmpty) {
      buf.writeln('#C: $contextStr');
    }
    buf.writeln('#I: $input');
    return buf.toString().trim();
  }
}
