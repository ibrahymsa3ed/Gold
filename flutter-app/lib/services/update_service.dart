import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../config.dart';

class UpdateInfo {
  final bool needsUpdate;
  final bool isForced;
  final String whatsNewText;
  final int latestVersionCode;
  final int currentVersionCode;

  const UpdateInfo({
    required this.needsUpdate,
    required this.isForced,
    required this.whatsNewText,
    required this.latestVersionCode,
    required this.currentVersionCode,
  });
}

class UpdateService {
  static const _storeUrl =
      'https://play.google.com/store/apps/details?id=com.ibrahym.goldfamily';

  static String get storeUrl => _storeUrl;

  static Future<UpdateInfo?> checkForUpdate(String locale) async {
    if (kIsWeb) return null;

    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/app-version');
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;

      final data = json.decode(resp.body) as Map<String, dynamic>;
      final latestCode = (data['latest_version_code'] as num?)?.toInt() ?? 0;
      final minCode = (data['min_version_code'] as num?)?.toInt() ?? 0;
      final whatsNew = data['whats_new'] as Map<String, dynamic>? ?? {};
      final localeKey = locale == 'ar' ? 'ar' : 'en';
      final text = (whatsNew[localeKey] as String?) ?? '';

      final info = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(info.buildNumber) ?? 0;

      if (Platform.isIOS) return null;

      final needsUpdate = currentCode < latestCode;
      final isForced = currentCode < minCode;

      return UpdateInfo(
        needsUpdate: needsUpdate,
        isForced: isForced,
        whatsNewText: text,
        latestVersionCode: latestCode,
        currentVersionCode: currentCode,
      );
    } catch (e) {
      debugPrint('UpdateService: check failed: $e');
      return null;
    }
  }
}
