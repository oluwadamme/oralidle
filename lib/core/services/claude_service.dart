import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/analysis/data/models/analysis_result.dart';
import '../utils/speech_analyser.dart';

class ClaudeService {
  static const _url = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-4-6';

  final String _apiKey;
  ClaudeService(this._apiKey);

  Future<AnalysisResult> analyseTranscript({
    required String topic,
    required String transcript,
    required int durationSeconds,
    required PreComputedMetrics metrics,
  }) async {
    final fillerSummary = metrics.fillerWords.isEmpty
        ? 'none detected'
        : metrics.fillerWords.entries.map((e) => '${e.key} (${e.value}x)').join(', ');

    final userMessage = '''
Topic: "$topic"
Duration: ${durationSeconds}s
Words per minute: ${metrics.wpm}
Lexical diversity (unique/total words): ${(metrics.uniqueWordRatio * 100).round()}%
Filler words detected: $fillerSummary

Transcript:
"$transcript"

Analyse this speech and return ONLY a JSON object — no markdown, no explanation. Use this exact schema:
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

    final response = await http.post(
      Uri.parse(_url),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 1024,
        'system':
            'You are a professional English speech coach. Analyse spoken transcripts and provide structured, constructive feedback. Be encouraging but honest. Focus on fluency, vocabulary, grammar, coherence, topic relevance, and confidence.',
        'messages': [
          {'role': 'user', 'content': userMessage},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Claude API error ${response.statusCode}: ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final content = (body['content'] as List).first['text'] as String;
    final cleaned = content.trim().replaceAll(RegExp(r'^```json|```$', multiLine: true), '');
    return AnalysisResult.fromJson(jsonDecode(cleaned) as Map<String, dynamic>);
  }
}
