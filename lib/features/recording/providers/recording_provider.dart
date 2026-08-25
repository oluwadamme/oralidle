import 'dart:async';
import 'dart:developer' show log;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/recording_session.dart';
import '../../topic_selection/data/models/topic.dart';
import '../../../core/services/speech/audio_capture_service.dart';
import '../../../core/services/speech/speech_providers.dart';
import '../../../core/services/speech/speech_recognition_service.dart';

enum RecordingStatus {
  idle,
  recording,
  finalising,
  stopped,
  error,
}

class RecordingState {
  final RecordingStatus status;

  final String transcript;
  final int elapsedSeconds;
  final String topicId;
  final String topicTitle;
  final String topicCategory;
  final RecordingSession? completedSession;
  final String? errorMessage;

  const RecordingState({
    this.status = RecordingStatus.idle,
    this.transcript = '',
    this.elapsedSeconds = 0,
    this.topicId = '',
    this.topicTitle = '',
    this.topicCategory = '',
    this.completedSession,
    this.errorMessage,
  });

  RecordingState copyWith({
    RecordingStatus? status,
    String? transcript,
    int? elapsedSeconds,
    String? topicId,
    String? topicTitle,
    String? topicCategory,
    RecordingSession? completedSession,
    String? errorMessage,
  }) => RecordingState(
    status: status ?? this.status,
    transcript: transcript ?? this.transcript,
    elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    topicId: topicId ?? this.topicId,
    topicTitle: topicTitle ?? this.topicTitle,
    topicCategory: topicCategory ?? this.topicCategory,
    completedSession: completedSession ?? this.completedSession,
    errorMessage: errorMessage ?? this.errorMessage,
  );

  bool get canStop => elapsedSeconds >= 60;
  bool get isRecording => status == RecordingStatus.recording;
  bool get isFinalising => status == RecordingStatus.finalising;
}

class RecordingNotifier extends StateNotifier<RecordingState> {
  RecordingNotifier({required this._capture, required this._recognition})
    : super(const RecordingState());

  static const _maxSeconds = 120;

  final AudioCaptureService _capture;
  final SpeechRecognitionService _recognition;
  Timer? _timer;

  bool _finalising = false;

  Future<void> startRecording(Topic topic) async {
    unawaited(_recognition.prepare());

    final started = await _capture.start();
    if (!mounted) return;

    if (!started) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage:
            'Microphone unavailable. Grant microphone access and try again.',
      );
      return;
    }

    _finalising = false;
    state = RecordingState(
      status: RecordingStatus.recording,
      topicId: topic.id,
      topicTitle: topic.title,
      topicCategory: topic.category,
    );

    if (_recognition.state.isReady) {
      await _recognition.listen(_capture.pcmStream, (transcript) {
        if (!mounted || state.status != RecordingStatus.recording) return;
        state = state.copyWith(transcript: transcript);
      });
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = state.elapsedSeconds + 1;
      if (next >= _maxSeconds) {
        timer.cancel();
        unawaited(_finalise(_maxSeconds));
      } else {
        state = state.copyWith(elapsedSeconds: next);
      }
    });
  }

  Future<void> stopManually() => _finalise(state.elapsedSeconds);

  Future<void> _finalise(int seconds) async {
    if (_finalising) return;
    _finalising = true;

    _timer?.cancel();
    _timer = null;

    if (mounted) {
      state = state.copyWith(
        status: RecordingStatus.finalising,
        elapsedSeconds: seconds,
      );
    }

    // Release the microphone first, then drain the recogniser's last window.
    final audio = await _capture.stop();
    final transcript = await _recognition.finish();

    if (!mounted) {
      log('RecordingNotifier: disposed while finalising — take discarded');
      return;
    }

    final usableAudio = (audio == null || audio.isEmpty) ? null : audio;

    if (usableAudio == null && transcript.isEmpty) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: 'No audio was captured. Please check your microphone.',
      );
      return;
    }

    final session = RecordingSession(
      topicId: state.topicId,
      topicTitle: state.topicTitle,
      topicCategory: state.topicCategory,
      transcript: transcript,
      durationSeconds: usableAudio?.duration.inSeconds ?? seconds,
      audioBytes: usableAudio?.playbackBytes,
      audioMimeType: usableAudio?.mimeType,
      uploadBytes: usableAudio?.uploadBytes,
    );

    state = state.copyWith(
      status: RecordingStatus.stopped,
      completedSession: session,
    );
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _finalising = false;
    unawaited(_capture.cancel());
    unawaited(_recognition.abort());
    state = const RecordingState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_capture.cancel());
    unawaited(_recognition.abort());
    super.dispose();
  }
}

final recordingProvider =
    StateNotifierProvider.autoDispose<RecordingNotifier, RecordingState>((ref) {
      return RecordingNotifier(
        capture: ref.watch(audioCaptureServiceProvider),
        recognition: ref.watch(speechRecognitionServiceProvider),
      );
    });

/// Live microphone level, 0..1, for the recording waveform.
final micLevelProvider = StreamProvider.autoDispose<double>((ref) {
  return ref.watch(audioCaptureServiceProvider).amplitudeStream;
});
