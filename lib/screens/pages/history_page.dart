import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/recording_provider.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  ColorScheme get _cs => Theme.of(context).colorScheme;

  @override
  Widget build(BuildContext context) {
    final recording = context.watch<RecordingProvider>();
    final history = recording.history;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 24,
                color: _cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.history,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _cs.onSurface,
                ),
              ),
              const Spacer(),
              if (history.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: _cs.outline),
                  tooltip: l10n.clearAll,
                  onPressed: () => _confirmClearAll(context, recording, l10n),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // 列表
          Expanded(
            child: history.isEmpty
                ? _buildEmpty(l10n)
                : _buildList(context, recording, history, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 48, color: _cs.outline),
          const SizedBox(height: 12),
          Text(
            l10n.noHistory,
            style: TextStyle(fontSize: 15, color: _cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.historyHint,
            style: TextStyle(fontSize: 13, color: _cs.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    RecordingProvider recording,
    List history,
    AppLocalizations l10n,
  ) {
    return ListView.builder(
      itemCount: history.length,
      itemBuilder: (context, index) {
        final item = history[index];
        final number = history.length - index;
        final dateStr = DateFormat('M月d日 HH:mm').format(item.createdAt);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：编号 + 时间 + 操作按钮
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#$number',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 13, color: _cs.onSurfaceVariant),
                  ),
                  const Spacer(),
                  // 复制按钮
                  _ActionIcon(
                    icon: Icons.copy_outlined,
                    tooltip: l10n.copy,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: item.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.copiedToClipboard),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  // 删除按钮
                  _ActionIcon(
                    icon: Icons.delete_outline,
                    tooltip: l10n.delete,
                    color: Colors.red.shade300,
                    onTap: () => recording.removeHistory(index),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 文本内容
              SelectableText(
                item.text,
                style: TextStyle(
                  fontSize: 15,
                  color: _cs.onSurface,
                  height: 1.6,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmClearAll(
    BuildContext context,
    RecordingProvider recording,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearHistory),
        content: Text(l10n.clearHistoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              recording.clearAllHistory();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color ?? cs.outline),
        ),
      ),
    );
  }
}
