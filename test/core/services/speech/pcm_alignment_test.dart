import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:widget_overlay_outside/core/services/speech/audio_capture_service.dart';
import 'package:widget_overlay_outside/core/services/speech/pcm16_view.dart';
import 'package:widget_overlay_outside/core/services/speech/wav_codec.dart';

/// Builds PCM16 bytes sitting at [offset] inside a larger buffer, which is how
/// a platform chunk can reach us — as a view, not a buffer of its own.
Uint8List _pcmAtOffset(List<int> samples, int offset) {
  final backing = Uint8List(offset + samples.length * 2);
  final view = ByteData.sublistView(backing, offset);
  for (var i = 0; i < samples.length; i++) {
    view.setInt16(i * 2, samples[i], Endian.little);
  }
  return Uint8List.sublistView(backing, offset);
}

void main() {
  const loud = [8000, -8000, 8000, -8000, 8000, -8000, 8000, -8000];

  group('Pcm16View', () {
    test('reads samples at an odd byte offset', () {
      // The regression: Int16List.sublistView and buffer.asInt16List both
      // throw "Offset (5) must be a multiple of BYTES_PER_ELEMENT (2)" here.
      final pcm = _pcmAtOffset(loud, 5);
      expect(pcm.offsetInBytes.isOdd, isTrue, reason: 'test setup');

      final view = Pcm16View(pcm);
      expect(view.length, loud.length);
      for (var i = 0; i < loud.length; i++) {
        expect(view[i], loud[i]);
      }
    });

    test('reads identically at every offset parity', () {
      for (final offset in [0, 1, 2, 3, 5, 7]) {
        final view = Pcm16View(_pcmAtOffset(loud, offset));
        expect(
          List.generate(view.length, (i) => view[i]),
          loud,
          reason: 'offset $offset',
        );
      }
    });

    test('ignores a trailing half sample', () {
      final pcm = Uint8List.fromList([0x00, 0x10, 0x7f]); // 1.5 samples
      expect(Pcm16View(pcm).length, 1);
    });

    test('normalises to -1..1', () {
      final view = Pcm16View(_pcmAtOffset([32767, -32768, 0], 3));
      expect(view.normalised(0), closeTo(1.0, 0.001));
      expect(view.normalised(1), closeTo(-1.0, 0.001));
      expect(view.normalised(2), 0.0);
    });
  });

  group('normalisedLoudness at an odd offset', () {
    test('does not throw and matches the aligned reading', () {
      final aligned = _pcmAtOffset(loud, 0);
      final misaligned = _pcmAtOffset(loud, 5);

      expect(
        AudioCaptureService.normalisedLoudness(misaligned),
        AudioCaptureService.normalisedLoudness(aligned),
      );
      expect(
        AudioCaptureService.normalisedLoudness(misaligned),
        greaterThan(0.05),
      );
    });

    test(
      'treats a sub-sample buffer as silence rather than dividing by zero',
      () {
        expect(AudioCaptureService.normalisedLoudness(Uint8List(1)), 0);
        expect(AudioCaptureService.normalisedLoudness(Uint8List(0)), 0);
      },
    );
  });

  group('encodeMuLaw at an odd offset', () {
    test('does not throw and produces the same bytes as when aligned', () {
      // The upload path reads samples the same way, so it crashed on exactly
      // the input that crashed the loudness meter.
      final aligned = WavCodec.encodeMuLaw(
        _pcmAtOffset(loud, 0),
        sampleRate: 16000,
      );
      final misaligned = WavCodec.encodeMuLaw(
        _pcmAtOffset(loud, 5),
        sampleRate: 16000,
      );

      expect(misaligned, aligned);
    });
  });

  group('Pcm16FrameAligner', () {
    test('carries a split sample into the next chunk', () {
      // A PCM16 frame is two bytes. If a chunk ends mid-frame, dropping the
      // stray byte would shift every following sample and turn the rest of
      // the recording into noise.
      final aligner = Pcm16FrameAligner();
      final stream = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

      final first = aligner.align(Uint8List.sublistView(stream, 0, 3));
      expect(first, [1, 2], reason: 'byte 3 is half a sample, held back');
      expect(aligner.hasPartialFrame, isTrue);

      final second = aligner.align(Uint8List.sublistView(stream, 3, 8));
      expect(second, [3, 4, 5, 6, 7, 8], reason: 'held byte leads the next');
      expect(
        [...first, ...second],
        stream,
        reason: 'nothing lost or reordered',
      );
    });

    test('passes even-length chunks straight through', () {
      final aligner = Pcm16FrameAligner();
      final chunk = Uint8List.fromList([1, 2, 3, 4]);

      expect(
        aligner.align(chunk),
        same(chunk),
        reason: 'no copy in the common case',
      );
      expect(aligner.hasPartialFrame, isFalse);
    });

    test('loses nothing across a run of odd-length chunks', () {
      final aligner = Pcm16FrameAligner();
      final out = <int>[];
      var next = 0;

      for (var i = 0; i < 20; i++) {
        out.addAll(
          aligner.align(
            Uint8List.fromList(List.generate(3, (_) => next++ & 0xff)),
          ),
        );
      }

      // 60 bytes in; at most one is still held back, and the rest arrived in
      // order with correct frame boundaries.
      expect(out.length, anyOf(60, 59));
      expect(out, List.generate(out.length, (i) => i & 0xff));
    });

    test('a lone stray byte yields nothing until it is completed', () {
      final aligner = Pcm16FrameAligner();

      expect(aligner.align(Uint8List.fromList([9])), isEmpty);
      expect(aligner.align(Uint8List.fromList([10])), [9, 10]);
    });

    test('reset drops a held byte so a new capture starts clean', () {
      final aligner = Pcm16FrameAligner();
      aligner.align(Uint8List.fromList([9]));
      expect(aligner.hasPartialFrame, isTrue);

      aligner.reset();
      expect(aligner.hasPartialFrame, isFalse);
      expect(aligner.align(Uint8List.fromList([1, 2])), [1, 2]);
    });
  });
}
