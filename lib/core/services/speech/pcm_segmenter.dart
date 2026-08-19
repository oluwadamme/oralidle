import 'dart:typed_data';

import 'audio_capture_service.dart';

/// Slices a continuous PCM stream into windows a fixed-window ASR model can
/// actually see.
///
/// Moonshine-tiny reads exactly 5 seconds per call and **silently discards**
/// anything beyond that — a 90-second answer handed over whole comes back as
/// its first five seconds with no error raised. This class exists so that
/// truncation can never happen: audio is cut into windows below the model's
/// limit, preferring the pauses between phrases so words are not split.
///
/// Pure and synchronous, so the segmentation can be tested directly rather
/// than only observed through a model's output.
class PcmSegmenter {
  /// Hard ceiling on a window. Must stay under the model's own window.
  final int maxWindowBytes;

  /// A window with less voiced audio than this is not worth a decode pass.
  final int minVoicedBytes;

  /// Trailing quiet this long is read as a phrase boundary.
  final int silenceHoldBytes;

  /// Chunk loudness below this counts as silence. Above typical room tone,
  /// well below speech.
  final double silenceThreshold;

  /// When forced to cut mid-speech, how far back to look for a quiet spot.
  final int cutSearchBytes;

  /// Granularity of that search.
  final int cutFrameBytes;

  PcmSegmenter({
    required this.maxWindowBytes,
    required this.minVoicedBytes,
    required this.silenceHoldBytes,
    this.silenceThreshold = 0.05,
    this.cutSearchBytes = 32000,
    this.cutFrameBytes = 640,
  });

  final _buffer = BytesBuilder(copy: false);
  int _voicedBytes = 0;
  int _trailingSilenceBytes = 0;

  int get bufferedBytes => _buffer.length;
  bool get hasSpeech => _voicedBytes >= minVoicedBytes;

  /// Feeds one chunk of PCM and returns any windows that are now ready.
  ///
  /// Usually empty — windows close at pauses, or when the size limit is hit.
  List<Uint8List> add(Uint8List chunk) {
    if (chunk.isEmpty) return const [];

    _buffer.add(chunk);

    if (AudioCaptureService.normalisedLoudness(chunk) >= silenceThreshold) {
      _voicedBytes += chunk.length;
      _trailingSilenceBytes = 0;
    } else {
      _trailingSilenceBytes += chunk.length;
    }

    final ready = <Uint8List>[];

    // A loop rather than a single check: a chunk larger than the window would
    // otherwise leave the excess buffered indefinitely.
    while (_buffer.length >= maxWindowBytes) {
      final window = _closeWindow(atNaturalPause: false);
      if (window != null) ready.add(window);
    }

    if (_trailingSilenceBytes >= silenceHoldBytes) {
      if (hasSpeech) {
        final window = _closeWindow(atNaturalPause: true);
        if (window != null) ready.add(window);
      } else {
        // Room tone only — drop it rather than spend a decode pass turning
        // silence into hallucinated words.
        reset();
      }
    }

    return ready;
  }

  /// Returns whatever is still buffered, if it holds speech. Call at the end
  /// of a recording so the final phrase is not lost.
  Uint8List? flush() {
    final window = hasSpeech ? _buffer.takeBytes() : null;
    reset();
    return window;
  }

  void reset() {
    _buffer.clear();
    _voicedBytes = 0;
    _trailingSilenceBytes = 0;
  }

  /// Closes the current window.
  ///
  /// At a pause the whole buffer goes. When forced by the size limit we cut
  /// at the quietest frame near the end instead and carry the remainder into
  /// the next window, so a word straddling the boundary is far less likely to
  /// be sliced in half.
  Uint8List? _closeWindow({required bool atNaturalPause}) {
    final pending = _buffer.takeBytes();
    final hadSpeech = _voicedBytes > 0;
    reset();

    if (pending.isEmpty) return null;

    if (atNaturalPause) return pending;

    // Forced by the size limit, so the window must not exceed it: the search
    // for a quiet spot happens just *before* the limit, not at the end of
    // whatever happens to be buffered. Searching from the end is how a window
    // ends up longer than the model can read — the exact silent-truncation
    // failure this class exists to prevent.
    final limit = pending.length < maxWindowBytes
        ? pending.length
        : maxWindowBytes;

    final cut = quietestCut(
      pending,
      searchBytes: cutSearchBytes,
      frameBytes: cutFrameBytes,
      limit: limit,
    );

    if (cut < pending.length) {
      final remainder = Uint8List.sublistView(pending, cut);
      _buffer.add(remainder);
      // Measure the carried tail rather than assuming it is all speech.
      // Assuming would let silence masquerade as voiced audio and get sent
      // for decoding on the following window.
      _voicedBytes = _voicedBytesIn(remainder);
      _trailingSilenceBytes = _trailingSilenceIn(remainder);
    }

    // A window holding nothing but silence is not worth a decode pass, even
    // when it was the size limit that closed it.
    if (!hadSpeech) return null;

    return Uint8List.sublistView(pending, 0, cut);
  }

  /// Bytes of [pcm] that carry speech, measured in [cutFrameBytes] frames.
  int _voicedBytesIn(Uint8List pcm) {
    var voiced = 0;
    for (
      var offset = 0;
      offset + cutFrameBytes <= pcm.length;
      offset += cutFrameBytes
    ) {
      final frame = Uint8List.sublistView(pcm, offset, offset + cutFrameBytes);
      if (AudioCaptureService.normalisedLoudness(frame) >= silenceThreshold) {
        voiced += cutFrameBytes;
      }
    }
    return voiced;
  }

  /// Length of the run of silence at the end of [pcm]. Carried across a cut so
  /// a pause spanning the boundary is still recognised as one pause.
  int _trailingSilenceIn(Uint8List pcm) {
    var silence = 0;
    for (
      var offset = pcm.length - cutFrameBytes;
      offset >= 0;
      offset -= cutFrameBytes
    ) {
      final frame = Uint8List.sublistView(pcm, offset, offset + cutFrameBytes);
      if (AudioCaptureService.normalisedLoudness(frame) >= silenceThreshold) {
        break;
      }
      silence += cutFrameBytes;
    }
    return silence;
  }

  /// Byte offset of the quietest frame in the [searchBytes] leading up to
  /// [limit], aligned to a 16-bit sample boundary.
  ///
  /// [limit] defaults to the end of [pcm]; pass the window size to guarantee
  /// the result never exceeds it. Returns [limit] when the region is too
  /// short to search, meaning "cut at the limit".
  static int quietestCut(
    Uint8List pcm, {
    required int searchBytes,
    required int frameBytes,
    int? limit,
  }) {
    final end = (limit ?? pcm.length).clamp(0, pcm.length);
    final searchStart = end - searchBytes;
    if (searchStart <= 0) return end;

    var bestOffset = end;
    var bestLoudness = double.infinity;

    for (
      var offset = searchStart;
      offset + frameBytes <= end;
      offset += frameBytes
    ) {
      final frame = Uint8List.sublistView(pcm, offset, offset + frameBytes);
      final loudness = AudioCaptureService.normalisedLoudness(frame);
      if (loudness < bestLoudness) {
        bestLoudness = loudness;
        bestOffset = offset + frameBytes ~/ 2;
      }
    }

    // Keep the offset even so it never splits a 16-bit sample.
    return bestOffset - (bestOffset % 2);
  }
}
