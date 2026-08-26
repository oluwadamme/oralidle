import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration for hCaptcha integration.
///
/// Resolves the sitekey from `--dart-define` first, then `.env`, falling back
/// to the official hCaptcha test sitekey during development or testing.
abstract final class HCaptchaConfig {
  static const _defineSiteKey = String.fromEnvironment('HCAPTCHA_SITE_KEY');

  /// Official hCaptcha test sitekey that always returns a valid pass token.
  static const testSiteKey = '10000000-ffff-ffff-ffff-000000000001';

  /// Resolves the active sitekey for captcha verification.
  static String get siteKey {
    final configured = _resolve(_defineSiteKey, 'HCAPTCHA_SITE_KEY');
    if (configured.isNotEmpty) return configured;
    return testSiteKey;
  }

  /// Whether custom or test hCaptcha is configured.
  static bool get isConfigured => siteKey.isNotEmpty;

  /// Whether the *test* sitekey is in play.
  ///
  /// It accepts any hostname and always returns a passing token, so it hides
  /// exactly the domain-registration mistakes that break the real one — and
  /// Supabase rejects its tokens against a real secret.
  static bool get isTestKey => siteKey == testSiteKey;

  /// The origin the native webview reports to hCaptcha.
  ///
  /// hCaptcha checks it against the domains registered for the sitekey, so it
  /// must be one you own. There is no meaningful default: a wrong value fails
  /// identically to no value, and the test key ignores it either way.
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
