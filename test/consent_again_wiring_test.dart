import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The VPN consent dialog is shown once more when it closed itself before
/// the user could see it (ConsentAgain.kt). Up to 2.3.0 that ended the tap
/// with PERMISSION_BLOCKED: 7 taps on 3 phones in the week to 2026-10-27,
/// 4 of which connected on the user's next tap.
///
/// MainActivity cannot run in a unit test, so this reads its source: the
/// branch for a dialog that closed itself asks ConsentAgain, and asks again
/// only through the same consent steps, marked as the second showing. Those
/// steps call prepare() only for a tap (see other_vpn_app_test.dart).
void main() {
  final source = File(
    'android/app/src/main/java/com/vpn/fortivavpn/MainActivity.kt',
  ).readAsStringSync();

  String silentBranch() {
    final start = source.indexOf('if (elapsed in 0 until SILENT_CANCEL_MS) {');
    expect(start, isNot(-1), reason: 'the silent close branch is gone');
    final end = source.indexOf('"PERMISSION_BLOCKED"', start);
    expect(end, isNot(-1));
    return source.substring(start, end);
  }

  test('a dialog that closed itself asks ConsentAgain first', () {
    expect(silentBranch(), contains('ConsentAgain.shouldAsk('));
    expect(silentBranch(), contains('shownAgain,'));
  });

  test('it asks again only as the second showing, through the consent '
      'steps', () {
    final branch = silentBranch();
    expect(
      branch,
      contains(
        'connectPsiphon(psiphon, takeSlot = true, result, shownAgain = true)',
      ),
    );
    expect(
      branch,
      contains(
        'connectTunnel(link, alternates, exits, penalties, outbounds, '
        'takeSlot = true, result, shownAgain = true)',
      ),
    );
    // No prepare() of its own: only withVpnConsent calls it.
    final code = [
      for (final line in branch.split('\n')) line.split('//').first,
    ].join('\n');
    expect(code, isNot(contains('prepare(')));
  });

  test('the second showing is remembered with its request', () {
    expect(source, contains('val shownAgain = pendingShownAgain'));
    expect(source, contains('pendingShownAgain = shownAgain'));
  });
}
