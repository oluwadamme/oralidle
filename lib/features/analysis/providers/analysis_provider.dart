import 'dart:developer' show log;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/models/analysis_result.dart';
import '../data/models/session_record.dart';
import '../../recording/data/models/recording_session.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/analytics/analytics_service.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/ollama_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/storage_scope.dart';
import '../../../core/services/supabase/remote_store.dart';
import '../../../core/services/sync/sync_outbox.dart';
import '../../../core/utils/speech_analyser.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

export '../../../core/providers/core_providers.dart' show storageServiceProvider;

class AnalysisNotifier extends StateNotifier<AsyncValue<SessionRecord?>> {
  AnalysisNotifier(
    this._gemini,
    this._ollama,
    this._storage,
    this._outbox,
    this._analytics,
    this._remote,
    this._scope,
  ) : super(const AsyncValue.data(null));

  final GeminiService _gemini;
  final OllamaService _ollama;
  final StorageService _storage;
  final SyncOutbox _outbox;
  final AnalyticsService _analytics;
  final RemoteStore? _remote;
  final StorageScope _scope;

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
              audioBytes: session.analysisBytes!,
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
      await _publishAudio(sessionId, session);
      _trackCompletion(session);

      if (mounted) {
        state = AsyncValue.data(record);
      }
    } catch (e, st) {
      _analytics.track(AnalyticsService.analysisFailed, {
        'stage': 'analyse',
        'reason': e.runtimeType.toString(),
      });
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// Sends the compressed µ-law form the Gemini request already produced —
  /// roughly half the linear-PCM copy kept for local playback. Uploaded files
  /// have no µ-law form, so those go as-is under a size cap.
  ///
  /// A failure here is never fatal: the bytes are stashed and `SyncService`
  /// retries on the next drain.
  Future<void> _publishAudio(String sessionId, RecordingSession session) async {
    final bytes = session.uploadBytes ?? session.audioBytes;
    if (bytes == null || bytes.lengthInBytes > AppConstants.maxUploadBytes) {
      return;
    }
    final extension = session.audioFileName?.split('.').last ?? 'wav';
    final contentType = session.audioMimeType ?? 'audio/wav';

    final remote = _remote;
    final userId = remote?.currentUserId;
    if (remote != null && userId != null) {
      try {
        final objectPath = await remote.uploadAudio(
          userId: userId,
          sessionId: sessionId,
          bytes: bytes,
          extension: extension,
          contentType: contentType,
        );
        final stored = _storage.getSession(sessionId);
        if (stored != null) {
          await _storage.cacheFromRemote(
            stored.copyWith(audioObjectPath: objectPath),
          );
          // Re-queue so the row carries the object key even if the drain
          // already pushed it while the upload was in flight.
          await _outbox.enqueue(SyncEntity.session, sessionId, _scope.value);
        }
        return;
      } catch (e) {
        log('Audio upload failed, stashing for retry: $e');
      }
    }

    await _outbox.stashAudio(
      sessionId,
      bytes,
      extension: extension,
      contentType: contentType,
    );
  }

  void _trackCompletion(RecordingSession session) {
    _analytics.track(AnalyticsService.recordingCompleted, {
      'topic_id': session.topicId,
      'category': session.topicCategory,
      'duration_seconds': session.durationSeconds,
      'uploaded': session.audioFileName != null,
    });
    if (session.audioFileName != null) {
      _analytics.track(AnalyticsService.fileUploaded, {
        'ext': session.audioFileName!.split('.').last.toLowerCase(),
        'size_bytes': session.audioBytes?.lengthInBytes ?? 0,
        'duration_seconds': session.durationSeconds,
      });
    }
  }

  void reset() => state = const AsyncValue.data(null);
}

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
        ref.watch(syncOutboxProvider),
        ref.watch(analyticsProvider),
        ref.watch(remoteStoreProvider),
        ref.watch(storageScopeProvider),
      );
    });
