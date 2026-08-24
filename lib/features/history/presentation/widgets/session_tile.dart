import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/category_badge.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/tabular_text.dart';
import '../../../analysis/data/models/session_record.dart';
import '../../../topic_selection/data/models/topic_category.dart';

class SessionTile extends StatelessWidget {
  final SessionRecord record;
  final VoidCallback onTap;

  const SessionTile({super.key, required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final score = record.result.overallScore;
    final band = AppColors.scoreColor(score);
    final category = TopicCategory.fromLabel(record.topicCategory);
    final transcript = record.result.transcript.trim();

    return Pressable(
      onTap: onTap,
      minSize: 0,
      borderRadius: Radii.mdAll,
      semanticLabel: record.topicTitle,
      semanticHint: '$score out of 100, ${category.label}',
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.md),
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: AppColors.raised,
          borderRadius: Radii.mdAll,
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The score is the tile's headline, so it takes its band colour
            // rather than a flat disc that told the reader nothing.
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: band.withValues(alpha: 0.16),
                border: Border.all(color: band.withValues(alpha: 0.45)),
              ),
              child: TabularText(
                '$score',
                style: context.readoutAt(
                  16,
                  color: band,
                  weight: AppFontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Four tiers, so the eye can rank them: title, then the
                  // category and measurements, then when, then what was said.
                  Text(
                    record.topicTitle,
                    style: context.cardTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: Space.sm),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      CategoryBadge(
                        label: category.label,
                        icon: category.icon,
                        dense: true,
                      ),
                      Text(
                        '${record.formattedDuration}  ·  ${record.result.wpm} wpm',
                        style: context.caption.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                      Text(
                        DateFormat('MMM d, h:mm a').format(record.timestamp),
                        style: context.caption.copyWith(
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                  if (transcript.isNotEmpty) ...[
                    const SizedBox(height: Space.sm),
                    Text(
                      '"$transcript"',
                      style: context.caption.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppColors.inkFaint,
                        height: 1.45,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            const Padding(
              padding: EdgeInsets.only(top: Space.md),
              child: Icon(
                LucideIcons.chevronRight,
                size: IconSize.md,
                color: AppColors.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
