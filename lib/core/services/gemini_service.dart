import 'dart:convert';
import 'dart:developer' show log;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../features/analysis/data/models/analysis_result.dart';
import '../config/ai_endpoint.dart';
import '../utils/speech_analyser.dart';

class GeminiService {
  static const _timeout = Duration(seconds: 75);
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

Analyse this speech as an English speech coach. Score every dimension from 0 to
100, give each improvement an actionable tip, and keep the summary to two or
three sentences.
''';

    final json = await _generate(
      [
        {'text': userMessage},
      ],
      schema: _responseSchema(includeTranscript: false),
    );

    return AnalysisResult.fromJson({
      ..._normalised(json),
      'wpm': metrics.wpm,
      'filler_words': metrics.fillerWords,
      'transcript': transcript,
    });
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

The transcript must be strictly verbatim: keep every filler and hesitation
actually spoken (um, uh, er, like, you know), keep repeated and restarted
words, and do not tidy up the grammar.

Score every dimension from 0 to 100, count each filler word you hear, estimate
words per minute, give each improvement an actionable tip, and keep the summary
to two or three sentences.
''';

    final json = await _generate(
      [
        {
          'inline_data': {
            'mime_type': mimeType,
            'data': base64Encode(audioBytes),
          },
        },
        {'text': prompt},
      ],
      schema: _responseSchema(includeTranscript: true),
    );

    return AnalysisResult.fromJson(
      _withMeasuredMetrics(
        _normalised(json),
        durationSeconds: durationSeconds,
      ),
    );
  }

  /// A response schema cannot describe an object with arbitrary keys, so
  /// `filler_words` crosses the wire as a list of pairs and becomes a map here.
  static Map<String, dynamic> _responseSchema({
    required bool includeTranscript,
  }) {
    const integer = {'type': 'INTEGER'};
    return {
      'type': 'OBJECT',
      'properties': {
        if (includeTranscript) 'transcript': {'type': 'STRING'},
        'scores': {
          'type': 'OBJECT',
          'properties': {
            'fluency': integer,
            'vocabulary': integer,
            'grammar': integer,
            'coherence': integer,
            'topic_relevance': integer,
            'confidence': integer,
          },
          'required': [
            'fluency',
            'vocabulary',
            'grammar',
            'coherence',
            'topic_relevance',
            'confidence',
          ],
        },
        'overall_score': integer,
        'filler_words': {
          'type': 'ARRAY',
          'items': {
            'type': 'OBJECT',
            'properties': {
              'word': {'type': 'STRING'},
              'count': integer,
            },
            'required': ['word', 'count'],
          },
        },
        'wpm': integer,
        'strengths': {
          'type': 'ARRAY',
          'items': {'type': 'STRING'},
        },
        'improvements': {
          'type': 'ARRAY',
          'items': {
            'type': 'OBJECT',
            'properties': {
              'area': {'type': 'STRING'},
              'tip': {'type': 'STRING'},
            },
            'required': ['area', 'tip'],
          },
        },
        'summary': {'type': 'STRING'},
      },
      'required': [
        if (includeTranscript) 'transcript',
        'scores',
        'overall_score',
        'filler_words',
        'wpm',
        'strengths',
        'improvements',
        'summary',
      ],
    };
  }

  /// Rebuilds `filler_words` into the `{word: count}` map [AnalysisResult]
  /// requires, which casts it without a null check.
  static Map<String, dynamic> _normalised(Map<String, dynamic> json) {
    final raw = json['filler_words'];
    final counts = <String, int>{};

    if (raw is List) {
      for (final entry in raw) {
        if (entry is! Map) continue;
        final word = (entry['word'] as String?)?.trim().toLowerCase();
        final count = (entry['count'] as num?)?.toInt();
        if (word == null || word.isEmpty || count == null || count <= 0) {
          continue;
        }
        counts[word] = (counts[word] ?? 0) + count;
      }
    } else if (raw is Map) {
      raw.forEach((key, value) {
        final count = (value as num?)?.toInt();
        if (count != null && count > 0) counts[key.toString()] = count;
      });
    }

    return {...json, 'filler_words': counts};
  }

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
    List<Map<String, dynamic>> parts, {
    required Map<String, dynamic> schema,
  }) async {
    try {
      final response = await http
          .post(
            // Google directly on native, our own proxy on web — see AiEndpoint.
            AiEndpoint.generateContent,
            headers: AiEndpoint.headers(_apiKey),
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
                // A ceiling rather than a target, so it costs nothing to leave
                // room for a long uploaded answer's verbatim transcript.
                'maxOutputTokens': 4096,
                'temperature': 0.4,
                // Constrained decoding: the model emits the schema's shape
                // directly, with no fences, preamble or missing fields.
                'responseMimeType': 'application/json',
                'responseSchema': schema,
              },
            }),
          )
          .timeout(
            _timeout,
            onTimeout: () => throw Exception(
              'Analysis timed out. Please check your connection and try again.',
            ),
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
        throw Exception(
          'The AI response was cut off before it finished. Please try again '
          'with a shorter recording.',
        );
      }

      final text =
          (candidate['content']['parts'] as List).first['text'] as String;
      return _decodeJsonObject(text);
    } catch (e, st) {
      log('GeminiService error: $e\n$st');
      rethrow;
    }
  }

  /// Decodes a JSON object from model output.
  ///
  /// `responseMimeType: application/json` should make this a plain decode, but
  /// a model that ignores it wraps the object in ``` fences or opens with a
  /// sentence of prose. Falling back to the outermost braces recovers both.
  static Map<String, dynamic> _decodeJsonObject(String text) {
    final trimmed = text
        .trim()
        .replaceAll(RegExp(r'```json|```', multiLine: true), '')
        .trim();
    try {
      return jsonDecode(trimmed) as Map<String, dynamic>;
    } on FormatException {
      final start = trimmed.indexOf('{');
      final end = trimmed.lastIndexOf('}');
      if (start == -1 || end <= start) rethrow;
      return jsonDecode(trimmed.substring(start, end + 1))
          as Map<String, dynamic>;
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
