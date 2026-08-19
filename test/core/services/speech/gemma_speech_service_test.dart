import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_gemma/flutter_gemma.dart' show SpeechRecognizer;
import 'package:flutter_test/flutter_test.dart';
import 'package:widget_overlay_outside/core/services/speech/gemma_speech_service.dart';
import 'package:widget_overlay_outside/core/services/speech/speech_recognition_service.dart';

const _bytesPerSecond = 32000; // 16 kHz, mono, 16-bit

/// Moonshine's real window. Nothing handed to [SpeechRecognizer.transcribe]
/// may exceed it, or the model discards the excess without saying so.
const _modelWindowBytes = _bytesPerSecond * 5;

Uint8List _speech(int bytes) {
  final samples = Int16List(bytes ~/ 2);
  for (var i = 0; i < samples.length; i++) {
    samples[i] = i.isEven ? 8000 : -8000;
  }
  return samples.buffer.asUint8List();
}

Uint8List _silence(int bytes) => Uint8List(bytes);

/// Stands in for the LiteRT recognizer so the streaming, fencing and
/// accumulation logic can be tested without a model or a device.
class _FakeRecognizer implements SpeechRecognizer {
  _FakeRecognizer({List<String>? script}) : _script = script ?? const [];

  final List<String> _script;
  final List<Uint8List> received = [];

  /// When set, decoding blocks until it completes — used to hold a window
  /// "in flight" across an abort.
  Completer<void>? gate;

  var _index = 0;
  var closed = false;

  @override
  Future<String> transcribe(Uint8List pcm16kMono) async {
    received.add(pcm16kMono);
    final gate = this.gate;
    if (gate != null) await gate.future;
    // Yield at least once so callers can interleave.
    await Future<void>.delayed(Duration.zero);
    return _index < _script.length ? _script[_index++] : 'word';
  }

  @override
  void addCloseListener(void Function() listener) {}

  @override
  Future<void> close() async => closed = true;
}

