import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';
import 'waveform_loader.dart';

enum AppButtonSize {
  small(40, IconSize.sm),
  medium(TouchTarget.min, IconSize.md),
  large(52, IconSize.md);

  const AppButtonSize(this.height, this.icon);
  final double height;
  final double icon;
}

enum _Kind { primary, secondary, destructive, quiet }

/// The app's buttons. See DESIGN.md §4.
class AppButton extends StatelessWidget {
  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = AppButtonSize.medium,
    this.expand = false,
    this.busy = false,
    this.semanticHint,
  }) : _kind = _Kind.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = AppButtonSize.medium,
    this.expand = false,
    this.busy = false,
    this.semanticHint,
  }) : _kind = _Kind.secondary;

  /// An outline, never a filled red block. A filled `critical` also fails
  /// contrast for its own label, so the outline is the accessible form too.
  const AppButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = AppButtonSize.medium,
    this.expand = false,
    this.busy = false,
    this.semanticHint,
  }) : _kind = _Kind.destructive;

  const AppButton.quiet({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = AppButtonSize.small,
    this.expand = false,
    this.busy = false,
    this.semanticHint,
  }) : _kind = _Kind.quiet;

  final String label;
  final IconData? icon;

  /// Null renders as disabled and is announced as such.
  final VoidCallback? onPressed;

  final AppButtonSize size;
  final bool expand;

  final bool busy;

  final String? semanticHint;
  final _Kind _kind;

  bool get _enabled => onPressed != null && !busy;

  static bool get _canVibrate =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  void _handle() {
    if (_canVibrate) HapticFeedback.selectionClick();
    onPressed!.call();
  }

  Color get _foreground => switch (_kind) {
    _Kind.primary => AppColors.onAction,
    _Kind.secondary => AppColors.ink,
    _Kind.destructive => AppColors.critical,
    _Kind.quiet => AppColors.inkMuted,
  };

  @override
  Widget build(BuildContext context) {
    final child = _Content(
      label: label,
      icon: icon,
      size: size,
      busy: busy,
      foreground: _foreground,
    );

    final minimum = Size(0, size.height);
    final padding = EdgeInsets.symmetric(
      horizontal: _kind == _Kind.quiet ? Space.md : Space.xl,
    );

    final button = switch (_kind) {
      _Kind.primary => FilledButton(
        onPressed: _enabled ? _handle : null,
        style: FilledButton.styleFrom(minimumSize: minimum, padding: padding),
        child: child,
      ),
      _Kind.secondary => OutlinedButton(
        onPressed: _enabled ? _handle : null,
        style: OutlinedButton.styleFrom(minimumSize: minimum, padding: padding),
        child: child,
      ),
      _Kind.destructive => OutlinedButton(
        onPressed: _enabled ? _handle : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.critical,
          backgroundColor: Colors.transparent,
          minimumSize: minimum,
          padding: padding,
          side: const BorderSide(color: AppColors.critical),
        ),
        child: child,
      ),
      _Kind.quiet => TextButton(
        onPressed: _enabled ? _handle : null,
        style: TextButton.styleFrom(minimumSize: minimum, padding: padding),
        child: child,
      ),
    };

    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      hint: semanticHint,
      excludeSemantics: true,
      child: expand ? _Expanded(child: button) : button,
    );
  }
}

class _Expanded extends StatelessWidget {
  const _Expanded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => constraints.hasBoundedWidth
          ? SizedBox(width: double.infinity, child: child)
          : child,
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.label,
    required this.icon,
    required this.size,
    required this.busy,
    required this.foreground,
  });

  final String label;
  final IconData? icon;
  final AppButtonSize size;
  final bool busy;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    if (busy) {
     return Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 0, child: _row(context)),
          WaveformLoader.compact(
            height: size.icon * 0.85,
            barCount: 4,
            barWidth: 2.5,
            color: foreground,
          ),
        ],
      );
    }
    return _row(context);
  }

  Widget _row(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (icon != null) ...[
        ExcludeSemantics(child: Icon(icon, size: size.icon)),
        const SizedBox(width: Space.sm),
      ],
      Flexible(
        child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
      ),
    ],
  );
}

/// An icon-only control.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = IconSize.md,
    this.color,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  final String tooltip;

  final double size;
  final Color? color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      selected: selected,
      label: tooltip,
      excludeSemantics: true,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: size),
        tooltip: tooltip,
        color: color ?? (selected ? AppColors.ink : AppColors.inkMuted),
      ),
    );
  }
}
