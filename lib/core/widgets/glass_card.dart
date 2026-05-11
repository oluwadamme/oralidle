import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Glassmorphism card with backdrop blur + 10% white border.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? borderColor;
  final Color? bgColor;
  final double blur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 16,
    this.borderColor,
    this.bgColor,
    this.blur = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bgColor ?? AppColors.surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor ?? AppColors.cardBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Blurred ambient glow orb for background depth.
class AmbientOrb extends StatelessWidget {
  final Color color;
  final double size;

  const AmbientOrb({super.key, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

/// Circular score badge with thick ring + optional glow.
class ScoreRing extends StatelessWidget {
  final int score;
  final Color color;
  final double size;
  final double strokeWidth;
  final bool showGlow;

  const ScoreRing({
    super.key,
    required this.score,
    required this.color,
    this.size = 110,
    this.strokeWidth = 7,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showGlow)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          SizedBox(
            width: size - 4,
            height: size - 4,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: size * 0.3,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
              Text(
                '/100',
                style: TextStyle(
                  fontSize: size * 0.1,
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
