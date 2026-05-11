import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../analysis/data/models/session_record.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../topic_selection/data/models/topic.dart';

class SessionTile extends StatelessWidget {
  final SessionRecord record;
  final VoidCallback onTap;

  const SessionTile({super.key, required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final score = record.result.overallScore;
    final color = AppColors.scoreColor(score);
    final categoryColor = record.topicCategory.categoryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: AppColors.glassCard(radius: 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              alignment: Alignment.center,
              child: Text(
                '$score',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.topicTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          record.topicCategory,
                          style: TextStyle(
                              fontSize: 10, color: categoryColor, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${record.formattedDuration} • ${record.result.wpm} wpm',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMedium),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM d, h:mm a').format(record.timestamp),
                    style: const TextStyle(fontSize: 11, color: AppColors.outline),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}
