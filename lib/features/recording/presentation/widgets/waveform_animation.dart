import 'dart:math';
import 'package:flutter/material.dart';

class WaveformAnimation extends StatefulWidget {
  final bool isActive;
  final Color color;

  const WaveformAnimation({
    super.key,
    required this.isActive,
    this.color = const Color(0xFF3D5A99),
  });

  @override
  State<WaveformAnimation> createState() => _WaveformAnimationState();
}

class _WaveformAnimationState extends State<WaveformAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _rng = Random();
  late List<double> _heights;

  static const _barCount = 28;

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
        (i) => widget.isActive
            ? 0.15 + _rng.nextDouble() * 0.85
            : 0.2,
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
              color: widget.color.withValues(
                alpha: widget.isActive ? 0.6 + _heights[i] * 0.4 : 0.3,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}
