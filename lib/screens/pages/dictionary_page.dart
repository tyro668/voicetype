import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/dictionary_entry.dart';
import '../../providers/settings_provider.dart';

class DictionaryPage extends StatefulWidget {
  const DictionaryPage({super.key});

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<DictionaryPage> {
  ColorScheme get _cs => Theme.of(context).colorScheme;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final entries = settings.dictionaryEntries;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entries.isEmpty)
            _buildEmptyState(l10n)
          else
            ...entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildEntryCard(e, settings, l10n),
            )),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAddDialog(settings, l10n),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.bookmark_outline, size: 18, color: _cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.word,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _cs.onSurface,
                  ),
                ),
                if (entry.description != null && entry.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: _cs.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showEditDialog(entry, settings, l10n),
            icon: Icon(Icons.edit_outlined, size: 18, color: _cs.onSurfaceVariant),
            tooltip: l10n.edit,
          ),
          IconButton(
            onPressed: () => settings.deleteDictionaryEntry(entry.id),
            icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
            tooltip: l10n.delete,
          ),
        ],
      ),
    );
  }

  void _showAddDialog(SettingsProvider settings, AppLocalizations l10n) {
    final wordController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dictionaryAdd),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: wordController,
                decoration: InputDecoration(
                  labelText: l10n.dictionaryWord,
                  hintText: l10n.dictionaryWordHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: l10n.dictionaryWordDescription,
                  hintText: l10n.dictionaryWordDescriptionHint,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
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
              if (wordController.text.trim().isEmpty) return;
              final entry = DictionaryEntry.create(
                word: wordController.text.trim(),
                description: descController.text.trim().isEmpty
                    ? null
                    : descController.text.trim(),
              );
              settings.addDictionaryEntry(entry);
              Navigator.pop(ctx);
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
    DictionaryEntry entry,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    final wordController = TextEditingController(text: entry.word);
    final descController = TextEditingController(text: entry.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dictionaryEdit),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: wordController,
                decoration: InputDecoration(
                  labelText: l10n.dictionaryWord,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: l10n.dictionaryWordDescription,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
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
              if (wordController.text.trim().isEmpty) return;
              settings.updateDictionaryEntry(
                entry.copyWith(
                  word: wordController.text.trim(),
                  description: descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                ),
              );
              Navigator.pop(ctx);
            },
            child: Text(l10n.saveChanges),
          ),
        ],
      ),
    );
  }
}
