import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_constants.dart';
import 'app_spacing.dart';

/// The app theme. See DESIGN.md §7 for the type scale and §4 for controls.
class AppTheme {
  /// Mono readouts are tabular so numbers keep their own width as they
  /// change. Without this a running timer reflows on every tick. (§7)
  static const _tabular = [FontFeature.tabularFigures()];

  /// Every focusable control gets the same 2px [AppColors.voiceLow] ring. (§4)
  static WidgetStateProperty<BorderSide?> _focusRing({BorderSide? base}) =>
      WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? const BorderSide(color: AppColors.voiceLow, width: 2)
            : base,
      );

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme)
        .copyWith(
          // Display — Bricolage Grotesque
          displayLarge: GoogleFonts.bricolageGrotesque(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              color: AppColors.ink),
          displayMedium: GoogleFonts.bricolageGrotesque(
              fontSize: 34, fontWeight: FontWeight.w700, color: AppColors.ink),
          headlineLarge: GoogleFonts.bricolageGrotesque(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: AppColors.ink),
          headlineMedium: GoogleFonts.bricolageGrotesque(
              fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.ink),
          headlineSmall: GoogleFonts.bricolageGrotesque(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.25,
              color: AppColors.ink),
          titleLarge: GoogleFonts.bricolageGrotesque(
              fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink),
          titleMedium: GoogleFonts.bricolageGrotesque(
              fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
          titleSmall: GoogleFonts.bricolageGrotesque(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
          // Body — Manrope
          bodyLarge: GoogleFonts.manrope(
              fontSize: 16, height: 1.55, color: AppColors.ink),
          bodyMedium: GoogleFonts.manrope(
              fontSize: 14, height: 1.5, color: AppColors.inkMuted),
          bodySmall: GoogleFonts.manrope(
              fontSize: 12, height: 1.5, color: AppColors.inkMuted),
          // Readouts — IBM Plex Mono, tabular
          labelLarge: GoogleFonts.ibmPlexMono(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFeatures: _tabular,
              color: AppColors.ink),
          labelMedium: GoogleFonts.ibmPlexMono(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.7,
              fontFeatures: _tabular,
              color: AppColors.inkMuted),
          labelSmall: GoogleFonts.ibmPlexMono(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              fontFeatures: _tabular,
              color: AppColors.inkMuted),
        )
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

    // Manrope, not Bricolage: a display face does not belong on a control.
    final controlLabel =
        GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600);

    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.action,
        onPrimary: AppColors.onAction,
        primaryContainer: AppColors.raised2,
        onPrimaryContainer: AppColors.ink,
        secondary: AppColors.voiceLow,
        onSecondary: AppColors.onAction,
        tertiary: AppColors.voiceMid,
        onTertiary: AppColors.onAction,
        error: AppColors.critical,
        onError: AppColors.onAction,
        errorContainer: AppColors.raised2,
        onErrorContainer: AppColors.critical,
        surface: AppColors.canvas,
        onSurface: AppColors.ink,
        onSurfaceVariant: AppColors.inkMuted,
        outline: AppColors.borderControl,
        outlineVariant: AppColors.line,
        surfaceContainerLowest: AppColors.sunken,
        surfaceContainerLow: AppColors.canvas,
        surfaceContainer: AppColors.raised,
        surfaceContainerHigh: AppColors.raised2,
        surfaceContainerHighest: AppColors.raised2,
      ),
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.bricolageGrotesque(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.raised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.lgAll,
          side: const BorderSide(color: AppColors.line),
        ),
        margin: EdgeInsets.zero,
      ),
      // Primary: an achromatic fill, which makes it the highest-contrast
      // object on the screen at 16.86:1. (§4)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.action,
          foregroundColor: AppColors.onAction,
          disabledBackgroundColor: AppColors.raised2,
          disabledForegroundColor: AppColors.inkFaint,
          minimumSize: const Size(TouchTarget.min, TouchTarget.min),
          shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
          textStyle: controlLabel,
          elevation: 0,
        ).copyWith(side: _focusRing()),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.action,
          foregroundColor: AppColors.onAction,
          disabledBackgroundColor: AppColors.raised2,
          disabledForegroundColor: AppColors.inkFaint,
          minimumSize: const Size(TouchTarget.min, TouchTarget.min),
          shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
          textStyle: controlLabel,
          elevation: 0,
        ).copyWith(side: _focusRing()),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.raised2,
          disabledForegroundColor: AppColors.inkFaint,
          minimumSize: const Size(TouchTarget.min, TouchTarget.min),
          shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
          textStyle: controlLabel,
        ).copyWith(
          side: _focusRing(
            base: const BorderSide(color: AppColors.borderControl),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.inkMuted,
          disabledForegroundColor: AppColors.inkFaint,
          minimumSize: const Size(TouchTarget.min, TouchTarget.min),
          shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
          textStyle: controlLabel,
        ).copyWith(side: _focusRing()),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.inkMuted,
          disabledForegroundColor: AppColors.inkFaint,
          minimumSize: const Size.square(TouchTarget.min),
          shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
        ).copyWith(side: _focusRing()),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.raised,
        indicatorColor: AppColors.raised2,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorShape:
            const RoundedRectangleBorder(borderRadius: Radii.pillAll),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        // An unselected tab is neither disabled nor a placeholder, so it gets
        // inkMuted (8.49:1) rather than inkFaint.
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.inkMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: IconSize.md,
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.inkMuted,
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.canvas,
        indicatorColor: AppColors.raised2,
        selectedIconTheme:
            IconThemeData(color: AppColors.ink, size: IconSize.md),
        unselectedIconTheme:
            IconThemeData(color: AppColors.inkMuted, size: IconSize.md),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.raised2,
        selectedColor: AppColors.raised2,
        side: const BorderSide(color: AppColors.line),
        shape: const RoundedRectangleBorder(borderRadius: Radii.pillAll),
        labelStyle: textTheme.labelMedium!,
        padding: const EdgeInsets.symmetric(
            horizontal: Space.md, vertical: Space.sm),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.raised2,
        contentTextStyle: textTheme.bodyMedium!.copyWith(color: AppColors.ink),
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.raised2,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: Radii.lgAll,
          side: BorderSide(color: AppColors.lineStrong),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.raised2,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.voiceLow,
        linearTrackColor: AppColors.sunken,
        circularTrackColor: AppColors.sunken,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: AppColors.raised2,
          borderRadius: Radii.smAll,
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.lineStrong),
          ),
        ),
        textStyle: textTheme.bodySmall!.copyWith(color: AppColors.ink),
        padding: const EdgeInsets.symmetric(
            horizontal: Space.sm, vertical: Space.xs),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.raised2,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: Space.lg, vertical: Space.md),
        border: const OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: AppColors.borderControl),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: AppColors.borderControl),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: AppColors.voiceLow, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: AppColors.critical),
        ),
        labelStyle: textTheme.bodyMedium,
        hintStyle: textTheme.bodyMedium!.copyWith(color: AppColors.inkFaint),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall!.copyWith(color: AppColors.critical),
      ),
    );
  }

  static ThemeData get light => dark;
}
