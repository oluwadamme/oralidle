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

class AppColors {
  static const good = Color(0xFF27AE60);
  static const fair = Color(0xFFF39C12);
  static const poor = Color(0xFFE74C3C);
  static const primary = Color(0xFF3D5A99);
  static const primaryLight = Color(0xFF6B8DD6);
  static const background = Color(0xFFF0F2F5);
  static const surface = Color(0xFFFFFFFF);
  static const textDark = Color(0xFF1A1A2E);
  static const textMedium = Color(0xFF6B7280);

  static Color scoreColor(int score) {
    if (score >= 75) return good;
    if (score >= 50) return fair;
    return poor;
  }
}
