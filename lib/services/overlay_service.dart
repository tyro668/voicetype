import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 与原生 macOS overlay 窗口通信的服务
class OverlayService {
  static const _channel = MethodChannel('com.voicetype/overlay');

  /// 全局快捷键回调
  static Function(int keyCode, String type, bool isRepeat)? onGlobalKeyEvent;

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onGlobalKeyEvent') {
        final args = call.arguments as Map;
        final keyCode = args['keyCode'] as int;
        final type = args['type'] as String;
        final isRepeat = args['isRepeat'] as bool;
        debugPrint('[hotkey] keyCode=$keyCode type=$type repeat=$isRepeat');
        onGlobalKeyEvent?.call(keyCode, type, isRepeat);
      }
    });
  }

  static Future<void> showOverlay({
    required String state,
    String duration = '00:00',
    double? level,
  }) async {
    final args = <String, Object>{'state': state, 'duration': duration};
    if (level != null) {
      args['level'] = level;
    }
    await _channel.invokeMethod('showOverlay', args);
  }

  static Future<void> hideOverlay() async {
    await _channel.invokeMethod('hideOverlay');
  }

  static Future<void> updateOverlay({
    required String state,
    String duration = '00:00',
    double? level,
  }) async {
    final args = <String, Object>{'state': state, 'duration': duration};
    if (level != null) {
      args['level'] = level;
    }
    await _channel.invokeMethod('updateOverlay', args);
  }

  static Future<void> showMainWindow() async {
    await _channel.invokeMethod('showMainWindow');
  }

  static Future<void> insertText(String text) async {
    await _channel.invokeMethod('insertText', {'text': text});
  }

  /// 检查辅助功能权限
  static Future<bool> checkAccessibility() async {
    final result = await _channel.invokeMethod<bool>('checkAccessibility');
    return result ?? false;
  }

  /// 请求辅助功能权限（弹出系统提示）
  static Future<bool> requestAccessibility() async {
    final result = await _channel.invokeMethod<bool>('requestAccessibility');
    return result ?? false;
  }

  /// 打开系统声音输入设置
  static Future<void> openSoundInput() async {
    await _channel.invokeMethod('openSoundInput');
  }

  /// 打开麦克风隐私设置
  static Future<void> openMicrophonePrivacy() async {
    await _channel.invokeMethod('openMicrophonePrivacy');
  }

  /// 打开辅助功能隐私设置
  static Future<void> openAccessibilityPrivacy() async {
    await _channel.invokeMethod('openAccessibilityPrivacy');
  }
}
