import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Central service for initializing and providing ad IDs for AdMob & AdSense.
class AdService {
  AdService._();

  /// Your production AdSense publisher ID
  static const String adSensePublisherId = 'ca-pub-9551858594597671';

  /// Standard AdMob Test Unit IDs (Replace with your actual AdMob Unit IDs in production)
  static String get bannerAdUnitId {
    if (kIsWeb) {
      return '';
    }
    if (Platform.isAndroid) {
      // Android Test Banner Ad Unit ID
      return 'ca-app-pub-3940256099942544/6300978111';
    } else if (Platform.isIOS) {
      // iOS Test Banner Ad Unit ID
      return 'ca-app-pub-3940256099942544/2934735716';
    }
    return '';
  }

  /// Initialize AdMob on mobile platforms
  static Future<void> initialize() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await MobileAds.instance.initialize();
    }
  }
}
