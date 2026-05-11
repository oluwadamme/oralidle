import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/session_record.dart';
import '../widgets/radar_chart_widget.dart';
import '../widgets/filler_words_bar_chart.dart';
import '../widgets/metric_score_card.dart';
import '../widgets/improvement_tips_card.dart';
import '../../../history/providers/history_provider.dart';
import '../../../../core/constants/app_constants.dart';

class ResultsScreen extends ConsumerWidget {
  final SessionRecord record;
  const ResultsScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = record.result;
    final overall = r.overallScore;
    final overallColor = AppColors.scoreColor(overall);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Results'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            onPressed: () {
              ref.read(historyProvider.notifier).refresh();
              context.go(AppRoutes.home);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OverallScoreCard(score: overall, color: overallColor, summary: r.summary),
            const SizedBox(height: 20),
            _SectionHeader(
              title: record.topicTitle,
              subtitle: DateFormat('MMM d, y • h:mm a').format(record.timestamp),
            ),
            const SizedBox(height: 4),
            Text(
              '${record.formattedDuration} • ${r.wpm} wpm',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            _WpmIndicator(wpm: r.wpm),
            const SizedBox(height: 20),
            Text('Skill Breakdown', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SpeechRadarChart(scores: r.scores),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
              children: [
                MetricScoreCard(label: 'Fluency', score: r.scores.fluency, icon: Icons.waves_rounded),
                MetricScoreCard(label: 'Vocabulary', score: r.scores.vocabulary, icon: Icons.menu_book_rounded),
                MetricScoreCard(label: 'Grammar', score: r.scores.grammar, icon: Icons.spellcheck_rounded),
                MetricScoreCard(label: 'Coherence', score: r.scores.coherence, icon: Icons.account_tree_rounded),
                MetricScoreCard(label: 'Topic', score: r.scores.topicRelevance, icon: Icons.topic_rounded),
                MetricScoreCard(label: 'Confidence', score: r.scores.confidence, icon: Icons.emoji_events_rounded),
              ],
            ),
            const SizedBox(height: 20),
            if (r.fillerWords.isNotEmpty) ...[
              Text('Filler Words', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              FillerWordsBarChart(fillerWords: r.fillerWords),
              const SizedBox(height: 20),
            ],
            ImprovementTipsCard(tips: r.improvements, strengths: r.strengths),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.go(AppRoutes.topics),
              icon: const Icon(Icons.mic_rounded),
              label: const Text('Try a New Topic'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(historyProvider.notifier).refresh();
                context.go(AppRoutes.home);
              },
              icon: const Icon(Icons.home_outlined),
              label: const Text('Back to Home'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _OverallScoreCard extends StatelessWidget {
  final int score;
  final Color color;
  final String summary;

  const _OverallScoreCard({required this.score, required this.color, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            alignment: Alignment.center,
            child: Text(
              '$score',
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label(score),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
                ),
                const SizedBox(height: 4),
                Text(summary, style: const TextStyle(fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _label(int s) {
    if (s >= 85) return 'Excellent!';
    if (s >= 75) return 'Great Job!';
    if (s >= 60) return 'Good Progress';
    if (s >= 45) return 'Keep Practising';
    return 'Just Getting Started';
  }
}

class _WpmIndicator extends StatelessWidget {
  final int wpm;
  const _WpmIndicator({required this.wpm});

  @override
  Widget build(BuildContext context) {
    final ideal = wpm >= AppConstants.idealWpmMin && wpm <= AppConstants.idealWpmMax;
    final color = ideal ? AppColors.good : AppColors.fair;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.speed_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$wpm words per minute',
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
                Text(
                  ideal
                      ? 'Great pace! Ideal range is ${AppConstants.idealWpmMin}–${AppConstants.idealWpmMax} WPM'
                      : wpm < AppConstants.idealWpmMin
                          ? 'A little slow — aim for ${AppConstants.idealWpmMin}+ WPM'
                          : 'A little fast — try to slow down slightly',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context).textTheme.titleLarge,
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
