import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level enforcement of DESIGN.md.
///
/// These rules are about what the code is *allowed to say*, not about what it
/// renders, so they read the tree as text rather than pumping widgets. That
/// makes them nearly free to run and impossible to satisfy accidentally — a
/// reviewer can forget the system, CI cannot.
///
/// Each allowlist below is an exception DESIGN.md grants explicitly. Adding an
/// entry means amending §14 first.
void main() {
  final sources = _dartSources();

  test('lib/ has sources to scan', () {
    expect(sources, isNotEmpty, reason: 'the sweep would pass vacuously');
  });

  group('colour', () {
    test('no retired brand purple', () {
      _expectNoMatch(sources, RegExp(r'0xFF490080', caseSensitive: false));
    });

    test('no pure white or black', () {
      _expectNoMatch(sources, RegExp(r'Colors\.(white|black)\b'));
    });

    test('no raw Material palette hues', () {
      _expectNoMatch(
        sources,
        RegExp(r'Colors\.(red|pink|purple|indigo|blue|cyan|teal|green|lime|'
            r'yellow|orange|brown|grey|blueGrey|deepPurple|deepOrange|'
            r'lightBlue|lightGreen|amber)\b'),
      );
    });
  });

  group('depth', () {
    test('no backdrop blur', () {
      _expectNoMatch(sources, RegExp(r'BackdropFilter|ImageFilter\.blur'));
    });

    test('shadows only where DESIGN.md allows', () {
      _expectOnlyIn(sources, RegExp(r'BoxShadow'), _shadowAllowlist);
    });

    test('gradients only where DESIGN.md allows', () {
      _expectOnlyIn(
        sources,
        RegExp(r'(Linear|Radial|Sweep)Gradient'),
        _gradientAllowlist,
      );
    });
  });

  group('typography', () {
    test('no inline font sizing', () {
      _expectNoMatch(sources, RegExp(r'fontSize:\s*\d'));
    });

    test('no inline font weight', () {
      _expectNoMatch(sources, RegExp(r'fontWeight:\s*FontWeight\.'));
    });
  });

  group('interaction', () {
    test('no bare GestureDetector for taps', () {
      _expectOnlyIn(sources, RegExp(r'GestureDetector'), _gestureAllowlist);
    });
  });
}

// ── Allowlists ──────────────────────────────────────────────────────────────

/// §2: the record-control glow while capturing, and the level-3 modal shadow.
const _shadowAllowlist = <String>{
  'lib/features/recording/presentation/screens/recording_screen.dart',
};

/// §3: amplitude-driven colour lives in the waveform, which paints rather than
/// decorates.
const _gradientAllowlist = <String>{
  'lib/features/recording/presentation/widgets/waveform_animation.dart',
};

/// `Pressable` is the one place allowed to reach for a raw gesture primitive.
const _gestureAllowlist = <String>{
  'lib/core/widgets/pressable.dart',
};

// ── Helpers ─────────────────────────────────────────────────────────────────

class _Source {
  const _Source(this.path, this.lines);
  final String path;
  final List<String> lines;
}

List<_Source> _dartSources() {
  final root = Directory('lib');
  if (!root.existsSync()) return const [];
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => _Source(f.path, f.readAsLinesSync()))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

/// Comments describe the system; only code has to obey it.
bool _isComment(String line) {
  final t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('///') || t.startsWith('*');
}

List<String> _hits(List<_Source> sources, RegExp pattern, {Set<String>? skip}) {
  final out = <String>[];
  for (final s in sources) {
    if (skip != null && skip.contains(s.path)) continue;
    for (var i = 0; i < s.lines.length; i++) {
      final line = s.lines[i];
      if (_isComment(line)) continue;
      if (pattern.hasMatch(line)) {
        out.add('${s.path}:${i + 1}  ${line.trim()}');
      }
    }
  }
  return out;
}

void _expectNoMatch(List<_Source> sources, RegExp pattern) {
  final hits = _hits(sources, pattern);
  expect(
    hits,
    isEmpty,
    reason: 'DESIGN.md forbids /${pattern.pattern}/:\n${hits.join('\n')}',
  );
}

void _expectOnlyIn(
  List<_Source> sources,
  RegExp pattern,
  Set<String> allowlist,
) {
  final hits = _hits(sources, pattern, skip: allowlist);
  expect(
    hits,
    isEmpty,
    reason: 'DESIGN.md allows /${pattern.pattern}/ only in '
        '${allowlist.join(', ')}:\n${hits.join('\n')}',
  );
}
