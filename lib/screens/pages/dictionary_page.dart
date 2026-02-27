import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/dictionary_entry.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/dictionary_entry_dialog.dart';

class DictionaryPage extends StatefulWidget {
  const DictionaryPage({super.key});

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<DictionaryPage> {
  ColorScheme get _cs => Theme.of(context).colorScheme;

  /// 当前选中的分类筛选（null = 全部）
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final allEntries = settings.dictionaryEntries;
    final categories = settings.dictionaryCategories;

    // 按分类筛选
    final entries = _selectedCategory == null
        ? allEntries
        : allEntries.where((e) => e.category == _selectedCategory).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 智能纠错开关
          _buildCorrectionToggle(settings, l10n),
          const SizedBox(height: 16),
          // 分类筛选 chips
          if (categories.isNotEmpty) ...[
            _buildCategoryChips(categories, l10n),
            const SizedBox(height: 16),
          ],
          if (entries.isEmpty)
            _buildEmptyState(l10n)
          else
            ...entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildEntryCard(e, settings, l10n),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _handleAddEntry(settings),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.dictionaryAdd),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrectionToggle(
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.spellcheck, size: 20, color: _cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.correctionEnabled,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.correctionDescription,
                  style: TextStyle(fontSize: 11, color: _cs.outline),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: settings.correctionEnabled,
              onChanged: (v) => settings.setCorrectionEnabled(v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(List<String> categories, AppLocalizations l10n) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        FilterChip(
          label: Text(l10n.dictionaryCategoryAll),
          selected: _selectedCategory == null,
          onSelected: (_) => setState(() => _selectedCategory = null),
          visualDensity: VisualDensity.compact,
        ),
        ...categories.map(
          (cat) => FilterChip(
            label: Text(cat),
            selected: _selectedCategory == cat,
            onSelected: (_) => setState(
              () => _selectedCategory = _selectedCategory == cat ? null : cat,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: _cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cs.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.menu_book_outlined, size: 40, color: _cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            l10n.dictionaryEmpty,
            style: TextStyle(fontSize: 14, color: _cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.dictionaryEmptyHint,
            style: TextStyle(fontSize: 12, color: _cs.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(
    DictionaryEntry entry,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    final isCorrection = entry.type == DictionaryEntryType.correction;
    final typeColor = isCorrection ? _cs.primary : _cs.tertiary;

    return Opacity(
      opacity: entry.enabled ? 1.0 : 0.5,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cs.outlineVariant),
        ),
        child: Row(
          children: [
            // 启用/禁用开关
            SizedBox(
              width: 36,
              child: Transform.scale(
                scale: 0.75,
                child: Switch(
                  value: entry.enabled,
                  onChanged: (v) => settings.toggleDictionaryEntry(entry.id, v),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 类型标识
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isCorrection
                    ? l10n.dictionaryTypeCorrection
                    : l10n.dictionaryTypePreserve,
                style: TextStyle(
                  fontSize: 10,
                  color: typeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCorrection)
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 14, color: _cs.onSurface),
                        children: [
                          TextSpan(
                            text: entry.original,
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: _cs.onSurfaceVariant,
                            ),
                          ),
                          const TextSpan(text: ' → '),
                          TextSpan(
                            text: entry.corrected,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      entry.original,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _cs.onSurface,
                      ),
                    ),
                  if (entry.category != null && entry.category!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.category!,
                      style: TextStyle(fontSize: 11, color: _cs.outline),
                    ),
                  ],
                  // 拼音预览
                  if (settings.correctionEnabled) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.pinyinPreview}: ${entry.pinyinNormalized}',
                      style: TextStyle(
                        fontSize: 10,
                        color: _cs.outline.withValues(alpha: 0.6),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: () => _handleEditEntry(settings, entry),
              icon: Icon(
                Icons.edit_outlined,
                size: 18,
                color: _cs.onSurfaceVariant,
              ),
              tooltip: l10n.edit,
            ),
            IconButton(
              onPressed: () => settings.deleteDictionaryEntry(entry.id),
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.red.shade400,
              ),
              tooltip: l10n.delete,
            ),
          ],
        ),
      ),
    );
  }

  /// 统一的添加/编辑对话框
  Future<void> _handleAddEntry(SettingsProvider settings) async {
    final entry = await showDictionaryEntryDialog(context);
    if (entry != null) {
      await settings.addDictionaryEntry(entry);
    }
  }

  Future<void> _handleEditEntry(
    SettingsProvider settings,
    DictionaryEntry existing,
  ) async {
    final entry = await showDictionaryEntryDialog(context, existing: existing);
    if (entry != null) {
      await settings.updateDictionaryEntry(entry);
    }
  }
}
