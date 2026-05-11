import 'package:flutter/material.dart';
import '../../data/models/topic.dart';
import '../../../../core/constants/app_constants.dart';

class TopicCard extends StatelessWidget {
  final Topic topic;
  final VoidCallback onTap;

  const TopicCard({super.key, required this.topic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = topic.category.categoryColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Text(
                topic.category,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600, color: color),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              topic.title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: AppColors.textDark),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              topic.hint,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textMedium, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
