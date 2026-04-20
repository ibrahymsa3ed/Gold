import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

import 'api_service.dart';
import 'notifications_service.dart';

const _backgroundTaskName = 'instagold_price_watcher';
const _backgroundTaskUniqueName = 'instagold_price_watcher_unique';
const _kLastSlotKey = 'pw_last_slot';

const _priceChannelId = 'price_updates';
const _priceChannelName = 'Price Updates';

/// Cairo fixed-time notification slots (hours in Africa/Cairo).
const _cairoSlotHours = [7, 11, 15, 19];

/// Quiet hours: no notifications between 23:00 and 07:00 Cairo.
const _quietStart = 23;
const _quietEnd = 7;

/// Reads the latest gold prices the same way the dashboard does:
///   - call [ApiService.syncPrices] to scrape and write [GoldPriceCache]
///   - read back via [ApiService.getCurrentPrices]
///   - pick `sell_price` for 21K, 24K, and ounce
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

/// Returns the current Cairo slot key (e.g. "2026-04-20#11") if we are
/// within the 30-minute window after a fixed slot hour, or null otherwise.
String? _currentCairoSlot() {
  tz.initializeTimeZones();
  final cairo = tz.getLocation('Africa/Cairo');
  final now = tz.TZDateTime.now(cairo);

  final hour = now.hour;

  // Quiet hours check
  if (hour >= _quietStart || hour < _quietEnd) return null;

  for (final slotHour in _cairoSlotHours) {
    if (hour == slotHour && now.minute < 30) {
      return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}#$slotHour';
    }
  }
  return null;
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

      // Always update the home-screen widget with fresh prices.
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

      // Fixed Cairo slot notification: only fire if we are inside a
      // 30-minute window after 07:00/11:00/15:00/19:00 Cairo time,
      // and we haven't already sent for this exact slot.
      final slot = _currentCairoSlot();
      if (slot == null) {
        return Future.value(true);
      }

      final lastSlot = prefs.getString(_kLastSlotKey);
      if (lastSlot == slot) {
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

      await prefs.setString(_kLastSlotKey, slot);
      debugPrint('PriceWatcher: notification fired for slot $slot');

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
