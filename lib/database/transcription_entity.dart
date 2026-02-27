import 'package:floor/floor.dart';
import '../models/transcription.dart';

/// 转录历史记录实体，对应 `transcriptions` 表。
@Entity(tableName: 'transcriptions')
class TranscriptionEntity {
  @primaryKey
  final String id;

  final String text;

  @ColumnInfo(name: 'raw_text')
  final String? rawText;

  @ColumnInfo(name: 'created_at')
  final String createdAt;

  @ColumnInfo(name: 'duration_ms')
  final int durationMs;

  final String provider;

  final String model;

  @ColumnInfo(name: 'provider_config')
  final String providerConfig;

  TranscriptionEntity({
    required this.id,
    required this.text,
    this.rawText,
    required this.createdAt,
    required this.durationMs,
    required this.provider,
    required this.model,
    required this.providerConfig,
  });

  /// 转换为领域模型。
  Transcription toModel() => Transcription(
    id: id,
    text: text,
    rawText: rawText,
    createdAt: DateTime.parse(createdAt),
    duration: Duration(milliseconds: durationMs),
    provider: provider,
    model: model,
    providerConfigJson: providerConfig,
  );

  /// 从领域模型创建。
  factory TranscriptionEntity.fromModel(Transcription t) => TranscriptionEntity(
    id: t.id,
    text: t.text,
    rawText: t.rawText,
    createdAt: t.createdAt.toIso8601String(),
    durationMs: t.duration.inMilliseconds,
    provider: t.provider,
    model: t.model,
    providerConfig: t.providerConfigJson,
  );
}
