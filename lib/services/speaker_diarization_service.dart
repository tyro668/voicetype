import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'log_service.dart';

class SpeakerDiarizationResult {
  final String speakerId;
  final double confidence;

  const SpeakerDiarizationResult({
    required this.speakerId,
    required this.confidence,
  });
}

class SpeakerDiarizationService {
  final int maxSpeakers;
  final double onlineBaseThreshold;
  final double minDynamicThreshold;
  final double maxDynamicThreshold;
  final double top1Top2Margin;
  final double offlineMergeThreshold;
  final int offlineMinClusterSize;
  final bool preferThreeDSpeaker;
  final String? threeDSpeakerModelPath;

  final Map<String, _SpeakerPrototype> _prototypes = {};
  final Map<String, _SamplePoint> _samples = {};
  final List<String> _sampleOrder = [];

  sherpa.SpeakerEmbeddingExtractor? _extractor;
  String? _resolvedModelPath;
  String? _asciiModelLinkPath;
  bool _extractorUnavailableLogged = false;
  bool _fallbackLogged = false;
  static bool _bindingsInitialized = false;

  SpeakerDiarizationService({
    this.maxSpeakers = 6,
    this.onlineBaseThreshold = 0.78,
    this.minDynamicThreshold = 0.74,
    this.maxDynamicThreshold = 0.86,
    this.top1Top2Margin = 0.04,
    this.offlineMergeThreshold = 0.80,
    this.offlineMinClusterSize = 1,
    this.preferThreeDSpeaker = true,
    this.threeDSpeakerModelPath,
  });

  void reset() {
    _prototypes.clear();
    _samples.clear();
    _sampleOrder.clear();
  }

  Future<void> dispose() async {
    _extractor?.free();
    _extractor = null;

    final linkPath = _asciiModelLinkPath;
    _asciiModelLinkPath = null;
    if (linkPath != null) {
      try {
        final link = Link(linkPath);
        if (await link.exists()) {
          await link.delete();
        }
      } catch (_) {}
    }
  }

  Future<SpeakerDiarizationResult?> assignSpeaker({
    required String audioPath,
    String? segmentKey,
  }) async {
    final wav = await _readWavMono(audioPath);
    final samples = wav.$1;
    final sampleRate = wav.$2;

    if (samples.isEmpty) return null;

    final embedding = await _extractEmbedding(samples, sampleRate);
    if (embedding.isEmpty) return null;

    final result = _assignEmbedding(embedding);

    if (segmentKey != null && segmentKey.trim().isNotEmpty) {
      _samples[segmentKey] = _SamplePoint(
        segmentKey: segmentKey,
        embedding: embedding,
        speakerId: result.speakerId,
        confidence: result.confidence,
      );
      if (!_sampleOrder.contains(segmentKey)) {
        _sampleOrder.add(segmentKey);
      }
    }

    return result;
  }

