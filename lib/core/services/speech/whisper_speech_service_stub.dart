import 'speech_recognition_service.dart';

/// Never selected on native, where Moonshine handles transcription.
SpeechRecognitionService createWhisperSpeechService() =>
    UnsupportedSpeechRecognitionService();
