import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../topic_selection/data/models/topic.dart';
import '../../providers/recording_provider.dart';
import '../widgets/waveform_animation.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/tabular_text.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/pressable.dart';
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
            backgroundColor: AppColors.critical,
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
                            LucideIcons.x,
                            color: AppColors.inkMuted,
                          ),
                          onPressed: () => _confirmStop(context),
                        ),
                        Expanded(
                          child: Text(
                            'Oralidle',
                            textAlign: TextAlign.center,
                            style: context.cardTitle.copyWith(color: AppColors.ink,
                              fontWeight: AppFontWeight.w700,
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
                              color: AppColors.caution.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.caution.withValues(alpha: 0.35),
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
                                    color: AppColors.caution,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  widget.topic.category.toUpperCase(),
                                  style: context.overline.copyWith(
                                    color: AppColors.caution,
                                    fontWeight: AppFontWeight.w700,
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
                            style: context.title.copyWith(
                              color: AppColors.ink,
                              height: 1.35,
                              fontWeight: AppFontWeight.w700,
                            ),
                          ),

                          const Spacer(),

                          // ── AI listening indicator ──────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                state.isFinalising
                                    ? LucideIcons.hourglass
                                    : LucideIcons.activity,
                                size: 14,
                                color: state.isRecording || state.isFinalising
                                    ? AppColors.voiceLow
                                    : AppColors.borderControl,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _statusLabel(state, engineState),
                                  textAlign: TextAlign.center,
                                  style: context.caption.copyWith(
                                    color:
                                        state.isRecording || state.isFinalising
                                        ? AppColors.voiceLow
                                        : AppColors.borderControl,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // ── Large timer ─────────────────────────────────
                          TabularText(
                            '$minutes:${seconds.toString().padLeft(2, '0')}',
                            style: context.timer,
                            semanticsLabel: '$minutes minutes ${seconds.toString().padLeft(2, '0')} seconds elapsed',
                          ),
                          const SizedBox(height: 6),
                          Text(
                            elapsed < AppConstants.minRecordingSeconds
                                ? 'Min 1:00 to stop'
                                : 'Tap the mic to stop',
                            style: context.caption.copyWith(color: AppColors.inkMuted,
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
                                color: AppColors.raised2,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: SingleChildScrollView(
                                reverse: true,
                                child: Text(
                                  state.transcript,
                                  style: context.caption.copyWith(color: AppColors.inkMuted,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          const Spacer(),

                          // ── Mic / stop button ───────────────────────────
                          _RecordControl(
                            recording: state.isRecording,
                            onStop: state.canStop && !state.isFinalising
                                ? () => ref
                                      .read(recordingProvider.notifier)
                                      .stopManually()
                                : null,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            state.isFinalising
                                ? 'Finishing up…'
                                : state.canStop
                                ? 'Tap to stop recording'
                                : 'Keep speaking…',
                            style: context.caption.copyWith(color: AppColors.inkMuted,
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
        backgroundColor: AppColors.raised2,
        title: const Text('Stop Recording?'),
        content: const Text('Your current recording will be discarded.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.inkMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Discard',
              style: TextStyle(color: AppColors.critical),
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

/// The only circular control in the app, and the only chromatic one.
/// DESIGN.md §4.
///
/// Outlined rather than filled while recording: a glyph on filled `critical`
/// measures 2.62:1 and fails, while `critical` on the canvas is 8.06:1. The
/// glow is the single exception DESIGN.md §2 grants, and only while capturing.
class _RecordControl extends StatelessWidget {
  const _RecordControl({required this.recording, required this.onStop});

  final bool recording;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onStop,
      borderRadius: BorderRadius.circular(TouchTarget.record),
      semanticLabel: recording ? 'Stop recording' : 'Recording',
      semanticHint: onStop == null ? 'Keep speaking to enable' : null,
      haptic: false,
      padding: EdgeInsets.all(1),
      child: AnimatedContainer(
        duration: context.motion(Motion.base),
        curve: Motion.curve,
        width: TouchTarget.record,
        height: TouchTarget.record,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: recording ? Colors.transparent : AppColors.accent,
          border: recording ? Border.all(color: AppColors.critical, width: 3) : null,
          boxShadow: recording
              ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 28, spreadRadius: 2)]
              : null,
        ),
        child: Icon(
          recording ? LucideIcons.square : LucideIcons.mic,
          color: recording ? AppColors.critical : AppColors.onAccent,
          size: IconSize.xl,
        ),
      ),
    );
  }
}
