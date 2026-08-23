import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import 'adsense_stub_ad.dart' if (dart.library.html) 'adsense_web_ad.dart';

/// A responsive ad banner widget supporting Google Mobile Ads (AdMob) on mobile
/// and Google AdSense on Web.
class AppAdBannerWidget extends StatefulWidget {
  final String? adSlot; // AdSense ad unit slot ID for Web (optional)
  final Alignment alignment;
  final double? maxWidth;
  final double minHeight;
  final double maxHeight;

  const AppAdBannerWidget({
    super.key,
    this.adSlot,
    this.alignment = Alignment.center,
    this.maxWidth = 1200,
    this.minHeight = 90,
    this.maxHeight = 280,
  });

  @override
  State<AppAdBannerWidget> createState() => _AppAdBannerWidgetState();
}

class _AppAdBannerWidgetState extends State<AppAdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadMobileAd();
  }

  void _loadMobileAd() {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Mobile Ad failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
            });
          }
        },
      ),
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Web (Google AdSense)
    if (kIsWeb) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        alignment: widget.alignment,
        child: buildAdSenseWebAd(
          adClient: AdService.adSensePublisherId,
          adSlot: widget.adSlot,
          maxWidth: widget.maxWidth,
          minHeight: widget.minHeight,
          maxHeight: widget.maxHeight,
        ),
      );
    }

    // 2. Mobile (Google AdMob)
    if (_isAdLoaded && _bannerAd != null) {
      return Align(
        alignment: widget.alignment,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      );
    }

    // Fallback/Placeholder while loading on mobile
    return const SizedBox.shrink();
  }
}
