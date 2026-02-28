import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/prompt_template.dart';
import '../models/provider_config.dart';
import '../providers/recording_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/meeting_provider.dart';
import '../services/log_service.dart';
import '../services/overlay_service.dart';
import 'pages/dictionary_page.dart';
import 'pages/history_page.dart';
import 'pages/meeting_list_page.dart';
import 'pages/meeting_recording_page.dart';
import 'pages/meeting_dashboard_page.dart';
import 'pages/dashboard_page.dart';
import 'settings_screen.dart';

/// macOS keyCode 到 Flutter LogicalKeyboardKey 的映射
const _macKeyCodeMap = <int, LogicalKeyboardKey>{
  63: LogicalKeyboardKey.fn,
  120: LogicalKeyboardKey.f2,
  99: LogicalKeyboardKey.f3,
  118: LogicalKeyboardKey.f4,
  96: LogicalKeyboardKey.f5,
  97: LogicalKeyboardKey.f6,
  98: LogicalKeyboardKey.f7,
  100: LogicalKeyboardKey.f8,
  101: LogicalKeyboardKey.f9,
  109: LogicalKeyboardKey.f10,
  103: LogicalKeyboardKey.f11,
  111: LogicalKeyboardKey.f12,
  49: LogicalKeyboardKey.space,
  36: LogicalKeyboardKey.enter,
  53: LogicalKeyboardKey.escape,
  48: LogicalKeyboardKey.tab,
};

