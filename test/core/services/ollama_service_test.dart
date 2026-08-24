import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:widget_overlay_outside/core/services/ollama_service.dart';
import 'package:widget_overlay_outside/core/utils/speech_analyser.dart';

void main() {
  group('OllamaService', () {
    test('isAvailable returns true when server responds 200 OK', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/api/tags'));
        return http.Response('{"models":[]}', 200);
      });

      final service = OllamaService(client: mockClient);
      final available = await service.isAvailable();
      expect(available, isTrue);
    });

    test('isAvailable returns false on server error or timeout', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server error', 500);
      });

      final service = OllamaService(client: mockClient);
      final available = await service.isAvailable();
      expect(available, isFalse);
    });

    test('analyseTranscript formats prompt and parses JSON response', () async {
      final mockResponseBody = jsonEncode({
        'message': {
          'role': 'assistant',
          'content': '''
```json
{
  "scores": {
    "fluency": 82,
    "vocabulary": 78,
    "grammar": 85,
    "coherence": 80,
    "topic_relevance": 90,
    "confidence": 84
  },
  "overall_score": 83,
  "filler_words": { "um": 1 },
  "wpm": 130,
  "strengths": ["Clear delivery"],
  "improvements": [{"area": "Pace", "tip": "Slightly increase speed"}],
  "summary": "Solid speech performance overall."
}
```
''',
        },
      });

      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/api/chat'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], equals('llama3.2'));
        return http.Response(mockResponseBody, 200);
      });

      final service = OllamaService(client: mockClient);
      final result = await service.analyseTranscript(
        topic: 'Leadership',
        transcript: 'I believe effective leadership requires active listening.',
        durationSeconds: 30,
        metrics: SpeechAnalyser.analyse(
          'I believe effective leadership requires active listening.',
          30,
        ),
      );

      expect(result.overallScore, equals(83));
      expect(result.summary, equals('Solid speech performance overall.'));
      expect(
        result.transcript,
        equals('I believe effective leadership requires active listening.'),
      );
      expect(result.scores.fluency, equals(82));
    });

    test('throws exception when Ollama API returns error status', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Model not found', 404);
      });

      final service = OllamaService(client: mockClient);
      expect(
        () => service.analyseTranscript(
          topic: 'Test Topic',
          transcript: 'Test speech',
          durationSeconds: 10,
          metrics: SpeechAnalyser.analyse('Test speech', 10),
        ),
        throwsException,
      );
    });
  });
}
