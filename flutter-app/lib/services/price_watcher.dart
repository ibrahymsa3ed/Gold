import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:workmanager/workmanager.dart';

import 'api_service.dart';
import 'notifications_service.dart';
import 'push_notifications_service.dart';

const _backgroundTaskName = 'instagold_price_watcher';
const _backgroundTaskUniqueName = 'instagold_price_watcher_unique';
const _kLastNotifTimestamp = 'pw_last_notif_ts';

const _priceChannelId = 'price_updates';
const _priceChannelName = 'Price Updates';

/// Interval between guaranteed notifications in milliseconds (1 hour).
const _notifIntervalMs = 60 * 60 * 1000;

/// Reads the latest gold prices the same way the dashboard does:
///   • call [ApiService.syncPrices] to scrape and write [GoldPriceCache]
///   • read back via [ApiService.getCurrentPrices]
///   • pick `sell_price` for 21K, 24K, and ounce
/// Notification banners and the home-screen widget show sell prices only;
/// the in-app dashboard still renders both buy and sell columns separately.
Future<({double? p21, double? p24, double? ounce})> _loadFreshPrices() async {
  final api = ApiService.devBypass();
  try {
    await api.syncPrices();
  } catch (e) {
    debugPrint('PriceWatcher: syncPrices failed, falling back to cache: $e');
  }
  final current = await api.getCurrentPrices();
  final pricesMap = (current['prices'] as Map?) ?? const {};
  num? readSell(String key) =>
      (pricesMap[key] as Map?)?['sell_price'] as num?;
  return (
    p21: readSell('21k')?.toDouble(),
    p24: readSell('24k')?.toDouble(),
    ounce: readSell('ounce')?.toDouble(),
  );
}

/// Top-level entry point invoked by WorkManager when the periodic task fires.
@pragma('vm:entry-point')
void priceWatcherCallback() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final prices = await _loadFreshPrices();
      final p21 = prices.p21;
      final p24 = prices.p24;
      final pOunce = prices.ounce;

      final prefs = await SharedPreferences.getInstance();

      try {
        if (p21 != null) {
          await HomeWidget.saveWidgetData<double>('price_21k', p21);
        }
        if (p24 != null) {
          await HomeWidget.saveWidgetData<double>('price_24k', p24);
        }
        if (pOunce != null) {
          await HomeWidget.saveWidgetData<double>('price_ounce', pOunce);
        }
        await HomeWidget.saveWidgetData<String>(
            'updated_at', DateTime.now().toIso8601String());
        await HomeWidget.updateWidget(
          name: 'InstaGoldWidgetProvider',
          iOSName: 'InstaGoldWidget',
          qualifiedAndroidName:
              'com.ibrahym.instagold.InstaGoldWidgetProvider',
        );
      } catch (e) {
        debugPrint('PriceWatcher: widget update failed: $e');
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final lastNotifMs = prefs.getInt(_kLastNotifTimestamp) ?? 0;
      final periodicDue = (nowMs - lastNotifMs) >= _notifIntervalMs;

      if (!periodicDue) {
        return Future.value(true);
      }

      // Self-disable when the backend is going to push us. The flag is set
      // by PushNotificationsService after a successful registration where
      // the server confirms this device qualifies (FCM_SUMMARIES_ENABLED on
      // AND build_number >= MIN_FCM_CLIENT_BUILD AND summaries_enabled=1).
      // Avoids double notifications during/after the FCM rollout.
      if (await PushNotificationsService.isFcmActive()) {
        debugPrint('PriceWatcher: skip local notif (fcm_summaries_active)');
        return Future.value(true);
      }

      if (p21 == null && p24 == null && pOunce == null) {
        debugPrint('PriceWatcher: no prices available — skipping notif');
        return Future.value(true);
      }

      final body = NotificationsService.buildPriceBody(
        price21k: p21,
        price24k: p24,
        priceOunce: pOunce,
        // Background isolate has no BuildContext; pull the user's last
        // selected locale from SharedPreferences (written by app.dart).
        localeCode: prefs.getString('instagold_locale') ?? 'en',
      );

      tz.initializeTimeZones();
      final plugin = FlutterLocalNotificationsPlugin();
      const androidInit =
          AndroidInitializationSettings('@drawable/ic_stat_notification');
      const iosInit = DarwinInitializationSettings();
      await plugin.initialize(
          const InitializationSettings(android: androidInit, iOS: iosInit));

      const details = NotificationDetails(
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

      await plugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        'InstaGold',
        body,
        details,
      );

      await prefs.setInt(_kLastNotifTimestamp, nowMs);

      return Future.value(true);
    } catch (e) {
      debugPrint('PriceWatcher: background task failed: $e');
      return Future.value(false);
    }
  });
}

class PriceWatcher {
  static Future<void> initialize() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;

    try {
      await Workmanager().initialize(
        priceWatcherCallback,
        isInDebugMode: false,
      );

      await Workmanager().registerPeriodicTask(
        _backgroundTaskUniqueName,
        _backgroundTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    } catch (e) {
      debugPrint('PriceWatcher: initialize failed: $e');
    }
  }
}
