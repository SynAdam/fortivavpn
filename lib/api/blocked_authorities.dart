import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Certificate authorities this app no longer trusts for its own calls,
/// even when the phone's trust store still does.
///
/// In October 2026 the private keys of eight intermediate authorities of
/// eMudhra became public. Sectigo had cross-signed all eight under its AAA
/// Certificate Services root, which Android's system store holds, and the
/// app's TLS reads only that store. Anyone on the path could then issue a
/// certificate for any name that the app would accept. Both issuers revoked
/// them, but the app checks no revocation.
///
/// Every one of the eight is limited to path length 0, so it cannot sign
/// another authority that the phone would accept. A certificate made with
/// one of their keys therefore names that authority as its own issuer, and
/// a look at the server's own certificate is enough to catch it.
///
/// No certificate of ours comes from these authorities, so refusing them
/// can never lock a phone out of our servers.
abstract final class BlockedAuthorities {
  /// The common names of the eight, in the form [canonical] gives.
  static const names = {
    'em dv tls ca - g3b',
    'em ov tls ca - g3b',
    'em ev tls ca - g3b',
    'em dv tls ca - g3c',
    'em ov tls ca - g3c',
    'em ev tls ca - g3c',
    'em ov cs ca - g3b',
    'em ov cs ca - g3c',
  };

  /// The subject key identifiers of the eight, as lowercase hex. A
  /// certificate they signed may carry one as its authority key identifier.
  static const keyIds = {
    'e21e2fe71c19390e554b62c120245735248a2514',
    '9bd86551afe7e72c37ad08ee6919d9bf3784ae0a',
    '3edc20d9894698877b873fd88147b25c15d84706',
    'ae7e105c3c2996c1a847270559f1e03dd4e50af3',
    '34eaea0cebc90adaf9d0c5e2ed9b78c9879e1b6c',
    'a6255e80a94db7f3967c1bc791df92bcee4beb5f',
    '79fae8eccfdb0d758da458d69fb6eddc7c49dee6',
    'ee6f73298d6fbfa7b31bc39534f61556447866b7',
  };

  static const _commonName = [0x55, 0x04, 0x03];
  static const _authorityKeyId = [0x55, 0x1d, 0x23];

  /// Whether the certificate in [der] was issued by one of the blocked
  /// authorities: its issuer has one of their [names] as a common name, or
  /// its authority key identifier is one of their [keyIds].
  ///
  /// Never throws. A certificate this cannot read counts as not blocked,
  /// because the platform has already accepted it, and a fault in this
  /// reader must never cut a phone off from us.
  static bool issuedByBlocked(Uint8List der) {
    try {
      final cert = _Der(der).sequence();
      final tbs = cert.sequence();
      // version [0], when present.
      if (tbs.peekTag == 0xa0) tbs.skip();
      tbs.skip(); // serialNumber
      tbs.skip(); // signature
      final issuer = tbs.sequence();
      if (_issuerBlocked(issuer)) return true;
      tbs.skip(); // validity
      tbs.skip(); // subject
      tbs.skip(); // subjectPublicKeyInfo
      while (tbs.hasMore) {
        final tag = tbs.peekTag;
        if (tag == 0xa3) {
          final extensions = tbs.explicit().sequence();
          return _authorityKeyBlocked(extensions);
        }
        tbs.skip(); // issuerUniqueID or subjectUniqueID
      }
      return false;
    } catch (e) {
      debugPrint('BlockedAuthorities: could not read a certificate ($e)');
      return false;
    }
  }

  static bool _issuerBlocked(_Der name) {
    while (name.hasMore) {
      final rdn = name.set();
      while (rdn.hasMore) {
        final pair = rdn.sequence();
        final oid = pair.take(0x06);
        if (!listEquals(oid, _commonName)) continue;
        final (tag, value) = pair.any();
        final text = decodeString(tag, value);
        if (names.contains(canonical(text))) return true;
      }
    }
    return false;
  }

  static bool _authorityKeyBlocked(_Der extensions) {
    while (extensions.hasMore) {
      final extension = extensions.sequence();
      final oid = extension.take(0x06);
      if (!listEquals(oid, _authorityKeyId)) continue;
      // critical BOOLEAN DEFAULT FALSE, when present.
      if (extension.peekTag == 0x01) extension.skip();
      final value = _Der(extension.take(0x04)).sequence();
      while (value.hasMore) {
        final (tag, bytes) = value.any();
        // keyIdentifier [0] IMPLICIT OCTET STRING
        if (tag == 0x80) return keyIds.contains(_hex(bytes));
      }
      return false;
    }
    return false;
  }

