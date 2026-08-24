import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/category_badge.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../data/models/topic.dart';
import '../../data/models/topic_category.dart';

class TopicCard extends StatelessWidget {
  final Topic topic;
  final VoidCallback onTap;

  const TopicCard({super.key, required this.topic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final category = TopicCategory.fromLabel(topic.category);

    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Space.lg),
      semanticLabel: '${topic.title}. ${category.label}',
      semanticHint: topic.hint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: CategoryBadge(
              label: category.label,
              icon: category.icon,
              dense: true,
            ),
          ),
          const SizedBox(height: Space.lg),
          Text(
            topic.title,
            style: context.cardTitle.copyWith(height: 1.3),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Space.md),
          const Spacer(),
          Text(
            topic.hint,
            style: context.caption.copyWith(
              color: AppColors.inkMuted,
              height: 1.45,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
