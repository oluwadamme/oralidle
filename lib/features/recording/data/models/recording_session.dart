import 'dart:typed_data';

class RecordingSession {
  final String topicId;
  final String topicTitle;
  final String topicCategory;
  final String transcript;
  final int durationSeconds;

  // Set when the session comes from an uploaded audio file rather than live recording
  final Uint8List? audioFileBytes;
  final String? audioFileMimeType;
  final String? audioFileName;

  const RecordingSession({
    required this.topicId,
    required this.topicTitle,
    required this.topicCategory,
    required this.transcript,
    required this.durationSeconds,
    this.audioFileBytes,
    this.audioFileMimeType,
    this.audioFileName,
  });

  bool get isAudioUpload => audioFileBytes != null;
}
