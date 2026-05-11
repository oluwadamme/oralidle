import 'dart:convert';
import 'dart:developer' show log;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../features/analysis/data/models/analysis_result.dart';
import '../utils/speech_analyser.dart';

class GeminiService {
  static const _model = 'gemini-2.5-flash';
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  final String _apiKey;
  GeminiService(this._apiKey);

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

    return _generate([
      {'text': userMessage},
    ]);
  }

  Future<AnalysisResult> analyseAudioFile({
    required String topic,
    required Uint8List audioBytes,
    required String mimeType,
  }) async {
    final prompt = '''
Topic the speaker was addressing: "$topic"

Listen to this audio recording. Transcribe the speech, then analyse its quality as an English speech coach.

Return ONLY a JSON object — no markdown, no explanation. Use this exact schema:
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
  "wpm": <estimated words per minute>,
  "strengths": ["<string>", ...],
  "improvements": [{"area": "<string>", "tip": "<actionable advice>"}],
  "summary": "<2-3 sentence coaching summary>"
}
''';

    return _generate([
      {
        'inline_data': {
          'mime_type': mimeType,
          'data': base64Encode(audioBytes),
        },
      },
      {'text': prompt},
    ]);
  }

  Future<AnalysisResult> _generate(List<Map<String, dynamic>> parts) async {
    try {
      
    
    final response = await http.post(
      Uri.parse('$_baseUrl?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'system_instruction': {
          'parts': [
            {
              'text':
                  'You are a professional English speech coach. Analyse spoken transcripts and audio recordings, providing structured, constructive feedback. Be encouraging but honest. Focus on fluency, vocabulary, grammar, coherence, topic relevance, and confidence.',
            },
          ],
        },
        'contents': [
          {'parts': parts},
        ],
        'generationConfig': {
          'maxOutputTokens': 8192,
          'temperature': 0.4,
        },
      }),
    );

    if (response.statusCode != 200) {
      log(response.body);
      throw Exception(_extractErrorMessage(response.body, response.statusCode));
    }
    log(response.body.toString());
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final candidate = (body['candidates'] as List).first as Map<String, dynamic>;

    final finishReason = candidate['finishReason'] as String? ?? 'STOP';
    if (finishReason == 'MAX_TOKENS') {
      throw Exception('The AI response was cut off. Please try again.');
    }

    final text =
        (candidate['content']['parts'] as List).first['text'] as String;
    final cleaned = text.trim().replaceAll(RegExp(r'```json|```', multiLine: true), '').trim();
    return AnalysisResult.fromJson(jsonDecode(cleaned) as Map<String, dynamic>);
    } catch (e, st) {
      log('GeminiService error: $e\n$st');
      rethrow;
    }
  }

  String _extractErrorMessage(String responseBody, int statusCode) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      if (error != null) {
        return error['message'] as String? ?? 'Unknown error';
      }
    } catch (_) {}
    return 'Analysis failed (HTTP $statusCode). Please try again.';
  }
}
