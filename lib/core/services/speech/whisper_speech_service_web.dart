import 'dart:async';
import 'dart:developer' show log;
import 'dart:js_interop';
import 'dart:typed_data';

import 'pcm16_view.dart';
import 'speech_recognition_service.dart';

@JS('oralidleWhisper')
external JSObject? get _whisper;

@JS('oralidleWhisper.load')
external JSPromise<JSAny?> _load(JSFunction onProgress);

@JS('oralidleWhisper.transcribe')
external JSPromise<JSString> _transcribe(JSFloat32Array audio);

SpeechRecognitionService createWhisperSpeechService() => WhisperSpeechService();

/// Browser speech-to-text using Whisper compiled to WASM.
///
/// Fills the gap left by Moonshine, which reaches LiteRT through `dart:ffi`
/// and therefore cannot run on web. Audio never leaves the device.
///
/// Whisper is a batch model, so unlike Moonshine there is no live preview: the
/// buffered take is transcribed in [finish]. That is enough for everything
/// downstream, which only reads the transcript once a recording ends.
class WhisperSpeechService implements SpeechRecognitionService {
  final _stateController = StreamController<SpeechEngineState>.broadcast();
  final _buffer = BytesBuilder(copy: false);

  SpeechEngineState _state = const SpeechEngineState(
    status: SpeechEngineStatus.notInstalled,
  );

  StreamSubscription<Uint8List>? _sub;
  Future<bool>? _preparation;
  int _session = 0;

  @override
  SpeechEngineState get state => _state;

  @override
  Stream<SpeechEngineState> get stateStream =>
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
    final inFlight = _preparation;
    if (inFlight != null) return inFlight;

    final attempt = _prepare();
    _preparation = attempt;
    unawaited(
      attempt.then((ok) {
        if (!ok) _preparation = null;
      }, onError: (_) => _preparation = null),
    );
    return attempt;
  }

  Future<bool> _prepare() async {
    if (_whisper == null) {
      _emit(
        const SpeechEngineState(
          status: SpeechEngineStatus.failed,
          error: 'Speech recognition script did not load.',
        ),
      );
      return false;
    }

    try {
      _emit(const SpeechEngineState(status: SpeechEngineStatus.downloading));

      void onProgress(JSNumber fraction) {
        _emit(
          SpeechEngineState(
            status: SpeechEngineStatus.downloading,
            progress: fraction.toDartDouble.clamp(0.0, 1.0),
          ),
        );
      }

      await _load(onProgress.toJS).toDart;
      _emit(const SpeechEngineState(status: SpeechEngineStatus.ready));
      return true;
    } catch (e) {
      log('WhisperSpeechService: prepare failed: $e');
      _emit(
        SpeechEngineState(
          status: SpeechEngineStatus.failed,
          error:
              'On-device transcription is unavailable in this browser. '
              'Recording still works; the analysis runs server-side.',
        ),
      );
      return false;
    }
  }

  @override
  Future<void> listen(
    Stream<Uint8List> pcm,
    void Function(String transcript) onTranscript,
  ) async {
    await abort();
    _sub = pcm.listen(
      _buffer.add,
      onError: (Object e) => log('WhisperSpeechService: pcm error: $e'),
      cancelOnError: false,
    );
  }

  @override
  Future<String> finish() async {
    final session = _session;

    await _sub?.cancel();
    _sub = null;

    final pcm = _buffer.takeBytes();
    _reset();

    if (pcm.isEmpty || !_state.isReady) return '';

    try {
      final text = await _transcribe(_toFloat32(pcm).toJS).toDart;
      // A recording abandoned mid-decode must not surface under the next one.
      if (session != _session) return '';
      return text.toDart.trim();
    } catch (e) {
      log('WhisperSpeechService: transcribe failed: $e');
      return '';
    }
  }

  /// PCM16 little-endian to the normalised float samples Whisper expects.
  /// Read through [Pcm16View] because a capture chunk is not guaranteed to
  /// start on an even byte offset.
  static Float32List _toFloat32(Uint8List pcm) {
    final view = Pcm16View(pcm);
    final out = Float32List(view.length);
    for (var i = 0; i < view.length; i++) {
      out[i] = view.normalised(i);
    }
    return out;
  }

  @override
  Future<void> abort() async {
    await _sub?.cancel();
    _sub = null;
    _reset();
  }

  void _reset() {
    _session++;
    _buffer.clear();
  }

  @override
  Future<void> dispose() async {
    await abort();
    await _stateController.close();
  }
}
