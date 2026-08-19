import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../topic_selection/data/models/topic.dart';
import '../../providers/recording_provider.dart';
import '../widgets/waveform_animation.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/services/speech/speech_providers.dart';
import '../../../../core/services/speech/speech_recognition_service.dart';

class RecordingScreen extends ConsumerStatefulWidget {
  final Topic topic;
  const RecordingScreen({super.key, required this.topic});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recordingProvider.notifier).startRecording(widget.topic);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingProvider);
    final micLevel = ref.watch(micLevelProvider).valueOrNull ?? 0.0;
    final engineState = ref.watch(speechEngineStateProvider).valueOrNull;

    ref.listen(recordingProvider, (prev, next) {
      if (next.status == RecordingStatus.stopped &&
          next.completedSession != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          context.pushReplacement(
            AppRoutes.processing,
            extra: next.completedSession,
          );
          ref.read(recordingProvider.notifier).reset();
        });
      } else if (next.status == RecordingStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.errorMessage ?? 'Speech recognition unavailable',
            ),
            backgroundColor: AppColors.poor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });

    final elapsed = state.elapsedSeconds;
    final minutes = elapsed ~/ 60;
    final seconds = elapsed % 60;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmStop(context);
      },
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned(
              top: -60,
              right: -40,
              child: AmbientOrb(color: AppColors.primary, size: 240),
            ),
            const Positioned(
              bottom: 80,
              left: -60,
              child: AmbientOrb(color: AppColors.amber, size: 200),
            ),
            SafeArea(
              child: Column(
                children: [
                  // ── Header ─────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textMedium,
                          ),
                          onPressed: () => _confirmStop(context),
                        ),
                        const Expanded(
                          child: Text(
                            'Lumina Speech',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ResponsiveContainer(
                      child: Column(
                        children: [
                          const SizedBox(height: 16),

                          // ── Category badge ──────────────────────────────
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.amber.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.amber,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  widget.topic.category.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.amber,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // ── Topic title ─────────────────────────────────
                          Text(
                            widget.topic.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              height: 1.35,
                            ),
                          ),

                          const Spacer(),

                          // ── AI listening indicator ──────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                state.isFinalising
                                    ? Icons.hourglass_top_rounded
                                    : Icons.graphic_eq_rounded,
                                size: 14,
                                color: state.isRecording || state.isFinalising
                                    ? AppColors.primary
                                    : AppColors.outline,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _statusLabel(state, engineState),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        state.isRecording || state.isFinalising
                                        ? AppColors.primary
                                        : AppColors.outline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // ── Large timer ─────────────────────────────────
                          Text(
                            '$minutes:${seconds.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: context.isShort ? 52 : 72,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                              letterSpacing: -3,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            elapsed < AppConstants.minRecordingSeconds
                                ? 'Min 1:00 to stop'
                                : 'Tap the mic to stop',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMedium,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Waveform ────────────────────────────────────
                          // Driven by the real microphone level, so a flat
                          // row means the mic is picking nothing up rather
                          // than the animation having stopped.
                          WaveformAnimation(
                            isActive: state.isRecording,
                            level: micLevel,
                            height: context.isShort ? 44 : 60,
                          ),

                          if (state.transcript.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Container(
                              constraints: BoxConstraints(
                                maxHeight: context.isShort ? 64 : 96,
                              ),
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceHigh,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: SingleChildScrollView(
                                reverse: true,
                                child: Text(
                                  state.transcript,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMedium,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          const Spacer(),

                          // ── Mic / stop button ───────────────────────────
                          GestureDetector(
                            onTap: state.canStop && !state.isFinalising
                                ? () => ref
                                      .read(recordingProvider.notifier)
                                      .stopManually()
                                : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: state.canStop
                                    ? AppColors.poor
                                    : AppColors.primary,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (state.canStop
                                                ? AppColors.poor
                                                : AppColors.primary)
                                            .withValues(alpha: 0.45),
                                    blurRadius: 32,
                                    spreadRadius: 6,
                                  ),
                                ],
                              ),
                              child: Icon(
                                state.canStop
                                    ? Icons.stop_rounded
                                    : Icons.mic_rounded,
                                color: state.canStop
                                    ? Colors.white
                                    : const Color(0xFF490080),
                                size: 38,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            state.isFinalising
                                ? 'Finishing up…'
                                : state.canStop
                                ? 'Tap to stop recording'
                                : 'Keep speaking…',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMedium,
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Explains what the app is doing, including why a live transcript may be
  /// absent — the model downloads once and the recording never waits for it.
  String _statusLabel(RecordingState state, SpeechEngineState? engine) {
    if (state.isFinalising) return 'Transcribing your last words…';
    if (!state.isRecording) return 'Initialising…';

    switch (engine?.status) {
      case SpeechEngineStatus.downloading:
        final percent = (engine!.progress * 100).round();
        return 'Recording — preparing on-device transcription ($percent%)';
      case SpeechEngineStatus.loading:
        return 'Recording — loading on-device transcription…';
      case SpeechEngineStatus.unsupported:
      case SpeechEngineStatus.failed:
        return 'Recording — transcribed after you finish';
      default:
        return 'AI Listening & Analysing…';
    }
  }

  Future<void> _confirmStop(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: const Text('Stop Recording?'),
        content: const Text('Your current recording will be discarded.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMedium),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Discard',
              style: TextStyle(color: AppColors.poor),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ref.read(recordingProvider.notifier).reset();
      context.go(AppRoutes.home);
    }
  }
}
