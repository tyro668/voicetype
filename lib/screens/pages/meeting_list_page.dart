import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/meeting.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/settings_provider.dart';
import 'meeting_recording_page.dart';
import 'meeting_detail_page.dart';

/// 会议记录列表页面
class MeetingListPage extends StatefulWidget {
  const MeetingListPage({super.key});

  @override
  State<MeetingListPage> createState() => _MeetingListPageState();
}

class _MeetingListPageState extends State<MeetingListPage> {
  ColorScheme get _cs => Theme.of(context).colorScheme;

  @override
  void initState() {
    super.initState();
    // 刷新会议列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MeetingProvider>().refreshMeetings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final meetingProvider = context.watch<MeetingProvider>();
    final meetings = meetingProvider.meetings;
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
                Icons.record_voice_over_outlined,
                size: 24,
                color: _cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.meetingMinutes,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _cs.onSurface,
                ),
              ),
              const Spacer(),
              // 当前录制中的提示
              if (meetingProvider.isRecording)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.meetingRecording,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 12),
              // 新建会议按钮
              FilledButton.icon(
                onPressed: meetingProvider.isRecording
                    ? null
                    : () => _startNewMeeting(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.meetingNew),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 列表
          Expanded(
            child: meetings.isEmpty
                ? _buildEmpty(l10n)
                : _buildList(context, meetingProvider, meetings, l10n),
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
          Icon(Icons.record_voice_over, size: 48, color: _cs.outline),
          const SizedBox(height: 12),
          Text(
            l10n.meetingEmpty,
            style: TextStyle(fontSize: 15, color: _cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.meetingEmptyHint,
            style: TextStyle(fontSize: 13, color: _cs.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    MeetingProvider provider,
    List<MeetingRecord> meetings,
    AppLocalizations l10n,
  ) {
    return ListView.builder(
      itemCount: meetings.length,
      itemBuilder: (context, index) {
        final meeting = meetings[index];
        return _buildMeetingCard(context, provider, meeting, l10n, index);
      },
    );
  }

  Widget _buildMeetingCard(
    BuildContext context,
    MeetingProvider provider,
    MeetingRecord meeting,
    AppLocalizations l10n,
    int index,
  ) {
    final dateStr = DateFormat('M月d日 HH:mm').format(meeting.createdAt);
    final statusLabel = _statusLabel(meeting.status, l10n);
    final statusColor = _statusColor(meeting.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: meeting.status == MeetingStatus.recording
            ? () => _navigateToRecording(context)
            : () => _navigateToDetail(context, meeting),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // 会议图标
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  meeting.status == MeetingStatus.recording
                      ? Icons.mic
                      : Icons.description_outlined,
                  color: _cs.onSecondaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              // 标题和信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meeting.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          dateStr,
                          style: TextStyle(fontSize: 13, color: _cs.onSurfaceVariant),
                        ),
                        const SizedBox(width: 12),
                        if (meeting.totalDuration.inSeconds > 0) ...[
                          Icon(Icons.timer_outlined, size: 14, color: _cs.outline),
                          const SizedBox(width: 4),
                          Text(
                            meeting.formattedDuration,
                            style: TextStyle(fontSize: 13, color: _cs.onSurfaceVariant),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // 状态标签
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 操作按钮
              if (meeting.status == MeetingStatus.completed) ...[
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20, color: _cs.outline),
                  tooltip: l10n.delete,
                  onPressed: () => _confirmDelete(context, provider, meeting, l10n),
                ),
              ],
              Icon(Icons.chevron_right, size: 20, color: _cs.outline),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(MeetingStatus status, AppLocalizations l10n) {
    switch (status) {
      case MeetingStatus.recording:
        return l10n.meetingRecording;
      case MeetingStatus.paused:
        return l10n.meetingPaused;
      case MeetingStatus.completed:
        return l10n.meetingCompleted;
    }
  }

  Color _statusColor(MeetingStatus status) {
    switch (status) {
      case MeetingStatus.recording:
        return Colors.red;
      case MeetingStatus.paused:
        return Colors.orange;
      case MeetingStatus.completed:
        return Colors.green;
    }
  }

  void _startNewMeeting(BuildContext context) {
    final settings = context.read<SettingsProvider>();

    // 检查 STT 模型配置
    if (settings.config.model.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseConfigureSttModel),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<MeetingProvider>(),
          child: MeetingRecordingPage(
            sttConfig: settings.config,
            aiConfig: settings.effectiveAiEnhanceConfig,
            aiEnhanceEnabled: settings.aiEnhanceEnabled,
          ),
        ),
      ),
    );
  }

  void _navigateToRecording(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<MeetingProvider>(),
          child: MeetingRecordingPage(
            sttConfig: settings.config,
            aiConfig: settings.effectiveAiEnhanceConfig,
            aiEnhanceEnabled: settings.aiEnhanceEnabled,
          ),
        ),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, MeetingRecord meeting) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<MeetingProvider>(),
          child: MeetingDetailPage(meetingId: meeting.id),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    MeetingProvider provider,
    MeetingRecord meeting,
    AppLocalizations l10n,
  ) {
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
            onPressed: () {
              provider.deleteMeeting(meeting.id);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}
