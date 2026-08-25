import 'dart:typed_data';

class RecordingSession {
  final String topicId;
  final String topicTitle;
  final String topicCategory;
  final String transcript;
  final int durationSeconds;
  final Uint8List? audioBytes;
  final String? audioMimeType;
  final Uint8List? uploadBytes;
  final String? audioFileName;

  const RecordingSession({
    required this.topicId,
    required this.topicTitle,
    required this.topicCategory,
    required this.transcript,
    required this.durationSeconds,
    this.audioBytes,
    this.audioMimeType,
    this.uploadBytes,
    this.audioFileName,
  });

  bool get hasAudio => audioBytes != null && audioBytes!.isNotEmpty;

  Uint8List? get analysisBytes => uploadBytes ?? audioBytes;
  bool get hasTranscript => transcript.trim().isNotEmpty;
  bool get isAudioUpload => audioFileName != null;
}
