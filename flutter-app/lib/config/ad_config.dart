import 'app_flavor.dart';

/// Set to true when you are ready to monetise with AdMob.
/// While false: MobileAds is never initialised, no ad requests are made,
/// and the banner slot collapses to zero height — no SDK overhead at all.
const bool kAdsEnabled = false;

/// AdMob unit IDs. Use [Google test IDs](https://developers.google.com/admob/android/test-ads) for dev.
/// For production Play release, set real IDs from AdMob console:
/// `--dart-define=ADMOB_BANNER_PROD=ca-app-pub-xxx/yyy`
class AdConfig {
  AdConfig._();

  /// Google sample banner (always safe for dev / internal testing).
  static const String _googleTestBanner = 'ca-app-pub-3940256099942544/6300978111';

  static const String _bannerProd = String.fromEnvironment(
    'ADMOB_BANNER_PROD',
    defaultValue: _googleTestBanner,
  );

  static String get bannerAdUnitId {
    switch (instaGoldFlavor) {
      case InstaGoldFlavor.dev:
        return _googleTestBanner;
      case InstaGoldFlavor.prod:
        return _bannerProd;
    }
  }
}