  Map<String, SpeakerDiarizationResult> refineOfflineAssignments() {
    if (_sampleOrder.isEmpty) return const {};

    final points = <_SamplePoint>[];
    for (final key in _sampleOrder) {
      final point = _samples[key];
      if (point != null) points.add(point);
    }
    if (points.isEmpty) return const {};

    final clusters = <_OfflineCluster>[
      for (var i = 0; i < points.length; i++)
        _OfflineCluster(
          memberIndexes: {i},
          centroid: List<double>.from(points[i].embedding),
        ),
    ];

    while (clusters.length > 1) {
      var bestI = -1;
      var bestJ = -1;
      var bestSim = -1.0;

      for (var i = 0; i < clusters.length; i++) {
        for (var j = i + 1; j < clusters.length; j++) {
          final sim = _cosineSimilarity(
            clusters[i].centroid,
            clusters[j].centroid,
          );
          if (sim > bestSim) {
            bestSim = sim;
            bestI = i;
            bestJ = j;
          }
        }
      }

      if (bestI < 0 || bestJ < 0) break;
      final shouldMerge =
          bestSim >= offlineMergeThreshold || clusters.length > maxSpeakers;
      if (!shouldMerge) break;

      final a = clusters[bestI];
      final b = clusters[bestJ];
      final mergedMembers = <int>{...a.memberIndexes, ...b.memberIndexes};
      final mergedCentroid = _meanCentroid(points, mergedMembers);

      final next = <_OfflineCluster>[];
      for (var idx = 0; idx < clusters.length; idx++) {
        if (idx == bestI || idx == bestJ) continue;
        next.add(clusters[idx]);
      }
      next.add(
        _OfflineCluster(memberIndexes: mergedMembers, centroid: mergedCentroid),
      );
      clusters
        ..clear()
        ..addAll(next);
    }

    clusters.removeWhere((c) => c.memberIndexes.length < offlineMinClusterSize);

    if (clusters.isEmpty) return const {};

    clusters.sort((a, b) {
      final aFirst = a.memberIndexes.reduce(math.min);
      final bFirst = b.memberIndexes.reduce(math.min);
      return aFirst.compareTo(bFirst);
    });

    final mapping = <String, SpeakerDiarizationResult>{};

    for (var cIdx = 0; cIdx < clusters.length; cIdx++) {
      final speakerId = 'Speaker${cIdx + 1}';
      final cluster = clusters[cIdx];
      for (final pointIdx in cluster.memberIndexes) {
        final point = points[pointIdx];
        final sim = _cosineSimilarity(point.embedding, cluster.centroid);
        mapping[point.segmentKey] = SpeakerDiarizationResult(
          speakerId: speakerId,
          confidence: _normalizeConfidence(sim),
        );
      }
    }

    for (final entry in mapping.entries) {
      final point = _samples[entry.key];
      if (point == null) continue;
      _samples[entry.key] = point.copyWith(
        speakerId: entry.value.speakerId,
        confidence: entry.value.confidence,
      );
    }

    return mapping;
  }

  SpeakerDiarizationResult _assignEmbedding(List<double> embedding) {
    if (_prototypes.isEmpty) {
      const id = 'Speaker1';
      _prototypes[id] = _SpeakerPrototype(
        vector: embedding,
        count: 1,
        intraSimEma: 0.86,
      );
      return const SpeakerDiarizationResult(speakerId: id, confidence: 1.0);
    }

    final candidates = <_Candidate>[];

    for (final entry in _prototypes.entries) {
      final sim = _cosineSimilarity(embedding, entry.value.vector);
      candidates.add(_Candidate(id: entry.key, similarity: sim));
    }

    candidates.sort((a, b) => b.similarity.compareTo(a.similarity));

    final top1 = candidates.first;
    final top2Sim = candidates.length > 1 ? candidates[1].similarity : -1.0;
    final proto = _prototypes[top1.id]!;
    final dynamicThreshold = _computeDynamicThreshold(proto);
    final margin = top1.similarity - top2Sim;

    final accept =
        top1.similarity >= dynamicThreshold &&
        (margin >= top1Top2Margin ||
            top1.similarity >= dynamicThreshold + 0.03);

    if (!accept && _prototypes.length < maxSpeakers) {
      final id = 'Speaker${_prototypes.length + 1}';
      _prototypes[id] = _SpeakerPrototype(
        vector: embedding,
        count: 1,
        intraSimEma: top1.similarity.clamp(0.5, 0.9).toDouble(),
      );
      return SpeakerDiarizationResult(
        speakerId: id,
        confidence: _normalizeConfidence(top1.similarity),
      );
    }

    final merged = _mergeCentroid(proto.vector, embedding, proto.count);
    final nextEma = _updateEma(proto.intraSimEma, top1.similarity);
    _prototypes[top1.id] = _SpeakerPrototype(
      vector: merged,
      count: proto.count + 1,
      intraSimEma: nextEma,
    );

    return SpeakerDiarizationResult(
      speakerId: top1.id,
      confidence: _normalizeConfidence(top1.similarity),
    );
  }

  double _computeDynamicThreshold(_SpeakerPrototype proto) {
    final adjusted = onlineBaseThreshold + (proto.intraSimEma - 0.80) * 0.35;
    final warmupBoost = proto.count < 3 ? 0.02 : 0.0;
    return (adjusted + warmupBoost)
        .clamp(minDynamicThreshold, maxDynamicThreshold)
        .toDouble();
  }

