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

class _MeetingDetailPageState extends State<MeetingDetailPage>
    with SingleTickerProviderStateMixin {
  ColorScheme get _cs => Theme.of(context).colorScheme;

  MeetingRecord? _meeting;
  bool _loading = true;

  late final TabController _tabController;
  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _detailController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();

  bool _savingDetail = false;
  bool _savingSummary = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailController.dispose();
    _summaryController.dispose();
    _tabController.dispose();
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
      appBar: AppBar(
        backgroundColor: _cs.surface,
        elevation: 0,
        title: Text(
          meeting.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _cs.onSurface,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: _cs.onSurfaceVariant),
            onSelected: (value) => _handleMenuAction(value, meeting, l10n),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    const Icon(Icons.copy, size: 18),
                    const SizedBox(width: 8),
                    Text(l10n.meetingCopyAll),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export_text',
                child: Row(
                  children: [
                    const Icon(Icons.text_snippet_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(l10n.meetingExportText),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export_md',
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(l10n.meetingExportMarkdown),
                  ],
                ),
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: _cs.primary,
          unselectedLabelColor: _cs.onSurfaceVariant,
          indicatorColor: _cs.primary,
          tabs: [
            Tab(
              icon: const Icon(Icons.article_outlined, size: 18),
              text: l10n.meetingDetailTab,
            ),
            Tab(
              icon: const Icon(Icons.summarize_outlined, size: 18),
              text: l10n.meetingSummaryTab,
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailTab(meeting, dateStr, l10n),
          _buildSummaryTab(meeting, l10n),
        ],
      ),
    );
  }

  Widget _buildDetailTab(
    MeetingRecord meeting,
    String dateStr,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(meeting, dateStr, l10n),
          const SizedBox(height: 20),
          _buildTitleSection(meeting, l10n),
          const SizedBox(height: 20),
          _buildDetailEditorSection(l10n),
        ],
      ),
    );
  }

  Widget _buildSummaryTab(MeetingRecord meeting, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.meetingSummary,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _cs.onSurface,
                ),
              ),
              const Spacer(),
              if (_hasFullTranscription)
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(l10n.meetingRegenerateSummary),
                  onPressed: () => _regenerateSummary(l10n),
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _savingSummary ? null : _saveSummary,
                icon: _savingSummary
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(l10n.saveChanges),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextEditorCard(
            controller: _summaryController,
            emptyHint: l10n.meetingNoSummary,
            minLines: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailEditorSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.article_outlined, size: 18, color: _cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              l10n.meetingFullTranscription,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _cs.onSurface,
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _savingDetail ? null : _saveDetail,
              icon: _savingDetail
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 16),
              label: Text(l10n.saveChanges),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTextEditorCard(
          controller: _detailController,
          emptyHint: l10n.meetingNoContent,
          minLines: 14,
        ),
      ],
    );
  }

  Widget _buildTextEditorCard({
    required TextEditingController controller,
    required String emptyHint,
    required int minLines,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) {
        _showDictionaryContextMenu(details.globalPosition, controller);
      },
      child: Container(
        decoration: BoxDecoration(
          color: _cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cs.outlineVariant),
        ),
        child: TextField(
          controller: controller,
          minLines: minLines,
          maxLines: null,
          style: TextStyle(fontSize: 14, color: _cs.onSurface, height: 1.7),
          decoration: InputDecoration(
            hintText: emptyHint,
            hintStyle: TextStyle(color: _cs.outline),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    MeetingRecord meeting,
    String dateStr,
    AppLocalizations l10n,
  ) {
    final charCount = _detailController.text.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cs.outlineVariant),
      ),
      child: Row(
        children: [
          _InfoItem(
            icon: Icons.calendar_today_outlined,
            label: l10n.meetingDate,
            value: dateStr,
            cs: _cs,
          ),
          const SizedBox(width: 32),
          _InfoItem(
            icon: Icons.timer_outlined,
            label: l10n.meetingDuration,
            value: meeting.formattedDuration,
            cs: _cs,
          ),
          const SizedBox(width: 32),
          _InfoItem(
            icon: Icons.text_fields_outlined,
            label: l10n.meetingTotalChars,
            value: '$charCount',
            cs: _cs,
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection(MeetingRecord meeting, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cs.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _titleController,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _cs.onSurface,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                labelText: l10n.meetingTitle,
                labelStyle: TextStyle(color: _cs.onSurfaceVariant),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (_titleController.text.isEmpty) return;
              await context.read<MeetingProvider>().updateMeetingTitle(
                widget.meetingId,
                _titleController.text,
              );
              if (!mounted) return;
              setState(() => _meeting!.title = _titleController.text);
              _showSavedSnackBar();
            },
            child: Text(l10n.saveChanges),
          ),
        ],
      ),
    );
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
      if (mounted) {
        setState(() => _savingDetail = false);
      }
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
      if (mounted) {
        setState(() => _savingSummary = false);
      }
    }
  }

  Future<void> _regenerateSummary(AppLocalizations l10n) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.meetingGeneratingSummary),
        duration: const Duration(seconds: 60),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      await context.read<MeetingProvider>().regenerateSummary(widget.meetingId);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSavedSnackBar();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.meetingError),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  bool get _hasFullTranscription {
    return _detailController.text.trim().isNotEmpty;
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

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: cs.outline),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}
