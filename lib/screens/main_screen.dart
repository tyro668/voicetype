import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/provider_config.dart';
import '../providers/recording_provider.dart';
import '../providers/settings_provider.dart';
import '../services/overlay_service.dart';
import 'pages/general_page.dart';
import 'pages/stt_page.dart';
import 'pages/ai_model_page.dart';
import 'pages/prompt_workshop_page.dart';
import 'pages/history_page.dart';
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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedNav = 0;
  bool _processing = false;
  late VoidCallback _settingsListener;
  bool _didShowAccessibilityGuide = false;

  static const _navItems = [
    _NavItem(icon: Icons.settings_outlined, label: '通用'),
    _NavItem(icon: Icons.mic_outlined, label: '语音模型'),
    _NavItem(icon: Icons.psychology_outlined, label: '文本模型'),
    _NavItem(icon: Icons.auto_fix_high_outlined, label: '智能体'),
    _NavItem(icon: Icons.history_outlined, label: '历史记录'),
    _NavItem(icon: Icons.info_outline, label: '关于'),
  ];

  @override
  void initState() {
    super.initState();
    OverlayService.init();
    OverlayService.onGlobalKeyEvent = _handleGlobalKeyEvent;
    _ensureAccessibilityPermission();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      _settingsListener = () {
        final keyCode = _macKeyCodeFor(settings.hotkey);
        if (keyCode != null) {
          OverlayService.registerHotkey(keyCode: keyCode);
        }
      };
      settings.addListener(_settingsListener);
      _settingsListener();
    });
  }

  Future<void> _ensureAccessibilityPermission() async {
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

  void _showAccessibilityGuide() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('需要辅助功能权限'),
        content: const Text('为实现自动输入，需要在“系统设置 > 隐私与安全性 > 辅助功能”中勾选 VoiceType。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              OverlayService.openAccessibilityPrivacy();
            },
            child: const Text('打开设置'),
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
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('请先配置语音转换模型'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    OverlayService.onGlobalKeyEvent = null;
    final settings = context.read<SettingsProvider>();
    settings.removeListener(_settingsListener);
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

  void _handleGlobalKeyEvent(int keyCode, String type, bool isRepeat) {
    if (isRepeat) return;
    if (_processing) return;

    final settings = context.read<SettingsProvider>();
    final recording = context.read<RecordingProvider>();

    final key = _macKeyCodeMap[keyCode];
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
      backgroundColor: const Color(0xFFF7F7F8),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  const Icon(Icons.mic, color: Color(0xFF6C63FF), size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'VoiceType',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            ...List.generate(_navItems.length, (i) {
              final item = _navItems[i];
              final selected = _selectedNav == i;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Material(
                  color: selected
                      ? const Color(0xFFF0F0F5)
                      : Colors.transparent,
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
                                ? Colors.black87
                                : Colors.grey.shade500,
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
                                  ? Colors.black87
                                  : Colors.grey.shade600,
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
      5 => const AboutPage(),
      _ => const SizedBox(),
    };
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
