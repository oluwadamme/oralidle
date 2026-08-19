import 'dart:developer' show log;
import 'package:flutter/foundation.dart' show kIsWeb;
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

      // On Web, use Ollama directly to prevent exposing Gemini API key in browser network traffic.
      // if (kIsWeb) {
      //   log('Web platform detected: using local Ollama service to protect API keys');
      //   if (session.hasTranscript) {
      //     result = await _ollama.analyseTranscript(
      //       topic: session.topicTitle,
      //       transcript: session.transcript,
      //       durationSeconds: session.durationSeconds,
      //       metrics: SpeechAnalyser.analyse(
      //         session.transcript,
      //         session.durationSeconds,
      //       ),
      //     );
      //   } else {
      //     throw Exception(
      //       'Speech analysis on web requires a transcript. Make sure audio input was captured.',
      //     );
      //   }
      // } else {
      //   // On native platforms (iOS, Android, macOS), attempt Gemini first, then fallback to Ollama

      // }
      Object? geminiError;
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
        } else if (session.hasTranscript) {
          result = await _gemini.analyseTranscript(
            topic: session.topicTitle,
            transcript: session.transcript,
            durationSeconds: session.durationSeconds,
            metrics: SpeechAnalyser.analyse(
              session.transcript,
              session.durationSeconds,
            ),
          );
        }
      } catch (error) {
        geminiError = error;
        log('GeminiService analysis failed: $error');
      }

      // Ollama runs on a local address, so it is only reachable from a device
      // on the same machine or network — never from a deployed web build.
      // Attempting it there would just stall and then report the wrong cause.
      if (result == null && !kIsWeb && session.hasTranscript) {
        log('Falling back to Ollama local LLM for transcript analysis...');
        result = await _ollama.analyseTranscript(
          topic: session.topicTitle,
          transcript: session.transcript,
          durationSeconds: session.durationSeconds,
          metrics: SpeechAnalyser.analyse(
            session.transcript,
            session.durationSeconds,
          ),
        );
      }

      if (result == null) {
        // Report what actually went wrong rather than pointing at Ollama on a
        // platform that never tried it.
        throw Exception(
          geminiError != null
              ? 'Analysis failed: $geminiError'
              : 'Analysis failed: this session had neither audio nor a '
                    'transcript to analyse.',
        );
      }

      final record = SessionRecord(
        id: const Uuid().v4(),
        topicTitle: session.topicTitle,
        topicCategory: session.topicCategory,
        timestamp: DateTime.now(),
        durationSeconds: session.durationSeconds,
        result: result,
      );
      await _storage.saveSession(record);
      state = AsyncValue.data(record);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
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
