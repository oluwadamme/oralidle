import 'dart:async';
import 'dart:developer' show log;

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/interview_models.dart';
import '../data/repositories/interview_repository.dart';
import '../services/interview_service.dart';
import '../../../core/config/ai_endpoint.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/analytics/analytics_service.dart';
import '../../../core/services/speech/audio_capture_service.dart';
import '../../../core/services/speech/speech_providers.dart';
import '../../../core/services/speech/speech_recognition_service.dart';
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

enum InterviewPhase {
  loading,
  waiting,
  recording,

  /// Microphone released; the last on-device window is still decoding.
  ///
  /// Draining that queue can take a second or two. Without a phase of its own
  /// the UI stayed in [recording] with a stopped timer and a dead waveform,
  /// which reads as a hang.
  finalising,
  processing,
  feedback,
  error,
}

class InterviewState {
  final InterviewMode mode;
  final int targetQuestions;
  final List<InterviewTurn> completedTurns;
  final InterviewQuestion? currentQuestion;

  /// Live on-device transcript for the answer in progress.
  ///
  /// A preview only — the authoritative transcript comes back from Gemini,
  /// which hears the audio itself. Empty on platforms with no on-device
  /// engine, which is why nothing downstream depends on it being populated.
  final String transcript;
  final int elapsedSeconds;
  final InterviewPhase phase;
  final TurnEvaluation? lastEvaluation;
  final InterviewEvaluation? finalEvaluation;
  // Set when the session completes and is persisted. Passed to results screen
  // so it carries the same id as the Hive record.
  final CompletedInterview? completedInterview;

  /// Audio for the most recent answer, held in memory so the same bytes serve
  /// both playback and the Gemini upload on every platform including web.
  /// Cleared when moving to the next question.
  final CapturedAudio? lastRecordingAudio;
  final String? error;

  const InterviewState({
    this.mode = InterviewMode.mixed,
    this.targetQuestions = 5,
    this.completedTurns = const [],
    this.currentQuestion,
    this.transcript = '',
    this.elapsedSeconds = 0,
    this.phase = InterviewPhase.loading,
    this.lastEvaluation,
    this.finalEvaluation,
    this.completedInterview,
    this.lastRecordingAudio,
    this.error,
  });

  InterviewState copyWith({
    InterviewMode? mode,
    int? targetQuestions,
    List<InterviewTurn>? completedTurns,
    Object? currentQuestion = _absent,
    String? transcript,
    int? elapsedSeconds,
    InterviewPhase? phase,
    Object? lastEvaluation = _absent,
    Object? finalEvaluation = _absent,
    Object? completedInterview = _absent,
    Object? lastRecordingAudio = _absent,
    Object? error = _absent,
  }) => InterviewState(
    mode: mode ?? this.mode,
    targetQuestions: targetQuestions ?? this.targetQuestions,
    completedTurns: completedTurns ?? this.completedTurns,
    currentQuestion: identical(currentQuestion, _absent)
        ? this.currentQuestion
        : currentQuestion as InterviewQuestion?,
    transcript: transcript ?? this.transcript,
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
    lastRecordingAudio: identical(lastRecordingAudio, _absent)
        ? this.lastRecordingAudio
        : lastRecordingAudio as CapturedAudio?,
    error: identical(error, _absent) ? this.error : error as String?,
  );

