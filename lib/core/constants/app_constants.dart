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
    'um',
    'uh',
    'er',
    'like',
    'basically',
    'actually',
    'literally',
    'you know',
    'i mean',
    'kind of',
    'sort of',
    'right',
    'so',
    'okay so',
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

/// Design tokens for the Oralidle dark system. See DESIGN.md.
///
/// Ratios are stated against the hardest background each token renders on,
/// which is [raised2] for anything that can sit inside a nested card.
class AppColors {
  // ── Surfaces. A warm umber-black, not a neutral or a cool one: the product
  // is meant to feel encouraging rather than clinical, and the warmth is
  // doing that work before any accent arrives.
  static const canvas = Color(0xFF16110F);
  static const raised = Color(0xFF221A17); // 1.10:1 vs canvas
  static const raised2 = Color(0xFF2E2320); // 1.23:1
  static const sunken = Color(0xFF0E0A09); // wells and meter tracks

  static const line = Color(0xFF3A2D28); // decorative separation
  static const lineStrong = Color(0xFF4E3E37); // structural dividers
  static const borderControl = Color(0xFF8A756B); // 3.51:1 — clears 1.4.11

  // ── Accent. The brand colour, used generously: primary actions, active
  // navigation, selected state, score fills, and section markers.
  static const accent = Color(0xFFFF8A5B); // 6.56:1 — apricot
  static const accentSoft = Color(0xFFFFB392); // hover and subtle marks
  static const onAccent = Color(0xFF2B1206); // 7.58:1 on [accent]

  static const action = accent;
  static const onAction = onAccent;

  // ── Voice ramp. Four stops, because a speaker's real question is "am I in
  // a good range?", which a two-ended ramp cannot answer.
  //
  // Deliberately cool where the rest of the interface is warm, so the
  // waveform never reads as another piece of brand furniture. The peak is a
  // true red rather than an orange so it cannot be mistaken for [accent].
  static const voiceRest = Color(0xFF856F66); // 3.24:1 — silence, unlit bar
  static const voiceLow = Color(0xFF58C7D4); // 7.65:1 — quiet but audible
  static const voiceMid = Color(0xFF5FD9A4); // 8.67:1 — the sweet spot
  static const voicePeak = Color(0xFFE03131); // 3.38:1 — too loud

  // ── Text.
  static const ink = Color(0xFFF5EFEA); // 13.37:1 vs raised2
  static const inkMuted = Color(0xFFB0A099); // 6.05:1
  static const inkFaint = Color(0xFF9C8B82); // 4.67:1 — disabled, not "small"

  // ── Semantic. Genuine system state only, never a score. Always paired with
  // an icon or text, per WCAG 1.4.1.
  static const positive = Color(0xFF4FC98A); // 7.30:1
  static const caution = Color(0xFFF5B93C); // 8.63:1
  static const critical = Color(0xFFE03131); // 3.38:1 — same as voicePeak

  // ── Score bands. A four-stop ramp so a number reads at a glance.
  //
  // This is a deliberate exception to "colour never grades": the bands were
  // asked for so the breakdown is scannable. It is a ramp rather than a
  // red/green pass-fail — the low end is a soft coral, not an alarm red, and
  // the accent sits mid-scale so the brand stays present.
  static const scoreLow = Color(0xFFE0705C); // under 40
  static const scoreFair = Color(0xFFF0894B); // 40-59
  static const scoreGood = Color(0xFFE2C24E); // 60-79
  static const scoreHigh = Color(0xFF4FC98A); // 80+

  /// The band a score falls in.
  static Color scoreColor(int score) {
    if (score < 40) return scoreLow;
    if (score < 60) return scoreFair;
    if (score < 80) return scoreGood;
    return scoreHigh;
  }

  /// Continuous version, for a fill that should shade rather than step.
  static Color scoreRamp(double t) {
    final v = t.clamp(0.0, 1.0);
    if (v < 0.4) return Color.lerp(scoreLow, scoreFair, v / 0.4)!;
    if (v < 0.6) return Color.lerp(scoreFair, scoreGood, (v - 0.4) / 0.2)!;
    return Color.lerp(scoreGood, scoreHigh, (v - 0.6) / 0.4)!;
  }

  static Color voiceColor(double t) {
    final v = t.clamp(0.0, 1.0);
    if (v < _quietAt) {
      return Color.lerp(voiceRest, voiceLow, v / _quietAt)!;
    }
    if (v < _idealAt) {
      return Color.lerp(
        voiceLow,
        voiceMid,
        (v - _quietAt) / (_idealAt - _quietAt),
      )!;
    }
    return Color.lerp(voiceMid, voicePeak, (v - _idealAt) / (1 - _idealAt))!;
  }

  /// Where the ramp crosses from quiet into the ideal band, and from ideal
  /// into peak.
  static const _quietAt = 0.18;
  static const _idealAt = 0.55;
}

abstract class AppFontWeight {
  static const w400 = FontWeight.w400;
  static const w500 = FontWeight.w500;
  static const w600 = FontWeight.w600;
  static const w700 = FontWeight.w700;
  static const w800 = FontWeight.w800;
}

/// Sizes for the type scale in `AppTheme`.
///
/// The theme is the only place these belong; screens reach for the named
/// styles on `BuildContext` instead. `design_system_test.dart` enforces that.
abstract class AppFontSize {
  static const double f11 = 11;
  static const double f12 = 12;
  static const double f14 = 14;
  static const double f15 = 15;
  static const double f16 = 16;
  static const double f18 = 18;
  static const double f20 = 20;
  static const double f22 = 22;
  static const double f24 = 24;
  static const double f32 = 32;
  static const double f34 = 34;
  static const double f40 = 40;
}
