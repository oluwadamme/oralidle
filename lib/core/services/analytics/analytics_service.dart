import 'dart:developer' show log;

import '../supabase/remote_store.dart';

/// Fire-and-forget product analytics.
///
/// Never throws and never blocks a user action — a dropped event is always
/// preferable to a failed recording. Events are not queued offline for the same
/// reason: they are aggregate signal, not user data.
///
/// `props` must never carry a filename, a transcript, or CV content.
class AnalyticsService {
  AnalyticsService(this._remote);

  final RemoteStore? _remote;

  void track(String name, [Map<String, Object?> props = const {}]) {
    final remote = _remote;
    final userId = remote?.currentUserId;
    if (remote == null || userId == null) return;
    remote
        .insertEvent(userId: userId, name: name, props: props)
        .catchError((Object e) => log('Analytics: dropped "$name": $e'));
  }

  static const topicSelected = 'topic_selected';
  static const recordingCompleted = 'recording_completed';
  static const fileUploaded = 'file_uploaded';
  static const interviewStarted = 'interview_started';
  static const interviewCompleted = 'interview_completed';
  static const analysisFailed = 'analysis_failed';
}
