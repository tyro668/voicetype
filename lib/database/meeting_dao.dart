import 'package:floor/floor.dart';
import 'meeting_entity.dart';

/// 会议记录表的 DAO（数据访问对象）。
@dao
abstract class MeetingDao {
  @Query('SELECT * FROM meetings ORDER BY created_at DESC')
  Future<List<MeetingEntity>> getAll();

  @Query('SELECT * FROM meetings WHERE id = :id')
  Future<MeetingEntity?> findById(String id);

  @Query('SELECT * FROM meetings WHERE status = :status ORDER BY created_at DESC')
  Future<List<MeetingEntity>> findByStatus(String status);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertMeeting(MeetingEntity meeting);

  @Update(onConflict: OnConflictStrategy.replace)
  Future<void> updateMeeting(MeetingEntity meeting);

  @Query('DELETE FROM meetings WHERE id = :id')
  Future<void> deleteById(String id);

  @Query('DELETE FROM meetings')
  Future<void> deleteAll();
}
