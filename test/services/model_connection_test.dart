import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicetype/models/ai_enhance_config.dart';
import 'package:voicetype/models/provider_config.dart';
import 'package:voicetype/services/ai_enhance_service.dart';
import 'package:voicetype/services/stt_service.dart';

void main() {
  const aliyunBaseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1';
  final runAliyunRealTest =
      (Platform.environment['RUN_ALIYUN_COMPAT_TEST'] ?? '') == '1';
  final aliyunApiKey = (Platform.environment['ALIYUN_DASHSCOPE_API_KEY'] ?? '')
      .trim();
  final aliyunSttModel =
      (Platform.environment['ALIYUN_STT_MODEL'] ?? 'qwen3-asr-flash').trim();
  final aliyunTextModel =
      (Platform.environment['ALIYUN_TEXT_MODEL'] ?? 'qwen-plus').trim();

  group('模型测试连接', () {
    test('Aliyun 与 OpenAI 兼容模型都可以测试连接成功', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

      server.listen((HttpRequest request) async {
        final auth = request.headers.value(HttpHeaders.authorizationHeader);
        if (auth == null || auth.isEmpty) {
          request.response.statusCode = HttpStatus.unauthorized;
          request.response.write(
            json.encode({
              'error': {'message': 'Missing Authorization header'},
            }),
          );
          await request.response.close();
          return;
        }

        if (request.uri.path.endsWith('/models')) {
          request.response.statusCode = HttpStatus.ok;
          request.response.write(
            json.encode({
              'object': 'list',
              'data': [
                {'id': 'qwen3-asr-flash'},
                {'id': 'qwen-plus'},
                {'id': 'deepseek-chat'},
              ],
            }),
          );
          await request.response.close();
          return;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });

      addTearDown(() async {
        await server.close(force: true);
      });

      final baseUrl = 'http://${server.address.address}:${server.port}/v1';

      final sttConfigs = <SttProviderConfig>[
        SttProviderConfig(
          type: SttProviderType.cloud,
          name: 'Aliyun',
          baseUrl: baseUrl,
          apiKey: 'sk-aliyun-test',
          model: 'qwen3-asr-flash',
        ),
        SttProviderConfig(
          type: SttProviderType.cloud,
          name: 'OpenAI Compatible',
          baseUrl: baseUrl,
          apiKey: 'sk-openai-test',
          model: 'whisper-1',
        ),
      ];

      for (final config in sttConfigs) {
        final result = await SttService(config).checkAvailabilityDetailed();
        expect(
          result.ok,
          isTrue,
          reason: '语音模型 ${config.model} 应该测试连接成功，实际: ${result.message}',
        );
      }

      final aiConfigs = <AiEnhanceConfig>[
        const AiEnhanceConfig(
          baseUrl: 'http://127.0.0.1:1',
          apiKey: 'placeholder',
          model: 'placeholder',
          prompt: AiEnhanceConfig.defaultPrompt,
          agentName: AiEnhanceConfig.defaultAgentName,
        ).copyWith(
          baseUrl: baseUrl,
          apiKey: 'sk-aliyun-text-test',
          model: 'qwen-plus',
        ),
        const AiEnhanceConfig(
          baseUrl: 'http://127.0.0.1:1',
          apiKey: 'placeholder',
          model: 'placeholder',
          prompt: AiEnhanceConfig.defaultPrompt,
          agentName: AiEnhanceConfig.defaultAgentName,
        ).copyWith(
          baseUrl: baseUrl,
          apiKey: 'sk-deepseek-test',
          model: 'deepseek-chat',
        ),
      ];

      for (final config in aiConfigs) {
        final result = await AiEnhanceService(
          config,
        ).checkAvailabilityDetailed();
        expect(
          result.ok,
          isTrue,
          reason: '文本模型 ${config.model} 应该测试连接成功，实际: ${result.message}',
        );
      }
    });

    test(
      'Aliyun 真实 compatible-mode/v1 地址可测试连接成功（环境变量开关）',
      () async {
        final sttConfig = SttProviderConfig(
          type: SttProviderType.cloud,
          name: 'Aliyun',
          baseUrl: aliyunBaseUrl,
          apiKey: aliyunApiKey,
          model: aliyunSttModel,
        );

        final sttResult = await SttService(
          sttConfig,
        ).checkAvailabilityDetailed();
        expect(
          sttResult.ok,
          isTrue,
          reason: 'Aliyun 语音模型连接失败: ${sttResult.message}',
        );

        final aiConfig =
            const AiEnhanceConfig(
              baseUrl: 'http://127.0.0.1:1',
              apiKey: 'placeholder',
              model: 'placeholder',
              prompt: AiEnhanceConfig.defaultPrompt,
              agentName: AiEnhanceConfig.defaultAgentName,
            ).copyWith(
              baseUrl: aliyunBaseUrl,
              apiKey: aliyunApiKey,
              model: aliyunTextModel,
            );

        final aiResult = await AiEnhanceService(
          aiConfig,
        ).checkAvailabilityDetailed();
        expect(
          aiResult.ok,
          isTrue,
          reason: 'Aliyun 文本模型连接失败: ${aiResult.message}',
        );
      },
      skip: !runAliyunRealTest || aliyunApiKey.isEmpty,
    );
  });
}
