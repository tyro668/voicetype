import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.promptWorkshop,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.promptDescription,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          _buildTabs(l10n),
          const SizedBox(height: 16),
          if (_tabController.index == 0)
            _buildCurrentTab(l10n)
          else if (_tabController.index == 1)
            _buildCustomTab(settings, l10n)
          else
            _buildTestTab(settings, l10n),
        ],
      ),
    );
  }

  Widget _buildTabs(AppLocalizations l10n) {
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
        tabs: [
          Tab(text: l10n.current),
          Tab(text: l10n.custom),
          Tab(text: l10n.test),
        ],
        onTap: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildCurrentTab(AppLocalizations l10n) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.currentSystemPrompt,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildCodeBlock(_defaultPrompt),
        ],
      ),
    );
  }

  Widget _buildCustomTab(SettingsProvider settings, AppLocalizations l10n) {
    final useCustomPrompt = settings.aiEnhanceUseCustomPrompt;
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.customPromptTitle,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                l10n.enableCustomPrompt,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Switch(
                value: useCustomPrompt,
                onChanged: settings.setAiEnhanceUseCustomPrompt,
              ),
            ],
          ),
          Text(
            useCustomPrompt
                ? l10n.customPromptEnabled
                : l10n.customPromptDisabled,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.agentNamePlaceholder('{agentName}'),
            style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: l10n.agentName,
            controller: _agentNameController,
            hintText: AiEnhanceConfig.defaultAgentName,
            onChanged: settings.setAiEnhanceAgentName,
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: l10n.systemPrompt,
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
                label: Text(l10n.saveAgentConfig),
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
                child: Text(l10n.restoreDefault),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestTab(SettingsProvider settings, AppLocalizations l10n) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.testYourAgent,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.testAgentDescription,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: l10n.testInput,
            controller: _testInputController,
            hintText: l10n.enterTestText,
            maxLines: 5,
            onChanged: (_) {},
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _testing ? null : () => _runTest(settings),
              icon: const Icon(Icons.play_arrow, size: 16),
              label: Text(_testing ? l10n.running : l10n.runTest),
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
            label: l10n.outputResult,
            controller: _testOutputController,
            hintText: l10n.outputWillAppearHere,
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
