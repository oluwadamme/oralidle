import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';

/// An animated audio-waveform loader that replaces standard circular and linear
/// progress indicators across the app.
class WaveformLoader extends StatefulWidget {
  final double height;
  final int barCount;
  final double barWidth;
  final double barSpacing;
  final Color? color;
  final bool useVoiceColors;

  const WaveformLoader({
    super.key,
    this.height = 24,
    this.barCount = 7,
    this.barWidth = 3.5,
    this.barSpacing = 2.5,
    this.color,
    this.useVoiceColors = false,
  });

  /// Full-size hero waveform for prominent loading screens (e.g. ProcessingScreen).
  const WaveformLoader.hero({
    super.key,
    this.height = 36,
    this.barCount = 18,
    this.barWidth = 4,
    this.barSpacing = 3,
    this.color,
    this.useVoiceColors = true,
  });

  /// Compact inline waveform loader for buttons and small cards.
  const WaveformLoader.compact({
    super.key,
    this.height = 16,
    this.barCount = 4,
    this.barWidth = 2.5,
    this.barSpacing = 2,
    this.color,
    this.useVoiceColors = false,
  });

  @override
  State<WaveformLoader> createState() => _WaveformLoaderState();
}

class _WaveformLoaderState extends State<WaveformLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _resolveColor(int index, double heightRatio) {
    if (widget.color != null) return widget.color!;
    if (widget.useVoiceColors) {
      if (heightRatio < 0.35) return AppColors.voiceLow;
      if (heightRatio < 0.70) return AppColors.voiceMid;
      return AppColors.accent;
    }
    return AppColors.ink;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value * 2 * math.pi;

          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.barCount, (i) {
              final phase = (i / widget.barCount) * 2 * math.pi;
              final wave1 = math.sin(t + phase);
              final wave2 = math.cos(t * 1.5 - phase * 0.8);
              final rawHeight = (0.5 + 0.3 * wave1 + 0.2 * wave2).clamp(
                0.15,
                1.0,
              );

              final barColor = _resolveColor(i, rawHeight);

              return Container(
                margin: EdgeInsets.symmetric(
                  horizontal: widget.barSpacing / 2,
                ),
                width: widget.barWidth,
                height: widget.height * rawHeight,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(Radii.bar),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
