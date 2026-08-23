import 'package:flutter/material.dart';

/// Non-web fallback stub for AdSense rendering.
Widget buildAdSenseWebAd({
  required String adClient,
  String? adSlot,
  double? maxWidth = 1200,
  double minHeight = 90,
  double maxHeight = 280,
}) {
  return const SizedBox.shrink();
}
