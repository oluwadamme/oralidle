import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

@JS('eval')
external void _jsEval(String code);

/// Responsive Web implementation for AdSense ad unit injection using package:web.
Widget buildAdSenseWebAd({
  required String adClient,
  String? adSlot,
  double? maxWidth = 1200,
  double minHeight = 90,
  double maxHeight = 280,
}) {
  return _AdSenseWebWidget(
    adClient: adClient,
    adSlot: adSlot,
    maxWidth: maxWidth,
    minHeight: minHeight,
    maxHeight: maxHeight,
  );
}

class _AdSenseWebWidget extends StatefulWidget {
  final String adClient;
  final String? adSlot;
  final double? maxWidth;
  final double minHeight;
  final double maxHeight;

  const _AdSenseWebWidget({
    required this.adClient,
    this.adSlot,
    this.maxWidth,
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  State<_AdSenseWebWidget> createState() => _AdSenseWebWidgetState();
}

class _AdSenseWebWidgetState extends State<_AdSenseWebWidget> {
  late final String _viewId;
  bool _pushed = false;

  @override
  void initState() {
    super.initState();
    _viewId =
        'adsense-${widget.adSlot ?? "auto"}-${DateTime.now().microsecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int id) {
      final ins = web.document.createElement('ins') as web.HTMLElement;
      ins.id = _viewId;
      ins.className = 'adsbygoogle';
      ins.style.display = 'block';
      ins.style.width = '100%';
      ins.style.height = '100%';
      ins.setAttribute('data-ad-client', widget.adClient);
      ins.setAttribute('data-ad-format', 'auto');
      ins.setAttribute('data-full-width-responsive', 'true');

      if (widget.adSlot != null && widget.adSlot!.isNotEmpty) {
        ins.setAttribute('data-ad-slot', widget.adSlot!);
      }

      final div = web.document.createElement('div') as web.HTMLDivElement;
      div.style.width = '100%';
      div.style.height = '100%';
      div.append(ins);

      return div;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryPushAd(attempts: 0);
    });
  }

  void _tryPushAd({int attempts = 0}) {
    if (!mounted || _pushed) return;

    try {
      final el = web.document.getElementById(_viewId);
      if (el != null) {
        final status =
            el.getAttribute('data-adsbygoogle-status') ??
            el.getAttribute('data-ad-status');
        if (status != null && status.isNotEmpty) {
          _pushed = true;
          return;
        }

        try {
          _jsEval('(window.adsbygoogle = window.adsbygoogle || []).push({});');
        } catch (e) {
          debugPrint('AdSense push caught: $e');
        }
        _pushed = true;
        return;
      }
    } catch (e) {
      debugPrint('AdSense element check error: $e');
    }

    // If element is not in DOM yet, retry after a delay
    if (attempts < 10) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && !_pushed) {
          _tryPushAd(attempts: attempts + 1);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: widget.maxWidth ?? double.infinity,
        minHeight: widget.minHeight,
        maxHeight: widget.maxHeight,
      ),
      width: double.infinity,
      child: HtmlElementView(viewType: _viewId),
    );
  }
}
