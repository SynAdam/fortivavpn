import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/services/connect_trace.dart';
import 'package:fortiva_vpn/utils/standby_doors.dart';
import 'package:fortiva_vpn/utils/tls_fragment.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The CDN link the filter resets by server name when the hello is whole.
const cdn =
    'vless://00000000-0000-4000-8000-000000000000@198.51.100.215:443'
    '?encryption=none&security=tls&sni=files.example.site&type=ws'
    '&host=files.example.site&path=%2F4138&fp=chrome#Fortiva%20DE';

AppConfig configWith(
  String tlsFragment, {
  String minimum = '1.0.0',
  Map<String, dynamic>? checklist,
  Map<String, dynamic>? connectTrace,
  bool? standbyDoors,
  Map<String, dynamic>? apnGuide,
}) => AppConfig.fromJson({
  'privacy_policy_url': 'https://example.com/privacy',
  'terms_of_service_url': 'https://example.com/terms',
  'eula_url': 'https://example.com/eula',
  'support_email': 'support@example.com',
  'force_update': {
    for (final os in ['ios', 'android'])
      os: {
        'latest_version': '1.0.0',
        'minimum_version': minimum,
        'update_url': 'https://example.com/update',
      },
  },
  'feature_flags': {
    'tls_fragment': tlsFragment,
    'standby_doors': ?standbyDoors,
  },
  'checklist': ?checklist,
  'connect_trace': ?connectTrace,
  'apn_guide': ?apnGuide,
});

