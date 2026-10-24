import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/services/log_privacy.dart';

/// No line that names a site or an address may leave the phone in the
/// technical log. Until 1.6.21 every connected and dropped event carried
/// the core's `sniffed domain: <host>` line for each connection, with its
/// time, and the backend kept it with no time limit (issue #244).
///
/// The sample lines are shared with the native filter's test
/// (android/.../handler/LogPrivacyTest.kt), so both are held to the same
/// lines.
void main() {
  final samples = [
    for (final line in File(
      'test/fixtures/log_privacy_lines.txt',
    ).readAsLinesSync())
      if (line.trim().isNotEmpty && !line.startsWith('#'))
        if (line.startsWith('drop '))
          (drop: true, line: line.substring(5))
        else if (line.startsWith('keep '))
          (drop: false, line: line.substring(5))
        else
          throw StateError('a sample line must start with drop or keep: $line'),
  ];
  final dropped = [
    for (final s in samples)
      if (s.drop) s.line,
  ];
  final kept = [
    for (final s in samples)
      if (!s.drop) s.line,
  ];

  test('the samples have both kinds', () {
    expect(dropped.length, greaterThan(30));
    expect(kept.length, greaterThan(5));
  });

  test('every line that names a site or an address is found', () {
    for (final line in dropped) {
      expect(LogPrivacy.namesDestination(line), isTrue, reason: line);
    }
  });

  test('lines without a site or an address are not found', () {
    for (final line in kept) {
      expect(LogPrivacy.namesDestination(line), isFalse, reason: line);
    }
  });

  test('a scrubbed log holds only the kept lines and a summary', () {
    final log = '${[for (final s in samples) s.line].join('\n')}\n';
    final out = LogPrivacy.scrub(log).split('\n');
    expect(out.sublist(0, out.length - 1), kept);
    expect(out.last, LogPrivacy.summary(dropped.length));
  });

  test('no site name or address survives a scrub', () {
    final out = LogPrivacy.scrub([for (final s in samples) s.line].join('\n'));
    for (final name in [
      'example.com',
      'example.org',
      'example.ir',
      'example.net',
      'xn--mgbh0fb',
      'مثال',
      '203.0.113.',
      '198.51.100.',
      '2001:db8',
      '10.10.34.35',
      '2001:4188',
      'Example VPN',
      'com.example.app',
    ]) {
      expect(out, isNot(contains(name)), reason: name);
    }
  });

  // The native side ends a scrubbed log with its own summary line. This
  // filter must keep that line, or the counts in it are lost.
  test('the native summary lines pass this filter', () {
    for (final summary in [
      '[privacy] 1 line that names a site or an address was left out.',
      '[privacy] 41 lines that name a site or an address were left out. '
          'Of these, 2 named a 10.10.34.x sinkhole address and 5 used port '
          '853.',
      LogPrivacy.summary(1),
      LogPrivacy.summary(7),
    ]) {
      expect(LogPrivacy.namesDestination(summary), isFalse, reason: summary);
    }
  });

  test('a log with nothing to leave out is unchanged', () {
    final log = '${kept.join('\n')}\n';
    expect(LogPrivacy.scrub(log), log);
  });

  test('scrubbing twice changes nothing more', () {
    final once = LogPrivacy.scrub([for (final s in samples) s.line].join('\n'));
    expect(LogPrivacy.scrub(once), once);
  });

  test('the phrase list is the native one', () {
    final kotlin = File(
      'android/app/src/main/java/com/vpn/fortivavpn/handler/LogPrivacy.kt',
    ).readAsStringSync();
    final start = kotlin.indexOf('DESTINATION_PHRASES = listOf(');
    final end = kotlin.indexOf('\n    )', start);
    expect(start, greaterThan(0));
    final native = [
      for (final m in RegExp(
        r'^\s*"([^"]+)",',
        multiLine: true,
      ).allMatches(kotlin.substring(start, end)))
        m[1]!,
    ];
    expect(LogPrivacy.destinationPhrases, native);
  });
}
