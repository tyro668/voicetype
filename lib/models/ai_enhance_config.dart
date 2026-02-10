class AiEnhanceConfig {
  static const defaultPrompt =
      'Fix mistakes and improve readability. Keep the original language and meaning. Do not add new content.';
  static const defaultAgentName = 'Agent';
  final String baseUrl;
  final String apiKey;
  final String model;
  final String prompt;
  final String agentName;

  const AiEnhanceConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.prompt,
    required this.agentName,
  });

  static const defaultConfig = AiEnhanceConfig(
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    apiKey: '',
    model: 'glm-4-flash',
    prompt: defaultPrompt,
    agentName: defaultAgentName,
  );

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'model': model,
    'prompt': prompt,
    'agentName': agentName,
  };

  factory AiEnhanceConfig.fromJson(Map<String, dynamic> json) =>
      AiEnhanceConfig(
        baseUrl: json['baseUrl'] ?? defaultConfig.baseUrl,
        apiKey: json['apiKey'] ?? '',
        model: json['model'] ?? defaultConfig.model,
        prompt: json['prompt'] ?? defaultConfig.prompt,
        agentName: json['agentName'] ?? defaultConfig.agentName,
      );

  AiEnhanceConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? model,
    String? prompt,
    String? agentName,
  }) => AiEnhanceConfig(
    baseUrl: baseUrl ?? this.baseUrl,
    apiKey: apiKey ?? this.apiKey,
    model: model ?? this.model,
    prompt: prompt ?? this.prompt,
    agentName: agentName ?? this.agentName,
  );
}
