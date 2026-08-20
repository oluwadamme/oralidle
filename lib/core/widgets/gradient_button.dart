import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

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
    this.textColor = const Color(0xFF490080),
    this.iconColor = const Color(0xFF490080),
    this.fontSize = 15,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = gradientColors ??
        const [AppColors.primaryLight, AppColors.primary];
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(14);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: effectiveGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: effectiveBorderRadius,
          boxShadow: [
            BoxShadow(
              color: effectiveGradient.last.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
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
                fontWeight: FontWeight.w800,
                fontSize: fontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
