import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/dashboard_stats.dart';
import '../../services/dashboard_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardStats _stats = DashboardStats.empty;
  bool _loading = true;
  TrendGranularity _granularity = TrendGranularity.day;
  int _periodTab = 0; // 0 = today, 1 = week, 2 = month

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats({bool showLoading = true}) async {
    if (showLoading) setState(() => _loading = true);
    final stats = await DashboardService.instance.computeStats(
      granularity: _granularity,
    );
    if (mounted)
      setState(() {
        _stats = stats;
        if (showLoading) _loading = false;
      });
  }

  void _setGranularity(TrendGranularity g) {
    if (g == _granularity) return;
    _granularity = g;
    _loadStats(showLoading: false);
  }

  ColorScheme get _cs => Theme.of(context).colorScheme;
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _l10n.dashboard,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _stats.isEmpty
                ? _buildEmptyState()
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  // ─────────────── Empty State ───────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_rounded, size: 64, color: _cs.outlineVariant),
          const SizedBox(height: 16),
          Text(
            _l10n.noDataYet,
            style: TextStyle(fontSize: 15, color: _cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ─────────────── Main Content ───────────────

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 核心汇总
          _buildSummaryRow(),
          const SizedBox(height: 12),
          // 平均值
          _buildAverageRow(),
          const SizedBox(height: 20),
          // 今日 / 本周 / 本月
          _buildPeriodSection(),
          const SizedBox(height: 20),
          // 时间趋势
          _buildTrendSection(),
          const SizedBox(height: 20),
          // 分布
          _buildDistributionSection(),
          const SizedBox(height: 20),
          // 活跃度 + 效率
          _buildActivityAndEfficiencyRow(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─────────────── 核心汇总卡片 ───────────────

  Widget _buildSummaryRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.format_list_numbered,
            label: _l10n.totalTranscriptions,
            value: _formatNumber(_stats.totalCount),
            color: _cs.primary,
            cs: _cs,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.timer_outlined,
            label: _l10n.totalRecordingTime,
            value: _formatDuration(_stats.totalDurationMs),
            color: _cs.tertiary,
            cs: _cs,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.text_fields,
            label: _l10n.totalCharacters,
            value: _formatNumber(_stats.totalCharCount),
            color: _cs.secondary,
            cs: _cs,
          ),
        ),
      ],
    );
  }

  // ─────────────── 平均值卡片 ───────────────

  Widget _buildAverageRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.short_text,
            label: _l10n.avgCharsPerSession,
            value: _stats.avgCharsPerSession.toStringAsFixed(1),
            color: _cs.primary,
            cs: _cs,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.av_timer,
            label: _l10n.avgRecordingDuration,
            value: _formatDuration(_stats.avgDurationMs.round()),
            color: _cs.tertiary,
            cs: _cs,
          ),
        ),
        const SizedBox(width: 12),
        // 占位使三列对齐
        const Expanded(child: SizedBox()),
      ],
    );
  }

  // ─────────────── 今日 / 本周 / 本月 ───────────────

  Widget _buildPeriodSection() {
    final tabs = [_l10n.today, _l10n.thisWeek, _l10n.thisMonth];
    int count, durationMs, chars;
    switch (_periodTab) {
      case 1:
        count = _stats.weekCount;
        durationMs = _stats.weekDurationMs;
        chars = _stats.weekChars;
        break;
      case 2:
        count = _stats.monthCount;
        durationMs = _stats.monthDurationMs;
        chars = _stats.monthChars;
        break;
      default:
        count = _stats.todayCount;
        durationMs = _stats.todayDurationMs;
        chars = _stats.todayChars;
    }

    return _CardContainer(
      cs: _cs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<int>(
            segments: List.generate(
              tabs.length,
              (i) => ButtonSegment(value: i, label: Text(tabs[i])),
            ),
            selected: {_periodTab},
            onSelectionChanged: (s) => setState(() => _periodTab = s.first),
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(const TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MiniStat(
                label: _l10n.transcriptionCount,
                value: '$count',
                cs: _cs,
              ),
              const SizedBox(width: 32),
              _MiniStat(
                label: _l10n.recordingTime,
                value: _formatDuration(durationMs),
                cs: _cs,
              ),
              const SizedBox(width: 32),
              _MiniStat(
                label: _l10n.characters,
                value: _formatNumber(chars),
                cs: _cs,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────── 使用趋势图 ───────────────

  Widget _buildTrendSection() {
    final granLabels = {
      TrendGranularity.day: _l10n.day,
      TrendGranularity.week: _l10n.week,
      TrendGranularity.month: _l10n.month,
    };

    return _CardContainer(
      cs: _cs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _l10n.usageTrend,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _cs.onSurface,
                ),
              ),
              const Spacer(),
              SegmentedButton<TrendGranularity>(
                segments: TrendGranularity.values
                    .map(
                      (g) =>
                          ButtonSegment(value: g, label: Text(granLabels[g]!)),
                    )
                    .toList(),
                selected: {_granularity},
                onSelectionChanged: (s) => _setGranularity(s.first),
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                    const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(height: 200, child: _buildBarChart()),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final data = _stats.trendData;
    if (data.isEmpty) return const SizedBox();

    final maxY = data.fold<int>(0, (m, d) => d.count > m ? d.count : m);
    final effectiveMaxY = (maxY == 0 ? 5 : maxY) * 1.2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: effectiveMaxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIdx, rod, rodIdx) {
              final dp = data[groupIdx];
              return BarTooltipItem(
                '${_l10n.sessions(dp.count)}\n${_formatNumber(dp.charCount)} ${_l10n.characters}',
                TextStyle(color: _cs.onInverseSurface, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => value == meta.max
                  ? const SizedBox.shrink()
                  : Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        fontSize: 11,
                        color: _cs.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _formatTrendLabel(data[idx].date),
                    style: TextStyle(fontSize: 10, color: _cs.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: _cs.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(data.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: data[i].count.toDouble(),
                width: _granularity == TrendGranularity.month ? 20 : 14,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                color: _cs.primary,
              ),
            ],
          );
        }),
      ),
    );
  }

  String _formatTrendLabel(DateTime date) {
    switch (_granularity) {
      case TrendGranularity.day:
        return DateFormat('M/d').format(date);
      case TrendGranularity.week:
        return DateFormat('M/d').format(date);
      case TrendGranularity.month:
        return DateFormat('yyyy/M').format(date);
    }
  }

  // ─────────────── 分布饼图 ───────────────

  Widget _buildDistributionSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildPieCard(
            title: _l10n.providerDistribution,
            data: _stats.providerDistribution,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildPieCard(
            title: _l10n.modelDistribution,
            data: _stats.modelDistribution,
          ),
        ),
      ],
    );
  }

  Widget _buildPieCard({
    required String title,
    required Map<String, int> data,
  }) {
    if (data.isEmpty) return const SizedBox();

    final total = data.values.fold<int>(0, (a, b) => a + b);
    final colors = _distributionColors;

    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _CardContainer(
      cs: _cs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 24,
                      sections: List.generate(entries.length, (i) {
                        final e = entries[i];
                        final pct = total > 0 ? e.value / total * 100 : 0.0;
                        return PieChartSectionData(
                          value: e.value.toDouble(),
                          color: colors[i % colors.length],
                          radius: 32,
                          title: pct >= 10 ? '${pct.toStringAsFixed(0)}%' : '',
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(
                      entries.length > 5 ? 5 : entries.length,
                      (i) {
                        final e = entries[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: colors[i % colors.length],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  e.key,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Text(
                                '${e.value}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Color> get _distributionColors => [
    _cs.primary,
    _cs.tertiary,
    _cs.secondary,
    Colors.orange,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
  ];

  // ─────────────── 活跃度 + 效率 ───────────────

  Widget _buildActivityAndEfficiencyRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildActivityCard()),
        const SizedBox(width: 12),
        Expanded(child: _buildEfficiencyCard()),
      ],
    );
  }

  Widget _buildActivityCard() {
    return _CardContainer(
      cs: _cs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _l10n.activity,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _ActivityItem(
            icon: Icons.local_fire_department_rounded,
            iconColor: Colors.orange,
            label: _l10n.currentStreak,
            value: _l10n.streakDays(_stats.currentStreak),
            cs: _cs,
          ),
          const SizedBox(height: 12),
          _ActivityItem(
            icon: Icons.access_time,
            iconColor: _cs.tertiary,
            label: _l10n.lastUsed,
            value: _stats.lastTranscriptionAt != null
                ? _formatTimeAgo(_stats.lastTranscriptionAt!)
                : '-',
            cs: _cs,
          ),
          const SizedBox(height: 12),
          _ActivityItem(
            icon: Icons.emoji_events_outlined,
            iconColor: Colors.amber.shade700,
            label: _l10n.mostActiveDay,
            value: _stats.mostActiveDate != null
                ? '${DateFormat('M/d').format(_stats.mostActiveDate!)}  (${_l10n.sessions(_stats.mostActiveDateCount)})'
                : '-',
            cs: _cs,
          ),
        ],
      ),
    );
  }

  Widget _buildEfficiencyCard() {
    return _CardContainer(
      cs: _cs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _l10n.efficiency,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _ActivityItem(
            icon: Icons.speed,
            iconColor: _cs.primary,
            label: _l10n.charsPerMinute,
            value: _stats.avgCharsPerMinute.toStringAsFixed(1),
            cs: _cs,
          ),
          if (_stats.enhanceTotalTokens > 0) ...[
            const SizedBox(height: 20),
            Text(
              _l10n.enhanceTokenUsage,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            _ActivityItem(
              icon: Icons.arrow_upward_rounded,
              iconColor: Colors.orange,
              label: _l10n.enhanceInputTokens,
              value: _formatNumber(_stats.enhancePromptTokens),
              cs: _cs,
            ),
            const SizedBox(height: 12),
            _ActivityItem(
              icon: Icons.arrow_downward_rounded,
              iconColor: Colors.teal,
              label: _l10n.enhanceOutputTokens,
              value: _formatNumber(_stats.enhanceCompletionTokens),
              cs: _cs,
            ),
            const SizedBox(height: 12),
            _ActivityItem(
              icon: Icons.token_outlined,
              iconColor: _cs.secondary,
              label: _l10n.enhanceTotalTokens,
              value: _formatNumber(_stats.enhanceTotalTokens),
              cs: _cs,
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────── Helpers ───────────────

  String _formatNumber(int n) {
    if (n >= 10000) {
      return '${(n / 10000).toStringAsFixed(1)}w';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return '$n';
  }

  String _formatDuration(int ms) {
    final totalSeconds = ms ~/ 1000;
    if (totalSeconds < 60) {
      return '$totalSeconds${_l10n.secondShort}';
    }
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes < 60) {
      return seconds > 0
          ? '$minutes${_l10n.minuteShort} $seconds${_l10n.secondShort}'
          : '$minutes${_l10n.minuteShort}';
    }
    final hours = minutes ~/ 60;
    final remainMin = minutes % 60;
    return remainMin > 0
        ? '$hours${_l10n.hourShort} $remainMin${_l10n.minuteShort}'
        : '$hours${_l10n.hourShort}';
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return _l10n.timeAgo('<1${_l10n.minuteShort}');
    if (diff.inHours < 1) {
      return _l10n.timeAgo('${diff.inMinutes}${_l10n.minuteShort}');
    }
    if (diff.inDays < 1) {
      return _l10n.timeAgo('${diff.inHours}${_l10n.hourShort}');
    }
    if (diff.inDays < 30) {
      return _l10n.timeAgo('${diff.inDays}d');
    }
    return DateFormat('yyyy/M/d').format(dt);
  }
}

// ═══════════════════════════════════════════════════
// 私有小组件
// ═══════════════════════════════════════════════════

/// 统计卡片
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ColorScheme cs;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 容器卡片
class _CardContainer extends StatelessWidget {
  final Widget child;
  final ColorScheme cs;

  const _CardContainer({required this.child, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: child,
    );
  }
}

/// 小型统计项（今日/周/月摘要用）
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;

  const _MiniStat({required this.label, required this.value, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ],
    );
  }
}

/// 活跃度条目
class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final ColorScheme cs;

  const _ActivityItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}
