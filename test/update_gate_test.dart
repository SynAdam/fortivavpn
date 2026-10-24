import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:fortiva_vpn/core/update_check.dart';
import 'package:fortiva_vpn/core/update_gate.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The update check runs at launch and on every return to the foreground,
/// fetches the config again only when the copy in hand is stale, and runs
/// on the saved rules at once rather than after that fetch, and again when
/// the fetch fails.

AppConfig configWith({String minimum = '1.6.4'}) => AppConfig.fromJson({
  'privacy_policy_url': 'https://example.com/privacy',
  'terms_of_service_url': 'https://example.com/terms',
  'eula_url': 'https://example.com/eula',
  'support_email': 'support@example.com',
  'force_update': {
    for (final os in ['ios', 'android'])
      os: {
        'latest_version': '1.6.10',
        'minimum_version': minimum,
        'update_url': 'https://example.com/update',
      },
  },
});

void main() {
  late DateTime now;
  late int fetches;
  late bool backendDown;
  late String minimum;
  late List<ForceUpdate?> checked;
  late AppConfigState config;
  late UpdateOpens opens;
  late UpdateGate gate;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 10, 6, 12);
    fetches = 0;
    backendDown = false;
    minimum = '1.6.4';
    checked = [];
    config = AppConfigState(
      fetch: () async {
        fetches++;
        if (backendDown) throw Exception('no route');
        return configWith(minimum: minimum);
      },
      retryGaps: const [],
      now: () => now,
    );
    opens = UpdateOpens(now: () => now);
    gate = UpdateGate(
      config: config,
      opens: opens,
      check: (rules) async => checked.add(rules),
      now: () => now,
    );
  });

  /// Leave the app for [away], then come back.
  Future<void> leaveFor(Duration away) async {
    gate.hidden();
    now = now.add(away);
    await gate.resumed();
  }

  test('checks at launch on the rules the launch fetched', () async {
    await gate.launched(config.load());
    // Nothing was saved before this first launch, so only the check after
    // the fetch runs.
    expect(checked, hasLength(1));
    expect(checked.single!.android.minimumVersion, '1.6.4');
  });

  test('checks again on every return to the foreground', () async {
    await gate.launched(config.load());
    await leaveFor(const Duration(seconds: 10));
    await leaveFor(const Duration(seconds: 10));
    // A quick return checks once, on the rules in hand.
    expect(checked, hasLength(3));
  });

  test('a quick return does not fetch the config again', () async {
    await gate.launched(config.load());
    await leaveFor(const Duration(minutes: 4));
    expect(fetches, 1);
    expect(checked, hasLength(2));
  });

  test('a return after five minutes fetches the config first', () async {
    await gate.launched(config.load());

    minimum = '1.6.10';
    await leaveFor(UpdateGate.configFreshFor);

    expect(fetches, 2);
    expect(checked.last!.android.minimumVersion, '1.6.10');
  });

  test('a return whose fetch fails still checks, on the saved rules', () async {
    await gate.launched(config.load());

    backendDown = true;
    await leaveFor(const Duration(hours: 1));

    expect(fetches, 2);
    // Once on the rules in hand, once after the fetch failed.
    expect(checked, hasLength(3));
    expect(checked.last!.android.minimumVersion, '1.6.4');
  });

  test('a launch whose fetch fails checks on the last launch rules', () async {
    await config.load();

    // The next launch, with the backend out of reach.
    backendDown = true;
    final next = AppConfigState(
      fetch: () async => throw Exception('no route'),
      retryGaps: const [],
    );
    final seen = <ForceUpdate?>[];
    await UpdateGate(
      config: next,
      opens: UpdateOpens(),
      check: (rules) async => seen.add(rules),
    ).launched(next.load());

    expect(next.config, isNull);
    expect(seen.map((r) => r!.android.minimumVersion), ['1.6.4', '1.6.4']);
  });

  test('a launch that never reached the backend checks on nothing', () async {
    backendDown = true;
    await gate.launched(config.load());
    expect(checked, [null]);
  });

  test('a launch checks on the saved rules before the fetch ends', () async {
    await config.load();

    // The next launch, with a fetch that has not ended: every route to the
    // backend is timing out.
    final hanging = Completer<AppConfig>();
    final next = AppConfigState(fetch: () => hanging.future, retryGaps: []);
    final seen = <ForceUpdate?>[];
    final launch = UpdateGate(
      config: next,
      opens: UpdateOpens(),
      check: (rules) async => seen.add(rules),
    ).launched(next.load());
    await pumpEventQueue();

    expect(seen.map((r) => r!.android.minimumVersion), ['1.6.4']);

    hanging.complete(configWith(minimum: '1.6.10'));
    await launch;
    expect(seen.map((r) => r!.android.minimumVersion), ['1.6.4', '1.6.10']);
  });

  test('a stale return checks on the rules in hand before fetching', () async {
    await gate.launched(config.load());

    final hanging = Completer<AppConfig>();
    final slow = AppConfigState(fetch: () => hanging.future, retryGaps: []);
    await slow.restoreSaved();
    final seen = <ForceUpdate?>[];
    final slowGate = UpdateGate(
      config: slow,
      opens: UpdateOpens(),
      check: (rules) async => seen.add(rules),
    );
    final back = slowGate.resumed();
    await pumpEventQueue();
    expect(seen.map((r) => r!.android.minimumVersion), ['1.6.4']);

    hanging.complete(configWith(minimum: '1.6.10'));
    await back;
    expect(seen.map((r) => r!.android.minimumVersion), ['1.6.4', '1.6.10']);
  });

  test('a check that throws does not escape', () async {
    final failing = UpdateGate(
      config: config,
      opens: opens,
      check: (_) async => throw StateError('no navigator'),
    );
    await failing.launched(config.load());
    await failing.resumed();
  });

  test('a long stay in the background starts a new open', () async {
    await gate.launched(config.load());
    opens.optionalAnswered();

    await leaveFor(const Duration(minutes: 2));
    expect(opens.optionalHeld, isTrue);

    await leaveFor(UpdateOpens.newOpenAfter);
    expect(opens.optionalHeld, isFalse);
  });

  group('isStale', () {
    final at = DateTime(2026, 10, 6, 12);

    test('never fetched is stale', () {
      expect(UpdateGate.isStale(null, at), isTrue);
    });

    test('fresh for just under five minutes', () {
      expect(
        UpdateGate.isStale(at, at.add(const Duration(minutes: 4, seconds: 59))),
        isFalse,
      );
      expect(UpdateGate.isStale(at, at.add(UpdateGate.configFreshFor)), isTrue);
    });

    test('a fetch time in the future is stale', () {
      // The clock moved back.
      expect(
        UpdateGate.isStale(at, at.subtract(const Duration(minutes: 1))),
        isTrue,
      );
    });
  });
}
