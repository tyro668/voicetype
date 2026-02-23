import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_enhance_config.dart';
import '../models/ai_model_entry.dart';
import '../models/ai_vendor_preset.dart';
import '../models/network_settings.dart';
import '../models/provider_config.dart';
import '../models/stt_model_entry.dart';
import '../services/crypto_service.dart';
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

  List<SttProviderConfig> _sttPresets = List<SttProviderConfig>.from(
    SttProviderConfig.fallbackPresets,
  );
  List<AiVendorPreset> _aiPresets = List<AiVendorPreset>.from(
    AiVendorPreset.fallbackPresets,
  );
  SttProviderConfig _config = SttProviderConfig.fallbackPresets.first;
  List<SttProviderConfig> _customProviders = [];

  static const LogicalKeyboardKey defaultHotkey = LogicalKeyboardKey.fn;

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

  // ===== 加密辅助方法 =====

  /// 解析 API Key：支持明文、单层加密、历史双层加密。
  /// 如果最终仍是 ENC: 前缀，说明解密失败（如主密钥丢失），返回空字符串。
  String _resolveApiKey(String raw) {
    var value = raw.trim();
    for (var i = 0; i < 3; i++) {
      if (!value.startsWith('ENC:')) break;
      final decrypted = CryptoService.instance.decryptText(value).trim();
      if (decrypted == value) break;
      value = decrypted;
    }
    if (value.startsWith('ENC:')) {
      return '';
    }
    return value;
  }

  /// 加密 JSON Map 中的 apiKey 字段
  Map<String, dynamic> _encryptApiKeyInJson(Map<String, dynamic> jsonMap) {
    final copy = Map<String, dynamic>.from(jsonMap);
    final apiKey = copy['apiKey'];
    if (apiKey is String && apiKey.isNotEmpty) {
      final resolved = _resolveApiKey(apiKey);
      copy['apiKey'] = resolved.isEmpty
          ? ''
          : CryptoService.instance.encryptText(resolved);
    }
    return copy;
  }

  /// 解密 JSON Map 中的 apiKey 字段
  Map<String, dynamic> _decryptApiKeyInJson(Map<String, dynamic> jsonMap) {
    final copy = Map<String, dynamic>.from(jsonMap);
    final apiKey = copy['apiKey'];
    if (apiKey is String && apiKey.isNotEmpty) {
      copy['apiKey'] = _resolveApiKey(apiKey);
    }
    return copy;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // 初始化加密服务（必须在加载数据之前）
    await CryptoService.initialize();

    await _loadPresetsFromAssets();

    // 加载服务商配置（解密 apiKey）
    final configJson = prefs.getString(_configKey);
    if (configJson != null) {
      final decoded = json.decode(configJson) as Map<String, dynamic>;
      _config = SttProviderConfig.fromJson(_decryptApiKeyInJson(decoded));
    }

    // 加载自定义服务商（解密 apiKey）
    final customJson = prefs.getString('custom_providers');
    if (customJson != null) {
      _customProviders = (json.decode(customJson) as List)
          .map(
            (e) => SttProviderConfig.fromJson(
              _decryptApiKeyInJson(e as Map<String, dynamic>),
            ),
          )
          .toList();
    }

    // 加载 API Keys（解密值）
    final keysJson = prefs.getString('api_keys');
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

    final minSec = prefs.getInt(_minRecordingSecondsKey);
    if (minSec != null) {
      _minRecordingSeconds = minSec;
    }

    try {
      final prompt = await rootBundle.loadString(
        'assets/prompts/default_prompt.md',
      );
      _aiEnhanceDefaultPrompt = prompt;
    } catch (_) {}

    final aiEnhanceJson = prefs.getString(_aiEnhanceConfigKey);
    if (aiEnhanceJson != null) {
      final decoded = json.decode(aiEnhanceJson) as Map<String, dynamic>;
      _aiEnhanceConfig = AiEnhanceConfig.fromJson(
        _decryptApiKeyInJson(decoded),
      );
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

    // 加载文本模型条目列表（解密 apiKey）
    final entriesJson = prefs.getString(_aiModelEntriesKey);
    if (entriesJson != null) {
      try {
        final list = json.decode(entriesJson) as List<dynamic>;
        _aiModelEntries = list
            .whereType<Map<String, dynamic>>()
            .map((e) => AiModelEntry.fromJson(_decryptApiKeyInJson(e)))
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

    // 加载语音模型条目列表（解密 apiKey）
    final sttEntriesJson = prefs.getString(_sttModelEntriesKey);
    if (sttEntriesJson != null) {
      try {
        final list = json.decode(sttEntriesJson) as List<dynamic>;
        _sttModelEntries = list
            .whereType<Map<String, dynamic>>()
            .map((e) => SttModelEntry.fromJson(_decryptApiKeyInJson(e)))
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
    final localeStr = prefs.getString(_localeKey);
    if (localeStr != null) {
      _locale = Locale(localeStr);
    }

    final proxyModeStr = prefs.getString(_networkProxyModeKey);
    _networkProxyMode = NetworkProxyModeX.fromStorage(proxyModeStr);
    NetworkClientService.setProxyMode(_networkProxyMode);

    // 迁移：将所有明文密钥重新加密保存
    await _migrateEncryptKeys(prefs);

    notifyListeners();
  }

  /// 迁移旧的明文密钥到加密存储
  Future<void> _migrateEncryptKeys(SharedPreferences prefs) async {
    // 重新保存所有包含 apiKey 的数据（加密后写入）
    await _saveConfigEncrypted(prefs);
    await _saveApiKeysEncrypted(prefs);
    await _saveAiEnhanceConfigEncrypted(prefs);
    await _saveCustomProvidersEncrypted(prefs);
    if (_aiModelEntries.isNotEmpty) await _saveAiModelEntries();
    if (_sttModelEntries.isNotEmpty) await _saveSttModelEntries();
  }

  Future<void> _saveConfigEncrypted(SharedPreferences prefs) async {
    final configMap = _encryptApiKeyInJson(_config.toJson());
    await prefs.setString(_configKey, json.encode(configMap));
  }

  Future<void> _saveApiKeysEncrypted(SharedPreferences prefs) async {
    if (_apiKeys.isEmpty) return;
    final encrypted = <String, String>{};
    for (final entry in _apiKeys.entries) {
      final resolved = _resolveApiKey(entry.value);
      encrypted[entry.key] = resolved.isEmpty
          ? ''
          : CryptoService.instance.encryptText(resolved);
    }
    await prefs.setString('api_keys', json.encode(encrypted));
  }

  Future<void> _saveAiEnhanceConfigEncrypted(SharedPreferences prefs) async {
    final configMap = _encryptApiKeyInJson(_aiEnhanceConfig.toJson());
    await prefs.setString(_aiEnhanceConfigKey, json.encode(configMap));
  }

  Future<void> _saveCustomProvidersEncrypted(SharedPreferences prefs) async {
    if (_customProviders.isEmpty) return;
    final encrypted = _customProviders
        .map((e) => _encryptApiKeyInJson(e.toJson()))
        .toList();
    await prefs.setString('custom_providers', json.encode(encrypted));
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _configKey,
      json.encode(_encryptApiKeyInJson(config.toJson())),
    );
    notifyListeners();
  }

  /// 选择服务商（从 preset 或 custom 列表中选择）
  Future<void> selectProvider(SttProviderConfig provider) async {
    // 恢复该服务商之前存储的 apiKey
    final savedKey = _apiKeys[provider.name] ?? '';
    _config = provider.copyWith(apiKey: savedKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _configKey,
      json.encode(_encryptApiKeyInJson(_config.toJson())),
    );
    notifyListeners();
  }

  /// 设置当前服务商的 API Key
  Future<void> setApiKey(String apiKey) async {
    final normalizedApiKey = apiKey.trim();
    _apiKeys[_config.name] = normalizedApiKey;
    _config = _config.copyWith(apiKey: normalizedApiKey);
    final prefs = await SharedPreferences.getInstance();
    // 加密后存储 API Keys
    final encryptedKeys = <String, String>{};
    for (final entry in _apiKeys.entries) {
      final resolved = _resolveApiKey(entry.value);
      encryptedKeys[entry.key] = resolved.isEmpty
          ? ''
          : CryptoService.instance.encryptText(resolved);
    }
    await prefs.setString('api_keys', json.encode(encryptedKeys));
    await prefs.setString(
      _configKey,
      json.encode(_encryptApiKeyInJson(_config.toJson())),
    );
    notifyListeners();
  }

  /// 设置当前服务商的模型
  Future<void> setModel(String model) async {
    _config = _config.copyWith(model: model);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _configKey,
      json.encode(_encryptApiKeyInJson(_config.toJson())),
    );
    notifyListeners();
  }

  Future<void> setHotkey(LogicalKeyboardKey key) async {
    _hotkey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hotkeyKey, key.keyId);
    notifyListeners();
  }

  Future<void> resetHotkey() async {
    _hotkey = defaultHotkey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hotkeyKey);
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

  Future<void> setMinRecordingSeconds(int seconds) async {
    _minRecordingSeconds = seconds.clamp(1, 30);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_minRecordingSecondsKey, _minRecordingSeconds);
    notifyListeners();
  }

  Future<void> setAiEnhanceConfig(AiEnhanceConfig config) async {
    _aiEnhanceConfig = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _aiEnhanceConfigKey,
      json.encode(_encryptApiKeyInJson(config.toJson())),
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _aiEnhanceDefaultModelsKey,
      json.encode(_aiEnhanceDefaultModels),
    );
    notifyListeners();
  }

  // ===== 文本模型条目管理 =====

  Future<void> _saveAiModelEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final encryptedList = _aiModelEntries
        .map((e) => _encryptApiKeyInJson(e.toJson()))
        .toList();
    await prefs.setString(_aiModelEntriesKey, json.encode(encryptedList));
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
      // 同时持久化 aiEnhanceConfig（加密 apiKey）
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(
          _aiEnhanceConfigKey,
          json.encode(_encryptApiKeyInJson(_aiEnhanceConfig.toJson())),
        );
      });
    }
  }

  // ===== 语音模型条目管理 =====

  Future<void> _saveSttModelEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final encryptedList = _sttModelEntries
        .map((e) => _encryptApiKeyInJson(e.toJson()))
        .toList();
    await prefs.setString(_sttModelEntriesKey, json.encode(encryptedList));
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
      // 同时持久化 config（加密 apiKey）
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(
          _configKey,
          json.encode(_encryptApiKeyInJson(_config.toJson())),
        );
      });
    }
  }

  Future<void> addCustomProvider(SttProviderConfig provider) async {
    _customProviders.add(provider);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'custom_providers',
      json.encode(
        _customProviders.map((e) => _encryptApiKeyInJson(e.toJson())).toList(),
      ),
    );
    notifyListeners();
  }

  Future<void> removeCustomProvider(int index) async {
    _customProviders.removeAt(index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'custom_providers',
      json.encode(
        _customProviders.map((e) => _encryptApiKeyInJson(e.toJson())).toList(),
      ),
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
    notifyListeners();
  }

  Future<void> setNetworkProxyMode(NetworkProxyMode mode) async {
    _networkProxyMode = mode;
    NetworkClientService.setProxyMode(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_networkProxyModeKey, mode.storageValue);
    notifyListeners();
  }
}
