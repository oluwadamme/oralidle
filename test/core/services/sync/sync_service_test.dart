import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:widget_overlay_outside/core/services/app_prefs.dart';
import 'package:widget_overlay_outside/core/services/storage_scope.dart';
import 'package:widget_overlay_outside/core/services/storage_service.dart';
import 'package:widget_overlay_outside/core/services/sync/sync_outbox.dart';
import 'package:widget_overlay_outside/core/services/sync/sync_service.dart';
import 'package:widget_overlay_outside/features/interview/data/repositories/interview_repository_impl.dart';

import 'fake_remote_store.dart';
import 'hive_harness.dart';

void main() {
  final harness = HiveHarness();

  late FakeRemoteStore remote;
  late SyncOutbox outbox;
  late StorageService storage;
  late InterviewRepositoryImpl interviews;
  late SyncService sync;
  late StorageScope scope;

  setUp(() async {
    await harness.setUp();
    remote = FakeRemoteStore();
    outbox = SyncOutbox();
    scope = StorageScope();
    storage = StorageService(scope, outbox);
    interviews = InterviewRepositoryImpl(scope, outbox);
    sync = SyncService(
      remote: remote,
      outbox: outbox,
      storage: storage,
      interviews: interviews,
      prefs: AppPrefs(),
      scope: scope,
    );
  });

  tearDown(() async {
    await sync.dispose();
    await harness.tearDown();
  });

  group('push', () {
    test('sends a locally saved session and clears the queue', () async {
      await storage.saveSession(fakeSession(id: 'a'));

      await sync.syncNow();

      expect(remote.sessions.keys, ['a']);
      expect(outbox.isEmpty, isTrue);
    });

    test('sends a locally saved interview', () async {
      await interviews.save(fakeInterview(id: 'i1'));

      await sync.syncNow();

      expect(remote.interviews.keys, ['i1']);
    });

    test('a queued id with no local row is a tombstone', () async {
      await storage.saveSession(fakeSession(id: 'a'));
      await sync.syncNow();

      await storage.deleteSession('a');
      await sync.syncNow();

      expect(remote.deletedSessionIds, ['a']);
      expect(remote.sessions, isEmpty);
    });

    test('a failed push stays queued for the next drain', () async {
      await storage.saveSession(fakeSession(id: 'a'));
      remote.failWrites = true;

      await sync.syncNow();
      expect(remote.sessions, isEmpty);
      expect(outbox.pending().map((e) => e.id), ['a']);

      remote.failWrites = false;
      await sync.syncNow();
      expect(remote.sessions.keys, ['a']);
    });

    test('does nothing while signed out', () async {
      remote.currentUserId = null;
      await storage.saveSession(fakeSession(id: 'a'));

      await sync.syncNow();

      expect(remote.sessions, isEmpty);
      expect(outbox.pending(), hasLength(1));
    });
  });

  group('stashed audio', () {
    test('uploads, records the object path, and clears the stash', () async {
      await storage.saveSession(fakeSession(id: 'a'));
      await outbox.stashAudio(
        'a',
        Uint8List.fromList([9, 9, 9]),
        extension: 'wav',
        contentType: 'audio/wav',
      );

      await sync.syncNow();

      expect(remote.uploads.keys, ['user-1/a.wav']);
      expect(remote.sessions['a']!.audioObjectPath, 'user-1/a.wav');
      expect(storage.getSession('a')!.audioObjectPath, 'user-1/a.wav');
      expect(outbox.readAudio('a'), isNull);
    });

    test('a failed upload leaves the stash intact', () async {
      await storage.saveSession(fakeSession(id: 'a'));
      await outbox.stashAudio(
        'a',
        Uint8List.fromList([9]),
        extension: 'wav',
        contentType: 'audio/wav',
      );
      remote.failWrites = true;

      await sync.syncNow();

      expect(outbox.readAudio('a'), isNotNull);
      expect(outbox.pending().map((e) => e.id), ['a']);
    });
  });

  group('pull', () {
    test('caches a session that only exists remotely', () async {
      remote.seedSession(
        fakeSession(
          id: 'remote-only',
          audioObjectPath: 'user-1/remote-only.wav',
        ),
      );

      await sync.syncNow();

      final local = storage.getSession('remote-only')!;
      expect(local.audioObjectPath, 'user-1/remote-only.wav');
      expect(local.audioPath, isNull);
    });

    test('fills in the object path without losing the local audio', () async {
      await storage.saveSession(
        fakeSession(id: 'a', audioPath: '/device/a.wav'),
      );
      await sync.syncNow();

      remote.seedSession(
        fakeSession(id: 'a', audioObjectPath: 'user-1/a.wav'),
      );
      await sync.syncNow();

      final local = storage.getSession('a')!;
      expect(local.audioPath, '/device/a.wav');
      expect(local.audioObjectPath, 'user-1/a.wav');
    });

    test('does not duplicate rows across repeated syncs', () async {
      remote.seedSession(fakeSession(id: 'a'));
      remote.seedInterview(fakeInterview(id: 'i1'));

      await sync.syncNow();
      await sync.syncNow();

      expect(storage.getSessions(), hasLength(1));
      expect(interviews.getAll(), hasLength(1));
    });

    test('a pulled row is not pushed straight back', () async {
      remote.seedSession(fakeSession(id: 'a'));

      await sync.syncNow();

      expect(outbox.isEmpty, isTrue);
    });
  });

  group('deletion', () {
    test('a local delete becomes a tombstone, not a row removal', () async {
      await storage.saveSession(fakeSession(id: 'a'));
      await sync.syncNow();

      await storage.deleteSession('a');
      await sync.syncNow();

      expect(remote.sessionTombstones.keys, ['a']);
      expect(remote.sessions.containsKey('a'), isFalse);
    });

    test('a deletion made elsewhere is applied on this device', () async {
      // This device pulled the row down, then another device deleted it.
      remote.seedSession(fakeSession(id: 'a'));
      await sync.syncNow();
      expect(storage.getSession('a'), isNotNull);

      remote.sessionTombstones['a'] = 'user-1';
      remote.sessions.remove('a');
      await sync.syncNow();

      expect(storage.getSession('a'), isNull);
    });

    test('a deleted row is not resurrected by this device', () async {
      // The bug soft delete exists to fix: pull only ever added, so the row
      // survived here and the next push put it back on the server.
      remote.seedSession(fakeSession(id: 'a'));
      await sync.syncNow();

      remote.sessionTombstones['a'] = 'user-1';
      remote.sessions.remove('a');

      await sync.syncNow();
      await sync.syncNow();

      expect(storage.getSession('a'), isNull);
      expect(remote.sessions.containsKey('a'), isFalse);
    });

    test('applying a tombstone queues no second delete', () async {
      remote.seedSession(fakeSession(id: 'a'));
      await sync.syncNow();
      remote.sessionTombstones['a'] = 'user-1';
      remote.sessions.remove('a');

      await sync.syncNow();

      expect(outbox.isEmpty, isTrue);
      expect(remote.deletedSessionIds, isEmpty);
    });

    test('interviews travel the same way', () async {
      remote.seedInterview(fakeInterview(id: 'i1'));
      await sync.syncNow();
      expect(interviews.getAll(), hasLength(1));

      remote.interviewTombstones['i1'] = 'user-1';
      remote.interviews.remove('i1');
      await sync.syncNow();

      expect(interviews.getAll(), isEmpty);
    });

    test("one account's tombstones never touch another's rows", () async {
      remote.seedSession(fakeSession(id: 'shared-id'), userId: 'alice');
      remote.sessionTombstones['shared-id'] = 'alice';

      remote.currentUserId = 'bob';
      scope.value = 'bob';
      await storage.saveSession(fakeSession(id: 'shared-id'));
      await sync.syncNow();

      expect(storage.getSession('shared-id'), isNotNull);
    });
  });

  group('account switching', () {
    // Anonymous first, then link. `scope` follows what AuthNotifier sets: ''
    // while anonymous, the uid once an email is verified.
    Future<void> link(String uid) async {
      remote.currentUserId = uid;
      scope.value = uid;
      await sync.syncNow();
    }

    test('a pre-existing cache reaches the server on first sign-in', () async {
      // The upgrade case: rows written before any of this shipped, so bare
      // keys, no outbox entries, and no account at all.
      final beforeUpgrade = StorageService(scope);
      await beforeUpgrade.saveSession(fakeSession(id: 'old-1'));
      await beforeUpgrade.saveSession(fakeSession(id: 'old-2'));

      remote.currentUserId = null;
      await sync.syncNow();
      expect(remote.sessions, isEmpty, reason: 'no account, nothing to push');

      // They tap Sign in and verify a code.
      await link('user-9');

      expect(remote.sessions.keys, containsAll(['old-1', 'old-2']));
      expect(storage.getSessions(scope: 'user-9'), hasLength(2));
      expect(
        storage.getSessions(scope: StorageScope.anonymous),
        isEmpty,
        reason: 'claimed rows must not stay claimable by the next account',
      );
      expect(
        outbox.isEmpty,
        isTrue,
        reason: 'an empty queue is what marks the cache as synced',
      );
    });

    test('linking a new email keeps the ids — nothing is re-keyed', () async {
      // Case A: updateUser attaches the address to the *same* anonymous user,
      // so the uid never changes and the server rows are already owned.
      await storage.saveSession(fakeSession(id: 'recorded-anonymously'));
      await sync.syncNow();

      await link('user-1');

      expect(storage.getSessions().single.id, 'recorded-anonymously');
      expect(remote.sessions.keys, ['recorded-anonymously']);
      expect(remote.sessions, hasLength(1), reason: 'must not duplicate');
    });

    test('claiming empties the anonymous namespace', () async {
      await storage.saveSession(fakeSession(id: 'before-linking'));
      await sync.syncNow();

      await link('user-2');

      expect(storage.getSessions(scope: StorageScope.anonymous), isEmpty);
      expect(storage.getSessions(scope: 'user-2'), hasLength(1));
    });

    test('a second person cannot claim what the first already took', () async {
      await storage.saveSession(fakeSession(id: 'before-linking'));
      await sync.syncNow();
      await link('user-2');
      final claimed = storage.getSessions(scope: 'user-2').single.id;

      // Someone else links on the same device.
      await link('user-3');

      expect(storage.getSessions(scope: 'user-3'), isEmpty);
      expect(
        remote.sessionOwners.values.where((owner) => owner == 'user-3'),
        isEmpty,
        reason: 'nothing should have been pushed under the second account',
      );
      expect(remote.sessionOwners[claimed], 'user-2');
    });

    test('one account never re-uploads another account rows', () async {
      // Alice signs in and her history is pulled onto this device.
      remote.seedSession(fakeSession(id: 'alice-1'), userId: 'alice');
      remote.seedSession(fakeSession(id: 'alice-2'), userId: 'alice');
      await link('alice');
      expect(storage.getSessions(scope: 'alice'), hasLength(2));

      // Bob signs in on the same device.
      await link('bob');

      expect(storage.getSessions(scope: 'bob'), isEmpty);
      expect(
        remote.sessionOwners.values.where((owner) => owner == 'bob'),
        isEmpty,
        reason: "Alice's rows must not be copied into Bob's account",
      );
      expect(remote.sessionOwners['alice-1'], 'alice');
      expect(remote.sessionOwners['alice-2'], 'alice');
    });

    test('signing back in restores that account rows, not the others', () async {
      remote.seedSession(fakeSession(id: 'alice-1'), userId: 'alice');
      await link('alice');
      await link('bob');
      expect(storage.getSessions(), isEmpty);

      await link('alice');

      expect(storage.getSessions().single.id, 'alice-1');
    });

    test('a queued push waits for its own account to return', () async {
      await link('alice');
      await storage.saveSession(fakeSession(id: 'alice-pending'));
      remote.failWrites = true;
      await sync.syncNow();
      expect(outbox.pending(), hasLength(1));

      // Bob signs in while Alice's write is still queued. It must not be read
      // as a tombstone and delete her row off the server.
      remote.failWrites = false;
      await link('bob');

      expect(remote.deletedSessionIds, isEmpty);
      expect(outbox.pending(scope: 'alice'), hasLength(1));

      await link('alice');
      expect(remote.sessions.keys, contains('alice-pending'));
    });
  });

  group('backfill', () {
    test('queues rows that pre-date the first sign-in', () async {
      // Written through a storage service with no outbox, standing in for data
      // saved before this feature shipped.
      await StorageService(scope).saveSession(fakeSession(id: 'legacy'));
      await InterviewRepositoryImpl(scope).save(fakeInterview(id: 'legacy-i'));
      expect(outbox.isEmpty, isTrue);

      await sync.syncNow();

      expect(remote.sessions.keys, ['legacy']);
      expect(remote.interviews.keys, ['legacy-i']);
    });

    test('re-keys rows already pushed under an abandoned uid', () async {
      // Device B: record while anonymous, so the row lands on the server under
      // the throwaway uid.
      await storage.saveSession(fakeSession(id: 'recorded-before-linking'));
      await sync.syncNow();
      expect(remote.sessions['recorded-before-linking']!.id, isNotNull);

      // Linking an email that already has an account switches uid.
      remote.currentUserId = 'user-2';
      await sync.syncNow();

      // The row survives under a fresh id rather than colliding on the primary
      // key against a row RLS will not let this user touch.
      expect(storage.getSessions(), hasLength(1));
      expect(storage.getSessions().single.id, isNot('recorded-before-linking'));
      expect(remote.sessions, hasLength(2));
      expect(outbox.isEmpty, isTrue);
    });

    test('re-keyed audio is re-uploaded under the new account', () async {
      await storage.saveSession(
        fakeSession(
          id: 'a',
          audioPath: 'data:audio/wav;base64,${base64Encode([1, 2, 3])}',
        ),
      );
      await outbox.stashAudio(
        'a',
        Uint8List.fromList([1, 2, 3]),
        extension: 'wav',
        contentType: 'audio/wav',
      );
      await sync.syncNow();
      expect(remote.uploads.keys, ['user-1/a.wav']);

      remote.currentUserId = 'user-2';
      await sync.syncNow();

      final rekeyedId = storage.getSessions().single.id;
      expect(remote.uploads.keys, contains('user-2/$rekeyedId.wav'));
      expect(storage.getSessions().single.audioObjectPath, isNotNull);
    });

    test('re-keys interviews too', () async {
      await interviews.save(fakeInterview(id: 'i1'));
      await sync.syncNow();

      remote.currentUserId = 'user-2';
      await sync.syncNow();

      expect(interviews.getAll(), hasLength(1));
      expect(interviews.getAll().single.id, isNot('i1'));
      expect(remote.interviews, hasLength(2));
    });

    test('does not re-queue the same rows for the same user', () async {
      await StorageService(scope).saveSession(fakeSession(id: 'legacy'));
      await sync.syncNow();
      expect(remote.sessions.keys, ['legacy']);

      remote.sessions.clear();
      remote.sessionOwners.clear();

      await sync.syncNow();

      expect(remote.sessions, isEmpty);
    });
  });
}
