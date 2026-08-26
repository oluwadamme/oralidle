import 'dart:typed_data';

import 'package:widget_overlay_outside/core/services/supabase/remote_store.dart';
import 'package:widget_overlay_outside/features/analysis/data/models/analysis_result.dart';
import 'package:widget_overlay_outside/features/analysis/data/models/session_record.dart';
import 'package:widget_overlay_outside/features/interview/data/models/interview_models.dart';

class FakeRemoteStore implements RemoteStore {
  FakeRemoteStore({this.currentUserId = 'user-1'});

  @override
  String? currentUserId;

  final sessions = <String, SessionRecord>{};
  final interviews = <String, CompletedInterview>{};
  final uploads = <String, Uint8List>{};
  final events = <Map<String, Object?>>[];
  final deletedSessionIds = <String>[];
  final deletedInterviewIds = <String>[];

  /// Tombstones, mirroring the server's `deleted_at`. Keyed by owner so a
  /// deletion is only visible to the account that made it.
  final sessionTombstones = <String, String>{};
  final interviewTombstones = <String, String>{};

  /// Row ownership, so reads and writes can be scoped the way RLS scopes them.
  /// Without this the fake would happily hand one user another's rows and the
  /// tests would prove nothing.
  final sessionOwners = <String, String>{};
  final interviewOwners = <String, String>{};

  /// Set to make the next write throw, standing in for an offline device.
  bool failWrites = false;

  void seedSession(SessionRecord record, {String userId = 'user-1'}) {
    sessions[record.id] = record;
    sessionOwners[record.id] = userId;
  }

  void seedInterview(CompletedInterview interview, {String userId = 'user-1'}) {
    interviews[interview.id] = interview;
    interviewOwners[interview.id] = userId;
  }

  void _guard() {
    if (failWrites) throw Exception('offline');
  }

  /// Postgres refuses `on conflict do update` when RLS hides the conflicting
  /// row: the unique index still sees it, but the update policy does not permit
  /// touching it.
  void _guardOwnership(Map<String, String> owners, String id, String userId) {
    final owner = owners[id];
    if (owner != null && owner != userId) {
      throw Exception('new row violates row-level security policy');
    }
  }

  @override
  Future<void> upsertSession(SessionRecord record, String userId) async {
    _guard();
    _guardOwnership(sessionOwners, record.id, userId);
    sessions[record.id] = record;
    sessionOwners[record.id] = userId;
  }

  @override
  Future<List<SessionRecord>> fetchSessions() async =>
      sessions.values
          .where(
            (s) =>
                sessionOwners[s.id] == currentUserId &&
                !sessionTombstones.containsKey(s.id),
          )
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  @override
  Future<List<String>> fetchDeletedSessionIds() async => sessionTombstones
      .entries
      .where((e) => e.value == currentUserId)
      .map((e) => e.key)
      .toList();

  @override
  Future<void> deleteSession(String id) async {
    _guard();
    final owner = sessionOwners[id];
    if (owner != currentUserId) return;
    // Soft: the row stays as a tombstone, its contents stripped by the trigger.
    sessions.remove(id);
    sessionTombstones[id] = owner!;
    deletedSessionIds.add(id);
  }

  @override
  Future<void> upsertInterview(
    CompletedInterview interview,
    String userId,
  ) async {
    _guard();
    _guardOwnership(interviewOwners, interview.id, userId);
    interviews[interview.id] = interview;
    interviewOwners[interview.id] = userId;
  }

  @override
  Future<List<CompletedInterview>> fetchInterviews() async => interviews.values
      .where(
        (i) =>
            interviewOwners[i.id] == currentUserId &&
            !interviewTombstones.containsKey(i.id),
      )
      .toList();

  @override
  Future<List<String>> fetchDeletedInterviewIds() async => interviewTombstones
      .entries
      .where((e) => e.value == currentUserId)
      .map((e) => e.key)
      .toList();

  @override
  Future<void> deleteInterview(String id) async {
    _guard();
    final owner = interviewOwners[id];
    if (owner != currentUserId) return;
    interviews.remove(id);
    interviewTombstones[id] = owner!;
    deletedInterviewIds.add(id);
  }

  @override
  Future<String> uploadAudio({
    required String userId,
    required String sessionId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    _guard();
    final objectPath = '$userId/$sessionId.$extension';
    uploads[objectPath] = bytes;
    return objectPath;
  }

  @override
  Future<String> signedAudioUrl(String objectPath) async =>
      'https://signed.test/$objectPath';

  @override
  Future<void> upsertProfile({
    required String userId,
    String? displayName,
  }) async {
    _guard();
  }

  @override
  Future<void> insertEvent({
    required String userId,
    required String name,
    required Map<String, Object?> props,
  }) async {
    events.add({'user_id': userId, 'name': name, 'props': props});
  }
}

SessionRecord fakeSession({
  required String id,
  DateTime? timestamp,
  String? audioPath,
  String? audioObjectPath,
}) => SessionRecord(
  id: id,
  topicTitle: 'A topic',
  topicCategory: 'general',
  timestamp: timestamp ?? DateTime(2026, 8, 25, 12),
  durationSeconds: 90,
  result: const AnalysisResult(
    scores: SpeechScores(
      fluency: 70,
      vocabulary: 70,
      grammar: 70,
      coherence: 70,
      topicRelevance: 70,
      confidence: 70,
    ),
    overallScore: 70,
    fillerWords: {'um': 2},
    wpm: 130,
    strengths: ['Clear'],
    improvements: [],
    summary: 'Solid.',
    transcript: 'Hello world.',
  ),
  audioPath: audioPath,
  audioObjectPath: audioObjectPath,
);

CompletedInterview fakeInterview({required String id}) => CompletedInterview(
  id: id,
  mode: InterviewMode.technical,
  targetQuestions: 3,
  turns: const [],
  evaluation: const InterviewEvaluation(
    overallScore: 72,
    summary: 'Good.',
    strengths: ['Structured'],
    improvements: ['More detail'],
  ),
  timestamp: DateTime(2026, 8, 25, 13),
);
