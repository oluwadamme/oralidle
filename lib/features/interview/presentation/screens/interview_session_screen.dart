import 'dart:async';
import 'dart:developer' show log;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/category_badge.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/score_meter.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/waveform_loader.dart';
import '../../../recording/presentation/widgets/waveform_animation.dart';
import '../../../recording/providers/recording_provider.dart';
import '../../data/models/interview_models.dart';
import '../../../../core/services/speech/audio_capture_service.dart';
import '../../providers/interview_provider.dart';
import '../utils/interview_ui_utils.dart';
import '../../../../core/utils/responsive.dart';

class InterviewSessionScreen extends ConsumerStatefulWidget {
  final InterviewSetup setup;

  const InterviewSessionScreen({super.key, required this.setup});

  @override
  ConsumerState<InterviewSessionScreen> createState() =>
      _InterviewSessionScreenState();
}

class _InterviewSessionScreenState
    extends ConsumerState<InterviewSessionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(interviewProvider.notifier)
          .initialize(
            mode: widget.setup.mode,
            questionCount: widget.setup.questionCount,
            customCvContent: widget.setup.customCvContent,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(interviewProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit(context);
      },
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(context, state),
                  Expanded(child: _buildBody(context, state)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, InterviewState state) {
    final total = widget.setup.questionCount;
    // In the feedback phase the last turn has already been appended, so
    // currentQuestionNumber (= completedTurns.length + 1) overshoots by one.
    // Show the number of the question that was just answered instead.
    final current = switch (state.phase) {
      InterviewPhase.loading => 1,
      InterviewPhase.feedback => state.completedTurns.length.clamp(1, total),
      _ => state.currentQuestionNumber.clamp(1, total),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.x, color: AppColors.inkMuted),
            onPressed: () => _confirmExit(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Mock Interview',
                  style: context.cardTitle.copyWith(
                    color: AppColors.ink,
                    fontWeight: AppFontWeight.w700,
                  ),
                ),
                if (state.phase != InterviewPhase.loading)
                  Text(
                    'Q$current of $total  ·  ${widget.setup.mode.label}',
                    style: context.overline.copyWith(color: AppColors.inkMuted),
                  ),
              ],
            ),
          ),
          if (state.phase != InterviewPhase.loading)
            _ProgressDots(
              total: total,
              completed: state.completedTurns.length,
              current: current - 1,
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, InterviewState state) {
    switch (state.phase) {
      case InterviewPhase.loading:
        return const _LoadingView();

      case InterviewPhase.error:
        return _ErrorView(
          message: state.error ?? 'Something went wrong.',
          onRetry: () => ref.read(interviewProvider.notifier).retryFromError(),
        );

      case InterviewPhase.waiting:
      case InterviewPhase.recording:
      case InterviewPhase.finalising:
      case InterviewPhase.processing:
        return _QuestionView(
          question: state.currentQuestion,
          phase: state.phase,
          transcript: state.transcript,
          elapsedSeconds: state.elapsedSeconds,
        );

      case InterviewPhase.feedback:
        // Both fields are set by the provider before transitioning to this
        // phase, but guard defensively so any future state-shape change
        // surfaces as an empty loading view rather than a crash.
        final lastTurn = state.completedTurns.lastOrNull;
        final eval = state.lastEvaluation;
        if (lastTurn == null || eval == null) return const _LoadingView();
        return _FeedbackView(
          turn: lastTurn,
          evaluation: eval,
          isFinal: state.finalEvaluation != null,
          recordingAudio: state.lastRecordingAudio,
          onNext: state.finalEvaluation != null
              ? () => _navigateToResults(state)
              : () => ref
                    .read(interviewProvider.notifier)
                    .proceedToNextQuestion(),
        );
    }
  }

  void _navigateToResults(InterviewState state) {
    // Use the persisted instance so the results screen carries the same id
    // as the Hive record, enabling direct re-entry from history.
    // Falls back to a fresh instance only if persistence failed.
    final completed =
        state.completedInterview ??
        CompletedInterview(
          mode: state.mode,
          targetQuestions: state.targetQuestions,
          turns: state.completedTurns,
          evaluation: state.finalEvaluation!,
        );
    context.pushReplacement(AppRoutes.interviewResults, extra: completed);
  }

  Future<void> _confirmExit(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.raised2,
        title: const Text('End Interview?'),
        content: const Text(
          'Your progress will be lost and the interview will end.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Continue',
              style: TextStyle(color: AppColors.inkMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'End',
              style: TextStyle(color: AppColors.critical),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.go(AppRoutes.interview);
    }
  }
}

