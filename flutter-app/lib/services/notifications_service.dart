import 'dart:async';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import '../l10n.dart';

class NotificationsService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _priceChannelId = 'price_updates';
  static const _priceChannelName = 'Price Updates';

  /// Completer that resolves once [init] finishes. Every public method
  /// awaits this so callers never race against plugin initialization.
  final Completer<void> _ready = Completer<void>();

  Future<void> init() async {
    try {
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

      // Cancel any stale scheduled notifications from previous app versions.
      // We delegate periodic notifications to the WorkManager-based PriceWatcher,
      // so no foreground-scheduled notifications should remain.
      try {
        await _plugin.cancelAll();
      } catch (e) {
        debugPrint('InstaGold: stale notif cleanup failed: $e');
      }

      debugPrint('InstaGold: NotificationsService initialized');
    } catch (e) {
      debugPrint('InstaGold: NotificationsService init failed: $e');
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  /// Renders the notification body for a sell-only price summary.
  ///
  /// English: `21K: 5240 EGP | 24K: 5990 EGP | Ounce: $2350`
  /// Arabic:  `عيار 21: 5240 جنيه | عيار 24: 5990 جنيه | الأونصه: $2350`
  ///
  /// Numbers are intentionally kept in Western digits in both modes
  /// (product decision: parity with the in-app price cards and widget).
  static String buildPriceBody({
    double? price21k,
    double? price24k,
    double? priceOunce,
    String localeCode = 'en',
  }) {
    final isAr = localeCode == 'ar';
    final egp = isAr ? 'جنيه' : 'EGP';
    final ounceLabel = isAr ? 'الأونصه' : 'Ounce';

    final parts = <String>[];
    if (price21k != null) {
      parts.add(
          '${AppStrings.formatKarat(localeCode, 21)}: ${price21k.toStringAsFixed(0)} $egp');
    }
    if (price24k != null) {
      parts.add(
          '${AppStrings.formatKarat(localeCode, 24)}: ${price24k.toStringAsFixed(0)} $egp');
    }
    if (priceOunce != null) {
      parts.add('$ounceLabel: \$${priceOunce.toStringAsFixed(0)}');
    }
    if (parts.isEmpty) {
      return isAr ? 'تحقق من آخر أسعار الذهب!' : 'Check the latest gold prices!';
    }
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
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
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
  /// Throws on failure so callers can surface the error to the user.
  Future<void> showPriceChangeNotification({
    required String title,
    required String body,
  }) async {
    await _ready.future;
    await _plugin.show(2, title, body, _priceNotifDetails);
    debugPrint('InstaGold: notification shown — $title | $body');
  }

  Future<void> cancelAll() async {
    await _ready.future;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('InstaGold: cancelAll failed: $e');
    }
  }
}