  bool get isLastQuestion => completedTurns.length + 1 == targetQuestions;
  int get currentQuestionNumber => completedTurns.length + 1;
  bool get isRecording => phase == InterviewPhase.recording;
  bool get isFinalising => phase == InterviewPhase.finalising;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class InterviewNotifier extends StateNotifier<InterviewState> {
  InterviewNotifier({
    required this._recognition,
    required this._capture,
    required this._repository,
    required this._ref,
  }) : super(const InterviewState());

  /// Hard cap on a single answer.
  ///
  /// Not a product preference: the answer is uploaded as base64 audio, and the
  /// serverless proxy rejects request bodies over 4.5 MB. Three minutes of
  /// µ-law comes to ~3.7 MB encoded, which fits with room for the conversation
  /// history; five minutes would be ~6.1 MB and fail.
  static const maxAnswerSeconds = 180;

  final SpeechRecognitionService _recognition;
  final AudioCaptureService _capture;
  final InterviewRepository _repository;
  final Ref _ref;
  InterviewService? _service;
  Timer? _timer;

  Future<void> initialize({
    required InterviewMode mode,
    required int questionCount,
    String? customCvContent,
  }) async {
    _ref
        .read(analyticsProvider)
        .track(AnalyticsService.interviewStarted, {
          'mode': mode.name,
          'question_count': questionCount,
          'custom_cv': customCvContent != null,
        });

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

    unawaited(_recognition.prepare());

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? AiEndpoint.localApiKey;
      if (AiEndpoint.requiresApiKey && apiKey.isEmpty) {
        if (AiEndpoint.isLocalWeb) {
          throw Exception(
            'GEMINI_API_KEY is missing from .env for local web testing.\n'
            'Add GEMINI_API_KEY to your .env file, or run `vercel dev` and launch with `--dart-define=API_PROXY_BASE=http://localhost:3000`.',
          );
        }
        throw Exception('GEMINI_API_KEY is not configured in .env');
      }

      final results = await Future.wait([
        _ref.read(cvContentProvider.future),
        _ref.read(skillsContentProvider.future),
      ]);

      if (!mounted) return;

      final customCv = customCvContent?.trim();
      final effectiveCv = (customCv != null && customCv.isNotEmpty)
          ? customCv
          : results[0];

      _service = InterviewService(
        apiKey: apiKey,
        cvContent: effectiveCv,
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
    final started = await _capture.start();
    if (!mounted) return;

    if (!started) {
      state = state.copyWith(
        phase: InterviewPhase.error,
        error: 'Microphone unavailable. Grant microphone access and try again.',
      );
      return;
    }

    state = state.copyWith(
      phase: InterviewPhase.recording,
      transcript: '',
      elapsedSeconds: 0,
      lastRecordingAudio: null,
      error: null,
    );

    if (_recognition.state.isReady) {
      await _recognition.listen(_capture.pcmStream, (transcript) {
        if (!mounted || state.phase != InterviewPhase.recording) return;
        state = state.copyWith(transcript: transcript);
      });
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = state.elapsedSeconds + 1;
      if (next >= maxAnswerSeconds) {
        t.cancel();
        unawaited(stopAnswering());
      } else {
        state = state.copyWith(elapsedSeconds: next);
      }
    });
  }

  Future<void> stopAnswering() async {
    // Guards a double tap and a tap that races the phase change; without it a
    // second call would stop an already-stopped capture and submit twice.
    if (state.phase != InterviewPhase.recording) return;

    _timer?.cancel();
    _timer = null;

    // Show the wait before taking it. Everything below is asynchronous and
    // can run for seconds.
    state = state.copyWith(phase: InterviewPhase.finalising);

    // Release the microphone before draining the recogniser, so the mic
    // indicator clears promptly even if the final decode takes a moment.
    final audio = await _capture.stop();

    // Commit the recording to state as soon as it exists, ahead of the longer
    // transcript drain. Anything that goes wrong after this point — an error,
    // a retry — still has the audio to work with.
    if (mounted && audio != null) {
      state = state.copyWith(lastRecordingAudio: audio);
    }

    final sttTranscript = await _recognition.finish();

    if (!mounted) {
      log('InterviewNotifier: disposed while finalising — answer discarded');
      return;
    }

    // Bail early only when both the recording and the transcript are empty.
    if (sttTranscript.isEmpty && (audio == null || audio.isEmpty)) {
      state = state.copyWith(
        phase: InterviewPhase.waiting,
        error: 'Nothing was recorded. Check your microphone and try again.',
      );
      return;
    }

    // Defensive guard — phase gating means this is always non-null in the
    // recording phase. A bare `return` here would be worse than the crash it
    // prevents: the UI would be stranded on the finalising spinner, which has
    // no button to escape from. Surface it instead.
    final currentQuestion = state.currentQuestion;
    if (currentQuestion == null) {
      state = state.copyWith(
        phase: InterviewPhase.error,
        error:
            'Lost track of the current question. Please restart the '
            'interview.',
      );
      return;
    }

    state = state.copyWith(phase: InterviewPhase.processing);

    await _submitToApi(
      question: currentQuestion,
      sttFallback: sttTranscript,
      isLast: state.isLastQuestion,
      audio: audio,
    );
  }

  /// Re-tries the appropriate operation after an error without losing progress.
  ///
  /// If the error happened mid-session (transcript or recording present,
  /// service still alive) the last answer is re-submitted.  If it was an
  /// initialization failure the session restarts from scratch.
  Future<void> retryFromError() async {
    final sttFallback = state.transcript;
    final currentQuestion = state.currentQuestion;

    final hasContent =
        sttFallback.isNotEmpty || state.lastRecordingAudio != null;

    if (hasContent && currentQuestion != null && _service != null) {
      state = state.copyWith(phase: InterviewPhase.processing);
      await _submitToApi(
        question: currentQuestion,
        sttFallback: sttFallback,
        isLast: state.isLastQuestion,
        audio: state.lastRecordingAudio,
      );
      return;
    }

    await initialize(mode: state.mode, questionCount: state.targetQuestions);
  }

  /// Sends the answer to Gemini and transitions state on both success and
  /// failure.  When [audio] is provided it is evaluated directly;
  /// [sttFallback] is used if the audio is unavailable or encoding fails.
  Future<void> _submitToApi({
    required InterviewQuestion question,
    required String sttFallback,
    required bool isLast,
    CapturedAudio? audio,
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
        audioBytes: audio?.uploadBytes,
        audioMimeType: audio?.mimeType ?? 'audio/wav',
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
          unawaited(
            _ref.read(syncServiceProvider)?.syncNow(),
          );
          _ref
              .read(analyticsProvider)
              .track(AnalyticsService.interviewCompleted, {
                'mode': saved.mode.name,
                'question_count': saved.targetQuestions,
                'turns_answered': saved.turns.length,
              });
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
        // lastRecordingAudio intentionally omitted — the sentinel keeps the
        // value written when entering processing phase, so it's present on
        // first attempt and on retry without any extra plumbing.
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
    // Dropping the reference is all the cleanup the audio needs now that it
    // lives in memory rather than in a temp file.
    state = state.copyWith(
      phase: InterviewPhase.waiting,
      elapsedSeconds: 0,
      lastEvaluation: null,
      lastRecordingAudio: null,
    );
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
    // Both are async; unawaited because dispose() must be synchronous. The
    // recogniser is app-lifetime and only detached here, while the capture
    // service is disposed by its own autoDispose provider.
    unawaited(_recognition.abort());
    unawaited(_capture.cancel());
    _service?.close();
    super.dispose();
  }
}

// ── Provider — autoDispose so the capture service + Timer + http.Client are
// released as soon as the interview screen goes away ─────────────────────────

final interviewProvider =
    StateNotifierProvider.autoDispose<InterviewNotifier, InterviewState>(
      (ref) => InterviewNotifier(
        recognition: ref.watch(speechRecognitionServiceProvider),
        capture: ref.watch(audioCaptureServiceProvider),
        repository: ref.read(interviewRepositoryProvider),
        ref: ref,
      ),
    );
