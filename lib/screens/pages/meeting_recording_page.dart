import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/meeting.dart';
import '../../models/provider_config.dart';
import '../../models/ai_enhance_config.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/settings_provider.dart';

/// 会议录制页面
class MeetingRecordingPage extends StatefulWidget {
  final SttProviderConfig sttConfig;
  final AiEnhanceConfig? aiConfig;
  final bool aiEnhanceEnabled;
  final String dictionarySuffix;

  const MeetingRecordingPage({
    super.key,
    required this.sttConfig,
    this.aiConfig,
    this.aiEnhanceEnabled = false,
    this.dictionarySuffix = '',
  });

  @override
  State<MeetingRecordingPage> createState() => _MeetingRecordingPageState();
}

class _MeetingRecordingPageState extends State<MeetingRecordingPage>
    with SingleTickerProviderStateMixin {
  ColorScheme get _cs => Theme.of(context).colorScheme;

  final TextEditingController _titleController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isStarting = false;

  /// 是否显示合并纪要视图（false = 分段视图）
  bool _showMergedView = false;

  // 长按结束相关
  Timer? _longPressTimer;
  double _longPressProgress = 0.0;
  bool _isLongPressing = false;
  static const _longPressDurationMs = 1500;
  static const _longPressStepMs = 30;

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
      _titleController.text = provider.currentMeeting?.title ?? '';
      return;
    }

    setState(() => _isStarting = true);
    try {
      final settings = context.read<SettingsProvider>();
      final meeting = await provider.startMeeting(
        sttConfig: widget.sttConfig,
        aiConfig: widget.aiConfig,
        aiEnhanceEnabled: widget.aiEnhanceEnabled,
        dictionarySuffix: widget.dictionarySuffix,
        pinyinMatcher: settings.correctionEffective
            ? settings.pinyinMatcher
            : null,
        correctionPrompt: settings.correctionEffective
            ? settings.correctionPrompt
            : null,
        maxReferenceEntries: settings.correctionMaxReferenceEntries,
        minCandidateScore: settings.correctionMinCandidateScore,
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
    _longPressTimer?.cancel();
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

  // ── 长按结束会议 ──

  void _startLongPress() {
    setState(() {
      _isLongPressing = true;
      _longPressProgress = 0.0;
    });
    _longPressTimer = Timer.periodic(
      const Duration(milliseconds: _longPressStepMs),
      (timer) {
        setState(() {
          _longPressProgress += _longPressStepMs / _longPressDurationMs;
        });
        if (_longPressProgress >= 1.0) {
          timer.cancel();
          _confirmEndMeeting();
        }
      },
    );
  }

  void _cancelLongPress() {
    _longPressTimer?.cancel();
    setState(() {
      _isLongPressing = false;
      _longPressProgress = 0.0;
    });
  }

  Future<void> _confirmEndMeeting() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isLongPressing = false;
      _longPressProgress = 0.0;
    });

    final provider = context.read<MeetingProvider>();
    if (_titleController.text.isNotEmpty && provider.currentMeeting != null) {
      await provider.updateMeetingTitle(
        provider.currentMeeting!.id,
        _titleController.text,
      );
    }
    await provider.stopMeeting();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<MeetingProvider>();
    final segments = provider.currentSegments;

    if (segments.isNotEmpty) {
      _scrollToBottom();
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          // 保存标题（录音在后台继续）
          if (_titleController.text.isNotEmpty &&
              provider.currentMeeting != null) {
            provider.updateMeetingTitle(
              provider.currentMeeting!.id,
              _titleController.text,
            );
          }
        }
      },
      child: Scaffold(
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
                  provider.updateMeetingTitle(
                    provider.currentMeeting!.id,
                    value,
                  );
                }
              },
            ),
          ),
          actions: [
            // 暂停/继续 + 长按结束会议
            if (provider.isRecording)
              GestureDetector(
                onLongPressStart: (_) => _startLongPress(),
                onLongPressEnd: (_) => _cancelLongPress(),
                onLongPressCancel: () => _cancelLongPress(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 长按进度环
                    if (_isLongPressing)
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          value: _longPressProgress,
                          strokeWidth: 3,
                          color: Colors.red,
                          backgroundColor: Colors.red.withValues(alpha: 0.15),
                        ),
                      ),
                    IconButton(
                      onPressed: () {
                        if (provider.isPaused) {
                          provider.resumeMeeting();
                        } else {
                          provider.pauseMeeting();
                        }
                      },
                      icon: Icon(
                        _isLongPressing
                            ? Icons.stop_rounded
                            : provider.isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        size: 20,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: _isLongPressing
                            ? Colors.red
                            : provider.isPaused
                            ? _cs.primary
                            : Colors.orange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(36, 36),
                        padding: const EdgeInsets.all(6),
                      ),
                      tooltip: provider.isPaused
                          ? l10n.meetingResume
                          : l10n.meetingPause,
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 4),
            // 停止会议按钮
            if (provider.isRecording)
              IconButton(
                onPressed: () => _confirmEndMeeting(),
                icon: const Icon(Icons.stop_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(36, 36),
                  padding: const EdgeInsets.all(6),
                ),
                tooltip: l10n.meetingStop,
              ),
            const SizedBox(width: 6),
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
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: _cs.onSecondaryContainer,
                  ),
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
            // 视图切换栏
            _buildViewToggle(l10n),
            // 内容区域
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
                  : _showMergedView
                  ? _buildMergedNoteArea(provider, l10n)
                  : _buildTranscriptionArea(segments, provider, l10n),
            ),
          ],
        ),
      ), // end Scaffold / PopScope child
    ); // end PopScope
  }

  /// 分段视图 / 合并纪要 切换栏
  Widget _buildViewToggle(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _cs.surface,
        border: Border(
          bottom: BorderSide(color: _cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          _buildToggleButton(
            label: l10n.meetingSegmentView,
            isSelected: !_showMergedView,
            onTap: () => setState(() => _showMergedView = false),
          ),
          const SizedBox(width: 8),
          _buildToggleButton(
            label: l10n.meetingMergedNoteView,
            isSelected: _showMergedView,
            onTap: () => setState(() => _showMergedView = true),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _cs.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? _cs.primary.withValues(alpha: 0.3)
                : _cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? _cs.onPrimaryContainer : _cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// 合并纪要展示区域
  Widget _buildMergedNoteArea(MeetingProvider provider, AppLocalizations l10n) {
    final content = provider.mergedNoteContent;
    final isStreaming = provider.isStreamingMerge;

    if (content.isEmpty && !isStreaming) {
      return Center(
        child: Text(
          l10n.meetingNoContent,
          style: TextStyle(fontSize: 14, color: _cs.outline),
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 流式加载指示器
          if (isStreaming)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
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
                    l10n.meetingStreamingMerge,
                    style: TextStyle(fontSize: 13, color: _cs.primary),
                  ),
                ],
              ),
            ),
          // 合并纪要文本
          SelectableText(
            content,
            style: TextStyle(fontSize: 14, color: _cs.onSurface, height: 1.6),
          ),
        ],
      ),
    );
  }

  /// 实时转写文字滚动区域
  Widget _buildTranscriptionArea(
    List<MeetingSegment> segments,
    MeetingProvider provider,
    AppLocalizations l10n,
  ) {
    if (segments.isEmpty && !provider.isPaused) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WaveformIndicator(amplitudeStream: provider.amplitudeStream),
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

    // 计算列表项数：已有分段 + 正在录音指示器
    final showRecordingIndicator = provider.isRecording && !provider.isPaused;
    final itemCount = segments.length + (showRecordingIndicator ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // 最后一项：当前正在录音的段（脉冲指示器）
        if (showRecordingIndicator && index == segments.length) {
          return _buildRecordingIndicator(l10n);
        }
        final segment = segments[index];
        return _buildSegmentCard(segment, l10n, index);
      },
    );
  }

  Widget _buildSegmentCard(
    MeetingSegment segment,
    AppLocalizations l10n,
    int index,
  ) {
    final text = segment.enhancedText ?? segment.transcription;
    final isProcessing =
        segment.status == SegmentStatus.pending ||
        segment.status == SegmentStatus.transcribing;
    final isEnhancing = segment.status == SegmentStatus.enhancing;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: segment.status == SegmentStatus.error
              ? Colors.red.withValues(alpha: 0.3)
              : _cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间戳
          Row(
            children: [
              Text(
                segment.formattedTimestamp,
                style: TextStyle(
                  fontSize: 11,
                  color: _cs.outline,
                  fontFamily: 'monospace',
                ),
              ),
              if (isProcessing || isEnhancing) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: isEnhancing ? Colors.purple : _cs.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  isEnhancing
                      ? l10n.meetingEnhancing
                      : l10n.meetingTranscribing,
                  style: TextStyle(
                    fontSize: 11,
                    color: isEnhancing ? Colors.purple : _cs.primary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // 文字内容
          if (segment.status == SegmentStatus.error)
            Row(
              children: [
                Text(
                  segment.errorMessage ?? l10n.meetingSegmentError,
                  style: const TextStyle(fontSize: 13, color: Colors.red),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () =>
                      context.read<MeetingProvider>().retrySegment(segment),
                  child: Text(
                    l10n.meetingRetry,
                    style: TextStyle(
                      fontSize: 13,
                      color: _cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            )
          else if (text != null && text.isNotEmpty)
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 300),
              child: SelectableText(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: _cs.onSurface,
                  height: 1.6,
                ),
              ),
            )
          else if (!isProcessing && !isEnhancing)
            Text(
              l10n.meetingNoContent,
              style: TextStyle(
                fontSize: 13,
                color: _cs.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  /// 正在录音的脉冲指示器
  Widget _buildRecordingIndicator(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          _PulsingDot(color: Colors.red),
          const SizedBox(width: 8),
          Text(
            l10n.meetingRecordingSegment,
            style: TextStyle(fontSize: 13, color: _cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _handleBack(MeetingProvider provider, AppLocalizations l10n) {
    // 保存标题
    if (_titleController.text.isNotEmpty && provider.currentMeeting != null) {
      provider.updateMeetingTitle(
        provider.currentMeeting!.id,
        _titleController.text,
      );
    }
    // 直接返回列表，录音在后台继续
    Navigator.pop(context);
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

/// 红点闪烁动画
class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withValues(
              alpha: 0.4 + _controller.value * 0.6,
            ),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
