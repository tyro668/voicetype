import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ai_enhance_config.dart';
import '../models/ai_model_entry.dart';
import '../models/ai_vendor_preset.dart';
import '../models/network_settings.dart';
import '../models/provider_config.dart';
import '../models/stt_model_entry.dart';
import '../database/app_database.dart';
import '../services/network_client_service.dart';

class SettingsProvider extends ChangeNotifier {
  static const _configKey = 'stt_provider_config';
  static const _hotkeyKey = 'hotkey';
  static const _activationModeKey = 'activation_mode';
  static const _aiEnhanceEnabledKey = 'ai_enhance_enabled';
  static const _aiEnhanceConfigKey = 'ai_enhance_config';
  static const _aiEnhanceDefaultModelsKey = 'ai_enhance_default_models';
  static const _aiEnhanceUseCustomPromptKey = 'ai_enhance_use_custom_prompt';
  static const _minRecordingSecondsKey = 'min_recording_seconds';
  static const _aiModelEntriesKey = 'ai_model_entries';
  static const _sttModelEntriesKey = 'stt_model_entries';
  static const _localeKey = 'locale';
  static const _networkProxyModeKey = 'network_proxy_mode';
  static const _themeModeKey = 'theme_mode';

  List<SttProviderConfig> _sttPresets = List<SttProviderConfig>.from(
    SttProviderConfig.fallbackPresets,
  );
  List<AiVendorPreset> _aiPresets = List<AiVendorPreset>.from(
    AiVendorPreset.fallbackPresets,
  );
  SttProviderConfig _config = SttProviderConfig.fallbackPresets.first;
  List<SttProviderConfig> _customProviders = [];

