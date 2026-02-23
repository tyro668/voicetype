import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/provider_config.dart';
import '../providers/recording_provider.dart';
import '../providers/settings_provider.dart';
import '../services/overlay_service.dart';
import 'pages/general_page.dart';
import 'pages/stt_page.dart';
import 'pages/ai_model_page.dart';
import 'pages/prompt_workshop_page.dart';
import 'pages/history_page.dart';
import 'pages/network_settings_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/about_page.dart';

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

/// Windows VK 虚拟键码 到 Flutter LogicalKeyboardKey 的映射
const _winKeyCodeMap = <int, LogicalKeyboardKey>{
  0x71: LogicalKeyboardKey.f2, // VK_F2
  0x72: LogicalKeyboardKey.f3, // VK_F3
  0x73: LogicalKeyboardKey.f4, // VK_F4
  0x74: LogicalKeyboardKey.f5, // VK_F5
  0x75: LogicalKeyboardKey.f6, // VK_F6
  0x76: LogicalKeyboardKey.f7, // VK_F7
  0x77: LogicalKeyboardKey.f8, // VK_F8
  0x78: LogicalKeyboardKey.f9, // VK_F9
  0x79: LogicalKeyboardKey.f10, // VK_F10
  0x7A: LogicalKeyboardKey.f11, // VK_F11
  0x7B: LogicalKeyboardKey.f12, // VK_F12
  0x20: LogicalKeyboardKey.space, // VK_SPACE
  0x0D: LogicalKeyboardKey.enter, // VK_RETURN
  0x1B: LogicalKeyboardKey.escape, // VK_ESCAPE
  0x09: LogicalKeyboardKey.tab, // VK_TAB
};

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  ColorScheme get _cs => Theme.of(context).colorScheme;

  int _selectedNav = 0;
  bool _processing = false;
  late VoidCallback _settingsListener;
  SettingsProvider? _settingsProvider;
  bool _didShowAccessibilityGuide = false;
  bool _didShowInputMonitoringGuide = false;

  List<_NavItem> _getNavItems(AppLocalizations l10n) => [
    _NavItem(icon: Icons.settings_outlined, label: l10n.generalSettings),
    _NavItem(icon: Icons.mic_outlined, label: l10n.voiceModelSettings),
    _NavItem(icon: Icons.psychology_outlined, label: l10n.textModelSettings),
    _NavItem(icon: Icons.auto_fix_high_outlined, label: l10n.promptWorkshop),
    _NavItem(icon: Icons.history_outlined, label: l10n.history),
    _NavItem(icon: Icons.language_outlined, label: l10n.networkSettings),
    _NavItem(icon: Icons.dashboard_outlined, label: l10n.dashboard),
    _NavItem(icon: Icons.info_outline, label: l10n.about),
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
        _ensureInputMonitoringPermissionIfNeeded(settings.hotkey);
      };
      settings.addListener(_settingsListener);
      _settingsListener();
    });
  }

  void _registerCurrentHotkey(SettingsProvider settings) {
    final keyCode = _nativeKeyCodeFor(settings.hotkey);
    if (keyCode == null) return;

    OverlayService.registerHotkey(keyCode: keyCode).then((ok) {
      if (!mounted || ok) return;
      if (Platform.isMacOS && settings.hotkey == LogicalKeyboardKey.fn) {
        _showInputMonitoringGuide();
      }
    });
  }

  Future<void> _ensureAccessibilityPermission() async {
    // Windows 不需要辅助功能权限检查
    if (!Platform.isMacOS) return;

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
    // 输入监控权限仅 macOS 需要
    if (!Platform.isMacOS) return;
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

  void _promptSttConfig() {
    OverlayService.showMainWindow();
    if (!mounted) return;
    setState(() => _selectedNav = 1);
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

  /// 获取当前平台的 keyCode 映射表
  Map<int, LogicalKeyboardKey> get _platformKeyCodeMap =>
      Platform.isWindows ? _winKeyCodeMap : _macKeyCodeMap;

  int? _nativeKeyCodeFor(LogicalKeyboardKey key) {
    for (final entry in _platformKeyCodeMap.entries) {
      if (entry.value == key) {
        return entry.key;
      }
    }
    return null;
  }

  void _handleGlobalKeyEvent(int keyCode, String type, bool isRepeat) {
    if (isRepeat) return;
    if (_processing) return;

    final settings = context.read<SettingsProvider>();
    final recording = context.read<RecordingProvider>();

    final key = _platformKeyCodeMap[keyCode];
    if (key == null) return;
    if (key != settings.hotkey) return;

    if (settings.activationMode == ActivationMode.tapToTalk) {
      if (type == 'down') {
        _processing = true;
        if (recording.state == RecordingState.recording) {
          recording
              .stopAndTranscribe(
                settings.config,
                aiEnhanceEnabled: settings.aiEnhanceEnabled,
                aiEnhanceConfig: settings.effectiveAiEnhanceConfig,
                minRecordingSeconds: settings.minRecordingSeconds,
              )
              .whenComplete(() {
                _processing = false;
              });
        } else {
          if (!_hasValidSttModel(settings)) {
            _promptSttConfig();
            _processing = false;
            return;
          }
          recording.startRecording().whenComplete(() {
            _processing = false;
          });
        }
      }
    } else {
      if (type == 'down' && recording.state != RecordingState.recording) {
        _processing = true;
        if (!_hasValidSttModel(settings)) {
          _promptSttConfig();
          _processing = false;
          return;
        }
        recording.startRecording().whenComplete(() {
          _processing = false;
        });
      } else if (type == 'up' && recording.state == RecordingState.recording) {
        _processing = true;
        recording
            .stopAndTranscribe(
              settings.config,
              aiEnhanceEnabled: settings.aiEnhanceEnabled,
              aiEnhanceConfig: settings.effectiveAiEnhanceConfig,
              minRecordingSeconds: settings.minRecordingSeconds,
            )
            .whenComplete(() {
              _processing = false;
            });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Icon(Icons.mic, color: _cs.primary, size: 22),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'VoiceType',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _cs.onSurface,
                      ),
                    ),
                  ),
                ],
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
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return switch (_selectedNav) {
      0 => const GeneralPage(),
      1 => const SttPage(),
      2 => const AiModelPage(),
      3 => const PromptWorkshopPage(),
      4 => const HistoryPage(),
      5 => const NetworkSettingsPage(),
      6 => const DashboardPage(),
      7 => const AboutPage(),
      _ => const SizedBox(),
    };
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
