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
            },
          ],
          'usage': {'prompt_tokens': 50, 'completion_tokens': 20},
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
        aiConfig: AiEnhanceConfig(
          agentName: 'test',
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
        aiConfig: AiEnhanceConfig(
          agentName: 'test',
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
        aiConfig: AiEnhanceConfig(
          agentName: 'test',
          baseUrl: baseUrl,
          apiKey: 'test-key',
          model: 'test-model',
          prompt: '',
        ),
        correctionPrompt: '纠错 prompt',
      );

      final result = await service.correct('今天用了帆软做报表');
      expect(result.text, '今天用了帆软做报表');
      expect(result.llmInvoked, isTrue);
      expect(result.promptTokens, 50);
      expect(result.completionTokens, 20);
    });

    test(
      'normalizes homophonic Chinese variants via one canonical pinyin alias rule',
      () async {
        matcher.buildIndex([
          DictionaryEntry.create(original: '好数连', corrected: 'hao shu lian'),
        ]);

        setupMockServer('好数联和好树练以及号书练都在这里');

        final service = CorrectionService(
          matcher: matcher,
          context: context,
          aiConfig: AiEnhanceConfig(
            agentName: 'test',
            baseUrl: baseUrl,
            apiKey: 'test-key',
            model: 'test-model',
            prompt: '',
          ),
          correctionPrompt: '纠错 prompt',
          maxReferenceEntries: 12,
          minCandidateScore: 0.1,
        );

        final result = await service.correct('好数联和好树练以及号书练都在这里');
        expect(result.text, '好数连和好数连以及好数连都在这里');
      },
    );

    test('context is updated after correction', () async {
      matcher.buildIndex([
        DictionaryEntry.create(original: '帆软', corrected: 'FanRuan'),
      ]);

      setupMockServer('FanRuan数据');

      final service = CorrectionService(
        matcher: matcher,
        context: context,
        aiConfig: AiEnhanceConfig(
          agentName: 'test',
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
        aiConfig: AiEnhanceConfig(
          agentName: 'test',
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

    test(
      'uses local normalization fallback on LLM failure for homophones',
      () async {
        matcher.buildIndex([
          DictionaryEntry.create(original: '好数连', corrected: 'hao shu lian'),
          DictionaryEntry.create(original: '帆软', corrected: 'FanRuan'),
        ]);

        server.listen((request) async {
          request.response
            ..statusCode = 500
            ..write('Internal Server Error');
          await request.response.close();
        });

        final service = CorrectionService(
          matcher: matcher,
          context: context,
          aiConfig: AiEnhanceConfig(
            agentName: 'test',
            baseUrl: baseUrl,
            apiKey: 'test-key',
            model: 'test-model',
            prompt: '',
          ),
          correctionPrompt: '纠错 prompt',
        );

        final input = '好数联这个产品跟帆软的其他产品不太一样，它是一个底层数据治理工具。';
        final result = await service.correct(input);
        expect(result.text, '好数连这个产品跟帆软的其他产品不太一样，它是一个底层数据治理工具。');
        expect(result.llmInvoked, isFalse);
      },
    );

    test('limits #R references by maxReferenceEntries', () async {
      matcher.buildIndex([
        DictionaryEntry.create(original: '兴阔', corrected: '星阔'),
        DictionaryEntry.create(original: '蓝乔', corrected: '蓝桥'),
        DictionaryEntry.create(original: '云凡', corrected: '云帆'),
      ]);

      String capturedReference = '';
      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        final payload = json.decode(body) as Map<String, dynamic>;
        final messages = payload['messages'] as List<dynamic>? ?? [];
        final userMessage = messages.isNotEmpty
            ? (messages.last as Map<String, dynamic>)['content'] as String? ??
                  ''
            : '';
        for (final line in userMessage.split('\n')) {
          if (line.startsWith('#R: ')) {
            capturedReference = line.substring(4).trim();
            break;
          }
        }

        final responseJson = json.encode({
          'choices': [
            {
              'message': {'content': '星阔和蓝桥都在开会'},
            },
          ],
          'usage': {'prompt_tokens': 12, 'completion_tokens': 6},
        });
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(responseJson);
        await request.response.close();
      });

      final service = CorrectionService(
        matcher: matcher,
        context: context,
        aiConfig: AiEnhanceConfig(
          agentName: 'test',
          baseUrl: baseUrl,
          apiKey: 'test-key',
          model: 'test-model',
          prompt: '',
        ),
        correctionPrompt: '纠错 prompt',
        maxReferenceEntries: 1,
        minCandidateScore: 0,
      );

      final result = await service.correct('兴阔和蓝乔都在开会');
      expect(result.llmInvoked, isTrue);
      expect(capturedReference, isNotEmpty);
      final refs = capturedReference
          .split('|')
          .where((e) => e.isNotEmpty)
          .toList();
      expect(refs.length, 1);
    });

    test('regression samples: 12 boundary cases', () async {
      final dictionaries = <DictionaryEntry>[
        DictionaryEntry.create(original: '兴阔', corrected: '星阔'),
        DictionaryEntry.create(original: '蓝乔', corrected: '蓝桥'),
        DictionaryEntry.create(original: '云凡', corrected: '云帆'),
        DictionaryEntry.create(original: '云凡平台', corrected: '云帆平台'),
        DictionaryEntry.create(original: '星阔', corrected: 'XingKuo'),
        DictionaryEntry.create(original: 'xing kuo', corrected: '星阔'),
        DictionaryEntry.create(original: 'xing-kuo', corrected: '星阔'),
        DictionaryEntry.create(original: 'xingkuo', corrected: '星阔'),
        DictionaryEntry.create(original: 'sdk', corrected: 'SDK'),
        DictionaryEntry.create(original: 'SDK'),
        DictionaryEntry.create(original: 'OpenAPI'),
        DictionaryEntry.create(original: 'Metis'),
      ];
      matcher.buildIndex(dictionaries);

      final cases = <Map<String, dynamic>>[
        {
          'input': '兴阔今年发布了新产品。',
          'model': '星阔今年发布了新产品。',
          'expected': '星阔今年发布了新产品。',
        },
        {
          'input': '蓝乔的报表系统很稳定。',
          'model': '蓝桥的报表系统很稳定。',
          'expected': '蓝桥的报表系统很稳定。',
        },
        {
          'input': '云凡平台支持实时同步。',
          'model': '云帆平台支持实时同步。',
          'expected': '云帆平台支持实时同步。',
        },
        {
          'input': 'XingKuo 的数据中心上线了。',
          'model': 'XingKuo的数据中心上线了。',
          'expected': '星阔的数据中心上线了。',
        },
        {
          'input': 'xing kuo 本周完成迁移。',
          'model': '星阔本周完成迁移。',
          'expected': '星阔本周完成迁移。',
        },
        {
          'input': 'xing-kuo 报表性能提升明显。',
          'model': '星阔报表性能提升明显。',
          'expected': '星阔报表性能提升明显。',
        },
        {
          'input': '兴阔和蓝乔都在做云凡项目。',
          'model': '星阔和蓝桥都在做云帆项目。',
          'expected': '星阔和蓝桥都在做云帆项目。',
        },
        {
          'input': '今天在 Metis 上跑了任务。',
          'model': '今天在 Metis 上跑了任务。',
          'expected': '今天在 Metis 上跑了任务。',
        },
        {
          'input': 'openapi 文档需要更新。',
          'model': 'OpenAPI 文档需要更新。',
          'expected': 'OpenAPI 文档需要更新。',
        },
        {'input': '库存还有多少？', 'model': '库存还有多少？', 'expected': '库存还有多少？'},
        {
          'input': '公园里有一座蓝色的小桥。',
          'model': '公园里有一座蓝色的小桥。',
          'expected': '公园里有一座蓝色的小桥。',
        },
        {
          'input': 'xing kuo sdk 今天发版。',
          'model': '星阔 SDK 今天发版。',
          'expected': '星阔 SDK 今天发版。',
        },
      ];

      final modelByInput = <String, String>{
        for (final item in cases)
          item['input'] as String: item['model'] as String,
      };

      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        final payload = json.decode(body) as Map<String, dynamic>;
        final messages = payload['messages'] as List<dynamic>? ?? [];
        final userMessage = messages.isNotEmpty
            ? (messages.last as Map<String, dynamic>)['content'] as String? ??
                  ''
            : '';
        String input = '';
        for (final line in userMessage.split('\n')) {
          if (line.startsWith('#I: ')) {
            input = line.substring(4).trim();
            break;
          }
        }

        final content = modelByInput[input] ?? input;

        final responseJson = json.encode({
          'choices': [
            {
              'message': {'content': content},
            },
          ],
          'usage': {'prompt_tokens': 10, 'completion_tokens': 5},
        });
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(responseJson);
        await request.response.close();
      });

      final service = CorrectionService(
        matcher: matcher,
        context: context,
        aiConfig: AiEnhanceConfig(
          agentName: 'test',
          baseUrl: baseUrl,
          apiKey: 'test-key',
          model: 'test-model',
          prompt: '',
        ),
        correctionPrompt: '纠错 prompt',
        maxReferenceEntries: 15,
        minCandidateScore: 0,
      );

      for (final item in cases) {
        final result = await service.correct(item['input'] as String);
        expect(result.text, item['expected']);
      }
    });
  });
}
