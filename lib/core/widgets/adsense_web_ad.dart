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

  @override
  void initState() {
    super.initState();
    _viewId =
        'adsense-${widget.adSlot ?? "auto"}-${DateTime.now().microsecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int id) {
      final ins = web.document.createElement('ins') as web.HTMLElement;
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

    // Safely trigger adsbygoogle.push AFTER Flutter Web attaches the platform view to the DOM
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          try {
            _jsEval(
                '(window.adsbygoogle = window.adsbygoogle || []).push({});');
          } catch (e) {
            debugPrint('AdSense push error: $e');
          }
        }
      });
    });
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
