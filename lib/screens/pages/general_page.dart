import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../../models/provider_config.dart';
import '../../providers/settings_provider.dart';
import '../../services/audio_recorder.dart';
import '../../services/overlay_service.dart';

class GeneralPage extends StatefulWidget {
  const GeneralPage({super.key});

  @override
  State<GeneralPage> createState() => _GeneralPageState();
}

class _GeneralPageState extends State<GeneralPage> {
  bool? _micPermission;
  bool? _accessibilityPermission;
  String _currentDeviceName = '';
  bool _preferBuiltIn = true;
  bool _checkingMic = false;
  bool _checkingAccessibility = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadInputDevices();
  }

  Future<void> _loadPermissions() async {
    final recorder = AudioRecorderService();
    final mic = await recorder.hasPermission();
    final accessibility = await OverlayService.checkAccessibility();
    if (mounted) {
      setState(() {
        _micPermission = mic;
        _accessibilityPermission = accessibility;
      });
    }
    recorder.dispose();
  }

  Future<void> _loadInputDevices() async {
    final recorder = AudioRecorderService();
    final devices = await recorder.listInputDevices();
    if (mounted) {
      setState(() {
        _currentDeviceName = _pickDeviceName(devices);
      });
    }
    recorder.dispose();
  }

  String _pickDeviceName(List<InputDevice> devices) {
    if (devices.isEmpty) return '';
    final defaultDevice = devices.firstWhere(
      (d) =>
          d.id.toLowerCase() == 'default' ||
          d.label.toLowerCase().contains('default'),
      orElse: () => devices.first,
    );
    return defaultDevice.label;
  }

  Future<void> _testMicPermission() async {
    setState(() => _checkingMic = true);
    final recorder = AudioRecorderService();
    final result = await recorder.hasPermission();
    if (mounted) {
      setState(() {
        _micPermission = result;
        _checkingMic = false;
      });
    }
    recorder.dispose();
  }

  Future<void> _testAccessibilityPermission() async {
    setState(() => _checkingAccessibility = true);
    final result = await OverlayService.requestAccessibility();
    if (mounted) {
      setState(() {
        _accessibilityPermission = result;
        _checkingAccessibility = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== Activation Mode =====
          const Text(
            'Activation Mode',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _ActivationModeSelector(settings: settings),
          const SizedBox(height: 8),
          Center(
            child: Text(
              settings.activationMode == ActivationMode.tapToTalk
                  ? 'Press hotkey to start recording, press again to stop'
                  : 'Hold hotkey to record, release to stop',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ),
          const SizedBox(height: 32),

          // ===== 听写快捷键 =====
          const Text(
            '听写快捷键',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '配置用于开始和停止语音听写的按键。',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          _HotkeyCapture(settings: settings),
          const SizedBox(height: 36),

          // ===== 权限设置 =====
          const Text(
            '权限设置',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '管理系统权限以获取最佳性能功能。',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          _buildPermissionButtons(),
          const SizedBox(height: 12),
          _buildPermissionHint(),
          const SizedBox(height: 36),

          // ===== 麦克风输入 =====
          const Text(
            '麦克风输入',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '选择用于听写的麦克风。启用"优先使用内置麦克风"可防止使用蓝牙耳机时音频中断。',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          _buildPreferBuiltIn(),
          const SizedBox(height: 12),
          _buildCurrentDevice(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPermissionButtons() {
    return Column(
      children: [
        // 测试麦克风权限
        _PermissionButton(
          icon: Icons.mic_outlined,
          label: '测试麦克风权限',
          status: _micPermission,
          loading: _checkingMic,
          onTap: _testMicPermission,
        ),
        const SizedBox(height: 8),
        // 测试辅助功能权限
        _PermissionButton(
          icon: Icons.accessibility_new_outlined,
          label: '测试辅助功能权限',
          status: _accessibilityPermission,
          loading: _checkingAccessibility,
          onTap: _testAccessibilityPermission,
        ),
        const SizedBox(height: 8),
        // 修复权限问题
        _PermissionButton(
          icon: Icons.build_outlined,
          label: '修复权限问题',
          onTap: () async {
            await _testMicPermission();
            await _testAccessibilityPermission();
          },
        ),
      ],
    );
  }

  Widget _buildPermissionHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8D48A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '如果麦克风提示未出现，请打开声音设置选择输入设备，然后重试。',
            style: TextStyle(
              fontSize: 13,
              color: Colors.brown.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HintActionButton(
                label: '打开声音输入',
                onTap: OverlayService.openSoundInput,
              ),
              _HintActionButton(
                label: '打开麦克风隐私',
                onTap: OverlayService.openMicrophonePrivacy,
              ),
              _HintActionButton(
                label: '打开辅助功能隐私',
                onTap: OverlayService.openAccessibilityPrivacy,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreferBuiltIn() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '优先使用内置麦克风',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '外置麦克风可能导致延迟或降低转录质量',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _preferBuiltIn,
            activeColor: const Color(0xFF6C63FF),
            onChanged: (v) => setState(() => _preferBuiltIn = v),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentDevice() {
    final name = _currentDeviceName.isNotEmpty ? _currentDeviceName : '未检测到麦克风';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC3E6C3)),
      ),
      child: Row(
        children: [
          Icon(Icons.mic, size: 18, color: Colors.green.shade700),
          const SizedBox(width: 10),
          Text(
            'Using: $name',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.green.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 权限按钮 ====================
class _PermissionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool? status; // null=未检测, true=已授权, false=未授权
  final bool loading;
  final VoidCallback onTap;

  const _PermissionButton({
    required this.icon,
    required this.label,
    this.status,
    this.loading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: loading ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (status != null && !loading)
                Icon(
                  status! ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: status! ? Colors.green : Colors.red,
                )
              else if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(icon, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 提示区操作按钮 ====================
class _HintActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _HintActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.brown.shade700,
        side: BorderSide(color: Colors.brown.shade300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

// ==================== 快捷键捕获组件 ====================
class _HotkeyCapture extends StatefulWidget {
  final SettingsProvider settings;
  const _HotkeyCapture({required this.settings});

  @override
  State<_HotkeyCapture> createState() => _HotkeyCaptureState();
}

class _HotkeyCaptureState extends State<_HotkeyCapture> {
  bool _listening = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _listening = true);
        _focusNode.requestFocus();
      },
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _listening
            ? (event) {
                if (event is KeyDownEvent) {
                  widget.settings.setHotkey(event.logicalKey);
                  setState(() => _listening = false);
                }
              }
            : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _listening
                  ? const Color(0xFF6C63FF)
                  : Colors.grey.shade200,
              width: _listening ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F5),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _listening ? '...' : widget.settings.hotkeyLabel,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _listening ? '请按下新的快捷键...' : '点击更改快捷键',
                style: TextStyle(
                  fontSize: 13,
                  color: _listening
                      ? const Color(0xFF6C63FF)
                      : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 激活模式选择器 ====================
class _ActivationModeSelector extends StatelessWidget {
  final SettingsProvider settings;
  const _ActivationModeSelector({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeCard(
            icon: Icons.touch_app_outlined,
            title: 'Tap to Talk',
            subtitle: 'Tap on, tap off',
            selected: settings.activationMode == ActivationMode.tapToTalk,
            onTap: () => settings.setActivationMode(ActivationMode.tapToTalk),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ModeCard(
            icon: Icons.pan_tool_outlined,
            title: 'Push to Talk',
            subtitle: 'Hold to record',
            selected: settings.activationMode == ActivationMode.pushToTalk,
            onTap: () => settings.setActivationMode(ActivationMode.pushToTalk),
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF6C63FF) : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? const Color(0xFF6C63FF) : Colors.grey.shade500,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
