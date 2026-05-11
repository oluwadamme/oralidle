import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../topic_selection/data/models/topic.dart';
import '../../providers/recording_provider.dart';
import '../widgets/waveform_animation.dart';
import '../../../../core/constants/app_constants.dart';

class RecordingScreen extends ConsumerStatefulWidget {
  final Topic topic;
  const RecordingScreen({super.key, required this.topic});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recordingProvider.notifier).startRecording(widget.topic);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingProvider);

    ref.listen(recordingProvider, (prev, next) {
      if (next.status == RecordingStatus.stopped && next.completedSession != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
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
    final progress = elapsed / AppConstants.maxRecordingSeconds;
    final timerColor = elapsed < 60
        ? AppColors.good
        : elapsed < 90
            ? AppColors.fair
            : AppColors.poor;

    final transcript = state.fullTranscript;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmStop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.topic.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _confirmStop(context),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _CircularTimer(elapsed: elapsed, progress: progress, color: timerColor),
                const SizedBox(height: 8),
                Text(
                  elapsed < AppConstants.minRecordingSeconds
                      ? 'Keep speaking…'
                      : 'You can stop anytime',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 20),
                WaveformAnimation(
                  isActive: state.isRecording,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: transcript.isEmpty
                        ? Center(
                            child: Text(
                              'Start speaking — your transcript will appear here',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                            ),
                          )
                        : SingleChildScrollView(
                            controller: _scrollController,
                            child: Text(
                              transcript,
                              style: const TextStyle(fontSize: 15, height: 1.6),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _WordCountBadge(
                        count: state.fullTranscript
                            .trim()
                            .split(RegExp(r'\s+'))
                            .where((w) => w.isNotEmpty)
                            .length,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: state.canStop
                            ? () => ref.read(recordingProvider.notifier).stopManually()
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.poor,
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                        icon: const Icon(Icons.stop_rounded),
                        label: Text(
                          state.canStop ? 'Stop Recording' : 'Min 60s to stop',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmStop(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop Recording?'),
        content: const Text('Your current recording will be discarded.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
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

class _CircularTimer extends StatelessWidget {
  final int elapsed;
  final double progress;
  final Color color;

  const _CircularTimer({required this.elapsed, required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    final m = elapsed ~/ 60;
    final s = (elapsed % 60).toString().padLeft(2, '0');
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 7,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$m:$s',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color),
            ),
            Text('/ 2:00', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ],
        ),
      ],
    );
  }
}

class _WordCountBadge extends StatelessWidget {
  final int count;
  const _WordCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          Text('words', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
