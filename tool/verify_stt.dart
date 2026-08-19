// One-off harness: drives the real Moonshine pipeline on a real device.
//
// Unit tests cover the segmenter against a fake recogniser; this covers the
// half they cannot — the LiteRT runtime, the model download, and whether the
// windows we cut actually reassemble into coherent text.
//
//   flutter run -d <device> -t tool/verify_stt.dart \
//     --dart-define=WAV=/absolute/path/to/16k-mono.wav
//
// Generate a sample on macOS with:
//   say -o /tmp/s.aiff "Um, so basically the main challenge was scaling."
//   afconvert -f WAVE -d LEI16@16000 -c 1 /tmp/s.aiff /tmp/s.wav
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:widget_overlay_outside/core/services/speech/gemma_speech_service.dart';
import 'package:widget_overlay_outside/core/services/speech/speech_recognition_service.dart';

const _expected =
    'Um, so basically, I think the main challenge was, you know, '
    'scaling the database under load. Uh, we ended up sharding it by tenant.';

// print(), not stdout: only print/debugPrint is forwarded to the
// `flutter run` console on iOS and Android.
// ignore: avoid_print
void say(String line) => print('[VERIFY] $line');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final service = GemmaSpeechService();
  service.stateStream.listen((s) {
    if (s.status == SpeechEngineStatus.downloading) {
      say('downloading ${(s.progress * 100).toStringAsFixed(0)}%');
    } else {
      say('state: ${s.status.name}${s.error == null ? '' : ' — ${s.error}'}');
    }
  });

  final startedAt = DateTime.now();
  say('preparing engine…');
  final ready = await service.prepare();
  say('prepare: $ready in ${DateTime.now().difference(startedAt).inSeconds}s');

  if (!ready) {
    say('RESULT: FAILED — engine did not become ready');
    exit(1);
  }

  // Read from a host path rather than a bundled asset, so no fixture rides
  // along in every production build.
  const wavPath = String.fromEnvironment('WAV');
  if (wavPath.isEmpty) {
    say('RESULT: FAILED — pass --dart-define=WAV=/path/to/16k-mono.wav');
    exit(64);
  }
  // Real speech, 16 kHz mono, header stripped to raw samples.
  final wav = File(wavPath).readAsBytesSync();
  final pcm = Uint8List.sublistView(wav, 44);
  say('audio: ${(pcm.length / 32000).toStringAsFixed(1)}s');

  // Feed it the way the microphone does, in small chunks.
  final mic = StreamController<Uint8List>.broadcast();
  final updates = <String>[];
  await service.listen(mic.stream, updates.add);

  final decodeStart = DateTime.now();
  const chunk = 1024;
  for (var i = 0; i < pcm.length; i += chunk) {
    final end = (i + chunk < pcm.length) ? i + chunk : pcm.length;
    mic.add(Uint8List.sublistView(pcm, i, end));
    await Future<void>.delayed(Duration.zero);
  }

  final transcript = await service.finish();
  final elapsed = DateTime.now().difference(decodeStart);

  say('interim updates: ${updates.length}');
  say(
    'decode wall time: ${elapsed.inMilliseconds}ms '
    'for ${(pcm.length / 32000).toStringAsFixed(1)}s of audio',
  );
  say('EXPECTED: $_expected');
  say('GOT     : $transcript');

  final words = transcript.toLowerCase().split(RegExp(r'[^a-z]+'))
    ..removeWhere((w) => w.isEmpty);
  final wanted = ['challenge', 'scaling', 'database', 'sharding', 'tenant'];
  final hits = wanted.where(words.contains).toList();
  say('keyword recall: ${hits.length}/${wanted.length} $hits');

  await service.dispose();
  await mic.close();

  say(hits.length >= 4 ? 'RESULT: PASS' : 'RESULT: WEAK');
  exit(hits.length >= 4 ? 0 : 2);
}
