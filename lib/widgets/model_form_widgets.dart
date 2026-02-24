import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// 表单字段标签（带可选必填标记）
class FormFieldLabel extends StatelessWidget {
  final String text;
  final bool required;

  const FormFieldLabel(this.text, {super.key, this.required = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (required)
          const Text('* ', style: TextStyle(color: Colors.red, fontSize: 13)),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

/// 统一样式的下拉选择框
class StyledDropdown<T> extends StatelessWidget {
  final T? value;
  final String hintText;
  final List<StyledDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;

  const StyledDropdown({
    super.key,
    required this.value,
    required this.hintText,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 42,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        hint: Text(hintText, style: TextStyle(fontSize: 14, color: cs.outline)),
        style: TextStyle(fontSize: 14, color: cs.onSurface),
        icon: Icon(Icons.unfold_more_rounded, size: 18, color: cs.onSurfaceVariant),
        dropdownColor: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        decoration: InputDecoration(
          filled: true,
          fillColor: cs.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: cs.primary, width: 1.5),
          ),
        ),
        items: items
            .map((item) => DropdownMenuItem<T>(
                  value: item.value,
                  child: Text(
                    item.label,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

/// 下拉选项数据
class StyledDropdownItem<T> {
  final T value;
  final String label;
  const StyledDropdownItem({required this.value, required this.label});
}

/// 统一样式的文本输入框
class StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final ValueChanged<String>? onChanged;

  const StyledTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 42,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 14),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: cs.outline, fontSize: 14),
          filled: true,
          fillColor: cs.surfaceContainerHighest,
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

/// 空状态卡片（无模型时展示）
class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: cs.outline),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 13, color: cs.outline)),
        ],
      ),
    );
  }
}

/// 模型卡片（STT / AI 模型通用）
class ModelEntryCard extends StatelessWidget {
  final String vendorName;
  final String modelName;
  final bool isActive;
  final AppLocalizations l10n;
  final VoidCallback onTest;
  final VoidCallback onEdit;
  final VoidCallback? onEnable;
  final VoidCallback onDelete;

  const ModelEntryCard({
    super.key,
    required this.vendorName,
    required this.modelName,
    required this.isActive,
    required this.l10n,
    required this.onTest,
    required this.onEdit,
    required this.onEnable,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? cs.primary : cs.outlineVariant,
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
                      vendorName,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
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
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l10n.inUse,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  modelName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.wifi_tethering, size: 18),
            tooltip: l10n.testConnection,
            color: cs.onSurfaceVariant,
            onPressed: onTest,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: l10n.edit,
            color: cs.onSurfaceVariant,
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(
              isActive ? Icons.check_circle : Icons.check_circle_outline,
              size: 18,
              color: isActive ? Colors.green : cs.outline,
            ),
            tooltip: isActive ? l10n.currentlyInUse : l10n.useThisModel,
            onPressed: onEnable,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: l10n.delete,
            color: Colors.red.shade300,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
