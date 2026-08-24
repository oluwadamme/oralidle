import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';
import '../theme/text_styles.dart';
import 'tabular_text.dart';

enum ScoreMeterSize {
  /// A row in a list of sub-scores.
  inline(readout: 14, track: 6),

  /// A single metric on its own card.
  card(readout: 32, track: 6),

  /// The headline score on a results screen.
  hero(readout: 56, track: 8);

  const ScoreMeterSize({required this.readout, required this.track});
  final double readout;
  final double track;
}

class ScoreMeter extends StatelessWidget {
  const ScoreMeter({
    super.key,
    required this.score,
    this.label,
    this.caption,
    this.previousAverage,
    this.size = ScoreMeterSize.inline,
    this.animate = true,
  });

  /// 0..100.
  final int score;

  final String? label;

  final String? caption;

  /// Marked on the track as a reference tick, if present.
  final int? previousAverage;

  final ScoreMeterSize size;
  final bool animate;

  double get _fraction => (score / 100).clamp(0.0, 1.0);

  String get _semanticValue {
    final base = '$score out of 100';
    if (previousAverage == null) return base;
    final delta = score - previousAverage!;
    if (delta == 0) return '$base, level with your average';
    final direction = delta > 0 ? 'up' : 'down';
    return '$base, $direction ${delta.abs()} from your average of '
        '$previousAverage';
  }

  @override
  Widget build(BuildContext context) {
    final isHero = size == ScoreMeterSize.hero;

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: label ?? 'Score',
      value: _semanticValue,
      child: Column(
        crossAxisAlignment: isHero
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isHero)
            _HeroReadout(score: score, size: size)
          else
            _InlineHeader(score: score, label: label, size: size),
          SizedBox(height: isHero ? Space.md : Space.sm),
          _Track(
            fraction: _fraction,
            previous: previousAverage,
            height: size.track,
            animate: animate,
            bandColor: AppColors.scoreColor(score),
          ),
          if (caption != null) ...[
            const SizedBox(height: Space.sm),
            Text(
              caption!,
              style: context.caption,
              textAlign: isHero ? TextAlign.center : TextAlign.start,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroReadout extends StatelessWidget {
  const _HeroReadout({required this.score, required this.size});

  final int score;
  final ScoreMeterSize size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        TabularText(
          '$score',
          style: context.readoutAt(
            size.readout,
            color: AppColors.scoreColor(score),
          ),
        ),
        Text('/100', style: context.caption),
      ],
    );
  }
}

class _InlineHeader extends StatelessWidget {
  const _InlineHeader({
    required this.score,
    required this.label,
    required this.size,
  });

  final int score;
  final String? label;
  final ScoreMeterSize size;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (label != null)
          Expanded(
            child: Text(
              label!,
              style: context.body.copyWith(color: AppColors.ink),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        TabularText(
          '$score',
          style: context.readoutAt(
            size.readout,
            color: AppColors.scoreColor(score),
          ),
        ),
      ],
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({
    required this.fraction,
    required this.previous,
    required this.height,
    required this.animate,
    required this.bandColor,
  });

  final Color bandColor;
  final double fraction;
  final int? previous;
  final double height;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final shouldAnimate = animate && !context.reduceMotion;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return SizedBox(
          height: height,
          child: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.sunken,
                    borderRadius: Radii.pillAll,
                  ),
                ),
              ),
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: shouldAnimate ? 0 : fraction,
                    end: fraction,
                  ),
                  duration: shouldAnimate ? Motion.base : Duration.zero,
                  curve: Motion.curve,
                  builder: (context, value, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: bandColor,
                        borderRadius: Radii.pillAll,
                      ),
                    ),
                  ),
                ),
              ),
              if (previous != null)
                Positioned(
                  left: (width - 2) * (previous!.clamp(0, 100) / 100),
                  top: -2,
                  bottom: -2,
                  child: const SizedBox(
                    width: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: AppColors.borderControl),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
