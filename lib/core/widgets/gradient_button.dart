import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'pressable.dart';

class PrimaryGradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final double height;
  final List<Color>? gradientColors;
  final Color textColor;
  final Color iconColor;
  final double fontSize;
  final BorderRadius? borderRadius;

  const PrimaryGradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.height = 54,
    this.gradientColors,
    this.textColor = AppColors.onAction,
    this.iconColor = AppColors.onAction,
    this.fontSize = 15,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = gradientColors ??
        const [AppColors.primaryLight, AppColors.primary];
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(14);

    return Pressable(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.action,
          borderRadius: effectiveBorderRadius,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: AppFontWeight.w800,
                fontSize: fontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
