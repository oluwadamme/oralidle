import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/analysis_provider.dart';
import '../../../recording/data/models/recording_session.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/glass_card.dart';

class ProcessingScreen extends ConsumerStatefulWidget {
  final RecordingSession session;
  const ProcessingScreen({super.key, required this.session});

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analysisProvider.notifier).analyse(widget.session);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _retry() => ref.read(analysisProvider.notifier).analyse(widget.session);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analysisProvider);

    ref.listen(analysisProvider, (_, next) {
      next.whenOrNull(
        data: (record) {
          if (record != null) {
            context.pushReplacement(AppRoutes.results, extra: record);
          }
        },
      );
    });

    return Scaffold(
      body: Stack(
        children: [
          // Ambient orbs
          const Positioned(
            top: -60,
            left: -60,
            child: AmbientOrb(color: AppColors.primary, size: 260),
          ),
          const Positioned(
            bottom: 80,
            right: -50,
            child: AmbientOrb(color: AppColors.amber, size: 180),
          ),
          SafeArea(
            child: state.hasError
                ? _ErrorView(
                    message: _friendlyMessage(state.error),
                    onRetry: _retry,
                    onBack: () => context.go(AppRoutes.home),
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Pulsing glow orb
                          AnimatedBuilder(
                            animation: _pulse,
                            builder: (context, _) {
                              final scale = 1.0 + _pulse.value * 0.08;
                              return Transform.scale(
                                scale: scale,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withValues(
                                        alpha: 0.08 + _pulse.value * 0.06),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                          alpha: 0.3 + _pulse.value * 0.2),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                            alpha: 0.2 + _pulse.value * 0.2),
                                        blurRadius: 30 + _pulse.value * 20,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.psychology_rounded,
                                    size: 52,
                                    color: AppColors.primary,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 36),
                          Text(
                            widget.session.isAudioUpload
                                ? 'Transcribing & Analysing'
                                : 'Analysing Your Speech',
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.session.isAudioUpload
                                ? 'Gemini is transcribing "${widget.session.audioFileName ?? "your audio"}" and coaching your fluency, grammar, and more…'
                                : 'Gemini is reviewing your fluency, grammar, vocabulary, and more…',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 36),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: const LinearProgressIndicator(minHeight: 3),
                          ),
                          const SizedBox(height: 36),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: const [
                              _CheckChip(label: 'Fluency'),
                              _CheckChip(label: 'Vocabulary'),
                              _CheckChip(label: 'Grammar'),
                              _CheckChip(label: 'Coherence'),
                              _CheckChip(label: 'Confidence'),
                              _CheckChip(label: 'Topic'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _friendlyMessage(Object? error) {
    if (error == null) return 'Something went wrong. Please try again.';
    final raw = error is Exception
        ? error.toString().replaceFirst('Exception: ', '')
        : error.toString();
    if (raw.length > 200) return 'Analysis failed. Please check your connection and try again.';
    return raw;
  }
}

class _CheckChip extends StatelessWidget {
  final String label;
  const _CheckChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      radius: 20,
      borderColor: AppColors.primary.withValues(alpha: 0.25),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _ErrorView({required this.message, required this.onRetry, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.poor.withValues(alpha: 0.1),
                border: Border.all(color: AppColors.poor.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.poor.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: const Icon(Icons.error_outline_rounded, size: 36, color: AppColors.poor),
            ),
            const SizedBox(height: 24),
            Text(
              'Analysis Failed',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onBack,
              child: const Text('Go to Home', style: TextStyle(color: AppColors.textMedium)),
            ),
          ],
        ),
      ),
    );
  }
}
