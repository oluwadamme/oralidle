import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';
import '../theme/text_styles.dart';
import 'pressable.dart';

/// A neutral chip carrying an icon and a label. DESIGN.md §6, §8.
///
/// Categories are distinguished by glyph and word, never by hue.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({
    super.key,
    required this.label,
    required this.icon,
    this.selected = false,
    this.onTap,
    this.dense = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  /// Tighter padding for use inside a card header rather than as a filter.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? Space.sm : Space.md,
        vertical: dense ? Space.xs : Space.sm,
      ),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: Radii.pillAll,
        border: Border.all(color: selected ? AppColors.accent : AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: dense ? IconSize.xs : IconSize.sm,
            color: AppColors.accent,
          ),
          const SizedBox(width: Space.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.overline.copyWith(
                color: selected ? AppColors.accent : AppColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;

    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      semanticHint: selected ? 'Selected filter' : 'Filter by $label',
      borderRadius: Radii.pillAll,
      child: chip,
    );
  }
}
