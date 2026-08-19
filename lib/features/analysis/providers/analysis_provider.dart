import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/models/analysis_result.dart';
import '../data/models/session_record.dart';
import '../../recording/data/models/recording_session.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/speech_analyser.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AnalysisNotifier extends StateNotifier<AsyncValue<SessionRecord?>> {
  AnalysisNotifier(this._gemini, this._storage)
    : super(const AsyncValue.data(null));

  final GeminiService _gemini;
  final StorageService _storage;

  Future<void> analyse(RecordingSession session) async {
    state = const AsyncValue.loading();
    try {
      // Audio is always the better input — it carries pace, hesitation and
      // delivery that a transcript throws away — so it wins whenever it
      // exists, whether it was recorded live or uploaded. The transcript path
      // remains for sessions that somehow produced text but no audio.
      final AnalysisResult result;
      if (session.hasAudio) {
        result = await _gemini.analyseAudioFile(
          topic: session.topicTitle,
          audioBytes: session.audioBytes!,
          mimeType: session.audioMimeType ?? 'audio/wav',
          // Known for live takes (measured from the captured PCM), unknown
          // for uploads — which is what decides whether pace is measured or
          // estimated.
          durationSeconds: session.durationSeconds > 0
              ? session.durationSeconds
              : null,
        );
      } else {
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

final analysisProvider =
    StateNotifierProvider<AnalysisNotifier, AsyncValue<SessionRecord?>>((ref) {
      return AnalysisNotifier(
        ref.watch(geminiServiceProvider),
        ref.watch(storageServiceProvider),
      );
    });
