import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../data/models/session_record.dart';
import '../../data/models/analysis_result.dart';
import '../widgets/recording_player_card.dart';
import '../../../history/providers/history_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/score_meter.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/meta_chip.dart';
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

    return Stack(
      children: [
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
                        LucideIcons.home,
                        color: AppColors.inkMuted,
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
                            SurfaceCard(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Text(
                                    'CLARITY SCORE',
                                    style: context.overline,
                                  ),
                                  const SizedBox(height: Space.lg),
                                  const SizedBox(height: Space.md),
                                  ScoreMeter(
                                    score: overall,
                                    size: ScoreMeterSize.hero,
                                    caption: _scoreLabel(overall),
                                  ),
                                  const SizedBox(height: Space.md),
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
                            SurfaceCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  MetaChip(
                                    icon: LucideIcons.clock,
                                    label: record.formattedDuration,
                                  ),
                                  MetaChip(
                                    icon: LucideIcons.gauge,
                                    label: '${r.wpm} wpm',
                                  ),
                                  MetaChip(
                                    icon: LucideIcons.calendar,
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
                            if (record.audioPath != null &&
                                record.audioPath!.isNotEmpty) ...[
                              RecordingPlayerCard(
                                audioPath: record.audioPath!,
                                fallbackDurationSeconds: record.durationSeconds,
                              ),
                              const SizedBox(height: 20),
                            ],
                            if (r.transcript.isNotEmpty) ...[
                              _SpeechTranscriptSection(
                                transcript: r.transcript,
                              ),
                              const SizedBox(height: 20),
                            ],
                            SurfaceCard(
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
                                  const SizedBox(height: Space.md),
                                  ScoreMeter(
                                    label: 'Fluency',
                                    score: r.scores.fluency,
                                  ),
                                  const SizedBox(height: Space.md),
                                  ScoreMeter(
                                    label: 'Vocabulary',
                                    score: r.scores.vocabulary,
                                  ),
                                  const SizedBox(height: Space.md),
                                  ScoreMeter(
                                    label: 'Grammar',
                                    score: r.scores.grammar,
                                  ),
                                  const SizedBox(height: Space.md),
                                  ScoreMeter(
                                    label: 'Coherence',
                                    score: r.scores.coherence,
                                  ),
                                  const SizedBox(height: Space.md),
                                  ScoreMeter(
                                    label: 'Confidence',
                                    score: r.scores.confidence,
                                  ),
                                  const SizedBox(height: Space.md),
                                  ScoreMeter(
                                    label: 'Topic',
                                    score: r.scores.topicRelevance,
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
                                  child: AppButton.primary(
                                    expand: true,
                                    label: 'Try a New Topic',
                                    icon: LucideIcons.mic,
                                    onPressed: () {
                                      ref
                                          .read(historyProvider.notifier)
                                          .refresh();
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
                                    icon: const Icon(LucideIcons.home),
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

    return Stack(
      children: [
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
                        'Oralidle',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        LucideIcons.home,
                        color: AppColors.inkMuted,
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
                      ScoreMeter(
                        score: overall,
                        size: ScoreMeterSize.hero,
                        caption: _scoreLabel(overall),
                      ),
                      const SizedBox(height: Space.sm),
                      Center(
                        child: Text(
                          '${DateFormat('MMM d, y').format(record.timestamp)}  •  ${record.formattedDuration}  •  ${r.wpm} wpm',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SurfaceCard(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          r.summary,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (record.audioPath != null &&
                          record.audioPath!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        RecordingPlayerCard(
                          audioPath: record.audioPath!,
                          fallbackDurationSeconds: record.durationSeconds,
                        ),
                      ],
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
                      SurfaceCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            ScoreMeter(
                              label: 'Fluency',
                              score: r.scores.fluency,
                            ),
                            ScoreMeter(
                              label: 'Vocabulary',
                              score: r.scores.vocabulary,
                            ),
                            ScoreMeter(
                              label: 'Grammar',
                              score: r.scores.grammar,
                            ),
                            ScoreMeter(
                              label: 'Coherence',
                              score: r.scores.coherence,
                            ),
                            ScoreMeter(
                              label: 'Confidence',
                              score: r.scores.confidence,
                            ),
                            ScoreMeter(
                              label: 'Topic',
                              score: r.scores.topicRelevance,
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
                        icon: const Icon(LucideIcons.mic),
                        label: const Text('Try a New Topic'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          ref.read(historyProvider.notifier).refresh();
                          context.go(AppRoutes.home);
                        },
                        icon: const Icon(LucideIcons.home),
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
    final wpmColor = ideal ? AppColors.positive : AppColors.caution;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Key Insights', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SurfaceCard(
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
                      borderRadius: Radii.pillAll,
                      color: wpmColor.withValues(alpha: 0.12),
                      border: Border.all(
                        color: wpmColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.gauge, size: 12, color: wpmColor),
                        const SizedBox(width: 5),
                        Text(
                          '${result.wpm} WPM',
                          style: TextStyle(
                            fontWeight: AppFontWeight.w700,
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
                      style: const TextStyle(color: AppColors.inkMuted),
                    ),
                  ),
                ],
              ),
              if (hasFillers) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.alertTriangle,
                      size: 14,
                      color: AppColors.caution,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'FILLER WORDS DETECTED',
                      style: TextStyle(
                        fontWeight: AppFontWeight.w700,
                        color: AppColors.caution,
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
                  spacing: 8,
                  children: [
                    Icon(
                      LucideIcons.checkCircle2,
                      size: 14,
                      color: AppColors.positive,
                    ),
                    Flexible(
                      child: Text(
                        'No filler words detected — excellent!',
                        style: TextStyle(color: AppColors.positive, fontWeight: AppFontWeight.w600),
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
        borderRadius: Radii.pillAll,
        color: AppColors.caution.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.caution.withValues(alpha: 0.3)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '"$word"',
              style: const TextStyle(
                fontWeight: AppFontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            TextSpan(
              text: '  $count×',
              style: const TextStyle(
                fontWeight: AppFontWeight.w700,
                color: AppColors.caution,
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
        borderRadius: Radii.mdAll,
        color: AppColors.raised,
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.raised2,
              border: Border.all(color: AppColors.borderControl),
            ),
            child: const Icon(
              LucideIcons.arrowUp,
              size: 16,
              color: AppColors.ink,
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
                    fontWeight: AppFontWeight.w700,
                    color: AppColors.ink,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(tip.tip, style: const TextStyle(color: AppColors.ink)),
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
                    Icon(LucideIcons.copy, size: 14, color: AppColors.ink),
                    SizedBox(width: 4),
                    Text(
                      'Copy',
                      style: TextStyle(
                        fontWeight: AppFontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.raised2,
                ),
                child: const Icon(
                  LucideIcons.quote,
                  size: 18,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SelectableText(
                  transcript,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
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
