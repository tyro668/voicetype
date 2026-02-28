import 'dart:convert';

import '../database/app_database.dart';
import '../models/correction_change_log.dart';

class CorrectionChangeLogService {
  CorrectionChangeLogService._();
  static final instance = CorrectionChangeLogService._();

  static const _key = 'correction_change_logs';
  static const _maxRecords = 200;

  Future<void> recordChange({
    required String source,
    required String inputText,
    required String outputText,
    required List<CorrectionTermPair> terms,
  }) async {
    final input = inputText.trim();
    final output = outputText.trim();
    if (input.isEmpty || output.isEmpty || input == output) return;

    final db = await AppDatabase.getInstance();
    final current = await getRecent(limit: _maxRecords);
    final next = <CorrectionChangeLog>[
      CorrectionChangeLog(
        createdAt: DateTime.now(),
        source: source,
        inputText: input,
        outputText: output,
        terms: terms,
      ),
      ...current,
    ];

    final capped = next.take(_maxRecords).toList(growable: false);
    final encoded = jsonEncode(
      capped.map((e) => e.toJson()).toList(growable: false),
    );
    await db.setSetting(_key, encoded);
  }

  Future<List<CorrectionChangeLog>> getRecent({int limit = 20}) async {
    final db = await AppDatabase.getInstance();
    final raw = await db.getSetting(_key);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final logs = <CorrectionChangeLog>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          logs.add(CorrectionChangeLog.fromJson(item));
        } else if (item is Map) {
          logs.add(CorrectionChangeLog.fromJson(item.cast<String, dynamic>()));
        }
      }
      return logs.take(limit).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
