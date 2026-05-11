import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';

class WaveformAnimation extends StatefulWidget {
  final bool isActive;

  const WaveformAnimation({super.key, required this.isActive});

  @override
  State<WaveformAnimation> createState() => _WaveformAnimationState();
}

class _WaveformAnimationState extends State<WaveformAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _rng = Random();
  late List<double> _heights;

  static const _barCount = 28;

  // Gradient: primary purple → amber (Lumina design spec)
  static const _colorStart = AppColors.primary; // #DDB7FF
  static const _colorEnd = AppColors.amber;      // #FFB95F

  @override
  void initState() {
    super.initState();
    _heights = List.generate(_barCount, (_) => 0.2);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..addListener(_updateBars);

    if (widget.isActive) _controller.repeat();
  }

  void _updateBars() {
    if (!mounted) return;
    setState(() {
      _heights = List.generate(
        _barCount,
        (i) => widget.isActive ? 0.15 + _rng.nextDouble() * 0.85 : 0.2,
      );
    });
  }

  @override
  void didUpdateWidget(WaveformAnimation old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      setState(() => _heights = List.generate(_barCount, (_) => 0.2));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _barColor(int index, double height) {
    final t = index / (_barCount - 1);
    final r = lerpDouble(_colorStart.r, _colorEnd.r, t)!;
    final g = lerpDouble(_colorStart.g, _colorEnd.g, t)!;
    final b = lerpDouble(_colorStart.b, _colorEnd.b, t)!;
    final alpha = widget.isActive ? 0.55 + height * 0.45 : 0.25;
    return Color.from(alpha: alpha, red: r, green: g, blue: b);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_barCount, (i) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: 4,
            height: 60 * _heights[i],
            decoration: BoxDecoration(
              color: _barColor(i, _heights[i]),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}
