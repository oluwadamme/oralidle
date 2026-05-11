import 'dart:convert';
import 'package:hive_ce_flutter/hive_flutter.dart';
import '../../features/analysis/data/models/session_record.dart';
import '../constants/app_constants.dart';

class StorageService {
  Box<String> get _box => Hive.box<String>(AppConstants.hiveSessionsBox);

  Future<void> saveSession(SessionRecord session) async {
    await _box.put(session.id, jsonEncode(session.toJson()));
  }

  List<SessionRecord> getSessions() {
    return _box.values
        .map((raw) => SessionRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> deleteSession(String id) async {
    await _box.delete(id);
  }

  int calculateStreak() {
    final sessions = getSessions();
    if (sessions.isEmpty) return 0;

    final dates = sessions
        .map((s) => DateTime(s.timestamp.year, s.timestamp.month, s.timestamp.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    if (dates.first.difference(todayNorm).inDays.abs() > 1) return 0;

    int streak = 1;
    for (int i = 0; i < dates.length - 1; i++) {
      if (dates[i].difference(dates[i + 1]).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}
