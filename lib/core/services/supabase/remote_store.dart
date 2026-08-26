import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/analysis/data/models/analysis_result.dart';
import '../../../features/analysis/data/models/session_record.dart';
import '../../../features/interview/data/models/interview_models.dart';
import '../../config/supabase_config.dart';

/// Every read and write against the server.
///
/// An interface so `SyncService` can be exercised without a network, in the
/// same spirit as [InterviewRepository].
abstract interface class RemoteStore {
  String? get currentUserId;

  Future<void> upsertSession(SessionRecord record, String userId);

  /// Live rows only — tombstones come back through [fetchDeletedSessionIds].
  Future<List<SessionRecord>> fetchSessions();

  /// Ids this account deleted, on any device. Applied locally so a deletion
  /// propagates instead of being resurrected by the next pull.
  Future<List<String>> fetchDeletedSessionIds();

  /// Marks the row deleted rather than removing it. A DELETE leaves nothing for
  /// other devices to notice. A trigger strips the contents server-side.
  Future<void> deleteSession(String id);

  Future<void> upsertInterview(CompletedInterview interview, String userId);
  Future<List<CompletedInterview>> fetchInterviews();
  Future<List<String>> fetchDeletedInterviewIds();
  Future<void> deleteInterview(String id);

  Future<String> uploadAudio({
    required String userId,
    required String sessionId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  });
  Future<String> signedAudioUrl(String objectPath);

  Future<void> upsertProfile({required String userId, String? displayName});
  /// Batched: an offline stretch drains as one request rather than one per
  /// event. Rows are pre-shaped by the caller.
  Future<void> insertEvents(List<Map<String, Object?>> rows);
}

/// Maps models to rows and back, and nothing else. Deciding *when* to call any
/// of it — offline queueing, retries, merge order — belongs to `SyncService`.
///
/// No read passes a user id: RLS scopes every query to `auth.uid()` on the
/// server, so a forgotten filter cannot leak another user's rows.
class SupabaseRemoteStore implements RemoteStore {
  SupabaseRemoteStore(this._client);

  final SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  // ── sessions ────────────────────────────────────────────────────────────

  @override
  Future<void> upsertSession(SessionRecord record, String userId) async {
    await _client.from('sessions').upsert({
      'id': record.id,
      'user_id': userId,
      'topic_title': record.topicTitle,
      'topic_category': record.topicCategory,
      'duration_seconds': record.durationSeconds,
      'result': record.result.toJson(),
      'audio_object_path': record.audioObjectPath,
      'recorded_at': record.timestamp.toUtc().toIso8601String(),
    });
  }

  @override
  Future<List<SessionRecord>> fetchSessions() async {
    final rows = await _client
        .from('sessions')
        .select(
          'id, topic_title, topic_category, duration_seconds, result, '
          'audio_object_path, recorded_at',
        )
        .isFilter('deleted_at', null)
        .order('recorded_at', ascending: false);
    return rows.map(_sessionFromRow).toList();
  }

  @override
  Future<List<String>> fetchDeletedSessionIds() async {
    final rows = await _client
        .from('sessions')
        .select('id')
        .not('deleted_at', 'is', null);
    return rows.map((row) => row['id'] as String).toList();
  }

  @override
  Future<void> deleteSession(String id) async {
    await _client
        .from('sessions')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  static SessionRecord _sessionFromRow(Map<String, dynamic> row) =>
      SessionRecord(
        id: row['id'] as String,
        topicTitle: row['topic_title'] as String,
        topicCategory: row['topic_category'] as String,
        timestamp: DateTime.parse(row['recorded_at'] as String).toLocal(),
        durationSeconds: (row['duration_seconds'] as num).toInt(),
        result: AnalysisResult.fromJson(
          Map<String, dynamic>.from(row['result'] as Map),
        ),
        // audioPath stays absent: a device-local path means nothing here.
        audioObjectPath: row['audio_object_path'] as String?,
      );

  // ── interviews ──────────────────────────────────────────────────────────

  @override
  Future<void> upsertInterview(
    CompletedInterview interview,
    String userId,
  ) async {
    await _client.from('interviews').upsert({
      'id': interview.id,
      'user_id': userId,
      'mode': interview.mode.name,
      'target_questions': interview.targetQuestions,
      'turns': interview.turns.map((t) => t.toJson()).toList(),
      'evaluation': interview.evaluation.toJson(),
      'recorded_at': interview.timestamp.toUtc().toIso8601String(),
    });
  }

  @override
  Future<List<CompletedInterview>> fetchInterviews() async {
    final rows = await _client
        .from('interviews')
        .select('id, mode, target_questions, turns, evaluation, recorded_at')
        .isFilter('deleted_at', null)
        .order('recorded_at', ascending: false);
    return rows.map(_interviewFromRow).toList();
  }

  @override
  Future<List<String>> fetchDeletedInterviewIds() async {
    final rows = await _client
        .from('interviews')
        .select('id')
        .not('deleted_at', 'is', null);
    return rows.map((row) => row['id'] as String).toList();
  }

  @override
  Future<void> deleteInterview(String id) async {
    await _client
        .from('interviews')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  static CompletedInterview _interviewFromRow(Map<String, dynamic> row) =>
      CompletedInterview.fromJson({
        'id': row['id'],
        'mode': row['mode'],
        'target_questions': row['target_questions'],
        'turns': row['turns'],
        'evaluation': row['evaluation'],
        'timestamp': DateTime.parse(
          row['recorded_at'] as String,
        ).toLocal().toIso8601String(),
      });

  // ── audio ───────────────────────────────────────────────────────────────

  /// Uploads to `{uid}/{sessionId}.{ext}`. The bucket policy compares the first
  /// path segment against `auth.uid()`, so the layout is load-bearing.
  @override
  Future<String> uploadAudio({
    required String userId,
    required String sessionId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    final objectPath = '$userId/$sessionId.$extension';
    await _client.storage
        .from(SupabaseConfig.audioBucket)
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return objectPath;
  }

  @override
  Future<String> signedAudioUrl(String objectPath) => _client.storage
      .from(SupabaseConfig.audioBucket)
      .createSignedUrl(objectPath, SupabaseConfig.signedUrlTtl.inSeconds);

  // ── profile & events ────────────────────────────────────────────────────

  @override
  Future<void> upsertProfile({
    required String userId,
    String? displayName,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'display_name': ?displayName,
    });
  }

  @override
  Future<void> insertEvents(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return;
    await _client.from('events').insert(rows);
  }
}
