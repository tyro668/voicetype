class Transcription {
  final String id;
  final String text;
  final String? rawText;
  final DateTime createdAt;
  final Duration duration;
  final String provider;
  final String model;
  final String providerConfigJson;

  Transcription({
    required this.id,
    required this.text,
    this.rawText,
    required this.createdAt,
    required this.duration,
    required this.provider,
    required this.model,
    required this.providerConfigJson,
  });

  /// 是否启用了 AI 增强（rawText 被记录）
  bool get hasRawText => rawText != null && rawText!.isNotEmpty;

  /// AI 增强是否实际改变了文本
  bool get isEnhanced =>
      rawText != null && rawText!.isNotEmpty && rawText != text;

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'rawText': rawText,
    'createdAt': createdAt.toIso8601String(),
    'duration': duration.inMilliseconds,
    'provider': provider,
    'model': model,
    'providerConfigJson': providerConfigJson,
  };

  Map<String, dynamic> toDb() => {
    'id': id,
    'text': text,
    'raw_text': rawText,
    'created_at': createdAt.toIso8601String(),
    'duration_ms': duration.inMilliseconds,
    'provider': provider,
    'model': model,
    'provider_config': providerConfigJson,
  };

  factory Transcription.fromJson(Map<String, dynamic> json) => Transcription(
    id: json['id'],
    text: json['text'],
    rawText: json['rawText'],
    createdAt: DateTime.parse(json['createdAt']),
    duration: Duration(milliseconds: json['duration']),
    provider: json['provider'],
    model: json['model'] ?? '',
    providerConfigJson: json['providerConfigJson'] ?? '{}',
  );

  factory Transcription.fromDb(Map<String, dynamic> row) => Transcription(
    id: row['id'] as String,
    text: row['text'] as String,
    rawText: row['raw_text'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String),
    duration: Duration(milliseconds: row['duration_ms'] as int),
    provider: row['provider'] as String,
    model: (row['model'] as String?) ?? '',
    providerConfigJson: (row['provider_config'] as String?) ?? '{}',
  );
}
