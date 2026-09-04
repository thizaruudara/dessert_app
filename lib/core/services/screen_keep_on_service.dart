import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScreenKeepOnService {
  static const MethodChannel _channel = MethodChannel('com.institute.dessert/screen');

  /// Keeps the device screen turned on (prevents screen timeout/sleep during live exam)
  static Future<void> setKeepScreenOn(bool enable) async {
    try {
      await _channel.invokeMethod('keepScreenOn', {'enable': enable});
      debugPrint('ScreenKeepOnService: setKeepScreenOn($enable) successful');
    } catch (e) {
      debugPrint('ScreenKeepOnService: Error setting keepScreenOn: $e');
    }
  }
}
