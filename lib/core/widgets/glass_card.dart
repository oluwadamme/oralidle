import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? borderColor;
  final Color? bgColor;

  @Deprecated('Backdrop blur was retired; this value is ignored.')
  final double blur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 16,
    this.borderColor,
    this.bgColor,
    // ignore: deprecated_member_use_from_same_package
    this.blur = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.cardBorder),
      ),
      child: child,
    );
  }
}

/// Soft background wash.
///
/// Kept as a radial gradient rather than a blurred circle: a 55-sigma
/// `ImageFilter.blur` is expensive to composite, and there are two dozen of
/// these across the app. The gradient renders the same shape for free.
class AmbientOrb extends StatelessWidget {
  final Color color;
  final double size;

  const AmbientOrb({super.key, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.06), color.withValues(alpha: 0.0)],
            stops: const [0.0, 0.55, 1.0],
          ),
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
