import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:widget_overlay_outside/core/services/speech/audio_capture_service.dart';
import 'package:widget_overlay_outside/core/services/speech/speech_recognition_service.dart';
import 'package:widget_overlay_outside/features/recording/providers/recording_provider.dart';
import 'package:widget_overlay_outside/features/topic_selection/data/models/topic.dart';

import '../../core/services/speech/fakes.dart';

const _topic = Topic(
  id: 't1',
  title: 'Describe a challenge',
  category: 'Work',
  hint: '',
);

CapturedAudio _audio({int seconds = 90}) =>
    CapturedAudio(pcm: Uint8List(16000 * 2 * seconds), sampleRate: 16000);

void main() {
  late FakeAudioCapture capture;
  late FakeSpeechRecognition recognition;
  late RecordingNotifier notifier;

  RecordingNotifier build() =>
      RecordingNotifier(capture: capture, recognition: recognition);

  setUp(() {
    capture = FakeAudioCapture(audio: _audio());
    recognition = FakeSpeechRecognition(transcript: 'um so I think');
    notifier = build();
  });

  tearDown(() => notifier.dispose());

  group('starting', () {
    test('opens the microphone exactly once', () async {
      await notifier.startRecording(_topic);

      expect(capture.starts, 1);
      expect(notifier.state.isRecording, isTrue);
      expect(notifier.state.topicTitle, _topic.title);
    });

    test('attaches the recogniser to the capture we already opened', () async {
      await notifier.startRecording(_topic);
      expect(recognition.listens, 1);
    });

    test(
      'records without the recogniser when the model is not ready',
      () async {
        recognition = FakeSpeechRecognition(
          status: SpeechEngineStatus.downloading,
        );
        notifier = build();

        await notifier.startRecording(_topic);

        expect(
          notifier.state.isRecording,
          isTrue,
          reason: 'recording proceeds',
        );
        expect(recognition.listens, 0, reason: 'nothing to attach yet');
      },
    );

    test('surfaces an error when the microphone is refused', () async {
      capture = FakeAudioCapture(permitted: false);
      notifier = build();

      await notifier.startRecording(_topic);

      expect(notifier.state.status, RecordingStatus.error);
      expect(notifier.state.errorMessage, contains('Microphone'));
    });

    test('shows the live transcript as windows settle', () async {
      await notifier.startRecording(_topic);
      recognition.emitTranscript('um so');

      expect(notifier.state.transcript, 'um so');
    });
  });

  group('stopping', () {
    test('announces the wait before taking it', () async {
      // Regression: the UI used to sit in `recording` with a stopped timer
      // while the decode backlog drained, which reads as a hang.
      capture.stopDelay = const Duration(milliseconds: 50);
      await notifier.startRecording(_topic);

      final pending = notifier.stopManually();
      expect(notifier.state.status, RecordingStatus.finalising);

      await pending;
      expect(notifier.state.status, RecordingStatus.stopped);
    });

    test('closes the microphone and drains the recogniser', () async {
      await notifier.startRecording(_topic);
      await notifier.stopManually();

      expect(capture.stops, 1);
      expect(recognition.finishes, 1);
    });

    test('builds a session carrying audio and transcript', () async {
      await notifier.startRecording(_topic);
      await notifier.stopManually();

      final session = notifier.state.completedSession;
      expect(session, isNotNull);
      expect(session!.hasAudio, isTrue);
      expect(session.transcript, 'um so I think');
      expect(session.topicTitle, _topic.title);
    });

    test('takes the duration from the audio, not the wall clock', () async {
      // Words-per-minute divides by this, so a timer that drifted or a
      // capture that started late would skew the headline metric.
      capture.audio = _audio(seconds: 90);
      await notifier.startRecording(_topic);
      await notifier.stopManually();

      expect(notifier.state.completedSession!.durationSeconds, 90);
    });

    test('a second stop cannot build a second session', () async {
      capture.stopDelay = const Duration(milliseconds: 30);
      await notifier.startRecording(_topic);

      await Future.wait([notifier.stopManually(), notifier.stopManually()]);

      expect(capture.stops, 1, reason: 'the microphone is closed once');
      expect(recognition.finishes, 1);
    });

    test('reports an error when nothing was captured', () async {
      capture = FakeAudioCapture(audio: null);
      recognition = FakeSpeechRecognition(transcript: '');
      notifier = build();

      await notifier.startRecording(_topic);
      await notifier.stopManually();

      expect(notifier.state.status, RecordingStatus.error);
      expect(notifier.state.completedSession, isNull);
    });

    test('keeps a transcript that arrived without audio', () async {
      capture = FakeAudioCapture(audio: null);
      notifier = build();

      await notifier.startRecording(_topic);
      await notifier.stopManually();

      expect(notifier.state.completedSession?.transcript, 'um so I think');
    });
  });

  group('releasing the device', () {
    test('reset closes the microphone and detaches the recogniser', () async {
      await notifier.startRecording(_topic);
      notifier.reset();
      await pumpEventQueue();

      expect(capture.cancels, 1);
      expect(recognition.aborts, greaterThanOrEqualTo(1));
      expect(notifier.state.status, RecordingStatus.idle);
    });

    test('dispose closes the microphone even mid-recording', () async {
      await notifier.startRecording(_topic);
      notifier.dispose();
      await pumpEventQueue();

      expect(capture.cancels, greaterThanOrEqualTo(1));
      notifier = build(); // tearDown disposes a fresh, unused notifier
    });

    test('a take can be restarted after a reset', () async {
      await notifier.startRecording(_topic);
      notifier.reset();
      await notifier.startRecording(_topic);

      expect(capture.starts, 2);
      expect(notifier.state.isRecording, isTrue);
    });
  });
}
