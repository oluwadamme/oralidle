import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/text_styles.dart';

class StatSummaryCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const StatSummaryCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: AppColors.raised,
        borderRadius: Radii.lgAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: context.title.copyWith(
              color: color,
              fontWeight: AppFontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: context.caption.copyWith(color: AppColors.inkMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
