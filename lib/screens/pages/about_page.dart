import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/modern_ui.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModernSurfaceCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ModernSectionHeader(
                  icon: Icons.waving_hand_outlined,
                  title: '产品信息',
                  subtitle: '应用定位、版本信息与语音工作台说明。',
                  compact: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.mic, color: cs.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      l10n.appTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${l10n.version} 1.0.0',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.appDescription,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.appSlogan,
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
