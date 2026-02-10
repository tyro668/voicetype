import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/provider_config.dart';
import '../../providers/settings_provider.dart';
import '../../services/stt_service.dart';

class SttPage extends StatefulWidget {
  const SttPage({super.key});

  @override
  State<SttPage> createState() => _SttPageState();
}

class _SttPageState extends State<SttPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _apiKeyController = TextEditingController();
  final _customBaseUrlController = TextEditingController();
  final _customApiKeyController = TextEditingController();
  final _customModelController = TextEditingController();
  List<SttProviderConfig> _presets = const [];
  int _presetCount = 0;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _presets = settings.sttPresets;
    _presetCount = _presets.length;
    _tabController = TabController(length: _presetCount + 1, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final idx = _presets.indexWhere((p) => p.name == settings.config.name);
      if (idx >= 0) {
        _tabController.animateTo(idx);
      } else {
        _tabController.animateTo(_presetCount);
      }
      _apiKeyController.text = settings.config.apiKey;
      _syncCustomControllers(settings);
    });
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final settings = context.read<SettingsProvider>();
      final idx = _tabController.index;
      if (idx < _presetCount) {
        settings.selectProvider(_presets[idx]);
        _apiKeyController.text = settings.config.apiKey;
      } else {
        _syncCustomControllers(settings);
      }
      setState(() {});
    }
  }

  void _refreshPresets(SettingsProvider settings) {
    if (_presetCount == settings.sttPresets.length) {
      _presets = settings.sttPresets;
      return;
    }

    _presets = settings.sttPresets;
    _presetCount = _presets.length;
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _tabController = TabController(length: _presetCount + 1, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final idx = _presets.indexWhere((p) => p.name == settings.config.name);
      if (idx >= 0) {
        _tabController.animateTo(idx);
      } else {
        _tabController.animateTo(_presetCount);
      }
      setState(() {});
    });
  }

  void _syncCustomControllers(SettingsProvider settings) {
    _customBaseUrlController.text = settings.config.baseUrl;
    _customApiKeyController.text = settings.config.apiKey;
    _customModelController.text = settings.config.model;
  }

  void _applyCustomConfig(SettingsProvider settings) {
    final baseUrl = _customBaseUrlController.text.trim();
    final apiKey = _customApiKeyController.text.trim();
    final model = _customModelController.text.trim().isEmpty
        ? 'whisper-1'
        : _customModelController.text.trim();
    final type = baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1')
        ? SttProviderType.whisper
        : SttProviderType.cloud;
    settings.setConfig(
      SttProviderConfig(
        type: type,
        name: '自定义',
        baseUrl: baseUrl,
        apiKey: apiKey,
        model: model,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _apiKeyController.dispose();
    _customBaseUrlController.dispose();
    _customApiKeyController.dispose();
    _customModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    _refreshPresets(settings);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '语音模型',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '选择用于语音转文字的模型服务提供商。',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          _buildProviderTabs(settings),
          const SizedBox(height: 24),
          if (_tabController.index < _presetCount)
            _buildProviderContent(settings)
          else
            _buildCustomContent(settings),
        ],
      ),
    );
  }

  Widget _buildProviderTabs(SettingsProvider settings) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.black87,
        unselectedLabelColor: Colors.grey.shade500,
        indicatorColor: const Color(0xFF6C63FF),
        indicatorWeight: 2,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.grey.shade200,
        tabs: [
          ..._presets.map(
            (p) => Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    p.type == SttProviderType.whisper
                        ? Icons.computer
                        : Icons.language,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(p.name),
                ],
              ),
            ),
          ),
          const Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.build_outlined, size: 16),
                SizedBox(width: 6),
                Text('自定义'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderContent(SettingsProvider settings) {
    final preset = _presets[_tabController.index];
    final currentModel = settings.config.name == preset.name
        ? settings.config.model
        : preset.model;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'API Key',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            if (preset.apiKeyUrl != null)
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: preset.apiKeyUrl!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('API Key 获取链接已复制'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Text(
                  '获取 API key →',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _apiKeyController,
                obscureText: true,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '输入 API Key...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF6C63FF),
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: (v) => settings.setApiKey(v),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) {
                    _apiKeyController.text = data!.text!;
                    settings.setApiKey(data.text!);
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Paste',
                  style: TextStyle(color: Colors.black87),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          '选择模型',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...preset.availableModels.map(
          (m) => _buildModelTile(settings, m, selected: currentModel == m.id),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _testConnection(settings.config),
              icon: const Icon(Icons.wifi_tethering, size: 16),
              label: const Text('测试连接'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () {
                settings.selectProvider(preset);
                _apiKeyController.clear();
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('默认', style: TextStyle(color: Colors.black54)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModelTile(
    SettingsProvider settings,
    SttModel model, {
    required bool selected,
  }) {
    return GestureDetector(
      onTap: () => settings.setModel(model.id),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF6C63FF) : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.language,
              size: 18,
              color: selected ? const Color(0xFF6C63FF) : Colors.grey.shade400,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.id,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.black87 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    model.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            if (selected)
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 16, color: Color(0xFF6C63FF)),
                  SizedBox(width: 4),
                  Text(
                    '已选择',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _testConnection(SttProviderConfig config) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('正在测试连接...'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
    final stt = SttService(config);
    final ok = await stt.checkAvailability();
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? '连接成功 ✓' : '连接失败，请检查配置'),
        backgroundColor: ok ? Colors.green : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildCustomContent(SettingsProvider settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabeledField(
          label: '端点 URL',
          controller: _customBaseUrlController,
          hintText: 'http://localhost:8080/v1',
          onChanged: (_) => _applyCustomConfig(settings),
        ),
        const SizedBox(height: 12),
        _buildLabeledField(
          label: 'API Key',
          controller: _customApiKeyController,
          hintText: 'sk-...',
          obscureText: true,
          onChanged: (_) => _applyCustomConfig(settings),
        ),
        const SizedBox(height: 12),
        _buildLabeledField(
          label: '模型名称',
          controller: _customModelController,
          hintText: 'whisper-1',
          onChanged: (_) => _applyCustomConfig(settings),
        ),
      ],
    );
  }

  Widget _buildLabeledField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required ValueChanged<String> onChanged,
    bool obscureText = false,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          maxLines: maxLines,
          readOnly: readOnly,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF6C63FF),
                width: 1.5,
              ),
            ),
          ),
          onChanged: readOnly ? null : onChanged,
        ),
      ],
    );
  }
}
