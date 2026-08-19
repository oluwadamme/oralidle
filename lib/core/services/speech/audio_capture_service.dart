import 'dart:async';
import 'dart:developer' show log;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:record/record.dart';

import 'pcm16_view.dart';
import 'wav_codec.dart';

/// The result of one capture session.
///
/// Holds the raw samples and derives the two forms we need from them, because
/// playback and upload want different trade-offs:
///
/// * **Playback** is local, so it costs nothing to be faithful — linear PCM.
/// * **Upload** crosses the network on every answer, so it is companded to
///   µ-law: half the bytes for a transcript verified to come back identical.
///   That keeps an answer the same size it was under the AAC encoder this
///   pipeline replaced.
///
/// Kept in memory rather than written to disk: at 16 kHz mono a two-minute
/// answer is under 4 MB, and one representation then works for playback, for
/// the Gemini upload and for web, where there is no filesystem to write to.
class CapturedAudio {
  /// Raw little-endian 16-bit samples, as captured.
  final Uint8List pcm;
  final int sampleRate;
  final int numChannels;

  CapturedAudio({
    required this.pcm,
    required this.sampleRate,
    this.numChannels = 1,
  });

  /// Shorter than this and the clip cannot hold speech worth sending.
  static const _minMeaningfulBytes = 1600; // 50 ms at 16 kHz mono

  Duration get duration => WavCodec.durationOf(
    pcm.length,
    sampleRate: sampleRate,
    numChannels: numChannels,
  );

  /// Faithful linear-PCM WAV, for the in-app player.
  late final Uint8List playbackBytes = WavCodec.encode(
    pcm,
    sampleRate: sampleRate,
    numChannels: numChannels,
  );

  /// Companded µ-law WAV, for sending to Gemini.
  late final Uint8List uploadBytes = WavCodec.encodeMuLaw(
    pcm,
    sampleRate: sampleRate,
    numChannels: numChannels,
  );

  /// Both forms are WAV containers, so one MIME type covers them.
  String get mimeType => WavCodec.mimeType;

  bool get isEmpty => pcm.length < _minMeaningfulBytes;
}

/// The single owner of the microphone.
///
/// Everything that needs audio — the WAV we send to Gemini, the live
/// on-device transcript, the waveform meter — is fed from this one capture.
/// Nothing else in the app may open the microphone: running two capture
/// clients at once is a hard conflict on both iOS (a second client
/// reconfigures the shared `AVAudioSession`) and Android (`SpeechRecognizer`
/// holds an exclusive `AudioRecord`), and produces silence or an outright
/// failure in whichever client loses the race.
///
/// The stream is raw little-endian 16-bit PCM at [sampleRate] Hz, mono —
/// which is both what `SpeechRecognizer.transcribe` expects and what makes
/// the smallest useful upload. On web `record` resamples to the requested
/// rate inside its audio worklet, so the format is identical on every
/// platform.
class AudioCaptureService {
  /// 16 kHz mono is the format `flutter_gemma_speech` requires, and is ample
  /// for speech — 44.1 kHz would triple the upload for no accuracy gain.
  static const sampleRate = 16000;
  static const numChannels = 1;

  /// Smaller than the 2048-frame default so the waveform and the recogniser
  /// react promptly rather than in visible steps.
  static const _streamBufferSize = 1024;

  /// Upper bound on waiting for the capture stream to close on stop.
  /// Generous next to the ~32 ms a buffer represents, but short enough that a
  /// misbehaving platform cannot stall the UI.
  static const _drainTimeout = Duration(milliseconds: 750);

  final AudioRecorder _recorder = AudioRecorder();

  // Created once and closed only in dispose(), so consumers can subscribe
  // before capture starts and stay subscribed across start/stop cycles.
  final _pcmController = StreamController<Uint8List>.broadcast();
  final _amplitudeController = StreamController<double>.broadcast();

  StreamSubscription<Uint8List>? _sub;
  BytesBuilder? _buffer;
  bool _capturing = false;
  bool _disposed = false;

  /// Holds back half a frame when a chunk arrives with an odd length, so the
  /// PCM handed downstream is always a whole number of samples.
  final _aligner = Pcm16FrameAligner();

  /// Completes when the platform stream closes, which is the only reliable
  /// signal that every captured chunk has been delivered. `record` forwards
  /// data only while a listener is attached, so cancelling our subscription
  /// before the stream closes silently drops whatever was still in flight —
  /// the tail of the recording, where the last word is.
  Completer<void>? _streamDone;

  bool get isCapturing => _capturing;

  /// Raw PCM chunks, broadcast so both the recogniser and any meter can
  /// listen without either starving the other.
  Stream<Uint8List> get pcmStream => _pcmController.stream;

