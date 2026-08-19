import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:widget_overlay_outside/core/services/speech/wav_codec.dart';

/// Reads a little-endian uint32 from a WAV header field.
int _u32(Uint8List b, int offset) =>
    ByteData.sublistView(b).getUint32(offset, Endian.little);
int _u16(Uint8List b, int offset) =>
    ByteData.sublistView(b).getUint16(offset, Endian.little);
String _tag(Uint8List b, int offset) =>
    String.fromCharCodes(b.sublist(offset, offset + 4));

void main() {
  group('WavCodec.encode', () {
    final pcm = Uint8List.fromList(List.generate(1600, (i) => i % 256));
    final wav = WavCodec.encode(pcm, sampleRate: 16000);

    test('emits a well-formed RIFF/WAVE header', () {
      expect(_tag(wav, 0), 'RIFF');
      expect(_tag(wav, 8), 'WAVE');
      expect(_tag(wav, 12), 'fmt ');
      expect(_tag(wav, 36), 'data');
      expect(_u32(wav, 16), 16, reason: 'PCM fmt chunk size');
      expect(_u16(wav, 20), 1, reason: 'audio format 1 = PCM');
    });

    test('declares the format the recogniser and Gemini both expect', () {
      expect(_u16(wav, 22), 1, reason: 'mono');
      expect(_u32(wav, 24), 16000, reason: 'sample rate');
      expect(_u16(wav, 34), 16, reason: 'bits per sample');
      expect(_u32(wav, 28), 32000, reason: 'byte rate = 16000 * 1 * 2');
      expect(_u16(wav, 32), 2, reason: 'block align');
    });

    test('sizes match the payload, so players do not read past the end', () {
      expect(wav.length, WavCodec.headerBytes + pcm.length);
      expect(_u32(wav, 4), 36 + pcm.length, reason: 'RIFF chunk size');
      expect(_u32(wav, 40), pcm.length, reason: 'data chunk size');
    });

    test('preserves the samples byte for byte', () {
      expect(wav.sublist(WavCodec.headerBytes), pcm);
    });

    test('handles an empty payload without corrupting the header', () {
      final empty = WavCodec.encode(Uint8List(0), sampleRate: 16000);
      expect(empty.length, WavCodec.headerBytes);
      expect(_u32(empty, 40), 0);
    });
  });

  group('WavCodec.durationOf', () {
    test('derives seconds from byte length at 16 kHz mono', () {
      // 32 000 bytes per second: 16 000 samples x 2 bytes x 1 channel.
      expect(
        WavCodec.durationOf(32000, sampleRate: 16000),
        const Duration(seconds: 1),
      );
      expect(
        WavCodec.durationOf(96000, sampleRate: 16000),
        const Duration(seconds: 3),
      );
    });

    test('accounts for channel count', () {
      expect(
        WavCodec.durationOf(64000, sampleRate: 16000, numChannels: 2),
        const Duration(seconds: 1),
      );
    });

    test('returns zero for empty audio rather than dividing by nothing', () {
      expect(WavCodec.durationOf(0, sampleRate: 16000), Duration.zero);
    });
  });

  group('WavCodec.encodeMuLaw', () {
    // A speech-like sweep rather than a constant tone, so the companding is
    // exercised across its whole dynamic range.
    final samples = Int16List(4000);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = (32767 * math.sin(i * 0.05) * (i / samples.length)).round();
    }
    final pcm = samples.buffer.asUint8List();
    final wav = WavCodec.encodeMuLaw(pcm, sampleRate: 16000);

    test('halves the payload, which is the entire point', () {
      expect(wav.length - WavCodec.muLawHeaderBytes, pcm.length ~/ 2);
    });

    test('declares the companded format the spec requires', () {
      expect(_tag(wav, 0), 'RIFF');
      expect(_tag(wav, 12), 'fmt ');
      expect(_u32(wav, 16), 18, reason: 'non-PCM fmt chunks carry cbSize');
      expect(_u16(wav, 20), 7, reason: 'WAVE_FORMAT_MULAW');
      expect(_u16(wav, 22), 1, reason: 'mono');
      expect(_u32(wav, 24), 16000);
      expect(_u16(wav, 32), 1, reason: 'block align: one byte per sample');
      expect(_u16(wav, 34), 8, reason: 'bits per sample');
      expect(_u16(wav, 36), 0, reason: 'cbSize');
    });

    test('emits the fact chunk non-PCM formats require', () {
      expect(_tag(wav, 38), 'fact');
      expect(_u32(wav, 42), 4);
      expect(_u32(wav, 46), samples.length, reason: 'frames per channel');
    });

    test('sizes are self-consistent', () {
      expect(_tag(wav, 50), 'data');
      expect(_u32(wav, 54), samples.length);
      expect(
        _u32(wav, 4),
        WavCodec.muLawHeaderBytes - 8 + samples.length,
        reason: 'RIFF chunk size',
      );
      expect(wav.length, WavCodec.muLawHeaderBytes + samples.length);
    });

    test('round-trips speech-level audio within companding tolerance', () {
      // µ-law is lossy by design: error grows with amplitude but stays a
      // roughly constant *fraction* of it. Verified against the decoder so a
      // broken exponent table cannot pass by agreeing with itself.
      var worstRelative = 0.0;
      for (final original in samples) {
        final decoded = WavCodec.decodeMuLawSample(
          WavCodec.encodeMuLawSample(original),
        );
        final magnitude = original.abs();
        // Near silence is covered by the absolute-error test below.
        if (magnitude < 256) {
          continue;
        }
        final relative = (decoded - original).abs() / magnitude;
        if (relative > worstRelative) worstRelative = relative;
      }
      expect(worstRelative, lessThan(0.08));
    });

    test('keeps quiet passages quiet', () {
      for (var v = -255; v <= 255; v += 17) {
        final decoded = WavCodec.decodeMuLawSample(
          WavCodec.encodeMuLawSample(v),
        );
        expect((decoded - v).abs(), lessThanOrEqualTo(16));
      }
    });

    test('preserves sign and clamps beyond full scale', () {
      expect(
        WavCodec.decodeMuLawSample(WavCodec.encodeMuLawSample(0)).abs(),
        lessThanOrEqualTo(8),
      );
      expect(
        WavCodec.decodeMuLawSample(WavCodec.encodeMuLawSample(20000)),
        greaterThan(0),
      );
      expect(
        WavCodec.decodeMuLawSample(WavCodec.encodeMuLawSample(-20000)),
        lessThan(0),
      );
      // -32768 has no positive counterpart; it must not wrap to a positive.
      expect(
        WavCodec.decodeMuLawSample(WavCodec.encodeMuLawSample(-32768)),
        lessThan(0),
      );
    });

    test('every code is a byte', () {
      for (var v = -32768; v <= 32767; v += 7) {
        final code = WavCodec.encodeMuLawSample(v);
        expect(code, inInclusiveRange(0, 255));
      }
    });
  });
}
