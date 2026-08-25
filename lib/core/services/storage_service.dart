import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io' show Directory, File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/analysis/data/models/session_record.dart';
import '../constants/app_constants.dart';

class StorageService {
  Box<String> get _box => Hive.box<String>(AppConstants.hiveSessionsBox);

  Future<void> saveSession(SessionRecord session) async {
    await _box.put(session.id, jsonEncode(session.toJson()));
  }

  Future<String?> saveAudioFile(
    String id,
    Uint8List bytes, {
    String extension = 'wav',
    String? mimeType,
  }) async {
    try {
      if (kIsWeb) {
        final mime = mimeType ?? 'audio/${extension.replaceAll('.', '')}';
        final base64Str = base64Encode(bytes);
        return 'data:$mime;base64,$base64Str';
      } else {
        final docsDir = await getApplicationDocumentsDirectory();
        final recordingsDir = Directory('${docsDir.path}/recordings');
        if (!await recordingsDir.exists()) {
          await recordingsDir.create(recursive: true);
        }
        final ext = extension.replaceAll('.', '');
        final file = File('${recordingsDir.path}/$id.$ext');
        await file.writeAsBytes(bytes);
        return file.path;
      }
    } catch (e) {
      log('StorageService: failed to save audio file for session $id: $e');
      return null;
    }
  }

  List<SessionRecord> getSessions() {
    return _box.values
        .map(
          (raw) =>
              SessionRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        )
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> deleteSession(String id) async {
    final raw = _box.get(id);
    if (raw != null) {
      try {
        final session = SessionRecord.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (session.audioPath != null && !kIsWeb && !session.audioPath!.startsWith('data:')) {
          final file = File(session.audioPath!);
          if (await file.exists()) {
            await file.delete();
          }
        }
      } catch (e) {
        log('StorageService: error deleting audio file for session $id: $e');
      }
    }
    await _box.delete(id);
  }

  int calculateStreak() {
    final sessions = getSessions();
    if (sessions.isEmpty) return 0;

    final dates =
        sessions
            .map(
              (s) => DateTime(
                s.timestamp.year,
                s.timestamp.month,
                s.timestamp.day,
              ),
            )
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
