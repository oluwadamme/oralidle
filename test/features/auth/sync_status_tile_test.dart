import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:widget_overlay_outside/core/constants/app_constants.dart';
import 'package:widget_overlay_outside/core/providers/core_providers.dart';
import 'package:widget_overlay_outside/core/services/sync/sync_outbox.dart';
import 'package:widget_overlay_outside/features/auth/presentation/sync_status_tile.dart';
import 'package:widget_overlay_outside/features/auth/providers/auth_provider.dart';
import 'package:widget_overlay_outside/features/home/presentation/screens/home_screen.dart';

import '../../core/services/sync/fake_remote_store.dart';

/// The main sweep never lays this widget out: with Supabase unconfigured it
/// renders as an empty box. It now shares the home top bar with the level pill
/// and the greeting, which is exactly where a narrow screen at large text runs
/// out of room — so it needs its own sweep with the thing actually on screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('tile_sweep');
    Hive.init(dir.path);
    for (final box in [
      AppConstants.hiveSessionsBox,
      AppConstants.hiveInterviewsBox,
      AppConstants.hiveOutboxBox,
      AppConstants.hivePendingAudioBox,
      AppConstants.hivePrefsBox,
    ]) {
      await Hive.openBox<String>(box);
    }
    dotenv.testLoad(fileInput: '');
  });

  Widget host(Widget child, {double scale = 1.0}) => ProviderScope(
    overrides: [remoteStoreProvider.overrideWithValue(FakeRemoteStore())],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: child,
      ),
    ),
  );

  group('greeting name', () {
    test('falls back to Speaker with no linked account', () {
      expect(const AccountState().greetingName, 'Speaker');
      expect(
        const AccountState(displayName: '   ').greetingName,
        'Speaker',
      );
    });

    test('uses the first name only', () {
      expect(
        const AccountState(displayName: 'Damilola Adeniyi').greetingName,
        'Damilola',
      );
      expect(
        const AccountState(displayName: '  Ada   Lovelace ').greetingName,
        'Ada',
      );
    });
  });

  group('states', () {
    testWidgets('signed out offers Sign in', (tester) async {
      await tester.pumpWidget(host(const Scaffold(body: SyncStatusTile())));
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Sync session'), findsNothing);
    });

    testWidgets('hidden entirely when Supabase is unconfigured', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: SyncStatusTile())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsNothing);
      expect(find.text('Sync session'), findsNothing);
    });
  });

  group('home top bar lays out cleanly with the tile visible', () {
    for (final width in [390.0, 700.0, 1000.0, 1440.0]) {
      for (final scale in [1.0, 1.5]) {
        testWidgets('@ ${width.toInt()} x$scale', (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(host(const HomeScreen(), scale: scale));
          await tester.pumpAndSettle();

          expect(find.text('Sign in'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('outbox state decides whether a linked user sees it', (
    tester,
  ) async {
    // Nothing queued, so a synced account has nothing to act on.
    expect(SyncOutbox().isEmpty, isTrue);

    await tester.pumpWidget(host(const Scaffold(body: SyncStatusTile())));
    await tester.pumpAndSettle();

    // Anonymous still gets the sign-in affordance regardless of the queue.
    expect(find.text('Sign in'), findsOneWidget);
  });
}
