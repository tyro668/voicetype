import 'dart:convert';
import 'dart:io';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/dictionary_entry.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/recording_provider.dart';
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
  final TextEditingController _searchCtrl = TextEditingController();
  _EntryStatusFilter _statusFilter = _EntryStatusFilter.all;
  int _rowsPerPage = 100;
  int _currentPage = 0;

  static const List<int> _pageSizeOptions = [50, 100, 200, 500];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final allEntries = settings.dictionaryEntries;
    final categories = settings.dictionaryCategories;
    final search = _searchCtrl.text.trim().toLowerCase();

    final entries = allEntries.where((entry) {
      if (_selectedCategory != null && entry.category != _selectedCategory) {
        return false;
      }
      if (_statusFilter == _EntryStatusFilter.enabledOnly && !entry.enabled) {
        return false;
      }
      if (_statusFilter == _EntryStatusFilter.disabledOnly && entry.enabled) {
        return false;
      }
      if (search.isEmpty) return true;
      final inOriginal = entry.original.toLowerCase().contains(search);
      final inCorrected = (entry.corrected ?? '').toLowerCase().contains(
        search,
      );
      final inCategory = (entry.category ?? '').toLowerCase().contains(search);
      final inPinyin = entry.pinyinNormalized.toLowerCase().contains(search);
      return inOriginal || inCorrected || inCategory || inPinyin;
    }).toList();

    entries.sort((a, b) {
      if (a.enabled != b.enabled) {
        return a.enabled ? -1 : 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    final enabledCount = allEntries.where((e) => e.enabled).length;
    final disabledCount = allEntries.length - enabledCount;

    final totalPages = entries.isEmpty
        ? 1
        : ((entries.length - 1) ~/ _rowsPerPage) + 1;
    if (_currentPage >= totalPages) {
      _currentPage = totalPages - 1;
    }
    final pageStart = _currentPage * _rowsPerPage;
    final pageEntries = entries
        .skip(pageStart)
        .take(_rowsPerPage)
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 智能纠错开关
          _buildCorrectionToggle(settings, l10n),
          const SizedBox(height: 16),
          // 一体化表格卡片
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cs.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── 顶部工具栏：搜索 + 筛选 + 添加 ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                    child: Row(
                      children: [
                        // 搜索框
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (_) => _resetToFirstPage(),
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: l10n.dictionarySearchHint,
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: _cs.outline,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  size: 18,
                                  color: _cs.outline,
                                ),
                                suffixIcon: _searchCtrl.text.isEmpty
                                    ? null
                                    : IconButton(
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          _resetToFirstPage();
                                        },
                                        icon: Icon(
                                          Icons.close,
                                          size: 14,
                                          color: _cs.outline,
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: _cs.outlineVariant,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: _cs.outlineVariant,
                                  ),
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 状态筛选下拉
                        _buildDropdownFilter<_EntryStatusFilter>(
                          value: _statusFilter,
                          items: [
                            (_EntryStatusFilter.all, l10n.dictionaryFilterAll),
                            (
                              _EntryStatusFilter.enabledOnly,
                              l10n.dictionaryFilterEnabled,
                            ),
                            (
                              _EntryStatusFilter.disabledOnly,
                              l10n.dictionaryFilterDisabled,
                            ),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _statusFilter = v;
                              _currentPage = 0;
                            });
                          },
                        ),
                        // 分类筛选下拉
                        if (categories.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          _buildDropdownFilter<String?>(
                            value: _selectedCategory,
                            items: [
                              (null, l10n.dictionaryCategoryAll),
                              ...categories.map((c) => (c, c)),
                            ],
                            onChanged: (v) {
                              setState(() {
                                _selectedCategory = v;
                                _currentPage = 0;
                              });
                            },
                          ),
                        ],
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () => _handleExportCsv(settings, l10n),
                          icon: Icon(
                            Icons.download_outlined,
                            size: 20,
                            color: _cs.onSurfaceVariant,
                          ),
                          tooltip: l10n.dictionaryExportCsv,
                        ),
                        IconButton(
                          onPressed: () => _handleImportCsv(settings, l10n),
                          icon: Icon(
                            Icons.upload_outlined,
                            size: 20,
                            color: _cs.onSurfaceVariant,
                          ),
                          tooltip: l10n.dictionaryImportCsv,
                        ),
                        const SizedBox(width: 4),
                        // 添加按钮
                        IconButton(
                          onPressed: () => _handleAddEntry(settings),
                          icon: Icon(
                            Icons.add_circle_outline,
                            size: 22,
                            color: _cs.primary,
                          ),
                          tooltip: l10n.dictionaryAdd,
                        ),
                      ],
                    ),
                  ),
                  // ── 统计 + 分页行 ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${l10n.dictionaryCountTotal} ${allEntries.length}',
                          style: TextStyle(fontSize: 11, color: _cs.outline),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${l10n.dictionaryCountEnabled} $enabledCount',
                          style: TextStyle(fontSize: 11, color: _cs.outline),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${l10n.dictionaryCountDisabled} $disabledCount',
                          style: TextStyle(fontSize: 11, color: _cs.outline),
                        ),
                        const Spacer(),
                        Text(
                          l10n.dictionaryPageSummary(
                            entries.isEmpty ? 0 : pageStart + 1,
                            pageStart + pageEntries.length,
                            entries.length,
                          ),
                          style: TextStyle(fontSize: 11, color: _cs.outline),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 28,
                          child: DropdownButton<int>(
                            value: _rowsPerPage,
                            underline: const SizedBox.shrink(),
                            isDense: true,
                            style: TextStyle(
                              fontSize: 12,
                              color: _cs.onSurface,
                            ),
                            items: _pageSizeOptions
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text('$e'),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _rowsPerPage = v;
                                _currentPage = 0;
                              });
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: _currentPage > 0
                              ? () => setState(() => _currentPage -= 1)
                              : null,
                          icon: const Icon(Icons.chevron_left, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          tooltip: l10n.dictionaryPagePrev,
                        ),
                        Text(
                          '${_currentPage + 1}/$totalPages',
                          style: TextStyle(fontSize: 11, color: _cs.outline),
                        ),
                        IconButton(
                          onPressed: _currentPage + 1 < totalPages
                              ? () => setState(() => _currentPage += 1)
                              : null,
                          icon: const Icon(Icons.chevron_right, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          tooltip: l10n.dictionaryPageNext,
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: _cs.outlineVariant),
                  // ── 表格主体 ──
                  if (entries.isEmpty)
                    _buildEmptyState(l10n)
                  else
                    Expanded(
                      child: DataTable2(
                        columnSpacing: 12,
                        horizontalMargin: 16,
                        minWidth: 760,
                        headingRowHeight: 36,
                        dataRowHeight: 44,
                        headingRowColor: WidgetStateProperty.all(
                          _cs.surfaceContainerHighest.withValues(alpha: 0.4),
                        ),
                        headingTextStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _cs.onSurfaceVariant,
                        ),
                        columns: [
                          const DataColumn2(label: Text('#'), fixedWidth: 44),
                          DataColumn2(
                            label: Text(l10n.dictionaryFilterEnabled),
                            fixedWidth: 60,
                          ),
                          DataColumn2(
                            label: Text(l10n.dictionaryTypeCorrection),
                            fixedWidth: 68,
                          ),
                          DataColumn2(
                            label: Text(l10n.dictionaryOriginal),
                            size: ColumnSize.L,
                          ),
                          DataColumn2(
                            label: Text(l10n.dictionaryCorrected),
                            size: ColumnSize.L,
                          ),
                          DataColumn2(
                            label: Text(l10n.dictionaryCategoryAll),
                            size: ColumnSize.S,
                          ),
                          if (settings.correctionEnabled)
                            DataColumn2(
                              label: Text(l10n.pinyinPreview),
                              size: ColumnSize.M,
                            ),
                          DataColumn2(label: Text(l10n.edit), fixedWidth: 88),
                        ],
                        rows: pageEntries
                            .asMap()
                            .entries
                            .map((e) {
                              final idx = pageStart + e.key + 1;
                              final entry = e.value;
                              final isCorr =
                                  entry.type == DictionaryEntryType.correction;
                              final typeClr = isCorr
                                  ? _cs.primary
                                  : _cs.tertiary;

                              return DataRow2(
                                color: WidgetStateProperty.resolveWith<Color?>(
                                  (states) => !entry.enabled
                                      ? _cs.surfaceContainerHighest.withValues(
                                          alpha: 0.3,
                                        )
                                      : null,
                                ),
                                cells: [
                                  DataCell(
                                    Text(
                                      '$idx',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _cs.outline,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Center(
                                      child: Transform.scale(
                                        scale: 0.6,
                                        child: Switch(
                                          value: entry.enabled,
                                          onChanged: (v) =>
                                              settings.toggleDictionaryEntry(
                                                entry.id,
                                                v,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: typeClr.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isCorr
                                            ? l10n.dictionaryTypeCorrection
                                            : l10n.dictionaryTypePreserve,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: typeClr,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      entry.original.trim().isEmpty
                                          ? '—'
                                          : entry.original,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isCorr
                                            ? _cs.onSurfaceVariant
                                            : _cs.onSurface,
                                        decoration: isCorr
                                            ? TextDecoration.lineThrough
                                            : null,
                                        fontWeight: isCorr
                                            ? FontWeight.normal
                                            : FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      entry.corrected ?? '—',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _cs.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DataCell(
                                    entry.category != null &&
                                            entry.category!.isNotEmpty
                                        ? _buildMetaTag(
                                            entry.category!,
                                            _cs.tertiary,
                                          )
                                        : Text(
                                            '—',
                                            style: TextStyle(
                                              color: _cs.outline,
                                            ),
                                          ),
                                  ),
                                  if (settings.correctionEnabled)
                                    DataCell(
                                      Text(
                                        entry.pinyinNormalized,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _cs.outline,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: () =>
                                              _handleEditEntry(settings, entry),
                                          icon: Icon(
                                            Icons.edit_outlined,
                                            size: 15,
                                            color: _cs.onSurfaceVariant,
                                          ),
                                          tooltip: l10n.edit,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 30,
                                            minHeight: 30,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () => settings
                                              .deleteDictionaryEntry(entry.id),
                                          icon: Icon(
                                            Icons.delete_outline,
                                            size: 15,
                                            color: _cs.error,
                                          ),
                                          tooltip: l10n.delete,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 30,
                                            minHeight: 30,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter<T>({
    required T value,
    required List<(T, String)> items,
    required ValueChanged<T> onChanged,
  }) {
    return SizedBox(
      height: 36,
      child: PopupMenuButton<T>(
        initialValue: value,
        onSelected: onChanged,
        tooltip: '',
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _cs.outlineVariant),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                items.firstWhere((e) => e.$1 == value).$2,
                style: TextStyle(fontSize: 12, color: _cs.onSurface),
              ),
              const SizedBox(width: 2),
              Icon(Icons.arrow_drop_down, size: 18, color: _cs.outline),
            ],
          ),
        ),
        itemBuilder: (_) => items
            .map(
              (e) => PopupMenuItem<T>(
                value: e.$1,
                height: 36,
                child: Text(e.$2, style: const TextStyle(fontSize: 13)),
              ),
            )
            .toList(growable: false),
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
                Row(
                  children: [
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.retrospectiveCorrectionEnabled,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.retrospectiveCorrectionDescription,
                            style: TextStyle(fontSize: 11, color: _cs.outline),
                          ),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: settings.retrospectiveCorrectionEnabled,
                        onChanged: settings.correctionEnabled
                            ? (v) =>
                                  settings.setRetrospectiveCorrectionEnabled(v)
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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

  /// 统一的添加/编辑对话框
  Future<void> _handleAddEntry(SettingsProvider settings) async {
    final entry = await showDictionaryEntryDialog(context);
    if (entry != null) {
      await settings.addDictionaryEntry(entry);
      await _applySessionGlossaryOverride(entry);
    }
  }

  Future<void> _handleEditEntry(
    SettingsProvider settings,
    DictionaryEntry existing,
  ) async {
    final entry = await showDictionaryEntryDialog(context, existing: existing);
    if (entry != null) {
      await settings.updateDictionaryEntry(entry);
      await _applySessionGlossaryOverride(entry);
    }
  }

  Future<void> _applySessionGlossaryOverride(DictionaryEntry entry) async {
    if (entry.type != DictionaryEntryType.correction) return;
    final corrected = (entry.corrected ?? '').trim();
    if (corrected.isEmpty) return;

    final recording = Provider.of<RecordingProvider?>(context, listen: false);
    final meeting = Provider.of<MeetingProvider?>(context, listen: false);
    recording?.applySessionGlossaryOverride(entry.original, corrected);
    meeting?.applySessionGlossaryOverride(entry.original, corrected);
  }

  Future<void> _handleExportCsv(
    SettingsProvider settings,
    AppLocalizations l10n,
  ) async {
    try {
      final now = DateTime.now();
      final fileName =
          'dictionary_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.csv';

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.dictionaryExportCsv,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (savePath == null || savePath.trim().isEmpty) return;

      final targetPath = savePath.toLowerCase().endsWith('.csv')
          ? savePath
          : '$savePath.csv';
      final csv = settings.exportDictionaryAsCsv();
      await File(targetPath).writeAsString('\uFEFF$csv', encoding: utf8);

      _showSnackBar(l10n.dictionaryExportSuccess(targetPath));
    } catch (_) {
      _showSnackBar(l10n.dictionaryExportFailed, isError: true);
    }
  }

  Future<void> _handleImportCsv(
    SettingsProvider settings,
    AppLocalizations l10n,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: l10n.dictionaryImportCsv,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null || path.trim().isEmpty) {
        _showSnackBar(l10n.dictionaryImportFailed, isError: true);
        return;
      }

      final csvContent = await File(path).readAsString(encoding: utf8);
      final imported = await settings.importDictionaryFromCsv(csvContent);
      _resetToFirstPage();

      _showSnackBar(
        l10n.dictionaryImportSuccess(
          imported.importedRows,
          imported.skippedRows,
          imported.totalRows,
        ),
      );
    } on FormatException {
      _showSnackBar(l10n.dictionaryImportInvalidFormat, isError: true);
    } catch (_) {
      _showSnackBar(l10n.dictionaryImportFailed, isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _cs.error : null,
      ),
    );
  }

  Widget _buildMetaTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color.withValues(alpha: 0.1),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: color)),
    );
  }

  void _resetToFirstPage() {
    setState(() {
      _currentPage = 0;
    });
  }
}

enum _EntryStatusFilter { all, enabledOnly, disabledOnly }
