import 'package:flutter/material.dart';

/// Layout breakpoints, following Material 3's window size classes.
///
/// The app was built phone-first; these exist so the same screens hold up
/// from a 360 px phone to a maximised desktop browser without every widget
/// inventing its own magic number.
abstract final class Breakpoints {
  /// Phones, and narrow browser windows.
  static const compact = 600.0;

  /// Large phones in landscape, small tablets.
  static const medium = 905.0;

  /// Tablets, laptops, desktop browsers. Above this the shell shows its
  /// sidebar instead of a bottom bar.
  static const expanded = 1240.0;

  /// Where screens switch from a single stacked column to two columns.
  /// Deliberately below [medium]: the split earns its keep well before a
  /// window is tablet-sized.
  static const twoColumn = 700.0;

  /// Reading measure for body content.
  ///
  /// Text lines much wider than this get hard to track back to the start, so
  /// content stops growing here and the extra space becomes margin.
  static const contentMaxWidth = 760.0;

  /// Wider ceiling for grids and dashboards, where multiple columns use the
  /// space productively rather than producing over-long lines.
  static const wideContentMaxWidth = 1180.0;
}

enum WindowSize { compact, medium, expanded }

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  WindowSize get windowSize {
    final width = screenWidth;
    if (width < Breakpoints.compact) return WindowSize.compact;
    if (width < Breakpoints.expanded) return WindowSize.medium;
    return WindowSize.expanded;
  }

  bool get isCompact => windowSize == WindowSize.compact;
  bool get isMedium => windowSize == WindowSize.medium;
  bool get isExpanded => windowSize == WindowSize.expanded;

  /// True where a two-column split is worth doing.
  bool get isWide => screenWidth >= Breakpoints.medium;

  /// Short windows — a laptop browser with devtools open, or a phone in
  /// landscape — where vertically generous spacing stops fitting.
  bool get isShort => screenHeight < 700;

  /// Picks a value for the current window size, falling back down the scale
  /// so only the sizes that actually differ need to be listed.
  T responsive<T>({required T compact, T? medium, T? expanded}) =>
      switch (windowSize) {
        WindowSize.compact => compact,
        WindowSize.medium => medium ?? compact,
        WindowSize.expanded => expanded ?? medium ?? compact,
      };

  /// Standard horizontal page padding for the current window size.
  double get pagePadding => responsive(compact: 20, medium: 28, expanded: 32);
}

/// Constrains content to a readable width and centres it.
///
/// Without this, every screen stretches to the full width of a desktop
/// browser — the single biggest thing that makes a phone layout look broken
/// on the web.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;

  /// Defaults to the reading measure; pass
  /// [Breakpoints.wideContentMaxWidth] for grids and dashboards.
  final double maxWidth;

  /// Horizontal padding. Defaults to the window size's standard page padding.
  final double? horizontalPadding;
  final EdgeInsets extraPadding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.contentMaxWidth,
    this.horizontalPadding,
    this.extraPadding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final padding = horizontalPadding ?? context.pagePadding;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth + padding * 2),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padding).add(extraPadding),
          child: child,
        ),
      ),
    );
  }
}

/// Page padding that centres content by growing the side margins.
///
/// Preferred over wrapping content in a `ConstrainedBox`: the background
/// stack (ambient orbs, gradients) still spans the full window, while the
/// content itself stops widening at [maxContentWidth]. Feed it the width
/// from a `LayoutBuilder` or `MediaQuery`.
EdgeInsets centeredPagePadding(
  double availableWidth, {
  double maxContentWidth = Breakpoints.wideContentMaxWidth,
  double minHorizontal = 20,
  double top = 0,
  double bottom = 0,
}) {
  final overflow = (availableWidth - maxContentWidth) / 2;
  final horizontal = overflow > minHorizontal ? overflow : minHorizontal;
  return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
}

/// Column count for a grid of cards, chosen so tiles keep a sensible width
/// instead of stretching with the window.
int responsiveColumns(
  double availableWidth, {
  double targetTileWidth = 220,
  int min = 2,
  int max = 5,
}) {
  final columns = (availableWidth / targetTileWidth).floor();
  return columns.clamp(min, max);
}
