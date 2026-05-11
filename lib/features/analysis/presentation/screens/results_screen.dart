import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/session_record.dart';
import '../../data/models/analysis_result.dart';
import '../../../history/providers/history_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/glass_card.dart';

class ResultsScreen extends ConsumerWidget {
  final SessionRecord record;
  const ResultsScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = record.result;
    final overall = r.overallScore;
    final color = AppColors.scoreColor(overall);

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: AmbientOrb(color: color, size: 200),
          ),
          const Positioned(
            bottom: 100,
            left: -50,
            child: AmbientOrb(color: AppColors.primary, size: 160),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── App bar ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      const SizedBox(width: 48),
                      Expanded(
                        child: Text(
                          'Lumina Speech',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.home_rounded,
                            color: AppColors.textMedium),
                        onPressed: () {
                          ref.read(historyProvider.notifier).refresh();
                          context.go(AppRoutes.home);
                        },
                      ),
                    ],
                  ),
                ),

                // ── Scrollable body ────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Score ring ────────────────────────────────
                        Center(
                          child: ScoreRing(
                            score: overall,
                            color: color,
                            size: 140,
                            strokeWidth: 9,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            _scoreLabel(overall),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            '${DateFormat('MMM d, y').format(record.timestamp)}  •  ${record.formattedDuration}  •  ${r.wpm} wpm',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Summary ───────────────────────────────────
                        GlassCard(
                          padding: const EdgeInsets.all(16),
                          bgColor: color.withValues(alpha: 0.06),
                          borderColor: color.withValues(alpha: 0.2),
                          child: Text(
                            r.summary,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Performance Breakdown ─────────────────────
                        Text('Performance Breakdown',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 14),
                        GlassCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              _ScoreBar(label: 'Fluency', score: r.scores.fluency),
                              _ScoreBar(label: 'Vocabulary', score: r.scores.vocabulary),
                              _ScoreBar(label: 'Grammar', score: r.scores.grammar),
                              _ScoreBar(label: 'Coherence', score: r.scores.coherence),
                              _ScoreBar(label: 'Confidence', score: r.scores.confidence),
                              _ScoreBar(
                                label: 'Topic',
                                score: r.scores.topicRelevance,
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Key Insights ──────────────────────────────
                        _KeyInsightsSection(result: r),
                        const SizedBox(height: 24),

                        // ── Coaching Tips ─────────────────────────────
                        if (r.improvements.isNotEmpty) ...[
                          Text('Coaching Tips',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          ...r.improvements.map((tip) => _CoachingTipCard(tip: tip)),
                          const SizedBox(height: 8),
                        ],

                        // ── CTAs ──────────────────────────────────────
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _scoreLabel(int s) {
    if (s >= 85) return 'Excellent!';
    if (s >= 75) return 'Great Job!';
    if (s >= 60) return 'Good Progress';
    if (s >= 45) return 'Keep Practising';
    return 'Just Getting Started';
  }
}

// ── Score bar row ─────────────────────────────────────────────────────────────

class _ScoreBar extends StatelessWidget {
  final String label;
  final int score;
  final bool isLast;

  const _ScoreBar({required this.label, required this.score, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.scoreColor(score);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark),
                ),
              ),
              Text(
                '$score%',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  color: AppColors.outlineVariant,
                ),
                FractionallySizedBox(
                  widthFactor: score / 100,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Key Insights (WPM + filler words) ────────────────────────────────────────

class _KeyInsightsSection extends StatelessWidget {
  final AnalysisResult result;
  const _KeyInsightsSection({required this.result});

  @override
  Widget build(BuildContext context) {
    final hasFillers = result.fillerWords.isNotEmpty;
    final ideal = result.wpm >= AppConstants.idealWpmMin &&
        result.wpm <= AppConstants.idealWpmMax;
    final wpmColor = ideal ? AppColors.good : AppColors.fair;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Key Insights',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // WPM row
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: wpmColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: wpmColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.speed_rounded, size: 12, color: wpmColor),
                        const SizedBox(width: 5),
                        Text(
                          '${result.wpm} WPM',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: wpmColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ideal
                          ? 'Great pace! (${AppConstants.idealWpmMin}–${AppConstants.idealWpmMax} WPM ideal)'
                          : result.wpm < AppConstants.idealWpmMin
                              ? 'A little slow — aim for ${AppConstants.idealWpmMin}+ WPM'
                              : 'A little fast — try to slow down',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMedium),
                    ),
                  ),
                ],
              ),

              if (hasFillers) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 14, color: AppColors.amber),
                    const SizedBox(width: 6),
                    Text(
                      'FILLER WORDS DETECTED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.amber,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: result.fillerWords.entries
                      .toList()
                      .map((e) => _FillerChip(word: e.key, count: e.value))
                      .toList(),
                ),
              ],

              if (!hasFillers) ...[
                const SizedBox(height: 12),
                Row(
                  children: const [
                    Icon(Icons.check_circle_rounded,
                        size: 14, color: AppColors.good),
                    SizedBox(width: 6),
                    Text(
                      'No filler words detected — excellent!',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.good,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FillerChip extends StatelessWidget {
  final String word;
  final int count;
  const _FillerChip({required this.word, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '"$word"',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark),
            ),
            TextSpan(
              text: '  $count×',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.amber),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Coaching tip card ─────────────────────────────────────────────────────────

class _CoachingTipCard extends StatelessWidget {
  final ImprovementTip tip;
  const _CoachingTipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.arrow_upward_rounded,
                size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.area,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.2),
                ),
                const SizedBox(height: 4),
                Text(
                  tip.tip,
                  style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.textDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
