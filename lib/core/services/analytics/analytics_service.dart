import 'dart:async';
import 'dart:developer' show log;

import 'event_queue.dart';

/// Records product analytics.
///
/// Writes to [EventQueue] rather than the network: an event fired before the
/// anonymous account exists — which is every event on a first visit — used to
/// be dropped on the floor. `SyncService` flushes the queue.
///
/// Never throws and never blocks a user action. A dropped event is always
/// preferable to a failed recording.
///
/// `props` must never carry a filename, a transcript, or CV content.
class AnalyticsService {
  AnalyticsService(this._queue);

  final EventQueue _queue;

  void track(String name, [Map<String, Object?> props = const {}]) {
    unawaited(
      _queue
          .add(name, props)
          .catchError((Object e) => log('Analytics: dropped "$name": $e')),
    );
  }

  static const topicSelected = 'topic_selected';
  static const recordingCompleted = 'recording_completed';
  static const fileUploaded = 'file_uploaded';
  static const interviewStarted = 'interview_started';
  static const interviewCompleted = 'interview_completed';
  static const analysisFailed = 'analysis_failed';
}
