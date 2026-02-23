import 'package:floor/floor.dart';
import 'transcription_entity.dart';

/// 转录历史记录表的 DAO（数据访问对象）。
@dao
abstract class TranscriptionDao {
  @Query('SELECT * FROM transcriptions ORDER BY created_at DESC')
  Future<List<TranscriptionEntity>> getAll();

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertItem(TranscriptionEntity item);

  @Query('DELETE FROM transcriptions WHERE id = :id')
  Future<void> deleteById(String id);

  @Query('DELETE FROM transcriptions')
  Future<void> deleteAll();
}