  /// Normalised 0..1 loudness per chunk, derived from the PCM we already
  /// have. Computing it here avoids polling `onAmplitudeChanged`, which is
  /// not implemented for stream captures on every platform.
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  /// Checks — and by default requests — microphone permission.
  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      log('AudioCaptureService: permission check failed: $e');
      return false;
    }
  }

  /// Opens the microphone. Returns false if permission was denied or the
  /// platform refused to start; callers treat that as "no audio this
  /// session" rather than a fatal error.
  Future<bool> start() async {
    if (_capturing || _disposed) return _capturing;

    try {
      if (!await _recorder.hasPermission()) {
        log('AudioCaptureService: microphone permission denied');
        return false;
      }

      final buffer = BytesBuilder(copy: false);

      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: numChannels,
          // Speech capture in a room with a speaker playing questions back —
          // let the platform clean up what it can before we ever see it.
          echoCancel: true,
          noiseSuppress: true,
          autoGain: true,
          streamBufferSize: _streamBufferSize,
        ),
      );

      final done = Completer<void>();

      _aligner.reset();
      _buffer = buffer;
      _streamDone = done;
      _capturing = true;

      _sub = stream.listen(
        (chunk) {
          final aligned = _aligner.align(chunk);
          if (aligned.isEmpty) return;

          buffer.add(aligned);
          if (!_pcmController.isClosed) _pcmController.add(aligned);
          if (!_amplitudeController.isClosed) {
            _amplitudeController.add(normalisedLoudness(aligned));
          }
        },
        onError: (Object e) => log('AudioCaptureService: stream error: $e'),
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: false,
      );

      return true;
    } catch (e) {
      log('AudioCaptureService: start failed: $e');
      await _teardown(drain: false);
      return false;
    }
  }

  /// Closes the microphone and returns everything captured as a WAV clip.
  ///
  /// Returns null when nothing was captured.
  Future<CapturedAudio?> stop() async {
    if (!_capturing) return null;

    final buffer = _buffer;
    await _teardown(drain: true);

    final pcm = buffer?.takeBytes();
    if (pcm == null || pcm.isEmpty) return null;

    return CapturedAudio(
      pcm: pcm,
      sampleRate: sampleRate,
      numChannels: numChannels,
    );
  }

  /// Closes the microphone and discards the audio.
  ///
  /// Skips the drain — there is no point waiting for chunks we are about to
  /// throw away.
  Future<void> cancel() => _teardown(drain: false);

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _teardown(drain: false);
    await _pcmController.close();
    await _amplitudeController.close();
    try {
      await _recorder.dispose();
    } catch (e) {
      log('AudioCaptureService: dispose failed: $e');
    }
  }

  /// Releases the microphone.
  ///
  /// Ordering matters. The recorder is stopped *first*, which closes the
  /// stream; only then is our subscription cancelled. Doing it the other way
  /// round detaches the listener while chunks are still being forwarded, and
  /// `record` drops them — clipping the end of every recording.
  ///
  /// With [drain] the stop waits for the stream's done event so those final
  /// chunks reach the buffer. The wait is bounded: a platform that never
  /// closes the stream must not hang the UI, and a slightly clipped recording
  /// beats a stuck screen.
  Future<void> _teardown({required bool drain}) async {
    _capturing = false;
    _aligner.reset();

    final done = _streamDone;
    _streamDone = null;

    try {
      // `record` closes the stream from inside stop(); its own docs say to
      // rely on the close event to know the data is complete.
      await _recorder.stop();
    } catch (e) {
      log('AudioCaptureService: recorder stop failed: $e');
      // stop() may have thrown before releasing the device, which would leave
      // the microphone indicator lit. cancel() is the harder reset.
      try {
        await _recorder.cancel();
      } catch (e2) {
        log('AudioCaptureService: recorder cancel also failed: $e2');
      }
      // The stream may never close now, so do not wait on it.
      if (done != null && !done.isCompleted) done.complete();
    }

    if (drain && done != null) {
      try {
        await done.future.timeout(_drainTimeout);
      } on TimeoutException {
        log(
          'AudioCaptureService: stream did not close within '
          '${_drainTimeout.inMilliseconds}ms; tail may be clipped',
        );
      }
    }

    await _sub?.cancel();
    _sub = null;

    // Settle the meter so a stale level is not left on screen.
    if (!_amplitudeController.isClosed) _amplitudeController.add(0);
    _buffer = null;
  }

  /// RMS of a PCM16 chunk mapped onto a 0..1 scale via dBFS.
  ///
  /// A -50 dBFS floor keeps room tone near zero while leaving normal speech
  /// (roughly -30 to -10 dBFS) spread across most of the range, which is what
  /// makes the waveform look responsive rather than pinned.
  static double normalisedLoudness(Uint8List pcm16) {
    if (pcm16.length < 2) return 0;

    // Pcm16View, not a typed-list view: chunks are not guaranteed to start on
    // an even byte offset and the aligned readers throw when they do not.
    final samples = Pcm16View(pcm16);
    if (samples.isEmpty) return 0;

    var sumSquares = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final normalised = samples.normalised(i);
      sumSquares += normalised * normalised;
    }

    final rms = math.sqrt(sumSquares / samples.length);
    if (rms <= 0) return 0;

    const floorDb = -50.0;
    final db = 20 * (math.log(rms) / math.ln10);
    return (1 - (db / floorDb)).clamp(0.0, 1.0);
  }
}
