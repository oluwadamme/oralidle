import 'package:flutter/foundation.dart' show kIsWeb;

/// Decides where Gemini requests go, and whether an API key travels with them.
///
/// A Flutter web build is a directory of static files served to the browser,
/// so anything it carries is readable by anyone who loads the page — including
/// a bundled `.env`. The key therefore lives on the server, behind
/// `api/gemini.js`, and the web app talks to that instead of Google.
///
/// Native builds keep the direct path by default so development works without
/// the proxy running, and can be pointed at a deployed proxy by passing
/// `--dart-define=API_PROXY_BASE=https://your-app.vercel.app` at build time.
abstract final class AiEndpoint {
  /// Set at build time for native builds that should use the proxy:
  /// `flutter build apk --dart-define=API_PROXY_BASE=https://your-app.vercel.app`
  static const proxyBase = String.fromEnvironment('API_PROXY_BASE');

  static const _googleDirect =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  /// Path the proxy is served from. Same value in `vercel.json`.
  static const _proxyPath = '/api/gemini';

  /// True when requests go through our own server rather than straight to
  /// Google — which is exactly when the client holds no API key.
  static bool get usesProxy => kIsWeb || proxyBase.isNotEmpty;

  /// Whether callers should attach the `x-goog-api-key` header.
  ///
  /// Only on the direct path: sending it to our own proxy would put the key
  /// back in the browser, defeating the point.
  static bool get sendsApiKey => !usesProxy;

  /// Whether a missing `GEMINI_API_KEY` should be treated as a fatal
  /// misconfiguration. On the proxy path the client is not supposed to have
  /// one.
  static bool get requiresApiKey => sendsApiKey;

  /// Where to POST a `generateContent` request.
  static Uri get generateContent {
    // Same-origin on web: resolving against the current document means
    // preview deployments work on their own URLs with nothing hardcoded.
    if (kIsWeb) return Uri.base.resolve(_proxyPath);
    if (proxyBase.isNotEmpty) {
      return Uri.parse(
        '${proxyBase.replaceAll(RegExp(r'/+$'), '')}$_proxyPath',
      );
    }
    return Uri.parse(_googleDirect);
  }

  /// Headers for a `generateContent` request, given the configured [apiKey].
  static Map<String, String> headers(String apiKey) => {
    'Content-Type': 'application/json',
    // Key goes in a header, never the URL, to keep it out of proxy logs,
    // crash reporters and browser network panels.
    if (sendsApiKey) 'x-goog-api-key': apiKey,
  };
}
