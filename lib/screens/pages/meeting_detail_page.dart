import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/dictionary_entry.dart';
import '../../models/meeting.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/settings_provider.dart';

class MeetingDetailPage extends StatefulWidget {
  final String meetingId;

  const MeetingDetailPage({super.key, required this.meetingId});

  @override
  State<MeetingDetailPage> createState() => _MeetingDetailPageState();
}

class _MeetingDetailPageState extends State<MeetingDetailPage> {
  ColorScheme get _cs => Theme.of(context).colorScheme;

  MeetingRecord? _meeting;
  bool _loading = true;
  bool _editingTitle = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();

  bool _savingDetail = false;
  bool _savingSummary = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final provider = context.read<MeetingProvider>();
    await provider.refreshMeetings();

    final meeting = provider.meetings
        .where((m) => m.id == widget.meetingId)
        .firstOrNull;

    if (!mounted) return;

    setState(() {
      _meeting = meeting;
      _loading = false;
      _titleController.text = meeting?.title ?? '';
      _detailController.text = meeting?.fullTranscription ?? '';
      _summaryController.text = meeting?.summary ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.meetingMinutes)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_meeting == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.meetingMinutes)),
        body: Center(child: Text(l10n.meetingNotFound)),
      );
    }

    final meeting = _meeting!;
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(meeting.createdAt);

    return Scaffold(
      backgroundColor: _cs.surfaceContainerLow,
      body: Column(
        children: [
          _buildHeader(meeting, dateStr, l10n),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 左侧：完整转写
                  Expanded(
                    flex: 3,
                    child: _buildPanel(
                      icon: Icons.article_outlined,
                      title: l10n.meetingFullTranscription,
                      trailing: _buildSaveButton(
                        saving: _savingDetail,
                        onPressed: _saveDetail,
                        l10n: l10n,
                      ),
                      body: _buildTextEditor(
                        controller: _detailController,
                        emptyHint: l10n.meetingNoContent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 右侧：会议摘要
                  Expanded(
                    flex: 2,
                    child: _buildPanel(
                      icon: Icons.summarize_outlined,
                      title: l10n.meetingSummary,
                      trailing: _buildSaveButton(
                        saving: _savingSummary,
                        onPressed: _saveSummary,
                        l10n: l10n,
                      ),
                      body: _buildTextEditor(
                        controller: _summaryController,
                        emptyHint: l10n.meetingNoSummary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────── Header ────────────────

  Widget _buildHeader(
    MeetingRecord meeting,
    String dateStr,
    AppLocalizations l10n,
  ) {
    final charCount = _detailController.text.length;

    return Container(
      height: 52,
      padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
      decoration: BoxDecoration(
        color: _cs.surface,
        border: Border(bottom: BorderSide(color: _cs.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => Navigator.pop(context),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          ),
          const SizedBox(width: 4),
          // 可编辑标题
          Expanded(child: _buildTitleArea(meeting)),
          const SizedBox(width: 12),
          // 信息标签
          _buildBadge(Icons.calendar_today_outlined, dateStr),
          const SizedBox(width: 6),
          _buildBadge(Icons.timer_outlined, meeting.formattedDuration),
          const SizedBox(width: 6),
          _buildBadge(Icons.text_fields, '$charCount'),
          const SizedBox(width: 4),
          // 操作菜单
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 20, color: _cs.onSurfaceVariant),
            onSelected: (v) => _handleMenuAction(v, meeting, l10n),
            itemBuilder: (_) => [
              _menuItem('copy', Icons.copy, l10n.meetingCopyAll),
              _menuItem(
                'export_text',
                Icons.text_snippet_outlined,
                l10n.meetingExportText,
              ),
              _menuItem(
                'export_md',
                Icons.description_outlined,
                l10n.meetingExportMarkdown,
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.delete,
                      style: TextStyle(color: Colors.red.shade300),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
      ),
    );
  }

  Widget _buildTitleArea(MeetingRecord meeting) {
    if (_editingTitle) {
      return SizedBox(
        height: 34,
        child: TextField(
          controller: _titleController,
          autofocus: true,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _cs.onSurface,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _cs.outline),
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.check, size: 16, color: _cs.primary),
                  onPressed: _saveTitle,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: _cs.outline),
                  onPressed: () {
                    _titleController.text = _meeting?.title ?? '';
                    setState(() => _editingTitle = false);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ],
            ),
          ),
          onSubmitted: (_) => _saveTitle(),
        ),
      );
    }

    return GestureDetector(
      onDoubleTap: () => setState(() => _editingTitle = true),
      child: Row(
        children: [
          Flexible(
            child: Text(
              meeting.title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _cs.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.edit_outlined, size: 14, color: _cs.outline),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, color: _cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ──────────────── Content Panels ────────────────

  Widget _buildPanel({
    required IconData icon,
    required String title,
    required Widget trailing,
    required Widget body,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 面板标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
            child: Row(
              children: [
                Icon(icon, size: 16, color: _cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _cs.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                trailing,
              ],
            ),
          ),
          Divider(height: 1, color: _cs.outlineVariant.withValues(alpha: 0.4)),
          // 编辑区域
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildTextEditor({
    required TextEditingController controller,
    required String emptyHint,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) {
        _showDictionaryContextMenu(details.globalPosition, controller);
      },
      child: TextField(
        controller: controller,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(fontSize: 13, color: _cs.onSurface, height: 1.8),
        decoration: InputDecoration(
          hintText: emptyHint,
          hintStyle: TextStyle(color: _cs.outline),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _buildSaveButton({
    required bool saving,
    required VoidCallback onPressed,
    required AppLocalizations l10n,
  }) {
    return SizedBox(
      height: 30,
      child: FilledButton.tonalIcon(
        onPressed: saving ? null : onPressed,
        icon: saving
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            : const Icon(Icons.save_outlined, size: 14),
        label: Text(l10n.saveChanges, style: const TextStyle(fontSize: 12)),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  // ──────────────── Data Actions ────────────────

  Future<void> _saveTitle() async {
    if (_titleController.text.isEmpty) return;
    await context.read<MeetingProvider>().updateMeetingTitle(
      widget.meetingId,
      _titleController.text,
    );
    if (!mounted) return;
    setState(() {
      _meeting!.title = _titleController.text;
      _editingTitle = false;
    });
    _showSavedSnackBar();
  }

  Future<void> _saveDetail() async {
    setState(() => _savingDetail = true);
    try {
      final stored = _detailController.text;
      await context.read<MeetingProvider>().updateMeetingFullTranscription(
        widget.meetingId,
        stored,
      );
      if (!mounted) return;
      _meeting?.fullTranscription = stored;
      _showSavedSnackBar();
      setState(() {});
    } finally {
      if (mounted) setState(() => _savingDetail = false);
    }
  }

  Future<void> _saveSummary() async {
    setState(() => _savingSummary = true);
    try {
      final stored = _summaryController.text;
      await context.read<MeetingProvider>().updateMeetingSummary(
        widget.meetingId,
        stored,
      );
      if (!mounted) return;
      _meeting?.summary = stored;
      _showSavedSnackBar();
    } finally {
      if (mounted) setState(() => _savingSummary = false);
    }
  }

  Future<void> _showDictionaryContextMenu(
    Offset globalPosition,
    TextEditingController controller,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final selectedText = _getSelectedText(controller);
    if (selectedText.isEmpty) return;

    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'add_dict',
          child: Text(l10n.addToDictionary),
        ),
      ],
    );
    if (selected == 'add_dict') {
      await _addToDictionary(selectedText);
    }
  }

  String _getSelectedText(TextEditingController controller) {
    final selection = controller.selection;
    if (!selection.isValid || selection.isCollapsed) return '';
    final text = controller.text;
    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);
    if (start >= end) return '';
    return text.substring(start, end).trim();
  }

  Future<void> _addToDictionary(String word) async {
    if (word.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    await context.read<SettingsProvider>().addDictionaryEntry(
      DictionaryEntry.create(word: word),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${l10n.addedToDictionary}: $word'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleMenuAction(
    String action,
    MeetingRecord meeting,
    AppLocalizations l10n,
  ) async {
    switch (action) {
      case 'copy':
        final text = _detailController.text;
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.copiedToClipboard),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;
      case 'export_text':
        final content = await context.read<MeetingProvider>().exportAsText(
          widget.meetingId,
        );
        await Clipboard.setData(ClipboardData(text: content));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.meetingExported),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;
      case 'export_md':
        final content = await context.read<MeetingProvider>().exportAsMarkdown(
          widget.meetingId,
        );
        await Clipboard.setData(ClipboardData(text: content));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.meetingExported),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;
      case 'delete':
        final isEmpty = (meeting.fullTranscription ?? '').trim().isEmpty;
        if (isEmpty) {
          await context.read<MeetingProvider>().deleteMeeting(meeting.id);
          if (mounted) Navigator.pop(context);
        } else {
          _confirmDelete(meeting, l10n);
        }
        break;
    }
  }

  void _confirmDelete(MeetingRecord meeting, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.meetingDeleteConfirmTitle),
        content: Text(l10n.meetingDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<MeetingProvider>().deleteMeeting(meeting.id);
              if (mounted) Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showSavedSnackBar() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.meetingSaved),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
