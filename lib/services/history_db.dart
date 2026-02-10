import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/transcription.dart';

class HistoryDb {
  HistoryDb._();

  static final HistoryDb instance = HistoryDb._();
  static const _dbName = 'voicetype.db';
  static const _table = 'transcriptions';

  Database? _db;

  Future<Database> _getDb() async {
    if (_db != null) return _db!;
    final databasesPath = await databaseFactory.getDatabasesPath();
    final dbPath = path.join(databasesPath, _dbName);
    _db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
CREATE TABLE $_table (
  id TEXT PRIMARY KEY,
  text TEXT NOT NULL,
  created_at TEXT NOT NULL,
  duration_ms INTEGER NOT NULL,
  provider TEXT NOT NULL,
  model TEXT NOT NULL,
  provider_config TEXT NOT NULL
)
''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'ALTER TABLE $_table ADD COLUMN model TEXT NOT NULL DEFAULT ""',
            );
            await db.execute(
              'ALTER TABLE $_table ADD COLUMN provider_config TEXT NOT NULL DEFAULT "{}"',
            );
          }
        },
      ),
    );
    return _db!;
  }

  Future<List<Transcription>> getAll() async {
    final db = await _getDb();
    final rows = await db.query(_table, orderBy: 'created_at DESC');
    return rows.map(Transcription.fromDb).toList();
  }

  Future<void> insert(Transcription item) async {
    final db = await _getDb();
    await db.insert(
      _table,
      item.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteById(String id) async {
    final db = await _getDb();
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clear() async {
    final db = await _getDb();
    await db.delete(_table);
  }
}
