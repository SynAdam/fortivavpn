/// Finding an invite code in what a friend sent.
///
/// Codes are 6 characters of Crockford's base 32, which the backend also
/// normalizes. A friend who installed the APK gets the code in a message,
/// often in Persian with Persian digits, and pastes the whole message.
class InviteCode {
  InviteCode._();

  /// Crockford's base 32: no I, L, O or U.
  static const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// The length of a code.
  static const codeLength = 6;

  /// The most the code field takes while typing, as before: a code with a
  /// dash or a space in it.
  static const maxTyped = 8;

  static final _valid = RegExp('^[$alphabet]{$codeLength}\$');
  static final _token = RegExp(
    '(?<![A-Za-z0-9])[$alphabet]{$codeLength}(?![A-Za-z0-9])',
  );
  static final _link = RegExp(r'/i/([^/?#\s]+)');

  /// Persian (۰-۹) and Arabic (٠-٩) digits as 0-9. Nothing else changes.
  static String foldDigits(String text) {
    final out = StringBuffer();
    for (final rune in text.runes) {
      if (rune >= 0x06F0 && rune <= 0x06F9) {
        out.writeCharCode(0x30 + rune - 0x06F0);
      } else if (rune >= 0x0660 && rune <= 0x0669) {
        out.writeCharCode(0x30 + rune - 0x0660);
      } else {
        out.writeCharCode(rune);
      }
    }
    return out.toString();
  }

  /// The code in [text], or null when none is found. After the digits are
  /// folded:
  ///
  /// 1. the path segment after "/i/" in a link, if it is a valid code. The
  ///    segment ends at the first "/", "?", "#" or space, so
  ///    https://fortivavpn.com/fa/i/AB3D7K?s=card gives AB3D7K;
  /// 2. else the last valid code on the last line that has one, as a word
  ///    of its own in the strict alphabet, upper case only, so a word of
  ///    the message such as "Pasang" is never taken for one;
  /// 3. else, when the whole text without spaces and dashes is
  ///    [maxTyped] characters or fewer, that text upper-cased with
  ///    Crockford's read-alikes (I and L to 1, O to 0, U to V), if that
  ///    makes a valid code.
  static String? find(String text) {
    final folded = foldDigits(text);

    for (final m in _link.allMatches(folded)) {
      final segment = m.group(1)!.toUpperCase();
      if (_valid.hasMatch(segment)) return segment;
    }

    final lines = folded.split(RegExp(r'\r?\n'));
    for (final line in lines.reversed) {
      final tokens = _token.allMatches(line).toList();
      if (tokens.isNotEmpty) return tokens.last.group(0);
    }

    final bare = folded.replaceAll(RegExp(r'[\s\-]'), '');
    if (bare.isEmpty || bare.length > maxTyped) return null;
    final read = readAlikes(bare.toUpperCase());
    return _valid.hasMatch(read) ? read : null;
  }

  /// I and L read as 1, O as 0, U as V, as Crockford's base 32 does.
  static String readAlikes(String upper) => upper
      .replaceAll('I', '1')
      .replaceAll('L', '1')
      .replaceAll('O', '0')
      .replaceAll('U', 'V');
}
