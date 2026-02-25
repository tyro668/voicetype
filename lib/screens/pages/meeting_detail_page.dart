import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/meeting.dart';
import '../../providers/meeting_provider.dart';

/// 会议详情 / 编辑页面
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
  final TextEditingController _titleController = TextEditingController();

  // 完整文稿编辑
  bool _isEditingTranscription = false;
  final TextEditingController _transcriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<MeetingProvider>();
    await provider.refreshMeetings();

    final meetings = provider.meetings;
    MeetingRecord? meeting;
    for (final m in meetings) {
      if (m.id == widget.meetingId) {
        meeting = m;
        break;
      }
    }

    if (mounted) {
      setState(() {
        _meeting = meeting;
        _loading = false;
        _titleController.text = meeting?.title ?? '';
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _transcriptionController.dispose();
    super.dispose();
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
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _cs.onSurface),
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
                    Icon(Icons.delete_outline, size: 18, color: Colors.red.shade300),
                    const SizedBox(width: 8),
                    Text(l10n.delete, style: TextStyle(color: Colors.red.shade300)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 会议信息卡片
            _buildInfoCard(meeting, dateStr, l10n),
            const SizedBox(height: 20),
            // 标题编辑
            _buildTitleSection(meeting, l10n),
            const SizedBox(height: 20),
            // 会议摘要
            if (meeting.summary != null && meeting.summary!.isNotEmpty) ...[
              _buildSummarySection(meeting, l10n),
              const SizedBox(height: 20),
            ],
            // 完整文稿
            _buildFullTranscriptionSection(meeting, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(MeetingRecord meeting, String dateStr, AppLocalizations l10n) {
    final charCount = (meeting.fullTranscription ?? '').length;

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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _cs.onSurface),
              decoration: InputDecoration(
                border: InputBorder.none,
                labelText: l10n.meetingTitle,
                labelStyle: TextStyle(color: _cs.onSurfaceVariant),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (_titleController.text.isNotEmpty) {
                await context.read<MeetingProvider>().updateMeetingTitle(
                  widget.meetingId,
                  _titleController.text,
                );
                if (mounted) {
                  setState(() {
                    _meeting!.title = _titleController.text;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.meetingSaved),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: Text(l10n.saveChanges),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(MeetingRecord meeting, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cs.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize_outlined, size: 18, color: _cs.primary),
              const SizedBox(width: 6),
              Text(
                l10n.meetingSummary,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            meeting.summary!,
            style: TextStyle(fontSize: 14, color: _cs.onSurface, height: 1.6),
          ),
        ],
      ),
    );
  }

  /// 完整文稿展示区域
  Widget _buildFullTranscriptionSection(MeetingRecord meeting, AppLocalizations l10n) {
    final hasFullText = meeting.fullTranscription != null &&
        meeting.fullTranscription!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            children: [
              Icon(Icons.article_outlined, size: 18, color: _cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                l10n.meetingFullTranscription,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _cs.onSurface,
                ),
              ),
              const Spacer(),
              // 复制按钮
              if (hasFullText)
                IconButton(
                  icon: Icon(Icons.copy_outlined, size: 18, color: _cs.outline),
                  tooltip: l10n.meetingCopyAll,
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: meeting.fullTranscription!),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.copiedToClipboard),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              // 编辑按钮
              IconButton(
                icon: Icon(
                  _isEditingTranscription ? Icons.close : Icons.edit_outlined,
                  size: 18,
                  color: _cs.outline,
                ),
                tooltip: _isEditingTranscription ? l10n.cancel : l10n.edit,
                onPressed: () {
                  setState(() {
                    if (_isEditingTranscription) {
                      _isEditingTranscription = false;
                    } else {
                      _isEditingTranscription = true;
                      _transcriptionController.text =
                          meeting.fullTranscription ?? '';
                    }
                  });
                },
              ),
            ],
          ),
          const Divider(height: 20),
          // 内容区
          if (_isEditingTranscription)
            Column(
              children: [
                TextField(
                  controller: _transcriptionController,
                  maxLines: null,
                  minLines: 8,
                  style: TextStyle(
                    fontSize: 14,
                    color: _cs.onSurface,
                    height: 1.8,
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() => _isEditingTranscription = false);
                      },
                      child: Text(l10n.cancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        await context
                            .read<MeetingProvider>()
                            .updateMeetingFullTranscription(
                              widget.meetingId,
                              _transcriptionController.text,
                            );
                        setState(() {
                          meeting.fullTranscription =
                              _transcriptionController.text;
                          _isEditingTranscription = false;
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.meetingSaved),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: Text(l10n.saveChanges),
                    ),
                  ],
                ),
              ],
            )
          else if (hasFullText)
            SelectableText(
              meeting.fullTranscription!,
              style: TextStyle(
                fontSize: 14,
                color: _cs.onSurface,
                height: 1.8,
              ),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  l10n.meetingNoContent,
                  style: TextStyle(
                    fontSize: 14,
                    color: _cs.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, MeetingRecord meeting, AppLocalizations l10n) async {
    switch (action) {
      case 'copy':
        final text = meeting.fullTranscription ?? '';
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
        final content = await context.read<MeetingProvider>().exportAsText(widget.meetingId);
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
        final content = await context.read<MeetingProvider>().exportAsMarkdown(widget.meetingId);
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
        _confirmDelete(meeting, l10n);
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
}

/// 信息项小部件
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
