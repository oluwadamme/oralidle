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
        : metrics.fillerWords.entries
              .map((e) => '${e.key} (${e.value}x)')
              .join(', ');

    final userMessage =
        '''
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

    return AnalysisResult.fromJson(
      await _generate([
        {'text': userMessage},
      ]),
    );
  }

  /// Analyses a recording by sending Gemini the audio itself.
  ///
  /// Preferred over [analyseTranscript] whenever audio exists: Gemini hears
  /// pace, hesitation and delivery, none of which survive a transcript.
  ///
  /// Words-per-minute and filler counts are *measured* from the verbatim
  /// transcript Gemini returns, against [durationSeconds], rather than taken
  /// from the model's own estimate. That keeps the numbers meaning the same
  /// thing on every platform and comparable with historical sessions.
  /// Uploaded files, whose duration we do not know, keep the estimate.
  Future<AnalysisResult> analyseAudioFile({
    required String topic,
    required Uint8List audioBytes,
    required String mimeType,
    int? durationSeconds,
  }) async {
    final duration = durationSeconds == null
        ? ''
        : '\nDuration: ${durationSeconds}s';

    final prompt =
        '''
Topic the speaker was addressing: "$topic"$duration

Listen to this audio recording. Transcribe the speech, then analyse its quality as an English speech coach.

Return ONLY a JSON object — no markdown, no explanation. Use this exact schema:
{
  "transcript": "<strictly verbatim transcription: keep every filler and hesitation actually spoken (um, uh, er, like, you know), keep repeated and restarted words, and do not tidy up the grammar>",
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

    final json = await _generate([
      {
        'inline_data': {
          'mime_type': mimeType,
          'data': base64Encode(audioBytes),
        },
      },
      {'text': prompt},
    ]);

    return AnalysisResult.fromJson(
      _withMeasuredMetrics(json, durationSeconds: durationSeconds),
    );
  }

  /// Replaces the model's estimated pace and filler counts with values
  /// computed from the transcript it returned.
  ///
  /// An LLM eyeballing "words per minute" from audio is guesswork; dividing a
  /// word count by a duration measured from the PCM is not. Falls back to the
  /// model's own numbers when there is nothing better — no transcript came
  /// back, or the duration is unknown, as with uploaded files.
  static Map<String, dynamic> _withMeasuredMetrics(
    Map<String, dynamic> json, {
    required int? durationSeconds,
  }) {
    final transcript = (json['transcript'] as String?)?.trim() ?? '';
    if (transcript.isEmpty || durationSeconds == null || durationSeconds <= 0) {
      return json;
    }

    final measured = SpeechAnalyser.analyse(transcript, durationSeconds);
    return {...json, 'wpm': measured.wpm, 'filler_words': measured.fillerWords};
  }

  /// Sends [parts] and returns the parsed JSON object.
  ///
  /// Returns the raw map rather than an [AnalysisResult] so callers can
  /// replace fields the model only estimates with values we can measure.
  Future<Map<String, dynamic>> _generate(
    List<Map<String, dynamic>> parts,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          // Key goes in a header, never in the URL, to keep it out of proxy
          // logs, crash reporters and browser network panels.
          'x-goog-api-key': _apiKey,
        },
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
          'generationConfig': {'maxOutputTokens': 8192, 'temperature': 0.4},
        }),
      );

      if (response.statusCode != 200) {
        log(response.body);
        throw Exception(
          _extractErrorMessage(response.body, response.statusCode),
        );
      }
      log(response.body.toString());
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final candidate =
          (body['candidates'] as List).first as Map<String, dynamic>;

      final finishReason = candidate['finishReason'] as String? ?? 'STOP';
      if (finishReason == 'MAX_TOKENS') {
        throw Exception('The AI response was cut off. Please try again.');
      }

      final text =
          (candidate['content']['parts'] as List).first['text'] as String;
      final cleaned = text
          .trim()
          .replaceAll(RegExp(r'```json|```', multiLine: true), '')
          .trim();
      return jsonDecode(cleaned) as Map<String, dynamic>;
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
