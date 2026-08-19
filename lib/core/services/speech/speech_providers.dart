import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_capture_service.dart';
import 'gemma_speech_service.dart';
import 'speech_recognition_service.dart';

/// App-lifetime, deliberately not `autoDispose`.
///
/// Loading Moonshine costs a 49 MB download once and a few hundred
/// milliseconds of model load on every `getActiveStt()`. Tearing it down
/// between sessions would repay that cost each time the user starts an
/// answer, so one instance lives for the life of the app.
final speechRecognitionServiceProvider = Provider<SpeechRecognitionService>((
  ref,
) {
  final service = kIsWeb
      ? UnsupportedSpeechRecognitionService()
      : GemmaSpeechService();
  ref.onDispose(service.dispose);
  return service;
});

/// Readiness and download progress of the on-device engine.
final speechEngineStateProvider = StreamProvider<SpeechEngineState>((ref) {
  final service = ref.watch(speechRecognitionServiceProvider);
  return service.stateStream;
});

/// Per-consumer microphone owner.
///
/// `autoDispose` so leaving a recording screen always releases the mic — a
/// live capture is exactly the kind of resource that must not outlive the
/// screen that started it.
final audioCaptureServiceProvider = Provider.autoDispose<AudioCaptureService>((
  ref,
) {
  final service = AudioCaptureService();
  ref.onDispose(service.dispose);
  return service;
});
