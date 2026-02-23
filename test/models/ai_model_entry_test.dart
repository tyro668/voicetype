import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicetype/models/ai_model_entry.dart';

void main() {
  group('AiModelEntry', () {
    test('toJson and fromJson round-trip', () {
      const entry = AiModelEntry(
        id: 'uuid-123',
        vendorName: 'OpenAI',
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4',
        apiKey: 'sk-test',
        enabled: true,
      );

      final json = entry.toJson();
      final restored = AiModelEntry.fromJson(json);

      expect(restored.id, entry.id);
      expect(restored.vendorName, entry.vendorName);
      expect(restored.baseUrl, entry.baseUrl);
      expect(restored.model, entry.model);
      expect(restored.apiKey, entry.apiKey);
      expect(restored.enabled, entry.enabled);
    });

    test('fromJson uses defaults for missing fields', () {
      final entry = AiModelEntry.fromJson({});

      expect(entry.id, '');
      expect(entry.vendorName, '');
      expect(entry.baseUrl, '');
      expect(entry.model, '');
      expect(entry.apiKey, '');
      expect(entry.enabled, false);
    });

    test('copyWith creates modified copy', () {
      const original = AiModelEntry(
        id: 'uuid-1',
        vendorName: 'Vendor1',
        baseUrl: 'https://example.com',
        model: 'model1',
        apiKey: 'key1',
        enabled: false,
      );

      final modified = original.copyWith(vendorName: 'Vendor2', enabled: true);

      expect(modified.id, original.id); // id is not copyable
      expect(modified.vendorName, 'Vendor2');
      expect(modified.baseUrl, original.baseUrl);
      expect(modified.model, original.model);
      expect(modified.apiKey, original.apiKey);
      expect(modified.enabled, true);
    });

    test('listToJson and listFromJson round-trip', () {
      const entries = [
        AiModelEntry(
          id: '1',
          vendorName: 'V1',
          baseUrl: 'https://a.com',
          model: 'm1',
          apiKey: 'k1',
          enabled: true,
        ),
        AiModelEntry(
          id: '2',
          vendorName: 'V2',
          baseUrl: 'https://b.com',
          model: 'm2',
          apiKey: 'k2',
          enabled: false,
        ),
      ];

      final jsonStr = AiModelEntry.listToJson(entries);
      final restored = AiModelEntry.listFromJson(jsonStr);

      expect(restored.length, 2);
      expect(restored[0].id, '1');
      expect(restored[0].vendorName, 'V1');
      expect(restored[0].enabled, true);
      expect(restored[1].id, '2');
      expect(restored[1].vendorName, 'V2');
      expect(restored[1].enabled, false);
    });

    test('listFromJson with empty list', () {
      final restored = AiModelEntry.listFromJson('[]');
      expect(restored, isEmpty);
    });

    test('listToJson with empty list', () {
      final jsonStr = AiModelEntry.listToJson([]);
      expect(json.decode(jsonStr), isEmpty);
    });
  });
}
