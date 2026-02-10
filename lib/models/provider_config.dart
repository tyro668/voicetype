enum SttProviderType { cloud, whisper }

/// 激活模式
enum ActivationMode { tapToTalk, pushToTalk }

/// 模型信息
class SttModel {
  final String id;
  final String description;

  const SttModel({required this.id, required this.description});

  factory SttModel.fromJson(Map<String, dynamic> json) =>
      SttModel(id: json['id'] ?? '', description: json['description'] ?? '');
}

class SttProviderConfig {
  final SttProviderType type;
  final String name;
  final String baseUrl;
  final String apiKey;
  final String model;
  final List<SttModel> availableModels;
  final String? apiKeyUrl;

  const SttProviderConfig({
    required this.type,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.availableModels = const [],
    this.apiKeyUrl,
  });

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'name': name,
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'model': model,
  };

  factory SttProviderConfig.fromJson(Map<String, dynamic> json) =>
      SttProviderConfig(
        type: SttProviderType.values[json['type']],
        name: json['name'],
        baseUrl: json['baseUrl'],
        apiKey: json['apiKey'],
        model: json['model'],
      );

  SttProviderConfig copyWith({
    SttProviderType? type,
    String? name,
    String? baseUrl,
    String? apiKey,
    String? model,
    List<SttModel>? availableModels,
    String? apiKeyUrl,
  }) => SttProviderConfig(
    type: type ?? this.type,
    name: name ?? this.name,
    baseUrl: baseUrl ?? this.baseUrl,
    apiKey: apiKey ?? this.apiKey,
    model: model ?? this.model,
    availableModels: availableModels ?? this.availableModels,
    apiKeyUrl: apiKeyUrl ?? this.apiKeyUrl,
  );

  /// 预设的云端服务商 (fallback)
  static const fallbackPresets = [
    SttProviderConfig(
      type: SttProviderType.cloud,
      name: 'Z.ai',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      apiKey: '',
      model: 'GLM-ASR-2512',
      apiKeyUrl: 'https://open.bigmodel.cn/usercenter/apikeys',
      availableModels: [
        SttModel(
          id: 'GLM-ASR-2512',
          description: 'Z.ai speech-to-text (supports wav/mp3, <=30s)',
        ),
      ],
    ),
    SttProviderConfig(
      type: SttProviderType.cloud,
      name: '阿里云',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      apiKey: '',
      model: 'qwen3-asr-flash',
      availableModels: [
        SttModel(
          id: 'qwen3-asr-flash',
          description: '千问3-ASR-Flash (OpenAI 兼容 + DashScope 同步)',
        ),
      ],
    ),
    SttProviderConfig(
      type: SttProviderType.whisper,
      name: '本地 Whisper',
      baseUrl: 'http://localhost:8080/v1',
      apiKey: '',
      model: 'whisper-1',
      availableModels: [
        SttModel(id: 'whisper-1', description: '本地 Whisper 模型 (需先启动本地服务)'),
      ],
    ),
  ];

  static List<SttProviderConfig> fromPresetJsonList(List<dynamic> items) {
    return items
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => SttProviderConfig(
            type: _parseProviderType(item['type']?.toString()),
            name: item['name'] ?? '',
            baseUrl: item['baseUrl'] ?? '',
            apiKey: '',
            model: item['defaultModel'] ?? '',
            apiKeyUrl: item['apiKeyUrl'],
            availableModels: (item['models'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .map(SttModel.fromJson)
                .toList(),
          ),
        )
        .where(
          (preset) =>
              preset.name.isNotEmpty &&
              preset.baseUrl.isNotEmpty &&
              preset.model.isNotEmpty,
        )
        .toList();
  }

  static SttProviderType _parseProviderType(String? value) {
    switch (value) {
      case 'whisper':
        return SttProviderType.whisper;
      case 'cloud':
      default:
        return SttProviderType.cloud;
    }
  }
}
