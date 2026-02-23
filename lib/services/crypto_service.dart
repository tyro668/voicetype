import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:shared_preferences/shared_preferences.dart';

/// 对称加密服务，用于加密存储 API 密钥等敏感信息。
/// 使用 AES-CBC-256 算法，每次加密生成随机 IV。
class CryptoService {
  static const _keyPrefKey = '_enc_master_key';
  static const _encPrefix = 'ENC:';

  static CryptoService? _instance;

  late final encrypt.Key _key;
  late final encrypt.Encrypter _encrypter;

  CryptoService._();

  /// 初始化加密服务。首次调用时会从 SharedPreferences 加载或生成主密钥。
  static Future<CryptoService> initialize() async {
    if (_instance != null) return _instance!;

    final service = CryptoService._();
    final prefs = await SharedPreferences.getInstance();

    final storedKey = prefs.getString(_keyPrefKey);
    if (storedKey == null) {
      // 首次运行，生成随机 256 位主密钥
      service._key = encrypt.Key.fromSecureRandom(32);
      await prefs.setString(_keyPrefKey, service._key.base64);
    } else {
      service._key = encrypt.Key.fromBase64(storedKey);
    }

    service._encrypter = encrypt.Encrypter(
      encrypt.AES(service._key, mode: encrypt.AESMode.cbc),
    );

    _instance = service;
    return service;
  }

  /// 获取已初始化的单例实例。
  static CryptoService get instance {
    if (_instance == null) {
      throw StateError(
        'CryptoService not initialized. Call initialize() first.',
      );
    }
    return _instance!;
  }

  /// 加密明文字符串。返回 "ENC:<base64_iv>:<base64_ciphertext>" 格式。
  /// 空字符串不加密，原样返回。
  String encryptText(String plainText) {
    if (plainText.isEmpty) return '';
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypted = _encrypter.encrypt(plainText, iv: iv);
    return '$_encPrefix${iv.base64}:${encrypted.base64}';
  }

  /// 解密由 [encryptText] 加密的字符串。
  /// 如果输入不是加密格式（无 ENC: 前缀），则视为明文原样返回，
  /// 以兼容升级前存储的未加密数据。
  String decryptText(String encryptedText) {
    if (encryptedText.isEmpty) return '';
    if (!encryptedText.startsWith(_encPrefix)) {
      // 未加密的明文（向后兼容）
      return encryptedText;
    }
    try {
      final data = encryptedText.substring(_encPrefix.length);
      final separatorIndex = data.indexOf(':');
      if (separatorIndex == -1) return encryptedText;

      final ivBase64 = data.substring(0, separatorIndex);
      final cipherBase64 = data.substring(separatorIndex + 1);

      final iv = encrypt.IV.fromBase64(ivBase64);
      final encrypted = encrypt.Encrypted.fromBase64(cipherBase64);
      return _encrypter.decrypt(encrypted, iv: iv);
    } catch (_) {
      // 解密失败，返回原始值（向后兼容）
      return encryptedText;
    }
  }
}
