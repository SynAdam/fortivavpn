import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/blocked_authorities.dart';

/// The reader behind the refusal of the blocked authorities: how it
/// compares names, how it reads strings, and that it never throws on bytes
/// it cannot read, so a fault in it can never cut a phone off.
void main() {
  test('the list holds eight names and eight key identifiers', () {
    expect(BlockedAuthorities.names, hasLength(8));
    expect(BlockedAuthorities.keyIds, hasLength(8));
    for (final id in BlockedAuthorities.keyIds) {
      expect(id, matches(RegExp(r'^[0-9a-f]{40}$')));
    }
    for (final name in BlockedAuthorities.names) {
      expect(BlockedAuthorities.canonical(name), name);
    }
  });

  test('names compare without case and with spaces collapsed', () {
    expect(
      BlockedAuthorities.canonical('  Example   TLS\tCA  '),
      'example tls ca',
    );
    expect(BlockedAuthorities.canonical('ABC'), 'abc');
    // Only ASCII letters change case, as in the TLS library.
    expect(BlockedAuthorities.canonical('ÄÖ'), 'ÄÖ');
  });

  test('strings are read by their tag', () {
    final ascii = Uint8List.fromList('Example CA'.codeUnits);
    expect(BlockedAuthorities.decodeString(0x13, ascii), 'Example CA');
    expect(BlockedAuthorities.decodeString(0x0c, ascii), 'Example CA');
    final bmp = Uint8List.fromList([
      for (final unit in 'Example CA'.codeUnits) ...[0, unit],
    ]);
    expect(BlockedAuthorities.decodeString(0x1e, bmp), 'Example CA');
    final universal = Uint8List.fromList([
      for (final unit in 'Example CA'.codeUnits) ...[0, 0, 0, unit],
    ]);
    expect(BlockedAuthorities.decodeString(0x1c, universal), 'Example CA');
  });

  test('bytes it cannot read are not blocked and never throw', () {
    for (final bytes in [
      <int>[],
      [0x30],
      [0x30, 0x82, 0xff, 0xff],
      [0x04, 0x02, 0x01, 0x02],
      List<int>.generate(64, (i) => i * 7 & 0xff),
    ]) {
      expect(
        BlockedAuthorities.issuedByBlocked(Uint8List.fromList(bytes)),
        isFalse,
      );
    }
  });

  test('the refusal is a TLS failure that names no host', () {
    const e = BlockedAuthority();
    expect(e.message, isNot(contains('.')));
  });
}
