import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_enhance_config.dart';
import '../models/provider_config.dart';

class SettingsProvider extends ChangeNotifier {
  static const _configKey = 'stt_provider_config';
  static const _hotkeyKey = 'hotkey';
  static const _activationModeKey = 'activation_mode';
  static const _aiEnhanceEnabledKey = 'ai_enhance_enabled';
  static const _aiEnhanceConfigKey = 'ai_enhance_config';
  static const _aiEnhanceDefaultModelsKey = 'ai_enhance_default_models';
  static const _aiEnhanceUseCustomPromptKey = 'ai_enhance_use_custom_prompt';

  SttProviderConfig _config = SttProviderConfig.presets.first;
  List<SttProviderConfig> _customProviders = [];

  // 快捷键配置
  LogicalKeyboardKey _hotkey = LogicalKeyboardKey.f2;
  ActivationMode _activationMode = ActivationMode.tapToTalk;

  /// 每个服务商独立存储的 API Key（按 name 索引）
  final Map<String, String> _apiKeys = {};

  bool _aiEnhanceEnabled = false;
  AiEnhanceConfig _aiEnhanceConfig = AiEnhanceConfig.defaultConfig;
  final Map<String, String> _aiEnhanceDefaultModels = {};
  bool _aiEnhanceUseCustomPrompt = true;
  String _aiEnhanceDefaultPrompt = AiEnhanceConfig.defaultPrompt;

  SttProviderConfig get config => _config;
  LogicalKeyboardKey get hotkey => _hotkey;
  ActivationMode get activationMode => _activationMode;
  bool get aiEnhanceEnabled => _aiEnhanceEnabled;
  AiEnhanceConfig get aiEnhanceConfig => _aiEnhanceConfig;
  bool get aiEnhanceUseCustomPrompt => _aiEnhanceUseCustomPrompt;
  String get aiEnhanceDefaultPrompt => _aiEnhanceDefaultPrompt;
  AiEnhanceConfig get effectiveAiEnhanceConfig => _aiEnhanceUseCustomPrompt
      ? _aiEnhanceConfig
      : _aiEnhanceConfig.copyWith(prompt: _aiEnhanceDefaultPrompt);
  String? aiEnhanceDefaultModelFor(String baseUrl) =>
      _aiEnhanceDefaultModels[baseUrl];

  List<SttProviderConfig> get allProviders => [
    ...SttProviderConfig.presets,
    ..._customProviders,
  ];

  List<SttProviderConfig> get customProviders => _customProviders;

