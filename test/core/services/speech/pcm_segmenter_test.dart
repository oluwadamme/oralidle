import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:widget_overlay_outside/core/services/speech/audio_capture_service.dart';
import 'package:widget_overlay_outside/core/services/speech/pcm_segmenter.dart';

const _bytesPerSecond = 32000; // 16 kHz, mono, 16-bit

/// Loud enough to read as speech (well above the 0.05 silence threshold).
Uint8List _speech(int bytes) {
  final samples = Int16List(bytes ~/ 2);
  for (var i = 0; i < samples.length; i++) {
    samples[i] = i.isEven ? 8000 : -8000;
  }
  return samples.buffer.asUint8List();
}

Uint8List _silence(int bytes) => Uint8List(bytes);

/// Feeds [pcm] the way the microphone does — in small chunks.
List<Uint8List> _feed(PcmSegmenter s, Uint8List pcm, {int chunk = 1024}) {
  final windows = <Uint8List>[];
  for (var i = 0; i < pcm.length; i += chunk) {
    final end = (i + chunk < pcm.length) ? i + chunk : pcm.length;
    windows.addAll(s.add(Uint8List.sublistView(pcm, i, end)));
  }
  return windows;
}

PcmSegmenter build() => PcmSegmenter(
  maxWindowBytes: _bytesPerSecond * 9 ~/ 2, // 4.5 s
  minVoicedBytes: _bytesPerSecond * 2 ~/ 5, // 400 ms
  silenceHoldBytes: _bytesPerSecond * 7 ~/ 20, // 350 ms
  cutSearchBytes: _bytesPerSecond,
);

