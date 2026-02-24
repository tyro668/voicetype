/// 时间趋势图的粒度。
enum TrendGranularity { day, week, month }

/// 时间趋势中的单个数据点。
class TrendDataPoint {
  /// 该时段的起始日期（天 = 当天 0:00，周 = 周一，月 = 1 号）。
  final DateTime date;

  /// 该时段内的转录次数。
  final int count;

  /// 该时段内的总录音时长（毫秒）。
  final int durationMs;

  /// 该时段内的总字数。
  final int charCount;

  const TrendDataPoint({
    required this.date,
    required this.count,
    required this.durationMs,
    required this.charCount,
  });
}

/// 仪表盘统计汇总数据。
class DashboardStats {
  // ── 核心汇总 ──
  final int totalCount;
  final int totalDurationMs;
  final int totalCharCount;
  final double avgCharsPerSession;
  final double avgDurationMs;

  // ── 今日 / 本周 / 本月 ──
  final int todayCount;
  final int todayDurationMs;
  final int todayChars;

  final int weekCount;
  final int weekDurationMs;
  final int weekChars;

  final int monthCount;
  final int monthDurationMs;
  final int monthChars;

  // ── 活跃度 ──
  final int currentStreak;
  final DateTime? lastTranscriptionAt;
  final DateTime? mostActiveDate;
  final int mostActiveDateCount;

  // ── 效率 ──
  final double avgCharsPerMinute;

  // ── 时间趋势 ──
  final List<TrendDataPoint> trendData;
  final TrendGranularity trendGranularity;

  // ── 分布 ──
  final Map<String, int> providerDistribution;
  final Map<String, int> modelDistribution;

  // ── AI 增强 token 用量 ──
  final int enhancePromptTokens;
  final int enhanceCompletionTokens;

  const DashboardStats({
    required this.totalCount,
    required this.totalDurationMs,
    required this.totalCharCount,
    required this.avgCharsPerSession,
    required this.avgDurationMs,
    required this.todayCount,
    required this.todayDurationMs,
    required this.todayChars,
    required this.weekCount,
    required this.weekDurationMs,
    required this.weekChars,
    required this.monthCount,
    required this.monthDurationMs,
    required this.monthChars,
    required this.currentStreak,
    this.lastTranscriptionAt,
    this.mostActiveDate,
    required this.mostActiveDateCount,
    required this.avgCharsPerMinute,
    required this.trendData,
    required this.trendGranularity,
    required this.providerDistribution,
    required this.modelDistribution,
    required this.enhancePromptTokens,
    required this.enhanceCompletionTokens,
  });

  /// 空状态。
  static const empty = DashboardStats(
    totalCount: 0,
    totalDurationMs: 0,
    totalCharCount: 0,
    avgCharsPerSession: 0,
    avgDurationMs: 0,
    todayCount: 0,
    todayDurationMs: 0,
    todayChars: 0,
    weekCount: 0,
    weekDurationMs: 0,
    weekChars: 0,
    monthCount: 0,
    monthDurationMs: 0,
    monthChars: 0,
    currentStreak: 0,
    mostActiveDateCount: 0,
    avgCharsPerMinute: 0,
    trendData: [],
    trendGranularity: TrendGranularity.day,
    providerDistribution: {},
    modelDistribution: {},
    enhancePromptTokens: 0,
    enhanceCompletionTokens: 0,
  );

  bool get isEmpty => totalCount == 0;

  int get enhanceTotalTokens => enhancePromptTokens + enhanceCompletionTokens;
}
