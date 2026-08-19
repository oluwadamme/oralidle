import 'dart:async';
import 'dart:typed_data';

/// How the live-transcript engine is doing, so the UI can explain itself
/// instead of just showing nothing.
enum SpeechEngineStatus {
  /// Not supported on this platform (web today) — audio still records and is
  /// transcribed server-side, there is simply no on-device preview.
  unsupported,

  /// Supported but the model has not been fetched yet.
  notInstalled,

  /// Model download in progress; see [SpeechEngineState.progress].
  downloading,

  /// Loading the downloaded model into memory.
  loading,

  /// Ready to transcribe.
  ready,

  /// Preparation failed; see [SpeechEngineState.error].
  failed,
}

class SpeechEngineState {
  final SpeechEngineStatus status;

  /// 0..1 while [status] is [SpeechEngineStatus.downloading].
  final double progress;
  final String? error;

  const SpeechEngineState({
    required this.status,
    this.progress = 0,
    this.error,
  });

  static const unsupported = SpeechEngineState(
    status: SpeechEngineStatus.unsupported,
  );

  bool get isReady => status == SpeechEngineStatus.ready;
  bool get isBusy =>
      status == SpeechEngineStatus.downloading ||
      status == SpeechEngineStatus.loading;
}

/// Turns a stream of microphone PCM into text as the user speaks.
///
/// Implementations never touch the microphone themselves — they consume the
/// PCM handed to them by [AudioCaptureService], which is the only component
/// allowed to open it. That constraint is what keeps a live transcript and a
/// recorded clip from fighting over the same device.
abstract class SpeechRecognitionService {
  /// Current readiness, including model-download progress.
  ///
  /// Implementations MUST replay the current state to every new subscriber.
  /// A widget typically subscribes after preparation has already begun, and a
  /// stream that only carries future transitions would leave it blank through
  /// the entire download — the one moment the state matters.
  Stream<SpeechEngineState> get stateStream;
  SpeechEngineState get state;

  /// Downloads and loads whatever the engine needs. Safe to call repeatedly;
  /// returns true when the engine is ready to transcribe.
  Future<bool> prepare();

  /// Starts consuming [pcm] (16 kHz mono 16-bit LE). [onTranscript] receives
  /// the full transcript so far each time more text is settled.
  Future<void> listen(
    Stream<Uint8List> pcm,
    void Function(String transcript) onTranscript,
  );

  /// Stops consuming audio, transcribes anything still buffered, and returns
  /// the final transcript.
  Future<String> finish();

  /// Stops consuming audio and discards any buffered audio.
  Future<void> abort();

  Future<void> dispose();
}

/// Used on platforms with no on-device engine (web today).
///
/// Recording and server-side transcription still work — this simply reports
/// that there is no live preview, so callers can degrade gracefully rather
/// than branch on `kIsWeb` at every call site.
class UnsupportedSpeechRecognitionService implements SpeechRecognitionService {
  @override
  SpeechEngineState get state => SpeechEngineState.unsupported;

  @override
  Stream<SpeechEngineState> get stateStream =>
      Stream.value(SpeechEngineState.unsupported);

  @override
  Future<bool> prepare() async => false;

  @override
  Future<void> listen(
    Stream<Uint8List> pcm,
    void Function(String transcript) onTranscript,
  ) async {}

  @override
  Future<String> finish() async => '';

  @override
  Future<void> abort() async {}

  @override
  Future<void> dispose() async {}
}
