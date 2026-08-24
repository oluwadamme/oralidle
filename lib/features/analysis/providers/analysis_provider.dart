import 'dart:developer' show log;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/models/analysis_result.dart';
import '../data/models/session_record.dart';
import '../../recording/data/models/recording_session.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/ollama_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/speech_analyser.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AnalysisNotifier extends StateNotifier<AsyncValue<SessionRecord?>> {
  AnalysisNotifier(this._gemini, this._ollama, this._storage)
    : super(const AsyncValue.data(null));

  final GeminiService _gemini;
  final OllamaService _ollama;
  final StorageService _storage;

  Future<void> analyse(RecordingSession session) async {
    state = const AsyncValue.loading();
    try {
      AnalysisResult? result;
      Object? primaryError;

      // Pre-compute metrics once for transcript-based analysis
      final metrics = session.hasTranscript
          ? SpeechAnalyser.analyse(session.transcript, session.durationSeconds)
          : null;

      final useOllama = kDebugMode && dotenv.env['USE_OLLAMA'] == 'true';

      if (useOllama && session.hasTranscript && metrics != null) {
        log('USE_OLLAMA=true: analysing transcript with local Ollama...');
        try {
          result = await _ollama.analyseTranscript(
            topic: session.topicTitle,
            transcript: session.transcript,
            durationSeconds: session.durationSeconds,
            metrics: metrics,
          );
        } catch (e) {
          primaryError = e;
          log('Primary Ollama analysis failed: $e');
        }
      }

      // 2. If no result yet, try Gemini (audio or transcript)
      if (result == null) {
        try {
          if (session.hasAudio) {
            result = await _gemini.analyseAudioFile(
              topic: session.topicTitle,
              audioBytes: session.audioBytes!,
              mimeType: session.audioMimeType ?? 'audio/wav',
              durationSeconds: session.durationSeconds > 0
                  ? session.durationSeconds
                  : null,
            );
          } else if (session.hasTranscript && metrics != null) {
            result = await _gemini.analyseTranscript(
              topic: session.topicTitle,
              transcript: session.transcript,
              durationSeconds: session.durationSeconds,
              metrics: metrics,
            );
          }
        } catch (error) {
          primaryError ??= error;
          log('GeminiService analysis failed: $error');
        }
      }

      // 3. Fallback to Ollama if Gemini failed or wasn't used
      if (result == null && session.hasTranscript && metrics != null) {
        final isOllamaUp = await _ollama.isAvailable();
        if (isOllamaUp) {
          log('Falling back to local Ollama LLM for transcript analysis...');
          try {
            result = await _ollama.analyseTranscript(
              topic: session.topicTitle,
              transcript: session.transcript,
              durationSeconds: session.durationSeconds,
              metrics: metrics,
            );
          } catch (e) {
            log('Fallback Ollama analysis failed: $e');
          }
        }
      }

      if (result == null) {
        throw Exception(
          primaryError != null
              ? 'Analysis failed: $primaryError'
              : 'Analysis failed: session has neither audio nor transcript to analyse.',
        );
      }

      final sessionId = const Uuid().v4();
      String? savedAudioPath;
      if (session.hasAudio) {
        final ext = session.audioFileName?.split('.').last ?? 'wav';
        savedAudioPath = await _storage.saveAudioFile(
          sessionId,
          session.audioBytes!,
          extension: ext,
          mimeType: session.audioMimeType,
        );
      }

      final record = SessionRecord(
        id: sessionId,
        topicTitle: session.topicTitle,
        topicCategory: session.topicCategory,
        timestamp: DateTime.now(),
        durationSeconds: session.durationSeconds,
        result: result,
        audioPath: savedAudioPath,
      );
      await _storage.saveSession(record);

      if (mounted) {
        state = AsyncValue.data(record);
      }
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  void reset() => state = const AsyncValue.data(null);
}

final storageServiceProvider = Provider<StorageService>(
  (_) => StorageService(),
);

final geminiServiceProvider = Provider<GeminiService>((ref) {
  final key = dotenv.env['GEMINI_API_KEY'] ?? '';
  return GeminiService(key);
});

final ollamaServiceProvider = Provider<OllamaService>((ref) {
  final url = dotenv.env['OLLAMA_BASE_URL'];
  final model = dotenv.env['OLLAMA_MODEL'];
  return OllamaService(baseUrl: url, model: model);
});

final analysisProvider =
    StateNotifierProvider<AnalysisNotifier, AsyncValue<SessionRecord?>>((ref) {
      return AnalysisNotifier(
        ref.watch(geminiServiceProvider),
        ref.watch(ollamaServiceProvider),
        ref.watch(storageServiceProvider),
      );
    });
