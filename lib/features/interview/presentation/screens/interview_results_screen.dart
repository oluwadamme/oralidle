import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/category_badge.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/score_meter.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/widgets/pressable.dart';
import '../../data/models/interview_models.dart';
import '../utils/interview_ui_utils.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/theme/text_styles.dart';

class InterviewResultsScreen extends StatelessWidget {
  final CompletedInterview interview;

  const InterviewResultsScreen({super.key, required this.interview});

  @override
  Widget build(BuildContext context) {
    // Hardware back from a full-screen route that replaced the session screen
    // has nowhere sensible to pop to. Redirect explicitly to the interview tab.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth >= Breakpoints.twoColumn
              ? _WideResults(
                  interview: interview,
                  availableWidth: constraints.maxWidth,
                )
              : _MobileResults(interview: interview),
        ),
      ),
    );
  }
}

// ── Shared chrome ─────────────────────────────────────────────────────────────
//
// Both layouts share the same ambient-orb Stack + SafeArea wrapper.
// Extracting it here removes the duplication that existed between
// _WideResults and _MobileResults.

class _ResultsScaffold extends StatelessWidget {
  final Color accentColor;
  final Widget child;

  const _ResultsScaffold({required this.accentColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [SafeArea(child: child)]);
  }
}

// ── Wide two-column layout ────────────────────────────────────────────────────

class _WideResults extends StatelessWidget {
  final CompletedInterview interview;

  /// Width of the content area, excluding the shell's sidebar.
  final double availableWidth;

  const _WideResults({required this.interview, required this.availableWidth});

