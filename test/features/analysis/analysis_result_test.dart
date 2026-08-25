import 'package:flutter_test/flutter_test.dart';
import 'package:widget_overlay_outside/features/analysis/data/models/analysis_result.dart';
import 'package:widget_overlay_outside/features/analysis/data/models/session_record.dart';

void main() {
  group('AnalysisResult serialization', () {
    test('serializes and deserializes transcript correctly', () {
      const result = AnalysisResult(
        scores: SpeechScores(
          fluency: 85,
          vocabulary: 80,
          grammar: 90,
          coherence: 88,
          topicRelevance: 95,
          confidence: 82,
        ),
        overallScore: 87,
        fillerWords: {'um': 2, 'like': 1},
        wpm: 135,
        strengths: ['Great pace', 'Clear articulation'],
        improvements: [
          ImprovementTip(area: 'Fluency', tip: 'Reduce um sounds'),
        ],
        summary: 'Solid presentation with strong topic relevance.',
        transcript:
            'I believe effective communication is essential for leadership.',
      );

      final json = result.toJson();
      expect(
        json['transcript'],
        equals(
          'I believe effective communication is essential for leadership.',
        ),
      );

      final restored = AnalysisResult.fromJson(json);
      expect(restored.transcript, equals(result.transcript));
      expect(restored.overallScore, equals(87));
      expect(restored.summary, equals(result.summary));
    });

    test('defaults transcript to empty string when absent in json', () {
      final json = {
        'scores': {
          'fluency': 70,
          'vocabulary': 70,
          'grammar': 70,
          'coherence': 70,
          'topic_relevance': 70,
          'confidence': 70,
        },
        'overall_score': 70,
        'filler_words': {},
        'wpm': 120,
        'strengths': [],
        'improvements': [],
        'summary': 'Good job',
      };

      final restored = AnalysisResult.fromJson(json);
      expect(restored.transcript, equals(''));
    });
  });

  group('SessionRecord with transcript', () {
    test('serializes and deserializes SessionRecord with transcript', () {
      final record = SessionRecord(
        id: 'test-session-1',
        topicTitle: 'Leadership Style',
        topicCategory: 'Career',
        timestamp: DateTime(2026, 8, 19, 17, 30),
        durationSeconds: 45,
        result: const AnalysisResult(
          scores: SpeechScores(
            fluency: 80,
            vocabulary: 80,
            grammar: 80,
            coherence: 80,
            topicRelevance: 80,
            confidence: 80,
          ),
          overallScore: 80,
          fillerWords: {},
          wpm: 140,
          strengths: [],
          improvements: [],
          summary: 'Well structured answer.',
          transcript: 'My leadership style relies on empathy and clear goals.',
        ),
      );

      final json = record.toJson();
      final restored = SessionRecord.fromJson(json);

      expect(
        restored.result.transcript,
        equals('My leadership style relies on empathy and clear goals.'),
      );
      expect(restored.topicTitle, equals('Leadership Style'));
      expect(restored.audioPath, isNull);
    });

    test('serializes and deserializes SessionRecord with audioPath', () {
      final record = SessionRecord(
        id: 'test-session-audio',
        topicTitle: 'Project Retrospective',
        topicCategory: 'Engineering',
        timestamp: DateTime(2026, 8, 24, 21, 0),
        durationSeconds: 75,
        audioPath: '/data/user/0/com.oradile/recordings/test-session-audio.wav',
        result: const AnalysisResult(
          scores: SpeechScores(
            fluency: 88,
            vocabulary: 85,
            grammar: 92,
            coherence: 86,
            topicRelevance: 90,
            confidence: 84,
          ),
          overallScore: 88,
          fillerWords: {'like': 1},
          wpm: 145,
          strengths: ['Great pacing'],
          improvements: [],
          summary: 'Clear and well-paced presentation.',
          transcript: 'In this sprint we improved our test coverage.',
        ),
      );

      final json = record.toJson();
      expect(
        json['audio_path'],
        equals('/data/user/0/com.oradile/recordings/test-session-audio.wav'),
      );

      final restored = SessionRecord.fromJson(json);
      expect(
        restored.audioPath,
        equals('/data/user/0/com.oradile/recordings/test-session-audio.wav'),
      );
      expect(restored.id, equals('test-session-audio'));
      expect(restored.durationSeconds, equals(75));
    });
  });
}
