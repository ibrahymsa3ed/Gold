// FCM client wiring for InstaGold price summaries.
//
// What it does
// ------------
//   1. Asks for notification permission (iOS + Android 13+).
//   2. Retrieves the FCM token (and listens for rotations).
//   3. Resolves a stable per-install device id stored in SharedPreferences.
//   4. Reads the current build_number via package_info_plus.
//   5. Calls POST/PUT /api/devices on the backend so the server knows where
//      to push, what locale to render in, and whether summaries are wanted.
//   6. Persists the backend-returned `fcm_summaries_active` flag locally so
//      [PriceWatcher] / [IosBackgroundFetch] can suppress their own local
//      notifications when the server is going to push us anyway.
//   7. Shows incoming foreground messages via [NotificationsService] (iOS
//      banners only render automatically when the app is backgrounded).
//
// Safety
// ------
// All network calls use [ApiService] which already returns null on failure,
// so a missing/unreachable backend leaves the rest of the app untouched.
// Phase 2 ships with the backend kill switch closed, so even successful
// registration cannot result in a real push until Phase 3.

import 'dart:io' show Platform;
import 'dart:math' show Random;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'notifications_service.dart';

// SharedPreferences keys.
const _kDeviceIdKey = 'instagold_device_id';
const _kFcmTokenKey = 'instagold_fcm_token';
const _kSummariesEnabledKey = 'instagold_summaries_enabled';
const _kFcmActiveKey = 'instagold_fcm_summaries_active';

/// Top-level FCM background message handler.
/// Must be a top-level function (not a method/closure) so it can run in the
/// dedicated background isolate. Kept intentionally tiny — Android already
/// renders the system notification from the FCM payload's `notification`
/// block via the manifest defaults; this handler exists so messages with a
/// `data`-only payload don't get dropped if we ever switch to silent push.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint('InstaGold: FCM bg msg ${message.messageId}');
  }
}

class PushNotificationsService {
  PushNotificationsService(this._notificationsService);

  final NotificationsService _notificationsService;

  bool _initialized = false;
  String? _deviceId;
  String? _lastToken;
  String? _lastLocale;

  /// `true` iff the backend confirmed it will deliver slot summaries to this
  /// device. Local notification fallbacks consult this via [isFcmActive].
  bool _fcmActive = false;
  bool get fcmActive => _fcmActive;

