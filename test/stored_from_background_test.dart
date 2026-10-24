import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/services/stored_from_background.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The values the background engine writes are read again key by key. A
/// reload of every stored value replaced the app's whole copy, and what the
/// app saved while it ran was lost: on 2026-10-16 the connected event saved
/// right after a connect, while the in-app messages check reloaded.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'k': 'old'}));
  tearDown(() => StoredFromBackground.readOverride = null);

  test('a value the background engine wrote is taken up', () async {
    StoredFromBackground.readOverride = (key) async =>
        key == 'k' ? 'new' : null;
    final prefs = await SharedPreferences.getInstance();
    await StoredFromBackground.refresh(prefs, const ['k', 'absent']);
    expect(prefs.getString('k'), 'new');
    expect(prefs.containsKey('absent'), isFalse);
  });

  test('what the app saves while the values are read is kept', () async {
    final platform = Completer<String?>();
    StoredFromBackground.readOverride = (key) => platform.future;
    final prefs = await SharedPreferences.getInstance();
    final refreshing = StoredFromBackground.refresh(prefs, const ['k']);
    // The connected event is saved while the read is on its way.
    await prefs.setString(
      VpnEventReporter.storageKey,
      '[{"type":"connected"}]',
    );
    platform.complete('new');
    await refreshing;
    expect(prefs.getString(VpnEventReporter.storageKey), contains('connected'));
    expect(prefs.getString('k'), 'new');
  });

  test('a read that fails changes nothing', () async {
    StoredFromBackground.readOverride = (key) async => throw StateError('no');
    final prefs = await SharedPreferences.getInstance();
    await StoredFromBackground.refresh(prefs, const ['k']);
    expect(prefs.getString('k'), 'old');
  });
}