  static double _updateEma(double previous, double current) {
    const alpha = 0.2;
    return previous * (1 - alpha) + current * alpha;
  }

  static List<double> _meanCentroid(
    List<_SamplePoint> points,
    Set<int> memberIndexes,
  ) {
    final first = points[memberIndexes.first].embedding;
    final sum = List<double>.filled(first.length, 0.0);

    for (final idx in memberIndexes) {
      final emb = points[idx].embedding;
      for (var i = 0; i < sum.length; i++) {
        sum[i] += emb[i];
      }
    }
    final inv = 1.0 / math.max(1, memberIndexes.length);
    for (var i = 0; i < sum.length; i++) {
      sum[i] *= inv;
    }
    return _normalizeVector(sum);
  }

  static double _normalizeConfidence(double similarity) {
    final score = ((similarity + 1.0) / 2.0).clamp(0.0, 1.0);
    return score.toDouble();
  }

  static List<double> _mergeCentroid(
    List<double> centroid,
    List<double> vector,
    int count,
  ) {
    final merged = List<double>.filled(centroid.length, 0);
    for (var i = 0; i < centroid.length; i++) {
      merged[i] = (centroid[i] * count + vector[i]) / (count + 1);
    }
    return _normalizeVector(merged);
  }

  Future<List<double>> _extractEmbedding(
    Float32List samples,
    int sampleRate,
  ) async {
    if (preferThreeDSpeaker) {
      final modelEmbedding = await _extractEmbeddingWithThreeDSpeaker(
        samples,
        sampleRate,
      );
      if (modelEmbedding.isNotEmpty) return modelEmbedding;
    }

    if (!_fallbackLogged) {
      _fallbackLogged = true;
      unawaited(
        LogService.warn(
          'SPEAKER',
          '3D-Speaker unavailable, fallback to heuristic embedding',
        ),
      );
    }

    return _extractHeuristicEmbedding(samples, sampleRate);
  }

  Future<List<double>> _extractEmbeddingWithThreeDSpeaker(
    Float32List samples,
    int sampleRate,
  ) async {
    final extractor = await _ensureExtractor();
    if (extractor == null) return const [];

    final voiced = _trimSilence(samples, threshold: 0.008);
    if (voiced.length < math.max(1600, sampleRate ~/ 8)) return const [];

    const targetRate = 16000;
    final normalizedSamples = sampleRate == targetRate
        ? voiced
        : _resample(voiced, sampleRate, targetRate);
    if (normalizedSamples.length < 1600) return const [];

    final stream = extractor.createStream();
    try {
      stream.acceptWaveform(samples: normalizedSamples, sampleRate: targetRate);
      stream.inputFinished();

      if (!extractor.isReady(stream)) return const [];

      final emb = extractor.compute(stream);
      if (emb.isEmpty) return const [];

      return _normalizeVector(emb.map((e) => e.toDouble()).toList());
    } catch (_) {
      return const [];
    } finally {
      stream.free();
    }
  }

  Future<sherpa.SpeakerEmbeddingExtractor?> _ensureExtractor() async {
    if (_extractor != null) return _extractor;

    try {
      if (!_bindingsInitialized) {
        sherpa.initBindings();
        _bindingsInitialized = true;
      }

      final modelFile = await _resolveThreeDSpeakerModelFile();
      if (modelFile == null || modelFile.trim().isEmpty) {
        if (!_extractorUnavailableLogged) {
          _extractorUnavailableLogged = true;
          await LogService.warn(
            'SPEAKER',
            '3D-Speaker model not found, checked default locations',
          );
        }
        return null;
      }

      final safeModelFile = await _ensureAsciiFilePath(modelFile);
      final threads = math.max(1, Platform.numberOfProcessors ~/ 2);

      _extractor = sherpa.SpeakerEmbeddingExtractor(
        config: sherpa.SpeakerEmbeddingExtractorConfig(
          model: safeModelFile,
          numThreads: threads,
          debug: false,
          provider: 'cpu',
        ),
      );
      _resolvedModelPath = modelFile;
      await LogService.info('SPEAKER', '3D-Speaker loaded: $modelFile');
      return _extractor;
    } catch (e) {
      if (!_extractorUnavailableLogged) {
        _extractorUnavailableLogged = true;
        await LogService.error('SPEAKER', 'load 3D-Speaker failed: $e');
      }
      _extractor = null;
      return null;
    }
  }

