import '../database/app_database.dart';

/// 持久化纠错召回与 Token 指标，用于后续参数调优。
class CorrectionStatsService {
  CorrectionStatsService._();
  static final instance = CorrectionStatsService._();

  static const _keyCallsTotal = 'correction_calls_total';
  static const _keyLlmCallsTotal = 'correction_llm_calls_total';
  static const _keyMatchesTotal = 'correction_matches_total';
  static const _keySelectedTotal = 'correction_selected_total';
  static const _keyReferenceCharsTotal = 'correction_reference_chars_total';
  static const _keyPromptTokensTotal = 'correction_prompt_tokens_total';
  static const _keyCompletionTokensTotal = 'correction_completion_tokens_total';

  Future<void> recordCall({
    required int matchesCount,
    required int selectedCount,
    required int referenceChars,
    required bool llmInvoked,
    int promptTokens = 0,
    int completionTokens = 0,
  }) async {
    final db = await AppDatabase.getInstance();
    final snapshot = await getSnapshot();

    await db.setSetting(_keyCallsTotal, (snapshot.calls + 1).toString());
    await db.setSetting(
      _keyLlmCallsTotal,
      (snapshot.llmCalls + (llmInvoked ? 1 : 0)).toString(),
    );
    await db.setSetting(
      _keyMatchesTotal,
      (snapshot.matches + matchesCount).toString(),
    );
    await db.setSetting(
      _keySelectedTotal,
      (snapshot.selected + selectedCount).toString(),
    );
    await db.setSetting(
      _keyReferenceCharsTotal,
      (snapshot.referenceChars + referenceChars).toString(),
    );
    await db.setSetting(
      _keyPromptTokensTotal,
      (snapshot.promptTokens + promptTokens).toString(),
    );
    await db.setSetting(
      _keyCompletionTokensTotal,
      (snapshot.completionTokens + completionTokens).toString(),
    );
  }

  Future<CorrectionStatsSnapshot> getSnapshot() async {
    final db = await AppDatabase.getInstance();
    final calls = int.tryParse(await db.getSetting(_keyCallsTotal) ?? '') ?? 0;
    final llmCalls =
        int.tryParse(await db.getSetting(_keyLlmCallsTotal) ?? '') ?? 0;
    final matches =
        int.tryParse(await db.getSetting(_keyMatchesTotal) ?? '') ?? 0;
    final selected =
        int.tryParse(await db.getSetting(_keySelectedTotal) ?? '') ?? 0;
    final referenceChars =
        int.tryParse(await db.getSetting(_keyReferenceCharsTotal) ?? '') ?? 0;
    final promptTokens =
        int.tryParse(await db.getSetting(_keyPromptTokensTotal) ?? '') ?? 0;
    final completionTokens =
        int.tryParse(await db.getSetting(_keyCompletionTokensTotal) ?? '') ?? 0;

    return CorrectionStatsSnapshot(
      calls: calls,
      llmCalls: llmCalls,
      matches: matches,
      selected: selected,
      referenceChars: referenceChars,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    );
  }
}

class CorrectionStatsSnapshot {
  final int calls;
  final int llmCalls;
  final int matches;
  final int selected;
  final int referenceChars;
  final int promptTokens;
  final int completionTokens;

  const CorrectionStatsSnapshot({
    required this.calls,
    required this.llmCalls,
    required this.matches,
    required this.selected,
    required this.referenceChars,
    required this.promptTokens,
    required this.completionTokens,
  });
}
