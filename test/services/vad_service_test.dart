import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicetype/services/vad_service.dart';

void main() {
  group('VadService - smart segment parameters', () {
    late VadService vad;
    late StreamController<double> amplitudeController;

    setUp(() {
      amplitudeController = StreamController<double>.broadcast();
    });

    tearDown(() {
      vad.dispose();
      amplitudeController.close();
    });

    test('should NOT trigger silence before softMinSeconds (20s)', () async {
      vad = VadService(
        silenceThreshold: 0.05,
        silenceDuration: const Duration(milliseconds: 500),
        minRecordingDuration: const Duration(seconds: 20),
      );

      var triggered = false;
      vad.onSilenceDetected.listen((_) => triggered = true);

      vad.start(amplitudeController.stream);

      // Simulate silence immediately (before 20s) — should not trigger
      for (var i = 0; i < 20; i++) {
        amplitudeController.add(0.01); // below threshold
        await Future.delayed(const Duration(milliseconds: 50));
      }

      expect(triggered, isFalse);
    });

    test(
      'should trigger silence after minRecordingDuration with sustained silence',
      () async {
        // Use a very short minRecordingDuration for testing
        vad = VadService(
          silenceThreshold: 0.05,
          silenceDuration: const Duration(milliseconds: 100),
          minRecordingDuration: const Duration(milliseconds: 50),
        );

        var triggered = false;
        vad.onSilenceDetected.listen((_) => triggered = true);

        vad.start(amplitudeController.stream);

        // Wait past minRecordingDuration
        await Future.delayed(const Duration(milliseconds: 80));

        // Now send silence for longer than silenceDuration
        for (var i = 0; i < 10; i++) {
          amplitudeController.add(0.01);
          await Future.delayed(const Duration(milliseconds: 20));
        }

        expect(triggered, isTrue);
      },
    );

    test(
      'should NOT trigger if amplitude goes above threshold during silence window',
      () async {
        vad = VadService(
          silenceThreshold: 0.05,
          silenceDuration: const Duration(milliseconds: 200),
          minRecordingDuration: const Duration(milliseconds: 50),
        );

        var triggered = false;
        vad.onSilenceDetected.listen((_) => triggered = true);

        vad.start(amplitudeController.stream);

        // Wait past minRecordingDuration
        await Future.delayed(const Duration(milliseconds: 80));

        // Send silence for a bit
        amplitudeController.add(0.01);
        await Future.delayed(const Duration(milliseconds: 80));

        // Then sound — resets silence timer
        amplitudeController.add(0.5);
        await Future.delayed(const Duration(milliseconds: 20));

        // Short silence again — not long enough
        amplitudeController.add(0.01);
        await Future.delayed(const Duration(milliseconds: 80));

        expect(triggered, isFalse);
      },
    );

    test('should only trigger once even if silence continues', () async {
      vad = VadService(
        silenceThreshold: 0.05,
        silenceDuration: const Duration(milliseconds: 100),
        minRecordingDuration: const Duration(milliseconds: 50),
      );

      var triggerCount = 0;
      vad.onSilenceDetected.listen((_) => triggerCount++);

      vad.start(amplitudeController.stream);

      // Wait past minRecordingDuration
      await Future.delayed(const Duration(milliseconds: 80));

      // Send sustained silence
      for (var i = 0; i < 20; i++) {
        amplitudeController.add(0.01);
        await Future.delayed(const Duration(milliseconds: 20));
      }

      expect(triggerCount, equals(1));
    });

    test('stop() prevents further triggers', () async {
      vad = VadService(
        silenceThreshold: 0.05,
        silenceDuration: const Duration(milliseconds: 100),
        minRecordingDuration: const Duration(milliseconds: 50),
      );

      var triggered = false;
      vad.onSilenceDetected.listen((_) => triggered = true);

      vad.start(amplitudeController.stream);

      // Wait past minRecordingDuration
      await Future.delayed(const Duration(milliseconds: 80));

      // Stop before silence can accumulate
      vad.stop();

      // Send silence
      for (var i = 0; i < 10; i++) {
        amplitudeController.add(0.01);
        await Future.delayed(const Duration(milliseconds: 20));
      }

      expect(triggered, isFalse);
    });

    test('can restart after stop and trigger again', () async {
      vad = VadService(
        silenceThreshold: 0.05,
        silenceDuration: const Duration(milliseconds: 100),
        minRecordingDuration: const Duration(milliseconds: 50),
      );

      var triggerCount = 0;
      vad.onSilenceDetected.listen((_) => triggerCount++);

      // First session
      vad.start(amplitudeController.stream);
      await Future.delayed(const Duration(milliseconds: 80));

      for (var i = 0; i < 10; i++) {
        amplitudeController.add(0.01);
        await Future.delayed(const Duration(milliseconds: 20));
      }
      expect(triggerCount, equals(1));

      // Stop and restart
      vad.stop();
      vad.start(amplitudeController.stream);
      await Future.delayed(const Duration(milliseconds: 80));

      for (var i = 0; i < 10; i++) {
        amplitudeController.add(0.01);
        await Future.delayed(const Duration(milliseconds: 20));
      }
      expect(triggerCount, equals(2));
    });
  });
}
