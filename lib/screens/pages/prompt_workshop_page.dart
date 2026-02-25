import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/prompt_template.dart';
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
  final _testInputController = TextEditingController();
  final _testOutputController = TextEditingController();
  bool _testing = false;
  String _testError = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
            _buildTemplatesTab(settings, l10n)
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
          Tab(text: l10n.promptTemplates),
          Tab(text: l10n.test),
        ],
        onTap: (_) => setState(() {}),
      ),
    );
  }

  // ===== Tab 1: Templates =====

  Widget _buildTemplatesTab(SettingsProvider settings, AppLocalizations l10n) {
    final templates = settings.promptTemplates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...templates.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildTemplateCard(t, settings, l10n),
        )),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showCreateTemplateDialog(settings, l10n),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.promptCreateTemplate),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(
    PromptTemplate template,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    final isActive = settings.activePromptTemplateId == template.id;
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ignore: deprecated_member_use
              Radio<String?>(
                value: template.id,
                // ignore: deprecated_member_use
                groupValue: settings.activePromptTemplateId,
                // ignore: deprecated_member_use
                onChanged: (_) =>
                    settings.setActivePromptTemplate(template.id),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          template.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.w600,
                            color: isActive ? _cs.primary : _cs.onSurface,
                          ),
                        ),
                        if (template.isBuiltin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _cs.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l10n.promptBuiltin,
                              style: TextStyle(
                                fontSize: 10,
                                color: _cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                        if (isActive) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.check_circle,
                              size: 16, color: _cs.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.summary,
                      style: TextStyle(
                        fontSize: 12,
                        color: _cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showPreviewTemplateDialog(template),
                icon: Icon(Icons.visibility_outlined, size: 18, color: _cs.onSurfaceVariant),
              ),
              if (!template.isBuiltin)
                PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'edit') {
                      _showEditTemplateDialog(template, settings, l10n);
                    } else if (action == 'delete') {
                      settings.deletePromptTemplate(template.id);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit, size: 16),
                          const SizedBox(width: 8),
                          Text(l10n.edit),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red.shade400),
                          const SizedBox(width: 8),
                          Text(l10n.delete, style: TextStyle(color: Colors.red.shade400)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPreviewTemplateDialog(PromptTemplate template) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(template.name),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: SelectableText(
              template.content,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.confirm),
          ),
        ],
      ),
    );
  }

  void _showEditTemplateDialog(
    PromptTemplate template,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    final contentController = TextEditingController(text: template.content);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${l10n.edit}: ${template.name}'),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: contentController,
            decoration: InputDecoration(
              labelText: l10n.promptTemplateContent,
              border: const OutlineInputBorder(),
            ),
            maxLines: 10,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              settings.updatePromptTemplate(
                template.copyWith(
                  content: contentController.text,
                  summary: PromptTemplate.defaultSummaryFromContent(
                    contentController.text,
                  ),
                ),
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.promptTemplateSaved),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(l10n.saveChanges),
          ),
        ],
      ),
    );
  }

  void _showCreateTemplateDialog(
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    final nameController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.promptCreateTemplate),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.promptTemplateName,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                decoration: InputDecoration(
                  labelText: l10n.promptTemplateContent,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 6,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              final template = PromptTemplate.create(
                name: nameController.text.trim(),
                content: contentController.text.trim(),
              );
              settings.addPromptTemplate(template);
              Navigator.pop(ctx);
            },
            child: Text(l10n.confirm),
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
      _testOutputController.text = result.text;
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
