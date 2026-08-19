import 'dart:convert';
import 'dart:developer' show log;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;
import '../data/models/interview_models.dart';
import '../../../core/config/ai_endpoint.dart';

class InterviewService {
  // Longer than the proxy's own 60s ceiling. At exactly 60 the two race, and
  // the client can give up a moment before the server's real error arrives.
  static const _timeout = Duration(seconds: 75);

  // Max history entries (user + model pairs). Keeps payload manageable for long
  // sessions while retaining enough context for coherent question generation.
  // 20 entries = 10 exchanges max; bounded further by questionCount ≤ 10.
  static const _maxHistoryEntries = 20;

  // Retry up to 2 additional times (3 total) on network failures and 5xx errors.
  static const _maxRetries = 2;

  // Shared generation config — single source of truth to prevent drift between
  // the text-only and audio request paths.
  static const _generationConfig = {
    'maxOutputTokens': 4096,
    'temperature': 0.7,
  };

  final String _apiKey;
  final http.Client _client;
  late final String _systemPrompt;
  final List<Map<String, dynamic>> _history = [];

  InterviewService({
    required this._apiKey,
    required String cvContent,
    required String skillsContent,
    required InterviewMode mode,
    required int questionCount,
    http.Client? client,
  }) : _client = client ?? http.Client() {
    _systemPrompt = _buildPrompt(
      cvContent: cvContent,
      skillsContent: skillsContent,
      mode: mode,
      questionCount: questionCount,
    );
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  Future<InterviewQuestion> startSession() async {
    final text = await _call('Start the interview. Ask me the first question.');
    final json = _parseJson(text);
    return InterviewQuestion.fromJson(
      json['first_question'] as Map<String, dynamic>,
    );
  }

  /// Submits an answer and returns the evaluation.
  ///
  /// When [audioBytes] is provided the clip is base64-encoded off the UI
  /// thread and sent to Gemini inline.  Gemini evaluates the audio directly
  /// (more accurate than any on-device transcript) and returns a
  /// [transcript] in its response.  That transcript — not the audio bytes —
  /// is stored in conversation history, so subsequent turns stay compact.
  ///
  /// Falls back to the text-only [sttFallback] path when no audio was
  /// captured or encoding fails.  On web, where there is no on-device
  /// recogniser, the audio path is the only one that produces a transcript.
  Future<
    ({
      String transcript,
      TurnEvaluation eval,
      InterviewQuestion? nextQuestion,
      InterviewEvaluation? finalEval,
    })
  >
  submitAnswer({
    required bool isLastQuestion,
    Uint8List? audioBytes,
    String audioMimeType = 'audio/wav',
    String sttFallback = '',
  }) async {
    // ── Encode audio off the UI thread ────────────────────────────────────────
    // base64 of a two-minute 16 kHz clip is a few MB of string building —
    // enough to drop frames if done inline.  `compute` runs it in an isolate
    // on native and inline on web, where isolates are unavailable.
    List<Map<String, dynamic>>? audioParts;
    if (audioBytes != null && audioBytes.isNotEmpty) {
      try {
        final encoded = await compute(base64Encode, audioBytes);
        final String textInstruction = sttFallback.trim().isNotEmpty
            ? 'Candidate spoken answer (verbatim transcript): "$sttFallback"\n\n${isLastQuestion ? 'That was my final answer. Please evaluate it and provide the comprehensive final evaluation.' : 'That is my answer. Please evaluate it and provide feedback and the next question.'}'
            : (isLastQuestion
                  ? 'That was my final answer. Please evaluate it and provide the comprehensive final evaluation.'
                  : 'That is my answer.');

        audioParts = [
          {
            'inline_data': {'mime_type': audioMimeType, 'data': encoded},
          },
          {'text': textInstruction},
        ];
      } catch (e) {
        log(
          'InterviewService: audio encoding failed — falling back to STT: $e',
        );
      }
    }

    // ── Text-only fallback path ───────────────────────────────────────────────
    if (audioParts == null) {
      final userMessage = isLastQuestion
          ? 'My answer: "$sttFallback"\n\nThat was my final answer. Please evaluate it and provide the comprehensive final evaluation.'
          : 'My answer: "$sttFallback"';
      final text = await _call(userMessage);
      return _parseSubmitResponse(text, sttFallback);
    }

    // ── Audio path ────────────────────────────────────────────────────────────
    // Add a text placeholder to history first so rollback on failure works the
    // same way as the text path.  On success this is replaced by the real
    // transcript returned by Gemini.
    _history.add({
      'role': 'user',
      'parts': [
        {'text': '[audio answer]'},
      ],
    });

    final requestBody = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': _systemPrompt},
        ],
      },
      // Send all prior history as text, then the current turn with audio inline.
      'contents': [
        ..._history.sublist(0, _history.length - 1),
        {'role': 'user', 'parts': audioParts},
      ],
      'generationConfig': _generationConfig,
    });

    final http.Response response;
    try {
      response = await _executePost(requestBody);
    } catch (e) {
      _history.removeLast(); // rollback placeholder
      rethrow;
    }

    if (response.statusCode != 200) {
      _history.removeLast();
      log(
        'InterviewService HTTP error ${response.statusCode}: ${response.body}',
      );
      throw Exception(_extractApiError(response.body, response.statusCode));
    }

    log('InterviewService audio response: ${response.body}');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final candidate =
        (body['candidates'] as List).first as Map<String, dynamic>;

    // Any finish reason other than STOP means content is missing or truncated.
    // SAFETY / RECITATION / OTHER all leave candidate['content'] absent or
    // incomplete — accessing it would crash.
    final finishReason = candidate['finishReason'] as String? ?? 'STOP';
    if (finishReason != 'STOP') {
      _history.removeLast();
      throw Exception(
        finishReason == 'MAX_TOKENS'
            ? 'AI response was cut off. Try reducing the number of questions, or try again.'
            : 'Response was blocked ($finishReason). Please try again.',
      );
    }

    // Safety-filter responses omit the 'content' key entirely.
    final content = candidate['content'] as Map<String, dynamic>?;
    if (content == null) {
      _history.removeLast();
      throw Exception('Received an empty response. Please try again.');
    }

    final text = (content['parts'] as List).first['text'] as String;
    final json = _parseJson(text);

    // Replace the placeholder with the real transcript so future turns have
    // meaningful context without re-sending the audio bytes.
    final geminiTranscript = (json['transcript'] as String?)?.trim();
    final transcript = (sttFallback.trim().isNotEmpty)
        ? sttFallback.trim()
        : (geminiTranscript ?? '');
    _history.last = {
      'role': 'user',
      'parts': [
        {'text': 'My answer: "$transcript"'},
      ],
    };
    _history.add({
      'role': 'model',
      'parts': [
        {'text': text},
      ],
    });
    _trimHistoryIfNeeded();

    return _parseSubmitResponse(text, transcript, precomputedJson: json);
  }

  /// Shared parsing logic for both the audio and text-only answer paths.
  static ({
    String transcript,
    TurnEvaluation eval,
    InterviewQuestion? nextQuestion,
    InterviewEvaluation? finalEval,
  })
  _parseSubmitResponse(
    String rawText,
    String fallbackTranscript, {
    Map<String, dynamic>? precomputedJson,
  }) {
    final json = precomputedJson ?? _parseJson(rawText);
    final transcript =
        (json['transcript'] as String?)?.trim() ?? fallbackTranscript;
    final eval = TurnEvaluation.fromJson(
      json['evaluation'] as Map<String, dynamic>,
    );
    final nextQuestion = json.containsKey('next_question')
        ? InterviewQuestion.fromJson(
            json['next_question'] as Map<String, dynamic>,
          )
        : null;
    final finalEval = json.containsKey('final_evaluation')
        ? InterviewEvaluation.fromJson(
            json['final_evaluation'] as Map<String, dynamic>,
          )
        : null;
    return (
      transcript: transcript,
      eval: eval,
      nextQuestion: nextQuestion,
      finalEval: finalEval,
    );
  }

  /// Release the underlying HTTP connection pool.
  /// Must be called from [InterviewNotifier.dispose].
  void close() => _client.close();

  // ── Private helpers ─────────────────────────────────────────────────────────

  Future<String> _call(String userText) async {
    _history.add({
      'role': 'user',
      'parts': [
        {'text': userText},
      ],
    });

    final requestBody = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': _systemPrompt},
        ],
      },
      'contents': _history,
      'generationConfig': _generationConfig,
    });

    final http.Response response;
    try {
      response = await _executePost(requestBody);
    } catch (e) {
      // Roll back the user message so history stays consistent after failure
      _history.removeLast();
      rethrow;
    }

    if (response.statusCode != 200) {
      _history.removeLast();
      log(
        'InterviewService HTTP error ${response.statusCode}: ${response.body}',
      );
      throw Exception(_extractApiError(response.body, response.statusCode));
    }

    log('InterviewService response: ${response.body}');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final candidate =
        (body['candidates'] as List).first as Map<String, dynamic>;

    final finishReason = candidate['finishReason'] as String? ?? 'STOP';
    if (finishReason != 'STOP') {
      _history.removeLast();
      throw Exception(
        finishReason == 'MAX_TOKENS'
            ? 'AI response was cut off. Try reducing the number of questions, or try again.'
            : 'Response was blocked ($finishReason). Please try again.',
      );
    }

    final content = candidate['content'] as Map<String, dynamic>?;
    if (content == null) {
      _history.removeLast();
      throw Exception('Received an empty response. Please try again.');
    }

    final text = (content['parts'] as List).first['text'] as String;

    _history.add({
      'role': 'model',
      'parts': [
        {'text': text},
      ],
    });

    _trimHistoryIfNeeded();

    return text;
  }

  /// Executes an HTTP POST with exponential-backoff retry.
  ///
  /// Retries on:
  ///   - Network-level failures ([http.ClientException])
  ///   - Server errors (5xx)
  ///
  /// Does NOT retry on client errors (4xx) — those indicate a bad request.
  Future<http.Response> _executePost(String requestBody) async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(seconds: attempt * 2));
      }

      try {
        final response = await _client
            .post(
              // Google directly on native, our own proxy on web — see
              // AiEndpoint.
              AiEndpoint.generateContent,
              headers: AiEndpoint.headers(_apiKey),
              body: requestBody,
            )
            .timeout(
              _timeout,
              onTimeout: () => throw Exception(
                'Request timed out. Please check your connection and try again.',
              ),
            );

        // 4xx = bad request / auth error — don't retry, surface immediately
        if (response.statusCode < 500) return response;

        // 5xx = server error — retry if attempts remain
        if (attempt == _maxRetries) return response;
        log(
          'InterviewService: server error ${response.statusCode}, '
          'retrying (attempt ${attempt + 1}/$_maxRetries)…',
        );
      } catch (e) {
        if (attempt == _maxRetries) rethrow;
        log(
          'InterviewService: request failed ($e), '
          'retrying (attempt ${attempt + 1}/$_maxRetries)…',
        );
      }
    }

    // Unreachable — every path above either returns or rethrows — but Dart
    // requires a return statement beyond the loop.
    throw Exception('Request failed after $_maxRetries retries.');
  }

  /// Removes the oldest non-initial exchange when history exceeds the cap.
  ///
  /// History always contains paired entries (user + model). The first pair
  /// (indices 0–1) is preserved as the session anchor so the AI remembers the
  /// opening question; older middle pairs are evicted first.
  void _trimHistoryIfNeeded() {
    while (_history.length > _maxHistoryEntries) {
      if (_history.length > 4) {
        _history.removeRange(2, 4); // remove oldest non-initial pair
      } else {
        break;
      }
    }
  }

  static Map<String, dynamic> _parseJson(String text) {
    final cleaned = text
        .trim()
        .replaceAll(RegExp(r'```json|```', multiLine: true), '')
        .trim();
    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      log('InterviewService: failed to parse response: $text');
      throw Exception(
        'Could not read the interview response. Please try again.',
      );
    }
  }

  static String _extractApiError(String body, int statusCode) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      if (error != null) return error['message'] as String? ?? 'Unknown error';
    } catch (_) {}
    return 'Interview request failed (HTTP $statusCode). Please try again.';
  }

  // ── Prompt builder — static, called once at construction ────────────────────

  static String _buildPrompt({
    required String cvContent,
    required String skillsContent,
    required InterviewMode mode,
    required int questionCount,
  }) =>
      '''
You are "Alex", a senior technical interviewer at a top tech company conducting a realistic mock interview to help the candidate sharpen their interview skills.

CANDIDATE CV:
$cvContent

INTERVIEW METHODOLOGY (use this to evaluate and generate questions):
$skillsContent

INTERVIEW CONFIGURATION:
- Mode: ${_modeDescription(mode)}
- Total questions: $questionCount

RULES:
1. Stay in character as a professional interviewer throughout — no small talk, stay focused
2. CV-based questions: reference specific projects, roles, or technologies from the CV above
3. Technical questions: probe for depth — expect trade-off explanations and design decisions
4. Behavioral questions: apply the STAR evaluation framework from the methodology above; note explicitly in feedback if Situation, Task, Action, or Result components are missing or weak
5. DSA/LeetCode questions: describe the problem clearly, ask about approach and time/space complexity
6. Feedback must be honest but constructive — 2–3 sentences only: what was strong, what was missing
7. Do NOT reveal you are an AI or break character under any circumstance

RESPONSE FORMAT — return ONLY valid JSON, no markdown fences, no extra text:

First message (starting the interview):
{"first_question": {"question": "<question text>", "question_type": "cvBased|technical|behavioral|leetcode"}}

Each answer followed by a next question:
{"transcript": "<verbatim transcription of exactly what the candidate said>", "evaluation": {"content_score": <0-100>, "feedback": "<2-3 sentences>", "model_answer": "<a strong 3-5 sentence ideal sample answer showing what an excellent response looks like for this question>"}, "next_question": {"question": "<question text>", "question_type": "cvBased|technical|behavioral|leetcode"}}

Final answer (no next question — give comprehensive evaluation):
{"transcript": "<verbatim transcription of exactly what the candidate said>", "evaluation": {"content_score": <0-100>, "feedback": "<2-3 sentences>", "model_answer": "<a strong 3-5 sentence ideal sample answer showing what an excellent response looks like for this question>"}, "final_evaluation": {"overall_score": <0-100>, "summary": "<3-4 sentence holistic assessment>", "strengths": ["<strength>", "<strength>", "<strength>"], "improvements": ["<specific improvement area>", "<specific improvement area>", "<specific improvement area>"]}}
''';

  static String _modeDescription(InterviewMode mode) {
    switch (mode) {
      case InterviewMode.technical:
        return 'technical (coding, system design, and CV-based questions)';
      case InterviewMode.behavioral:
        return 'behavioral (STAR-method, leadership, and situational questions)';
      case InterviewMode.mixed:
        return 'mixed (blend of technical, CV-based, behavioral, and DSA questions)';
    }
  }
}
