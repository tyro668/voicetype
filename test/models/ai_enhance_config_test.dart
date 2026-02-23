import 'package:flutter_test/flutter_test.dart';
import 'package:voicetype/models/ai_enhance_config.dart';

void main() {
  group('AiEnhanceConfig', () {
    test('toJson and fromJson round-trip', () {
      const config = AiEnhanceConfig(
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'test-key-123',
        model: 'gpt-4',
        prompt: 'Fix my text',
        agentName: 'TestAgent',
      );

      final json = config.toJson();
      final restored = AiEnhanceConfig.fromJson(json);

      expect(restored.baseUrl, config.baseUrl);
      expect(restored.apiKey, config.apiKey);
      expect(restored.model, config.model);
      expect(restored.prompt, config.prompt);
      expect(restored.agentName, config.agentName);
    });

    test('fromJson uses defaults for missing fields', () {
      final config = AiEnhanceConfig.fromJson({});

      expect(config.baseUrl, AiEnhanceConfig.defaultConfig.baseUrl);
      expect(config.apiKey, '');
      expect(config.model, AiEnhanceConfig.defaultConfig.model);
      expect(config.prompt, AiEnhanceConfig.defaultConfig.prompt);
      expect(config.agentName, AiEnhanceConfig.defaultConfig.agentName);
    });

    test('copyWith creates modified copy', () {
      const original = AiEnhanceConfig(
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'key1',
        model: 'model1',
        prompt: 'prompt1',
        agentName: 'agent1',
      );

      final modified = original.copyWith(apiKey: 'key2', model: 'model2');

      expect(modified.baseUrl, original.baseUrl);
      expect(modified.apiKey, 'key2');
      expect(modified.model, 'model2');
      expect(modified.prompt, original.prompt);
      expect(modified.agentName, original.agentName);
    });

    test('copyWith with no arguments returns equivalent copy', () {
      const original = AiEnhanceConfig(
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'key1',
        model: 'model1',
        prompt: 'prompt1',
        agentName: 'agent1',
      );

      final copy = original.copyWith();

      expect(copy.baseUrl, original.baseUrl);
      expect(copy.apiKey, original.apiKey);
      expect(copy.model, original.model);
      expect(copy.prompt, original.prompt);
      expect(copy.agentName, original.agentName);
    });

    test('defaultConfig has expected values', () {
      expect(AiEnhanceConfig.defaultConfig.baseUrl, isNotEmpty);
      expect(AiEnhanceConfig.defaultConfig.apiKey, isEmpty);
      expect(AiEnhanceConfig.defaultConfig.model, isNotEmpty);
      expect(AiEnhanceConfig.defaultConfig.prompt, isNotEmpty);
      expect(AiEnhanceConfig.defaultConfig.agentName, isNotEmpty);
    });
  });
}
