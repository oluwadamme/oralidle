import 'package:flutter/material.dart';

class AppConstants {
  static const int minRecordingSeconds = 60;
  static const int maxRecordingSeconds = 120;
  static const int prepCountdownSeconds = 30;
  static const int idealWpmMin = 110;
  static const int idealWpmMax = 160;
  static const String hiveSessionsBox = 'sessions';
  static const String hiveInterviewsBox = 'interview_sessions';

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
  static const interview = '/interview';
  static const interviewSession = '/interview/session';
  static const interviewResults = '/interview/results';
}

/// Oralidle dark design system colours.
class AppColors {
  // ── Level ramp — cool at conversational volume, warm at peak. DESIGN.md §2.
  static const levelLow = Color(0xFF4FB8A8);
  static const levelHigh = Color(0xFFE8A33D);
  static const levelRest = Color(0xFF2C4642); // unlit meter bar

  // ── Semantic. Real system states only — never a score verdict. ───────────
  static const good = Color(0xFF5BC38C);
  static const fair = Color(0xFFE8A33D);
  static const poor = Color(0xFFE08A7E);

  // ── Brand ──────────────────────────────────────────────────────────────────
  static const primary = levelLow;
  static const primaryLight = Color(0xFF6FD3C2);
  static const onPrimary = Color(0xFF06110F);
  static const amber = levelHigh;

  // ── Surfaces (dark layering: lowest → highest) ────────────────────────────
  static const background = Color(0xFF0E1513);
  static const surfaceLow = Color(0xFF121917);
  static const surface = Color(0xFF141C1A);
  static const surfaceHigh = Color(0xFF1B2422);
  static const surfaceHighest = Color(0xFF243230);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const textDark = Color(0xFFE6E9E5);
  static const textMedium = Color(0xFF8FA09B);

  // ── Borders ────────────────────────────────────────────────────────────────
  static const outline = Color(0xFF6B7A76);
  static const outlineVariant = Color(0xFF243230);
  static const cardBorder = Color(0x14FFFFFF); // 8 % white hairline

  // ── Helpers ────────────────────────────────────────────────────────────────
  /// Position on the level ramp, `t` in 0..1.
  static Color levelColor(double t) =>
      Color.lerp(levelLow, levelHigh, t.clamp(0.0, 1.0))!;

  /// A score read as a position on the ramp rather than a pass/fail hue.
  ///
  /// Someone practising their own voice should read a number as diagnostic,
  /// not as a verdict, so the scale is continuous and carries no red.
  static Color scoreColor(int score) => levelColor(score / 100);

  /// Track behind any score meter.
  static const scoreTrack = Color(0xFF243230);

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
