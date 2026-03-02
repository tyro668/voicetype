import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'log_service.dart';

enum ThreeDSpeakerDownloadSourceMode { auto, directOnly, mirrorOnly }

class ThreeDSpeakerModelService {
  static const String defaultRelativeDir = 'models/3d-speaker';
  static const String defaultFileName = 'model.onnx';

  static const List<String> _baseModelUrls = [
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/3dspeaker_speech_campplus_sv_zh_en_16k-common_advanced.onnx',
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/3dspeaker_speech_campplus_sv_zh-cn_16k-common.onnx',
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/3dspeaker_speech_campplus_sv_en_voxceleb_16k.onnx',
  ];

  static const List<String> _mirrorPrefixes = [
    'https://ghproxy.com/',
    'https://mirror.ghproxy.com/',
    'https://github.moeyy.xyz/',
  ];

  static List<String> _buildAutoModelUrls() {
    final urls = <String>[];
    for (final base in _baseModelUrls) {
      for (final prefix in _mirrorPrefixes) {
        urls.add('$prefix$base');
      }
      urls.add(base);
    }
    return urls;
  }

  static List<String> _buildDirectModelUrls() {
    return List<String>.from(_baseModelUrls);
  }

  static List<String> _buildMirrorModelUrls() {
    final urls = <String>[];
    for (final base in _baseModelUrls) {
      for (final prefix in _mirrorPrefixes) {
        urls.add('$prefix$base');
      }
    }
    return urls;
  }

  static List<String> _buildModelUrls(ThreeDSpeakerDownloadSourceMode mode) {
    switch (mode) {
      case ThreeDSpeakerDownloadSourceMode.directOnly:
        return _buildDirectModelUrls();
      case ThreeDSpeakerDownloadSourceMode.mirrorOnly:
        return _buildMirrorModelUrls();
      case ThreeDSpeakerDownloadSourceMode.auto:
        return _buildAutoModelUrls();
    }
  }

  static Future<String> defaultModelDir() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = p.join(appDir.path, defaultRelativeDir);
    await Directory(dir).create(recursive: true);
    return dir;
  }

  static Future<String> defaultModelPath() async {
    final dir = await defaultModelDir();
    return p.join(dir, defaultFileName);
  }

  static Future<bool> isModelReady({String? modelPath}) async {
    final path = (modelPath == null || modelPath.trim().isEmpty)
        ? await defaultModelPath()
        : modelPath.trim();
    return File(path).exists();
  }

  static Future<String> downloadDefaultModel({
    required void Function(ThreeDSpeakerDownloadProgress progress) onProgress,
    void Function(String status)? onStatus,
    ThreeDSpeakerDownloadSourceMode mode = ThreeDSpeakerDownloadSourceMode.auto,
  }) async {
    final modelPath = await defaultModelPath();
    final tmpPath = '$modelPath.tmp';
    final modelUrls = _buildModelUrls(mode);

    String? lastError;

    for (final url in modelUrls) {
      final host = Uri.tryParse(url)?.host ?? url;
      try {
        onStatus?.call('connecting $host');
        await LogService.info('3D_SPEAKER', 'download start: $url');

        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 45);

        final request = await client.getUrl(Uri.parse(url));
        request.followRedirects = true;
        request.maxRedirects = 5;
        final response = await request.close().timeout(
          const Duration(seconds: 90),
        );

        if (response.statusCode != 200) {
          await response.drain<void>();
          client.close();
          throw ThreeDSpeakerModelException(
            'HTTP ${response.statusCode} from $host',
          );
        }

        final total = response.contentLength;
        var received = 0;
        final sink = File(tmpPath).openWrite();

        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          onProgress(
            ThreeDSpeakerDownloadProgress(
              downloadedBytes: received,
              totalBytes: total,
            ),
          );
        }
        await sink.flush();
        await sink.close();
        client.close();

        final file = File(modelPath);
        if (await file.exists()) {
          await file.delete();
        }
        await File(tmpPath).rename(modelPath);

        onProgress(
          ThreeDSpeakerDownloadProgress(
            downloadedBytes: received,
            totalBytes: total > 0 ? total : received,
          ),
        );
        onStatus?.call('download completed');
        await LogService.info('3D_SPEAKER', 'download completed: $modelPath');
        return modelPath;
      } catch (e) {
        lastError = e.toString();
        await LogService.error('3D_SPEAKER', 'download failed from $url: $e');
        try {
          await File(tmpPath).delete();
        } catch (_) {}
      }
    }

    throw ThreeDSpeakerModelException(
      '3D-Speaker model download failed. lastError: $lastError',
    );
  }
}

class ThreeDSpeakerDownloadProgress {
  final int downloadedBytes;
  final int totalBytes;

  const ThreeDSpeakerDownloadProgress({
    required this.downloadedBytes,
    required this.totalBytes,
  });

  double get progress {
    if (totalBytes <= 0) return 0.0;
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }
}

class ThreeDSpeakerModelException implements Exception {
  final String message;
  ThreeDSpeakerModelException(this.message);

  @override
  String toString() => message;
}
