import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/meeting.dart';
import '../../models/provider_config.dart';
import '../../models/ai_enhance_config.dart';
import '../../providers/meeting_provider.dart';

/// 会议录制页面
class MeetingRecordingPage extends StatefulWidget {
  final SttProviderConfig sttConfig;
  final AiEnhanceConfig? aiConfig;
  final bool aiEnhanceEnabled;

  const MeetingRecordingPage({
    super.key,
    required this.sttConfig,
    this.aiConfig,
    this.aiEnhanceEnabled = false,
  });

  @override
  State<MeetingRecordingPage> createState() => _MeetingRecordingPageState();
}

class _MeetingRecordingPageState extends State<MeetingRecordingPage> {
  ColorScheme get _cs => Theme.of(context).colorScheme;

  final TextEditingController _titleController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoStart();
    });
  }

  Future<void> _autoStart() async {
    final provider = context.read<MeetingProvider>();
    if (provider.isRecording) {
      // 已经在录制中，恢复页面
      _titleController.text = provider.currentMeeting?.title ?? '';
      return;
    }

    setState(() => _isStarting = true);
    try {
      final meeting = await provider.startMeeting(
        sttConfig: widget.sttConfig,
        aiConfig: widget.aiConfig,
        aiEnhanceEnabled: widget.aiEnhanceEnabled,
      );
      _titleController.text = meeting.title;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('会议启动失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<MeetingProvider>();
    final segments = provider.currentSegments;

    // 每次有新分段时自动滚动
    if (segments.isNotEmpty) {
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: _cs.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: _cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _handleBack(provider, l10n),
        ),
        title: SizedBox(
          width: 300,
          child: TextField(
            controller: _titleController,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _cs.onSurface,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: l10n.meetingTitleHint,
              hintStyle: TextStyle(
                color: _cs.onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
            ),
            onSubmitted: (value) {
              if (provider.currentMeeting != null && value.isNotEmpty) {
                provider.updateMeetingTitle(provider.currentMeeting!.id, value);
              }
            },
          ),
        ),
        actions: [
          // 录音时长
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _cs.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, size: 16, color: _cs.onSecondaryContainer),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(provider.recordingDuration),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    color: _cs.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 状态栏
          _buildStatusBar(provider, l10n),
          // 分段内容列表
          Expanded(
            child: _isStarting
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(l10n.meetingStarting),
                      ],
                    ),
                  )
                : segments.isEmpty
                    ? _buildWaiting(l10n)
                    : _buildSegmentList(segments, l10n),
          ),
          // 底部控制栏
          _buildControlBar(provider, l10n),
        ],
      ),
    );
  }

  Widget _buildStatusBar(MeetingProvider provider, AppLocalizations l10n) {
    Color barColor;
    IconData barIcon;
    String barText;

    if (provider.isPaused) {
      barColor = Colors.orange;
      barIcon = Icons.pause_circle_outlined;
      barText = l10n.meetingPaused;
    } else if (provider.status == 'processing') {
      barColor = Colors.blue;
      barIcon = Icons.hourglass_top;
      barText = l10n.meetingProcessing;
    } else {
      barColor = Colors.red;
      barIcon = Icons.fiber_manual_record;
      barText = l10n.meetingRecording;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: barColor.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(barIcon, size: 14, color: barColor),
          const SizedBox(width: 6),
          Text(
            barText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: barColor,
            ),
          ),
          const Spacer(),
          Text(
            '${l10n.meetingSegments}: ${provider.currentSegments.length}',
            style: TextStyle(fontSize: 13, color: _cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildWaiting(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 录音波形动画
          _WaveformIndicator(amplitudeStream: context.read<MeetingProvider>().amplitudeStream),
          const SizedBox(height: 16),
          Text(
            l10n.meetingListening,
            style: TextStyle(fontSize: 15, color: _cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.meetingListeningHint,
            style: TextStyle(fontSize: 13, color: _cs.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentList(List<MeetingSegment> segments, AppLocalizations l10n) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: segments.length,
      itemBuilder: (context, index) {
        final segment = segments[index];
        return _buildSegmentCard(segment, l10n, index);
      },
    );
  }

  Widget _buildSegmentCard(MeetingSegment segment, AppLocalizations l10n, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: segment.status == SegmentStatus.error
              ? Colors.red.withValues(alpha: 0.3)
              : _cs.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分段头部
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _cs.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                segment.formattedTimestamp,
                style: TextStyle(fontSize: 12, color: _cs.onSurfaceVariant),
              ),
              const Spacer(),
              _buildSegmentStatusChip(segment, l10n),
            ],
          ),
          const SizedBox(height: 10),
          // 文本内容
          if (segment.status == SegmentStatus.pending ||
              segment.status == SegmentStatus.transcribing)
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _cs.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  segment.status == SegmentStatus.transcribing
                      ? l10n.meetingTranscribing
                      : l10n.meetingWaitingProcess,
                  style: TextStyle(fontSize: 13, color: _cs.onSurfaceVariant),
                ),
              ],
            )
          else if (segment.status == SegmentStatus.enhancing)
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.meetingEnhancing,
                  style: TextStyle(fontSize: 13, color: Colors.purple),
                ),
              ],
            )
          else if (segment.status == SegmentStatus.error)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  segment.errorMessage ?? l10n.meetingSegmentError,
                  style: const TextStyle(fontSize: 13, color: Colors.red),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => context.read<MeetingProvider>().retrySegment(segment),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(l10n.meetingRetry),
                  style: TextButton.styleFrom(
                    foregroundColor: _cs.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ],
            )
          else if (segment.displayText != null && segment.displayText!.isNotEmpty)
            SelectableText(
              segment.displayText!,
              style: TextStyle(
                fontSize: 14,
                color: _cs.onSurface,
                height: 1.6,
              ),
            )
          else
            Text(
              l10n.meetingNoContent,
              style: TextStyle(fontSize: 13, color: _cs.outline, fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  Widget _buildSegmentStatusChip(MeetingSegment segment, AppLocalizations l10n) {
    String label;
    Color color;

    switch (segment.status) {
      case SegmentStatus.pending:
        label = l10n.meetingPending;
        color = Colors.grey;
      case SegmentStatus.transcribing:
        label = l10n.meetingTranscribing;
        color = Colors.blue;
      case SegmentStatus.enhancing:
        label = l10n.meetingEnhancing;
        color = Colors.purple;
      case SegmentStatus.done:
        label = l10n.meetingDone;
        color = Colors.green;
      case SegmentStatus.error:
        label = l10n.meetingError;
        color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildControlBar(MeetingProvider provider, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: _cs.surface,
        border: Border(top: BorderSide(color: _cs.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 暂停/恢复按钮
          if (provider.isRecording) ...[
            _ControlButton(
              icon: provider.isPaused ? Icons.play_arrow : Icons.pause,
              label: provider.isPaused ? l10n.meetingResume : l10n.meetingPause,
              color: Colors.orange,
              onTap: () {
                if (provider.isPaused) {
                  provider.resumeMeeting();
                } else {
                  provider.pauseMeeting();
                }
              },
            ),
            const SizedBox(width: 24),
            // 结束会议按钮
            _ControlButton(
              icon: Icons.stop,
              label: l10n.meetingStop,
              color: Colors.red,
              filled: true,
              onTap: () => _confirmStop(provider, l10n),
            ),
            const SizedBox(width: 24),
            // 取消按钮
            _ControlButton(
              icon: Icons.close,
              label: l10n.cancel,
              color: _cs.outline,
              onTap: () => _confirmCancel(provider, l10n),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmStop(MeetingProvider provider, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.meetingStopConfirmTitle),
        content: Text(l10n.meetingStopConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // 更新标题
              if (_titleController.text.isNotEmpty && provider.currentMeeting != null) {
                await provider.updateMeetingTitle(
                  provider.currentMeeting!.id,
                  _titleController.text,
                );
              }
              await provider.stopMeeting();
              if (mounted) Navigator.pop(context);
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(MeetingProvider provider, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.meetingCancelConfirmTitle),
        content: Text(l10n.meetingCancelConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.cancelMeeting();
              if (mounted) Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _handleBack(MeetingProvider provider, AppLocalizations l10n) {
    if (provider.isRecording) {
      _confirmStop(provider, l10n);
    } else {
      Navigator.pop(context);
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }
}

/// 录音波形指示器
class _WaveformIndicator extends StatefulWidget {
  final Stream<double> amplitudeStream;

  const _WaveformIndicator({required this.amplitudeStream});

  @override
  State<_WaveformIndicator> createState() => _WaveformIndicatorState();
}

class _WaveformIndicatorState extends State<_WaveformIndicator> {
  double _level = 0.0;
  StreamSubscription<double>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.amplitudeStream.listen((level) {
      if (mounted) setState(() => _level = level);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (i) {
        final height = 8.0 + (_level * 32.0 * (1.0 - (i - 3).abs() / 4.0));
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 4,
          height: height.clamp(4.0, 40.0),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.6 + _level * 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

/// 底部控制按钮
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    this.filled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: filled ? color : color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: filled ? Colors.white : color,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
