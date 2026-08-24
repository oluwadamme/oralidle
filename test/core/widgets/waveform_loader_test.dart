import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widget_overlay_outside/core/theme/app_theme.dart';
import 'package:widget_overlay_outside/core/widgets/waveform_loader.dart';

void main() {
  testWidgets('WaveformLoader renders hero waveform bars', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: Center(
            child: WaveformLoader.hero(
              height: 40,
              barCount: 16,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(WaveformLoader), findsOneWidget);

    // Advance animation
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(WaveformLoader), findsOneWidget);
  });

  testWidgets('WaveformLoader renders compact inline waveform', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: Center(
            child: WaveformLoader.compact(
              height: 16,
              barCount: 4,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(WaveformLoader), findsOneWidget);
  });
}
