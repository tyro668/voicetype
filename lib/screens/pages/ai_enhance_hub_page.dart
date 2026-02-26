import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'prompt_workshop_page.dart';
import 'dictionary_page.dart';

/// Container page for "智能增强" (AI Enhancement) that holds
/// sub-navigation between Prompt Settings and Dictionary Settings.
class AiEnhanceHubPage extends StatefulWidget {
  const AiEnhanceHubPage({super.key});

  @override
  State<AiEnhanceHubPage> createState() => _AiEnhanceHubPageState();
}

class _AiEnhanceHubPageState extends State<AiEnhanceHubPage> {
  int _selectedTab = 0;

  ColorScheme get _cs => Theme.of(context).colorScheme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        _buildTabBar(l10n),
        Expanded(
          child: _selectedTab == 0
              ? const PromptWorkshopPage()
              : const DictionaryPage(),
        ),
      ],
    );
  }

  Widget _buildTabBar(AppLocalizations l10n) {
    final tabs = [
      _TabDef(
        icon: Icons.auto_fix_high_outlined,
        label: l10n.promptWorkshop,
      ),
      _TabDef(
        icon: Icons.menu_book_outlined,
        label: l10n.dictionarySettings,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _cs.surface,
        border: Border(bottom: BorderSide(color: _cs.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 0),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final tab = tabs[i];
          final selected = _selectedTab == i;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _selectedTab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? _cs.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab.icon,
                      size: 16,
                      color: selected ? _cs.primary : _cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected ? _cs.primary : _cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TabDef {
  final IconData icon;
  final String label;
  const _TabDef({required this.icon, required this.label});
}
