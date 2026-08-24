import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';
import 'pressable.dart';

/// The elevation ladder from DESIGN.md §2.
enum SurfaceLevel {
  /// Cards and sheets.
  one(AppColors.raised, AppColors.line),

  /// Inputs, nested cards, anything interactive.
  two(AppColors.raised2, AppColors.line),

  /// Modals.
  three(AppColors.raised2, AppColors.lineStrong);

  const SurfaceLevel(this.fill, this.border);
  final Color fill;
  final Color border;
}

/// A card.
///
/// Named for what it is rather than for an effect it no longer has — the
/// widget this replaces was called `GlassCard` long after its blur was
/// removed, which kept sending people looking for glassmorphism that was not
/// there.
///
/// The important behaviour is the border. Dark-on-dark fills top out around
/// 1.2:1 against the canvas, so a fill step cannot tell anyone that a card is
/// interactive. When [onTap] is set this steps up to [SurfaceLevel.two] and
/// switches to [AppColors.borderControl] at 3.80:1, which can. (§2)
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.lg),
    this.level,
    this.radius = Radii.lg,
    this.onTap,
    this.semanticLabel,
    this.semanticHint,
    this.borderColor,
    this.selected = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Defaults to [SurfaceLevel.two] when interactive, [SurfaceLevel.one]
  /// otherwise.
  final SurfaceLevel? level;

  final double radius;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final String? semanticHint;

  /// Escape hatch. Prefer letting the level decide.
  final Color? borderColor;

  final bool selected;

  bool get _interactive => onTap != null;

  @override
  Widget build(BuildContext context) {
    final effectiveLevel =
        level ?? (_interactive ? SurfaceLevel.two : SurfaceLevel.one);

    final effectiveBorder =
        borderColor ??
        (selected
            ? AppColors.accent
            : _interactive
            ? AppColors.borderControl
            : effectiveLevel.border);

    final radii = BorderRadius.circular(radius);

    final surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveLevel.fill,
        borderRadius: radii,
        border: Border.all(color: effectiveBorder, width: selected ? 2 : 1),
      ),
      child: child,
    );

    if (!_interactive) return surface;

    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      semanticHint: semanticHint,
      selected: selected,
      borderRadius: radii,
      minSize: 0,
      child: surface,
    );
  }
}