  Future<String?> _resolveThreeDSpeakerModelFile() async {
    if (_resolvedModelPath != null &&
        await File(_resolvedModelPath!).exists()) {
      return _resolvedModelPath;
    }

    final custom = (threeDSpeakerModelPath ?? '').trim();
    final candidates = <String>[];
    if (custom.isNotEmpty) {
      if (p.isAbsolute(custom)) {
        candidates.add(custom);
        candidates.add(p.join(custom, 'model.onnx'));
        candidates.add(p.join(custom, '3d_speaker.onnx'));
      } else {
        final appDir = await getApplicationSupportDirectory();
        candidates.add(p.join(appDir.path, 'models', custom));
        candidates.add(p.join(appDir.path, 'models', custom, 'model.onnx'));
      }
    }

    final appDir = await getApplicationSupportDirectory();
    candidates.addAll([
      p.join(appDir.path, 'models', '3d-speaker', 'model.onnx'),
      p.join(appDir.path, 'models', '3d_speaker', 'model.onnx'),
      p.join(appDir.path, 'models', '3d-speaker.onnx'),
      p.join(appDir.path, 'models', 'speaker-embedding', 'model.onnx'),
    ]);

    for (final candidate in candidates) {
      if (await File(candidate).exists()) return candidate;
    }
    return null;
  }

  Future<String> _ensureAsciiFilePath(String modelFile) async {
    final isAscii = modelFile.codeUnits.every((c) => c >= 0x20 && c <= 0x7E);
    if (isAscii) return modelFile;

    final modelDir = p.dirname(modelFile);
    final fileName = p.basename(modelFile);
    final safeLink = p.join(
      Directory.systemTemp.path,
      'sherpa_3d_speaker_${DateTime.now().millisecondsSinceEpoch}',
    );

    final oldLink = _asciiModelLinkPath;
    if (oldLink != null && oldLink != safeLink) {
      try {
        final l = Link(oldLink);
        if (await l.exists()) await l.delete();
      } catch (_) {}
    }

    final link = Link(safeLink);
    if (await link.exists()) {
      await link.delete();
    }
    await link.create(modelDir);
    _asciiModelLinkPath = safeLink;
    return p.join(safeLink, fileName);
  }

  static List<double> _extractHeuristicEmbedding(
    Float32List samples,
    int sampleRate,
  ) {
    if (samples.isEmpty) return const [];

    final voiced = _trimSilence(samples, threshold: 0.01);
    if (voiced.length < math.max(1600, sampleRate ~/ 10)) return const [];

    final maxSamples = sampleRate * 6;
    final useSamples = voiced.length > maxSamples
        ? voiced.sublist(0, maxSamples)
        : voiced;

    final rms = _rms(useSamples);
    final zcr = _zcr(useSamples);
    final pitch = _estimatePitch(useSamples, sampleRate);

    final spectrumSignature = _extractSpectrumSignature(useSamples, sampleRate);
    final envelopeSignature = _extractEnvelopeSignature(useSamples);

    final vec = <double>[
      rms,
      zcr,
      pitch,
      ...spectrumSignature,
      ...envelopeSignature,
    ];
    return _normalizeVector(vec);
  }

  static Float32List _resample(Float32List input, int srcRate, int dstRate) {
    if (srcRate == dstRate) return input;
    final ratio = srcRate / dstRate;
    final outputLength = (input.length / ratio).floor();
    final output = Float32List(outputLength);
    for (var i = 0; i < outputLength; i++) {
      final srcPos = i * ratio;
      final srcIndex = srcPos.floor();
      final frac = srcPos - srcIndex;
      if (srcIndex + 1 < input.length) {
        output[i] = input[srcIndex] * (1 - frac) + input[srcIndex + 1] * frac;
      } else if (srcIndex < input.length) {
        output[i] = input[srcIndex];
      }
    }
    return output;
  }

