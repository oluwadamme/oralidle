import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io' show Directory, File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/analysis/data/models/session_record.dart';
import '../constants/app_constants.dart';
import 'scoped_keys.dart';
import 'storage_scope.dart';
import 'sync/sync_outbox.dart';

/// Device-local session store, partitioned by [StorageScope].
///
/// Still the only thing the UI reads from, which is what keeps [getSessions]
/// and [calculateStreak] synchronous. Writes also land in [SyncOutbox] so
/// `SyncService` can push them; with no outbox the app behaves exactly as it
/// did before remote sync existed.
class StorageService {
  StorageService(this._scope, [this._outbox]);

  final StorageScope _scope;
  final SyncOutbox? _outbox;

  Box<String> get _box => Hive.box<String>(AppConstants.hiveSessionsBox);

  String get _currentScope => _scope.value;

  Future<void> saveSession(SessionRecord session) async {
    await _put(_currentScope, session);
    await _outbox?.enqueue(SyncEntity.session, session.id, _currentScope);
  }

  /// Writes a row that came *from* the server. Does not enqueue — that would
  /// push straight back what was just pulled.
  Future<void> cacheFromRemote(SessionRecord session) =>
      _put(_currentScope, session);

  Future<void> _put(String scope, SessionRecord session) =>
      _box.put(ScopedKeys.of(scope, session.id), jsonEncode(session.toJson()));

  SessionRecord? getSession(String id, {String? scope}) =>
      _decode(_box.get(ScopedKeys.of(scope ?? _currentScope, id)), id);

  List<SessionRecord> getSessions({String? scope}) {
    final target = scope ?? _currentScope;
    final sessions = <SessionRecord>[];
    for (final key in _box.keys) {
      if (!ScopedKeys.matches(key, target)) continue;
      final record = _decode(_box.get(key), key as String);
      if (record != null) sessions.add(record);
    }
    return sessions..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  SessionRecord? _decode(String? raw, String label) {
    if (raw == null) return null;
    try {
      return SessionRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      log('StorageService: unreadable session $label: $e');
      return null;
    }
  }

  /// Replaces a row's id in place, leaving no tombstone: the row under the old
  /// id belongs to a server account this device can no longer write to, so
  /// asking for its deletion would fail on every retry.
  Future<void> rekeySession(
    String oldId,
    SessionRecord updated, {
    String? scope,
  }) async {
    final target = scope ?? _currentScope;
    await _box.delete(ScopedKeys.of(target, oldId));
    await _outbox?.resolve(SyncEntity.session, oldId, target);
    await _outbox?.clearAudio(oldId);
    await _put(target, updated);
    await _outbox?.enqueue(SyncEntity.session, updated.id, target);
  }

  /// Moves a row out of the anonymous namespace and into [toScope].
  ///
  /// A move rather than a copy, deliberately: anything left behind in the
  /// anonymous namespace would be claimed again by the next person to link an
  /// account on this device.
  Future<void> claimFromAnonymous(
    String anonymousId,
    SessionRecord updated,
    String toScope,
  ) async {
    await _box.delete(ScopedKeys.of(StorageScope.anonymous, anonymousId));
    await _outbox?.resolve(
      SyncEntity.session,
      anonymousId,
      StorageScope.anonymous,
    );
    await _put(toScope, updated);
    await _outbox?.enqueue(SyncEntity.session, updated.id, toScope);
  }

  Future<String?> saveAudioFile(
    String id,
    Uint8List bytes, {
    String extension = 'wav',
    String? mimeType,
  }) async {
    try {
      if (kIsWeb) {
        final mime = mimeType ?? 'audio/${extension.replaceAll('.', '')}';
        final base64Str = base64Encode(bytes);
        return 'data:$mime;base64,$base64Str';
      } else {
        final docsDir = await getApplicationDocumentsDirectory();
        final recordingsDir = Directory('${docsDir.path}/recordings');
        if (!await recordingsDir.exists()) {
          await recordingsDir.create(recursive: true);
        }
        final ext = extension.replaceAll('.', '');
        final file = File('${recordingsDir.path}/$id.$ext');
        await file.writeAsBytes(bytes);
        return file.path;
      }
    } catch (e) {
      log('StorageService: failed to save audio file for session $id: $e');
      return null;
    }
  }

  /// Reads a session's audio back off this device, so it can be re-uploaded
  /// under a different account. Null when there is no local copy left.
  Future<PendingAudio?> readLocalAudio(SessionRecord session) async {
    final path = session.audioPath;
    if (path == null || path.isEmpty) return null;
    try {
      if (path.startsWith('data:')) {
        final match = RegExp(r'^data:([^;]+);base64,(.*)$').firstMatch(path);
        if (match == null) return null;
        final mime = match.group(1)!;
        return PendingAudio(
          bytes: base64Decode(match.group(2)!),
          extension: mime.split('/').last,
          contentType: mime,
        );
      }
      if (kIsWeb) return null;
      final file = File(path);
      if (!await file.exists()) return null;
      final extension = path.split('.').last;
      return PendingAudio(
        bytes: await file.readAsBytes(),
        extension: extension,
        contentType: 'audio/$extension',
      );
    } catch (e) {
      log('StorageService: could not read local audio for ${session.id}: $e');
      return null;
    }
  }

  /// Drops a row the server says was deleted elsewhere.
  ///
  /// No tombstone is queued — the server already has one, and pushing a second
  /// delete for a row this device never deleted would be pointless traffic.
  /// The local audio file goes with it.
  Future<void> forgetSession(String id) async {
    await _deleteLocalAudio(getSession(id));
    await _box.delete(ScopedKeys.of(_currentScope, id));
    await _outbox?.resolve(SyncEntity.session, id, _currentScope);
    await _outbox?.clearAudio(id);
  }

  Future<void> _deleteLocalAudio(SessionRecord? session) async {
    final path = session?.audioPath;
    if (path == null || kIsWeb || path.startsWith('data:')) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      log('StorageService: error deleting audio for ${session?.id}: $e');
    }
  }

  Future<void> deleteSession(String id) async {
    final session = getSession(id);
    if (session != null) {
      try {
        final path = session.audioPath;
        if (path != null && !kIsWeb && !path.startsWith('data:')) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
      } catch (e) {
        log('StorageService: error deleting audio file for session $id: $e');
      }
    }
    await _box.delete(ScopedKeys.of(_currentScope, id));
    await _outbox?.clearAudio(id);
    // Queued after the local delete: the drain reads "queued but no longer in
    // Hive" as a tombstone and issues the remote delete.
    await _outbox?.enqueue(SyncEntity.session, id, _currentScope);
  }

  int calculateStreak() {
    final sessions = getSessions();
    if (sessions.isEmpty) return 0;

    final dates =
        sessions
            .map(
              (s) => DateTime(
                s.timestamp.year,
                s.timestamp.month,
                s.timestamp.day,
              ),
            )
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    if (dates.first.difference(todayNorm).inDays.abs() > 1) return 0;

    int streak = 1;
    for (int i = 0; i < dates.length - 1; i++) {
      if (dates[i].difference(dates[i + 1]).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}
