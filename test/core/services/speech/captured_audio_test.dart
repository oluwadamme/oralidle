import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:widget_overlay_outside/core/services/speech/audio_capture_service.dart';
import 'package:widget_overlay_outside/core/services/speech/wav_codec.dart';

int _u16(Uint8List b, int o) =>
    ByteData.sublistView(b).getUint16(o, Endian.little);

void main() {
  CapturedAudio audioOf(int seconds) => CapturedAudio(
    pcm: Uint8List(AudioCaptureService.sampleRate * 2 * seconds),
    sampleRate: AudioCaptureService.sampleRate,
  );

  test('duration comes from the sample count, not a wall clock', () {
    expect(audioOf(3).duration, const Duration(seconds: 3));
  });

  test('playback keeps linear PCM, which every player can decode', () {
    final bytes = audioOf(1).playbackBytes;
    expect(_u16(bytes, 20), 1, reason: 'WAVE_FORMAT_PCM');
    expect(_u16(bytes, 34), 16, reason: 'bits per sample');
  });

  test('upload is companded, halving what crosses the network', () {
    final audio = audioOf(1);
    expect(_u16(audio.uploadBytes, 20), 7, reason: 'WAVE_FORMAT_MULAW');
    expect(
      audio.uploadBytes.length,
      lessThan(audio.playbackBytes.length * 0.55),
    );
  });

  test('a two-minute answer stays within the old AAC upload budget', () {
    // The pipeline this replaced sent ~1.83 MB of AAC for two minutes.
    // Regressing past that is what companding exists to prevent.
    final upload = audioOf(120).uploadBytes.length;
    expect(upload, lessThan(2 * 1024 * 1024));
  });

  test('both forms are WAV, so one MIME type is honest', () {
    expect(audioOf(1).mimeType, WavCodec.mimeType);
  });

  test('a burst too short to hold speech reports empty', () {
    expect(
      CapturedAudio(pcm: Uint8List(800), sampleRate: 16000).isEmpty,
      isTrue,
    );
    expect(audioOf(1).isEmpty, isFalse);
  });
}
