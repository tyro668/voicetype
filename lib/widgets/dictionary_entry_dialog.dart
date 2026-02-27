import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/dictionary_entry.dart';
import '../providers/settings_provider.dart';

/// 词典条目添加/编辑的统一弹窗。
///
/// 返回 `null` 表示用户取消，否则返回用户确认后的 [DictionaryEntry]。
/// - [existing] 非空时为编辑模式，否则为新增模式。
/// - [initialOriginal] 仅新增模式生效，用于预填「原始词」（如右键选中文本）。
Future<DictionaryEntry?> showDictionaryEntryDialog(
  BuildContext context, {
  DictionaryEntry? existing,
  String? initialOriginal,
}) async {
  // 需要从最近的 ancestor 取 settings（dialog builder 中的 ctx 无法访问）
  final settings = context.read<SettingsProvider>();
  final categories = settings.dictionaryCategories;
  final isEditing = existing != null;

  final originalCtrl = TextEditingController(
    text: existing?.original ?? initialOriginal ?? '',
  );
  final correctedCtrl = TextEditingController(text: existing?.corrected ?? '');
  final categoryCtrl = TextEditingController(text: existing?.category ?? '');
  final pinyinCtrl = TextEditingController(
    text: existing?.pinyinPattern ?? existing?.pinyinOverride ?? '',
  );

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => _DictionaryEntryDialogContent(
      isEditing: isEditing,
      originalCtrl: originalCtrl,
      correctedCtrl: correctedCtrl,
      categoryCtrl: categoryCtrl,
      pinyinCtrl: pinyinCtrl,
      categories: categories,
      correctionEnabled: settings.correctionEnabled,
    ),
  );

  if (confirmed != true) return null;

  final orig = originalCtrl.text.trim();
  final corr = correctedCtrl.text.trim();
  final cat = categoryCtrl.text.trim();
  final pin = pinyinCtrl.text.trim();

  if (orig.isEmpty && pin.isEmpty) return null;

  if (isEditing) {
    var updated = existing.copyWith(
      original: orig,
      corrected: corr.isEmpty ? existing.corrected : corr,
      category: cat.isEmpty ? existing.category : cat,
      pinyinPattern: pin.isEmpty ? existing.pinyinPattern : pin,
      pinyinOverride: pin.isEmpty ? existing.pinyinOverride : null,
    );
    if (corr.isEmpty && existing.corrected != null) {
      updated = updated.clearCorrected();
    }
    if (pin.isEmpty) {
      if (existing.pinyinPattern != null) {
        updated = updated.clearPinyinPattern();
      }
      if (existing.pinyinOverride != null) {
        updated = updated.clearPinyinOverride();
      }
    }
    if (cat.isEmpty && existing.category != null) {
      updated = DictionaryEntry(
        id: updated.id,
        original: updated.original,
        corrected: updated.corrected,
        category: null,
        enabled: updated.enabled,
        pinyinOverride: updated.pinyinOverride,
        pinyinPattern: updated.pinyinPattern,
        createdAt: updated.createdAt,
      );
    }
    return updated;
  } else {
    return DictionaryEntry.create(
      original: orig,
      corrected: corr.isEmpty ? null : corr,
      category: cat.isEmpty ? null : cat,
      pinyinPattern: pin.isEmpty ? null : pin,
    );
  }
}

/// 自动计算拼音的纯函数（与 DictionaryEntry._computePinyin 一致）。
String _computeAutoPinyin(String text) {
  if (text.trim().isEmpty) return '';
  try {
    return PinyinHelper.getPinyinE(
      text,
      separator: ' ',
      defPinyin: '#',
      format: PinyinFormat.WITHOUT_TONE,
    ).toLowerCase().replaceAll('#', '').trim().replaceAll(RegExp(r'\s+'), ' ');
  } catch (_) {
    return '';
  }
}

/// 弹窗内容（StatefulWidget），支持根据原始词实时预览拼音。
class _DictionaryEntryDialogContent extends StatefulWidget {
  final bool isEditing;
  final TextEditingController originalCtrl;
  final TextEditingController correctedCtrl;
  final TextEditingController categoryCtrl;
  final TextEditingController pinyinCtrl;
  final List<String> categories;
  final bool correctionEnabled;

