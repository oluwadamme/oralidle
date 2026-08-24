import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/score_meter.dart';
import '../../../../core/widgets/surface_card.dart';

class MetricScoreCard extends StatelessWidget {
  final String label;
  final int score;
  final IconData icon;

  const MetricScoreCard({
    super.key,
    required this.label,
    required this.score,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(icon, color: AppColors.inkMuted, size: IconSize.sm),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  label,
                  style: context.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          ScoreMeter(score: score, label: label, size: ScoreMeterSize.card),
        ],
      ),
    );
  }
}
