import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:widget_overlay_outside/core/constants/app_constants.dart';
import 'package:widget_overlay_outside/router.dart';

/// Every route that reads `state.extra` is reachable as a plain URL on the web
/// build, because it uses path URLs behind an SPA rewrite. `extra` lives in
/// memory, so a refresh or a pasted link arrives without it — and a hard cast
/// like `state.extra as Topic` would throw on arrival.
///
/// These cover the cold-start case: no navigation history, no extra, just the
/// address someone typed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('oralidle_router_test');
    Hive.init(dir.path);
    await Hive.openBox<String>(AppConstants.hiveSessionsBox);
    await Hive.openBox<String>(AppConstants.hiveInterviewsBox);
    dotenv.testLoad(fileInput: '');
  });

  Future<GoRouter> pumpAt(WidgetTester tester, String location) async {
    // A desktop-sized surface so the wide layouts are the ones exercised.
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A fresh router per case; the app-wide `appRouter` is a singleton and
    // would carry location between tests.
    final router = createAppRouter();
    router.go(location);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    return router;
  }

  String locationOf(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  group('routes needing extra survive a cold deep link', () {
    final cases = <String, String>{
      AppRoutes.prepare: AppRoutes.topics,
      AppRoutes.record: AppRoutes.topics,
      AppRoutes.processing: AppRoutes.topics,
      AppRoutes.results: AppRoutes.history,
      AppRoutes.interviewSession: AppRoutes.interview,
      AppRoutes.interviewResults: AppRoutes.interview,
    };

    cases.forEach((deepLink, fallback) {
      testWidgets('$deepLink redirects to $fallback instead of throwing', (
        tester,
      ) async {
        final router = await pumpAt(tester, deepLink);

        expect(tester.takeException(), isNull, reason: 'must not throw');
        expect(locationOf(router), fallback);
      });
    });
  });

  group('routes that need nothing still load', () {
    for (final path in [
      AppRoutes.home,
      AppRoutes.topics,
      AppRoutes.history,
      AppRoutes.interview,
    ]) {
      testWidgets('$path loads directly', (tester) async {
        final router = await pumpAt(tester, path);

        expect(tester.takeException(), isNull);
        expect(locationOf(router), path);
      });
    }
  });

  testWidgets('an unknown path shows the not-found screen, not a crash', (
    tester,
  ) async {
    // The SPA rewrite serves index.html for every path, so a typo reaches the
    // router rather than a server 404.
    await pumpAt(tester, '/no/such/page');

    expect(tester.takeException(), isNull);
    expect(find.text('Page not found'), findsOneWidget);
  });
}
