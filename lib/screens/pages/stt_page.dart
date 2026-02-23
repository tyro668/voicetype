import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../l10n/app_localizations.dart';
import '../../models/provider_config.dart';
import '../../models/stt_model_entry.dart';
import '../../providers/settings_provider.dart';
import '../../services/stt_service.dart';

class SttPage extends StatelessWidget {
  const SttPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final entries = settings.sttModelEntries;
    final l10n = AppLocalizations.of(context)!;

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(l10n),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAddDialog(context, settings, l10n),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addVoiceModel),
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

  Widget _buildHeader(AppLocalizations l10n) {
    return Text(
      l10n.voiceModelSettings,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
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
          Icon(Icons.mic_none_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            l10n.noModelsAdded,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.addVoiceModelHint,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(
    BuildContext context,
    SettingsProvider settings,
    SttModelEntry entry,
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
                : () => settings.enableSttModelEntry(entry.id),
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
    SttModelEntry entry,
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

    final config = SttProviderConfig(
      type:
          entry.baseUrl.contains('localhost') ||
              entry.baseUrl.contains('127.0.0.1')
          ? SttProviderType.whisper
          : SttProviderType.cloud,
      name: entry.vendorName,
      baseUrl: entry.baseUrl,
      apiKey: entry.apiKey,
      model: entry.model,
    );

    bool ok = false;
    String message = l10n.connectionFailed;
    try {
      final stt = SttService(config);
      final result = await stt.checkAvailabilityDetailed().timeout(
        const Duration(seconds: 25),
      );
      ok = result.ok;
      message = ok
          ? l10n.connectionSuccess
          : '${l10n.connectionFailed}: ${result.message}';
    } catch (e) {
      ok = false;
      message = '${l10n.connectionFailed}: ${e.toString()}';
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
    SttModelEntry entry,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteModel),
        content: Text(l10n.deleteModelConfirm(entry.vendorName, entry.model)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              settings.removeSttModelEntry(entry.id);
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
        presets: settings.sttPresets,
        onAdd: (entry) => settings.addSttModelEntry(entry),
        l10n: l10n,
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    SettingsProvider settings,
    SttModelEntry entry,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _EditModelDialog(
        entry: entry,
        presets: settings.sttPresets,
        onSave: (updated) => settings.updateSttModelEntry(updated),
        l10n: l10n,
      ),
    );
  }
}

// ==================== 添加模型对话框 ====================
class _AddModelDialog extends StatefulWidget {
  final List<SttProviderConfig> presets;
  final ValueChanged<SttModelEntry> onAdd;
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
  SttProviderConfig? _selectedVendor;
  SttModel? _selectedModel;
  bool _isCustom = false;
  final _apiKeyController = TextEditingController();
  final _customBaseUrlController = TextEditingController();
  final _customModelController = TextEditingController();

  List<SttProviderConfig> get _vendorOptions => widget.presets;

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
                    l10n.addVoiceModel,
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
                  hintText: l10n.enterModelName('whisper-1'),
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

    final entry = SttModelEntry(
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
    final models = _selectedVendor?.availableModels ?? [];
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
  final SttModelEntry entry;
  final List<SttProviderConfig> presets;
  final ValueChanged<SttModelEntry> onSave;
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
  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelController;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.entry.apiKey);
    _baseUrlController = TextEditingController(text: widget.entry.baseUrl);
    _modelController = TextEditingController(text: widget.entry.model);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
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
                    l10n.editVoiceModel,
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
              _buildReadOnlyField(widget.entry.vendorName),
              const SizedBox(height: 12),

              _buildLabel(l10n.endpointUrl, required: true),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _baseUrlController,
                hintText: 'https://api.example.com/v1',
              ),
              const SizedBox(height: 12),

              _buildLabel(l10n.model, required: true),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _modelController,
                hintText: l10n.enterModelName('whisper-1'),
              ),
              const SizedBox(height: 12),

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
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
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

  void _submit() {
    final updated = SttModelEntry(
      id: widget.entry.id,
      vendorName: widget.entry.vendorName,
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      enabled: widget.entry.enabled,
    );
    widget.onSave(updated);
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

  Widget _buildReadOnlyField(String text) {
    return Container(
      width: double.infinity,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
