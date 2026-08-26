import 'dart:convert';
import 'dart:developer' show log;
import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../constants/app_constants.dart';

enum SyncEntity { session, interview }

class OutboxEntry {
  const OutboxEntry({
    required this.kind,
    required this.id,
    required this.scope,
    required this.queuedAt,
  });

  final SyncEntity kind;
  final String id;

  /// Which local namespace the row lives in — '' for anonymous, otherwise the
  /// account's uid. Load-bearing: without it, a drain running under a different
  /// account would find no local row and mistake the entry for a tombstone,
  /// deleting the other account's data off the server.
  final String scope;

  final DateTime queuedAt;

  String get key => keyFor(kind, id, scope);

  static String keyFor(SyncEntity kind, String id, String scope) =>
      '${kind.name}:$scope:$id';
}

class PendingAudio {
  const PendingAudio({
    required this.bytes,
    required this.extension,
    required this.contentType,
  });

  final Uint8List bytes;
  final String extension;
  final String contentType;
}

/// The durable queue of local writes that have not reached Supabase yet.
///
/// Two Hive boxes rather than one: the row queue is tiny and read on every
/// drain, while pending audio is megabytes and read only when an upload is
/// actually retried. Keeping them apart means a routine drain never
/// deserialises a backlog of base64.
class SyncOutbox {
  Box<String> get _queue => Hive.box<String>(AppConstants.hiveOutboxBox);
  Box<String> get _audio => Hive.box<String>(AppConstants.hivePendingAudioBox);

  // ── row queue ───────────────────────────────────────────────────────────

  Future<void> enqueue(SyncEntity kind, String id, String scope) async {
    final key = OutboxEntry.keyFor(kind, id, scope);
    // Re-queueing an entry that is already waiting must not move it to the back
    // of the line, or a row that keeps failing could starve everything behind
    // it.
    if (_queue.containsKey(key)) return;
    await _queue.put(
      key,
      jsonEncode({
        'kind': kind.name,
        'id': id,
        'scope': scope,
        'queued_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  Future<void> resolve(SyncEntity kind, String id, String scope) async {
    await _queue.delete(OutboxEntry.keyFor(kind, id, scope));
  }

  /// Oldest first, so writes reach the server in the order they were made.
  /// Pass [scope] to list only the entries pushable by the current account.
  List<OutboxEntry> pending({String? scope}) {
    final entries = <OutboxEntry>[];
    for (final raw in _queue.values) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final entryScope = json['scope'] as String? ?? '';
        if (scope != null && entryScope != scope) continue;
        entries.add(
          OutboxEntry(
            kind: SyncEntity.values.firstWhere(
              (e) => e.name == json['kind'] as String,
            ),
            id: json['id'] as String,
            scope: entryScope,
            queuedAt: DateTime.parse(json['queued_at'] as String),
          ),
        );
      } catch (e) {
        log('SyncOutbox: dropping unreadable queue entry: $e');
      }
    }
    entries.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    return entries;
  }

  bool get isEmpty => _queue.isEmpty;

  // ── pending audio ───────────────────────────────────────────────────────

  /// Holds audio back for a later attempt. Only reached when the inline upload
  /// could not run — offline, or a failed request. Keyed by row id alone: ids
  /// are unique across scopes, and a re-keyed row re-stashes under its new one.
  Future<void> stashAudio(
    String sessionId,
    Uint8List bytes, {
    required String extension,
    required String contentType,
  }) async {
    await _audio.put(
      sessionId,
      jsonEncode({
        'bytes': base64Encode(bytes),
        'ext': extension,
        'mime': contentType,
        'queued_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    await _enforceAudioBudget();
  }

  PendingAudio? readAudio(String sessionId) {
    final raw = _audio.get(sessionId);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return PendingAudio(
        bytes: base64Decode(json['bytes'] as String),
        extension: json['ext'] as String,
        contentType: json['mime'] as String,
      );
    } catch (e) {
      log('SyncOutbox: dropping unreadable pending audio for $sessionId: $e');
      unawaitedDelete(sessionId);
      return null;
    }
  }

  Future<void> clearAudio(String sessionId) => _audio.delete(sessionId);

  void unawaitedDelete(String sessionId) {
    _audio.delete(sessionId).catchError(
      (Object e) => log('SyncOutbox: failed to delete pending audio: $e'),
    );
  }

  /// Drops the oldest stashed audio once the box outgrows its budget. The
  /// session row itself is untouched and still syncs — only the ability to play
  /// that take back from another device is lost, which is the right thing to
  /// give up rather than filling the user's disk during a long offline stretch.
  Future<void> _enforceAudioBudget() async {
    var total = 0;
    for (final raw in _audio.values) {
      total += raw.length;
    }
    if (total <= AppConstants.pendingAudioBudgetBytes) return;

    final dated = <MapEntry<String, DateTime>>[];
    for (final key in _audio.keys) {
      final raw = _audio.get(key);
      if (raw == null) continue;
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        dated.add(
          MapEntry(key as String, DateTime.parse(json['queued_at'] as String)),
        );
      } catch (_) {
        dated.add(
          MapEntry(key as String, DateTime.fromMillisecondsSinceEpoch(0)),
        );
      }
    }
    dated.sort((a, b) => a.value.compareTo(b.value));

    for (final entry in dated) {
      if (total <= AppConstants.pendingAudioBudgetBytes) break;
      total -= _audio.get(entry.key)?.length ?? 0;
      await _audio.delete(entry.key);
      log('SyncOutbox: dropped pending audio for ${entry.key} (over budget)');
    }
  }
}
