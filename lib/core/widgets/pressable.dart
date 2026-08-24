import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';

class Pressable extends StatelessWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.semanticHint,
    this.selected = false,
    this.borderRadius = Radii.mdAll,
    this.minSize = TouchTarget.min,
    this.haptic = true,
    this.tooltip,
    this.padding,
  });

  final Widget child;

  /// A null callback renders as disabled and is announced as such.
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  final String? semanticLabel;
  final String? semanticHint;

  /// Announced as a selected state, and used by callers to tint the child.
  final bool selected;

  final BorderRadius borderRadius;
  final double minSize;
  final bool haptic;

  /// Also serves as the accessible name when [semanticLabel] is null.
  final String? tooltip;
  final EdgeInsetsGeometry? padding;

  bool get _enabled => onTap != null || onLongPress != null;

  /// Haptics are a no-op on web and desktop; the guard skips a pointless
  /// platform-channel round trip on every tap.
  static bool get _canVibrate =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  void _handleTap() {
    if (haptic && _canVibrate) HapticFeedback.selectionClick();
    onTap!.call();
  }

  @override
  Widget build(BuildContext context) {
    Widget result = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap == null ? null : _handleTap,
        onLongPress: onLongPress,
        borderRadius: borderRadius,
        splashColor: AppColors.accent.withValues(alpha: 0.10),
        highlightColor: AppColors.accent.withValues(alpha: 0.06),
        hoverColor: AppColors.ink.withValues(alpha: 0.04),
        focusColor: AppColors.accent.withValues(alpha: 0.12),
        child: minSize > 0 ? Center(child: child) : child,
      ),
    );

    if (minSize > 0) {
      result = ConstrainedBox(
        constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
        child: result,
      );
    }

    if (tooltip != null) {
      result = Tooltip(message: tooltip!, child: result);
    }

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Semantics(
        container: true,
        button: true,
        enabled: _enabled,
        selected: selected,
        label: semanticLabel ?? tooltip,
        hint: semanticHint,
        child: result,
      ),
    );
  }
}
