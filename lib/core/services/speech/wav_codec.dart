import 'dart:typed_data';

/// Minimal RIFF/WAVE encoder for 16-bit little-endian PCM.
///
/// Pure Dart with no platform dependencies, so the same code produces the
/// bytes we hand to Gemini on mobile, desktop and web alike.  We build the
/// container ourselves rather than asking `record` for a `.wav` file because
/// the capture pipeline streams raw PCM (see [AudioCaptureService]) — the
/// stream is the single source of truth and the file is derived from it.
class WavCodec {
  const WavCodec._();

  /// Canonical WAV header size for PCM (no extension chunks).
  static const headerBytes = 44;

  /// Header size for the companded form: a 18-byte `fmt ` chunk (non-PCM
  /// formats must carry the `cbSize` field) plus a 12-byte `fact` chunk.
  static const muLawHeaderBytes = 58;

  static const mimeType = 'audio/wav';

  /// WAVE format tags.
  static const _formatPcm = 1;
  static const _formatMuLaw = 7;

  /// Wraps [pcm16] (raw little-endian 16-bit samples) in a WAV container.
  ///
  /// Linear PCM: the faithful form, used for local playback where size costs
  /// nothing. See [encodeMuLaw] for the form we upload.
  static Uint8List encode(
    Uint8List pcm16, {
    required int sampleRate,
    int numChannels = 1,
  }) {
    const bitsPerSample = 16;
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;

    final out = Uint8List(headerBytes + pcm16.length);
    final view = ByteData.view(out.buffer);

    // RIFF chunk descriptor
    _ascii(out, 0, 'RIFF');
    view.setUint32(4, 36 + pcm16.length, Endian.little); // chunk size
    _ascii(out, 8, 'WAVE');

    // "fmt " sub-chunk
    _ascii(out, 12, 'fmt ');
    view.setUint32(16, 16, Endian.little); // PCM sub-chunk size
    view.setUint16(20, _formatPcm, Endian.little);
    view.setUint16(22, numChannels, Endian.little);
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(28, byteRate, Endian.little);
    view.setUint16(32, blockAlign, Endian.little);
    view.setUint16(34, bitsPerSample, Endian.little);

    // "data" sub-chunk
    _ascii(out, 36, 'data');
    view.setUint32(40, pcm16.length, Endian.little);
    out.setRange(headerBytes, out.length, pcm16);

    return out;
  }

  /// Wraps [pcm16] in a WAV container using G.711 µ-law companding.
  ///
  /// Halves the payload — 8 bits per sample instead of 16 — which is what
  /// keeps an uploaded answer the same size it was under the AAC encoder this
  /// pipeline replaced. µ-law is logarithmic rather than linear, so it spends
  /// its smaller budget where speech actually lives; the result is telephony
  /// grade at 16 kHz, ample for transcription and for judging pace and
  /// delivery.
  ///
  /// Emits the layout the specification requires for non-PCM data: an
  /// 18-byte `fmt ` chunk carrying `cbSize`, followed by a `fact` chunk with
  /// the sample count. Some decoders tolerate the shorter PCM-style header;
  /// relying on that would be gambling the transcript on it.
  static Uint8List encodeMuLaw(
    Uint8List pcm16, {
    required int sampleRate,
    int numChannels = 1,
  }) {
    final samples = Int16List.sublistView(pcm16);
    final companded = Uint8List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      companded[i] = encodeMuLawSample(samples[i]);
    }

    const bitsPerSample = 8;
    final blockAlign = numChannels; // 1 byte per sample per channel
    final byteRate = sampleRate * blockAlign;
    final frames = numChannels == 0 ? 0 : companded.length ~/ numChannels;

    final out = Uint8List(muLawHeaderBytes + companded.length);
    final view = ByteData.view(out.buffer);

    _ascii(out, 0, 'RIFF');
    view.setUint32(4, muLawHeaderBytes - 8 + companded.length, Endian.little);
    _ascii(out, 8, 'WAVE');

    // "fmt " — 18 bytes: the 16 PCM fields plus cbSize.
    _ascii(out, 12, 'fmt ');
    view.setUint32(16, 18, Endian.little);
    view.setUint16(20, _formatMuLaw, Endian.little);
    view.setUint16(22, numChannels, Endian.little);
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(28, byteRate, Endian.little);
    view.setUint16(32, blockAlign, Endian.little);
    view.setUint16(34, bitsPerSample, Endian.little);
    view.setUint16(36, 0, Endian.little); // cbSize: no extra format bytes

    // "fact" — required for non-PCM: frames per channel.
    _ascii(out, 38, 'fact');
    view.setUint32(42, 4, Endian.little);
    view.setUint32(46, frames, Endian.little);

    _ascii(out, 50, 'data');
    view.setUint32(54, companded.length, Endian.little);
    out.setRange(muLawHeaderBytes, out.length, companded);

    return out;
  }

  /// One linear 16-bit sample to its 8-bit µ-law code (ITU-T G.711).
  static int encodeMuLawSample(int sample) {
    const bias = 0x84;
    const clip = 32635;

    var sign = 0;
    var value = sample;
    if (value < 0) {
      value = -value;
      sign = 0x80;
    }
    if (value > clip) value = clip;
    value += bias;

    final exponent = _muLawExponent[(value >> 7) & 0xFF];
    final mantissa = (value >> (exponent + 3)) & 0x0F;
    return ~(sign | (exponent << 4) | mantissa) & 0xFF;
  }

  /// One 8-bit µ-law code back to linear 16-bit. Present so the encoder can
  /// be checked against a round trip rather than against itself.
  static int decodeMuLawSample(int code) {
    final inverted = ~code & 0xFF;
    final sign = inverted & 0x80;
    final exponent = (inverted >> 4) & 0x07;
    final mantissa = inverted & 0x0F;

    var value = ((mantissa << 3) + 0x84) << exponent;
    value -= 0x84;
    return sign != 0 ? -value : value;
  }

  /// Segment exponent per G.711, indexed by the top bits of the biased
  /// magnitude.
  static const _muLawExponent = <int>[
    0, 0, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, //
    4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
    6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
    6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
    6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
    6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
  ];

  /// Duration of a raw PCM buffer, derived from its byte length.
  static Duration durationOf(
    int pcmByteLength, {
    required int sampleRate,
    int numChannels = 1,
  }) {
    final bytesPerSecond = sampleRate * numChannels * 2;
    if (bytesPerSecond == 0) return Duration.zero;
    return Duration(
      microseconds:
          (pcmByteLength / bytesPerSecond * Duration.microsecondsPerSecond)
              .round(),
    );
  }

  static void _ascii(Uint8List target, int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      target[offset + i] = value.codeUnitAt(i);
    }
  }
}
