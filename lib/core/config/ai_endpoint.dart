import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class AiEndpoint {
  static const proxyBase = String.fromEnvironment('API_PROXY_BASE');

  static const _googleDirect =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';
  static const _proxyPath = '/api/gemini';

  static String get localApiKey {
    const defineKey = String.fromEnvironment('GEMINI_API_KEY');
    if (defineKey.isNotEmpty) return defineKey;
    if (dotenv.isInitialized) {
      return dotenv.env['GEMINI_API_KEY'] ?? '';
    }
    return '';
  }

  static bool get isLocalWeb {
    if (!kIsWeb) return false;
    final host = Uri.base.host.toLowerCase();
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '0.0.0.0' ||
        host == '::1';
  }

  static bool get usesProxy {
    if (proxyBase.isNotEmpty) return true;
    if (isLocalWeb && localApiKey.isNotEmpty) return false;
    return kIsWeb;
  }

  /// Whether callers should attach the `x-goog-api-key` header.
  static bool get sendsApiKey => !usesProxy;

  static bool get requiresApiKey =>
      sendsApiKey || (isLocalWeb && proxyBase.isEmpty);

  /// Where to POST a `generateContent` request.
  static Uri get generateContent {
    if (usesProxy) {
      if (proxyBase.isNotEmpty) {
        return Uri.parse(
          '${proxyBase.replaceAll(RegExp(r'/+$'), '')}$_proxyPath',
        );
      }
      if (kIsWeb) return Uri.base.resolve(_proxyPath);
    }
    return Uri.parse(_googleDirect);
  }

  /// Headers for a `generateContent` request, given the configured [apiKey].
  static Map<String, String> headers(String apiKey) {
    final key = apiKey.isNotEmpty ? apiKey : localApiKey;
    return {
      'Content-Type': 'application/json',
      if (sendsApiKey) 'x-goog-api-key': key,
    };
  }
}
