import 'dart:io' show Platform;

import 'package:background_fetch/background_fetch.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:home_widget/home_widget.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/ios_background_fetch.dart';
import 'services/price_watcher.dart';
import 'services/push_notifications_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (!kIsWeb) {
    // Top-level FCM background handler must be registered before runApp.
    // The handler itself lives in push_notifications_service.dart.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await HomeWidget.setAppGroupId('group.com.ibrahym.goldtracker');
    await MobileAds.instance.initialize();
    await PriceWatcher.initialize();
    if (Platform.isIOS) {
      await IosBackgroundFetch.initialize();
    }
  }
  runApp(const GoldFamilyApp());
  if (!kIsWeb && Platform.isIOS) {
    BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
  }
}
