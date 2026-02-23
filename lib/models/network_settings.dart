enum NetworkProxyMode { system, none }

extension NetworkProxyModeX on NetworkProxyMode {
  String get storageValue {
    return switch (this) {
      NetworkProxyMode.system => 'system',
      NetworkProxyMode.none => 'none',
    };
  }

  static NetworkProxyMode fromStorage(String? value) {
    return switch (value) {
      'system' => NetworkProxyMode.system,
      'none' => NetworkProxyMode.none,
      _ => NetworkProxyMode.none,
    };
  }
}
