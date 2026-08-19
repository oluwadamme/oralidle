import 'dart:async';
import 'dart:developer' show log;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/interview_models.dart';
import '../data/repositories/interview_repository.dart';
import '../services/audio_recording_service.dart';
import '../services/interview_service.dart';
import '../../../core/services/speech_service.dart';
import 'interview_history_provider.dart';

// ── Asset providers — non-autoDispose, loaded once and cached app-lifetime ──

final cvContentProvider = FutureProvider<String>(
  (_) => rootBundle.loadString('assets/cv.md'),
);

final skillsContentProvider = FutureProvider<String>(
  (_) => rootBundle.loadString('assets/interview-prep-skills.md'),
);

// ── Sentinel for nullable copyWith fields ────────────────────────────────────
//
// const sentinel + identical() lets callers write:
//   copyWith(lastEvaluation: null)   → explicitly clears the field
//   copyWith()                       → preserves the current value
//
// Avoids the clearXxx: bool anti-pattern.

class _Absent {
  const _Absent();
}

const _absent = _Absent();

// ── State ─────────────────────────────────────────────────────────────────────

enum InterviewPhase { loading, waiting, recording, processing, feedback, error }

class InterviewState {
  final InterviewMode mode;
  final int targetQuestions;
  final List<InterviewTurn> completedTurns;
  final InterviewQuestion? currentQuestion;
  final String transcript;
  final String partialText;
  final int elapsedSeconds;
  final InterviewPhase phase;
  final TurnEvaluation? lastEvaluation;
  final InterviewEvaluation? finalEvaluation;
  // Set when the session completes and is persisted. Passed to results screen
  // so it carries the same id as the Hive record.
  final CompletedInterview? completedInterview;
  // File path of the audio recording for the most recent answer; cleared when
  // moving to the next question so the player isn't shown stale content.
  final String? lastRecordingPath;
  final String? error;

  const InterviewState({
    this.mode = InterviewMode.mixed,
    this.targetQuestions = 5,
    this.completedTurns = const [],
    this.currentQuestion,
    this.transcript = '',
    this.partialText = '',
    this.elapsedSeconds = 0,
    this.phase = InterviewPhase.loading,
    this.lastEvaluation,
    this.finalEvaluation,
    this.completedInterview,
    this.lastRecordingPath,
    this.error,
  });

  InterviewState copyWith({
    InterviewMode? mode,
    int? targetQuestions,
    List<InterviewTurn>? completedTurns,
    Object? currentQuestion = _absent,
    String? transcript,
    String? partialText,
    int? elapsedSeconds,
    InterviewPhase? phase,
    Object? lastEvaluation = _absent,
    Object? finalEvaluation = _absent,
    Object? completedInterview = _absent,
    Object? lastRecordingPath = _absent,
    Object? error = _absent,
  }) =>
      InterviewState(
        mode: mode ?? this.mode,
        targetQuestions: targetQuestions ?? this.targetQuestions,
        completedTurns: completedTurns ?? this.completedTurns,
        currentQuestion: identical(currentQuestion, _absent)
            ? this.currentQuestion
            : currentQuestion as InterviewQuestion?,
        transcript: transcript ?? this.transcript,
        partialText: partialText ?? this.partialText,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        phase: phase ?? this.phase,
        lastEvaluation: identical(lastEvaluation, _absent)
            ? this.lastEvaluation
            : lastEvaluation as TurnEvaluation?,
        finalEvaluation: identical(finalEvaluation, _absent)
            ? this.finalEvaluation
            : finalEvaluation as InterviewEvaluation?,
        completedInterview: identical(completedInterview, _absent)
            ? this.completedInterview
            : completedInterview as CompletedInterview?,
        lastRecordingPath: identical(lastRecordingPath, _absent)
            ? this.lastRecordingPath
            : lastRecordingPath as String?,
        error: identical(error, _absent) ? this.error : error as String?,
      );

