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

class _PromptWorkshopPageState extends State<PromptWorkshopPage> {
  ColorScheme get _cs => Theme.of(context).colorScheme;

  final _testInputController = TextEditingController();
  final _testOutputController = TextEditingController();
  bool _testing = false;
  String _testError = '';
  String? _previewTemplateId;
  bool _showTest = false;

  @override
  void dispose() {
    _testInputController.dispose();
    _testOutputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use side-by-side layout when wide enough, otherwise stack
        final wide = constraints.maxWidth >= 680;
        if (wide) {
          return _buildSplitLayout(settings, l10n);
        }
        return _buildStackedLayout(settings, l10n);
      },
    );
  }

  // ===== Split layout: list left, detail right =====

  Widget _buildSplitLayout(SettingsProvider settings, AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: template list
        SizedBox(
          width: 280,
          child: _buildTemplateList(settings, l10n),
        ),
        // Divider
        Container(
          width: 1,
          color: _cs.outlineVariant,
        ),
        // Right: detail / test panel
        Expanded(
          child: _buildDetailPanel(settings, l10n),
        ),
      ],
    );
  }

  // ===== Stacked layout for narrow screens =====

  Widget _buildStackedLayout(SettingsProvider settings, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTemplateGrid(settings, l10n),
          const SizedBox(height: 16),
          _buildDetailCard(settings, l10n),
        ],
      ),
    );
  }

  // ===== Template list (left panel) =====

  Widget _buildTemplateList(SettingsProvider settings, AppLocalizations l10n) {
    final templates = settings.promptTemplates;
    return Column(
      children: [
        // Header with add button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
          child: Row(
            children: [
              Icon(Icons.description_outlined, size: 18, color: _cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.promptTemplates,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _cs.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(
                height: 28,
                width: 28,
                child: IconButton(
                  onPressed: () => _showCreateTemplateDialog(settings, l10n),
                  icon: Icon(Icons.add, size: 16, color: _cs.primary),
                  padding: EdgeInsets.zero,
                  tooltip: l10n.promptCreateTemplate,
                ),
              ),
            ],
          ),
        ),
        // Template items
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: templates.length,
            itemBuilder: (_, i) => _buildTemplateListItem(
              templates[i], settings, l10n,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateListItem(
    PromptTemplate template,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    final isActive = settings.activePromptTemplateId == template.id;
    final isPreviewing = _previewTemplateId == template.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: isPreviewing
            ? _cs.secondaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              _previewTemplateId = template.id;
              _showTest = false;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Active indicator
                Container(
                  width: 4,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive ? _cs.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              template.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                                color: isActive ? _cs.primary : _cs.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (template.isBuiltin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: _cs.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l10n.promptBuiltin,
                                style: TextStyle(fontSize: 9, color: _cs.onPrimaryContainer),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        template.summary,
                        style: TextStyle(fontSize: 11, color: _cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Icon(Icons.check_circle, size: 14, color: _cs.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== Detail panel (right side) =====

  Widget _buildDetailPanel(SettingsProvider settings, AppLocalizations l10n) {
    final template = _resolvePreviewTemplate(settings);
    if (template == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app_outlined, size: 40, color: _cs.outlineVariant),
              const SizedBox(height: 12),
              Text(
                l10n.promptSelectHint,
                style: TextStyle(fontSize: 14, color: _cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Template header
          _buildDetailHeader(template, settings, l10n),
          const SizedBox(height: 16),
          // Toggle: preview / test
          _buildDetailToggle(l10n),
          const SizedBox(height: 16),
          if (!_showTest)
            _buildPreviewContent(template)
          else
            _buildTestPanel(settings, l10n),
        ],
      ),
    );
  }

  Widget _buildDetailHeader(
    PromptTemplate template,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    final isActive = settings.activePromptTemplateId == template.id;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                template.name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: _cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                template.summary,
                style: TextStyle(fontSize: 13, color: _cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (!isActive)
          FilledButton.tonalIcon(
            onPressed: () => settings.setActivePromptTemplate(template.id),
            icon: const Icon(Icons.check, size: 16),
            label: Text(l10n.useThisModel, style: const TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _cs.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 14, color: _cs.primary),
                const SizedBox(width: 4),
                Text(
                  l10n.inUse,
                  style: TextStyle(fontSize: 12, color: _cs.primary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        if (!template.isBuiltin) ...[
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'edit') {
                _showEditTemplateDialog(template, settings, l10n);
              } else if (action == 'delete') {
                settings.deletePromptTemplate(template.id);
                setState(() => _previewTemplateId = null);
              }
            },
            icon: Icon(Icons.more_vert, size: 20, color: _cs.onSurfaceVariant),
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
      ],
    );
  }

  Widget _buildDetailToggle(AppLocalizations l10n) {
    return Row(
      children: [
        _buildToggleChip(
          label: l10n.promptPreview,
          icon: Icons.visibility_outlined,
          selected: !_showTest,
          onTap: () => setState(() => _showTest = false),
        ),
        const SizedBox(width: 8),
        _buildToggleChip(
          label: l10n.test,
          icon: Icons.play_arrow_outlined,
          selected: _showTest,
          onTap: () => setState(() => _showTest = true),
        ),
      ],
    );
  }

  Widget _buildToggleChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? _cs.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? _cs.secondary : _cs.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: selected ? _cs.onSecondaryContainer : _cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? _cs.onSecondaryContainer : _cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewContent(PromptTemplate template) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cs.outlineVariant),
      ),
      child: SelectableText(
        template.content,
        style: TextStyle(
          fontSize: 13,
          height: 1.6,
          color: _cs.onSurface,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  // ===== Test panel =====

  Widget _buildTestPanel(SettingsProvider settings, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Input
        _buildFieldLabel(l10n.testInput),
        const SizedBox(height: 6),
        TextField(
          controller: _testInputController,
          maxLines: 4,
          style: const TextStyle(fontSize: 13),
          decoration: _fieldDecoration(l10n.enterTestText),
        ),
        const SizedBox(height: 12),
        // Run button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _testing ? null : () => _runTest(settings),
            icon: _testing
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _cs.onPrimary,
                    ),
                  )
                : const Icon(Icons.play_arrow, size: 16),
            label: Text(
              _testing ? l10n.running : l10n.runTest,
              style: const TextStyle(fontSize: 13),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        if (_testError.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              _testError,
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
          ),
        ],
        const SizedBox(height: 12),
        // Output
        _buildFieldLabel(l10n.outputResult),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _cs.outlineVariant),
          ),
          child: _testOutputController.text.isEmpty
              ? Text(
                  l10n.outputWillAppearHere,
                  style: TextStyle(fontSize: 13, color: _cs.outline),
                )
              : SelectableText(
                  _testOutputController.text,
                  style: TextStyle(fontSize: 13, color: _cs.onSurface, height: 1.5),
                ),
        ),
      ],
    );
  }

  // ===== Template grid for narrow layout =====

  Widget _buildTemplateGrid(SettingsProvider settings, AppLocalizations l10n) {
    final templates = settings.promptTemplates;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.description_outlined, size: 18, color: _cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.promptTemplates,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _cs.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(
              height: 28,
              width: 28,
              child: IconButton(
                onPressed: () => _showCreateTemplateDialog(settings, l10n),
                icon: Icon(Icons.add, size: 16, color: _cs.primary),
                padding: EdgeInsets.zero,
                tooltip: l10n.promptCreateTemplate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: templates.map((t) {
            final isActive = settings.activePromptTemplateId == t.id;
            final isPreviewing = _previewTemplateId == t.id;
            return ChoiceChip(
              label: Text(t.name),
              selected: isPreviewing,
              avatar: isActive ? Icon(Icons.check_circle, size: 16, color: _cs.primary) : null,
              onSelected: (_) {
                setState(() {
                  _previewTemplateId = t.id;
                  _showTest = false;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDetailCard(SettingsProvider settings, AppLocalizations l10n) {
    final template = _resolvePreviewTemplate(settings);
    if (template == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailHeader(template, settings, l10n),
          const SizedBox(height: 16),
          _buildDetailToggle(l10n),
          const SizedBox(height: 16),
          if (!_showTest)
            _buildPreviewContent(template)
          else
            _buildTestPanel(settings, l10n),
        ],
      ),
    );
  }

  // ===== Helpers =====

  PromptTemplate? _resolvePreviewTemplate(SettingsProvider settings) {
    final templates = settings.promptTemplates;
    if (templates.isEmpty) return null;
    final id = _previewTemplateId ?? settings.activePromptTemplateId;
    try {
      return templates.firstWhere((t) => t.id == id);
    } catch (_) {
      return templates.first;
    }
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _cs.onSurfaceVariant,
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _cs.outline, fontSize: 13),
      filled: true,
      fillColor: _cs.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _cs.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _cs.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _cs.primary, width: 1.5),
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
        setState(() => _testing = false);
      }
    }
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
}
