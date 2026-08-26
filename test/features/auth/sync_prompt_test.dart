import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widget_overlay_outside/core/providers/core_providers.dart';
import 'package:widget_overlay_outside/core/services/app_prefs.dart';
import 'package:widget_overlay_outside/features/auth/providers/auth_provider.dart';

import '../../core/services/sync/fake_remote_store.dart';
import '../../core/services/sync/hive_harness.dart';

void main() {
  final harness = HiveHarness();
  late AppPrefs prefs;

  setUp(() async {
    await harness.setUp();
    prefs = AppPrefs();
  });

  tearDown(harness.tearDown);

  ProviderContainer withSync({bool available = true}) => ProviderContainer(
    overrides: [
      if (available)
        remoteStoreProvider.overrideWithValue(FakeRemoteStore())
      else
        remoteStoreProvider.overrideWithValue(null),
    ],
  );

  bool offer(ProviderContainer container, int sessions) =>
      container.read(shouldOfferSyncProvider(sessions));

  test('never offered when Supabase is not configured', () {
    final container = withSync(available: false);
    addTearDown(container.dispose);

    expect(offer(container, 10), isFalse);
  });

  test('stays quiet until the second session', () {
    final container = withSync();
    addTearDown(container.dispose);

    expect(offer(container, 0), isFalse);
    expect(offer(container, 1), isFalse);
    expect(offer(container, 2), isTrue);
  });

  test('the second offer waits for the fifth session', () async {
    final container = withSync();
    addTearDown(container.dispose);

    await prefs.recordSyncPromptShown();
    container.invalidate(shouldOfferSyncProvider);

    expect(offer(container, 3), isFalse);
    expect(offer(container, 4), isFalse);
    expect(offer(container, 5), isTrue);
  });

  test('goes silent for good after two showings', () async {
    final container = withSync();
    addTearDown(container.dispose);

    await prefs.recordSyncPromptShown();
    await prefs.recordSyncPromptShown();
    container.invalidate(shouldOfferSyncProvider);

    expect(offer(container, 50), isFalse);
  });

  test('dismissing after the second showing suppresses it', () async {
    final container = withSync();
    addTearDown(container.dispose);

    await prefs.recordSyncPromptShown();
    await prefs.recordSyncPromptShown();
    await prefs.dismissSyncPrompt();
    container.invalidate(shouldOfferSyncProvider);

    expect(offer(container, 100), isFalse);
  });

  group('AppPrefs', () {
    test('backfill is tracked per user', () async {
      expect(prefs.hasBackfilled('user-1'), isFalse);

      await prefs.markBackfilled('user-1');
      expect(prefs.hasBackfilled('user-1'), isTrue);
      expect(prefs.hasBackfilled('user-2'), isFalse);

      await prefs.markBackfilled('user-2');
      expect(prefs.hasBackfilled('user-1'), isTrue);
      expect(prefs.hasBackfilled('user-2'), isTrue);
    });
  });
}
