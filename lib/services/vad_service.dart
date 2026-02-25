import 'dart:async';

/// Voice Activity Detection service.
///
/// Monitors an amplitude stream and fires [onSilenceDetected] when the
/// amplitude stays below [silenceThreshold] for [silenceDuration].
class VadService {
  /// Amplitude level below which audio is considered silence (0.0–1.0).
  final double silenceThreshold;

  /// How long the amplitude must stay below [silenceThreshold] before
  /// silence is declared.
  final Duration silenceDuration;

  /// Minimum recording duration before VAD is allowed to trigger.
  final Duration minRecordingDuration;

  StreamSubscription<double>? _sub;
  DateTime? _silenceStart;
  DateTime? _recordingStart;
  bool _triggered = false;

  final _silenceController = StreamController<void>.broadcast();

  /// Emits an event when silence is detected after [minRecordingDuration].
  Stream<void> get onSilenceDetected => _silenceController.stream;

  VadService({
    this.silenceThreshold = 0.05,
    this.silenceDuration = const Duration(seconds: 3),
    this.minRecordingDuration = const Duration(seconds: 3),
  });

  /// Start monitoring the given amplitude stream.
  void start(Stream<double> amplitudeStream) {
    stop();
    _triggered = false;
    _silenceStart = null;
    _recordingStart = DateTime.now();

    _sub = amplitudeStream.listen(_onAmplitude);
  }

  void _onAmplitude(double level) {
    if (_triggered) return;

    final now = DateTime.now();

    // Don't trigger before minimum recording duration
    if (_recordingStart != null &&
        now.difference(_recordingStart!) < minRecordingDuration) {
      _silenceStart = null;
      return;
    }

    if (level < silenceThreshold) {
      // Amplitude is below threshold — start or continue silence timer
      _silenceStart ??= now;

      if (now.difference(_silenceStart!) >= silenceDuration) {
        _triggered = true;
        _silenceController.add(null);
      }
    } else {
      // Sound detected — reset silence timer
      _silenceStart = null;
    }
  }

  /// Stop monitoring.
  void stop() {
    _sub?.cancel();
    _sub = null;
    _silenceStart = null;
  }

  /// Release resources.
  void dispose() {
    stop();
    _silenceController.close();
  }
}
