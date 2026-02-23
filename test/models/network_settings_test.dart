import 'package:flutter_test/flutter_test.dart';
import 'package:voicetype/models/network_settings.dart';

void main() {
  group('NetworkProxyMode', () {
    test('storageValue returns correct strings', () {
      expect(NetworkProxyMode.system.storageValue, 'system');
      expect(NetworkProxyMode.none.storageValue, 'none');
    });

    test('fromStorage parses system', () {
      expect(NetworkProxyModeX.fromStorage('system'), NetworkProxyMode.system);
    });

    test('fromStorage parses none', () {
      expect(NetworkProxyModeX.fromStorage('none'), NetworkProxyMode.none);
    });

    test('fromStorage defaults to none for null', () {
      expect(NetworkProxyModeX.fromStorage(null), NetworkProxyMode.none);
    });

    test('fromStorage defaults to none for unknown value', () {
      expect(NetworkProxyModeX.fromStorage('invalid'), NetworkProxyMode.none);
      expect(NetworkProxyModeX.fromStorage(''), NetworkProxyMode.none);
    });

    test('round-trip: storageValue -> fromStorage', () {
      for (final mode in NetworkProxyMode.values) {
        final restored = NetworkProxyModeX.fromStorage(mode.storageValue);
        expect(restored, mode, reason: 'Failed for $mode');
      }
    });
  });
}
