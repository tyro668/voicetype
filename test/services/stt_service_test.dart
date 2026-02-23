import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicetype/models/provider_config.dart';
import 'package:voicetype/services/stt_service.dart';

void main() {
  group('SttService', () {
    group('checkAvailabilityDetailed', () {
      test('returns ok=true for 200 /models response', () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));

        server.listen((req) async {
          if (req.uri.path.endsWith('/models')) {
            req.response.statusCode = 200;
            req.response.write(
              json.encode({
                'object': 'list',
                'data': [
                  {'id': 'whisper-1'},
                ],
              }),
            );
          }
          await req.response.close();
        });

        final config = SttProviderConfig(
          type: SttProviderType.cloud,
          name: 'Test',
          baseUrl: 'http://127.0.0.1:${server.port}/v1',
          apiKey: 'test-key',
          model: 'whisper-1',
        );

        final result = await SttService(config).checkAvailabilityDetailed();
        expect(result.ok, isTrue);
      });

      test('returns ok=false for empty API key', () async {
        const config = SttProviderConfig(
          type: SttProviderType.cloud,
          name: 'Test',
          baseUrl: 'https://example.com/v1',
          apiKey: '',
          model: 'whisper-1',
        );

        final result = await SttService(config).checkAvailabilityDetailed();
        expect(result.ok, isFalse);
      });

      test(
        'returns ok=false for ENC: prefixed API key (decrypt failure)',
        () async {
          const config = SttProviderConfig(
            type: SttProviderType.cloud,
            name: 'Test',
            baseUrl: 'https://example.com/v1',
            apiKey: 'ENC:bad-encrypted',
            model: 'whisper-1',
          );

          final result = await SttService(config).checkAvailabilityDetailed();
          expect(result.ok, isFalse);
        },
      );

      test('returns ok=true for 404 /models (server reachable)', () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));

        server.listen((req) async {
          req.response.statusCode = 404;
          await req.response.close();
        });

        final config = SttProviderConfig(
          type: SttProviderType.cloud,
          name: 'Test',
          baseUrl: 'http://127.0.0.1:${server.port}/v1',
          apiKey: 'test-key',
          model: 'whisper-1',
        );

        final result = await SttService(config).checkAvailabilityDetailed();
        expect(result.ok, isTrue);
      });

      test('returns ok=false for 401 /models (auth error)', () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));

        server.listen((req) async {
          req.response.statusCode = 401;
          req.response.write(
            json.encode({
              'error': {'message': 'Invalid API key'},
            }),
          );
          await req.response.close();
        });

        final config = SttProviderConfig(
          type: SttProviderType.cloud,
          name: 'Test',
          baseUrl: 'http://127.0.0.1:${server.port}/v1',
          apiKey: 'bad-key',
          model: 'whisper-1',
        );

        final result = await SttService(config).checkAvailabilityDetailed();
        expect(result.ok, isFalse);
        expect(result.message, contains('API'));
      });

      test('returns ok=false for unreachable host', () async {
        const config = SttProviderConfig(
          type: SttProviderType.cloud,
          name: 'Test',
          baseUrl: 'http://127.0.0.1:1/v1', // unlikely to have a server here
          apiKey: 'test-key',
          model: 'whisper-1',
        );

        final result = await SttService(config).checkAvailabilityDetailed();
        expect(result.ok, isFalse);
      });
    });

    group('transcribe', () {
      test('returns transcribed text for 200 response', () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));

        server.listen((req) async {
          if (req.uri.path.endsWith('/audio/transcriptions')) {
            req.response.statusCode = 200;
            req.response.write(json.encode({'text': 'Hello world'}));
          } else {
            req.response.statusCode = 404;
          }
          await req.response.close();
        });

        final config = SttProviderConfig(
          type: SttProviderType.cloud,
          name: 'Test',
          baseUrl: 'http://127.0.0.1:${server.port}/v1',
          apiKey: 'test-key',
          model: 'whisper-1',
        );

        // Create a temporary wav file
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/test_audio.wav');
        await tempFile.writeAsBytes([0, 0, 0, 0]); // minimal bytes
        addTearDown(() => tempFile.deleteSync());

        final result = await SttService(config).transcribe(tempFile.path);
        expect(result, 'Hello world');
      });

      test(
        'aliyun fallback works when /audio/transcriptions returns 500',
        () async {
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(() => server.close(force: true));

          server.listen((req) async {
            final path = req.uri.path;
            if (path.endsWith('/audio/transcriptions')) {
              req.response.statusCode = 500;
              req.response.write(
                json.encode({
                  'error': {'message': 'upstream unstable'},
                }),
              );
            } else if (path.endsWith('/chat/completions')) {
              req.response.statusCode = 200;
              req.response.write(
                json.encode({
                  'choices': [
                    {
                      'message': {'content': 'Aliyun fallback text'},
                    },
                  ],
                }),
              );
            } else {
              req.response.statusCode = 404;
            }
            await req.response.close();
          });

          final config = SttProviderConfig(
            type: SttProviderType.cloud,
            name: '阿里云',
            baseUrl:
                'http://127.0.0.1:${server.port}/dashscope.aliyuncs.com/compatible-mode/v1',
            apiKey: 'test-key',
            model: 'qwen3-asr-flash',
          );

          final tempFile = File(
            '${Directory.systemTemp.path}/test_audio_fallback.wav',
          );
          await tempFile.writeAsBytes([0, 0, 0, 0]);
          addTearDown(() => tempFile.deleteSync());

          final result = await SttService(config).transcribe(tempFile.path);
          expect(result, 'Aliyun fallback text');
        },
      );

      test('throws SttException for empty API key', () async {
        const config = SttProviderConfig(
          type: SttProviderType.cloud,
          name: 'Test',
          baseUrl: 'http://127.0.0.1:1/v1',
          apiKey: '',
          model: 'whisper-1',
        );

        expect(
          () => SttService(config).transcribe('/tmp/fake.wav'),
          throwsA(isA<SttException>()),
        );
      });

      test('throws SttException for non-200 response', () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));

        server.listen((req) async {
          req.response.statusCode = 500;
          req.response.write(
            json.encode({
              'error': {'message': 'Internal server error'},
            }),
          );
          await req.response.close();
        });

        final config = SttProviderConfig(
          type: SttProviderType.cloud,
          name: 'Test',
          baseUrl: 'http://127.0.0.1:${server.port}/v1',
          apiKey: 'test-key',
          model: 'whisper-1',
        );

        final tempFile = File('${Directory.systemTemp.path}/test_audio2.wav');
        await tempFile.writeAsBytes([0, 0, 0, 0]);
        addTearDown(() => tempFile.deleteSync());

        expect(
          () => SttService(config).transcribe(tempFile.path),
          throwsA(isA<SttException>()),
        );
      });
    });

    group('SttException', () {
      test('toString returns message', () {
        final exception = SttException('test error');
        expect(exception.toString(), 'test error');
        expect(exception.message, 'test error');
      });
    });
  });
}
