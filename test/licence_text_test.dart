import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The licence words at the bottom of Settings
/// (lib/screens/settings_screen.dart): the copyright line and the source
/// offer behind "Open source licence".
///
/// The Android and Windows builds are both GPL-3.0 (LICENSING.md), and the
/// footer shows in both, so its words must be true in both. NimusAI holds
/// the copyright, so every language names NimusAI and nothing else. The
/// offer names Xray-core, which both builds carry, and not v2rayNG, whose
/// code only the Android build has.
void main() {
  final files =
      Directory('lib/l10n')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.arb'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  Map<String, dynamic> read(File f) =>
      jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;

  test('every language is checked', () {
    expect(files, hasLength(18));
  });

  for (final file in files) {
    final name = file.uri.pathSegments.last;

    test('$name names NimusAI as the copyright holder', () {
      final line = read(file)['copyright'] as String;
      expect(line, matches(RegExp(r'^© [0-9۰-۹]{4} NimusAI$')));
    });

    test('$name offers the source in words true on Android and Windows', () {
      final body = read(file)['sourceOfferBody'] as String;
      expect(body, contains('Xray-core'));
      expect(body, isNot(contains('v2rayNG')));
      expect(body, contains('admin@fortivavpn.com'));
    });
  }

  test('LICENSING.md names the same copyright holder', () {
    final licensing = File('LICENSING.md').readAsStringSync();
    expect(licensing, contains('Copyright (C) 2026 NimusAI'));
    expect(licensing, contains('| Windows | GPL-3.0-or-later'));
  });
}
