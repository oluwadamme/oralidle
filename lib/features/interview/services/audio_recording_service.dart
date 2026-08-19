import 'dart:async';
import 'dart:developer' show log;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Wraps [AudioRecorder] with a simple start/stop/cancel lifecycle.
///
/// - [start] is non-throwing: permission denial and platform errors are logged
///   and swallowed.  Callers treat audio as best-effort; the session continues
///   on failure and the playback section simply won't appear.
/// - [stop] returns the recorded file path, or null if no recording was active
///   or an error occurred.
/// - [dispose] stops any active recording before releasing native resources, so
///   the microphone indicator is cleared even if the user leaves mid-recording.
/// - All public methods are safe to call in any order.
class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<void> start() async {
    try {
      if (!await _recorder.hasPermission()) {
        log('AudioRecordingService: microphone permission denied');
        return;
      }

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/interview_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
    } catch (e) {
      // Swallow: audio recording is non-critical; the interview session
      // continues without it and the playback widget simply won't appear.
      log('AudioRecordingService: start failed: $e');
    }
  }

  Future<String?> stop() async {
    try {
      final isRecording = await _recorder.isRecording();
      if (!isRecording) return null;
      return await _recorder.stop();
    } catch (e) {
      log('AudioRecordingService: stop failed: $e');
      return null;
    }
  }

  Future<void> cancel() async {
    try {
      await _recorder.cancel();
    } catch (e) {
      log('AudioRecordingService: cancel failed: $e');
    }
  }

  void dispose() {
    // cancel() stops any active recording before releasing native resources.
    // This prevents the microphone indicator from staying active when the user
    // exits mid-recording. The resulting Future is fire-and-forget since
    // dispose() must be synchronous; errors are swallowed intentionally.
    unawaited(
      _recorder.cancel().catchError((_) {}).whenComplete(_recorder.dispose),
    );
  }
}
