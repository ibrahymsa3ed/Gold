import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationsService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _priceChannelId = 'price_updates';
  static const _priceChannelName = 'Price Updates';
  static const _settingsChannelId = 'settings';
  static const _settingsChannelName = 'Settings';

  Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(settings);

    if (!kIsWeb && Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.requestNotificationsPermission();
        await android.requestExactAlarmsPermission();
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            _priceChannelId,
            _priceChannelName,
            description: 'Gold price update notifications',
            importance: Importance.high,
          ),
        );
      }
    } else if (!kIsWeb && Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  static String buildPriceBody({
    double? price21k,
    double? price24k,
    double? priceOunce,
  }) {
    final parts = <String>[];
    if (price21k != null) parts.add('21K: ${price21k.toStringAsFixed(0)} EGP');
    if (price24k != null) parts.add('24K: ${price24k.toStringAsFixed(0)} EGP');
    if (priceOunce != null) {
      parts.add('Ounce: \$${priceOunce.toStringAsFixed(0)}');
    }
    if (parts.isEmpty) return 'Check the latest gold prices!';
    return parts.join(' | ');
  }

  static NotificationDetails get _priceNotifDetails => const NotificationDetails(
        android: AndroidNotificationDetails(
          _priceChannelId,
          _priceChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// Schedule fallback periodic notifications (the primary notification path is
  /// the WorkManager background task that fires only on actual price change).
  /// This still ensures the user sees something even if background fetch is
  /// throttled by the OS.
  Future<void> schedulePriceNotifications({
    required int intervalHours,
    String title = 'InstaGold',
    String? body,
    double? price21k,
    double? price24k,
    double? priceOunce,
  }) async {
    final notifBody = body ??
        buildPriceBody(
          price21k: price21k,
          price24k: price24k,
          priceOunce: priceOunce,
        );

    // Cancel only the previously scheduled ones in our id range
    for (int i = 1; i <= 50; i++) {
      try {
        await _plugin.cancel(100 + i);
      } catch (_) {}
    }

    final now = tz.TZDateTime.now(tz.local);
    final count = (24 * 7) ~/ intervalHours;

    for (int i = 1; i <= count && i <= 50; i++) {
      final scheduled = now.add(Duration(hours: intervalHours * i));
      try {
        await _plugin.zonedSchedule(
          100 + i,
          title,
          notifBody,
          scheduled,
          _priceNotifDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        debugPrint('InstaGold: schedule #$i failed: $e');
      }
    }
  }

  /// Fire an immediate notification — used by the background change detector
  /// when prices actually change.
  Future<void> showPriceChangeNotification({
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.show(2, title, body, _priceNotifDetails);
    } catch (e) {
      debugPrint('InstaGold: price change notification failed: $e');
    }
  }

  Future<void> showImmediateTestNotification(String body) async {
    try {
      await _plugin.show(0, 'InstaGold', body, _priceNotifDetails);
    } catch (e) {
      debugPrint('InstaGold: test notification failed: $e');
    }
  }

  Future<void> showSettingsSavedNotification() async {
    try {
      const android = AndroidNotificationDetails(
        _settingsChannelId,
        _settingsChannelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      );
      const ios = DarwinNotificationDetails();
      const details = NotificationDetails(android: android, iOS: ios);

      await _plugin.show(
          1, 'InstaGold', 'Settings saved successfully', details);
    } catch (e) {
      debugPrint('InstaGold: settings notification failed: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('InstaGold: cancelAll failed: $e');
    }
  }
}
