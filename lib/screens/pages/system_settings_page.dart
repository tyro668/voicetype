import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/network_settings.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/settings_provider.dart';
import '../../services/overlay_service.dart';

class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({super.key});

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  ColorScheme get _cs => Theme.of(context).colorScheme;

  bool _launchAtLogin = false;
  bool _launchAtLoginLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLaunchAtLogin();
  }

  Future<void> _loadLaunchAtLogin() async {
    final enabled = await OverlayService.getLaunchAtLogin();
    if (mounted) {
      setState(() {
        _launchAtLogin = enabled;
        _launchAtLoginLoading = false;
      });
    }
  }

  Future<void> _toggleLaunchAtLogin(bool enabled) async {
    setState(() => _launchAtLoginLoading = true);
    final ok = await OverlayService.setLaunchAtLogin(enabled);
    if (ok) {
      setState(() {
        _launchAtLogin = enabled;
        _launchAtLoginLoading = false;
      });
    } else {
      setState(() => _launchAtLoginLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enabled
                ? AppLocalizations.of(context)!.launchAtLoginFailed
                : AppLocalizations.of(context)!.disableLaunchAtLoginFailed),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final mode = settings.networkProxyMode;
    final l10n = AppLocalizations.of(context)!;

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // ===== 系统设置 =====
          Text(
            l10n.systemSettings,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _buildLaunchAtLoginSection(l10n),
          const SizedBox(height: 36),

          // ===== 网络设置 =====
          Text(
            l10n.networkSettings,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.networkSettingsDescription,
            style: TextStyle(fontSize: 14, color: _cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _buildNetworkProxySection(l10n, settings, mode),
          const SizedBox(height: 40),
        ],
      ),
      ),
    );
  }

  Widget _buildLaunchAtLoginSection(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.power_settings_new_outlined, size: 20, color: _cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.launchAtLogin,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.launchAtLoginDescription,
                  style: TextStyle(fontSize: 12, color: _cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (_launchAtLoginLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch.adaptive(
              value: _launchAtLogin,
              activeTrackColor: _cs.primary,
              onChanged: _toggleLaunchAtLogin,
            ),
        ],
      ),
    );
  }

  Widget _buildNetworkProxySection(
    AppLocalizations l10n,
    SettingsProvider settings,
    NetworkProxyMode mode,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.proxyConfig,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _cs.onSurface,
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
    );
  }
}
