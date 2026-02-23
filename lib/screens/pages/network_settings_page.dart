import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/network_settings.dart';
import '../../providers/settings_provider.dart';

class NetworkSettingsPage extends StatelessWidget {
  const NetworkSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final mode = settings.networkProxyMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '网络设置',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '配置应用的网络代理模式。',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '代理配置',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                RadioListTile<NetworkProxyMode>(
                  value: NetworkProxyMode.system,
                  groupValue: mode,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('使用系统代理'),
                  subtitle: const Text('请求遵循系统网络代理配置。'),
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
                  title: const Text('不使用代理'),
                  subtitle: const Text('所有请求直连，不走任何代理。'),
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
