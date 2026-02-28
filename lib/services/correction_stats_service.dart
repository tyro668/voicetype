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

  // ── 终态回溯 ──
  static const _keyRetroCalls = 'correction_retro_calls_total';
  static const _keyRetroLlmCalls = 'correction_retro_llm_calls_total';
  static const _keyRetroPromptTokens = 'correction_retro_prompt_tokens_total';
  static const _keyRetroCompletionTokens =
      'correction_retro_completion_tokens_total';
  static const _keyRetroTextChanged = 'correction_retro_text_changed_total';

  // ── SessionGlossary ──
  static const _keyGlossaryPins = 'glossary_pins_total';
  static const _keyGlossaryStrongPromotions =
      'glossary_strong_promotions_total';
  static const _keyGlossaryOverrides = 'glossary_overrides_total';
  static const _keyGlossaryInjections = 'glossary_injections_total';

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

  /// 记录一次终态回溯调用。
  Future<void> recordRetroCall({
    required bool llmInvoked,
    required bool textChanged,
    int promptTokens = 0,
    int completionTokens = 0,
  }) async {
    final db = await AppDatabase.getInstance();
    final snap = await getSnapshot();
    await db.setSetting(_keyRetroCalls, (snap.retroCalls + 1).toString());
    await db.setSetting(
      _keyRetroLlmCalls,
      (snap.retroLlmCalls + (llmInvoked ? 1 : 0)).toString(),
    );
    await db.setSetting(
      _keyRetroPromptTokens,
      (snap.retroPromptTokens + promptTokens).toString(),
    );
    await db.setSetting(
      _keyRetroCompletionTokens,
      (snap.retroCompletionTokens + completionTokens).toString(),
    );
    await db.setSetting(
      _keyRetroTextChanged,
      (snap.retroTextChanged + (textChanged ? 1 : 0)).toString(),
    );
  }

  /// 累加 SessionGlossary 会话统计到持久化计数器。
  Future<void> flushGlossaryStats({
    required int pins,
    required int strongPromotions,
    required int overrides,
    required int injections,
  }) async {
    if (pins == 0 &&
        strongPromotions == 0 &&
        overrides == 0 &&
        injections == 0) {
      return;
    }
    final db = await AppDatabase.getInstance();
    final snap = await getSnapshot();
    await db.setSetting(
      _keyGlossaryPins,
      (snap.glossaryPins + pins).toString(),
    );
    await db.setSetting(
      _keyGlossaryStrongPromotions,
      (snap.glossaryStrongPromotions + strongPromotions).toString(),
    );
    await db.setSetting(
      _keyGlossaryOverrides,
      (snap.glossaryOverrides + overrides).toString(),
    );
    await db.setSetting(
      _keyGlossaryInjections,
      (snap.glossaryInjections + injections).toString(),
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

    // ── 终态回溯 ──
    final retroCalls =
        int.tryParse(await db.getSetting(_keyRetroCalls) ?? '') ?? 0;
    final retroLlmCalls =
        int.tryParse(await db.getSetting(_keyRetroLlmCalls) ?? '') ?? 0;
    final retroPromptTokens =
        int.tryParse(await db.getSetting(_keyRetroPromptTokens) ?? '') ?? 0;
    final retroCompletionTokens =
        int.tryParse(await db.getSetting(_keyRetroCompletionTokens) ?? '') ?? 0;
    final retroTextChanged =
        int.tryParse(await db.getSetting(_keyRetroTextChanged) ?? '') ?? 0;

    // ── SessionGlossary ──
    final glossaryPins =
        int.tryParse(await db.getSetting(_keyGlossaryPins) ?? '') ?? 0;
    final glossaryStrongPromotions =
        int.tryParse(await db.getSetting(_keyGlossaryStrongPromotions) ?? '') ??
        0;
    final glossaryOverrides =
        int.tryParse(await db.getSetting(_keyGlossaryOverrides) ?? '') ?? 0;
    final glossaryInjections =
        int.tryParse(await db.getSetting(_keyGlossaryInjections) ?? '') ?? 0;

    return CorrectionStatsSnapshot(
      calls: calls,
      llmCalls: llmCalls,
      matches: matches,
      selected: selected,
      referenceChars: referenceChars,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      retroCalls: retroCalls,
      retroLlmCalls: retroLlmCalls,
      retroPromptTokens: retroPromptTokens,
      retroCompletionTokens: retroCompletionTokens,
      retroTextChanged: retroTextChanged,
      glossaryPins: glossaryPins,
      glossaryStrongPromotions: glossaryStrongPromotions,
      glossaryOverrides: glossaryOverrides,
      glossaryInjections: glossaryInjections,
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

  // ── 终态回溯 ──
  final int retroCalls;
  final int retroLlmCalls;
  final int retroPromptTokens;
  final int retroCompletionTokens;
  final int retroTextChanged;

  // ── SessionGlossary ──
  final int glossaryPins;
  final int glossaryStrongPromotions;
  final int glossaryOverrides;
  final int glossaryInjections;

  const CorrectionStatsSnapshot({
    required this.calls,
    required this.llmCalls,
    required this.matches,
    required this.selected,
    required this.referenceChars,
    required this.promptTokens,
    required this.completionTokens,
    this.retroCalls = 0,
    this.retroLlmCalls = 0,
    this.retroPromptTokens = 0,
    this.retroCompletionTokens = 0,
    this.retroTextChanged = 0,
    this.glossaryPins = 0,
    this.glossaryStrongPromotions = 0,
    this.glossaryOverrides = 0,
    this.glossaryInjections = 0,
  });
}