  const _DictionaryEntryDialogContent({
    required this.isEditing,
    required this.originalCtrl,
    required this.correctedCtrl,
    required this.categoryCtrl,
    required this.pinyinCtrl,
    required this.categories,
    required this.correctionEnabled,
  });

  @override
  State<_DictionaryEntryDialogContent> createState() =>
      _DictionaryEntryDialogContentState();
}

class _DictionaryEntryDialogContentState
    extends State<_DictionaryEntryDialogContent> {
  late String _autoPinyin;
  bool _editingPinyin = false;

  @override
  void initState() {
    super.initState();
    _autoPinyin = _computeAutoPinyin(widget.originalCtrl.text);
    widget.originalCtrl.addListener(_onOriginalChanged);
  }

  @override
  void dispose() {
    widget.originalCtrl.removeListener(_onOriginalChanged);
    super.dispose();
  }

  void _onOriginalChanged() {
    final newPinyin = _computeAutoPinyin(widget.originalCtrl.text);
    if (newPinyin != _autoPinyin) {
      setState(() => _autoPinyin = newPinyin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.isEditing ? l10n.dictionaryEdit : l10n.dictionaryAdd),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: widget.originalCtrl,
              decoration: InputDecoration(
                labelText: l10n.dictionaryOriginal,
                hintText: l10n.dictionaryOriginalHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.correctedCtrl,
              decoration: InputDecoration(
                labelText: l10n.dictionaryCorrected,
                hintText: l10n.dictionaryCorrectedHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // 分类输入（支持快速选择已有分类）
            Autocomplete<String>(
              initialValue: widget.categoryCtrl.value,
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) return widget.categories;
                return widget.categories.where(
                  (c) => c.toLowerCase().contains(
                    textEditingValue.text.toLowerCase(),
                  ),
                );
              },
              fieldViewBuilder: (ctx, controller, focusNode, onSubmitted) {
                controller.addListener(() {
                  widget.categoryCtrl.text = controller.text;
                });
                if (controller.text.isEmpty &&
                    widget.categoryCtrl.text.isNotEmpty) {
                  controller.text = widget.categoryCtrl.text;
                }
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: l10n.dictionaryCategory,
                    hintText: l10n.dictionaryCategoryHint,
                    border: const OutlineInputBorder(),
                  ),
                );
              },
              onSelected: (value) => widget.categoryCtrl.text = value,
            ),
            // 拼音：自动预览 + 可选编辑
            if (widget.correctionEnabled) ...[
              const SizedBox(height: 10),
              _buildPinyinRow(l10n, cs),
            ],
            const SizedBox(height: 8),
            Text(
              l10n.dictionaryCorrectedTip,
              style: TextStyle(fontSize: 11, color: cs.outline),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(widget.isEditing ? l10n.saveChanges : l10n.confirm),
        ),
      ],
    );
  }

  Widget _buildPinyinRow(AppLocalizations l10n, ColorScheme cs) {
    final displayPinyin = widget.pinyinCtrl.text.trim().isNotEmpty
        ? widget.pinyinCtrl.text.trim()
        : _autoPinyin;
    final isOverridden = widget.pinyinCtrl.text.trim().isNotEmpty;

    if (_editingPinyin) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.pinyinCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: l10n.pinyinOverride,
                hintText: _autoPinyin.isEmpty
                    ? l10n.pinyinOverrideHint
                    : _autoPinyin,
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => setState(() => _editingPinyin = false),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.check, size: 18),
            tooltip: l10n.confirm,
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _editingPinyin = false),
          ),
          if (isOverridden)
            IconButton(
              icon: Icon(Icons.restart_alt, size: 18, color: cs.outline),
              tooltip: l10n.pinyinReset,
              visualDensity: VisualDensity.compact,
              onPressed: () {
                widget.pinyinCtrl.clear();
                setState(() => _editingPinyin = false);
              },
            ),
        ],
      );
    }

    // 只读预览模式
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() => _editingPinyin = true),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(Icons.music_note, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              '${l10n.pinyinPreview}: ',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            Expanded(
              child: Text(
                displayPinyin.isEmpty ? '—' : displayPinyin,
                style: TextStyle(
                  fontSize: 13,
                  color: isOverridden ? cs.primary : cs.onSurface,
                  fontStyle: isOverridden ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),
            Icon(Icons.edit, size: 14, color: cs.outline),
          ],
        ),
      ),
    );
  }
}
