import 'dart:typed_data';

/// Reads little-endian 16-bit PCM samples out of a byte buffer that may not
/// be 2-byte aligned.
///
/// Both `Int16List.sublistView(bytes)` and `bytes.buffer.asInt16List(...)`
/// require the view to start on an even byte offset, and throw
/// `RangeError: Offset (5) must be a multiple of BYTES_PER_ELEMENT (2)`
/// when it does not. Nothing guarantees that alignment here: a microphone
/// chunk can arrive as a view at an arbitrary offset into a larger platform
/// buffer, and slicing it further only carries that offset along.
///
/// [ByteData.getInt16] has no alignment requirement, so every read of
/// captured audio goes through this instead. An odd trailing byte is ignored
/// — a half sample carries no information.
///
/// This is a view, not a copy: constructing one over a two-minute recording
/// costs nothing.
class Pcm16View {
  Pcm16View(Uint8List bytes)
    : _data = ByteData.sublistView(bytes),
      length = bytes.lengthInBytes ~/ 2;

  final ByteData _data;

  /// Number of whole samples available.
  final int length;

  bool get isEmpty => length == 0;

  /// Sample [index] as a signed 16-bit value.
  int operator [](int index) => _data.getInt16(index * 2, Endian.little);

  /// Sample [index] scaled to -1.0..1.0.
  double normalised(int index) => this[index] / 32768.0;
}

/// Keeps a chunked byte stream aligned to whole PCM16 frames.
///
/// A frame is two bytes. If a platform ever hands over a chunk that ends
/// mid-frame, dropping the stray byte would shift every subsequent sample by
/// one and turn the rest of the recording into noise. This holds that byte
/// back and prepends it to the next chunk, so the stream a consumer sees is
/// always a whole number of samples with nothing lost or reordered.
class Pcm16FrameAligner {
  int? _carry;

  /// True while half a frame is being held back.
  bool get hasPartialFrame => _carry != null;

  /// Returns [chunk] trimmed to whole frames, led by any byte carried over.
  /// May be empty when a single stray byte is all there is.
  Uint8List align(Uint8List chunk) {
    final carry = _carry;
    _carry = null;

    var body = chunk;
    if (carry != null) {
      body = Uint8List(chunk.length + 1)
        ..[0] = carry
        ..setRange(1, chunk.length + 1, chunk);
    }

    if (body.length.isOdd) {
      _carry = body[body.length - 1];
      body = Uint8List.sublistView(body, 0, body.length - 1);
    }

    return body;
  }

  /// Forgets any held byte. Call when starting a new capture: a leftover from
  /// the previous one would corrupt the first frame of the next.
  void reset() => _carry = null;
}