  /// Reads the cached flag synchronously from SharedPreferences. Used by
  /// background isolates that don't have a [PushNotificationsService]
  /// instance (price_watcher, ios_background_fetch).
  static Future<bool> isFcmActive() async {
    if (kIsWeb) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kFcmActiveKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns the persisted `summaries_enabled` user choice (defaults to true).
  static Future<bool> readSummariesEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSummariesEnabledKey) ?? true;
  }

  Future<String?> deviceId() async {
    if (_deviceId != null) return _deviceId;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kDeviceIdKey);
    if (id == null || id.isEmpty) {
      id = _generateDeviceId();
      await prefs.setString(_kDeviceIdKey, id);
    }
    _deviceId = id;
    return id;
  }

  /// Initialize FCM + register the current device with the backend.
  /// Safe to call multiple times — subsequent calls become a no-op.
  ///
  /// [localeCode] is forwarded so server-side body rendering (sell-only,
  /// localized) matches what the user sees in-app.
  Future<void> initialize({
    required ApiService apiService,
    required String localeCode,
  }) async {
    if (_initialized) {
      // If only the locale changed, sync it.
      if (localeCode != _lastLocale) {
        await syncLocale(apiService, localeCode);
      }
      return;
    }
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _debugLog(
          'InstaGold: FCM permission status=${settings.authorizationStatus}');

      // iOS APNs token is required before we can fetch the FCM token. On
      // simulators / devices without APNs entitlement this returns null and
      // FirebaseMessaging.getToken() will throw — we degrade silently.
      if (Platform.isIOS) {
        await messaging.getAPNSToken();
      }

      String? token;
      try {
        token = await messaging.getToken();
      } catch (e) {
        _debugLog('InstaGold: FCM getToken failed: $e');
      }

      if (token == null || token.isEmpty) {
        _debugLog('InstaGold: no FCM token yet — registration skipped');
        _initialized = true;
        return;
      }
      _debugLog('InstaGold: FCM token obtained: ${_tokenPrefix(token)}...');

      _lastToken = token;
      _lastLocale = localeCode;

      // Read user's current preference (defaults to enabled). This is the
      // "soft" toggle the user controls via Settings; the "hard" gate is
      // the server's build-number filter.
      final summariesEnabled = await readSummariesEnabled();

      final deviceIdValue = await deviceId();
      final buildNumber = await _readBuildNumber();
      final platform = Platform.isIOS ? 'ios' : 'android';
      _debugLog(
        'InstaGold: push registration context '
        'platform=$platform locale=$localeCode build=$buildNumber '
        'summariesEnabled=$summariesEnabled deviceId=$deviceIdValue',
      );

      final result = await apiService.registerDevice(
        deviceId: deviceIdValue!,
        platform: platform,
        fcmToken: token,
        locale: localeCode,
        buildNumber: buildNumber,
      );
      _debugLog(
          'InstaGold: registerDevice result=${_redactDeviceResult(result)}');
      if (result == null) {
        _debugLog(
            'InstaGold: registerDevice returned null — registration failed');
      } else {
        _debugLog(
          'InstaGold: FCM active flag will be='
          '${result['fcm_summaries_active']}',
        );
      }

      // Persist the backend's confirmation that pushes will actually arrive.
      // This is what the local notification fallbacks check to avoid double
      // notifications post-flip.
      await _persistActiveFlag(result);

      // If the user has explicitly disabled summaries, push that to backend
      // so the next slot sweep skips this device.
      if (!summariesEnabled) {
        await apiService.updateDevice(
          deviceId: deviceIdValue,
          summariesEnabled: false,
        );
      }

      // Persist current token so next launch can detect rotation cheaply.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kFcmTokenKey, token);

      // Wire token rotation — on iOS this fires when APNs assigns or rotates
      // a token, on Android it fires after a Play Services data wipe.
      messaging.onTokenRefresh.listen((newToken) async {
        if (newToken == _lastToken) return;
        _lastToken = newToken;
        _debugLog('InstaGold: FCM token rotated');
        final updated = await apiService.updateDevice(
          deviceId: deviceIdValue,
          fcmToken: newToken,
          buildNumber: buildNumber,
        );
        await _persistActiveFlag(updated);
        await prefs.setString(_kFcmTokenKey, newToken);
      });

      // Foreground messages: iOS won't render the banner automatically while
      // the app is in the foreground, so we hand off to the local notification
      // plugin (which is already initialised via NotificationsService.init()).
      FirebaseMessaging.onMessage.listen((message) async {
        try {
          final n = message.notification;
          if (n == null) return;
          await _notificationsService.showPriceChangeNotification(
            title: n.title ?? 'InstaGold',
            body: n.body ?? '',
          );
        } catch (e) {
          _debugLog('InstaGold: FCM foreground render failed: $e');
        }
      });

      _initialized = true;
      _debugLog(
          'InstaGold: PushNotificationsService initialized (active=$_fcmActive)');
    } catch (e) {
      _debugLog('InstaGold: PushNotificationsService init failed: $e');
      _initialized = true;
    }
  }

  /// Pushes the new locale to the backend so summary bodies switch language
  /// for this device.
  Future<void> syncLocale(ApiService apiService, String localeCode) async {
    if (kIsWeb || !_initialized || _deviceId == null) {
      _lastLocale = localeCode;
      return;
    }
    if (localeCode == _lastLocale) return;
    final updated = await apiService.updateDevice(
      deviceId: _deviceId!,
      locale: localeCode,
    );
    _lastLocale = localeCode;
    await _persistActiveFlag(updated);
  }

  /// User toggled the "Price summaries" switch in Settings. We persist the
  /// preference locally and ALSO sync to backend so the server stops
  /// queueing this device.
  Future<void> setSummariesEnabled(ApiService apiService, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSummariesEnabledKey, enabled);
    if (kIsWeb || _deviceId == null) return;
    final updated = await apiService.updateDevice(
      deviceId: _deviceId!,
      summariesEnabled: enabled,
    );
    await _persistActiveFlag(updated);
  }

  /// Asks the backend to fire a single push to this device right now,
  /// ignoring slot/last_sent_slot. Returns true on success.
  Future<bool> sendTest(ApiService apiService) async {
    if (kIsWeb || _deviceId == null) return false;
    final result = await apiService.sendTestPush(_deviceId!);
    return result != null && result['ok'] == true;
  }

  Future<int?> _readBuildNumber() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final n = int.tryParse(info.buildNumber);
      return n;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistActiveFlag(Map<String, dynamic>? result) async {
    final active = result != null && result['fcm_summaries_active'] == true;
    _fcmActive = active;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kFcmActiveKey, active);
    } catch (_) {
      // Best-effort persistence; in-memory copy is still correct.
    }
    _debugLog('InstaGold: persisted FCM active flag=$active');
  }

  void _debugLog(String message) {
    if (kDebugMode) debugPrint(message);
  }

  String _tokenPrefix(String token) {
    if (token.length <= 20) return token;
    return token.substring(0, 20);
  }

  Map<String, dynamic>? _redactDeviceResult(Map<String, dynamic>? result) {
    if (result == null) return null;
    final copy = Map<String, dynamic>.from(result);
    final token = copy['fcm_token'];
    if (token is String && token.isNotEmpty) {
      copy['fcm_token'] = '${_tokenPrefix(token)}...';
    }
    return copy;
  }

  /// Generates a 32-char hex id; persisted in SharedPreferences. We keep
  /// this stable per-install (it survives app launches but resets on
  /// uninstall, which is exactly what we want for FCM token mapping).
  String _generateDeviceId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
