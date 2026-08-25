// One-off check: does Gemini transcribe the companded WAV we upload as well
// as it transcribes linear PCM?
//
// Halving the upload is only worth doing if the transcript survives it, and
// that is not something to take on trust from a format table. Run against a
// real 16 kHz mono PCM WAV:
//
//   dart run tool/verify_audio_format.dart <path-to-16k-mono.wav>
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:widget_overlay_outside/core/services/speech/wav_codec.dart';

const _model = 'gemini-2.5-flash-lite';
const _url =
    'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

const _prompt = '''
Transcribe this audio strictly verbatim. Keep every filler and hesitation
actually spoken (um, uh, er, like, you know). Return ONLY the transcript text,
with no commentary and no formatting.
''';

Future<String> transcribe(String apiKey, Uint8List wav, String label) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(Uri.parse(_url));
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('x-goog-api-key', apiKey);
    request.add(
      utf8.encode(
        jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'inline_data': {
                    'mime_type': 'audio/wav',
                    'data': base64Encode(wav),
                  },
                },
                {'text': _prompt},
              ],
            },
          ],
          'generationConfig': {'temperature': 0.0, 'maxOutputTokens': 1024},
        }),
      ),
    );

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      return 'HTTP ${response.statusCode}: $body';
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final candidate =
        (json['candidates'] as List).first as Map<String, dynamic>;
    final content = candidate['content'] as Map<String, dynamic>?;
    if (content == null) return 'NO CONTENT (${candidate['finishReason']})';
    return ((content['parts'] as List).first['text'] as String).trim();
  } finally {
    client.close();
  }
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/verify_audio_format.dart <wav>');
    exit(64);
  }

  final env = File('.env').readAsLinesSync();
  final keyLine = env.firstWhere((l) => l.startsWith('GEMINI_API_KEY='));
  final apiKey = keyLine.split('=').sublist(1).join('=').trim();

  // Strip the source header; everything below works from raw samples.
  final source = File(args.first).readAsBytesSync();
  final pcm = Uint8List.sublistView(source, 44);

  final linear = WavCodec.encode(pcm, sampleRate: 16000);
  final muLaw = WavCodec.encodeMuLaw(pcm, sampleRate: 16000);

  String kb(int n) => '${(n / 1024).toStringAsFixed(1)} KB';
  final duration = WavCodec.durationOf(pcm.length, sampleRate: 16000);

  stdout.writeln('audio: ${duration.inMilliseconds} ms');
  stdout.writeln(
    'linear PCM : ${kb(linear.length)} '
    '(${kb((linear.length * 4 / 3).round())} base64)',
  );
  stdout.writeln(
    'mu-law     : ${kb(muLaw.length)} '
    '(${kb((muLaw.length * 4 / 3).round())} base64)',
  );
  stdout.writeln(
    'reduction  : '
    '${(100 - muLaw.length / linear.length * 100).toStringAsFixed(1)}%\n',
  );

  stdout.writeln('--- linear PCM ---');
  stdout.writeln(await transcribe(apiKey, linear, 'linear'));
  stdout.writeln('\n--- mu-law ---');
  stdout.writeln(await transcribe(apiKey, muLaw, 'mu-law'));
}