void main() {
  group('loudness gate', () {
    test('digital silence reads as silent, tone reads as speech', () {
      expect(AudioCaptureService.normalisedLoudness(_silence(1024)), 0);
      expect(
        AudioCaptureService.normalisedLoudness(_speech(1024)),
        greaterThan(0.05),
      );
    });
  });

  group('PcmSegmenter', () {
    test('never emits a window past the model limit', () {
      // The whole point: Moonshine silently discards audio past its window,
      // so a window that is too long loses speech with no error raised.
      final segmenter = build();
      final windows = _feed(segmenter, _speech(_bytesPerSecond * 30));

      expect(windows, isNotEmpty);
      for (final window in windows) {
        expect(window.length, lessThanOrEqualTo(_bytesPerSecond * 9 ~/ 2));
      }
    });

    test('splits continuous speech without dropping any audio', () {
      final segmenter = build();
      const total = _bytesPerSecond * 30;
      final windows = _feed(segmenter, _speech(total));

      final emitted = windows.fold<int>(0, (sum, w) => sum + w.length);
      expect(
        emitted + segmenter.bufferedBytes,
        total,
        reason: 'every byte is either emitted or still buffered',
      );
    });

    test('closes a window at a pause, well short of the hard limit', () {
      final segmenter = build();

      // One second of speech, then a clear pause.
      var windows = _feed(segmenter, _speech(_bytesPerSecond));
      expect(windows, isEmpty, reason: 'no pause yet, nothing to close');

      windows = _feed(segmenter, _silence(_bytesPerSecond ~/ 2));
      expect(windows, hasLength(1));
      expect(
        windows.single.length,
        lessThan(_bytesPerSecond * 9 ~/ 2),
        reason: 'cut by the pause, not by the size limit',
      );
    });

    test('discards silence instead of decoding it', () {
      // Decoding room tone wastes a pass and invites hallucinated words.
      final segmenter = build();
      final windows = _feed(segmenter, _silence(_bytesPerSecond * 5));

      expect(windows, isEmpty);
      // Silence is dropped each time the hold is reached, so what remains is
      // only the tail below that threshold — never a growing backlog.
      expect(segmenter.bufferedBytes, lessThan(_bytesPerSecond * 7 ~/ 20));
      expect(segmenter.flush(), isNull);
    });

    test('drops a size-forced window that holds only silence', () {
      // Fed as one oversized chunk so the buffer passes the window limit
      // before the pause detector gets a chance to clear it. Nothing here is
      // speech, so nothing should reach the model.
      final segmenter = build();
      final windows = segmenter.add(_silence(_bytesPerSecond * 5));

      expect(windows, isEmpty);
    });

    test('does not count carried-over silence as speech', () {
      // Regression: the tail carried across a forced cut used to be assumed
      // voiced, which let silence masquerade as speech on the next window.
      final segmenter = build();
      segmenter.add(_silence(_bytesPerSecond * 5));

      expect(segmenter.hasSpeech, isFalse);
      expect(segmenter.flush(), isNull);
    });

    test('carries real speech across a forced cut', () {
      // The complement of the test above: a genuine tail must survive.
      final segmenter = build();
      segmenter.add(_speech(_bytesPerSecond * 5));

      expect(segmenter.hasSpeech, isTrue);
      expect(segmenter.flush(), isNotNull);
    });

    test('ignores a burst too short to be speech', () {
      final segmenter = build();
      // 100 ms of sound — below the 400 ms floor — then a pause.
      _feed(segmenter, _speech(_bytesPerSecond ~/ 10));
      final windows = _feed(segmenter, _silence(_bytesPerSecond ~/ 2));

      expect(windows, isEmpty);
    });

    test(
      'flush returns the final phrase, which no pause would have closed',
      () {
        final segmenter = build();
        _feed(segmenter, _speech(_bytesPerSecond));

        final tail = segmenter.flush();
        expect(tail, isNotNull);
        expect(tail!.length, _bytesPerSecond);
        expect(segmenter.bufferedBytes, 0, reason: 'flush resets');
      },
    );

    test('flush returns nothing when only silence is buffered', () {
      final segmenter = build();
      segmenter.add(_silence(1024));

      expect(segmenter.flush(), isNull);
    });

    test('handles a chunk larger than the window without stranding audio', () {
      final segmenter = build();
      final windows = segmenter.add(_speech(_bytesPerSecond * 12));

      expect(windows.length, greaterThan(1));
      for (final window in windows) {
        expect(window.length, lessThanOrEqualTo(_bytesPerSecond * 9 ~/ 2));
      }
    });

    test('reset clears buffered audio', () {
      final segmenter = build();
      _feed(segmenter, _speech(_bytesPerSecond));
      expect(segmenter.bufferedBytes, greaterThan(0));

      segmenter.reset();
      expect(segmenter.bufferedBytes, 0);
      expect(segmenter.hasSpeech, isFalse);
    });
  });

  group('PcmSegmenter.quietestCut', () {
    test('cuts at the quiet gap rather than through the loud part', () {
      // 1 s loud, then a 200 ms gap, then loud again — the gap is where a
      // word boundary is least likely to be sliced.
      final builder = BytesBuilder()
        ..add(_speech(_bytesPerSecond))
        ..add(_silence(_bytesPerSecond ~/ 5))
        ..add(_speech(_bytesPerSecond ~/ 5));
      final pcm = builder.toBytes();

      final cut = PcmSegmenter.quietestCut(
        pcm,
        searchBytes: _bytesPerSecond,
        frameBytes: 640,
      );

      expect(cut, greaterThan(_bytesPerSecond));
      expect(cut, lessThan(_bytesPerSecond + _bytesPerSecond ~/ 5));
    });

    test('returns an even offset so a 16-bit sample is never split', () {
      final pcm = _speech(_bytesPerSecond * 2);
      final cut = PcmSegmenter.quietestCut(
        pcm,
        searchBytes: _bytesPerSecond,
        frameBytes: 640,
      );

      expect(cut.isEven, isTrue);
    });

    test(
      'cuts at the end when the buffer is shorter than the search window',
      () {
        final pcm = _speech(1024);
        expect(
          PcmSegmenter.quietestCut(
            pcm,
            searchBytes: _bytesPerSecond,
            frameBytes: 640,
          ),
          pcm.length,
        );
      },
    );
  });
}