  /// 获取当前选中服务商的 preset（带 availableModels）
  SttProviderConfig? get currentPreset {
    try {
      return SttProviderConfig.presets.firstWhere(
        (p) => p.name == _config.name,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // 加载服务商配置
    final configJson = prefs.getString(_configKey);
    if (configJson != null) {
      _config = SttProviderConfig.fromJson(json.decode(configJson));
    }

    // 加载自定义服务商
    final customJson = prefs.getString('custom_providers');
    if (customJson != null) {
      _customProviders = (json.decode(customJson) as List)
          .map((e) => SttProviderConfig.fromJson(e))
          .toList();
    }

    // 加载 API Keys
    final keysJson = prefs.getString('api_keys');
    if (keysJson != null) {
      _apiKeys.addAll(Map<String, String>.from(json.decode(keysJson)));
    }
    // 将存储的 apiKey 应用到当前配置
    if (_apiKeys.containsKey(_config.name)) {
      _config = _config.copyWith(apiKey: _apiKeys[_config.name]);
    }

    // 加载快捷键
    final hotkeyId = prefs.getInt(_hotkeyKey);
    if (hotkeyId != null) {
      _hotkey = LogicalKeyboardKey(hotkeyId);
    }

    // 加载激活模式
    final modeIndex = prefs.getInt(_activationModeKey);
    if (modeIndex != null) {
      _activationMode = ActivationMode.values[modeIndex];
    }

    final aiEnhanceEnabled = prefs.getBool(_aiEnhanceEnabledKey);
    if (aiEnhanceEnabled != null) {
      _aiEnhanceEnabled = aiEnhanceEnabled;
    }

    final useCustomPrompt = prefs.getBool(_aiEnhanceUseCustomPromptKey);
    if (useCustomPrompt != null) {
      _aiEnhanceUseCustomPrompt = useCustomPrompt;
    }

    try {
      final prompt = await rootBundle.loadString(
        'assets/prompts/default_prompt.md',
      );
      _aiEnhanceDefaultPrompt = prompt;
    } catch (_) {}

    final aiEnhanceJson = prefs.getString(_aiEnhanceConfigKey);
    if (aiEnhanceJson != null) {
      _aiEnhanceConfig = AiEnhanceConfig.fromJson(json.decode(aiEnhanceJson));
    } else {
      _aiEnhanceConfig = _aiEnhanceConfig.copyWith(
        prompt: _aiEnhanceDefaultPrompt,
      );
    }

    final defaultModelsJson = prefs.getString(_aiEnhanceDefaultModelsKey);
    if (defaultModelsJson != null) {
      _aiEnhanceDefaultModels.addAll(
        Map<String, String>.from(json.decode(defaultModelsJson)),
      );
    }

    notifyListeners();
  }

  Future<void> setConfig(SttProviderConfig config) async {
    _config = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, json.encode(config.toJson()));
    notifyListeners();
  }

  /// 选择服务商（从 preset 或 custom 列表中选择）
  Future<void> selectProvider(SttProviderConfig provider) async {
    // 恢复该服务商之前存储的 apiKey
    final savedKey = _apiKeys[provider.name] ?? '';
    _config = provider.copyWith(apiKey: savedKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, json.encode(_config.toJson()));
    notifyListeners();
  }

  /// 设置当前服务商的 API Key
  Future<void> setApiKey(String apiKey) async {
    _apiKeys[_config.name] = apiKey;
    _config = _config.copyWith(apiKey: apiKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_keys', json.encode(_apiKeys));
    await prefs.setString(_configKey, json.encode(_config.toJson()));
    notifyListeners();
  }

  /// 设置当前服务商的模型
  Future<void> setModel(String model) async {
    _config = _config.copyWith(model: model);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, json.encode(_config.toJson()));
    notifyListeners();
  }

  /// 设置快捷键
  Future<void> setHotkey(LogicalKeyboardKey key) async {
    _hotkey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hotkeyKey, key.keyId);
    notifyListeners();
  }

  /// 设置激活模式
  Future<void> setActivationMode(ActivationMode mode) async {
    _activationMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_activationModeKey, mode.index);
    notifyListeners();
  }

  Future<void> setAiEnhanceEnabled(bool enabled) async {
    _aiEnhanceEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aiEnhanceEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setAiEnhanceUseCustomPrompt(bool enabled) async {
    _aiEnhanceUseCustomPrompt = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aiEnhanceUseCustomPromptKey, enabled);
    notifyListeners();
  }

  Future<void> setAiEnhanceConfig(AiEnhanceConfig config) async {
    _aiEnhanceConfig = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiEnhanceConfigKey, json.encode(config.toJson()));
    notifyListeners();
  }

  Future<void> setAiEnhanceBaseUrl(String baseUrl) async {
    await setAiEnhanceConfig(_aiEnhanceConfig.copyWith(baseUrl: baseUrl));
  }

  Future<void> setAiEnhanceApiKey(String apiKey) async {
    await setAiEnhanceConfig(_aiEnhanceConfig.copyWith(apiKey: apiKey));
  }

  Future<void> setAiEnhanceModel(String model) async {
    await setAiEnhanceConfig(_aiEnhanceConfig.copyWith(model: model));
  }

  Future<void> setAiEnhancePrompt(String prompt) async {
    await setAiEnhanceConfig(_aiEnhanceConfig.copyWith(prompt: prompt));
  }

  Future<void> setAiEnhanceAgentName(String agentName) async {
    await setAiEnhanceConfig(_aiEnhanceConfig.copyWith(agentName: agentName));
  }

  Future<void> setAiEnhanceDefaultModel(String baseUrl, String model) async {
    _aiEnhanceDefaultModels[baseUrl] = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _aiEnhanceDefaultModelsKey,
      json.encode(_aiEnhanceDefaultModels),
    );
    notifyListeners();
  }

  Future<void> addCustomProvider(SttProviderConfig provider) async {
    _customProviders.add(provider);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'custom_providers',
      json.encode(_customProviders.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> removeCustomProvider(int index) async {
    _customProviders.removeAt(index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'custom_providers',
      json.encode(_customProviders.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  /// 获取快捷键的显示名称
  String get hotkeyLabel {
    return _hotkey.keyLabel.isNotEmpty
        ? _hotkey.keyLabel
        : _hotkey.debugName ?? 'Unknown';
  }
}
