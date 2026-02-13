import 'dart:convert';

/// 用户添加的语音模型条目
class SttModelEntry {
  final String id;
  final String vendorName;
  final String baseUrl;
  final String model;
  final String apiKey;
  final bool enabled;

  const SttModelEntry({
    required this.id,
    required this.vendorName,
    required this.baseUrl,
    required this.model,
    required this.apiKey,
    this.enabled = false,
  });

  SttModelEntry copyWith({
    String? vendorName,
    String? baseUrl,
    String? model,
    String? apiKey,
    bool? enabled,
  }) =>
      SttModelEntry(
        id: id,
        vendorName: vendorName ?? this.vendorName,
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
        apiKey: apiKey ?? this.apiKey,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'vendorName': vendorName,
        'baseUrl': baseUrl,
        'model': model,
        'apiKey': apiKey,
        'enabled': enabled,
      };

  factory SttModelEntry.fromJson(Map<String, dynamic> json) => SttModelEntry(
        id: json['id'] ?? '',
        vendorName: json['vendorName'] ?? '',
        baseUrl: json['baseUrl'] ?? '',
        model: json['model'] ?? '',
        apiKey: json['apiKey'] ?? '',
        enabled: json['enabled'] ?? false,
      );

  static String listToJson(List<SttModelEntry> entries) =>
      json.encode(entries.map((e) => e.toJson()).toList());

  static List<SttModelEntry> listFromJson(String jsonStr) {
    final list = json.decode(jsonStr) as List<dynamic>;
    return list.map((e) => SttModelEntry.fromJson(e)).toList();
  }
}
