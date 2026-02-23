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
  ColorScheme get _cs => Theme.of(context).colorScheme;

  late TabController _tabController;
  final _promptController = TextEditingController();
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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.promptDescription,
            style: TextStyle(fontSize: 14, color: _cs.onSurfaceVariant),
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
        color: _cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cs.outlineVariant),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: _cs.onSurface,
        unselectedLabelColor: _cs.onSurfaceVariant,
        indicatorColor: _cs.onSurface,
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
            style: TextStyle(fontSize: 12, color: _cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: l10n.systemPrompt,
            controller: _promptController,
            hintText: AiEnhanceConfig.defaultPrompt,
            maxLines: 10,
            enabled: useCustomPrompt,
            onChanged: settings.setAiEnhancePrompt,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: useCustomPrompt ? () => _savePrompt(settings) : null,
                icon: const Icon(Icons.save, size: 16),
                label: Text(l10n.saveChanges),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cs.onSurface,
                  foregroundColor: _cs.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: useCustomPrompt
                    ? () => _resetPrompt(settings)
                    : null,
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
            style: TextStyle(fontSize: 12, color: _cs.onSurfaceVariant),
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
                backgroundColor: _cs.onSurface,
                foregroundColor: _cs.onPrimary,
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
    _promptController.text = _defaultPrompt;
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cs.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _buildCodeBlock(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cs.outlineVariant),
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
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          maxLines: maxLines,
          readOnly: readOnly,
          enabled: enabled,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: _cs.outline),
            filled: true,
            fillColor: _cs.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _cs.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _cs.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _cs.primary, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _cs.outlineVariant),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
