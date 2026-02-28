import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/recording_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/dictionary_entry_dialog.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  ColorScheme get _cs => Theme.of(context).colorScheme;

  /// 记录哪些 item id 的原始文本处于展开状态
  final Set<String> _expandedRawText = {};

  @override
  Widget build(BuildContext context) {
    final recording = context.watch<RecordingProvider>();
    final history = recording.history;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      color: _cs.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 22,
                color: _cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.history,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _cs.onSurface,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              if (history.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: _cs.outline.withValues(alpha: 0.55),
                    size: 22,
                  ),
                  tooltip: l10n.clearAll,
                  onPressed: () => _confirmClearAll(context, recording, l10n),
                ),
            ],
          ),
          const SizedBox(height: 24),
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
          Icon(
            Icons.history_rounded,
            size: 52,
            color: _cs.outline.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.noHistory,
            style: TextStyle(fontSize: 15, color: _cs.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.historyHint,
            style: TextStyle(
              fontSize: 13,
              color: _cs.outline.withValues(alpha: 0.7),
            ),
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
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: _cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _cs.outlineVariant.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: _cs.shadow.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：编号 + 时间 + 操作按钮
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE7F6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '#$number',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5C3BBF),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 13,
                      color: _cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
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
              // 文本内容（右键可加入词典）
              SelectableText(
                item.text,
                style: TextStyle(
                  fontSize: 14.5,
                  color: _cs.onSurface.withValues(alpha: 0.88),
                  height: 1.65,
                ),
                contextMenuBuilder: (ctx, editableTextState) {
                  final selectedText = editableTextState
                      .textEditingValue
                      .selection
                      .textInside(editableTextState.textEditingValue.text);
                  final builtinItems = editableTextState.contextMenuButtonItems;
                  return AdaptiveTextSelectionToolbar.buttonItems(
                    anchors: editableTextState.contextMenuAnchors,
                    buttonItems: [
                      ...builtinItems,
                      if (selectedText.trim().isNotEmpty)
                        ContextMenuButtonItem(
                          label: l10n.addToDictionary,
                          onPressed: () {
                            ContextMenuController.removeAny();
                            _addToDictionary(selectedText.trim());
                          },
                        ),
                    ],
                  );
                },
              ),
              // 原始录音文字（折叠/展开）
              if (item.hasRawText) ...[
                const SizedBox(height: 8),
                _buildRawTextToggle(item, l10n),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRawTextToggle(dynamic item, AppLocalizations l10n) {
    final isExpanded = _expandedRawText.contains(item.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedRawText.remove(item.id);
              } else {
                _expandedRawText.add(item.id);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: _cs.outline.withValues(alpha: 0.65),
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.originalSttText,
                  style: TextStyle(
                    fontSize: 12,
                    color: _cs.outline.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cs.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              item.rawText ?? '',
              style: TextStyle(
                fontSize: 13,
                color: _cs.onSurfaceVariant.withValues(alpha: 0.8),
                height: 1.55,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _addToDictionary(String selectedWord) async {
    if (selectedWord.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();

    final entry = await showDictionaryEntryDialog(
      context,
      initialOriginal: selectedWord,
    );
    if (entry == null || !mounted) return;

    await settings.addDictionaryEntry(entry);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${l10n.addedToDictionary}: ${entry.original}'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
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
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(
            icon,
            size: 18,
            color: color ?? cs.outline.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}
