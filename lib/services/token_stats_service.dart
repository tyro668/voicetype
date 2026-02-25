import '../database/app_database.dart';

/// 持久化累计 AI 增强 token 用量。
class TokenStatsService {
  TokenStatsService._();
  static final instance = TokenStatsService._();

  static const _keyPromptTokens = 'ai_enhance_prompt_tokens';
  static const _keyCompletionTokens = 'ai_enhance_completion_tokens';

  static const _keyMeetingPromptTokens = 'meeting_enhance_prompt_tokens';
  static const _keyMeetingCompletionTokens = 'meeting_enhance_completion_tokens';

  final _db = AppDatabase.instance;

  /// 累加本次增强消耗的 token 数（语音输入）。
  Future<void> addTokens({
    required int promptTokens,
    required int completionTokens,
  }) async {
    final current = await getTokens();
    await _db.setSetting(
      _keyPromptTokens,
      (current.promptTokens + promptTokens).toString(),
    );
    await _db.setSetting(
      _keyCompletionTokens,
      (current.completionTokens + completionTokens).toString(),
    );
  }

  /// 读取累计 token 数（语音输入）。
  Future<({int promptTokens, int completionTokens})> getTokens() async {
    final p = int.tryParse(await _db.getSetting(_keyPromptTokens) ?? '') ?? 0;
    final c =
        int.tryParse(await _db.getSetting(_keyCompletionTokens) ?? '') ?? 0;
    return (promptTokens: p, completionTokens: c);
  }

  /// 累加会议记录 AI 增强消耗的 token 数。
  Future<void> addMeetingTokens({
    required int promptTokens,
    required int completionTokens,
  }) async {
    final current = await getMeetingTokens();
    await _db.setSetting(
      _keyMeetingPromptTokens,
      (current.promptTokens + promptTokens).toString(),
    );
    await _db.setSetting(
      _keyMeetingCompletionTokens,
      (current.completionTokens + completionTokens).toString(),
    );
  }

  /// 读取累计会议记录 token 数。
  Future<({int promptTokens, int completionTokens})> getMeetingTokens() async {
    final p = int.tryParse(await _db.getSetting(_keyMeetingPromptTokens) ?? '') ?? 0;
    final c =
        int.tryParse(await _db.getSetting(_keyMeetingCompletionTokens) ?? '') ?? 0;
    return (promptTokens: p, completionTokens: c);
  }
}
