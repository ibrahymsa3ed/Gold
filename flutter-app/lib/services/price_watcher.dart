import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:workmanager/workmanager.dart';

import 'gold_scraper.dart';

const _backgroundTaskName = 'instagold_price_watcher';
const _backgroundTaskUniqueName = 'instagold_price_watcher_unique';
const _kLastPrice21k = 'pw_last_21k';
const _kLastPrice24k = 'pw_last_24k';
const _kLastPriceOunce = 'pw_last_ounce';

const _priceChannelId = 'price_updates';
const _priceChannelName = 'Price Updates';

/// Top-level entry point invoked by WorkManager when the periodic task fires.
/// Must be a top-level function annotated with [pragma].
@pragma('vm:entry-point')
void priceWatcherCallback() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final scraped = await GoldScraper.scrapeGoldPrices();
      final carats = (scraped['carats'] as Map?) ?? {};

      double? p21k;
      double? p24k;
      final c21 = carats['21'];
      if (c21 is Map) {
        p21k = (c21['buy'] as num?)?.toDouble() ??
            (c21['sell'] as num?)?.toDouble();
      }
      final c24 = carats['24'];
      if (c24 is Map) {
        p24k = (c24['buy'] as num?)?.toDouble() ??
            (c24['sell'] as num?)?.toDouble();
      }
      final pOunce = (scraped['ouncePrice'] as num?)?.toDouble();

      final prefs = await SharedPreferences.getInstance();
      final last21 = prefs.getDouble(_kLastPrice21k);
      final last24 = prefs.getDouble(_kLastPrice24k);
      final lastOunce = prefs.getDouble(_kLastPriceOunce);

      final changed21 = _isChanged(last21, p21k);
      final changed24 = _isChanged(last24, p24k);
      final changedOunce = _isChanged(lastOunce, pOunce);

      if (!changed21 && !changed24 && !changedOunce) {
        return Future.value(true);
      }

      // Save new values
      if (p21k != null) await prefs.setDouble(_kLastPrice21k, p21k);
      if (p24k != null) await prefs.setDouble(_kLastPrice24k, p24k);
      if (pOunce != null) await prefs.setDouble(_kLastPriceOunce, pOunce);

      // Update the iOS home widget shared store
      try {
        if (p21k != null) {
          await HomeWidget.saveWidgetData<double>('price_21k', p21k);
        }
        if (p24k != null) {
          await HomeWidget.saveWidgetData<double>('price_24k', p24k);
        }
        if (pOunce != null) {
          await HomeWidget.saveWidgetData<double>('price_ounce', pOunce);
        }
        await HomeWidget.saveWidgetData<String>(
            'updated_at', DateTime.now().toIso8601String());
        await HomeWidget.updateWidget(
          name: 'InstaGoldWidgetProvider',
          androidName: 'InstaGoldWidgetProvider',
          iOSName: 'InstaGoldWidget',
        );
      } catch (e) {
        debugPrint('PriceWatcher: widget update failed: $e');
      }

      // Build a notification body that highlights changed values
      final parts = <String>[];
      if (p21k != null) {
        parts.add('21K: ${p21k.toStringAsFixed(0)} EGP'
            '${changed21 ? ' (${_arrow(last21, p21k)})' : ''}');
      }
      if (p24k != null) {
        parts.add('24K: ${p24k.toStringAsFixed(0)} EGP'
            '${changed24 ? ' (${_arrow(last24, p24k)})' : ''}');
      }
      if (pOunce != null) {
        parts.add('Ounce: \$${pOunce.toStringAsFixed(0)}'
            '${changedOunce ? ' (${_arrow(lastOunce, pOunce)})' : ''}');
      }

      tz.initializeTimeZones();
      final plugin = FlutterLocalNotificationsPlugin();
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await plugin.initialize(
          const InitializationSettings(android: androidInit, iOS: iosInit));

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _priceChannelId,
          _priceChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      );

      await plugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        'Gold prices updated',
        parts.join(' | '),
        details,
      );

      return Future.value(true);
    } catch (e) {
      debugPrint('PriceWatcher: background task failed: $e');
      return Future.value(false);
    }
  });
}

bool _isChanged(double? a, double? b) {
  if (b == null) return false;
  if (a == null) return true;
  // Treat sub-1 EGP fluctuations as noise
  return (a - b).abs() >= 1.0;
}

String _arrow(double? prev, double curr) {
  if (prev == null) return '';
  if (curr > prev) return '+${(curr - prev).toStringAsFixed(0)}';
  if (curr < prev) return '${(curr - prev).toStringAsFixed(0)}';
  return '';
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
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );
    } catch (e) {
      debugPrint('PriceWatcher: initialize failed: $e');
    }
  }
}