Future<AppConfig> unreachable() async => throw Exception('no route');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TlsFragment.spec = TlsFragment.builtIn;
    ChecklistSettings.current = null;
    ConnectTraces.enabled = false;
    StandbyDoors.enabled = false;
  });

  tearDown(() {
    TlsFragment.spec = TlsFragment.builtIn;
    ChecklistSettings.current = null;
    ConnectTraces.enabled = false;
    StandbyDoors.enabled = false;
  });

  test('a phone the backend has never answered still splits the hello', () {
    final got = TlsFragment.apply(cdn, android: true);
    expect(got, contains('fragment=${TlsFragment.builtIn}'));
  });

  test('a launch whose fetch fails keeps the built-in spec', () async {
    await AppConfigState(fetch: unreachable, retryGaps: const []).load();

    expect(TlsFragment.spec, TlsFragment.builtIn);
    expect(TlsFragment.apply(cdn, android: true), contains('fragment='));
  });

  test('the backend\'s spec is used and kept for the next launch', () async {
    const remote = 'tlshello,5-9,3-4';
    await AppConfigState(fetch: () async => configWith(remote)).load();
    expect(TlsFragment.spec, remote);

    // The next launch, with the backend out of reach.
    TlsFragment.spec = TlsFragment.builtIn;
    await AppConfigState(fetch: unreachable, retryGaps: const []).load();

    expect(TlsFragment.spec, remote);
  });

  test('the backend turning the split off stays off across launches', () async {
    await AppConfigState(fetch: () async => configWith('')).load();
    expect(TlsFragment.apply(cdn, android: true), cdn);

    TlsFragment.spec = TlsFragment.builtIn;
    await AppConfigState(fetch: unreachable, retryGaps: const []).load();

    expect(TlsFragment.apply(cdn, android: true), cdn);
  });

  test('a fetch that fails is tried again', () async {
    var calls = 0;
    final state = AppConfigState(
      fetch: () async {
        calls++;
        if (calls < 3) throw Exception('no route');
        return configWith('tlshello,5-9,3-4');
      },
      retryGaps: const [Duration.zero, Duration.zero],
    );

    await state.load();

    expect(calls, 3);
    expect(state.config, isNotNull);
    expect(TlsFragment.spec, 'tlshello,5-9,3-4');
  });

  test('every try failing leaves the app without a config', () async {
    var calls = 0;
    final state = AppConfigState(
      fetch: () async {
        calls++;
        throw Exception('no route');
      },
      retryGaps: const [Duration.zero, Duration.zero],
    );

    await state.load();

    expect(calls, 3);
    expect(state.config, isNull);
    expect(state.isLoading, isFalse);
  });

  group('checklist settings', () {
    const block = {
      'last_pass_doors': 16,
      'last_pass_parallel': 4,
      'last_pass_timeout_ms': 5000,
      'skip_after_failures': 3,
      'skip_minutes': 30,
    };

    test('the built-in ones before the backend has ever answered', () async {
      await AppConfigState(fetch: unreachable, retryGaps: const []).load();
      // A new install on a network that cuts our calls keeps searching by
      // itself, and every other part is as before the block existed.
      expect(ChecklistSettings.current, same(ChecklistSettings.builtIn));
      expect(ChecklistSettings.current!.retry, same(RetrySettings.standard));
      expect(ChecklistSettings.current!.lastPass, isNull);
      expect(ChecklistSettings.current!.fallback, isNull);
    });

    test(
      'the backend\'s block is put in force and kept for the next launch',
      () async {
        await AppConfigState(
          fetch: () async => configWith('', checklist: block),
        ).load();
        expect(ChecklistSettings.current!.lastPass!.doors, 16);
        expect(ChecklistSettings.current!.skip!.skipFor.inMinutes, 30);

        // The next launch, with the backend out of reach.
        ChecklistSettings.current = null;
        await AppConfigState(fetch: unreachable, retryGaps: const []).load();
        expect(ChecklistSettings.current!.lastPass!.parallel, 4);
      },
    );

    test('a config without the block turns them off, and on the next '
        'launch too', () async {
      await AppConfigState(
        fetch: () async => configWith('', checklist: block),
      ).load();
      await AppConfigState(fetch: () async => configWith('')).load();
      expect(ChecklistSettings.current, isNull);

      await AppConfigState(fetch: unreachable, retryGaps: const []).load();
      expect(ChecklistSettings.current, isNull);
    });

    test('a saved copy that cannot be read is no settings', () async {
      SharedPreferences.setMockInitialValues({
        AppConfigState.checklistKey: '{not json',
      });
      await AppConfigState(fetch: unreachable, retryGaps: const []).load();
      expect(ChecklistSettings.current, isNull);
    });
  });

  group('connect trace', () {
    const on = {'enabled': true};

    test('off before the backend has ever answered', () async {
      await AppConfigState(fetch: unreachable, retryGaps: const []).load();
      expect(ConnectTraces.enabled, isFalse);
    });

    test('turned on by the backend and kept for the next launch', () async {
      await AppConfigState(
        fetch: () async => configWith('', connectTrace: on),
      ).load();
      expect(ConnectTraces.enabled, isTrue);

      // The next launch, with the backend out of reach.
      ConnectTraces.enabled = false;
      await AppConfigState(fetch: unreachable, retryGaps: const []).load();
      expect(ConnectTraces.enabled, isTrue);
    });

    test('a config without the block, or with enabled false, turns it off, '
        'and on the next launch too', () async {
      for (final off in [
        null,
        const {'enabled': false},
      ]) {
        SharedPreferences.setMockInitialValues({});
        await AppConfigState(
          fetch: () async => configWith('', connectTrace: on),
        ).load();
        await AppConfigState(
          fetch: () async => configWith('', connectTrace: off),
        ).load();
        expect(ConnectTraces.enabled, isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey(AppConfigState.connectTraceKey), isFalse);

        await AppConfigState(fetch: unreachable, retryGaps: const []).load();
        expect(ConnectTraces.enabled, isFalse);
      }
    });
  });

  group('standby doors', () {
    test('off before the backend has ever answered', () async {
      await AppConfigState(fetch: unreachable, retryGaps: const []).load();
      expect(StandbyDoors.enabled, isFalse);
    });

    test('turned on by the backend and kept for the next launch', () async {
      await AppConfigState(
        fetch: () async => configWith('', standbyDoors: true),
      ).load();
      expect(StandbyDoors.enabled, isTrue);

      // The next launch, with the backend out of reach.
      StandbyDoors.enabled = false;
      await AppConfigState(fetch: unreachable, retryGaps: const []).load();
      expect(StandbyDoors.enabled, isTrue);
    });

    test(
      'on for a dial made while this launch\'s fetch is in flight',
      () async {
        SharedPreferences.setMockInitialValues({
          AppConfigState.standbyDoorsKey: true,
        });
        final answer = Completer<AppConfig>();
        final loading = AppConfigState(fetch: () => answer.future).load();

        // The fetch has not landed, and a tap now dials with standby doors.
        await pumpEventQueue();
        expect(StandbyDoors.enabled, isTrue);

        answer.complete(configWith('', standbyDoors: true));
        await loading;
        expect(StandbyDoors.enabled, isTrue);
      },
    );

    test('a config with it off, or with no flag, turns it off, here and on '
        'the next launch', () async {
      for (final off in [false, null]) {
        SharedPreferences.setMockInitialValues({});
        await AppConfigState(
          fetch: () async => configWith('', standbyDoors: true),
        ).load();
        await AppConfigState(
          fetch: () async => configWith('', standbyDoors: off),
        ).load();
        expect(StandbyDoors.enabled, isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey(AppConfigState.standbyDoorsKey), isFalse);

        await AppConfigState(fetch: unreachable, retryGaps: const []).load();
        expect(StandbyDoors.enabled, isFalse);
      }
    });
  });

  group('APN guide', () {
    const on = {
      'enabled': true,
      'brands': ['samsung'],
      'carriers': ['Hamrah Aval', 'Irancell'],
    };

    test('off before the backend has ever answered', () async {
      final state = AppConfigState(fetch: unreachable, retryGaps: const []);
      await state.load();
      expect(state.apnGuide, isNull);
    });

    test('turned on by the backend and kept for the next launch', () async {
      final first = AppConfigState(
        fetch: () async => configWith('', apnGuide: on),
      );
      await first.load();
      expect(first.apnGuide!.brands, {'samsung'});

      // The next launch, with the backend out of reach: the phones the
      // guide is for are on the lines that block our calls.
      final next = AppConfigState(fetch: unreachable, retryGaps: const []);
      await next.load();
      expect(next.apnGuide!.brands, {'samsung'});
      expect(next.apnGuide!.carriers, {'hamrah aval', 'irancell'});
    });

    test('the saved settings reach the home screen while this launch\'s '
        'fetch is in flight', () async {
      await AppConfigState(
        fetch: () async => configWith('', apnGuide: on),
      ).load();
      final answer = Completer<AppConfig>();
      final state = AppConfigState(fetch: () => answer.future);
      final seen = <bool>[];
      state.addListener(() => seen.add(state.apnGuide != null));
      final loading = state.load();

      await pumpEventQueue();
      expect(state.apnGuide, isNotNull);
      expect(seen.last, isTrue);

      answer.complete(configWith('', apnGuide: on));
      await loading;
      expect(state.apnGuide, isNotNull);
    });

    test('a config without the block, or with enabled false, turns it off, '
        'here and on the next launch', () async {
      for (final off in [
        null,
        {...on, 'enabled': false},
      ]) {
        SharedPreferences.setMockInitialValues({});
        await AppConfigState(
          fetch: () async => configWith('', apnGuide: on),
        ).load();
        final state = AppConfigState(
          fetch: () async => configWith('', apnGuide: off),
        );
        await state.load();
        expect(state.apnGuide, isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey(AppConfigState.apnGuideKey), isFalse);

        final next = AppConfigState(fetch: unreachable, retryGaps: const []);
        await next.load();
        expect(next.apnGuide, isNull);
      }
    });

    test('a saved copy that cannot be read is off', () async {
      SharedPreferences.setMockInitialValues({
        AppConfigState.apnGuideKey: '{not json',
      });
      final state = AppConfigState(fetch: unreachable, retryGaps: const []);
      await state.load();
      expect(state.apnGuide, isNull);
    });
  });

  group('version rules', () {
    test('are kept for a launch whose fetch fails', () async {
      await AppConfigState(
        fetch: () async => configWith('', minimum: '1.6.4'),
      ).load();

      final next = AppConfigState(fetch: unreachable, retryGaps: const []);
      await next.load();

      // The feature flags still fall back to the defaults.
      expect(next.config, isNull);
      expect(next.flags.standbyDoors, isFalse);
      expect(next.versionRules!.android.minimumVersion, '1.6.4');
    });

    test('a newer fetch replaces them, a lowered minimum too', () async {
      await AppConfigState(
        fetch: () async => configWith('', minimum: '1.6.10'),
      ).load();
      await AppConfigState(
        fetch: () async => configWith('', minimum: '1.6.4'),
      ).load();

      final next = AppConfigState(fetch: unreachable, retryGaps: const []);
      await next.load();
      expect(next.versionRules!.android.minimumVersion, '1.6.4');
    });

    test('a fetch that lands wins over what was saved', () async {
      await AppConfigState(
        fetch: () async => configWith('', minimum: '1.6.4'),
      ).load();

      final next = AppConfigState(
        fetch: () async => configWith('', minimum: '1.6.10'),
      );
      await next.load();
      expect(next.versionRules!.android.minimumVersion, '1.6.10');
    });

    test('none before the backend has ever answered', () async {
      final state = AppConfigState(fetch: unreachable, retryGaps: const []);
      await state.load();
      expect(state.versionRules, isNull);
    });

    test('a saved copy that cannot be read is no rules', () async {
      SharedPreferences.setMockInitialValues({
        AppConfigState.versionRulesKey: '{not json',
      });
      final state = AppConfigState(fetch: unreachable, retryGaps: const []);
      await state.load();
      expect(state.versionRules, isNull);
    });
  });

  test('a second load while one runs waits for the same fetch', () async {
    var calls = 0;
    final state = AppConfigState(
      fetch: () async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return configWith('');
      },
    );
    final first = state.load();
    expect(state.isLoading, isTrue);
    await state.load();
    expect(state.config, isNotNull);
    await first;
    expect(calls, 1);
    expect(state.isLoading, isFalse);
    expect(state.loadedAt, isNotNull);
  });
}
