import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  bool _shouldContinue = false;
  Function(String text, bool isFinal)? _onResult;

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (error) => debugPrint('STT error: ${error.errorMsg}'),
      onStatus: (status) {
        // Some engines (especially Android) emit 'done' instead of, or in
        // addition to, 'notListening'. Catching both prevents the continuous
        // listener from silently going dark mid-answer.
        final ended = status == SpeechToText.notListeningStatus ||
            status == SpeechToText.doneStatus;
        if (ended && _shouldContinue) {
          Future.delayed(const Duration(milliseconds: 500), _listen);
        }
      },
    );
    return _initialized;
  }

  Future<void> startContinuous(Function(String text, bool isFinal) onResult) async {
    _onResult = onResult;
    _shouldContinue = true;
    await _listen();
  }

  Future<void> _listen() async {
    if (!_shouldContinue || _onResult == null) return;
    if (_speech.isListening) return;
    await _speech.listen(
      onResult: (result) => _onResult!(result.recognizedWords, result.finalResult),
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 10),
      localeId: 'en_US',
      listenOptions: SpeechListenOptions(partialResults: true),
    );
  }

  Future<void> stop() async {
    _shouldContinue = false;
    _onResult = null;
    await _speech.stop();
  }

  bool get isListening => _speech.isListening;
  bool get isAvailable => _speech.isAvailable;
}
