import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:widget_overlay_outside/core/constants/app_constants.dart';
import 'package:widget_overlay_outside/core/services/sync/sync_outbox.dart';

import 'hive_harness.dart';

void main() {
  final harness = HiveHarness();
  late SyncOutbox outbox;

  setUp(() async {
    await harness.setUp();
    outbox = SyncOutbox();
  });

  tearDown(harness.tearDown);

  group('queue', () {
    test('drains oldest first regardless of insertion key order', () async {
      await outbox.enqueue(SyncEntity.session, 'zzz', '');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await outbox.enqueue(SyncEntity.interview, 'aaa', '');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await outbox.enqueue(SyncEntity.session, 'mmm', '');

      expect(outbox.pending().map((e) => e.id), ['zzz', 'aaa', 'mmm']);
    });

    test('re-queueing keeps the original position', () async {
      await outbox.enqueue(SyncEntity.session, 'first', '');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await outbox.enqueue(SyncEntity.session, 'second', '');

      await outbox.enqueue(SyncEntity.session, 'first', '');

      expect(outbox.pending().map((e) => e.id), ['first', 'second']);
    });

    test('kind is part of the identity', () async {
      await outbox.enqueue(SyncEntity.session, 'shared-id', '');
      await outbox.enqueue(SyncEntity.interview, 'shared-id', '');

      expect(outbox.pending(), hasLength(2));

      await outbox.resolve(SyncEntity.session, 'shared-id', '');
      expect(outbox.pending().single.kind, SyncEntity.interview);
    });

    test('resolve empties the queue', () async {
      await outbox.enqueue(SyncEntity.session, 'a', '');
      await outbox.resolve(SyncEntity.session, 'a', '');

      expect(outbox.isEmpty, isTrue);
    });
  });

  group('pending audio', () {
    test('round-trips bytes and metadata', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 250]);
      await outbox.stashAudio(
        'session-1',
        bytes,
        extension: 'wav',
        contentType: 'audio/wav',
      );

      final read = outbox.readAudio('session-1')!;
      expect(read.bytes, bytes);
      expect(read.extension, 'wav');
      expect(read.contentType, 'audio/wav');
    });

    test('returns null once cleared', () async {
      await outbox.stashAudio(
        'session-1',
        Uint8List(4),
        extension: 'wav',
        contentType: 'audio/wav',
      );
      await outbox.clearAudio('session-1');

      expect(outbox.readAudio('session-1'), isNull);
    });

    test('evicts oldest entries once over budget', () async {
      // Three stashes, each comfortably over half the budget, so the first two
      // cannot both survive alongside the third.
      final chunk = Uint8List(
        (AppConstants.pendingAudioBudgetBytes * 0.6) ~/ 1,
      );

      for (final id in ['oldest', 'middle', 'newest']) {
        await outbox.stashAudio(
          id,
          chunk,
          extension: 'wav',
          contentType: 'audio/wav',
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(outbox.readAudio('newest'), isNotNull);
      expect(outbox.readAudio('oldest'), isNull);
    });
  });
}