void main() {
  late _FakeRecognizer recognizer;
  late GemmaSpeechService service;
  late StreamController<Uint8List> pcm;

  Future<GemmaSpeechService> ready({List<String>? script}) async {
    recognizer = _FakeRecognizer(script: script);
    service = GemmaSpeechService(recognizerFactory: () async => recognizer);
    expect(await service.prepare(), isTrue);
    return service;
  }

  setUp(() => pcm = StreamController<Uint8List>.broadcast());

  tearDown(() async {
    await pcm.close();
    await service.dispose();
  });

  /// One phrase followed by a pause, which is what closes a window.
  void speakPhrase({int millis = 1000}) {
    pcm.add(_speech(_bytesPerSecond * millis ~/ 1000));
    pcm.add(_silence(_bytesPerSecond ~/ 2));
  }

  group('readiness', () {
    test('reports ready once prepared', () async {
      await ready();
      expect(service.state.status, SpeechEngineStatus.ready);
    });

    test('replays current state to a late subscriber', () async {
      // Regression: a plain broadcast stream delivered only future changes,
      // so a widget subscribing after preparation saw nothing at all.
      await ready();

      final first = await service.stateStream.first;
      expect(first.status, SpeechEngineStatus.ready);
    });

    test('shares one preparation between concurrent callers', () async {
      var calls = 0;
      recognizer = _FakeRecognizer();
      service = GemmaSpeechService(
        recognizerFactory: () async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return recognizer;
        },
      );

      await Future.wait([service.prepare(), service.prepare()]);
      expect(calls, 1, reason: 'a 49 MB download must not run twice');
    });

    test('listening before preparation is a no-op, not a crash', () async {
      recognizer = _FakeRecognizer();
      service = GemmaSpeechService(recognizerFactory: () async => recognizer);

      await service.listen(pcm.stream, (_) {});
      speakPhrase();
      await pumpEventQueue();

      expect(recognizer.received, isEmpty);
      expect(await service.finish(), isEmpty);
    });
  });

  group('transcription', () {
    test('accumulates windows in order', () async {
      await ready(script: ['hello there', 'second phrase']);
      await service.listen(pcm.stream, (_) {});

      speakPhrase();
      await pumpEventQueue();
      speakPhrase();
      await pumpEventQueue();

      expect(await service.finish(), 'hello there second phrase');
    });

    test('reports progress through the callback as windows settle', () async {
      await ready(script: ['first', 'second']);
      final seen = <String>[];
      await service.listen(pcm.stream, seen.add);

      speakPhrase();
      await pumpEventQueue();
      speakPhrase();
      await pumpEventQueue();
      await service.finish();

      expect(seen, ['first', 'first second']);
    });

    test('decodes the final phrase even without a closing pause', () async {
      await ready(script: ['trailing words']);
      await service.listen(pcm.stream, (_) {});

      // No trailing silence: only finish() can close this window.
      pcm.add(_speech(_bytesPerSecond));
      await pumpEventQueue();

      expect(await service.finish(), 'trailing words');
    });

    test('never hands the model more than its window', () async {
      await ready();
      await service.listen(pcm.stream, (_) {});

      // 30 s of unbroken speech — no pauses to split on.
      for (var i = 0; i < 30; i++) {
        pcm.add(_speech(_bytesPerSecond));
        await pumpEventQueue();
      }
      await service.finish();

      expect(recognizer.received, isNotEmpty);
      for (final window in recognizer.received) {
        expect(window.length, lessThanOrEqualTo(_modelWindowBytes));
      }
    });

    test('does not decode silence', () async {
      await ready();
      await service.listen(pcm.stream, (_) {});

      for (var i = 0; i < 5; i++) {
        pcm.add(_silence(_bytesPerSecond));
        await pumpEventQueue();
      }

      expect(await service.finish(), isEmpty);
      expect(recognizer.received, isEmpty);
    });
  });

  group('session fencing', () {
    test(
      'a decode still in flight cannot leak into the next recording',
      () async {
        // The regression this guards: abort() cleared the buffer but left
        // queued decodes running, so a late result from an abandoned recording
        // was appended to the next one's transcript.
        await ready(script: ['ABANDONED', 'KEPT']);
        await service.listen(pcm.stream, (_) {});

        final gate = Completer<void>();
        recognizer.gate = gate;

        speakPhrase();
        await pumpEventQueue();
        expect(
          recognizer.received,
          hasLength(1),
          reason: 'decode is in flight',
        );

        // User leaves mid-recording, then starts a new one.
        await service.abort();
        await service.listen(pcm.stream, (_) {});

        // The abandoned decode now completes.
        recognizer.gate = null;
        gate.complete();
        await pumpEventQueue();

        speakPhrase();
        await pumpEventQueue();

        expect(await service.finish(), 'KEPT');
      },
    );

    test('no transcript callback fires after abort', () async {
      await ready(script: ['LATE']);
      final seen = <String>[];
      await service.listen(pcm.stream, seen.add);

      final gate = Completer<void>();
      recognizer.gate = gate;
      speakPhrase();
      await pumpEventQueue();

      await service.abort();
      recognizer.gate = null;
      gate.complete();
      await pumpEventQueue();

      expect(seen, isEmpty);
    });

    test('abort clears text already settled', () async {
      await ready(script: ['first phrase']);
      await service.listen(pcm.stream, (_) {});

      speakPhrase();
      await pumpEventQueue();

      await service.abort();
      await service.listen(pcm.stream, (_) {});

      expect(await service.finish(), isEmpty);
    });

    test(
      'finish returns nothing if the recording was abandoned mid-drain',
      () async {
        await ready(script: ['STALE']);
        await service.listen(pcm.stream, (_) {});

        final gate = Completer<void>();
        recognizer.gate = gate;
        speakPhrase();
        await pumpEventQueue();

        final pending = service.finish();
        await service.abort();

        recognizer.gate = null;
        gate.complete();

        expect(await pending, isEmpty);
      },
    );

    test('consecutive recordings do not bleed into each other', () async {
      await ready(script: ['one', 'two']);

      await service.listen(pcm.stream, (_) {});
      speakPhrase();
      await pumpEventQueue();
      expect(await service.finish(), 'one');

      await service.listen(pcm.stream, (_) {});
      speakPhrase();
      await pumpEventQueue();
      expect(await service.finish(), 'two');
    });
  });

  group('lifecycle', () {
    test('dispose closes the recognizer', () async {
      await ready();
      await service.dispose();
      expect(recognizer.closed, isTrue);
    });
  });
}
