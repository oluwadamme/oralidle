import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../topic_selection/data/models/topic.dart';
import '../../providers/recording_provider.dart';
import '../widgets/waveform_animation.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/glass_card.dart';

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

    ref.listen(recordingProvider, (prev, next) {
      if (next.status == RecordingStatus.stopped && next.completedSession != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          context.pushReplacement(AppRoutes.processing, extra: next.completedSession);
          ref.read(recordingProvider.notifier).reset();
        });
      } else if (next.status == RecordingStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'Speech recognition unavailable'),
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
                          icon: const Icon(Icons.close_rounded,
                              color: AppColors.textMedium),
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),

                          // ── Category badge ──────────────────────────────
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.amber.withValues(alpha: 0.35)),
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
                                Icons.graphic_eq_rounded,
                                size: 14,
                                color: state.isRecording
                                    ? AppColors.primary
                                    : AppColors.outline,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                state.isRecording
                                    ? 'AI Listening & Analysing…'
                                    : 'Initialising…',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: state.isRecording
                                      ? AppColors.primary
                                      : AppColors.outline,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // ── Large timer ─────────────────────────────────
                          Text(
                            '$minutes:${seconds.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 72,
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
                          WaveformAnimation(isActive: state.isRecording),

                          const Spacer(),

                          // ── Mic / stop button ───────────────────────────
                          GestureDetector(
                            onTap: state.canStop
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
                                    color: (state.canStop
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
                            state.canStop
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
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMedium))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Discard', style: TextStyle(color: AppColors.poor)),
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
