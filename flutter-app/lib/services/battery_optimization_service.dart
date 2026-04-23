import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kBatteryPromptShown = 'battery_opt_prompt_shown';
const _channel = MethodChannel('com.ibrahym.instagold/settings');

class BatteryOptimizationService {
  /// Returns true if this is a Xiaomi / Redmi / POCO device (MIUI).
  static Future<bool> _isMiui() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final manufacturer = info.manufacturer.toLowerCase();
      return manufacturer.contains('xiaomi') ||
          manufacturer.contains('redmi') ||
          manufacturer.contains('poco');
    } catch (_) {
      return false;
    }
  }

  /// Opens the system battery optimization exemption screen for this app.
  /// On MIUI this lands on the MIUI Power page; on stock Android it shows
  /// the standard "Ignore battery optimizations?" dialog.
  static Future<void> openBatterySettings() async {
    try {
      await _channel.invokeMethod('openBatterySettings');
    } on PlatformException catch (e) {
      debugPrint('BatteryOpt: cannot open settings — ${e.message}');
    }
  }

  /// Call once from the dashboard after the first successful price load.
  /// Shows a one-time prompt on Xiaomi/MIUI devices only; no-op on others.
  /// Returns true if the prompt was displayed this call.
  static Future<bool> maybePrompt({
    required void Function(String title, String body, VoidCallback onTap) showBanner,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kBatteryPromptShown) ?? false) return false;

      final miui = await _isMiui();
      if (!miui) return false;

      await prefs.setBool(_kBatteryPromptShown, true);

      showBanner(
        'Enable background notifications',
        'Tap to allow InstaGold to run in the background so price alerts arrive on time.',
        openBatterySettings,
      );
      return true;
    } catch (e) {
      debugPrint('BatteryOpt: maybePrompt failed — $e');
      return false;
    }
  }
}
