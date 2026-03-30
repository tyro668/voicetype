import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../widgets/modern_ui.dart';
import 'pages/general_page.dart';
import 'pages/stt_page.dart';
import 'pages/ai_model_page.dart';
import 'pages/ai_enhance_hub_page.dart';
import 'pages/system_settings_page.dart';
import 'pages/about_page.dart';

/// 设置界面 — 自带左侧子导航栏，以弹窗形式展示。
class SettingsScreen extends StatefulWidget {
  final int initialIndex;

  const SettingsScreen({super.key, this.initialIndex = 0});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 5);
  }

  ColorScheme get _cs => Theme.of(context).colorScheme;

  List<_SettingsNavItem> _getItems(AppLocalizations l10n) => [
    _SettingsNavItem(icon: Icons.tune_outlined, label: l10n.generalSettings),
    _SettingsNavItem(icon: Icons.mic_outlined, label: l10n.voiceModelSettings),
    _SettingsNavItem(
      icon: Icons.psychology_outlined,
      label: l10n.textModelSettings,
    ),
    _SettingsNavItem(
      icon: Icons.auto_fix_high_outlined,
      label: l10n.aiEnhanceHub,
    ),
    _SettingsNavItem(icon: Icons.computer_outlined, label: l10n.systemSettings),
    _SettingsNavItem(icon: Icons.info_outline, label: l10n.about),
  ];

  Widget _buildPage() {
    return switch (_selectedIndex) {
      0 => const GeneralPage(),
      1 => const SttPage(),
      2 => const AiModelPage(),
      3 => const AiEnhanceHubPage(),
      4 => const SystemSettingsPage(),
      5 => const AboutPage(),
      _ => const SizedBox(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = _getItems(l10n);

    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(32, 32),
                    backgroundColor: Color.alphaBlend(
                      _cs.primary.withValues(alpha: 0.02),
                      _cs.surface,
                    ),
                    side: BorderSide(
                      color: _cs.primary.withValues(alpha: 0.08),
                    ),
                  ),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: _cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: ModernSurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Row(
                    children: [
                      Container(
                        width: 220,
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                        decoration: BoxDecoration(
                          color: Color.alphaBlend(
                            _cs.primary.withValues(alpha: 0.025),
                            _cs.surfaceContainerLow.withValues(alpha: 0.72),
                          ),
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(22),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...List.generate(items.length, (i) {
                              final item = items[i];
                              final selected = _selectedIndex == i;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 3,
                                ),
                                child: Material(
                                  color: selected
                                      ? _cs.primary.withValues(alpha: 0.09)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () =>
                                        setState(() => _selectedIndex = i),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: selected
                                                  ? _cs.primary.withValues(
                                                      alpha: 0.08,
                                                    )
                                                  : Color.alphaBlend(
                                                      _cs.primary.withValues(
                                                        alpha: 0.015,
                                                      ),
                                                      _cs.surface,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(11),
                                            ),
                                            child: Icon(
                                              item.icon,
                                              size: 16,
                                              color: selected
                                                  ? _cs.primary
                                                  : _cs.onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Flexible(
                                            child: Text(
                                              item.label,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: selected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: selected
                                                    ? _cs.onSurface
                                                    : _cs.onSurfaceVariant,
                                              ),
                                              overflow: TextOverflow.ellipsis,
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
                      Expanded(
                        child: Container(
                          color: Color.alphaBlend(
                            _cs.primary.withValues(alpha: 0.01),
                            _cs.surface.withValues(alpha: 0.82),
                          ),
                          child: _buildPage(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsNavItem {
  final IconData icon;
  final String label;
  const _SettingsNavItem({required this.icon, required this.label});
}
