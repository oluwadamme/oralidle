import 'analysis_result.dart';

class SessionRecord {
  final String id;
  final String topicTitle;
  final String topicCategory;
  final DateTime timestamp;
  final int durationSeconds;
  final AnalysisResult result;

  /// Where the audio sits on *this* device — a file path on native, a `data:`
  /// URI on web. Never synced: a path from one device means nothing on another.
  final String? audioPath;

  /// Key of the object in the `recordings` bucket, once it has been uploaded.
  /// This is the form that travels, and the one a second device plays from.
  final String? audioObjectPath;

  const SessionRecord({
    required this.id,
    required this.topicTitle,
    required this.topicCategory,
    required this.timestamp,
    required this.durationSeconds,
    required this.result,
    this.audioPath,
    this.audioObjectPath,
  });

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
    id: json['id'] as String,
    topicTitle: json['topic_title'] as String,
    topicCategory: json['topic_category'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    durationSeconds: (json['duration_seconds'] as num).toInt(),
    result: AnalysisResult.fromJson(json['result'] as Map<String, dynamic>),
    audioPath: json['audio_path'] as String?,
    audioObjectPath: json['audio_object_path'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'topic_title': topicTitle,
    'topic_category': topicCategory,
    'timestamp': timestamp.toIso8601String(),
    'duration_seconds': durationSeconds,
    'result': result.toJson(),
    if (audioPath != null) 'audio_path': audioPath,
    if (audioObjectPath != null) 'audio_object_path': audioObjectPath,
  };

  /// The same session under a new id, with the uploaded copy forgotten.
  ///
  /// Used when a device switches accounts: the row already on the server
  /// belongs to the abandoned uid and cannot be reassigned, so this one inserts
  /// fresh instead.
  SessionRecord rekeyed(String newId) => SessionRecord(
    id: newId,
    topicTitle: topicTitle,
    topicCategory: topicCategory,
    timestamp: timestamp,
    durationSeconds: durationSeconds,
    result: result,
    audioPath: audioPath,
  );

  SessionRecord copyWith({String? audioPath, String? audioObjectPath}) =>
      SessionRecord(
        id: id,
        topicTitle: topicTitle,
        topicCategory: topicCategory,
        timestamp: timestamp,
        durationSeconds: durationSeconds,
        result: result,
        audioPath: audioPath ?? this.audioPath,
        audioObjectPath: audioObjectPath ?? this.audioObjectPath,
      );

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }
}
