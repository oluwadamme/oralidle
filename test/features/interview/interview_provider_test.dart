import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widget_overlay_outside/core/services/speech/audio_capture_service.dart';
import 'package:widget_overlay_outside/core/services/speech/speech_providers.dart';
import 'package:widget_overlay_outside/core/services/speech/speech_recognition_service.dart';
import 'package:widget_overlay_outside/features/interview/data/models/interview_models.dart';
import 'package:widget_overlay_outside/features/interview/data/repositories/interview_repository.dart';
import 'package:widget_overlay_outside/features/interview/providers/interview_history_provider.dart';
import 'package:widget_overlay_outside/features/interview/providers/interview_provider.dart';

import '../../core/services/speech/fakes.dart';

class _FakeRepository implements InterviewRepository {
  final saved = <CompletedInterview>[];

  @override
  Future<void> save(CompletedInterview interview) async => saved.add(interview);

  @override
  List<CompletedInterview> getAll({String? scope}) => saved;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> forget(String id) async =>
      saved.removeWhere((i) => i.id == id);

  @override
  Future<void> cacheFromRemote(CompletedInterview interview) async =>
      saved.add(interview);

  @override
  Future<void> rekey(
    String oldId,
    CompletedInterview updated, {
    String? scope,
  }) async {
    saved.removeWhere((i) => i.id == oldId);
    saved.add(updated);
  }

  @override
  Future<void> claimFromAnonymous(
    String anonymousId,
    CompletedInterview updated,
    String toScope,
  ) async {
    saved.removeWhere((i) => i.id == anonymousId);
    saved.add(updated);
  }
}

CapturedAudio _audio() =>
    CapturedAudio(pcm: Uint8List(16000 * 2 * 30), sampleRate: 16000);

void main() {
  late FakeAudioCapture capture;
  late FakeSpeechRecognition recognition;
  late ProviderContainer container;

  InterviewNotifier notifier() => container.read(interviewProvider.notifier);
  InterviewState state() => container.read(interviewProvider);

  void buildContainer() {
    container = ProviderContainer(
      overrides: [
        audioCaptureServiceProvider.overrideWith((_) => capture),
        speechRecognitionServiceProvider.overrideWith((_) => recognition),
        interviewRepositoryProvider.overrideWithValue(_FakeRepository()),
      ],
    );
    // Keep the autoDispose provider alive for the whole test. Without a
    // listener each read would be free to tear the notifier down and hand the
    // next read a fresh one, which is not how the screen uses it.
    container.listen(interviewProvider, (_, _) {}, fireImmediately: true);
    addTearDown(container.dispose);
  }

  setUp(() {
    capture = FakeAudioCapture(audio: _audio());
    recognition = FakeSpeechRecognition(transcript: 'my answer');
    buildContainer();
  });

  group('answering', () {
    test('opens the microphone once and attaches the recogniser', () async {
      await notifier().startAnswering();

      expect(capture.starts, 1);
      expect(recognition.listens, 1);
      expect(state().isRecording, isTrue);
    });

    test('records even when the on-device model is unavailable', () async {
      // Web, or a model still downloading: Gemini still transcribes the audio.
      recognition = FakeSpeechRecognition(
        status: SpeechEngineStatus.unsupported,
      );
      buildContainer();

      await notifier().startAnswering();

      expect(state().isRecording, isTrue);
      expect(recognition.listens, 0);
    });

    test('surfaces an error when the microphone is refused', () async {
      capture = FakeAudioCapture(permitted: false);
      buildContainer();

      await notifier().startAnswering();

      expect(state().phase, InterviewPhase.error);
      expect(state().error, contains('Microphone'));
    });

    test('shows the live transcript while answering', () async {
      await notifier().startAnswering();
      recognition.emitTranscript('my ans');

      expect(state().transcript, 'my ans');
    });
  });

  group('stopping', () {
    test(
      'shows a finalising phase instead of a frozen recording view',
      () async {
        // Regression: the screen stayed in `recording` — stopped timer, dead
        // waveform — for as long as the decode backlog took to drain.
        capture.stopDelay = const Duration(milliseconds: 50);
        await notifier().startAnswering();

        final pending = notifier().stopAnswering();
        expect(state().phase, InterviewPhase.finalising);
        expect(state().isRecording, isFalse);

        await pending;
        expect(state().phase, isNot(InterviewPhase.finalising));
      },
    );

    test(
      'commits the recording to state before draining the transcript',
      () async {
        // The drain is the long part. Anything that fails after it must still
        // find the audio, so a retry has something to send.
        recognition.finishDelay = const Duration(milliseconds: 50);
        await notifier().startAnswering();

        await notifier().stopAnswering();

        expect(state().lastRecordingAudio, isNotNull);
      },
    );

    test(
      'closes the microphone and drains the recogniser exactly once',
      () async {
        await notifier().startAnswering();
        await notifier().stopAnswering();

        expect(capture.stops, 1);
        expect(recognition.finishes, 1);
      },
    );

    test('a second stop is ignored', () async {
      capture.stopDelay = const Duration(milliseconds: 30);
      await notifier().startAnswering();

      await Future.wait([
        notifier().stopAnswering(),
        notifier().stopAnswering(),
      ]);

      expect(capture.stops, 1);
      expect(recognition.finishes, 1);
    });

    test('stopping outside a recording does nothing', () async {
      await notifier().stopAnswering();

      expect(capture.stops, 0);
      expect(recognition.finishes, 0);
    });

    test('explains itself when nothing was captured', () async {
      // Previously this dropped the user back to the question with no word
      // of why.
      capture = FakeAudioCapture(audio: null);
      recognition = FakeSpeechRecognition(transcript: '');
      buildContainer();

      await notifier().startAnswering();
      await notifier().stopAnswering();

      expect(state().phase, InterviewPhase.waiting);
      expect(state().error, isNotNull);
    });

    test('clears a stale error when the next answer starts', () async {
      capture = FakeAudioCapture(audio: null);
      recognition = FakeSpeechRecognition(transcript: '');
      buildContainer();

      await notifier().startAnswering();
      await notifier().stopAnswering();
      expect(state().error, isNotNull);

      capture.audio = _audio();
      await notifier().startAnswering();

      expect(state().error, isNull);
    });
  });

  group('releasing the device', () {
    test('leaving the screen closes the microphone', () async {
      await notifier().startAnswering();

      container.dispose();
      await pumpEventQueue();

      expect(capture.cancels, greaterThanOrEqualTo(1));
      expect(recognition.aborts, greaterThanOrEqualTo(1));
    });
  });
}
