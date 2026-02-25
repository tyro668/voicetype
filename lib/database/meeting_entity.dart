import 'package:floor/floor.dart';
import '../models/meeting.dart';

/// 会议记录实体，对应 `meetings` 表。
@Entity(tableName: 'meetings')
class MeetingEntity {
  @primaryKey
  final String id;

  final String title;

  @ColumnInfo(name: 'created_at')
  final String createdAt;

  @ColumnInfo(name: 'updated_at')
  final String updatedAt;

  final String status;

  final String? summary;

  @ColumnInfo(name: 'total_duration_ms')
  final int totalDurationMs;

  MeetingEntity({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.summary,
    required this.totalDurationMs,
  });

  /// 转换为领域模型
  MeetingRecord toModel() => MeetingRecord(
    id: id,
    title: title,
    createdAt: DateTime.parse(createdAt),
    updatedAt: DateTime.parse(updatedAt),
    status: MeetingStatus.values.byName(status),
    summary: summary,
    totalDuration: Duration(milliseconds: totalDurationMs),
  );

  /// 从领域模型创建
  factory MeetingEntity.fromModel(MeetingRecord m) => MeetingEntity(
    id: m.id,
    title: m.title,
    createdAt: m.createdAt.toIso8601String(),
    updatedAt: m.updatedAt.toIso8601String(),
    status: m.status.name,
    summary: m.summary,
    totalDurationMs: m.totalDuration.inMilliseconds,
  );
}