  @override
  Widget build(BuildContext context) {
    final eval = interview.evaluation;

    return _ResultsScaffold(
      accentColor: AppColors.ink,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
            child: Row(
              children: [
                Text(
                  'Interview Debrief',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(width: 12),
                Text(
                  '${interview.mode.label}  ·  ${DateFormat('MMM d, y').format(interview.timestamp)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(LucideIcons.home, color: AppColors.inkMuted),
                  onPressed: () => context.go(AppRoutes.home),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              // Side margins grow on wide windows so the two-column body
              // stops widening while the backdrop stays full-bleed.
              padding: centeredPagePadding(
                availableWidth,
                minHorizontal: 32,
                top: 8,
                bottom: 32,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 300,
                    child: Column(
                      children: [
                        _OverallCard(interview: interview),
                        const SizedBox(height: 16),
                        _InsightsCard(eval: eval),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _QuestionBreakdown(turns: interview.turns),
                        const SizedBox(height: 20),
                        const _ActionButtons(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mobile single-column layout ───────────────────────────────────────────────

class _MobileResults extends StatelessWidget {
  final CompletedInterview interview;

  const _MobileResults({required this.interview});

  @override
  Widget build(BuildContext context) {
    final eval = interview.evaluation;

    return _ResultsScaffold(
      accentColor: AppColors.ink,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    'Interview Debrief',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.home, color: AppColors.inkMuted),
                  onPressed: () => context.go(AppRoutes.home),
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
                  _OverallCard(interview: interview),
                  const SizedBox(height: 16),
                  _InsightsCard(eval: eval),
                  const SizedBox(height: 20),
                  _QuestionBreakdown(turns: interview.turns),
                  const SizedBox(height: 28),
                  const _ActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared section widgets ────────────────────────────────────────────────────

class _OverallCard extends StatelessWidget {
  final CompletedInterview interview;

  const _OverallCard({required this.interview});

  @override
  Widget build(BuildContext context) {
    final eval = interview.evaluation;

    return SurfaceCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'OVERALL SCORE',
            style: context.overline.copyWith(
              color: AppColors.inkMuted,
              fontWeight: AppFontWeight.w700,
            ),
          ),
          const SizedBox(height: Space.lg),
          ScoreMeter(
            score: eval.overallScore,
            size: ScoreMeterSize.hero,
            caption: _overallLabel(eval.overallScore),
          ),
          const SizedBox(height: Space.md),
          Text(
            eval.summary,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.55),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.line),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MetaChip(
                icon: LucideIcons.helpCircle,
                label: '${interview.turns.length} questions',
              ),
              _MetaChip(
                icon: LucideIcons.trendingUp,
                label: 'Avg ${interview.averageContentScore}%',
              ),
              _MetaChip(
                icon: LucideIcons.calendar,
                label: DateFormat('MMM d').format(interview.timestamp),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _overallLabel(int s) {
    if (s >= 85) return 'Interview Ready!';
    if (s >= 70) return 'Strong Performance';
    if (s >= 55) return 'Good Progress';
    if (s >= 40) return 'Keep Practising';
    return 'Just Getting Started';
  }
}

class _InsightsCard extends StatelessWidget {
  final InterviewEvaluation eval;

  const _InsightsCard({required this.eval});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.sparkles,
                    size: 16,
                    color: AppColors.positive,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Strengths',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...eval.strengths.map(
                (s) => _BulletItem(text: s, color: AppColors.positive),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.arrowUp,
                    size: 16,
                    color: AppColors.ink,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Areas to Improve',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...eval.improvements.map(
                (s) => _BulletItem(text: s, color: AppColors.ink),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuestionBreakdown extends StatelessWidget {
  final List<InterviewTurn> turns;

  const _QuestionBreakdown({required this.turns});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question Breakdown',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ...turns.indexed.map(
          (entry) => _TurnTile(index: entry.$1, turn: entry.$2),
        ),
      ],
    );
  }
}

class _TurnTile extends StatefulWidget {
  final int index;
  final InterviewTurn turn;

  const _TurnTile({required this.index, required this.turn});

  @override
  State<_TurnTile> createState() => _TurnTileState();
}

class _TurnTileState extends State<_TurnTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final eval = widget.turn.evaluation;
    final type = widget.turn.question.type;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.raised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Pressable(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.raised2,
                    ),
                    child: Center(
                      child: Text(
                        '${widget.index + 1}',
                        style: context.overline.copyWith(
                          color: AppColors.ink,
                          fontWeight: AppFontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.turn.question.text,
                          maxLines: _expanded ? null : 2,
                          overflow: _expanded ? null : TextOverflow.ellipsis,
                          style: context.overline.copyWith(
                            color: AppColors.ink,
                            height: 1.4,
                            fontWeight: AppFontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _TypePill(type: type),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${eval.contentScore}%',
                    style: context.cardTitle.copyWith(
                      color: AppColors.ink,
                      fontWeight: AppFontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 20,
                    color: AppColors.inkMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        LucideIcons.messageSquare,
                        size: 13,
                        color: AppColors.ink,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          eval.feedback,
                          style: context.caption.copyWith(
                            color: AppColors.ink,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.raised2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR ANSWER',
                          style: context.overline.copyWith(
                            color: AppColors.inkMuted,
                            fontWeight: AppFontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.turn.transcript,
                          style: context.caption.copyWith(
                            color: AppColors.inkMuted,
                            height: 1.5,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (eval.modelAnswer != null &&
                      eval.modelAnswer!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.raised2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderControl),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                LucideIcons.sparkles,
                                size: 12,
                                color: AppColors.ink,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'GEMINI SAMPLE / IDEAL ANSWER',
                                style: context.overline.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: AppFontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            eval.modelAnswer!,
                            style: context.caption.copyWith(
                              color: AppColors.ink,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pressable(
          onTap: () => context.go(AppRoutes.interview),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.action,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.rotateCcw,
                  color: AppColors.onAction,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Practice Again',
                  style: TextStyle(
                    color: AppColors.onAction,
                    fontWeight: AppFontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => context.go(AppRoutes.home),
          icon: const Icon(LucideIcons.home),
          label: const Text('Back to Home'),
        ),
      ],
    );
  }
}

// ── Small shared widgets ──────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.inkMuted),
        const SizedBox(width: 5),
        Text(label, style: context.caption.copyWith(color: AppColors.inkMuted)),
      ],
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  final Color color;

  const _BulletItem({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: context.caption.copyWith(
                color: AppColors.ink,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final QuestionType type;

  const _TypePill({required this.type});

  @override
  Widget build(BuildContext context) {
    return CategoryBadge(label: type.label, icon: type.icon, dense: true);
  }
}
