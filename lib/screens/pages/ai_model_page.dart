import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ai_vendor_preset.dart';
import '../../providers/settings_provider.dart';

class AiModelPage extends StatefulWidget {
  const AiModelPage({super.key});

  @override
  State<AiModelPage> createState() => _AiModelPageState();
}

class _AiModelPageState extends State<AiModelPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _aiBaseUrlController = TextEditingController();
  final _aiApiKeyController = TextEditingController();
  final _aiModelController = TextEditingController();
  List<AiVendorPreset> _presets = const [];
  int _presetCount = 0;
  int get _customTabIndex => _presetCount;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _presets = settings.aiPresets;
    _presetCount = _presets.length;
    _tabController = TabController(length: _presetCount + 1, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromSettings(settings);
    });
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final settings = context.read<SettingsProvider>();
    _syncFromSettings(settings, applyPreset: true);
  }

  void _syncFromSettings(
    SettingsProvider settings, {
    bool applyPreset = false,
  }) {
    final current = settings.aiEnhanceConfig;
    _aiBaseUrlController.text = current.baseUrl;
    _aiApiKeyController.text = current.apiKey;
    _aiModelController.text = current.model;

    final modelPresetIndex = _presets.indexWhere(
      (p) => p.models.any((m) => m.id == current.model),
    );
    final presetIndex = modelPresetIndex >= 0
        ? modelPresetIndex
        : _presets.indexWhere((p) => p.baseUrl == current.baseUrl);
    if (!applyPreset) {
      if (presetIndex >= 0) {
        final preset = _presets[presetIndex];
        final modelIds = preset.models.map((m) => m.id).toSet();
        final savedDefault = settings.aiEnhanceDefaultModelFor(preset.baseUrl);
        final resolvedDefault = modelIds.contains(savedDefault)
            ? savedDefault
            : preset.defaultModelId;
        if (preset.baseUrl != current.baseUrl ||
            !modelIds.contains(current.model)) {
          final updated = current.copyWith(
            baseUrl: preset.baseUrl,
            model: resolvedDefault,
          );
          settings.setAiEnhanceConfig(updated);
          _aiBaseUrlController.text = updated.baseUrl;
          _aiModelController.text = updated.model;
        }
        _tabController.animateTo(presetIndex);
      } else {
        _tabController.animateTo(_customTabIndex);
      }
      return;
    }

    if (_tabController.index < _presetCount) {
      final preset = _presets[_tabController.index];
      final modelIds = preset.models.map((m) => m.id).toSet();
      final savedDefault = settings.aiEnhanceDefaultModelFor(preset.baseUrl);
      final resolvedDefault = modelIds.contains(savedDefault)
          ? savedDefault
          : preset.defaultModelId;
      if (preset.baseUrl != current.baseUrl ||
          !modelIds.contains(current.model)) {
        final updated = current.copyWith(
          baseUrl: preset.baseUrl,
          model: resolvedDefault,
        );
        settings.setAiEnhanceConfig(updated);
        _aiBaseUrlController.text = updated.baseUrl;
        _aiModelController.text = updated.model;
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _aiBaseUrlController.dispose();
    _aiApiKeyController.dispose();
    _aiModelController.dispose();
    super.dispose();
  }

  void _refreshPresets(SettingsProvider settings) {
    if (_presetCount == settings.aiPresets.length) {
      _presets = settings.aiPresets;
      return;
    }

    _presets = settings.aiPresets;
    _presetCount = _presets.length;
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _tabController = TabController(length: _presetCount + 1, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncFromSettings(settings);
      setState(() {});
    });
  }

  int _resolvePresetIndex(SettingsProvider settings) {
    final current = settings.aiEnhanceConfig;
    final modelMatch = _presets.indexWhere(
      (p) => p.models.any((m) => m.id == current.model),
    );
    if (modelMatch >= 0) return modelMatch;
    return _presets.indexWhere((p) => p.baseUrl == current.baseUrl);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    _refreshPresets(settings);
    final resolvedIndex = _resolvePresetIndex(settings);
    if (resolvedIndex >= 0 && resolvedIndex != _tabController.index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _tabController.animateTo(resolvedIndex);
      });
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '文本模型',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '用文本模型对识别文本进行纠错和润色。',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          _buildEnableSection(settings),
          const SizedBox(height: 16),
          _buildProviderTabs(),
          const SizedBox(height: 16),
          Stack(
            children: [
              Opacity(
                opacity: settings.aiEnhanceEnabled ? 1.0 : 0.4,
                child: IgnorePointer(
                  ignoring: !settings.aiEnhanceEnabled,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: resolvedIndex >= 0 && resolvedIndex < _presetCount
                        ? _buildPresetContent(settings, resolvedIndex)
                        : _buildCustomContent(settings),
                  ),
                ),
              ),
              if (!settings.aiEnhanceEnabled)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '启用文本增强后可配置模型',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnableSection(SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Text(
            '启用文本增强',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          Switch.adaptive(
            value: settings.aiEnhanceEnabled,
            activeColor: const Color(0xFF6C63FF),
            onChanged: (v) => settings.setAiEnhanceEnabled(v),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderTabs() {
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
                  const Icon(Icons.language, size: 16),
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
        onTap: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildPresetContent(SettingsProvider settings, int presetIndex) {
    final preset = _presets[presetIndex];
    final currentModel = settings.aiEnhanceConfig.baseUrl == preset.baseUrl
        ? settings.aiEnhanceConfig.model
        : preset.defaultModelId;
    final defaultModel = settings.aiEnhanceDefaultModelFor(preset.baseUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabeledField(
          label: 'API Key',
          controller: _aiApiKeyController,
          hintText: 'sk-...',
          obscureText: true,
          onChanged: settings.setAiEnhanceApiKey,
        ),
        const SizedBox(height: 16),
        const Text(
          '选择模型',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...preset.models.map(
          (m) => _buildModelTile(
            m,
            selected: currentModel == m.id,
            onTap: () {
              settings.setAiEnhanceModel(m.id);
              _aiModelController.text = m.id;
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              defaultModel == null ? '默认: 未设置' : '默认: $defaultModel',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () => settings.setAiEnhanceDefaultModel(
                preset.baseUrl,
                currentModel,
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '设为默认',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomContent(SettingsProvider settings) {
    final baseUrl = _aiBaseUrlController.text.trim();
    final defaultModel = baseUrl.isEmpty
        ? null
        : settings.aiEnhanceDefaultModelFor(baseUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabeledField(
          label: '端点 URL',
          controller: _aiBaseUrlController,
          hintText: 'https://api.openai.com/v1',
          onChanged: settings.setAiEnhanceBaseUrl,
        ),
        const SizedBox(height: 12),
        _buildLabeledField(
          label: 'API Key',
          controller: _aiApiKeyController,
          hintText: 'sk-...',
          obscureText: true,
          onChanged: settings.setAiEnhanceApiKey,
        ),
        const SizedBox(height: 12),
        _buildLabeledField(
          label: '模型名称',
          controller: _aiModelController,
          hintText: 'gpt-4o-mini',
          onChanged: settings.setAiEnhanceModel,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              defaultModel == null ? '默认: 未设置' : '默认: $defaultModel',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: baseUrl.isEmpty
                  ? null
                  : () => settings.setAiEnhanceDefaultModel(
                      baseUrl,
                      _aiModelController.text.trim(),
                    ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '设为默认',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ],
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

  Widget _buildModelTile(
    AiModel model, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
                  const SizedBox(height: 4),
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
}
