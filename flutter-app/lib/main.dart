import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:home_widget/home_widget.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/price_watcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (!kIsWeb) {
    await HomeWidget.setAppGroupId('group.com.ibrahym.goldtracker');
    await MobileAds.instance.initialize();
    await PriceWatcher.initialize();
  }
  runApp(const GoldFamilyApp());
}
