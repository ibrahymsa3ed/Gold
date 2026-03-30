import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBioWOL4h6RgLUiXyC1Smgiwpqahm_g7tY',
    appId: '1:190629243449:web:73ad8df5886d2ea4e6bbe8',
    messagingSenderId: '190629243449',
    projectId: 'goldcalculate',
    authDomain: 'goldcalculate.firebaseapp.com',
    storageBucket: 'goldcalculate.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBioWOL4h6RgLUiXyC1Smgiwpqahm_g7tY',
    appId: '1:190629243449:android:73ad8df5886d2ea4e6bbe8',
    messagingSenderId: '190629243449',
    projectId: 'goldcalculate',
    storageBucket: 'goldcalculate.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBioWOL4h6RgLUiXyC1Smgiwpqahm_g7tY',
    appId: '1:190629243449:ios:73ad8df5886d2ea4e6bbe8',
    messagingSenderId: '190629243449',
    projectId: 'goldcalculate',
    storageBucket: 'goldcalculate.firebasestorage.app',
    iosBundleId: 'com.ibrahym.goldtracker',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBioWOL4h6RgLUiXyC1Smgiwpqahm_g7tY',
    appId: '1:190629243449:ios:73ad8df5886d2ea4e6bbe8',
    messagingSenderId: '190629243449',
    projectId: 'goldcalculate',
    storageBucket: 'goldcalculate.firebasestorage.app',
    iosBundleId: 'com.ibrahym.goldtracker',
  );
}
