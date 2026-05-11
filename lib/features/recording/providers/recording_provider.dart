import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/recording_session.dart';
import '../../topic_selection/data/models/topic.dart';
import '../../../core/services/speech_service.dart';

enum RecordingStatus { idle, recording, stopped, error }

class RecordingState {
  final RecordingStatus status;
  final String transcript;
  final String partialText;
  final int elapsedSeconds;
  final String topicId;
  final String topicTitle;
  final String topicCategory;
  final RecordingSession? completedSession;
  final String? errorMessage;

  const RecordingState({
    this.status = RecordingStatus.idle,
    this.transcript = '',
    this.partialText = '',
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
    String? partialText,
    int? elapsedSeconds,
    String? topicId,
    String? topicTitle,
    String? topicCategory,
    RecordingSession? completedSession,
    String? errorMessage,
  }) =>
      RecordingState(
        status: status ?? this.status,
        transcript: transcript ?? this.transcript,
        partialText: partialText ?? this.partialText,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        topicId: topicId ?? this.topicId,
        topicTitle: topicTitle ?? this.topicTitle,
        topicCategory: topicCategory ?? this.topicCategory,
        completedSession: completedSession ?? this.completedSession,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  String get fullTranscript => '$transcript $partialText'.trim();
  bool get canStop => elapsedSeconds >= 60;
  bool get isRecording => status == RecordingStatus.recording;
}

class RecordingNotifier extends StateNotifier<RecordingState> {
  RecordingNotifier(this._speechService) : super(const RecordingState());

  final SpeechService _speechService;
  Timer? _timer;

  Future<void> startRecording(Topic topic) async {
    final initialized = await _speechService.initialize();
    if (!initialized) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: 'Speech recognition is not available on this device.',
      );
      return;
    }

    state = RecordingState(
      status: RecordingStatus.recording,
      topicId: topic.id,
      topicTitle: topic.title,
      topicCategory: topic.category,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = state.elapsedSeconds + 1;
      if (next >= 120) {
        timer.cancel();
        _finalise(120);
      } else {
        state = state.copyWith(elapsedSeconds: next);
      }
    });

    await _speechService.startContinuous((text, isFinal) {
      if (!mounted || state.status != RecordingStatus.recording) return;
      if (isFinal) {
        final accumulated = state.transcript.isEmpty ? text : '${state.transcript} $text';
        state = state.copyWith(transcript: accumulated.trim(), partialText: '');
      } else {
        state = state.copyWith(partialText: text);
      }
    });
  }

  void stopManually() => _finalise(state.elapsedSeconds);

  void _finalise(int seconds) {
    _speechService.stop();
    final session = RecordingSession(
      topicId: state.topicId,
      topicTitle: state.topicTitle,
      topicCategory: state.topicCategory,
      transcript: state.fullTranscript,
      durationSeconds: seconds,
    );
    state = state.copyWith(
      status: RecordingStatus.stopped,
      elapsedSeconds: seconds,
      partialText: '',
      completedSession: session,
    );
  }

  void reset() {
    _timer?.cancel();
    _speechService.stop();
    state = const RecordingState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final speechServiceProvider = Provider<SpeechService>((_) => SpeechService());

final recordingProvider =
    StateNotifierProvider<RecordingNotifier, RecordingState>((ref) {
  return RecordingNotifier(ref.watch(speechServiceProvider));
});
