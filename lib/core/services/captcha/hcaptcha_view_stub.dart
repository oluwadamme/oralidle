import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/hcaptcha_config.dart';

Widget buildHCaptchaPlatformView({
  required String siteKey,
  required ValueChanged<String> onToken,
  required ValueChanged<String?> onError,
  required VoidCallback onExpired,
}) {
  return _HCaptchaMobileView(
    siteKey: siteKey,
    onToken: onToken,
    onError: onError,
    onExpired: onExpired,
  );
}

class _HCaptchaMobileView extends StatefulWidget {
  const _HCaptchaMobileView({
    required this.siteKey,
    required this.onToken,
    required this.onError,
    required this.onExpired,
  });

  final String siteKey;
  final ValueChanged<String> onToken;
  final ValueChanged<String?> onError;
  final VoidCallback onExpired;

  @override
  State<_HCaptchaMobileView> createState() => _HCaptchaMobileViewState();
}

class _HCaptchaMobileViewState extends State<_HCaptchaMobileView> {
  WebViewController? _controller;
  bool _initFailed = false;

  @override
  void initState() {
    super.initState();
    try {
      if (WebViewPlatform.instance == null) {
        _initFailed = true;
        return;
      }
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..addJavaScriptChannel(
          'HCaptchaChannel',
          onMessageReceived: (JavaScriptMessage message) {
            try {
              final data = jsonDecode(message.message) as Map<String, dynamic>;
              log(data.toString());
              final type = data['type'] as String?;
              if (type == 'success') {
                final token = data['token'] as String;
                widget.onToken(token);
              } else if (type == 'expired') {
                widget.onExpired();
              } else if (type == 'error') {
                widget.onError(data['error']?.toString() ?? 'unknown');
              }
            } catch (e) {
              widget.onError(e.toString());
            }
          },
        )
        ..loadHtmlString(
          _generateHtml(widget.siteKey),
          // hCaptcha checks this hostname against the sitekey's registered
          // domains, so it has to be a domain you actually own — not
          // hcaptcha.com, which is registered to nobody's sitekey.
          baseUrl: HCaptchaConfig.verifyOrigin,
        );
    } catch (_) {
      _initFailed = true;
    }
  }

  String _generateHtml(String siteKey) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <script src="https://js.hcaptcha.com/1/api.js" async defer></script>
  <style>
    * {
      box-sizing: border-box;
    }
    body {
      margin: 0;
      padding: 0;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      background-color: transparent;
      overflow: hidden;
    }
  </style>
</head>
<body>
  <div class="h-captcha"
       data-sitekey="$siteKey"
       data-theme="dark"
       data-callback="onSuccess"
       data-expired-callback="onExpired"
       data-error-callback="onError">
  </div>
  <script>
    function onSuccess(token) {
      if (window.HCaptchaChannel) {
        window.HCaptchaChannel.postMessage(JSON.stringify({ type: 'success', token: token }));
      }
    }
    function onExpired() {
      if (window.HCaptchaChannel) {
        window.HCaptchaChannel.postMessage(JSON.stringify({ type: 'expired' }));
      }
    }
    function onError(error) {
      if (window.HCaptchaChannel) {
        window.HCaptchaChannel.postMessage(JSON.stringify({ type: 'error', error: error }));
      }
    }
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    if (_initFailed || _controller == null) {
      return const SizedBox.shrink();
    }
    return WebViewWidget(controller: _controller!);
  }
}
