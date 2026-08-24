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


/// Design tokens for the Oralidle dark system. See DESIGN.md.
///
/// Every value here was derived against WCAG 2.2 and carries its measured
/// ratio. The two rules that shape the whole palette:
///
///   1. Depth comes from borders, not fills. Dark-on-dark fills cannot clear
///      3:1 — a surface would have to be mid-grey to manage it — so anything
///      interactive is identified by [borderControl] instead. (§2)
///   2. Chroma belongs to the user's voice. Controls are achromatic; the
///      record button is the single exception, because it is the one control
///      that is about the user's voice. (§3, §4)
class AppColors {
  // ── Surfaces. Fills carry hierarchy only; they are not asked to clear 3:1.
  static const canvas = Color(0xFF08100E);
  static const raised = Color(0xFF111A18); // 1.09:1 vs canvas
  static const raised2 = Color(0xFF1A2523); // 1.22:1
  static const sunken = Color(0xFF050B0A); // 1.03:1

  // ── Borders. Only [borderControl] is a WCAG claim; the other two are
  // decorative separation and must never be the sole marker of a control.
  static const line = Color(0xFF2A3937); // 1.59:1 — decorative
  static const lineStrong = Color(0xFF3E524E); // 2.31:1 — decorative
  static const borderControl = Color(0xFF5E736D); // 3.80:1 — clears 1.4.11

  // ── Voice ramp. Four stops, because a speaker's real question is "am I in
  // a good range?", which a two-ended ramp cannot answer.
  static const voiceRest = Color(0xFF55746E); // 3.77:1 — silence, unlit bar
  static const voiceLow = Color(0xFF46C8BC); // 9.40:1 — quiet but audible
  static const voiceMid = Color(0xFF7BD98A); // 11.12:1 — the sweet spot
  static const voicePeak = Color(0xFFF2B33F); // 10.36:1 — too loud

  // ── Actions. Achromatic on purpose: chroma is spent on the voice, which
  // leaves the primary action as the highest-contrast object on the screen.
  static const action = Color(0xFFECF1EF);
  static const onAction = Color(0xFF08100E); // 16.86:1 on [action]

  // ── Text. All three clear 4.5:1 on every surface in the ladder.
  static const ink = Color(0xFFECF1EF); // 16.86:1 vs canvas
  static const inkMuted = Color(0xFFA7B7B2); // 9.22:1
  static const inkFaint = Color(0xFF7C8E89); // 5.58:1 — disabled, not "small"

  // ── Semantic. Genuine system state only, never a score. Always paired with
  // an icon or text, per WCAG 1.4.1.
  static const positive = Color(0xFF5FC98F); // 9.39:1
  static const caution = Color(0xFFF2B33F); // 10.36:1 — same as voicePeak
  static const critical = Color(0xFFE8917F); // 8.06:1 — soft, never alarm-red

  /// Position on the voice ramp, `t` in 0..1, where `t` is real amplitude.
  ///
  /// Piecewise rather than a straight two-colour lerp so the ideal band gets
  /// its own stop: a speaker should be able to see that they are in the sweet
  /// spot, not just that they are louder than they were.
  static Color voiceColor(double t) {
    final v = t.clamp(0.0, 1.0);
    if (v < _quietAt) {
      return Color.lerp(voiceRest, voiceLow, v / _quietAt)!;
    }
    if (v < _idealAt) {
      return Color.lerp(voiceLow, voiceMid, (v - _quietAt) / (_idealAt - _quietAt))!;
    }
    return Color.lerp(voiceMid, voicePeak, (v - _idealAt) / (1 - _idealAt))!;
  }

  // ── Legacy names, retired during the v2 migration ───────────────────────
  //
  // These keep the tree compiling while call sites move over. Every one is
  // deleted once its last reference is gone; nothing new should reach for
  // them. Where the old system was semantically wrong the alias points at the
  // corrected value rather than preserving the mistake — `scoreColor` is the
  // clearest case, since it used to paint a 95 in warning-amber.

  @Deprecated('Use canvas')
  static const background = canvas;
  @Deprecated('Use raised')
  static const surface = raised;
  @Deprecated('Use raised')
  static const surfaceLow = raised;
  @Deprecated('Use raised2')
  static const surfaceHigh = raised2;
  @Deprecated('Use raised2')
  static const surfaceHighest = raised2;
  @Deprecated('Use line, or borderControl if it identifies a control')
  static const cardBorder = line;
  @Deprecated('Use line')
  static const outlineVariant = line;
  @Deprecated('Use inkMuted for text, borderControl for boundaries')
  static const outline = borderControl;
  @Deprecated('Use ink')
  static const textDark = ink;
  @Deprecated('Use inkMuted')
  static const textMedium = inkMuted;
  @Deprecated('Use voiceLow, or action for a button')
  static const primary = voiceLow;
  @Deprecated('Use voiceMid')
  static const primaryLight = voiceMid;
  @Deprecated('Use onAction')
  static const onPrimary = onAction;
  @Deprecated('Use caution, or voicePeak in the meter')
  static const amberColor = caution;
  @Deprecated('Use positive')
  static const good = positive;
  @Deprecated('Use caution')
  static const fair = caution;
  @Deprecated('Use critical')
  static const poor = critical;
  @Deprecated('Use voiceLow')
  static const levelLow = voiceLow;
  @Deprecated('Use voicePeak')
  static const levelHigh = voicePeak;
  @Deprecated('Use voiceRest')
  static const levelRest = voiceRest;
  @Deprecated('Use sunken')
  static const scoreTrack = sunken;

  @Deprecated('Use voiceColor')
  static Color levelColor(double t) => voiceColor(t);

  /// Score is achromatic now: colour carried no information here and actively
  /// misled, so this returns [ink] regardless of value. DESIGN.md §5.
  @Deprecated('Score is achromatic; use ink on a sunken track')
  static Color scoreColor(int score) => ink;

  @Deprecated('Use SurfaceCard')
  static BoxDecoration glassCard({
    double radius = 16,
    Color? borderColor,
    Color? bgColor,
  }) =>
      BoxDecoration(
        color: bgColor ?? raised,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? line),
      );

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

abstract class AppFontSize {
  static const double f9 = 9;
  static const double f10 = 10;
  static const double f11 = 11;
  static const double f12 = 12;
  static const double f13 = 13;
  static const double f14 = 14;
  static const double f15 = 15;
  static const double f16 = 16;
  static const double f17 = 17;
  static const double f18 = 18;
  static const double f20 = 20;
  static const double f22 = 22;
  static const double f24 = 24;
  static const double f30 = 30;
  static const double f32 = 32;
  static const double f34 = 34;
  static const double f40 = 40;
  static const double f44 = 44;
  static const double f56 = 56;
}

