import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
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

    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
    } else if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  String _buildPriceBody({
    double? price21k,
    double? price24k,
    double? priceOunce,
  }) {
    final parts = <String>[];
    if (price21k != null) parts.add('21K: ${price21k.toStringAsFixed(0)} EGP');
    if (price24k != null) parts.add('24K: ${price24k.toStringAsFixed(0)} EGP');
    if (priceOunce != null) parts.add('Ounce: \$${priceOunce.toStringAsFixed(0)}');
    if (parts.isEmpty) return 'Check the latest gold prices!';
    return parts.join(' | ');
  }

  Future<void> schedulePriceNotifications({
    required int intervalHours,
    String title = 'InstaGold',
    String? body,
    double? price21k,
    double? price24k,
    double? priceOunce,
  }) async {
    try {
      await _plugin.cancelAll();

      final notifBody = body ?? _buildPriceBody(
        price21k: price21k,
        price24k: price24k,
        priceOunce: priceOunce,
      );

      final now = tz.TZDateTime.now(tz.local);

      const notifDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          _priceChannelId,
          _priceChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      );

      // Schedule multiple notifications spread over the next 7 days
      final count = (24 * 7) ~/ intervalHours;
      for (int i = 1; i <= count && i <= 50; i++) {
        final scheduled = now.add(Duration(hours: intervalHours * i));
        await _plugin.zonedSchedule(
          100 + i,
          title,
          notifBody,
          scheduled,
          notifDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (_) {}
  }

  Future<void> showPriceUpdateNotification({
    required String title,
    required String body,
  }) async {
    const android = AndroidNotificationDetails(
      _priceChannelId,
      _priceChannelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);

    await _plugin.show(2, title, body, details);
  }

  Future<void> showSettingsSavedNotification() async {
    try {
      const android = AndroidNotificationDetails(
        _settingsChannelId,
        _settingsChannelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
      const ios = DarwinNotificationDetails();
      const details = NotificationDetails(android: android, iOS: ios);

      await _plugin.show(1, 'InstaGold', 'Settings saved successfully', details);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
