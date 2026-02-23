class AiVendorPreset {
  final String name;
  final String baseUrl;
  final List<AiModel> models;
  final String? defaultModelIdOverride;

  const AiVendorPreset({
    required this.name,
    required this.baseUrl,
    required this.models,
    this.defaultModelIdOverride,
  });

  String get defaultModelId => defaultModelIdOverride ?? models.first.id;

  static const fallbackPresets = [
    AiVendorPreset(
      name: 'Z.AI',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      models: [
        AiModel(id: 'GLM-4.7', description: 'GLM-4.7'),
        AiModel(id: 'GLM-4.7-FlashX', description: 'GLM-4.7-FlashX'),
      ],
      defaultModelIdOverride: 'GLM-4.7-FlashX',
    ),
    AiVendorPreset(
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com/v1',
      models: [AiModel(id: 'deepseek-chat', description: 'DeepSeek 默认模型')],
    ),
    AiVendorPreset(
      name: '阿里云',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      models: [
        AiModel(id: 'qwen-plus', description: '千问 Plus'),
        AiModel(id: 'qwen-max', description: '千问 Max'),
        AiModel(id: 'qwen-turbo', description: '千问 Turbo'),
      ],
    ),
  ];

  static List<AiVendorPreset> fromPresetJsonList(List<dynamic> items) {
    return items
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => AiVendorPreset(
            name: item['name'] ?? '',
            baseUrl: item['baseUrl'] ?? '',
            models: (item['models'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .map(AiModel.fromJson)
                .toList(),
            defaultModelIdOverride: _resolveDefaultModelId(
              item['defaultModel']?.toString(),
              item['models'],
            ),
          ),
        )
        .where(
          (preset) =>
              preset.name.isNotEmpty &&
              preset.baseUrl.isNotEmpty &&
              preset.models.isNotEmpty,
        )
        .toList();
  }

  static String? _resolveDefaultModelId(
    String? defaultModel,
    dynamic rawModels,
  ) {
    if (defaultModel == null || defaultModel.isEmpty) return null;
    if (rawModels is List) {
      final exists = rawModels.whereType<Map<String, dynamic>>().any(
        (model) => model['id'] == defaultModel,
      );
      return exists ? defaultModel : null;
    }
    return null;
  }
}

class AiModel {
  final String id;
  final String description;

  const AiModel({required this.id, required this.description});

  factory AiModel.fromJson(Map<String, dynamic> json) =>
      AiModel(id: json['id'] ?? '', description: json['description'] ?? '');
}