  static LogicalKeyboardKey get defaultHotkey {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return LogicalKeyboardKey.f2;
    }
    return LogicalKeyboardKey.fn;
  }

  // 快捷键配置
  LogicalKeyboardKey _hotkey = defaultHotkey;
  ActivationMode _activationMode = ActivationMode.tapToTalk;

  /// 每个服务商独立存储的 API Key（按 name 索引）
  final Map<String, String> _apiKeys = {};

  bool _aiEnhanceEnabled = false;
  AiEnhanceConfig _aiEnhanceConfig = AiEnhanceConfig.defaultConfig;
  final Map<String, String> _aiEnhanceDefaultModels = {};
  bool _aiEnhanceUseCustomPrompt = true;
  String _aiEnhanceDefaultPrompt = AiEnhanceConfig.defaultPrompt;
  int _minRecordingSeconds = 3;
  List<AiModelEntry> _aiModelEntries = [];
  List<SttModelEntry> _sttModelEntries = [];
  Locale _locale = const Locale('zh');
  NetworkProxyMode _networkProxyMode = NetworkProxyMode.none;
  ThemeMode _themeMode = ThemeMode.system;

  SttProviderConfig get config => _config;
  List<SttProviderConfig> get sttPresets => _sttPresets;
  List<AiVendorPreset> get aiPresets => _aiPresets;
  LogicalKeyboardKey get hotkey => _hotkey;
  ActivationMode get activationMode => _activationMode;
  bool get aiEnhanceEnabled => _aiEnhanceEnabled;
  AiEnhanceConfig get aiEnhanceConfig => _aiEnhanceConfig;
  bool get aiEnhanceUseCustomPrompt => _aiEnhanceUseCustomPrompt;
  String get aiEnhanceDefaultPrompt => _aiEnhanceDefaultPrompt;
  int get minRecordingSeconds => _minRecordingSeconds;
  List<AiModelEntry> get aiModelEntries => List.unmodifiable(_aiModelEntries);
  AiModelEntry? get activeAiModelEntry {
    try {
      return _aiModelEntries.firstWhere((e) => e.enabled);
    } catch (_) {
      return null;
    }
  }

  List<SttModelEntry> get sttModelEntries =>
      List.unmodifiable(_sttModelEntries);
  SttModelEntry? get activeSttModelEntry {
    try {
      return _sttModelEntries.firstWhere((e) => e.enabled);
    } catch (_) {
      return null;
    }
  }

  Locale get locale => _locale;
  NetworkProxyMode get networkProxyMode => _networkProxyMode;
  ThemeMode get themeMode => _themeMode;

  AiEnhanceConfig get effectiveAiEnhanceConfig {
    final active = activeAiModelEntry;
    final base = active != null
        ? _aiEnhanceConfig.copyWith(
            baseUrl: active.baseUrl,
            apiKey: active.apiKey,
            model: active.model,
          )
        : _aiEnhanceConfig;
    return _aiEnhanceUseCustomPrompt
        ? base
        : base.copyWith(prompt: _aiEnhanceDefaultPrompt);
  }

  String? aiEnhanceDefaultModelFor(String baseUrl) =>
      _aiEnhanceDefaultModels[baseUrl];

  List<SttProviderConfig> get allProviders => [
    ..._sttPresets,
    ..._customProviders,
  ];

  List<SttProviderConfig> get customProviders => _customProviders;

  /// 获取当前选中服务商的 preset（带 availableModels）
  SttProviderConfig? get currentPreset {
    try {
      return _sttPresets.firstWhere((p) => p.name == _config.name);
    } catch (_) {
      return null;
    }
  }

  // ===== API Key 辅助方法 =====

  /// 去除旧的 ENC: 加密前缀（兼容迁移），返回明文。
  String _resolveApiKey(String raw) {
    var value = raw.trim();
    // 旧版本可能存有 ENC: 前缀的加密密钥，无法解密则清空
    if (value.startsWith('ENC:')) return '';
    return value;
  }

  Future<void> load() async {
    final db = AppDatabase.instance;

    await _loadPresetsFromAssets();

    // 加载服务商配置
    final configJson = await db.getSetting(_configKey);
    if (configJson != null) {
      final decoded = json.decode(configJson) as Map<String, dynamic>;
      _config = SttProviderConfig.fromJson(_cleanApiKeyInJson(decoded));
    }

    // 加载自定义服务商
    final customJson = await db.getSetting('custom_providers');
    if (customJson != null) {
      _customProviders = (json.decode(customJson) as List)
          .map(
            (e) => SttProviderConfig.fromJson(
              _cleanApiKeyInJson(e as Map<String, dynamic>),
            ),
          )
          .toList();
    }

    // 加载 API Keys
    final keysJson = await db.getSetting('api_keys');
    if (keysJson != null) {
      final raw = Map<String, String>.from(json.decode(keysJson));
      for (final entry in raw.entries) {
        _apiKeys[entry.key] = _resolveApiKey(entry.value);
      }
    }
    // 将存储的 apiKey 应用到当前配置
    if (_apiKeys.containsKey(_config.name)) {
      _config = _config.copyWith(apiKey: _apiKeys[_config.name]);
    }

    // 加载快捷键
    final hotkeyStr = await db.getSetting(_hotkeyKey);
    if (hotkeyStr != null) {
      _hotkey = LogicalKeyboardKey(int.parse(hotkeyStr));
    }
    if (defaultTargetPlatform == TargetPlatform.windows &&
        _hotkey == LogicalKeyboardKey.fn) {
      _hotkey = LogicalKeyboardKey.f2;
      await _saveSetting(_hotkeyKey, _hotkey.keyId.toString());
    }

    // 加载激活模式
    final modeStr = await db.getSetting(_activationModeKey);
    if (modeStr != null) {
      _activationMode = ActivationMode.values[int.parse(modeStr)];
    }

    final aiEnabledStr = await db.getSetting(_aiEnhanceEnabledKey);
    if (aiEnabledStr != null) {
      _aiEnhanceEnabled = aiEnabledStr == 'true';
    }

    final useCustomStr = await db.getSetting(_aiEnhanceUseCustomPromptKey);
    if (useCustomStr != null) {
      _aiEnhanceUseCustomPrompt = useCustomStr == 'true';
    }

    final minSecStr = await db.getSetting(_minRecordingSecondsKey);
    if (minSecStr != null) {
      _minRecordingSeconds = int.parse(minSecStr);
    }

    try {
      final prompt = await rootBundle.loadString(
        'assets/prompts/default_prompt.md',
      );
      _aiEnhanceDefaultPrompt = prompt;
    } catch (_) {}

    final aiEnhanceJson = await db.getSetting(_aiEnhanceConfigKey);
    if (aiEnhanceJson != null) {
      final decoded = json.decode(aiEnhanceJson) as Map<String, dynamic>;
      _aiEnhanceConfig = AiEnhanceConfig.fromJson(_cleanApiKeyInJson(decoded));
    } else {
      _aiEnhanceConfig = _aiEnhanceConfig.copyWith(
        prompt: _aiEnhanceDefaultPrompt,
      );
    }

    final defaultModelsJson = await db.getSetting(_aiEnhanceDefaultModelsKey);
    if (defaultModelsJson != null) {
      _aiEnhanceDefaultModels.addAll(
        Map<String, String>.from(json.decode(defaultModelsJson)),
      );
    }

    // 加载文本模型条目列表
    final entriesJson = await db.getSetting(_aiModelEntriesKey);
    if (entriesJson != null) {
      try {
        final list = json.decode(entriesJson) as List<dynamic>;
        _aiModelEntries = list
            .whereType<Map<String, dynamic>>()
            .map((e) => AiModelEntry.fromJson(_cleanApiKeyInJson(e)))
            .toList();
      } catch (_) {}
    }
    // 如果有激活条目，同步到 aiEnhanceConfig
    final active = activeAiModelEntry;
    if (active != null) {
      _aiEnhanceConfig = _aiEnhanceConfig.copyWith(
        baseUrl: active.baseUrl,
        apiKey: active.apiKey,
        model: active.model,
      );
    }

    // 加载语音模型条目列表
    final sttEntriesJson = await db.getSetting(_sttModelEntriesKey);
    if (sttEntriesJson != null) {
      try {
        final list = json.decode(sttEntriesJson) as List<dynamic>;
        _sttModelEntries = list
            .whereType<Map<String, dynamic>>()
            .map((e) => SttModelEntry.fromJson(_cleanApiKeyInJson(e)))
            .toList();
      } catch (_) {}
    }
    // 如果有激活的语音模型条目，同步到 config
    final activeStt = activeSttModelEntry;
    if (activeStt != null) {
      _config = _config.copyWith(
        name: activeStt.vendorName,
        baseUrl: activeStt.baseUrl,
        apiKey: activeStt.apiKey,
        model: activeStt.model,
      );
    }

    // 加载语言设置
    final localeStr = await db.getSetting(_localeKey);
    if (localeStr != null) {
      _locale = Locale(localeStr);
    }

    // 加载主题模式
    final themeModeStr = await db.getSetting(_themeModeKey);
    if (themeModeStr != null) {
      _themeMode = switch (themeModeStr) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    }

    final proxyModeStr = await db.getSetting(_networkProxyModeKey);
    _networkProxyMode = NetworkProxyModeX.fromStorage(proxyModeStr);
    NetworkClientService.setProxyMode(_networkProxyMode);

    notifyListeners();
  }

  /// 清理 JSON Map 中的 apiKey 字段（去除旧 ENC: 前缀）。
  Map<String, dynamic> _cleanApiKeyInJson(Map<String, dynamic> jsonMap) {
    final copy = Map<String, dynamic>.from(jsonMap);
    final apiKey = copy['apiKey'];
    if (apiKey is String && apiKey.isNotEmpty) {
      copy['apiKey'] = _resolveApiKey(apiKey);
    }
    return copy;
  }

  Future<void> _loadPresetsFromAssets() async {
    try {
      final raw = await rootBundle.loadString('assets/presets/models.json');
      final jsonMap = json.decode(raw) as Map<String, dynamic>;
      final stt = jsonMap['stt'] as List<dynamic>?;
      final ai = jsonMap['ai'] as List<dynamic>?;
      if (stt != null) {
        final parsed = SttProviderConfig.fromPresetJsonList(stt);
        if (parsed.isNotEmpty) {
          _sttPresets = parsed;
        }
      }
      if (ai != null) {
        final parsed = AiVendorPreset.fromPresetJsonList(ai);
        if (parsed.isNotEmpty) {
          _aiPresets = parsed;
        }
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> setConfig(SttProviderConfig config) async {
    _config = config;
    await _saveSetting(_configKey, json.encode(_config.toJson()));
    notifyListeners();
  }

  /// 选择服务商（从 preset 或 custom 列表中选择）
  Future<void> selectProvider(SttProviderConfig provider) async {
    // 恢复该服务商之前存储的 apiKey
    final savedKey = _apiKeys[provider.name] ?? '';
    _config = provider.copyWith(apiKey: savedKey);
    await _saveSetting(_configKey, json.encode(_config.toJson()));
    notifyListeners();
  }

  /// 设置当前服务商的 API Key
  Future<void> setApiKey(String apiKey) async {
    final normalizedApiKey = apiKey.trim();
    _apiKeys[_config.name] = normalizedApiKey;
    _config = _config.copyWith(apiKey: normalizedApiKey);
    await _saveSetting('api_keys', json.encode(_apiKeys));
    await _saveSetting(_configKey, json.encode(_config.toJson()));
    notifyListeners();
  }

  /// 设置当前服务商的模型
  Future<void> setModel(String model) async {
    _config = _config.copyWith(model: model);
    await _saveSetting(_configKey, json.encode(_config.toJson()));
    notifyListeners();
  }

  Future<void> setHotkey(LogicalKeyboardKey key) async {
    _hotkey = key;
    await _saveSetting(_hotkeyKey, key.keyId.toString());
    notifyListeners();
  }

  Future<void> resetHotkey() async {
    _hotkey = defaultHotkey;
    await AppDatabase.instance.removeSetting(_hotkeyKey);
    notifyListeners();
  }

  /// 设置激活模式
  Future<void> setActivationMode(ActivationMode mode) async {
    _activationMode = mode;
    await _saveSetting(_activationModeKey, mode.index.toString());
    notifyListeners();
  }

  Future<void> setAiEnhanceEnabled(bool enabled) async {
    _aiEnhanceEnabled = enabled;
    await _saveSetting(_aiEnhanceEnabledKey, enabled.toString());
    notifyListeners();
  }

  Future<void> setAiEnhanceUseCustomPrompt(bool enabled) async {
    _aiEnhanceUseCustomPrompt = enabled;
    await _saveSetting(_aiEnhanceUseCustomPromptKey, enabled.toString());
    notifyListeners();
  }

  Future<void> setMinRecordingSeconds(int seconds) async {
    _minRecordingSeconds = seconds.clamp(1, 30);
    await _saveSetting(
      _minRecordingSecondsKey,
      _minRecordingSeconds.toString(),
    );
    notifyListeners();
  }

  Future<void> setAiEnhanceConfig(AiEnhanceConfig config) async {
    _aiEnhanceConfig = config;
    await _saveSetting(
      _aiEnhanceConfigKey,
      json.encode(_aiEnhanceConfig.toJson()),
    );
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
    await _saveSetting(
      _aiEnhanceDefaultModelsKey,
      json.encode(_aiEnhanceDefaultModels),
    );
    notifyListeners();
  }

  // ===== 文本模型条目管理 =====

  Future<void> _saveAiModelEntries() async {
    await _saveSetting(
      _aiModelEntriesKey,
      json.encode(_aiModelEntries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addAiModelEntry(AiModelEntry entry) async {
    // 如果是第一个条目，自动启用
    final shouldEnable = _aiModelEntries.isEmpty;
    final newEntry = shouldEnable ? entry.copyWith(enabled: true) : entry;
    if (shouldEnable) {
      // 禁用其他
      _aiModelEntries = _aiModelEntries
          .map((e) => e.copyWith(enabled: false))
          .toList();
    }
    _aiModelEntries.add(newEntry);
    await _saveAiModelEntries();
    _syncAiConfigFromActiveEntry();
    notifyListeners();
  }

  Future<void> removeAiModelEntry(String id) async {
    _aiModelEntries.removeWhere((e) => e.id == id);
    await _saveAiModelEntries();
    _syncAiConfigFromActiveEntry();
    notifyListeners();
  }

  Future<void> enableAiModelEntry(String id) async {
    _aiModelEntries = _aiModelEntries.map((e) {
      return e.copyWith(enabled: e.id == id);
    }).toList();
    await _saveAiModelEntries();
    _syncAiConfigFromActiveEntry();
    notifyListeners();
  }

  Future<void> updateAiModelEntry(AiModelEntry updated) async {
    _aiModelEntries = _aiModelEntries.map((e) {
      return e.id == updated.id ? updated.copyWith(enabled: e.enabled) : e;
    }).toList();
    await _saveAiModelEntries();
    _syncAiConfigFromActiveEntry();
    notifyListeners();
  }

  void _syncAiConfigFromActiveEntry() {
    final active = activeAiModelEntry;
    if (active != null) {
      _aiEnhanceConfig = _aiEnhanceConfig.copyWith(
        baseUrl: active.baseUrl,
        apiKey: active.apiKey,
        model: active.model,
      );
      _saveSetting(_aiEnhanceConfigKey, json.encode(_aiEnhanceConfig.toJson()));
    }
  }

  // ===== 语音模型条目管理 =====

  Future<void> _saveSttModelEntries() async {
    await _saveSetting(
      _sttModelEntriesKey,
      json.encode(_sttModelEntries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addSttModelEntry(SttModelEntry entry) async {
    // 如果是第一个条目，自动启用
    final shouldEnable = _sttModelEntries.isEmpty;
    final newEntry = shouldEnable ? entry.copyWith(enabled: true) : entry;
    if (shouldEnable) {
      // 禁用其他
      _sttModelEntries = _sttModelEntries
          .map((e) => e.copyWith(enabled: false))
          .toList();
    }
    _sttModelEntries.add(newEntry);
    await _saveSttModelEntries();
    _syncSttConfigFromActiveEntry();
    notifyListeners();
  }

  Future<void> removeSttModelEntry(String id) async {
    _sttModelEntries.removeWhere((e) => e.id == id);
    await _saveSttModelEntries();
    _syncSttConfigFromActiveEntry();
    notifyListeners();
  }

  Future<void> enableSttModelEntry(String id) async {
    _sttModelEntries = _sttModelEntries.map((e) {
      return e.copyWith(enabled: e.id == id);
    }).toList();
    await _saveSttModelEntries();
    _syncSttConfigFromActiveEntry();
    notifyListeners();
  }

  Future<void> updateSttModelEntry(SttModelEntry updated) async {
    _sttModelEntries = _sttModelEntries.map((e) {
      return e.id == updated.id ? updated.copyWith(enabled: e.enabled) : e;
    }).toList();
    await _saveSttModelEntries();
    _syncSttConfigFromActiveEntry();
    notifyListeners();
  }

  void _syncSttConfigFromActiveEntry() {
    final active = activeSttModelEntry;
    if (active != null) {
      _config = _config.copyWith(
        name: active.vendorName,
        baseUrl: active.baseUrl,
        apiKey: active.apiKey,
        model: active.model,
      );
      _saveSetting(_configKey, json.encode(_config.toJson()));
    }
  }

  Future<void> addCustomProvider(SttProviderConfig provider) async {
    _customProviders.add(provider);
    await _saveSetting(
      'custom_providers',
      json.encode(_customProviders.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> removeCustomProvider(int index) async {
    _customProviders.removeAt(index);
    await _saveSetting(
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

  /// 设置语言
  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    await _saveSetting(_localeKey, locale.languageCode);
    notifyListeners();
  }

  Future<void> setNetworkProxyMode(NetworkProxyMode mode) async {
    _networkProxyMode = mode;
    NetworkClientService.setProxyMode(mode);
    await _saveSetting(_networkProxyModeKey, mode.storageValue);
    notifyListeners();
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _saveSetting(_themeModeKey, value);
    notifyListeners();
  }

  // ===== 通用持久化辅助 =====

  Future<void> _saveSetting(String key, String value) async {
    await AppDatabase.instance.setSetting(key, value);
  }
}
