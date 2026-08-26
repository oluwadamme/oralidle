import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widget_overlay_outside/core/constants/app_constants.dart';
import 'package:widget_overlay_outside/core/theme/app_theme.dart';
import 'package:widget_overlay_outside/core/widgets/app_button.dart';
import 'package:widget_overlay_outside/core/widgets/waveform_loader.dart';

/// WCAG relative luminance.
double _luminance(Color c) {
  double channel(double v) {
    final s = v / 255.0;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel((c.r * 255).roundToDouble()) +
      0.7152 * channel((c.g * 255).roundToDouble()) +
      0.0722 * channel((c.b * 255).roundToDouble());
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  Widget host(Widget child) =>
      MaterialApp(theme: AppTheme.dark, home: Scaffold(body: Center(child: child)));

  Color loaderColour(WidgetTester tester) =>
      tester.widget<WaveformLoader>(find.byType(WaveformLoader)).color!;

  group('the busy waveform is visible on the disabled fill', () {
    // Regression: `busy` renders the button disabled, so the fill drops to
    // raised2 — but the loader kept the primary label colour (onAccent),
    // meant for bright accent. 1.15:1, invisible.
    testWidgets('primary', (tester) async {
      await tester.pumpWidget(
        host(AppButton.primary(label: 'Send code', busy: true, onPressed: () {})),
      );

      final colour = loaderColour(tester);
      expect(colour, isNot(AppColors.onAccent));
      expect(
        _contrast(colour, AppColors.raised2),
        greaterThanOrEqualTo(3.0),
        reason: 'must clear 3:1 against the disabled fill (WCAG 1.4.11)',
      );
    });

    testWidgets('secondary', (tester) async {
      await tester.pumpWidget(
        host(AppButton.secondary(label: 'Sync', busy: true, onPressed: () {})),
      );

      expect(
        _contrast(loaderColour(tester), AppColors.raised2),
        greaterThanOrEqualTo(3.0),
      );
    });
  });

  testWidgets('the old pairing really was invisible', (tester) async {
    // Pins the arithmetic behind the fix, so nobody "restores" onAccent here.
    expect(_contrast(AppColors.onAccent, AppColors.raised2), lessThan(1.3));
  });

  testWidgets('a busy button cannot be pressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(AppButton.primary(label: 'Send code', busy: true, onPressed: () => taps++)),
    );

    await tester.tap(find.byType(AppButton), warnIfMissed: false);
    await tester.pump();

    expect(taps, 0);
    expect(find.text('Send code'), findsOneWidget); // kept for layout stability
  });
}
