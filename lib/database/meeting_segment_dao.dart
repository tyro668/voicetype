import 'package:floor/floor.dart';
import 'meeting_segment_entity.dart';

/// 会议分段表的 DAO（数据访问对象）。
@dao
abstract class MeetingSegmentDao {
  @Query('SELECT * FROM meeting_segments WHERE meeting_id = :meetingId ORDER BY segment_index ASC')
  Future<List<MeetingSegmentEntity>> getByMeetingId(String meetingId);

  @Query('SELECT * FROM meeting_segments WHERE id = :id')
  Future<MeetingSegmentEntity?> findById(String id);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertSegment(MeetingSegmentEntity segment);

  @Update(onConflict: OnConflictStrategy.replace)
  Future<void> updateSegment(MeetingSegmentEntity segment);

  @Query('DELETE FROM meeting_segments WHERE meeting_id = :meetingId')
  Future<void> deleteByMeetingId(String meetingId);

  @Query('DELETE FROM meeting_segments WHERE id = :id')
  Future<void> deleteById(String id);
}
