import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicetype/models/stt_model_entry.dart';

void main() {
  group('SttModelEntry', () {
    test('toJson and fromJson round-trip', () {
      const entry = SttModelEntry(
        id: 'uuid-456',
        vendorName: 'Z.ai',
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
        model: 'GLM-ASR-2512',
        apiKey: 'test-key',
        enabled: true,
      );

      final json = entry.toJson();
      final restored = SttModelEntry.fromJson(json);

      expect(restored.id, entry.id);
      expect(restored.vendorName, entry.vendorName);
      expect(restored.baseUrl, entry.baseUrl);
      expect(restored.model, entry.model);
      expect(restored.apiKey, entry.apiKey);
      expect(restored.enabled, entry.enabled);
    });

    test('fromJson uses defaults for missing fields', () {
      final entry = SttModelEntry.fromJson({});

      expect(entry.id, '');
      expect(entry.vendorName, '');
      expect(entry.baseUrl, '');
      expect(entry.model, '');
      expect(entry.apiKey, '');
      expect(entry.enabled, false);
    });

    test('copyWith creates modified copy', () {
      const original = SttModelEntry(
        id: 'uuid-1',
        vendorName: 'Vendor1',
        baseUrl: 'https://example.com',
        model: 'whisper-1',
        apiKey: 'key1',
        enabled: false,
      );

      final modified = original.copyWith(model: 'whisper-2', enabled: true);

      expect(modified.id, original.id);
      expect(modified.vendorName, original.vendorName);
      expect(modified.baseUrl, original.baseUrl);
      expect(modified.model, 'whisper-2');
      expect(modified.apiKey, original.apiKey);
      expect(modified.enabled, true);
    });

    test('listToJson and listFromJson round-trip', () {
      const entries = [
        SttModelEntry(
          id: '1',
          vendorName: 'V1',
          baseUrl: 'https://a.com',
          model: 'm1',
          apiKey: 'k1',
          enabled: true,
        ),
        SttModelEntry(
          id: '2',
          vendorName: 'V2',
          baseUrl: 'https://b.com',
          model: 'm2',
          apiKey: 'k2',
        ),
      ];

      final jsonStr = SttModelEntry.listToJson(entries);
      final restored = SttModelEntry.listFromJson(jsonStr);

      expect(restored.length, 2);
      expect(restored[0].id, '1');
      expect(restored[0].enabled, true);
      expect(restored[1].id, '2');
      expect(restored[1].enabled, false);
    });

    test('listFromJson with empty list', () {
      final restored = SttModelEntry.listFromJson('[]');
      expect(restored, isEmpty);
    });

    test('listToJson with empty list', () {
      final jsonStr = SttModelEntry.listToJson([]);
      expect(json.decode(jsonStr), isEmpty);
    });
  });
}
