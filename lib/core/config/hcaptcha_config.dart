import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class HCaptchaConfig {
  static const _defineSiteKey = String.fromEnvironment('HCAPTCHA_SITE_KEY');

  static const testSiteKey = '10000000-ffff-ffff-ffff-000000000001';

  static String get siteKey {
    final configured = _resolve(_defineSiteKey, 'HCAPTCHA_SITE_KEY');
    if (configured.isNotEmpty) return configured;
    return testSiteKey;
  }

  static bool get isConfigured => siteKey.isNotEmpty;

  /// Whether the *test* sitekey is in play.
  static bool get isTestKey => siteKey == testSiteKey;

  /// The origin the native webview reports to hCaptcha.
  static String get verifyOrigin {
    const define = String.fromEnvironment('HCAPTCHA_ORIGIN');
    final configured = _resolve(define, 'HCAPTCHA_ORIGIN');
    return configured.isNotEmpty ? configured : 'https://oralidle.vercel.app';
  }

  static String _resolve(String define, String envKey) {
    if (define.isNotEmpty) return define;
    if (dotenv.isInitialized) return dotenv.env[envKey] ?? '';
    return '';
  }
}
