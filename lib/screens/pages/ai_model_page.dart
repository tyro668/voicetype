import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../l10n/app_localizations.dart';
import '../../models/ai_enhance_config.dart';
import '../../models/ai_model_entry.dart';
import '../../models/ai_vendor_preset.dart';
import '../../providers/settings_provider.dart';
import '../../services/ai_enhance_service.dart';

class AiModelPage extends StatelessWidget {
  const AiModelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final entries = settings.aiModelEntries;
    final l10n = AppLocalizations.of(context)!;

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEnableSection(settings, l10n),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAddDialog(context, settings, l10n),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addTextModel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              _buildEmptyState(context, l10n)
            else
              ...entries.map(
                (entry) => _buildEntryCard(context, settings, entry, l10n),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildEnableSection(SettingsProvider settings, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Text(
            l10n.enableTextEnhancement,
            style: const TextStyle(
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

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.noModelsAdded,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.addTextModelHint,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(
    BuildContext context,
    SettingsProvider settings,
    AiModelEntry entry,
    AppLocalizations l10n,
  ) {
    final isActive = entry.enabled;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFF6C63FF) : Colors.grey.shade200,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.vendorName,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE7F6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l10n.inUse,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6C63FF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  entry.model,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // 测试连接
          IconButton(
            icon: const Icon(Icons.wifi_tethering, size: 18),
            tooltip: l10n.testConnection,
            color: Colors.grey.shade500,
            onPressed: () => _testConnection(context, entry, l10n),
          ),
          // 编辑
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: l10n.edit,
            color: Colors.grey.shade500,
            onPressed: () => _showEditDialog(context, settings, entry, l10n),
          ),
          // 启用/切换
          IconButton(
            icon: Icon(
              isActive ? Icons.check_circle : Icons.check_circle_outline,
              size: 18,
              color: isActive ? Colors.green : Colors.grey.shade400,
            ),
            tooltip: isActive ? l10n.currentlyInUse : l10n.useThisModel,
            onPressed: isActive
                ? null
                : () => settings.enableAiModelEntry(entry.id),
          ),
          // 删除
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: l10n.delete,
            color: Colors.red.shade300,
            onPressed: () => _confirmDelete(context, settings, entry, l10n),
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection(
    BuildContext context,
    AiModelEntry entry,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.testingConnection),
        duration: const Duration(seconds: 20),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // 调试信息
    debugPrint('测试连接 - URL: ${entry.baseUrl}');
    debugPrint('测试连接 - Model: ${entry.model}');
    debugPrint('测试连接 - API Key长度: ${entry.apiKey.length}');

    final config = AiEnhanceConfig(
      baseUrl: entry.baseUrl,
      apiKey: entry.apiKey,
      model: entry.model,
      prompt: AiEnhanceConfig.defaultPrompt,
      agentName: AiEnhanceConfig.defaultAgentName,
    );
    bool ok = false;
    String message = l10n.connectionFailed;
    try {
      final result = await AiEnhanceService(
        config,
      ).checkAvailabilityDetailed().timeout(const Duration(seconds: 25));
      ok = result.ok;
      message = ok
          ? l10n.connectionSuccess
          : '${l10n.connectionFailed}: ${result.message}';
      debugPrint('测试连接结果: $message');
    } catch (e, stackTrace) {
      ok = false;
      message = '${l10n.connectionFailed}: ${e.toString()}';
      debugPrint('测试连接异常: $e');
      debugPrint('堆栈: $stackTrace');
    }

    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ok ? Colors.green : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    SettingsProvider settings,
    AiModelEntry entry,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteModel),
        content: Text(l10n.confirmDeleteModel(entry.vendorName, entry.model)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              settings.removeAiModelEntry(entry.id);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _AddModelDialog(
        presets: settings.aiPresets,
        onAdd: (entry) => settings.addAiModelEntry(entry),
        l10n: l10n,
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    SettingsProvider settings,
    AiModelEntry entry,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _EditModelDialog(
        entry: entry,
        presets: settings.aiPresets,
        onSave: (updated) => settings.updateAiModelEntry(updated),
        l10n: l10n,
      ),
    );
  }
}

// ==================== 添加模型对话框 ====================
class _AddModelDialog extends StatefulWidget {
  final List<AiVendorPreset> presets;
  final ValueChanged<AiModelEntry> onAdd;
  final AppLocalizations l10n;

  const _AddModelDialog({
    required this.presets,
    required this.onAdd,
    required this.l10n,
  });

  @override
  State<_AddModelDialog> createState() => _AddModelDialogState();
}

class _AddModelDialogState extends State<_AddModelDialog> {
  AiVendorPreset? _selectedVendor;
  AiModel? _selectedModel;
  bool _isCustom = false;
  final _apiKeyController = TextEditingController();
  final _customBaseUrlController = TextEditingController();
  final _customModelController = TextEditingController();

  List<AiVendorPreset> get _vendorOptions => widget.presets;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _customBaseUrlController.dispose();
    _customModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    l10n.addTextModel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _buildLabel(l10n.vendor, required: true),
              const SizedBox(height: 6),
              _buildVendorDropdown(l10n),
              const SizedBox(height: 12),

              _buildLabel(l10n.model, required: true),
              const SizedBox(height: 6),
              if (_isCustom)
                _buildTextField(
                  controller: _customModelController,
                  hintText: l10n.enterModelName('gpt-4o-mini'),
                )
              else
                _buildModelDropdown(l10n),
              const SizedBox(height: 12),

              if (_isCustom) ...[
                _buildLabel(l10n.endpointUrl, required: true),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _customBaseUrlController,
                  hintText: 'https://api.openai.com/v1',
                ),
                const SizedBox(height: 12),
              ],

              _buildLabel(l10n.apiKey, required: true),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _apiKeyController,
                hintText: l10n.enterApiKey,
                obscureText: true,
              ),

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    l10n.addModel,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canSubmit {
    if (_apiKeyController.text.trim().isEmpty) return false;
    if (_isCustom) {
      return _customBaseUrlController.text.trim().isNotEmpty &&
          _customModelController.text.trim().isNotEmpty;
    }
    return _selectedModel != null;
  }

