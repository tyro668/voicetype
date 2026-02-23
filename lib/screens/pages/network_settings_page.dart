import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/network_settings.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/settings_provider.dart';

class NetworkSettingsPage extends StatelessWidget {
  const NetworkSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final settings = context.watch<SettingsProvider>();
    final mode = settings.networkProxyMode;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.networkSettings,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.networkSettingsDescription,
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.proxyConfig,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                RadioListTile<NetworkProxyMode>(
                  value: NetworkProxyMode.system,
                  groupValue: mode,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.useSystemProxy),
                  subtitle: Text(l10n.systemProxySubtitle),
                  onChanged: (value) {
                    if (value != null) {
                      settings.setNetworkProxyMode(value);
                    }
                  },
                ),
                RadioListTile<NetworkProxyMode>(
                  value: NetworkProxyMode.none,
                  groupValue: mode,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.noProxy),
                  subtitle: Text(l10n.noProxySubtitle),
                  onChanged: (value) {
                    if (value != null) {
                      settings.setNetworkProxyMode(value);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
