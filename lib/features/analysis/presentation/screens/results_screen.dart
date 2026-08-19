import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/session_record.dart';
import '../../data/models/analysis_result.dart';
import '../../../history/providers/history_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/meta_chip.dart';
import '../../../../core/widgets/score_bar.dart';
import '../../../../core/utils/responsive.dart';

class ResultsScreen extends ConsumerWidget {
  final SessionRecord record;
  const ResultsScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= Breakpoints.twoColumn) {
            return _WebResults(
              record: record,
              ref: ref,
              availableWidth: constraints.maxWidth,
            );
          }
          return _MobileResults(record: record, ref: ref);
        },
      ),
    );
  }
}

// ── Web two-column layout ─────────────────────────────────────────────────────

class _WebResults extends StatelessWidget {
  final SessionRecord record;
  final WidgetRef ref;

  /// Width of the content area, excluding the shell's sidebar.
  final double availableWidth;

  const _WebResults({
    required this.record,
    required this.ref,
    required this.availableWidth,
  });

  @override
  Widget build(BuildContext context) {
    final r = record.result;
    final overall = r.overallScore;
    final color = AppColors.scoreColor(overall);

    return Stack(
      children: [
        Positioned(
          top: -40,
          right: -40,
          child: AmbientOrb(color: color, size: 220),
        ),
        const Positioned(
          bottom: 80,
          left: -50,
          child: AmbientOrb(color: AppColors.primary, size: 160),
        ),
        SafeArea(
          child: Column(
            children: [
              // ── Top bar ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
                child: Row(
                  children: [
                    Text(
                      'Speech Analysis',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Session from ${DateFormat('MMM d, y').format(record.timestamp)}  •  ${record.topicTitle}',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.home_rounded,
                        color: AppColors.textMedium,
                      ),
                      onPressed: () {
                        ref.read(historyProvider.notifier).refresh();
                        context.go(AppRoutes.home);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── Two-column body ─────────────────────────────────────
              Expanded(
                // Side margins grow on wide windows so the two-column
                // body stops widening while the backdrop stays full-bleed.
                child: SingleChildScrollView(
                  padding: centeredPagePadding(
                    availableWidth,
                    minHorizontal: 32,
                    top: 8,
                    bottom: 32,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Left: score + insights ──────────────────────
                      SizedBox(
                        width: 300,
                        child: Column(
                          children: [
                            GlassCard(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  const Text(
                                    'CLARITY SCORE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textMedium,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ScoreRing(
                                    score: overall,
                                    color: color,
                                    size: 140,
                                    strokeWidth: 9,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _scoreLabel(overall),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    r.summary,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(height: 1.5),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Meta
                            GlassCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  MetaChip(
                                    icon: Icons.timer_outlined,
                                    label: record.formattedDuration,
                                  ),
                                  MetaChip(
                                    icon: Icons.speed_rounded,
                                    label: '${r.wpm} wpm',
                                  ),
                                  MetaChip(
                                    icon: Icons.calendar_today_outlined,
                                    label: DateFormat(
                                      'MMM d',
                                    ).format(record.timestamp),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Key Insights
                            _KeyInsightsSection(result: r),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),

                      // ── Right: breakdown + tips ─────────────────────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (r.transcript.isNotEmpty) ...[
                              _SpeechTranscriptSection(transcript: r.transcript),
                              const SizedBox(height: 20),
                            ],
                            GlassCard(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Performance Breakdown',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 20),
                                  ScoreBar(
                                    label: 'Fluency',
                                    score: r.scores.fluency,
                                  ),
                                  ScoreBar(
                                    label: 'Vocabulary',
                                    score: r.scores.vocabulary,
                                  ),
                                  ScoreBar(
                                    label: 'Grammar',
                                    score: r.scores.grammar,
                                  ),
                                  ScoreBar(
                                    label: 'Coherence',
                                    score: r.scores.coherence,
                                  ),
                                  ScoreBar(
                                    label: 'Confidence',
                                    score: r.scores.confidence,
                                  ),
                                  ScoreBar(
                                    label: 'Topic',
                                    score: r.scores.topicRelevance,
                                    isLast: true,
                                  ),
                                ],
                              ),
                            ),
                            if (r.improvements.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Text(
                                'Coaching Tips',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              ...r.improvements.map(
                                (tip) => _CoachingTipCard(tip: tip),
                              ),
                            ],
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: PrimaryGradientButton(
                                    label: 'Try a New Topic',
                                    icon: Icons.mic_rounded,
                                    height: 48,
                                    onTap: () {
                                      ref.read(historyProvider.notifier).refresh();
                                      context.go(AppRoutes.topics);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      ref
                                          .read(historyProvider.notifier)
                                          .refresh();
                                      context.go(AppRoutes.home);
                                    },
                                    icon: const Icon(Icons.home_outlined),
                                    label: const Text('Back to Home'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

// ── Mobile single-column layout ───────────────────────────────────────────────

class _MobileResults extends StatelessWidget {
  final SessionRecord record;
  final WidgetRef ref;

  const _MobileResults({required this.record, required this.ref});

  @override
  Widget build(BuildContext context) {
    final r = record.result;
    final overall = r.overallScore;
    final color = AppColors.scoreColor(overall);

    return Stack(
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
                      icon: const Icon(
                        Icons.home_rounded,
                        color: AppColors.textMedium,
                      ),
                      onPressed: () {
                        ref.read(historyProvider.notifier).refresh();
                        context.go(AppRoutes.home);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        bgColor: color.withValues(alpha: 0.06),
                        borderColor: color.withValues(alpha: 0.2),
                        child: Text(
                          r.summary,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (r.transcript.isNotEmpty) ...[
                        _SpeechTranscriptSection(transcript: r.transcript),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        'Performance Breakdown',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 14),
                      GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            ScoreBar(
                              label: 'Fluency',
                              score: r.scores.fluency,
                            ),
                            ScoreBar(
                              label: 'Vocabulary',
                              score: r.scores.vocabulary,
                            ),
                            ScoreBar(
                              label: 'Grammar',
                              score: r.scores.grammar,
                            ),
                            ScoreBar(
                              label: 'Coherence',
                              score: r.scores.coherence,
                            ),
                            ScoreBar(
                              label: 'Confidence',
                              score: r.scores.confidence,
                            ),
                            ScoreBar(
                              label: 'Topic',
                              score: r.scores.topicRelevance,
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _KeyInsightsSection(result: r),
                      const SizedBox(height: 24),
                      if (r.improvements.isNotEmpty) ...[
                        Text(
                          'Coaching Tips',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        ...r.improvements.map(
                          (tip) => _CoachingTipCard(tip: tip),
                        ),
                        const SizedBox(height: 8),
                      ],
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

class _KeyInsightsSection extends StatelessWidget {
  final AnalysisResult result;
  const _KeyInsightsSection({required this.result});

  @override
  Widget build(BuildContext context) {
    final hasFillers = result.fillerWords.isNotEmpty;
    final ideal =
        result.wpm >= AppConstants.idealWpmMin &&
        result.wpm <= AppConstants.idealWpmMax;
    final wpmColor = ideal ? AppColors.good : AppColors.fair;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Key Insights', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: wpmColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: wpmColor.withValues(alpha: 0.3),
                      ),
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
                            color: wpmColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ideal
                          ? 'Great pace! (${AppConstants.idealWpmMin}–${AppConstants.idealWpmMax} ideal)'
                          : result.wpm < AppConstants.idealWpmMin
                          ? 'A little slow — aim for ${AppConstants.idealWpmMin}+ WPM'
                          : 'A little fast — try to slow down',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ),
                ],
              ),
              if (hasFillers) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: AppColors.amber,
                    ),
                    const SizedBox(width: 6),
                    const Text(
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
                      .map((e) => _FillerChip(word: e.key, count: e.value))
                      .toList(),
                ),
              ],
              if (!hasFillers) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: AppColors.good,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'No filler words detected — excellent!',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.good,
                        fontWeight: FontWeight.w600,
                      ),
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
                color: AppColors.textDark,
              ),
            ),
            TextSpan(
              text: '  $count×',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.amber,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              Icons.arrow_upward_rounded,
              size: 16,
              color: AppColors.primary,
            ),
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
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip.tip,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textDark,
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

class _SpeechTranscriptSection extends StatelessWidget {
  final String transcript;
  const _SpeechTranscriptSection({required this.transcript});

  @override
  Widget build(BuildContext context) {
    if (transcript.trim().isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Speech Transcript',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Clipboard.setData(ClipboardData(text: transcript));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transcript copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Copy',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.all(18),
          bgColor: AppColors.surface.withValues(alpha: 0.6),
          borderColor: AppColors.primary.withValues(alpha: 0.25),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.format_quote_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SelectableText(
                  transcript,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    color: AppColors.textDark,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
