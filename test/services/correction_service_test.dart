import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicetype/models/ai_enhance_config.dart';
import 'package:voicetype/models/dictionary_entry.dart';
import 'package:voicetype/services/correction_context.dart';
import 'package:voicetype/services/correction_service.dart';
import 'package:voicetype/services/pinyin_matcher.dart';

void main() {
  group('CorrectionService', () {
    late PinyinMatcher matcher;
    late CorrectionContext context;
    late HttpServer server;
    late String baseUrl;

    setUp(() async {
      matcher = PinyinMatcher();
      context = CorrectionContext();

      // Start a local mock server
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUrl = 'http://localhost:${server.port}';
    });

    tearDown(() async {
      await server.close(force: true);
    });

    /// Helper to create mock LLM server that echoes back a fixed response
    void setupMockServer(String responseText) {
      server.listen((request) async {
        final responseJson = json.encode({
          'choices': [
            {
              'message': {'content': responseText},
            }
          ],
          'usage': {
            'prompt_tokens': 50,
            'completion_tokens': 20,
          },
        });
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(responseJson);
        await request.response.close();
      });
    }

    test('returns original text when no dictionary matches', () async {
      matcher.buildIndex([]); // empty dictionary

      final service = CorrectionService(
        matcher: matcher,
        context: context,
        aiConfig: AiEnhanceConfig(agentName: 'test', 
          baseUrl: baseUrl,
          apiKey: 'test-key',
          model: 'test-model',
          prompt: '',
        ),
        correctionPrompt: '纠错 prompt',
      );

      final result = await service.correct('今天天气不错');
      expect(result.text, '今天天气不错');
      expect(result.llmInvoked, isFalse);
      expect(result.totalTokens, 0);
    });

    test('returns original text for empty input', () async {
      matcher.buildIndex([
        DictionaryEntry.create(original: '帆软', corrected: 'FanRuan'),
      ]);

      final service = CorrectionService(
        matcher: matcher,
        context: context,
        aiConfig: AiEnhanceConfig(agentName: 'test', 
          baseUrl: baseUrl,
          apiKey: 'test-key',
          model: 'test-model',
          prompt: '',
        ),
        correctionPrompt: '纠错 prompt',
      );

      final result = await service.correct('');
      expect(result.text, '');
      expect(result.llmInvoked, isFalse);
    });

    test('calls LLM when dictionary match found', () async {
      matcher.buildIndex([
        DictionaryEntry.create(original: '帆软', corrected: 'FanRuan'),
      ]);

      setupMockServer('今天用了FanRuan做报表');

      final service = CorrectionService(
        matcher: matcher,
        context: context,
        aiConfig: AiEnhanceConfig(agentName: 'test', 
          baseUrl: baseUrl,
          apiKey: 'test-key',
          model: 'test-model',
          prompt: '',
        ),
        correctionPrompt: '纠错 prompt',
      );

      final result = await service.correct('今天用了帆软做报表');
      expect(result.text, '今天用了FanRuan做报表');
      expect(result.llmInvoked, isTrue);
      expect(result.promptTokens, 50);
      expect(result.completionTokens, 20);
    });

    test('context is updated after correction', () async {
      matcher.buildIndex([
        DictionaryEntry.create(original: '帆软', corrected: 'FanRuan'),
      ]);

      setupMockServer('FanRuan数据');

      final service = CorrectionService(
        matcher: matcher,
        context: context,
        aiConfig: AiEnhanceConfig(agentName: 'test', 
          baseUrl: baseUrl,
          apiKey: 'test-key',
          model: 'test-model',
          prompt: '',
        ),
        correctionPrompt: '纠错 prompt',
      );

      await service.correct('帆软数据');
      expect(context.hasContext, isTrue);
      expect(context.segmentCount, 1);
    });

    test('falls back to original text on LLM failure', () async {
      matcher.buildIndex([
        DictionaryEntry.create(original: '帆软', corrected: 'FanRuan'),
      ]);

      // Server returns error
      server.listen((request) async {
        request.response
          ..statusCode = 500
          ..write('Internal Server Error');
        await request.response.close();
      });

      final service = CorrectionService(
        matcher: matcher,
        context: context,
        aiConfig: AiEnhanceConfig(agentName: 'test', 
          baseUrl: baseUrl,
          apiKey: 'test-key',
          model: 'test-model',
          prompt: '',
        ),
        correctionPrompt: '纠错 prompt',
      );

      final result = await service.correct('帆软数据');
      // Should fall back to original text
      expect(result.text, '帆软数据');
      expect(result.llmInvoked, isFalse);
    });
  });
}
