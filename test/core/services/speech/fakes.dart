import 'dart:async';
import 'dart:typed_data';

import 'package:widget_overlay_outside/core/services/speech/audio_capture_service.dart';
import 'package:widget_overlay_outside/core/services/speech/speech_recognition_service.dart';

/// Stands in for the microphone. Records how it was driven so tests can assert
/// the device is opened once and always released.
class FakeAudioCapture implements AudioCaptureService {
  FakeAudioCapture({this.permitted = true, this.audio});

  bool permitted;

  /// What [stop] hands back. Null models a capture that produced nothing.
  CapturedAudio? audio;

  /// Delays [stop], so a test can observe the state the UI is left in while
  /// the microphone is closing.
  Duration stopDelay = Duration.zero;

  final _pcm = StreamController<Uint8List>.broadcast();
  final _amplitude = StreamController<double>.broadcast();

  var starts = 0;
  var stops = 0;
  var cancels = 0;
  var disposals = 0;
  var _capturing = false;

  void emit(Uint8List chunk) => _pcm.add(chunk);

  @override
  bool get isCapturing => _capturing;

  @override
  Stream<Uint8List> get pcmStream => _pcm.stream;

  @override
  Stream<double> get amplitudeStream => _amplitude.stream;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<bool> start() async {
    starts++;
    if (!permitted) return false;
    _capturing = true;
    return true;
  }

  @override
  Future<CapturedAudio?> stop() async {
    stops++;
    if (stopDelay > Duration.zero) await Future<void>.delayed(stopDelay);
    _capturing = false;
    return audio;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    _capturing = false;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    _capturing = false;
    await _pcm.close();
    await _amplitude.close();
  }
}

/// Stands in for the on-device recogniser.
class FakeSpeechRecognition implements SpeechRecognitionService {
  FakeSpeechRecognition({
    SpeechEngineStatus status = SpeechEngineStatus.ready,
    this.transcript = '',
  }) : _state = SpeechEngineState(status: status);

  final SpeechEngineState _state;

  /// What [finish] returns.
  String transcript;

  /// Delays [finish], modelling the decode backlog drained on stop.
  Duration finishDelay = Duration.zero;

  var listens = 0;
  var finishes = 0;
  var aborts = 0;
  void Function(String)? _onTranscript;

  /// Pushes an interim transcript the way a settled window would.
  void emitTranscript(String text) => _onTranscript?.call(text);

  @override
  SpeechEngineState get state => _state;

  @override
  Stream<SpeechEngineState> get stateStream => Stream.value(_state);

  @override
  Future<bool> prepare() async => _state.isReady;

  @override
  Future<void> listen(
    Stream<Uint8List> pcm,
    void Function(String transcript) onTranscript,
  ) async {
    listens++;
    _onTranscript = onTranscript;
  }

  @override
  Future<String> finish() async {
    finishes++;
    if (finishDelay > Duration.zero) await Future<void>.delayed(finishDelay);
    _onTranscript = null;
    return transcript;
  }

  @override
  Future<void> abort() async {
    aborts++;
    _onTranscript = null;
  }

  @override
  Future<void> dispose() async {}
}