  /// A string of a certificate name as text, by its ASN.1 tag.
  @visibleForTesting
  static String decodeString(int tag, Uint8List value) {
    switch (tag) {
      case 0x0c: // UTF8String
        return utf8.decode(value, allowMalformed: true);
      case 0x1e: // BMPString, UTF-16BE
        final units = <int>[
          for (var i = 0; i + 1 < value.length; i += 2)
            (value[i] << 8) | value[i + 1],
        ];
        return String.fromCharCodes(units);
      case 0x1c: // UniversalString, UTF-32BE
        final points = <int>[
          for (var i = 0; i + 3 < value.length; i += 4)
            (value[i] << 24) |
                (value[i + 1] << 16) |
                (value[i + 2] << 8) |
                value[i + 3],
        ];
        return String.fromCharCodes(points);
      default:
        // PrintableString, IA5String, VisibleString, NumericString, and
        // T61String, which is read as Latin-1.
        return latin1.decode(value);
    }
  }

  /// [text] the way the TLS library compares names when it builds a chain:
  /// ASCII letters in lower case, no space at either end, and each run of
  /// spaces inside as one. A forged certificate can change the case or the
  /// spaces of its issuer's name and still be matched to that issuer, so
  /// the comparison here has to ignore the same things.
  @visibleForTesting
  static String canonical(String text) {
    final out = StringBuffer();
    var space = false;
    for (final unit in text.trim().codeUnits) {
      if (_isSpace(unit)) {
        space = true;
        continue;
      }
      if (space && out.isNotEmpty) out.write(' ');
      space = false;
      out.writeCharCode(unit >= 0x41 && unit <= 0x5a ? unit + 0x20 : unit);
    }
    return out.toString();
  }

  static bool _isSpace(int unit) =>
      unit == 0x20 || (unit >= 0x09 && unit <= 0x0d);

  static String _hex(Uint8List bytes) =>
      [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();

  /// Throws [BlockedAuthority] when [socket]'s certificate was issued by a
  /// blocked authority, after closing it.
  static void check(SecureSocket socket) {
    final der = socket.peerCertificate?.der;
    if (der == null || !issuedByBlocked(der)) return;
    socket.destroy();
    throw const BlockedAuthority();
  }
}

/// A connection was refused because the server's certificate came from an
/// authority this app does not trust ([BlockedAuthorities]).
///
/// A route failure like any failed handshake, so a call moves on to the
/// next route. The message names no host and no address.
class BlockedAuthority extends TlsException {
  const BlockedAuthority() : super('blocked certificate authority');
}

/// Reads DER one element at a time.
class _Der {
  _Der(this._bytes, [this._at = 0, int? end]) : _end = end ?? _bytes.length;

  final Uint8List _bytes;
  int _at;
  final int _end;

  bool get hasMore => _at < _end;

  int get peekTag {
    if (_at >= _end) throw const FormatException('no more elements');
    return _bytes[_at];
  }

  /// The next element's tag, and where its content starts and ends.
  (int, int, int) _next() {
    if (_at + 2 > _end) throw const FormatException('truncated element');
    final tag = _bytes[_at];
    // High tag numbers do not occur in what this reads.
    if (tag & 0x1f == 0x1f) throw const FormatException('long tag');
    var i = _at + 1;
    var length = _bytes[i++];
    if (length & 0x80 != 0) {
      final count = length & 0x7f;
      if (count == 0 || count > 4 || i + count > _end) {
        throw const FormatException('bad length');
      }
      length = 0;
      for (var k = 0; k < count; k++) {
        length = (length << 8) | _bytes[i++];
      }
    }
    final end = i + length;
    if (length < 0 || end > _end) throw const FormatException('overrun');
    _at = end;
    return (tag, i, end);
  }

  void skip() => _next();

  _Der _inner(int want) {
    final (tag, start, end) = _next();
    if (tag != want) {
      throw FormatException('tag ${tag.toRadixString(16)}, not $want');
    }
    return _Der(_bytes, start, end);
  }

  _Der sequence() => _inner(0x30);
  _Der set() => _inner(0x31);

  /// The content of an [n] EXPLICIT element.
  _Der explicit() {
    final (_, start, end) = _next();
    return _Der(_bytes, start, end);
  }

  /// The content of the next element, which must have [tag].
  Uint8List take(int tag) {
    final (got, start, end) = _next();
    if (got != tag) throw FormatException('tag $got, not $tag');
    return Uint8List.sublistView(_bytes, start, end);
  }

  /// The next element, whatever its tag.
  (int, Uint8List) any() {
    final (tag, start, end) = _next();
    return (tag, Uint8List.sublistView(_bytes, start, end));
  }
}
