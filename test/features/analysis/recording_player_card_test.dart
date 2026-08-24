import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widget_overlay_outside/core/theme/app_theme.dart';
import 'package:widget_overlay_outside/features/analysis/presentation/widgets/recording_player_card.dart';

void main() {
  testWidgets('RecordingPlayerCard renders title and play button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: RecordingPlayerCard(
            audioPath: 'data:audio/wav;base64,UklGRgAAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQAAAAA=',
            fallbackDurationSeconds: 65,
          ),
        ),
      ),
    );

    // Initial pump
    await tester.pump();

    expect(find.text('YOUR RECORDING'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });
}
