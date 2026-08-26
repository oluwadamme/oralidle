import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:widget_overlay_outside/features/analysis/data/models/session_record.dart';

import '../../core/services/sync/fake_remote_store.dart';

void main() {
  group('SessionRecord', () {
    test('round-trips both audio locations', () {
      final original = fakeSession(
        id: 'a',
        audioPath: '/device/a.wav',
        audioObjectPath: 'user-1/a.wav',
      );

      final decoded = SessionRecord.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.id, original.id);
      expect(decoded.audioPath, '/device/a.wav');
      expect(decoded.audioObjectPath, 'user-1/a.wav');
      expect(decoded.timestamp, original.timestamp);
      expect(decoded.result.overallScore, original.result.overallScore);
    });

    test('reads a row written before audio_object_path existed', () {
      final legacy = {
        'id': 'legacy',
        'topic_title': 'A topic',
        'topic_category': 'general',
        'timestamp': DateTime(2026, 1, 1).toIso8601String(),
        'duration_seconds': 90,
        'result': fakeSession(id: 'x').result.toJson(),
        'audio_path': '/device/legacy.wav',
      };

      final decoded = SessionRecord.fromJson(legacy);

      expect(decoded.audioPath, '/device/legacy.wav');
      expect(decoded.audioObjectPath, isNull);
    });

    test('omits absent audio fields rather than writing nulls', () {
      final json = fakeSession(id: 'a').toJson();

      expect(json.containsKey('audio_path'), isFalse);
      expect(json.containsKey('audio_object_path'), isFalse);
    });

    test('copyWith keeps the local path when adding the object path', () {
      final updated = fakeSession(
        id: 'a',
        audioPath: '/device/a.wav',
      ).copyWith(audioObjectPath: 'user-1/a.wav');

      expect(updated.audioPath, '/device/a.wav');
      expect(updated.audioObjectPath, 'user-1/a.wav');
    });
  });
}