/// Windows Virtual-Key 到 Flutter LogicalKeyboardKey 的映射
const _windowsKeyCodeMap = <int, LogicalKeyboardKey>{
  0x71: LogicalKeyboardKey.f2,
  0x72: LogicalKeyboardKey.f3,
  0x73: LogicalKeyboardKey.f4,
  0x74: LogicalKeyboardKey.f5,
  0x75: LogicalKeyboardKey.f6,
  0x76: LogicalKeyboardKey.f7,
  0x77: LogicalKeyboardKey.f8,
  0x78: LogicalKeyboardKey.f9,
  0x79: LogicalKeyboardKey.f10,
  0x7A: LogicalKeyboardKey.f11,
  0x7B: LogicalKeyboardKey.f12,
  0x20: LogicalKeyboardKey.space,
  0x0D: LogicalKeyboardKey.enter,
  0x1B: LogicalKeyboardKey.escape,
  0x09: LogicalKeyboardKey.tab,
};

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  ColorScheme get _cs => Theme.of(context).colorScheme;

  String _localizedTemplateName(
    PromptTemplate template,
    AppLocalizations l10n,
  ) {
    if (!template.isBuiltin) return template.name;
    switch (template.id) {
      case PromptTemplate.defaultBuiltinId:
        return l10n.promptBuiltinDefaultName;
      case 'builtin_punctuation':
        return l10n.promptBuiltinPunctuationName;
      case 'builtin_formal':
        return l10n.promptBuiltinFormalName;
      case 'builtin_colloquial':
        return l10n.promptBuiltinColloquialName;
      case 'builtin_translate_en':
        return l10n.promptBuiltinTranslateEnName;
      case 'builtin_meeting':
        return l10n.promptBuiltinMeetingName;
      default:
        return template.name;
    }
  }

  int _selectedNav = 0;
  late VoidCallback _settingsListener;
  SettingsProvider? _settingsProvider;
  bool _didShowAccessibilityGuide = false;
  bool _didShowInputMonitoringGuide = false;
  LogicalKeyboardKey? _lastRegisteredHotkey;
  LogicalKeyboardKey? _lastRegisteredMeetingHotkey;
  bool _fnTapToTalkPressCandidate = false;

  /// 主导航项（首页 / 词典 / 历史记录 / 会议记录）
  List<_NavItem> _getNavItems(AppLocalizations l10n) => [
    _NavItem(icon: Icons.home_outlined, label: l10n.home),
    _NavItem(icon: Icons.menu_book_outlined, label: l10n.dictionarySettings),
    _NavItem(icon: Icons.history_outlined, label: l10n.history),
    _NavItem(
      icon: Icons.record_voice_over_outlined,
      label: l10n.meetingMinutes,
    ),
  ];

  @override
  void initState() {
    super.initState();
    OverlayService.init();
    OverlayService.onGlobalKeyEvent = _handleGlobalKeyEvent;
    _ensureAccessibilityPermission();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      _settingsProvider = settings;
      _settingsListener = () {
        _registerCurrentHotkey(settings);
        _registerMeetingHotkey(settings);
        _ensureInputMonitoringPermissionIfNeeded(settings.hotkey);
      };
      settings.addListener(_settingsListener);
      _settingsListener();
    });
  }

  void _registerCurrentHotkey(SettingsProvider settings) {
    // 只在热键实际变化时才重新注册，避免不必要的反复注册
    if (settings.hotkey == _lastRegisteredHotkey) return;
    _lastRegisteredHotkey = settings.hotkey;

    final keyCode = _platformKeyCodeFor(settings.hotkey);
    if (keyCode == null) return;

    LogService.info('HOTKEY', 'registering hotkey keyCode=$keyCode');
    OverlayService.registerHotkey(keyCode: keyCode).then((ok) {
      LogService.info('HOTKEY', 'registerHotkey result=$ok');
      if (!mounted || ok) return;
      if (settings.hotkey == LogicalKeyboardKey.fn) {
        _showInputMonitoringGuide();
      }
    });
  }

  void _registerMeetingHotkey(SettingsProvider settings) {
    if (settings.meetingHotkey == _lastRegisteredMeetingHotkey) return;
    _lastRegisteredMeetingHotkey = settings.meetingHotkey;

    final keyCode = _platformKeyCodeFor(settings.meetingHotkey);
    if (keyCode == null) return;

    LogService.info('HOTKEY', 'registering meeting hotkey keyCode=$keyCode');
    OverlayService.registerMeetingHotkey(keyCode: keyCode).then((ok) {
      LogService.info('HOTKEY', 'registerMeetingHotkey result=$ok');
    });
  }

  Future<void> _ensureAccessibilityPermission() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) return;
    final granted = await OverlayService.checkAccessibility();
    if (!granted) {
      await OverlayService.requestAccessibility();
      final recheck = await OverlayService.checkAccessibility();
      if (!recheck && mounted && !_didShowAccessibilityGuide) {
        _didShowAccessibilityGuide = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showAccessibilityGuide();
          }
        });
      }
    }
  }

  Future<void> _ensureInputMonitoringPermissionIfNeeded(
    LogicalKeyboardKey hotkey,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.macOS) return;
    if (hotkey != LogicalKeyboardKey.fn) return;
    final granted = await OverlayService.checkInputMonitoring();
    if (granted) return;

    await OverlayService.requestInputMonitoring();
    final recheck = await OverlayService.checkInputMonitoring();
    if (!recheck && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showInputMonitoringGuide();
        }
      });
    }
  }

  void _showInputMonitoringGuide() {
    if (_didShowInputMonitoringGuide) return;
    _didShowInputMonitoringGuide = true;

    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.inputMonitoringRequired),
        content: Text(l10n.inputMonitoringDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.later),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              OverlayService.openInputMonitoringPrivacy();
            },
            child: Text(l10n.openSettings),
          ),
        ],
      ),
    );
  }

  void _showAccessibilityGuide() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.accessibilityRequired),
        content: Text(l10n.accessibilityDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.later),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              OverlayService.openAccessibilityPrivacy();
            },
            child: Text(l10n.openSettings),
          ),
        ],
      ),
    );
  }

  bool _hasValidSttModel(SettingsProvider settings) {
    final model = settings.config.model.trim();
    if (model.isEmpty) return false;
    final preset = settings.currentPreset;
    if (preset != null && preset.availableModels.isNotEmpty) {
      return preset.availableModels.any((m) => m.id == model);
    }
    return true;
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        return Dialog(
          insetPadding: const EdgeInsets.all(32),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: size.width * 0.95,
            height: size.height * 0.9,
            child: const SettingsScreen(),
          ),
        );
      },
    );
  }

  void _promptSttConfig() {
    OverlayService.showMainWindow();
    if (!mounted) return;
    // 打开设置界面，定位到语音模型页面
    _openSettings();
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.pleaseConfigureSttModel),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    OverlayService.onGlobalKeyEvent = null;
    _settingsProvider?.removeListener(_settingsListener);
    super.dispose();
  }

  int? _macKeyCodeFor(LogicalKeyboardKey key) {
    for (final entry in _macKeyCodeMap.entries) {
      if (entry.value == key) {
        return entry.key;
      }
    }
    return null;
  }

  int? _windowsKeyCodeFor(LogicalKeyboardKey key) {
    for (final entry in _windowsKeyCodeMap.entries) {
      if (entry.value == key) {
        return entry.key;
      }
    }
    return null;
  }

  int? _platformKeyCodeFor(LogicalKeyboardKey key) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return _windowsKeyCodeFor(key);
    }
    return _macKeyCodeFor(key);
  }

  LogicalKeyboardKey? _platformKeyFromCode(int keyCode) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return _windowsKeyCodeMap[keyCode];
    }
    return _macKeyCodeMap[keyCode];
  }

  void _handleGlobalKeyEvent(
    int keyCode,
    String type,
    bool isRepeat,
    bool hasModifiers,
  ) {
    if (isRepeat) return;

    // 单键快捷键：有修饰键（Cmd/Ctrl/Alt/Shift）按下时忽略
    if (hasModifiers) return;

    final settings = context.read<SettingsProvider>();
    final key = _platformKeyFromCode(keyCode);
    if (key == null) return;

    // 会议快捷键处理
    if (key == settings.meetingHotkey) {
      _handleMeetingHotkey(type, settings);
      return;
    }

    // 语音输入快捷键处理
    if (key != settings.hotkey) return;

    final recording = context.read<RecordingProvider>();

    LogService.info(
      'HOTKEY',
      'hotkey type=$type state=${recording.state} busy=${recording.busy} mode=${settings.activationMode}',
    );

    var effectiveType = type;

    if (settings.activationMode == ActivationMode.tapToTalk &&
        settings.hotkey == LogicalKeyboardKey.fn) {
      if (type == 'down') {
        _fnTapToTalkPressCandidate = !hasModifiers;
        return;
      }
      if (type == 'up') {
        final shouldTrigger = _fnTapToTalkPressCandidate && !hasModifiers;
        _fnTapToTalkPressCandidate = false;
        if (!shouldTrigger) return;
        effectiveType = 'down';
      } else {
        return;
      }
    }

    if (recording.busy) return;

    if (settings.activationMode == ActivationMode.tapToTalk) {
      if (effectiveType == 'down') {
        if (recording.state == RecordingState.recording) {
          // 防止重复触发 stop
          recording.stopAndTranscribe(
            settings.config,
            aiEnhanceEnabled: settings.aiEnhanceEnabled,
            aiEnhanceConfig: settings.effectiveAiEnhanceConfig,
            minRecordingSeconds: settings.minRecordingSeconds,
            useStreaming: settings.aiEnhanceEnabled,
          );
        } else if (recording.state == RecordingState.idle) {
          if (!_hasValidSttModel(settings)) {
            _promptSttConfig();
            return;
          }
          _configureCorrection(settings, recording);
          recording.startRecording(settings.config);
          _startVadIfEnabled(settings, recording);
        }
        // transcribing 状态下忽略
      }
    } else {
      // push-to-talk 模式
      if (type == 'down' && recording.state == RecordingState.idle) {
        if (!_hasValidSttModel(settings)) {
          _promptSttConfig();
          return;
        }
        _configureCorrection(settings, recording);
        recording.startRecording(settings.config);
        _startVadIfEnabled(settings, recording);
      } else if (type == 'up' && recording.state == RecordingState.recording) {
        recording.stopAndTranscribe(
          settings.config,
          aiEnhanceEnabled: settings.aiEnhanceEnabled,
          aiEnhanceConfig: settings.effectiveAiEnhanceConfig,
          minRecordingSeconds: settings.minRecordingSeconds,
          useStreaming: settings.aiEnhanceEnabled,
        );
      }
    }
  }

  void _handleMeetingHotkey(String type, SettingsProvider settings) {
    if (type != 'down') return;

    final meeting = context.read<MeetingProvider>();
    LogService.info(
      'HOTKEY',
      'meeting hotkey: isRecording=${meeting.isRecording}',
    );

    if (meeting.isRecording) {
      // 正在录制 → 结束会议
      unawaited(meeting.stopMeetingFast());
    } else {
      // 未录制 → 开始新会议
      if (!_hasValidSttModel(settings)) {
        _promptSttConfig();
        return;
      }
      meeting.startMeeting(
        sttConfig: settings.config,
        aiConfig: settings.effectiveAiEnhanceConfig,
        aiEnhanceEnabled: settings.aiEnhanceEnabled,
        dictionarySuffix: settings.dictionaryWordsForPrompt,
        pinyinMatcher: settings.correctionEffective
            ? settings.pinyinMatcher
            : null,
        correctionPrompt: settings.correctionEffective
            ? settings.correctionPrompt
            : null,
        maxReferenceEntries: settings.correctionMaxReferenceEntries,
        minCandidateScore: settings.correctionMinCandidateScore,
      );
    }
  }

  /// 根据 SettingsProvider 状态配置或禁用纠错服务。
  void _configureCorrection(
    SettingsProvider settings,
    RecordingProvider recording,
  ) {
    if (settings.correctionEffective) {
      recording.configureCorrectionService(
        matcher: settings.pinyinMatcher,
        aiConfig: settings.effectiveAiEnhanceConfig,
        correctionPrompt: settings.correctionPrompt,
        maxReferenceEntries: settings.correctionMaxReferenceEntries,
        minCandidateScore: settings.correctionMinCandidateScore,
      );
    } else {
      recording.disableCorrectionService();
    }
    // 终态回溯开关同步
    recording.retrospectiveCorrectionEnabled =
        settings.retrospectiveCorrectionEnabled;
  }

  void _startVadIfEnabled(
    SettingsProvider settings,
    RecordingProvider recording,
  ) {
    if (!settings.vadEnabled) return;
    recording.onVadTriggered = () {
      if (recording.state == RecordingState.recording && !recording.busy) {
        recording.stopAndTranscribe(
          settings.config,
          aiEnhanceEnabled: settings.aiEnhanceEnabled,
          aiEnhanceConfig: settings.effectiveAiEnhanceConfig,
          minRecordingSeconds: settings.minRecordingSeconds,
          useStreaming: settings.aiEnhanceEnabled,
        );
      }
    };
    recording.startVad(
      silenceThreshold: settings.vadSilenceThreshold,
      silenceDurationSeconds: settings.vadSilenceDurationSeconds,
      minRecordingSeconds: settings.minRecordingSeconds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    context.read<RecordingProvider>().setOverlayStateLabels(
      starting: l10n.overlayStarting,
      recording: l10n.overlayRecording,
      transcribing: l10n.overlayTranscribing,
      enhancing: l10n.overlayEnhancing,
      transcribeFailed: l10n.overlayTranscribeFailed,
    );
    context.read<MeetingProvider>().setOverlayStateLabels(
      starting: l10n.meetingOverlayStarting,
      recording: l10n.meetingOverlayRecording,
      processing: l10n.meetingOverlayProcessing,
    );
    OverlayService.setTrayLabels(open: l10n.trayOpen, quit: l10n.trayQuit);

    return Scaffold(
      backgroundColor: _cs.surfaceContainerLow,
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final l10n = AppLocalizations.of(context)!;
    final navItems = _getNavItems(l10n);
    final settings = context.watch<SettingsProvider>();
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: _cs.surface,
        border: Border(right: BorderSide(color: _cs.outlineVariant)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _cs.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _cs.outlineVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Icon(
                      Icons.mic_rounded,
                      color: _cs.onSurfaceVariant,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.appTitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _cs.onSurface,
                        letterSpacing: 0.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Divider(
                height: 1,
                thickness: 1,
                color: _cs.outlineVariant,
              ),
            ),
            const SizedBox(height: 4),
            ...List.generate(navItems.length, (i) {
              final item = navItems[i];
              final selected = _selectedNav == i;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Material(
                  color: selected ? _cs.secondaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _selectedNav = i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 18,
                            color: selected
                                ? _cs.onSurface
                                : _cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: selected
                                  ? _cs.onSurface
                                  : _cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Divider(
                height: 1,
                thickness: 1,
                color: _cs.outlineVariant,
              ),
            ),
            // 底部设置按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _openSettings,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.settings_outlined,
                          size: 18,
                          color: _cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          l10n.settings,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: _cs.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        _buildPromptTemplateSelector(settings, l10n),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptTemplateSelector(
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    final templates = settings.promptTemplates;
    if (templates.isEmpty) return const SizedBox.shrink();

    final activeTemplateId =
        templates.any(
          (template) => template.id == settings.activePromptTemplateId,
        )
        ? settings.activePromptTemplateId
        : templates.first.id;
    final activeTemplateIndex = templates.indexWhere(
      (template) => template.id == activeTemplateId,
    );
    final activeTemplateNumber = activeTemplateIndex >= 0
        ? activeTemplateIndex + 1
        : 1;

    return PopupMenuButton<String>(
      tooltip: l10n.promptTemplates,
      initialValue: activeTemplateId,
      onSelected: (templateId) {
        if (templateId == settings.activePromptTemplateId) return;
        settings.setActivePromptTemplate(templateId);
      },
      itemBuilder: (_) => templates.map((template) {
        return CheckedPopupMenuItem<String>(
          value: template.id,
          checked: template.id == activeTemplateId,
          child: SizedBox(
            width: 180,
            child: Text(
              _localizedTemplateName(template, l10n),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }).toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_fix_high_outlined,
              size: 14,
              color: _cs.onSurfaceVariant.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 2),
            Text(
              '#$activeTemplateNumber',
              style: TextStyle(
                fontSize: 10,
                color: _cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final Widget page = switch (_selectedNav) {
      0 => const DashboardPage(),
      1 => const DictionaryPage(),
      2 => const HistoryPage(),
      3 => const MeetingDashboardPage(),
      _ => const SizedBox(),
    };

    final meetingProvider = context.watch<MeetingProvider>();
    // 会议仪表盘页面已内嵌实时录制面板，其他页面仍显示录制横幅
    if (!meetingProvider.isRecording || _selectedNav == 3) return page;

    return Column(
      children: [
        _buildRecordingBanner(meetingProvider),
        Expanded(child: page),
      ],
    );
  }

  Widget _buildRecordingBanner(MeetingProvider meetingProvider) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();
    final duration = meetingProvider.recordingDuration;
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = duration.inHours;
    final timeStr = h > 0 ? '$h:$m:$s' : '$m:$s';

    return Material(
      color: Colors.red.withValues(alpha: 0.08),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: meetingProvider,
                child: MeetingRecordingPage(
                  sttConfig: settings.config,
                  aiConfig: settings.effectiveAiEnhanceConfig,
                  aiEnhanceEnabled: settings.aiEnhanceEnabled,
                  dictionarySuffix: settings.dictionaryWordsForPrompt,
                ),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.meetingRecordingBanner,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                timeStr,
                style: TextStyle(
                  color: Colors.red.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                l10n.meetingReturnToRecording,
                style: TextStyle(
                  color: _cs.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: _cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
