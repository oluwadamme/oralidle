import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/analysis_provider.dart';
import '../../../recording/data/models/recording_session.dart';
import '../../../../core/constants/app_constants.dart';

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
      duration: const Duration(milliseconds: 1200),
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

  void _retry() {
    ref.read(analysisProvider.notifier).analyse(widget.session);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analysisProvider);

    // Navigate on success — only inside build via listener so context is always valid
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
      body: SafeArea(
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
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) => Container(
                          width: 100 + _pulse.value * 20,
                          height: 100 + _pulse.value * 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.1 + _pulse.value * 0.1),
                          ),
                          child: const Icon(
                            Icons.psychology_rounded,
                            size: 48,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        widget.session.isAudioUpload
                            ? 'Transcribing & Analysing'
                            : 'Analysing Your Speech',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.session.isAudioUpload
                            ? 'Gemini is transcribing "${widget.session.audioFileName ?? "your audio"}" and reviewing your fluency, grammar, vocabulary, and more…'
                            : 'Gemini is reviewing your fluency, grammar, vocabulary, and more…',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 40),
                      const Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _CheckItem(label: 'Fluency'),
                          _CheckItem(label: 'Vocabulary'),
                          _CheckItem(label: 'Grammar'),
                          _CheckItem(label: 'Coherence'),
                          _CheckItem(label: 'Confidence'),
                          _CheckItem(label: 'Topic Relevance'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  String _friendlyMessage(Object? error) {
    if (error == null) return 'Something went wrong. Please try again.';
    final raw = error is Exception
        ? error.toString().replaceFirst('Exception: ', '')
        : error.toString();
    // Truncate if overly long (e.g. unexpected HTML or stack trace)
    if (raw.length > 200) return 'Analysis failed. Please check your connection and try again.';
    return raw;
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
            const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.poor),
            const SizedBox(height: 24),
            Text(
              'Analysis Failed',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: AppColors.textDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textMedium),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onBack,
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String label;
  const _CheckItem({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
    );
  }
}
