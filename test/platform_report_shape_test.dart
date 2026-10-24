import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The backend reads one diagnosis shape and its verdict rules have no
/// per-platform branch. Two native files fill that map, in two languages,
/// and nothing but this test stops one of them from calling the same fact
/// by a different name.
///
/// Read out of the sources rather than listed by hand, so a key added on
/// one side and not the other is caught the day it is written.
void main() {
  /// Keys assigned into the diagnostics map in a native source file.
  Set<String> keysIn(String path, RegExp assignment) {
    final source = File(path).readAsStringSync();
    return assignment.allMatches(source).map((m) => m.group(1)!).toSet();
  }

  // The carrier and network come from TunnelProbe, which the keeper's run
  // reads as well; the rest is filled in MainActivity.
  Set<String> androidKeys() => {
    for (final path in [
      'android/app/src/main/java/com/vpn/fortivavpn/MainActivity.kt',
      'android/app/src/main/java/com/vpn/fortivavpn/handler/TunnelProbe.kt',
    ])
      ...keysIn(path, RegExp(r'''out\["([a-z0-9_]+)"\]\s*=''')),
  };

  Set<String> iosKeys() => keysIn(
    'ios/Runner/AppDelegate.swift',
    RegExp(r'''out\["([a-z0-9_]+)"\]\s*='''),
  );

  /// Facts iOS reports that Android has no counterpart for.
  ///
  /// An extra key costs the backend nothing; a renamed one costs it a
  /// column. Anything here is a deliberate addition, not a mismatch.
  const iosOnly = {
    // The radio the phone is on. A carrier that blocks on 4G and not on
    // 5G is a distinction the transport alone cannot make, and Android
    // does not read it today.
    'radio',
  };

  test('the scan finds both maps, so an empty result is not a pass', () {
    expect(androidKeys(), contains('carrier'));
    expect(androidKeys(), contains('core_log'));
    expect(androidKeys().length, greaterThanOrEqualTo(12));
    expect(iosKeys(), contains('network'));
    expect(iosKeys().length, greaterThanOrEqualTo(8));
  });

  test('every key iOS sends is one Android already sends', () {
    final stray = iosKeys().difference(androidKeys()).difference(iosOnly);
    expect(
      stray,
      isEmpty,
      reason:
          'These keys exist only on iOS. Either name the fact the way '
          'Android already names it, or add it to iosOnly with a line '
          'saying why Android has no counterpart.',
    );
  });

  test('iOS answers the questions the verdict rules read', () {
    // The backend decides a verdict from control, dns, tcp, tls and
    // vpn_permission. The first four are measured in Dart on both
    // platforms; vpn_permission is the one the platform has to answer,
    // and a failure that omits it is read as a network fault rather than
    // a permission the user never granted.
    expect(iosKeys(), contains('vpn_permission'));
    // The carrier is the denominator of every per-carrier failure rate.
    expect(iosKeys(), contains('carrier'));
    expect(iosKeys(), contains('network'));
  });
}