  static Float32List _trimSilence(
    Float32List samples, {
    required double threshold,
  }) {
    var start = 0;
    while (start < samples.length && samples[start].abs() < threshold) {
      start++;
    }
    var end = samples.length - 1;
    while (end > start && samples[end].abs() < threshold) {
      end--;
    }
    if (end <= start) return Float32List(0);
    return Float32List.fromList(samples.sublist(start, end + 1));
  }

  static double _rms(Float32List samples) {
    var sumSq = 0.0;
    for (final s in samples) {
      sumSq += s * s;
    }
    return math.sqrt(sumSq / math.max(1, samples.length));
  }

  static double _zcr(Float32List samples) {
    if (samples.length < 2) return 0.0;
    var crossings = 0;
    var prev = samples.first;
    for (var i = 1; i < samples.length; i++) {
      final cur = samples[i];
      if ((cur >= 0 && prev < 0) || (cur < 0 && prev >= 0)) crossings++;
      prev = cur;
    }
    return crossings / samples.length;
  }

  static List<double> _extractEnvelopeSignature(Float32List samples) {
    const chunks = 6;
    final out = <double>[];
    final chunkSize = math.max(1, samples.length ~/ chunks);
    for (var c = 0; c < chunks; c++) {
      final start = c * chunkSize;
      if (start >= samples.length) {
        out.add(0.0);
        continue;
      }
      final end = math.min(samples.length, start + chunkSize);
      var sumAbs = 0.0;
      for (var i = start; i < end; i++) {
        sumAbs += samples[i].abs();
      }
      out.add(sumAbs / math.max(1, end - start));
    }
    return out;
  }

  static List<double> _extractSpectrumSignature(
    Float32List samples,
    int sampleRate,
  ) {
    // 以多个目标频点的 Goertzel 能量作为简易声纹特征。
    const freqs = [
      120.0,
      180.0,
      260.0,
      380.0,
      560.0,
      800.0,
      1150.0,
      1600.0,
      2200.0,
      3000.0,
    ];

    final frameSize = math.min(samples.length, 4096);
    if (frameSize < 256) return List<double>.filled(freqs.length, 0.0);

    final step = math.max(256, frameSize ~/ 2);
    final sums = List<double>.filled(freqs.length, 0.0);
    var frames = 0;

    for (var start = 0; start + frameSize <= samples.length; start += step) {
      final frame = samples.sublist(start, start + frameSize);
      for (var i = 0; i < freqs.length; i++) {
        sums[i] += _goertzelPower(frame, sampleRate, freqs[i]);
      }
      frames++;
      if (frames >= 6) break;
    }

    if (frames == 0) return List<double>.filled(freqs.length, 0.0);
    return sums.map((v) => v / frames).toList();
  }

  static double _goertzelPower(Float32List x, int sampleRate, double freq) {
    final n = x.length;
    final k = (0.5 + (n * freq) / sampleRate).floor();
    final omega = (2.0 * math.pi * k) / n;
    final coeff = 2.0 * math.cos(omega);

    var s0 = 0.0;
    var s1 = 0.0;
    var s2 = 0.0;

    for (var i = 0; i < n; i++) {
      s0 = x[i] + coeff * s1 - s2;
      s2 = s1;
      s1 = s0;
    }

    final power = s1 * s1 + s2 * s2 - coeff * s1 * s2;
    return math.log(1.0 + power.abs());
  }

  static double _estimatePitch(Float32List samples, int sampleRate) {
    if (samples.length < 2048) return 0.0;

    final window = math.min(samples.length, 4096);
    final lagMin = (sampleRate / 400).floor();
    final lagMax = (sampleRate / 60).floor();
    if (lagMax <= lagMin || lagMax >= window) return 0.0;

    var bestLag = lagMin;
    var bestCorr = -1.0;

    for (var lag = lagMin; lag <= lagMax; lag++) {
      var corr = 0.0;
      for (var i = 0; i < window - lag; i++) {
        corr += samples[i] * samples[i + lag];
      }
      if (corr > bestCorr) {
        bestCorr = corr;
        bestLag = lag;
      }
    }

    if (bestLag <= 0) return 0.0;
    final hz = sampleRate / bestLag;
    return (hz / 500).clamp(0.0, 1.0).toDouble();
  }

