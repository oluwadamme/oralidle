import 'dart:async';
import 'dart:developer' show log;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_speech/flutter_gemma_speech.dart';

import 'audio_capture_service.dart';
import 'pcm_segmenter.dart';
import 'speech_recognition_service.dart';

/// On-device transcription via `flutter_gemma_speech` (Moonshine-tiny).
///
/// Two things about this engine drive the whole design here:
///
/// 1. It never opens the microphone. It takes PCM we already captured, so it
///    coexists with recording instead of competing for the device.
/// 2. `SpeechRecognizer.transcribe` runs a **fixed 5-second window**. Audio
///    beyond 80 000 samples is silently discarded by the model — so passing a
///    whole 90-second answer would return only its first five seconds with no
///    error to tell you. [PcmSegmenter] exists to make that impossible.
///
/// Unlike the platform recognisers this model transcribes disfluencies rather
/// than tidying them away, which is what makes the filler-word metric mean
/// anything.
class GemmaSpeechService implements SpeechRecognitionService {
  /// Quantised build: 49 MB against 104 MB for f32, with no accuracy
  /// difference that matters for coaching feedback.
  static const _modelUrl =
      'https://huggingface.co/litert-community/moonshine-tiny/resolve/main/moonshine_tiny_5s_i8.tflite';
  static const _tokenizerUrl =
      'https://huggingface.co/UsefulSensors/moonshine/resolve/main/ctranslate2/tiny/tokenizer.json';

  static const _bytesPerSecond =
      AudioCaptureService.sampleRate * AudioCaptureService.numChannels * 2;

  /// The model's window is 5.0 s; we cut at 4.5 s so a slice can never reach
  /// the point where the model would truncate it.
  static const _maxChunkBytes = _bytesPerSecond * 9 ~/ 2;

  /// Below this there is not enough speech to be worth a decode pass.
  static const _minVoicedBytes = _bytesPerSecond * 2 ~/ 5; // 400 ms

  /// A pause this long is treated as a phrase boundary — the natural place to
  /// cut, and the reason most slices land well short of the hard limit.
  static const _silenceHoldBytes = _bytesPerSecond * 7 ~/ 20; // 350 ms

  static bool _runtimeInitialised = false;

  /// Registers the LiteRT STT backend exactly once per process.
  ///
  /// Call from `main()` before any recognizer is created. Cheap and offline —
  /// it wires up backends, it does not touch the model files.
  static Future<void> initializeRuntime() async {
    if (_runtimeInitialised || kIsWeb) return;
    try {
      await FlutterGemma.initialize(sttBackends: [const LiteRtSttBackend()]);
      _runtimeInitialised = true;
    } catch (e) {
      log('GemmaSpeechService: runtime initialize failed: $e');
    }
  }

  /// Test seam: supplies the recognizer directly, bypassing the model
  /// download and the LiteRT runtime so the streaming, fencing and
  /// accumulation logic can be exercised without a device.
  @visibleForTesting
  final Future<SpeechRecognizer> Function()? recognizerFactory;

  GemmaSpeechService({this.recognizerFactory});

  final _stateController = StreamController<SpeechEngineState>.broadcast();

  SpeechEngineState _state = const SpeechEngineState(
    status: kIsWeb
        ? SpeechEngineStatus.unsupported
        : SpeechEngineStatus.notInstalled,
  );

  SpeechRecognizer? _recognizer;
  Future<bool>? _preparation;

  StreamSubscription<Uint8List>? _pcmSub;
  void Function(String transcript)? _onTranscript;

  final _segmenter = PcmSegmenter(
    maxWindowBytes: _maxChunkBytes,
    minVoicedBytes: _minVoicedBytes,
    silenceHoldBytes: _silenceHoldBytes,
    cutSearchBytes: _bytesPerSecond, // search the last second
  );

  /// Serialises decode passes — the recognizer holds one interpreter and
  /// overlapping calls would interleave on it.
  Future<void> _decodeQueue = Future.value();
  final _settled = StringBuffer();

  /// Fences decodes to the recording that produced them.
  ///
  /// Decoding is asynchronous and queued, so a window enqueued during one
  /// recording can still be in flight when the user abandons it and starts
  /// another. Without this, that late result would be appended to the *next*
  /// recording's transcript. Every decode captures the value at enqueue time
  /// and discards itself if it no longer matches.
  int _session = 0;

  @override
  SpeechEngineState get state => _state;

  @override
  Stream<SpeechEngineState> get stateStream =>
      // Replays the current state to each new subscriber. A plain broadcast
      // stream only delivers *subsequent* changes, so a widget that subscribes
      // after preparation started would show nothing until the next
      // transition — losing exactly the download progress it exists to show.
      // Stream.multi's callback runs synchronously on subscribe, so no state
      // change can slip between the replay and the subscription.
      Stream<SpeechEngineState>.multi((controller) {
        controller.add(_state);
        final sub = _stateController.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        controller.onCancel = sub.cancel;
      });

