import 'package:flutter/material.dart';

/// Layout and motion tokens. See DESIGN.md §9 and §10.
///
/// Static holders rather than a `ThemeExtension`: the app is dark-only, so
/// there is no second theme for these to vary across, and
/// `Theme.of(context).extension<T>()!` at several hundred call sites buys
/// nothing but ceremony. This also matches how [AppColors] is already reached
/// for throughout the app.

/// The spacing scale. Nothing between these values. (§9)
abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
  static const huge = 64.0;
}

/// Corner radii. (§9)
abstract final class Radii {
  static const sm = 8.0;
  static const md = 12.0; // buttons, inputs
  static const lg = 16.0; // cards
  static const pill = 999.0;
  static const bar = 2.0; // waveform bar

  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
  static const pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Icon sizes. [xs] exists only for dense inline meta rows, where 16 crowds
/// the line; it is not a general-purpose small icon. (§9)
abstract final class IconSize {
  static const xs = 14.0;
  static const sm = 16.0;
  static const md = 20.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// Touch targets. (§8, §11)
abstract final class TouchTarget {
  static const min = 48.0;

  /// The record control, and the only circle in the app. (§4)
  static const record = 76.0;
}

/// Motion tokens. Every animation in the app draws its duration from here so
/// the whole product shares one rhythm. (§10)
abstract final class Motion {
  static const press = Duration(milliseconds: 90);
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 220);

  /// Deceleration on arrival.
  static const curve = Curves.easeOutCubic;

  /// Exits run at roughly 70% of the entering duration, which reads as
  /// responsive rather than hurried.
  static Duration exit(Duration enter) =>
      Duration(milliseconds: (enter.inMilliseconds * 0.7).round());
}

extension MotionContext on BuildContext {
  /// Whether the viewer has asked for reduced motion.
  ///
  /// Under this, data keeps flowing and only decoration stops — meters snap to
  /// their value, the waveform still reports level but stops its ticker. (§10)
  bool get reduceMotion => MediaQuery.maybeOf(this)?.disableAnimations ?? false;

  /// A duration that collapses to zero under reduced motion.
  Duration motion(Duration d) => reduceMotion ? Duration.zero : d;
}
