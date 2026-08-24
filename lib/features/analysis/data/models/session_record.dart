import 'analysis_result.dart';

class SessionRecord {
  final String id;
  final String topicTitle;
  final String topicCategory;
  final DateTime timestamp;
  final int durationSeconds;
  final AnalysisResult result;
  final String? audioPath;

  const SessionRecord({
    required this.id,
    required this.topicTitle,
    required this.topicCategory,
    required this.timestamp,
    required this.durationSeconds,
    required this.result,
    this.audioPath,
  });

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
    id: json['id'] as String,
    topicTitle: json['topic_title'] as String,
    topicCategory: json['topic_category'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    durationSeconds: (json['duration_seconds'] as num).toInt(),
    result: AnalysisResult.fromJson(json['result'] as Map<String, dynamic>),
    audioPath: json['audio_path'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'topic_title': topicTitle,
    'topic_category': topicCategory,
    'timestamp': timestamp.toIso8601String(),
    'duration_seconds': durationSeconds,
    'result': result.toJson(),
    if (audioPath != null) 'audio_path': audioPath,
  };

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }
}