  static List<double> _normalizeVector(List<double> vector) {
    var sumSq = 0.0;
    for (final v in vector) {
      sumSq += v * v;
    }
    final norm = math.sqrt(sumSq);
    if (norm <= 1e-8) return vector.map((_) => 0.0).toList();
    return vector.map((v) => v / norm).toList();
  }

  static double _cosineSimilarity(List<double> a, List<double> b) {
    var dot = 0.0;
    final n = math.min(a.length, b.length);
    for (var i = 0; i < n; i++) {
      dot += a[i] * b[i];
    }
    return dot.clamp(-1.0, 1.0).toDouble();
  }

  static Future<(Float32List, int)> _readWavMono(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    if (bytes.length < 44) return (Float32List(0), 16000);

    final data = ByteData.sublistView(bytes);
    if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
      return (Float32List(0), 16000);
    }

    int offset = 12;
    int? sampleRate;
    int? numChannels;
    int? bitsPerSample;
    int? audioFormat;
    Float32List? samples;

    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = data.getUint32(offset + 4, Endian.little);
      offset += 8;

      if (chunkId == 'fmt ') {
        if (chunkSize < 16) break;
        audioFormat = data.getUint16(offset, Endian.little);
        numChannels = data.getUint16(offset + 2, Endian.little);
        sampleRate = data.getUint32(offset + 4, Endian.little);
        bitsPerSample = data.getUint16(offset + 14, Endian.little);
        if (audioFormat == 0xFFFE && chunkSize >= 40) {
          final subFormat = data.getUint16(offset + 24, Endian.little);
          audioFormat = subFormat;
          final validBits = data.getUint16(offset + 18, Endian.little);
          if (validBits > 0 && validBits <= 32) bitsPerSample = validBits;
        }
      } else if (chunkId == 'data') {
        if (audioFormat == null ||
            sampleRate == null ||
            numChannels == null ||
            bitsPerSample == null) {
          break;
        }
        final bytesPerSample = bitsPerSample ~/ 8;
        final frameSize = bytesPerSample * numChannels;
        final totalFrames = chunkSize ~/ frameSize;
        samples = Float32List(totalFrames);
        var readOffset = offset;

        for (var i = 0; i < totalFrames; i++) {
          if (readOffset + bytesPerSample > bytes.length) break;
          if (audioFormat == 3 && bitsPerSample == 32) {
            samples[i] = data.getFloat32(readOffset, Endian.little);
          } else if (bitsPerSample == 16) {
            samples[i] = data.getInt16(readOffset, Endian.little) / 32768.0;
          } else if (bitsPerSample == 32) {
            samples[i] =
                data.getInt32(readOffset, Endian.little) / 2147483648.0;
          } else if (bitsPerSample == 8) {
            samples[i] = (bytes[readOffset] - 128) / 128.0;
          }
          readOffset += frameSize;
        }
        break;
      }

      offset += chunkSize;
      if (chunkSize.isOdd) offset++;
    }

    return (samples ?? Float32List(0), sampleRate ?? 16000);
  }
}

class _SpeakerPrototype {
  final List<double> vector;
  final int count;
  final double intraSimEma;

  const _SpeakerPrototype({
    required this.vector,
    required this.count,
    required this.intraSimEma,
  });
}

class _Candidate {
  final String id;
  final double similarity;

  const _Candidate({required this.id, required this.similarity});
}

class _SamplePoint {
  final String segmentKey;
  final List<double> embedding;
  final String speakerId;
  final double confidence;

  const _SamplePoint({
    required this.segmentKey,
    required this.embedding,
    required this.speakerId,
    required this.confidence,
  });

  _SamplePoint copyWith({String? speakerId, double? confidence}) {
    return _SamplePoint(
      segmentKey: segmentKey,
      embedding: embedding,
      speakerId: speakerId ?? this.speakerId,
      confidence: confidence ?? this.confidence,
    );
  }
}

class _OfflineCluster {
  final Set<int> memberIndexes;
  final List<double> centroid;

  const _OfflineCluster({required this.memberIndexes, required this.centroid});
}