  void _emit(SpeechEngineState next) {
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  @override
  Future<bool> prepare() {
    // Concurrent callers (screen rebuild, retry tap) share one attempt rather
    // than kicking off parallel downloads of a 49 MB file.
    final inFlight = _preparation;
    if (inFlight != null) return inFlight;

    final attempt = _prepare();
    _preparation = attempt;
    // Let a failed attempt be retried; a successful one stays cached.
    unawaited(
      attempt.then(
        (ok) {
          if (!ok) _preparation = null;
        },
        onError: (_) {
          _preparation = null;
        },
      ),
    );
    return attempt;
  }

  Future<bool> _prepare() async {
    if (_recognizer != null) return true;

    final factory = recognizerFactory;
    if (factory != null) {
      _emit(const SpeechEngineState(status: SpeechEngineStatus.loading));
      _recognizer = await factory();
      _emit(const SpeechEngineState(status: SpeechEngineStatus.ready));
      return true;
    }

    if (kIsWeb) {
      _emit(SpeechEngineState.unsupported);
      return false;
    }

    try {
      await initializeRuntime();

      _emit(const SpeechEngineState(status: SpeechEngineStatus.downloading));

      // Idempotent: once the files are on disk this resolves without
      // touching the network, so it is safe on every launch.
      await FlutterGemma.installStt()
          .modelFromNetwork(_modelUrl)
          .tokenizerFromNetwork(_tokenizerUrl)
          .ofType(SttModelType.moonshine)
          .withModelProgress((percent) {
            _emit(
              SpeechEngineState(
                status: SpeechEngineStatus.downloading,
                progress: (percent / 100).clamp(0.0, 1.0),
              ),
            );
          })
          .install();

      _emit(const SpeechEngineState(status: SpeechEngineStatus.loading));
      _recognizer = await FlutterGemma.getActiveStt();

      _emit(const SpeechEngineState(status: SpeechEngineStatus.ready));
      return true;
    } catch (e) {
      log('GemmaSpeechService: prepare failed: $e');
      _emit(
        SpeechEngineState(
          status: SpeechEngineStatus.failed,
          error: _describeFailure(e),
        ),
      );
      return false;
    }
  }

  /// Turns an engine failure into something worth showing.
  ///
  /// The common one is a native-library load error, which surfaces as an
  /// opaque `dlopen` message naming files no user has heard of. It has two
  /// causes worth separating, because the fix differs and neither is obvious
  /// from the raw text.
  static String _describeFailure(Object error) {
    final text = error.toString();
    final isLoadFailure =
        text.contains('LiteRtLm') || text.contains('dynamic library');

    if (isLoadFailure) {
      return 'On-device transcription is unavailable in this build — the '
          'speech runtime could not be loaded. Recording and transcription '
          'still work; only the live preview is missing. If you are '
          'developing, check that `flutter config --enable-native-assets` is '
          'set and see the notes in README.md.';
    }

    return 'On-device transcription is unavailable. Recording and '
        'transcription still work; only the live preview is missing.';
  }

  @override
  Future<void> listen(
    Stream<Uint8List> pcm,
    void Function(String transcript) onTranscript,
  ) async {
    if (_recognizer == null) {
      log('GemmaSpeechService: listen ignored — engine not prepared');
      return;
    }

    // Ends any previous recording and starts a new fencing session, so
    // nothing still decoding can leak into this one.
    await abort();

    _onTranscript = onTranscript;
    _pcmSub = pcm.listen(
      _onChunk,
      onError: (Object e) => log('GemmaSpeechService: pcm stream error: $e'),
      cancelOnError: false,
    );
  }

  void _onChunk(Uint8List chunk) {
    for (final window in _segmenter.add(chunk)) {
      _enqueueDecode(window);
    }
  }

  void _enqueueDecode(Uint8List window) {
    final session = _session;

    _decodeQueue = _decodeQueue.then((_) async {
      // Checked before the work: a window belonging to an abandoned recording
      // should not even occupy the interpreter.
      if (session != _session) return;

      final recognizer = _recognizer;
      if (recognizer == null) return;

      final String text;
      try {
        text = (await recognizer.transcribe(window)).trim();
      } catch (e) {
        // A failed window costs us those few seconds of preview text; the
        // recording itself is unaffected and Gemini still transcribes it.
        log('GemmaSpeechService: transcribe failed: $e');
        return;
      }

      // Checked again after the await: the recording may have been abandoned
      // while this window was decoding.
      if (session != _session || text.isEmpty) return;

      if (_settled.isNotEmpty) _settled.write(' ');
      _settled.write(text);
      _onTranscript?.call(_settled.toString());
    });
  }

  @override
  Future<String> finish() async {
    final session = _session;

    await _pcmSub?.cancel();
    _pcmSub = null;

    // Decode the final phrase, which no pause will have closed.
    final tail = _segmenter.flush();
    if (tail != null) _enqueueDecode(tail);

    await _decodeQueue;

    // An abort or a new recording during the drain wins; returning the
    // transcript now would attribute it to the wrong recording.
    if (session != _session) return '';

    final transcript = _settled.toString().trim();
    _endSession();
    return transcript;
  }

  @override
  Future<void> abort() async {
    await _pcmSub?.cancel();
    _pcmSub = null;
    _endSession();
  }

  /// Closes the current recording: anything still decoding for it becomes
  /// stale and will discard itself.
  void _endSession() {
    _session++;
    _segmenter.reset();
    _settled.clear();
    _onTranscript = null;
  }

  @override
  Future<void> dispose() async {
    await abort();
    await _stateController.close();
    try {
      await _recognizer?.close();
    } catch (e) {
      log('GemmaSpeechService: recognizer close failed: $e');
    }
    _recognizer = null;
  }
}
