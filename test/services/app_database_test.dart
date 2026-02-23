import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:voicetype/database/app_database.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await AppDatabase.resetForTest();
  });

  tearDownAll(() async {
    await AppDatabase.resetForTest();
  });

  group('AppDatabase settings', () {
    test('setSetting and getSetting', () async {
      final db = AppDatabase.instance;
      await db.setSetting('test_key', 'test_value');
      final value = await db.getSetting('test_key');
      expect(value, 'test_value');
    });

    test('setSetting overwrites existing value', () async {
      final db = AppDatabase.instance;
      await db.setSetting('overwrite_key', 'old');
      await db.setSetting('overwrite_key', 'new');
      final value = await db.getSetting('overwrite_key');
      expect(value, 'new');
    });

    test('getSetting returns null for missing key', () async {
      final db = AppDatabase.instance;
      final value = await db.getSetting('nonexistent_key_12345');
      expect(value, isNull);
    });

    test('removeSetting deletes key', () async {
      final db = AppDatabase.instance;
      await db.setSetting('remove_me', 'value');
      await db.removeSetting('remove_me');
      final value = await db.getSetting('remove_me');
      expect(value, isNull);
    });

    test('getAllSettings returns all entries', () async {
      final db = AppDatabase.instance;
      await db.setSetting('all_a', '1');
      await db.setSetting('all_b', '2');
      final all = await db.getAllSettings();
      expect(all['all_a'], '1');
      expect(all['all_b'], '2');
    });
  });
}
