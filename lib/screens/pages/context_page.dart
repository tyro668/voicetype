import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/markdown_term_import_result.dart';
import '../../models/term_context_entry.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/modern_ui.dart';

class ContextPage extends StatefulWidget {
  final bool embedded;

  const ContextPage({super.key, this.embedded = false});

  @override
  State<ContextPage> createState() => _ContextPageState();
}

class _ContextPageState extends State<ContextPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selectedIds = <String>{};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  ColorScheme get _cs => Theme.of(context).colorScheme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final search = _searchCtrl.text.trim().toLowerCase();
    final entries =
        settings.termContextEntries
            .where((entry) {
              if (search.isEmpty) return true;
              return entry.sourceName.toLowerCase().contains(search) ||
                  entry.displayTitle.toLowerCase().contains(search) ||
                  (entry.content ?? '').toLowerCase().contains(search);
            })
            .toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _selectedIds.removeWhere((id) => !entries.any((entry) => entry.id == id));

    final content = ModernSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildToolbar(settings, entries, l10n),
          const SizedBox(height: 18),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: entries.isEmpty
                  ? _buildEmptyState(l10n)
                  : ListView.separated(
                      key: ValueKey(entries.length),
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _buildEntryCard(settings, entries[index], l10n),
                    ),
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: content,
    );
  }

  Widget _buildToolbar(
    SettingsProvider settings,
    List<TermContextEntry> entries,
    AppLocalizations l10n,
  ) {
    final allSelected =
        entries.isNotEmpty && _selectedIds.length == entries.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 960;
        final summaryText = _selectedIds.isNotEmpty
            ? l10n.contextSelectedCount(_selectedIds.length)
            : l10n.contextCount(entries.length);

        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (entries.isNotEmpty)
              FilterChip(
                selected: allSelected,
                onSelected: (_) => _toggleSelectAll(entries),
                label: Text(l10n.contextSelectAll),
                selectedColor: _cs.primaryContainer.withValues(alpha: 0.72),
                side: BorderSide(
                  color: _cs.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
            if (_selectedIds.isNotEmpty)
              ShadButton.outline(
                onPressed: () => _handleBulkDelete(settings, l10n),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete_outline, size: 16),
                    const SizedBox(width: 8),
                    Text(l10n.contextDeleteSelected),
                  ],
                ),
              ),
          ],
        );

        final searchField = ShadInput(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          placeholder: Text(l10n.contextSearchHint),
          leading: Icon(Icons.search, size: 18, color: _cs.onSurfaceVariant),
        );

        final importButton = ShadButton(
          onPressed: () => _handleImportMarkdown(settings, l10n),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.upload_file_outlined, size: 16),
              const SizedBox(width: 8),
              Text(l10n.contextImportMarkdown),
            ],
          ),
        );

        final summary = Text(
          summaryText,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _cs.onSurfaceVariant,
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 10),
                  importButton,
                ],
              ),
              if (entries.isNotEmpty || _selectedIds.isNotEmpty) ...[
                const SizedBox(height: 12),
                actions,
              ],
              const SizedBox(height: 14),
              summary,
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 12),
                importButton,
                const SizedBox(width: 12),
                summary,
              ],
            ),
            if (entries.isNotEmpty || _selectedIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Flexible(child: actions),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 16).clamp(0, double.infinity),
            ),
            child: Center(
              child: Text(
                l10n.contextEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: _cs.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEntryCard(
    SettingsProvider settings,
    TermContextEntry entry,
    AppLocalizations l10n,
  ) {
    final selected = _selectedIds.contains(entry.id);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cs.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected
              ? _cs.primary.withValues(alpha: 0.7)
              : _cs.outlineVariant.withValues(
                  alpha: entry.enabled ? 0.5 : 0.25,
                ),
          width: selected ? 1.4 : 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    entry.displayTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _cs.onSurface,
                    ),
                  ),
                  _buildMetaChip(entry.enabled ? '启用中' : '已停用'),
                  _buildMetaChip(entry.sourceName),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                entry.contentPreview.isEmpty
                    ? l10n.contextContentEmpty
                    : entry.contentPreview,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: _cs.onSurfaceVariant,
                ),
              ),
            ],
          );

          final controls = Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.enabled ? '启用' : '停用',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: entry.enabled,
                    onChanged: (value) =>
                        settings.setTermContextEntryEnabled(entry.id, value),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => _handleDelete(settings, entry, l10n),
                tooltip: l10n.delete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: selected,
                      onChanged: (_) => _toggleSelection(entry.id),
                    ),
                    const SizedBox(width: 4),
                    Expanded(child: info),
                  ],
                ),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: controls),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: selected,
                onChanged: (_) => _toggleSelection(entry.id),
              ),
              const SizedBox(width: 8),
              Expanded(child: info),
              const SizedBox(width: 12),
              controls,
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _cs.onSurfaceVariant,
        ),
      ),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (!_selectedIds.add(id)) {
        _selectedIds.remove(id);
      }
    });
  }

  void _toggleSelectAll(List<TermContextEntry> entries) {
    setState(() {
      if (_selectedIds.length == entries.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(entries.map((entry) => entry.id));
      }
    });
  }

  Future<void> _handleDelete(
    SettingsProvider settings,
    TermContextEntry entry,
    AppLocalizations l10n,
  ) async {
    await settings.removeTermContextEntry(entry.id);
    _selectedIds.remove(entry.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.contextDeleteSuccess(entry.displayTitle))),
    );
    setState(() {});
  }

  Future<void> _handleBulkDelete(
    SettingsProvider settings,
    AppLocalizations l10n,
  ) async {
    final ids = _selectedIds.toList(growable: false);
    await settings.removeTermContextEntries(ids);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.contextDeleteSelectedSuccess(ids.length))),
    );
    setState(_selectedIds.clear);
  }

  Future<void> _handleImportMarkdown(
    SettingsProvider settings,
    AppLocalizations l10n,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: l10n.contextImportDialogTitle,
        type: FileType.custom,
        allowMultiple: true,
        allowedExtensions: const ['md', 'markdown'],
      );
      if (result == null || result.files.isEmpty) return;

      final previews = <MarkdownTermImportResult>[];
      for (final file in result.files) {
        final path = file.path;
        if (path == null || path.trim().isEmpty) continue;
        final markdown = await File(path).readAsString(encoding: utf8);
        previews.add(
          settings.previewContextMarkdownImport(markdown, fileName: file.name),
        );
      }

      if (!mounted || previews.isEmpty) return;
      final confirmed = await _showImportPreview(previews);
      if (!confirmed || !mounted) return;

      var contextCount = 0;
      for (final preview in previews) {
        final applied = await settings.applyTermContextMarkdownImport(preview);
        contextCount += applied.contextEntries.length;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.contextImportSuccess(contextCount, 0, 0, 0)),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.contextImportFailed)));
    }
  }

  Future<bool> _showImportPreview(
    List<MarkdownTermImportResult> previews,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final contextCount = previews.fold<int>(
      0,
      (sum, item) => sum + item.contextEntries.length,
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.contextImportPreviewTitle),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.contextImportPreviewSummary(
                    previews.length,
                    contextCount,
                    0,
                    0,
                    0,
                    0,
                  ),
                ),
                const SizedBox(height: 12),
                ...previews.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(
                            ctx,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.fileName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.contextEntries.isEmpty
                                ? l10n.contextContentEmpty
                                : item.contextEntries.first.contentPreview,
                          ),
                          if (item.warnings.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...item.warnings.map(
                              (warning) => Text(
                                warning,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(ctx).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
