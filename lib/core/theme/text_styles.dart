import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../utils/responsive.dart';

/// Named type styles. See DESIGN.md §7.
///
/// This exists to win an ergonomics argument. The reason the app accumulated
/// ~168 inline `TextStyle(fontSize: ...)` is that the correct alternative,
/// `Theme.of(context).textTheme.bodyMedium`, is forty characters long and
/// returns a nullable. `context.body` is nine. Making the right thing shorter
/// than the wrong thing is the only durable fix.
extension AppText on BuildContext {
  TextTheme get _t => Theme.of(this).textTheme;

  /// Bricolage 32/700. Screen titles, score headline.
  TextStyle get display => _t.headlineLarge!;

  /// Bricolage 22/600. Section and card titles.
  TextStyle get title => _t.headlineSmall!;

  /// Bricolage 16/600. Card headers.
  TextStyle get cardTitle => _t.titleMedium!;

  /// 16/400. Questions, prompts, transcript.
  TextStyle get bodyL => _t.bodyLarge!;

  /// 14/400. Default UI text.
  TextStyle get body => _t.bodyMedium!;

  /// 12/400. Secondary detail.
  TextStyle get caption => _t.bodySmall!;

  /// 12/500, tracked and uppercase. Meter labels, chips, overlines.
  TextStyle get overline => _t.labelMedium!;

  /// 14/500. Any measured value.
  ///
  /// Wrap in `TabularText` if the value changes in place.
  TextStyle get readout => _t.labelLarge!;

  /// The recording clock, dropping to 44 on short viewports
  /// so it still fits a phone in landscape. (§7, §11)
  TextStyle get timer => _t.labelLarge!.copyWith(
    fontSize: isShort ? 44 : 56,
    fontWeight: AppFontWeight.w500,
    letterSpacing: -2,
    height: 1,
    color: AppColors.ink,
  );

  /// A measured value at an arbitrary size.
  ///
  /// Pair with `TabularText` whenever the value changes while on screen: the
  /// family is proportional, so digits reflow their own layout on every tick,
  /// which is what makes a running timer look broken.
  TextStyle readoutAt(double size, {Color? color, FontWeight? weight}) => _t
      .labelLarge!
      .copyWith(fontSize: size, color: color, fontWeight: weight, height: 1);
}
