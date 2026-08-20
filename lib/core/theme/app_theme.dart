import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme)
        .copyWith(
          // Headings — Plus Jakarta Sans
          displayLarge: GoogleFonts.bricolageGrotesque(
              fontSize: 40, fontWeight: FontWeight.w700,
              letterSpacing: -0.8, color: AppColors.textDark),
          displayMedium: GoogleFonts.bricolageGrotesque(
              fontSize: 34, fontWeight: FontWeight.w700, color: AppColors.textDark),
          headlineLarge: GoogleFonts.bricolageGrotesque(
              fontSize: 32, fontWeight: FontWeight.w600,
              letterSpacing: -0.32, color: AppColors.textDark),
          headlineMedium: GoogleFonts.bricolageGrotesque(
              fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textDark),
          headlineSmall: GoogleFonts.bricolageGrotesque(
              fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark),
          titleLarge: GoogleFonts.bricolageGrotesque(
              fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark),
          titleMedium: GoogleFonts.bricolageGrotesque(
              fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark),
          titleSmall: GoogleFonts.bricolageGrotesque(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
          // Body — Manrope
          bodyLarge: GoogleFonts.manrope(fontSize: 16, color: AppColors.textDark),
          bodyMedium: GoogleFonts.manrope(fontSize: 14, color: AppColors.textMedium),
          bodySmall: GoogleFonts.manrope(fontSize: 12, color: AppColors.textMedium),
          // Labels and readouts — IBM Plex Mono, tabular figures
          labelLarge: GoogleFonts.ibmPlexMono(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
          labelMedium: GoogleFonts.ibmPlexMono(
              fontSize: 12, fontWeight: FontWeight.w500,
              letterSpacing: 0.7, color: AppColors.textMedium),
          labelSmall: GoogleFonts.ibmPlexMono(
              fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMedium),
        )
        .apply(
          bodyColor: AppColors.textDark,
          displayColor: AppColors.textDark,
        );

    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryLight,
        onPrimaryContainer: AppColors.onPrimary,
        secondary: AppColors.amber,
        onSecondary: AppColors.onPrimary,
        tertiary: AppColors.good,
        onTertiary: AppColors.onPrimary,
        error: AppColors.poor,
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        surface: AppColors.background,
        onSurface: AppColors.textDark,
        onSurfaceVariant: AppColors.textMedium,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        surfaceContainerLowest: AppColors.background,
        surfaceContainerLow: AppColors.surfaceLow,
        surfaceContainer: AppColors.surface,
        surfaceContainerHigh: AppColors.surfaceHigh,
        surfaceContainerHighest: AppColors.surfaceHighest,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.bricolageGrotesque(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: const Color(0xFF490080),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.bricolageGrotesque(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: AppColors.primary),
          textStyle: GoogleFonts.bricolageGrotesque(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.outlineVariant),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: GoogleFonts.manrope(color: AppColors.textDark, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.outlineVariant,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: TextStyle(color: AppColors.textMedium),
      ),
    );
  }

  // Keep old name working
  static ThemeData get light => dark;
}
