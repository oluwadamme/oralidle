import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the invariant the whole audio pipeline rests on.
///
/// The bug this codebase was built to fix was two microphone clients running
/// at once: `speech_to_text` and `record` both opened the device, and on both
/// iOS and Android whichever lost the race produced silence. Nothing in the
/// type system prevents someone reintroducing that, so it is asserted here.
///
/// Source-level checks are blunt, but this invariant is architectural rather
/// than behavioural — there is no runtime state that can express "only one
/// component may ever open the microphone".
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('lib is not empty (the scan below would pass vacuously)', () {
    expect(dartFiles.length, greaterThan(20));
  });

  test('only AudioCaptureService constructs a recorder', () {
    final offenders = <String>[];
    for (final file in dartFiles) {
      if (file.path.endsWith('audio_capture_service.dart')) continue;
      if (file.readAsStringSync().contains('AudioRecorder(')) {
        offenders.add(file.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A second microphone client silently breaks capture on iOS and '
          'Android. Feed AudioCaptureService.pcmStream instead.',
    );
  });

  test('no second speech engine opens the microphone behind our back', () {
    // `speech_to_text` runs SFSpeechRecognizer / SpeechRecognizer, both of
    // which take the device for themselves.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec.contains('speech_to_text'),
      isFalse,
      reason:
          'speech_to_text opens the microphone itself and cannot coexist '
          'with record. On-device transcription goes through '
          'flutter_gemma_speech, which consumes PCM we already captured.',
    );
  });

  test('the recogniser never touches the recorder package', () {
    // flutter_gemma_speech deliberately owns no audio I/O; if the recogniser
    // started capturing for itself the invariant would be gone.
    final recogniser = File(
      'lib/core/services/speech/gemma_speech_service.dart',
    ).readAsStringSync();

    expect(recogniser.contains("package:record/"), isFalse);
    expect(recogniser.contains('AudioRecorder'), isFalse);
  });
}