  void _submit() {
    final String vendorName;
    final String baseUrl;
    final String model;

    if (_isCustom) {
      vendorName = '自定义';
      baseUrl = _customBaseUrlController.text.trim();
      model = _customModelController.text.trim();
    } else {
      vendorName = _selectedVendor!.name;
      baseUrl = _selectedVendor!.baseUrl;
      model = _selectedModel!.id;
    }

    final entry = AiModelEntry(
      id: const Uuid().v4(),
      vendorName: vendorName,
      baseUrl: baseUrl,
      model: model,
      apiKey: _apiKeyController.text.trim(),
    );
    widget.onAdd(entry);
    Navigator.pop(context);
  }

  Widget _buildLabel(String text, {bool required = false}) {
    return Row(
      children: [
        if (required)
          const Text('* ', style: TextStyle(color: Colors.red, fontSize: 13)),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildVendorDropdown(AppLocalizations l10n) {
    final items = <DropdownMenuItem<String>>[
      ..._vendorOptions.map(
        (p) => DropdownMenuItem(value: p.name, child: Text(p.name)),
      ),
      DropdownMenuItem(value: '__custom__', child: Text(l10n.custom)),
    ];

    String? currentValue;
    if (_isCustom) {
      currentValue = '__custom__';
    } else if (_selectedVendor != null) {
      currentValue = _selectedVendor!.name;
    }

    return Container(
      width: double.infinity,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          isExpanded: true,
          hint: Text(l10n.selectVendor, style: const TextStyle(fontSize: 14)),
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          items: items,
          onChanged: (value) {
            setState(() {
              if (value == '__custom__') {
                _selectedVendor = null;
                _selectedModel = null;
                _isCustom = true;
              } else {
                _selectedVendor = _vendorOptions.firstWhere(
                  (p) => p.name == value,
                );
                _selectedModel = null;
                _isCustom = false;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildModelDropdown(AppLocalizations l10n) {
    final models = _selectedVendor?.models ?? [];
    return Container(
      width: double.infinity,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedModel?.id,
          isExpanded: true,
          hint: Text(l10n.selectModel, style: const TextStyle(fontSize: 14)),
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          items: models
              .map((m) => DropdownMenuItem(value: m.id, child: Text(m.id)))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedModel = models.firstWhere((m) => m.id == value);
            });
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
  }) {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 14),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          filled: true,
          fillColor: const Color(0xFFF5F5F7),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ==================== 编辑模型对话框 ====================
class _EditModelDialog extends StatefulWidget {
  final AiModelEntry entry;
  final List<AiVendorPreset> presets;
  final ValueChanged<AiModelEntry> onSave;
  final AppLocalizations l10n;

  const _EditModelDialog({
    required this.entry,
    required this.presets,
    required this.onSave,
    required this.l10n,
  });

  @override
  State<_EditModelDialog> createState() => _EditModelDialogState();
}

class _EditModelDialogState extends State<_EditModelDialog> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _baseUrlController;
  late String _vendorName;

  @override
  void initState() {
    super.initState();
    _vendorName = widget.entry.vendorName;
    _apiKeyController = TextEditingController(text: widget.entry.apiKey);
    _modelController = TextEditingController(text: widget.entry.model);
    _baseUrlController = TextEditingController(text: widget.entry.baseUrl);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  bool get _isCustom => !widget.presets.any((p) => p.name == _vendorName);

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    l10n.editTextModel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _buildLabel(l10n.vendor),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _vendorName,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              _buildLabel(l10n.model),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _modelController,
                hintText: l10n.model,
              ),
              const SizedBox(height: 12),

              if (_isCustom) ...[
                _buildLabel(l10n.endpointUrl),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _baseUrlController,
                  hintText: 'https://api.openai.com/v1',
                ),
                const SizedBox(height: 12),
              ],

              _buildLabel(l10n.apiKey),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _apiKeyController,
                hintText: l10n.enterApiKey,
                obscureText: true,
              ),

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    l10n.saveChanges,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canSubmit {
    if (_apiKeyController.text.trim().isEmpty) return false;
    if (_modelController.text.trim().isEmpty) return false;
    if (_isCustom && _baseUrlController.text.trim().isEmpty) return false;
    return true;
  }

  void _submit() {
    final updated = AiModelEntry(
      id: widget.entry.id,
      vendorName: _vendorName,
      baseUrl: _isCustom
          ? _baseUrlController.text.trim()
          : widget.entry.baseUrl,
      model: _modelController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
    );
    widget.onSave(updated);
    Navigator.pop(context);
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
  }) {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 14),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          filled: true,
          fillColor: const Color(0xFFF5F5F7),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
