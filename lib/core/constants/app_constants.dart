import 'package:flutter/material.dart';

class AppConstants {
  static const int minRecordingSeconds = 60;
  static const int maxRecordingSeconds = 120;
  static const int prepCountdownSeconds = 30;
  static const int idealWpmMin = 110;
  static const int idealWpmMax = 160;
  static const String hiveSessionsBox = 'sessions';

  static const List<String> fillerWords = [
    'um', 'uh', 'er', 'like', 'basically', 'actually', 'literally',
    'you know', 'i mean', 'kind of', 'sort of', 'right','so', 'okay so',
  ];
}

class AppRoutes {
  static const home = '/';
  static const topics = '/topics';
  static const prepare = '/prepare';
  static const record = '/record';
  static const processing = '/processing';
  static const results = '/results';
  static const history = '/history';
}

/// Lumina Speech dark design system colours.
class AppColors {
  // ── Semantic score colours ─────────────────────────────────────────────────
  static const good = Color(0xFF4EDEA3);   // emerald – success / growth
  static const fair = Color(0xFFFFB95F);   // amber   – caution / warmth
  static const poor = Color(0xFFFFB4AB);   // soft-red – error

  // ── Brand ──────────────────────────────────────────────────────────────────
  static const primary = Color(0xFFDDB7FF);       // light purple (AI/CTA)
  static const primaryLight = Color(0xFFB76DFF);  // mid-purple (gradient end)
  static const amber = Color(0xFFFFB95F);         // alias for secondary

  // ── Surfaces (dark layering: lowest → highest) ────────────────────────────
  static const background = Color(0xFF131313);
  static const surface = Color(0xFF201F1F);
  static const surfaceHigh = Color(0xFF2A2A2A);
  static const surfaceHighest = Color(0xFF353534);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const textDark = Color(0xFFE5E2E1);
  static const textMedium = Color(0xFFCFC2D6);

  // ── Borders ────────────────────────────────────────────────────────────────
  static const outline = Color(0xFF988D9F);
  static const outlineVariant = Color(0xFF4D4354);
  static const cardBorder = Color(0x1AFFFFFF); // 10 % white – glass card edge

  // ── Helpers ────────────────────────────────────────────────────────────────
  static Color scoreColor(int score) {
    if (score >= 75) return good;
    if (score >= 50) return fair;
    return poor;
  }

  /// Glass-morphism card decoration used throughout the app.
  static BoxDecoration glassCard({
    double radius = 16,
    Color? borderColor,
    Color? bgColor,
  }) =>
      BoxDecoration(
        color: bgColor ?? surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? cardBorder),
      );
}
