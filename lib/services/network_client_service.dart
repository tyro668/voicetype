import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/network_settings.dart';

class NetworkClientService {
  static NetworkProxyMode _proxyMode = NetworkProxyMode.none;

  static void setProxyMode(NetworkProxyMode mode) {
    _proxyMode = mode;
  }

  static http.Client createClient() {
    final ioHttpClient = HttpClient();
    if (_proxyMode == NetworkProxyMode.none) {
      ioHttpClient.findProxy = (_) => 'DIRECT';
    }
    return IOClient(ioHttpClient);
  }
}
