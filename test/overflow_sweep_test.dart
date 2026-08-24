import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:widget_overlay_outside/core/constants/app_constants.dart';
import 'package:widget_overlay_outside/features/home/presentation/screens/home_screen.dart';
import 'package:widget_overlay_outside/features/interview/presentation/screens/interview_home_screen.dart';
import 'package:widget_overlay_outside/features/topic_selection/presentation/screens/topic_selection_screen.dart';
import 'package:widget_overlay_outside/features/history/presentation/screens/history_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('sweep');
    Hive.init(dir.path);
    await Hive.openBox<String>(AppConstants.hiveSessionsBox);
    await Hive.openBox<String>(AppConstants.hiveInterviewsBox);
    dotenv.testLoad(fileInput: '');
  });

  final screens = <String, Widget>{
    'home': const HomeScreen(),
    'topics': const TopicSelectionScreen(),
    'history': const HistoryScreen(),
    'interview': const InterviewHomeScreen(),
  };

  // The second axis matters as much as the first: every text metric in the app
  // changed in the v2 migration, and Dynamic Type is where that shows.
  for (final entry in screens.entries) {
    for (final w in [390.0, 700.0, 1000.0, 1440.0]) {
      for (final scale in [1.0, 1.5]) {
        testWidgets('${entry.key} @ ${w.toInt()} x$scale lays out cleanly', (
          tester,
        ) async {
          tester.view.physicalSize = Size(w, 1000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: entry.value,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
