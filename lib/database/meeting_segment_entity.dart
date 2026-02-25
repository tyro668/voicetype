import 'package:floor/floor.dart';
import '../models/meeting.dart';
import 'meeting_entity.dart';

/// 会议分段实体，对应 `meeting_segments` 表。
@Entity(
  tableName: 'meeting_segments',
  foreignKeys: [
    ForeignKey(
      childColumns: ['meeting_id'],
      parentColumns: ['id'],
      entity: MeetingEntity,
      onDelete: ForeignKeyAction.cascade,
    ),
  ],
)
class MeetingSegmentEntity {
  @primaryKey
  final String id;

  @ColumnInfo(name: 'meeting_id')
  final String meetingId;

  @ColumnInfo(name: 'segment_index')
  final int segmentIndex;

  @ColumnInfo(name: 'start_time')
  final String startTime;

  @ColumnInfo(name: 'duration_ms')
  final int durationMs;

  @ColumnInfo(name: 'audio_file_path')
  final String? audioFilePath;

  final String? transcription;

  @ColumnInfo(name: 'enhanced_text')
  final String? enhancedText;

  final String status;

  @ColumnInfo(name: 'error_message')
  final String? errorMessage;

  MeetingSegmentEntity({
    required this.id,
    required this.meetingId,
    required this.segmentIndex,
    required this.startTime,
    required this.durationMs,
    this.audioFilePath,
    this.transcription,
    this.enhancedText,
    required this.status,
    this.errorMessage,
  });

  /// 转换为领域模型
  MeetingSegment toModel() => MeetingSegment(
    id: id,
    meetingId: meetingId,
    segmentIndex: segmentIndex,
    startTime: DateTime.parse(startTime),
    duration: Duration(milliseconds: durationMs),
    audioFilePath: audioFilePath,
    transcription: transcription,
    enhancedText: enhancedText,
    status: SegmentStatus.values.byName(status),
    errorMessage: errorMessage,
  );

  /// 从领域模型创建
  factory MeetingSegmentEntity.fromModel(MeetingSegment s) =>
      MeetingSegmentEntity(
        id: s.id,
        meetingId: s.meetingId,
        segmentIndex: s.segmentIndex,
        startTime: s.startTime.toIso8601String(),
        durationMs: s.duration.inMilliseconds,
        audioFilePath: s.audioFilePath,
        transcription: s.transcription,
        enhancedText: s.enhancedText,
        status: s.status.name,
        errorMessage: s.errorMessage,
      );
}
