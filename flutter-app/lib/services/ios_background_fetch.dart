import 'dart:io';

import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'dart:ui' show Color;

import 'api_service.dart';
import 'notifications_service.dart';
import 'push_notifications_service.dart';

const _kLastNotifTimestamp = 'pw_last_notif_ts';
const _notifIntervalMs = 60 * 60 * 1000;

const _priceChannelId = 'price_updates';
const _priceChannelName = 'Price Updates';

/// Top-level handler used when iOS wakes the app while it is terminated.
/// Must be a top-level function (not a closure) to be called from a background
/// isolate.
@pragma('vm:entry-point')
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  final taskId = task.taskId;
  if (task.timeout) {
    BackgroundFetch.finish(taskId);
    return;
  }
  try {
    await _runFetch();
  } catch (e) {
    debugPrint('IosBackgroundFetch headless: $e');
  } finally {
    BackgroundFetch.finish(taskId);
  }
}

Future<void> _runFetch() async {
  final api = ApiService.devBypass();
  try {
    await api.syncPrices();
  } catch (e) {
    debugPrint('IosBackgroundFetch: syncPrices failed: $e');
  }
  Map<String, dynamic> current;
  try {
    current = await api.getCurrentPrices();
  } catch (e) {
    debugPrint('IosBackgroundFetch: getCurrentPrices failed: $e');
    return;
  }
  // Notifications + widget show sell prices only (21K, 24K, ounce). The
  // dashboard renders buy and sell separately, but here we surface the price
  // a customer would actually pay.
  final pricesMap = (current['prices'] as Map?) ?? const {};
  final p21 = ((pricesMap['21k'] as Map?)?['sell_price'] as num?)?.toDouble();
  final p24 = ((pricesMap['24k'] as Map?)?['sell_price'] as num?)?.toDouble();
  final pOunce =
      ((pricesMap['ounce'] as Map?)?['sell_price'] as num?)?.toDouble();

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
    debugPrint('IosBackgroundFetch: widget update failed: $e');
  }

  if (p21 == null && p24 == null && pOunce == null) {
    debugPrint('IosBackgroundFetch: no prices available — skipping notif');
    return;
  }

  // Self-disable when backend will push this device — see price_watcher.dart
  // for the full reasoning.
  if (await PushNotificationsService.isFcmActive()) {
    debugPrint('IosBackgroundFetch: skip local notif (fcm_summaries_active)');
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final lastNotifMs = prefs.getInt(_kLastNotifTimestamp) ?? 0;
  if (nowMs - lastNotifMs < _notifIntervalMs) {
    debugPrint(
        'IosBackgroundFetch: skip notif (last=${(nowMs - lastNotifMs) ~/ 1000}s ago)');
    return;
  }

  final body = NotificationsService.buildPriceBody(
    price21k: p21,
    price24k: p24,
    priceOunce: pOunce,
    // Background isolate has no BuildContext; pull the user's last selected
    // locale from SharedPreferences (written by app.dart).
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
  debugPrint('IosBackgroundFetch: notification fired');
}

/// Best-effort iOS background notifications using BGAppRefreshTask via the
/// `background_fetch` plugin. iOS decides when to wake the app — typical
/// minimum is 15 minutes but Apple may delay or skip fires entirely. The
/// foreground guarantee in the dashboard still ensures notifications fire on
/// app open if 1h has passed.
class IosBackgroundFetch {
  static Future<void> initialize() async {
    if (kIsWeb) return;
    if (!Platform.isIOS) return;

    try {
      await BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: 15,
          stopOnTerminate: false,
          enableHeadless: true,
          startOnBoot: true,
          requiredNetworkType: NetworkType.ANY,
        ),
        _onFetch,
        _onTimeout,
      );
      await BackgroundFetch.start();
      debugPrint('IosBackgroundFetch: configured + started');
    } catch (e) {
      debugPrint('IosBackgroundFetch: configure failed: $e');
    }
  }

  static Future<void> _onFetch(String taskId) async {
    try {
      await _runFetch();
    } catch (e) {
      debugPrint('IosBackgroundFetch onFetch: $e');
    } finally {
      BackgroundFetch.finish(taskId);
    }
  }

  static void _onTimeout(String taskId) {
    debugPrint('IosBackgroundFetch: timeout $taskId');
    BackgroundFetch.finish(taskId);
  }
}
