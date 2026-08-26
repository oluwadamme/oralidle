import 'dart:async';
import 'dart:developer' show log;

import 'package:uuid/uuid.dart';

import '../../../features/interview/data/repositories/interview_repository.dart';
import '../../constants/app_constants.dart';
import '../app_prefs.dart';
import '../storage_scope.dart';
import '../storage_service.dart';
import '../supabase/remote_store.dart';
import 'sync_outbox.dart';

/// Reconciles the local Hive mirror with Supabase.
///
/// Push runs before pull so a delete made offline is not undone by the row
/// coming straight back down.
///
/// Pull fetches the full row set rather than tracking a cursor. A session row
/// is a few KB and a heavy user has hundreds, so the payload stays around a
/// megabyte — cheap enough that it is not worth the correctness risk of cursor
/// bookkeeping against rows written from two devices.
class SyncService {
  SyncService({
    required this.remote,
    required this.outbox,
    required this.storage,
    required this.interviews,
    required this.prefs,
    required this.scope,
  });

  final RemoteStore remote;
  final SyncOutbox outbox;
  final StorageService storage;
  final InterviewRepository interviews;
  final AppPrefs prefs;
  final StorageScope scope;

  bool _running = false;
  bool _rerunRequested = false;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get status => _statusController.stream;

  /// Called after a sync changes local rows, so the history notifiers reload
  /// rather than serving the list they read at construction.
  void Function()? onLocalDataChanged;

  Future<void> syncNow() async {
    final userId = remote.currentUserId;
    if (userId == null) return;
    if (_running) {
      _rerunRequested = true;
      return;
    }

    _running = true;
    _emit(SyncStatus.syncing);
    var changed = false;
    try {
      final scope = this.scope.value;
      changed = await _claimAnonymousData(scope, userId);
      changed = await _rekeyReownedRows(scope, userId) || changed;
      await backfillIfNeeded(scope, userId);
      await _push(scope, userId);
      changed = await _pull() || changed;
      _emit(SyncStatus.idle);
    } catch (e) {
      log('SyncService: sync failed: $e');
      _emit(SyncStatus.failed);
    } finally {
      _running = false;
      if (changed) onLocalDataChanged?.call();
    }

    if (_rerunRequested) {
      _rerunRequested = false;
      await syncNow();
    }
  }

  /// Hands anything recorded while anonymous to the account that just linked.
  ///
  /// A move, not a copy: whatever stays behind in the anonymous namespace would
  /// be claimed all over again by the next person to link on this device.
  Future<bool> _claimAnonymousData(String scope, String userId) async {
    if (scope == StorageScope.anonymous) return false;

    final orphanSessions = storage.getSessions(
      scope: StorageScope.anonymous,
    );
    final orphanInterviews = interviews.getAll(
      scope: StorageScope.anonymous,
    );
    if (orphanSessions.isEmpty && orphanInterviews.isEmpty) return false;

    final anonymousOwner = prefs.lastSyncedUserIdFor(StorageScope.anonymous);
    final needsRekey = anonymousOwner != null && anonymousOwner != userId;

    for (final session in orphanSessions) {
      final audio = needsRekey ? await storage.readLocalAudio(session) : null;
      final claimed = needsRekey
          ? session.rekeyed(const Uuid().v4())
          : session;
      await storage.claimFromAnonymous(session.id, claimed, scope);
      if (audio != null &&
          audio.bytes.lengthInBytes <= AppConstants.maxUploadBytes) {
        await outbox.stashAudio(
          claimed.id,
          audio.bytes,
          extension: audio.extension,
          contentType: audio.contentType,
        );
      }
    }

    for (final interview in orphanInterviews) {
      final claimed = needsRekey
          ? interview.rekeyed(const Uuid().v4())
          : interview;
      await interviews.claimFromAnonymous(interview.id, claimed, scope);
    }

    return true;
  }

  /// Re-keys a namespace whose rows were pushed under a different uid than the
  /// one now signed in. Only reachable for the anonymous namespace, whose uid
  /// is reissued whenever a fresh anonymous session is created.
  Future<bool> _rekeyReownedRows(String scope, String userId) async {
    final previous = prefs.lastSyncedUserIdFor(scope);
    if (previous == null) {
      await prefs.setLastSyncedUserIdFor(scope, userId);
      return false;
    }
    if (previous == userId) return false;

    for (final session in storage.getSessions(scope: scope)) {
      final audio = await storage.readLocalAudio(session);
      final rekeyed = session.rekeyed(const Uuid().v4());
      await storage.rekeySession(session.id, rekeyed, scope: scope);
      if (audio != null &&
          audio.bytes.lengthInBytes <= AppConstants.maxUploadBytes) {
        await outbox.stashAudio(
          rekeyed.id,
          audio.bytes,
          extension: audio.extension,
          contentType: audio.contentType,
        );
      }
    }
    for (final interview in interviews.getAll(scope: scope)) {
      await interviews.rekey(
        interview.id,
        interview.rekeyed(const Uuid().v4()),
        scope: scope,
      );
    }

    await prefs.setLastSyncedUserIdFor(scope, userId);
    return true;
  }

