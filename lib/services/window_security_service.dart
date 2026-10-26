import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WindowSecurityService {
  static const _channel = MethodChannel('local_vault/window_security');

  static Future<void> setSecureFlag(bool enable) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setSecureFlag', {'enable': enable});
    } catch (e) {
      debugPrint('[WindowSecurity] setSecureFlag($enable) failed: $e');
    }
  }
}
