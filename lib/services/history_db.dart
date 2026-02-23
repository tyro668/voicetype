import '../models/transcription.dart';
import '../database/app_database.dart';

/// 历史记录数据库访问层，委托给统一的 [AppDatabase]。
class HistoryDb {
  HistoryDb._();

  static final HistoryDb instance = HistoryDb._();

  final _db = AppDatabase.instance;

  Future<List<Transcription>> getAll() => _db.getAllHistory();

  Future<void> insert(Transcription item) => _db.insertHistory(item);

  Future<void> deleteById(String id) => _db.deleteHistoryById(id);

  Future<void> clear() => _db.clearHistory();
}