  String get fullTranscript => '$transcript $partialText'.trim();
  bool get isLastQuestion => completedTurns.length + 1 == targetQuestions;
  int get currentQuestionNumber => completedTurns.length + 1;
  bool get isRecording => phase == InterviewPhase.recording;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class InterviewNotifier extends StateNotifier<InterviewState> {
  InterviewNotifier({
    required SpeechService speechService,
    required AudioRecordingService audioService,
    required InterviewRepository repository,
    required Ref ref,
  })  : _speechService = speechService,
        _audioService = audioService,
        _repository = repository,
        _ref = ref,
        super(const InterviewState());

  final SpeechService _speechService;
  final AudioRecordingService _audioService;
  final InterviewRepository _repository;
  final Ref _ref;
  InterviewService? _service;
  Timer? _timer;

  Future<void> initialize({
    required InterviewMode mode,
    required int questionCount,
  }) async {
    // Close and release any service from a prior session or failed attempt
    _timer?.cancel();
    _timer = null;
    _service?.close();
    _service = null;

    state = InterviewState(
      mode: mode,
      targetQuestions: questionCount,
      phase: InterviewPhase.loading,
    );

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('GEMINI_API_KEY is not configured in .env');
      }

      // Assets come from FutureProviders cached at app-level — one disk read
      // per app session, not per interview session.
      final results = await Future.wait([
        _ref.read(cvContentProvider.future),
        _ref.read(skillsContentProvider.future),
      ]);

      // Guard against the screen being popped while assets were loading
      if (!mounted) return;

      _service = InterviewService(
        apiKey: apiKey,
        cvContent: results[0],
        skillsContent: results[1],
        mode: mode,
        questionCount: questionCount,
      );

      final firstQuestion = await _service!.startSession();
      if (!mounted) return;

      state = state.copyWith(
        phase: InterviewPhase.waiting,
        currentQuestion: firstQuestion,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        phase: InterviewPhase.error,
        error: _extractMessage(e),
      );
    }
  }

  Future<void> startAnswering() async {
    final initialized = await _speechService.initialize();
    if (!mounted) return;

    if (!initialized) {
      state = state.copyWith(
        phase: InterviewPhase.error,
        error: 'Speech recognition is not available on this device.',
      );
      return;
    }

    state = state.copyWith(
      phase: InterviewPhase.recording,
      transcript: '',
      partialText: '',
      elapsedSeconds: 0,
      lastRecordingPath: null,
    );

    // Start audio recording alongside STT — non-critical; if it fails, the
    // session continues and the playback section simply won't appear.
    try {
      await _audioService.start();
    } catch (e) {
      log('InterviewNotifier: audio recording start failed (non-critical): $e');
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });

    await _speechService.startContinuous((text, isFinal) {
      if (!mounted || state.phase != InterviewPhase.recording) return;
      if (isFinal) {
        final accumulated =
            state.transcript.isEmpty ? text : '${state.transcript} $text';
        state = state.copyWith(transcript: accumulated.trim(), partialText: '');
      } else {
        state = state.copyWith(partialText: text);
      }
    });
  }

  Future<void> stopAnswering() async {
    _timer?.cancel();
    _timer = null;
    await _speechService.stop();

    // Stop audio recording — returns null gracefully on failure.
    String? recordingPath;
    try {
      recordingPath = await _audioService.stop();
    } catch (e) {
      log('InterviewNotifier: audio recording stop failed (non-critical): $e');
    }

    final sttTranscript = state.fullTranscript;

    // Bail early only when both STT and audio recording produced nothing.
    if (sttTranscript.isEmpty && recordingPath == null) {
      state = state.copyWith(phase: InterviewPhase.waiting, partialText: '');
      return;
    }

    // Defensive guard — phase gating means this is always non-null in recording
    // phase, but an explicit check prevents a silent crash if that ever changes.
    final currentQuestion = state.currentQuestion;
    if (currentQuestion == null) return;

    // Write recording path into state immediately so it survives into both the
    // feedback transition (success) and the error state (retry), without
    // needing to thread it through _submitToApi as a parameter.
    state = state.copyWith(
      phase: InterviewPhase.processing,
      partialText: '',
      lastRecordingPath: recordingPath,
    );

    await _submitToApi(
      question: currentQuestion,
      sttFallback: sttTranscript,
      isLast: state.isLastQuestion,
      audioPath: recordingPath,
    );
  }

  /// Re-tries the appropriate operation after an error without losing progress.
  ///
  /// If the error happened mid-session (STT transcript or recording present,
  /// service still alive) the last answer is re-submitted — audio is re-sent
  /// if the file still exists.  If it was an initialization failure the session
  /// restarts from scratch.
  Future<void> retryFromError() async {
    final sttFallback = state.transcript;
    final currentQuestion = state.currentQuestion;

    final hasContent =
        sttFallback.isNotEmpty || state.lastRecordingPath != null;

    if (hasContent && currentQuestion != null && _service != null) {
      state = state.copyWith(phase: InterviewPhase.processing);
      await _submitToApi(
        question: currentQuestion,
        sttFallback: sttFallback,
        isLast: state.isLastQuestion,
        audioPath: state.lastRecordingPath,
      );
      return;
    }

    await initialize(mode: state.mode, questionCount: state.targetQuestions);
  }

  /// Sends the answer to Gemini and transitions state on both success and
  /// failure.  When [audioPath] is provided the audio is evaluated directly;
  /// [sttFallback] is used if the audio is unavailable or encoding fails.
  Future<void> _submitToApi({
    required InterviewQuestion question,
    required String sttFallback,
    required bool isLast,
    String? audioPath,
  }) async {
    // Guard against a null service — can happen if initialization failed and
    // somehow _submitToApi is reached (e.g. concurrent state transition). Show
    // an error rather than crashing with a null-dereference.
    if (_service == null) {
      state = state.copyWith(
        phase: InterviewPhase.error,
        error: 'Session expired — please restart the interview.',
      );
      return;
    }

    try {
      final result = await _service!.submitAnswer(
        isLastQuestion: isLast,
        audioPath: audioPath,
        sttFallback: sttFallback,
      );

      if (!mounted) return;

      final turn = InterviewTurn(
        question: question,
        transcript: result.transcript,
        evaluation: result.eval,
      );
      final updatedTurns = [...state.completedTurns, turn];

      // Persist when the final evaluation arrives so the same object (with the
      // same UUID) is available to both the results screen and the history list.
      CompletedInterview? saved;
      if (result.finalEval != null) {
        saved = CompletedInterview(
          mode: state.mode,
          targetQuestions: state.targetQuestions,
          turns: updatedTurns,
          evaluation: result.finalEval!,
        );
        try {
          await _repository.save(saved);
          if (!mounted) return;
          _ref.read(interviewHistoryProvider.notifier).refresh();
        } catch (e) {
          // Persistence failure is non-critical — the session can still
          // complete and the user can view the results screen.
          log('InterviewNotifier: failed to persist session: $e');
        }
      }

      if (!mounted) return;

      state = state.copyWith(
        phase: InterviewPhase.feedback,
        completedTurns: updatedTurns,
        lastEvaluation: result.eval,
        currentQuestion: result.nextQuestion,
        finalEvaluation: result.finalEval,
        completedInterview: saved,
        // lastRecordingPath intentionally omitted — sentinel keeps the value
        // written when entering processing phase, so it's present on first
        // attempt and on retry without any extra plumbing.
        transcript: '',
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        phase: InterviewPhase.error,
        error: _extractMessage(e),
      );
    }
  }

  void proceedToNextQuestion() {
    // Capture the path before clearing state so we can delete the file after
    // the UI has already moved away from the feedback view (and the audio
    // player is no longer holding the file open).
    final oldRecordingPath = state.lastRecordingPath;
    state = state.copyWith(
      phase: InterviewPhase.waiting,
      elapsedSeconds: 0,
      lastEvaluation: null,
      lastRecordingPath: null,
    );
    if (oldRecordingPath != null) {
      unawaited(Future(() async {
        try {
          await File(oldRecordingPath).delete();
        } catch (_) {}
      }));
    }
  }

  static String _extractMessage(Object e) {
    if (e is Exception) {
      final msg = e.toString();
      return msg.startsWith('Exception: ')
          ? msg.substring('Exception: '.length)
          : msg;
    }
    return e.toString();
  }

  @override
  void dispose() {
    _timer?.cancel();
    // stop() is async; unawaited because dispose() must be synchronous.
    unawaited(_speechService.stop());
    _service?.close();
    // Delete the last recording file if the user leaves before proceeding to
    // the next question (e.g. taps the close button on the feedback screen).
    final lastPath = state.lastRecordingPath;
    if (lastPath != null) {
      unawaited(Future(() async {
        try {
          await File(lastPath).delete();
        } catch (_) {}
      }));
    }
    _audioService.dispose();
    super.dispose();
  }
}

// ── Provider — autoDispose so SpeechService + Timer + http.Client are freed ──

final interviewProvider =
    StateNotifierProvider.autoDispose<InterviewNotifier, InterviewState>(
  (ref) => InterviewNotifier(
    speechService: SpeechService(),
    audioService: AudioRecordingService(),
    repository: ref.read(interviewRepositoryProvider),
    ref: ref,
  ),
);