  /// Queues every local row the first time a user id is seen — the launch after
  /// this feature ships, and again if the user later links into a different
  /// account on a device that already holds recordings.
  Future<void> backfillIfNeeded(String scope, String userId) async {
    if (prefs.hasBackfilled(userId)) return;
    for (final session in storage.getSessions(scope: scope)) {
      await outbox.enqueue(SyncEntity.session, session.id, scope);
    }
    for (final interview in interviews.getAll(scope: scope)) {
      await outbox.enqueue(SyncEntity.interview, interview.id, scope);
    }
    await prefs.markBackfilled(userId);
  }

  Future<void> _push(String scope, String userId) async {
    // Scoped: entries belonging to another account stay queued until that
    // account signs back in. Pushing them now would find no local row and read
    // as a tombstone, deleting that account's rows off the server.
    for (final entry in outbox.pending(scope: scope)) {
      try {
        switch (entry.kind) {
          case SyncEntity.session:
            await _pushSession(entry.id, scope, userId);
          case SyncEntity.interview:
            await _pushInterview(entry.id, scope, userId);
        }
        await outbox.resolve(entry.kind, entry.id, entry.scope);
      } catch (e) {
        // Left queued deliberately: the next drain retries it.
        log('SyncService: push failed for ${entry.key}: $e');
      }
    }
  }

  Future<void> _pushSession(String id, String scope, String userId) async {
    var record = storage.getSession(id, scope: scope);
    if (record == null) {
      await remote.deleteSession(id);
      await outbox.clearAudio(id);
      return;
    }

    if (record.audioObjectPath == null) {
      final pending = outbox.readAudio(id);
      if (pending != null) {
        final objectPath = await remote.uploadAudio(
          userId: userId,
          sessionId: id,
          bytes: pending.bytes,
          extension: pending.extension,
          contentType: pending.contentType,
        );
        record = record.copyWith(audioObjectPath: objectPath);
        await storage.cacheFromRemote(record);
        await outbox.clearAudio(id);
      }
    }

    await remote.upsertSession(record, userId);
  }

  Future<void> _pushInterview(String id, String scope, String userId) async {
    final matches = interviews
        .getAll(scope: scope)
        .where((i) => i.id == id);
    if (matches.isEmpty) {
      await remote.deleteInterview(id);
      return;
    }
    await remote.upsertInterview(matches.first, userId);
  }

  /// True when anything landed locally, so the history notifiers know to
  /// reload instead of serving the list they read at construction.
  Future<bool> _pull() async {
    var changed = false;

    for (final remoteSession in await remote.fetchSessions()) {
      final local = storage.getSession(remoteSession.id);
      if (local == null) {
        await storage.cacheFromRemote(remoteSession);
        changed = true;
      } else if (local.audioObjectPath == null &&
          remoteSession.audioObjectPath != null) {
        // Fill in the object key without clobbering this device's local
        // audioPath, which plays back without a network round trip.
        await storage.cacheFromRemote(
          local.copyWith(audioObjectPath: remoteSession.audioObjectPath),
        );
        changed = true;
      }
    }

    final localInterviewIds = interviews.getAll().map((i) => i.id).toSet();
    for (final remoteInterview in await remote.fetchInterviews()) {
      if (!localInterviewIds.contains(remoteInterview.id)) {
        await interviews.cacheFromRemote(remoteInterview);
        changed = true;
      }
    }

    return await _applyTombstones() || changed;
  }

  /// Removes rows this account deleted on another device.
  ///
  /// Without it a delete never travelled: the other device kept its copy and
  /// its next push put the row back. Dropped locally rather than flagged, so
  /// nothing has to teach every read to skip deleted rows.
  Future<bool> _applyTombstones() async {
    var changed = false;

    for (final id in await remote.fetchDeletedSessionIds()) {
      if (storage.getSession(id) == null) continue;
      await storage.forgetSession(id);
      changed = true;
    }

    final localInterviews = interviews.getAll().map((i) => i.id).toSet();
    for (final id in await remote.fetchDeletedInterviewIds()) {
      if (!localInterviews.contains(id)) continue;
      await interviews.forget(id);
      changed = true;
    }

    return changed;
  }

  void _emit(SyncStatus status) {
    if (!_statusController.isClosed) _statusController.add(status);
  }

  Future<void> dispose() => _statusController.close();
}

enum SyncStatus { idle, syncing, failed }