// ── Loading ───────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WaveformLoader.hero(
            height: 38,
            barCount: 16,
            barWidth: 4,
            barSpacing: 3,
          ),
          SizedBox(height: 20),
          Text(
            'Preparing your interview…',
            style: context.cardTitle.copyWith(color: AppColors.ink),
          ),
          SizedBox(height: 8),
          Text(
            'Reading your CV and crafting questions',
            style: context.caption.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.alertCircle,
              size: 48,
              color: AppColors.critical,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.body.copyWith(color: AppColors.ink, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.rotateCcw),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Active question (waiting / recording / processing) ────────────────────────
//
// Takes explicit fields rather than the full InterviewState so this widget
// stays decoupled from state shape changes unrelated to what it displays.

class _QuestionView extends ConsumerWidget {
  final InterviewQuestion? question;
  final InterviewPhase phase;

  /// Live on-device preview; empty where no on-device engine exists (web) or
  /// while the model is still downloading.
  final String transcript;
  final int elapsedSeconds;

  const _QuestionView({
    required this.question,
    required this.phase,
    required this.transcript,
    required this.elapsedSeconds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minutes = elapsedSeconds ~/ 60;
    final seconds = elapsedSeconds % 60;
    final isRecording = phase == InterviewPhase.recording;
    final isFinalising = phase == InterviewPhase.finalising;
    final isProcessing = phase == InterviewPhase.processing;
    // The mic is already closed while finalising, so the controls behave as
    // they do during processing: visible progress, nothing to tap.
    final isBusy = isFinalising || isProcessing;

    return ResponsiveContainer(
      horizontalPadding: 24,
      child: Column(
        children: [
          const SizedBox(height: 12),

          if (question != null) _TypeBadge(type: question!.type),

          const SizedBox(height: 16),

          SurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Text(
              question?.text ?? '',
              style: context.cardTitle.copyWith(
                color: AppColors.ink,
                height: 1.5,
              ),
            ),
          ),

          const Spacer(),

          if ((isRecording || isFinalising) && transcript.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 100),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.raised2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  transcript,
                  style: context.caption.copyWith(
                    color: AppColors.inkMuted,
                    height: 1.45,
                  ),
                ),
              ),
            ),

          if ((isRecording || isFinalising) && transcript.isNotEmpty)
            const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isRecording
                    ? LucideIcons.activity
                    : isBusy
                    ? LucideIcons.hourglass
                    : LucideIcons.mic,
                size: 14,
                color: isRecording || isFinalising
                    ? AppColors.ink
                    : AppColors.borderControl,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  isProcessing
                      ? 'Evaluating your answer…'
                      : isFinalising
                      ? 'Finishing up…'
                      : isRecording
                      ? 'Recording  $minutes:${seconds.toString().padLeft(2, '0')}'
                            ' / ${InterviewNotifier.maxAnswerSeconds ~/ 60}:'
                            '${(InterviewNotifier.maxAnswerSeconds % 60).toString().padLeft(2, '0')}'
                      : 'Tap the mic to answer',
                  textAlign: TextAlign.center,
                  style: context.caption.copyWith(
                    color: isRecording || isFinalising
                        ? AppColors.ink
                        : AppColors.borderControl,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          WaveformAnimation(
            isActive: isRecording,
            level: ref.watch(micLevelProvider).valueOrNull ?? 0,
          ),

          const SizedBox(height: 20),

          if (!isBusy)
            Pressable(
              onTap: isRecording
                  ? () => ref.read(interviewProvider.notifier).stopAnswering()
                  : () => ref.read(interviewProvider.notifier).startAnswering(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRecording ? AppColors.critical : AppColors.ink,
                ),
                child: Icon(
                  isRecording ? LucideIcons.square : LucideIcons.mic,
                  color: isRecording ? AppColors.ink : AppColors.onAction,
                  size: 34,
                ),
              ),
            )
          else
            const SizedBox(
              width: 76,
              height: 76,
              child: Center(
                child: WaveformLoader.compact(
                  height: 28,
                  barCount: 5,
                  barWidth: 3.5,
                  barSpacing: 3,
                  color: AppColors.ink,
                ),
              ),
            ),

          const SizedBox(height: 10),
          Text(
            // isBusy, not isProcessing: while finalising there is a spinner
            // where the button was, so "Tap to start answering" would be
            // telling the user to press something that isn't there.
            isBusy
                ? 'Please wait…'
                : isRecording
                ? 'Tap to stop when done'
                : 'Tap to start answering',
            style: context.caption.copyWith(color: AppColors.inkMuted),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Feedback ──────────────────────────────────────────────────────────────────
//
// Takes the completed turn + evaluation explicitly rather than the full state.

class _FeedbackView extends StatelessWidget {
  final InterviewTurn turn;
  final TurnEvaluation evaluation;
  final bool isFinal;
  final CapturedAudio? recordingAudio;
  final VoidCallback onNext;

  const _FeedbackView({
    required this.turn,
    required this.evaluation,
    required this.isFinal,
    this.recordingAudio,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = AppColors.ink;

    return SingleChildScrollView(
      padding: centeredPagePadding(
        MediaQuery.sizeOf(context).width,
        maxContentWidth: Breakpoints.contentMaxWidth,
        minHorizontal: 24,
        top: 12,
        bottom: 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TypeBadge(type: turn.question.type),
          const SizedBox(height: 10),
          SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Text(
              turn.question.text,
              style: context.cardTitle.copyWith(
                color: AppColors.ink,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Score + feedback ──────────────────────────────────────────────
          SurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ANSWER QUALITY', style: context.overline),
                          const SizedBox(height: Space.sm),
                          ScoreMeter(
                            score: evaluation.contentScore,
                            size: ScoreMeterSize.card,
                            caption: _scoreLabel(evaluation.contentScore),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.line, height: 1),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LucideIcons.messageSquare,
                      size: 14,
                      color: scoreColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        evaluation.feedback,
                        style: context.body.copyWith(
                          color: AppColors.ink,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Your answer (transcript + optional audio playback) ────────────
          SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'YOUR ANSWER',
                        style: context.overline.copyWith(
                          color: AppColors.inkMuted,
                          fontWeight: AppFontWeight.w700,
                        ),
                      ),
                    ),
                    if (recordingAudio != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.raised2,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.borderControl),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.headphones,
                              size: 10,
                              color: AppColors.ink,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Recording',
                              style: context.overline.copyWith(
                                color: AppColors.ink,
                                fontWeight: AppFontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (recordingAudio != null) ...[
                  const SizedBox(height: 14),
                  _AudioPlayerWidget(audio: recordingAudio!),
                  const SizedBox(height: 14),
                  const Divider(color: AppColors.line, height: 1),
                ],
                const SizedBox(height: 10),
                Text(
                  turn.transcript,
                  style: context.caption.copyWith(
                    color: AppColors.inkMuted,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          // ── Alex's ideal answer (only when score < 80) ───────────────────
          if (evaluation.modelAnswer != null) ...[
            const SizedBox(height: 16),
            _ModelAnswerCard(answer: evaluation.modelAnswer!),
          ],

          const SizedBox(height: 28),

          // ── Next / results button ─────────────────────────────────────────
          Pressable(
            onTap: onNext,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.action,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isFinal ? LucideIcons.barChart2 : LucideIcons.arrowRight,
                    color: AppColors.onAction,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isFinal ? 'See Final Results' : 'Next Question',
                    style: context.cardTitle.copyWith(
                      color: AppColors.onAction,
                      fontWeight: AppFontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _scoreLabel(int s) {
    if (s >= 85) return 'Excellent';
    if (s >= 70) return 'Strong Answer';
    if (s >= 55) return 'Good Start';
    if (s >= 40) return 'Needs Work';
    return 'Keep Practising';
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final QuestionType type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CategoryBadge(label: type.label, icon: type.icon),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int total;
  final int completed;
  final int current;

  const _ProgressDots({
    required this.total,
    required this.completed,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final isDone = i < completed;
        final isCurrent = i == current && !isDone;
        return Container(
          width: isCurrent ? 12 : 6,
          height: 6,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: isDone
                ? AppColors.positive
                : isCurrent
                ? AppColors.ink
                : AppColors.line,
          ),
        );
      }),
    );
  }
}

// ── Audio playback ────────────────────────────────────────────────────────────

class _AudioPlayerWidget extends StatefulWidget {
  final CapturedAudio audio;

  const _AudioPlayerWidget({required this.audio});

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  late final AudioPlayer _player;
  // Held so we can cancel explicitly in dispose() — belt-and-suspenders
  // alongside _player.dispose(), which closes the streams, but explicit
  // cancellation makes intent clear and guards against API changes.
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerState _playerState = PlayerState.stopped;
  bool _isReady = false;
  bool _hasError = false;
  // Tracks whether the user is actively dragging the slider so that incoming
  // position updates from the player don't fight the drag gesture.
  bool _isSeeking = false;
  double _seekValue = 0.0;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    unawaited(_player.setVolume(1.0));
    _subscriptions.addAll([
      _player.onPositionChanged.listen(_onPosition),
      _player.onDurationChanged.listen(_onDuration),
      _player.onPlayerStateChanged.listen(_onState),
      _player.onPlayerComplete.listen(_onComplete),
    ]);
    _loadSource();
  }

  void _onPosition(Duration pos) {
    if (mounted && !_isSeeking) setState(() => _position = pos);
  }

  void _onDuration(Duration dur) {
    if (mounted) setState(() => _duration = dur);
  }

  void _onState(PlayerState s) {
    if (mounted) setState(() => _playerState = s);
  }

  void _onComplete(void _) {
    unawaited(_player.seek(Duration.zero));
    if (mounted) {
      setState(() {
        _playerState = PlayerState.stopped;
        _position = Duration.zero;
      });
    }
  }

  Future<void> _loadSource() async {
    try {
      await _player.setVolume(1.0);
      await _player.setSource(
        BytesSource(
          widget.audio.playbackBytes,
          mimeType: widget.audio.mimeType,
        ),
      );
      if (mounted) setState(() => _isReady = true);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  Future<void> _togglePlay() async {
    try {
      await _player.setVolume(1.0);
      if (_playerState == PlayerState.playing) {
        await _player.pause();
      } else if (_playerState == PlayerState.paused) {
        await _player.resume();
      } else {
        await _player.play(
          BytesSource(
            widget.audio.playbackBytes,
            mimeType: widget.audio.mimeType,
          ),
        );
      }
    } catch (e) {
      log('AudioPlayerWidget: play error: $e');
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Row(
        children: [
          Icon(LucideIcons.alertCircle, size: 15, color: AppColors.inkMuted),
          SizedBox(width: 6),
          Text(
            'Playback unavailable',
            style: context.caption.copyWith(color: AppColors.inkMuted),
          ),
        ],
      );
    }

    if (!_isReady) {
      return const SizedBox(
        height: 44,
        child: Center(
          child: WaveformLoader.compact(
            height: 16,
            barCount: 4,
            barWidth: 2.5,
            color: AppColors.inkMuted,
          ),
        ),
      );
    }

    final isPlaying = _playerState == PlayerState.playing;
    final maxMs = _duration.inMilliseconds;
    final progress = maxMs > 0
        ? (_position.inMilliseconds / maxMs).clamp(0.0, 1.0)
        : 0.0;

    return Row(
      children: [
        Pressable(
          onTap: _togglePlay,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.raised2,
              border: Border.all(color: AppColors.borderControl),
            ),
            child: Icon(
              isPlaying ? LucideIcons.pause : LucideIcons.play,
              color: AppColors.ink,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                  activeTrackColor: AppColors.ink,
                  inactiveTrackColor: AppColors.line,
                  thumbColor: AppColors.ink,
                  overlayColor: AppColors.borderControl,
                ),
                child: Slider(
                  value: _isSeeking ? _seekValue : progress,
                  onChangeStart: (double v) => setState(() {
                    _isSeeking = true;
                    _seekValue = v;
                  }),
                  onChanged: (double v) => setState(() => _seekValue = v),
                  onChangeEnd: (double v) {
                    setState(() => _isSeeking = false);
                    _player.seek(Duration(milliseconds: (v * maxMs).round()));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fmt(_position),
                      style: context.overline.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                    Text(
                      _fmt(_duration),
                      style: context.overline.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── AI ideal answer (shown when content score < 80) ───────────────────────────

class _ModelAnswerCard extends StatefulWidget {
  final String answer;

  const _ModelAnswerCard({required this.answer});

  @override
  State<_ModelAnswerCard> createState() => _ModelAnswerCardState();
}

class _ModelAnswerCardState extends State<_ModelAnswerCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pressable(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.raised2,
                  ),
                  child: const Icon(
                    LucideIcons.sparkles,
                    size: 13,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "ALEX'S IDEAL ANSWER",
                    style: context.overline.copyWith(
                      color: AppColors.ink,
                      fontWeight: AppFontWeight.w700,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    LucideIcons.chevronDown,
                    size: 18,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(color: AppColors.line, height: 1),
                        const SizedBox(height: 12),
                        Text(
                          widget.answer,
                          style: context.body.copyWith(
                            color: AppColors.ink,
                            height: 1.65,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
