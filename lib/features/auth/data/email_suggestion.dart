/// Catches a mistyped domain before a code is sent to an address the user
/// cannot read.
///
/// Autofill only helps once the browser already knows the address, so it does
/// nothing on a first sign-in — which is exactly when a typo is most costly:
/// the code goes to `gmial.com`, nothing arrives, and there is no way to tell
/// that from a slow email.
abstract final class EmailSuggestion {
  /// Domains worth guarding. Deliberately short — a long list starts
  /// "correcting" legitimate company domains, which is worse than the typo.
  static const _known = [
    'gmail.com',
    'googlemail.com',
    'yahoo.com',
    'yahoo.co.uk',
    'hotmail.com',
    'hotmail.co.uk',
    'outlook.com',
    'live.com',
    'icloud.com',
    'me.com',
    'proton.me',
    'protonmail.com',
    'aol.com',
  ];

  /// A corrected address, or null when the domain looks fine or is too far off
  /// any known one to guess at.
  static String? forAddress(String email) {
    final at = email.lastIndexOf('@');
    if (at <= 0 || at == email.length - 1) return null;

    final local = email.substring(0, at);
    final domain = email.substring(at + 1).toLowerCase();
    if (_known.contains(domain)) return null;

    for (final candidate in _known) {
      if (_looksLike(domain, candidate)) return '$local@$candidate';
    }
    return null;
  }

  /// One edit, or one swap of neighbouring characters.
  ///
  /// The swap is a separate case because plain edit distance scores it as two
  /// — and `gmial` for `gmail` is the most common email typo there is, so a
  /// budget of one would miss exactly the one worth catching.
  static bool _looksLike(String a, String b) =>
      _within(a, b, 1) || _isAdjacentSwap(a, b);

  static bool _isAdjacentSwap(String a, String b) {
    if (a.length != b.length) return false;
    final differing = <int>[];
    for (var i = 0; i < a.length; i++) {
      if (a[i] == b[i]) continue;
      differing.add(i);
      if (differing.length > 2) return false;
    }
    return differing.length == 2 &&
        differing[1] == differing[0] + 1 &&
        a[differing[0]] == b[differing[1]] &&
        a[differing[1]] == b[differing[0]];
  }

  /// Whether [a] can be turned into [b] with at most [max] single-character
  /// edits. Bails out as soon as the budget is spent rather than computing a
  /// full distance matrix.
  static bool _within(String a, String b, int max) {
    if ((a.length - b.length).abs() > max) return false;
    if (a == b) return true;

    var i = 0;
    var j = 0;
    var edits = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        i++;
        j++;
        continue;
      }
      if (++edits > max) return false;
      if (a.length == b.length) {
        i++;
        j++;
      } else if (a.length > b.length) {
        i++;
      } else {
        j++;
      }
    }
    return edits + (a.length - i) + (b.length - j) <= max;
  }
}
