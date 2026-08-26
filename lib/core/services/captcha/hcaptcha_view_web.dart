import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// hCaptcha rendered into the host page's own DOM.
///
/// Deliberately **not** inside a `srcdoc` iframe. That document's URL is
/// `about:srcdoc`, so `location.hostname` is empty, and hCaptcha validates the
/// requesting hostname against the domains registered for the sitekey — with
/// nothing to match it fails every time. The test sitekey accepts any hostname,
/// which is why the iframe approach appeared to work right up until a real key
/// was configured.
///
/// hCaptcha builds its own sandboxed iframes internally, so wrapping it in
/// another buys nothing.
Widget buildHCaptchaPlatformView({
  required String siteKey,
  required ValueChanged<String> onToken,
  required ValueChanged<String?> onError,
  required VoidCallback onExpired,
}) {
  return _HCaptchaWebWidget(
    siteKey: siteKey,
    onToken: onToken,
    onError: onError,
    onExpired: onExpired,
  );
}

@JS('hcaptcha')
external JSObject? get _hcaptchaApi;

const _scriptId = 'hcaptcha-api';
const _scriptSrc = 'https://js.hcaptcha.com/1/api.js?render=explicit';

/// Loads the hCaptcha script once per page and completes when the global is
/// ready. Repeat challenges reuse it.
Future<void> _ensureScriptLoaded() async {
  if (_hcaptchaApi != null) return;

  final existing = web.document.getElementById(_scriptId);
  if (existing == null) {
    final script = web.document.createElement('script') as web.HTMLScriptElement
      ..id = _scriptId
      ..src = _scriptSrc
      ..async = true
      ..defer = true;
    web.document.head!.append(script);
  }

  // The load event alone is not enough — `hcaptcha` is defined slightly after
  // it on some builds, so wait for the global itself.
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (_hcaptchaApi == null) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('hCaptcha script did not load');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

class _HCaptchaWebWidget extends StatefulWidget {
  const _HCaptchaWebWidget({
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
  State<_HCaptchaWebWidget> createState() => _HCaptchaWebWidgetState();
}

class _HCaptchaWebWidgetState extends State<_HCaptchaWebWidget> {
  late final String _viewId;
  late final web.HTMLDivElement _host;

  @override
  void initState() {
    super.initState();
    _viewId = 'hcaptcha-${DateTime.now().microsecondsSinceEpoch}';
    _host = web.document.createElement('div') as web.HTMLDivElement
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center';

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int _) => _host);
    WidgetsBinding.instance.addPostFrameCallback((_) => _render());
  }

  Future<void> _render() async {
    try {
      await _ensureScriptLoaded();
      if (!mounted) return;

      // HtmlElementView attaches the host during paint; rendering into a
      // detached node silently produces nothing.
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (!_host.isConnected) {
        if (DateTime.now().isAfter(deadline)) {
          widget.onError('view-not-attached');
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 16));
        if (!mounted) return;
      }

      final params = JSObject()
        ..setProperty('sitekey'.toJS, widget.siteKey.toJS)
        ..setProperty('theme'.toJS, 'dark'.toJS)
        ..setProperty(
          'callback'.toJS,
          ((JSString token) => widget.onToken(token.toDart)).toJS,
        )
        ..setProperty(
          'error-callback'.toJS,
          ((JSAny? error) =>
                  widget.onError(error?.dartify()?.toString() ?? 'unknown'))
              .toJS,
        )
        ..setProperty(
          'expired-callback'.toJS,
          (() => widget.onExpired()).toJS,
        );

      _hcaptchaApi!.callMethod<JSAny?>('render'.toJS, _host, params);
    } catch (e) {
      if (mounted) widget.onError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewId);
}
