import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_config.dart';

// When ads are disabled the widget collapses immediately with zero overhead.

/// Bottom banner ad (AdMob). Hidden on web; no-op if load fails.
class InstaGoldAdBanner extends StatefulWidget {
  const InstaGoldAdBanner({super.key});

  @override
  State<InstaGoldAdBanner> createState() => _InstaGoldAdBannerState();
}

class _InstaGoldAdBannerState extends State<InstaGoldAdBanner> {
  BannerAd? _bannerAd;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb || !kAdsEnabled) return;
    _load();
  }

  void _load() {
    final ad = BannerAd(
      adUnitId: AdConfig.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
        },
      ),
    );
    _bannerAd = ad;
    ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !kAdsEnabled) return const SizedBox.shrink();
    final ad = _bannerAd;
    if (!_loaded || ad == null) {
      return const SizedBox(height: 0);
    }
    return Container(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
      alignment: Alignment.center,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
