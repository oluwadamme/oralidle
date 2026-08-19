import 'dart:typed_data';

/// One completed speaking session, on its way to analysis.
///
/// Audio and transcript are independent: a live recording normally carries
/// both (the clip plus the on-device transcript), an uploaded file carries
/// only audio, and a live recording on a platform without an on-device
/// recogniser also carries only audio. Analysis prefers audio whenever it is
/// present, because Gemini hears delivery that no transcript preserves.
class RecordingSession {
  final String topicId;
  final String topicTitle;
  final String topicCategory;
  final String transcript;
  final int durationSeconds;

  /// The recorded or uploaded clip. Held in memory rather than on disk so the
  /// same representation works on web.
  final Uint8List? audioBytes;
  final String? audioMimeType;

  /// Set only when the audio came from the file picker.
  final String? audioFileName;

  const RecordingSession({
    required this.topicId,
    required this.topicTitle,
    required this.topicCategory,
    required this.transcript,
    required this.durationSeconds,
    this.audioBytes,
    this.audioMimeType,
    this.audioFileName,
  });

  bool get hasAudio => audioBytes != null && audioBytes!.isNotEmpty;
  bool get hasTranscript => transcript.trim().isNotEmpty;
  bool get isAudioUpload => audioFileName != null;
}
