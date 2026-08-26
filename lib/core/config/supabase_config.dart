import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Resolved the same way [AiEndpoint] resolves its own configuration: a
/// `--dart-define` first, then `.env` for local native development.
///
/// Unlike the Gemini key this one is public by design — it ships in
/// `main.dart.js`, and row-level security is what actually protects the data.
/// Every table in `supabase/migrations/` has RLS enabled; pointing this at a
/// project without it would turn the key into a full read/write credential.
///
/// The `sb_secret_…` key is the dangerous one and must never appear here or in
/// any `--dart-define`.
abstract final class SupabaseConfig {
  static const _defineUrl = String.fromEnvironment('SUPABASE_URL');
  static const _definePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const _defineAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get url => _resolve(_defineUrl, 'SUPABASE_URL');

  /// Prefers the current `sb_publishable_…` key, falling back to the legacy
  /// anon JWT so a project created before the key split still works.
  static String get publishableKey {
    final current = _resolve(
      _definePublishableKey,
      'SUPABASE_PUBLISHABLE_KEY',
    );
    if (current.isNotEmpty) return current;
    return _resolve(_defineAnonKey, 'SUPABASE_ANON_KEY');
  }

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static const audioBucket = 'recordings';

  static const signedUrlTtl = Duration(hours: 1);

  static String _resolve(String define, String envKey) {
    if (define.isNotEmpty) return define;
    if (dotenv.isInitialized) return dotenv.env[envKey] ?? '';
    return '';
  }
}
