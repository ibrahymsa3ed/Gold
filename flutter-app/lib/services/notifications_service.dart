import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationsService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _priceChannelId = 'price_updates';
  static const _priceChannelName = 'Price Updates';

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

  static const _priceNotifDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _priceChannelId,
      _priceChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_stat_notification',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: Color(0xFFD4AF37),
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// No-op on foreground side. All scheduled notifications are now handled by
  /// the WorkManager background task which scrapes fresh prices before firing.
  Future<void> schedulePriceNotifications({
    required int intervalHours,
    String? title,
    String? body,
    double? price21k,
    double? price24k,
    double? priceOunce,
  }) async {
    debugPrint(
        'InstaGold: notifications delegated to background price watcher');
  }

  /// Fire a notification immediately with supplied content.
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

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('InstaGold: cancelAll failed: $e');
    }
  }
}
