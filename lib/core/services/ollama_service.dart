import 'dart:convert';
import 'dart:developer' show log;
import 'package:http/http.dart' as http;
import '../../features/analysis/data/models/analysis_result.dart';
import '../utils/speech_analyser.dart';

class OllamaService {
  final String baseUrl;
  final String model;
  final http.Client _client;

  OllamaService({
    String? baseUrl,
    String? model,
    http.Client? client,
  })  : baseUrl = baseUrl ?? 'http://localhost:11434',
        model = model ?? 'llama3.2',
        _client = client ?? http.Client();

  /// Quick health check to verify if the local Ollama instance is reachable.
  Future<bool> isAvailable() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/tags'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<AnalysisResult> analyseTranscript({
    required String topic,
    required String transcript,
    required int durationSeconds,
    required PreComputedMetrics metrics,
  }) async {
    final fillerSummary = metrics.fillerWords.isEmpty
        ? 'none detected'
        : metrics.fillerWords.entries
            .map((e) => '${e.key} (${e.value}x)')
            .join(', ');

    final userMessage = '''
Topic: "$topic"
Duration: ${durationSeconds}s
Words per minute: ${metrics.wpm}
Lexical diversity (unique/total words): ${(metrics.uniqueWordRatio * 100).round()}%
Filler words detected: $fillerSummary

Transcript:
"$transcript"

Analyse this speech as a professional English coach. Return ONLY a JSON object — no markdown, no explanation. Use this exact schema:
{
  "scores": {
    "fluency": <0-100>,
    "vocabulary": <0-100>,
    "grammar": <0-100>,
    "coherence": <0-100>,
    "topic_relevance": <0-100>,
    "confidence": <0-100>
  },
  "overall_score": <0-100>,
  "filler_words": { "<word>": <count> },
  "wpm": ${metrics.wpm},
  "strengths": ["<string>", ...],
  "improvements": [{"area": "<string>", "tip": "<actionable advice>"}],
  "summary": "<2-3 sentence coaching summary>"
}
''';

    final response = await _client.post(
      Uri.parse('$baseUrl/api/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': model,
        'stream': false,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a professional English speech coach. Analyse spoken transcripts and provide structured, constructive feedback in JSON format.',
          },
          {'role': 'user', 'content': userMessage},
        ],
        'options': {'temperature': 0.3},
      }),
    );

    if (response.statusCode != 200) {
      log('Ollama API error ${response.statusCode}: ${response.body}');
      throw Exception('Ollama API error (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final message = body['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String? ?? '';

    if (content.trim().isEmpty) {
      throw Exception('Ollama returned empty response');
    }

    final cleaned = content
        .trim()
        .replaceAll(RegExp(r'```json|```', multiLine: true), '')
        .trim();

    final parsedJson = jsonDecode(cleaned) as Map<String, dynamic>;
    return AnalysisResult.fromJson({
      ...parsedJson,
      if ((parsedJson['transcript'] as String?)?.trim().isEmpty ?? true)
        'transcript': transcript,
    });
  }
}
