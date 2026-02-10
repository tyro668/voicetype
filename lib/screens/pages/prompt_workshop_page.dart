import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../models/ai_enhance_config.dart';
import '../../providers/settings_provider.dart';
import '../../services/ai_enhance_service.dart';

class PromptWorkshopPage extends StatefulWidget {
  const PromptWorkshopPage({super.key});

  @override
  State<PromptWorkshopPage> createState() => _PromptWorkshopPageState();
}

class _PromptWorkshopPageState extends State<PromptWorkshopPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _promptController = TextEditingController();
  final _agentNameController = TextEditingController();
  final _testInputController = TextEditingController();
  final _testOutputController = TextEditingController();
  String _defaultPrompt = AiEnhanceConfig.defaultPrompt;
  bool _testing = false;
  String _testError = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      _promptController.text = settings.aiEnhanceConfig.prompt;
      _agentNameController.text = settings.aiEnhanceConfig.agentName;
    });
    _loadDefaultPrompt();
  }

  Future<void> _loadDefaultPrompt() async {
    try {
      final prompt = await rootBundle.loadString(
        'assets/prompts/default_prompt.md',
      );
      if (mounted) {
        setState(() => _defaultPrompt = prompt);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promptController.dispose();
    _agentNameController.dispose();
    _testInputController.dispose();
    _testOutputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '智能体',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '配置智能体名称与提示词，用于控制文本增强的格式与风格。',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          _buildTabs(),
          const SizedBox(height: 16),
          if (_tabController.index == 0)
            _buildCurrentTab()
          else if (_tabController.index == 1)
            _buildCustomTab(settings)
          else
            _buildTestTab(settings),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.black87,
        unselectedLabelColor: Colors.grey.shade500,
        indicatorColor: Colors.black87,
        indicatorWeight: 2,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
        tabs: const [
          Tab(text: '当前'),
          Tab(text: '自定义'),
          Tab(text: '测试'),
        ],
        onTap: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildCurrentTab() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '当前系统智能体提示词',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildCodeBlock(_defaultPrompt),
        ],
      ),
    );
  }

  Widget _buildCustomTab(SettingsProvider settings) {
    final useCustomPrompt = settings.aiEnhanceUseCustomPrompt;
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '自定义智能体提示词',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                '启用自定义提示词',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Switch(
                value: useCustomPrompt,
                onChanged: settings.setAiEnhanceUseCustomPrompt,
              ),
            ],
          ),
          Text(
            useCustomPrompt ? '已启用：文本整理将使用下方自定义提示词' : '已关闭：文本整理将使用系统默认提示词',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            '使用 {agentName} 作为智能体名称占位符。',
            style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: '智能体名称',
            controller: _agentNameController,
            hintText: AiEnhanceConfig.defaultAgentName,
            onChanged: settings.setAiEnhanceAgentName,
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: '系统提示词',
            controller: _promptController,
            hintText: AiEnhanceConfig.defaultPrompt,
            maxLines: 10,
            onChanged: settings.setAiEnhancePrompt,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _savePrompt(settings),
                icon: const Icon(Icons.save, size: 16),
                label: const Text('保存智能体配置'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => _resetPrompt(settings),
                child: const Text('恢复默认'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestTab(SettingsProvider settings) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '测试您的智能体',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '使用当前文本模型与智能体提示词进行测试。',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: '测试输入',
            controller: _testInputController,
            hintText: '输入一段需要润色的文本...',
            maxLines: 5,
            onChanged: (_) {},
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _testing ? null : () => _runTest(settings),
              icon: const Icon(Icons.play_arrow, size: 16),
              label: Text(_testing ? '运行中...' : '运行测试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          if (_testError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _testError,
              style: TextStyle(fontSize: 12, color: Colors.red.shade400),
            ),
          ],
          const SizedBox(height: 12),
          _buildLabeledField(
            label: '输出结果',
            controller: _testOutputController,
            hintText: '输出结果将显示在这里',
            maxLines: 5,
            onChanged: (_) {},
            readOnly: true,
          ),
        ],
      ),
    );
  }

  Future<void> _runTest(SettingsProvider settings) async {
    setState(() {
      _testing = true;
      _testError = '';
    });

    try {
      final config = settings.effectiveAiEnhanceConfig;
      final service = AiEnhanceService(config);
      final result = await service.enhance(_testInputController.text);
      _testOutputController.text = result;
    } catch (e) {
      setState(() {
        _testError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _testing = false;
        });
      }
    }
  }

  void _savePrompt(SettingsProvider settings) {
    settings.setAiEnhancePrompt(_promptController.text);
    settings.setAiEnhanceAgentName(_agentNameController.text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('提示词已保存'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _resetPrompt(SettingsProvider settings) {
    settings.setAiEnhancePrompt(_defaultPrompt);
    settings.setAiEnhanceAgentName(AiEnhanceConfig.defaultAgentName);
    _promptController.text = _defaultPrompt;
    _agentNameController.text = AiEnhanceConfig.defaultAgentName;
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }

  Widget _buildCodeBlock(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(fontSize: 12, height: 1.4),
      ),
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
          onChanged: onChanged,
        ),
      ],
    );
  }
}
