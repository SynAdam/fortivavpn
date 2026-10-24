import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/psiphon_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config_state_test.dart' as base show configWith;

/// The backup network's settings (clients #299): the app config's `psiphon`
/// block, kept between launches, and the per-device answer that comes with
/// /configs/dedicated.
///
/// Every value here is made up. The real ones come from the backend only.
const network = {
  'PropagationChannelId': '0123456789ABCDEF',
  'SponsorId': 'FEDCBA9876543210',
  'RemoteServerListURLs': [
    {'URL': 'https://lists.example.test/list', 'OnlyAfterAttempts': 0},
  ],
};

Map<String, dynamic> block([Map<String, dynamic> over = const {}]) => {
  'enabled': true,
  'network': network,
  ...over,
};

/// A config the backend could send, with [psiphon] as its `psiphon` block.
AppConfig configWith(Object? psiphon) =>
    AppConfig.fromJson({...base.configWith('').toJson(), 'psiphon': ?psiphon});

Future<AppConfig> unreachable() async => throw Exception('no route');

QuotaStatus quota({bool blocked = false}) => QuotaStatus(
  unlimited: false,
  limitBytes: 100,
  usedBytes: blocked ? 100 : 10,
  remainingBytes: blocked ? 0 : 90,
  blocked: blocked,
);

DedicatedConfigs answer({bool? psiphon, bool blocked = false}) =>
    DedicatedConfigs.fromJson({
      'configs': blocked ? const <String>[] : ['vless://u@h.example:443#A'],
      'quota': {
        'unlimited': false,
        'limit_bytes': 100,
        'used_bytes': blocked ? 100 : 10,
        'remaining_bytes': blocked ? 0 : 90,
        'blocked': blocked,
        if (blocked)
          'resets_at': DateTime.now()
              .toUtc()
              .add(const Duration(hours: 3))
              .toIso8601String(),
      },
      'psiphon': ?psiphon,
    });

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PsiphonSettings.current = null;
  });

  tearDown(() => PsiphonSettings.current = null);

  group('the block', () {
    test('off when it is missing, not an object, or has no network', () {
      expect(PsiphonSettings.fromJson(null), isNull);
      expect(PsiphonSettings.fromJson('on'), isNull);
      expect(PsiphonSettings.fromJson({'enabled': true}), isNull);
      expect(
        PsiphonSettings.fromJson({'enabled': true, 'network': null}),
        isNull,
      );
      expect(
        PsiphonSettings.fromJson({'enabled': true, 'network': const {}}),
        isNull,
      );
      expect(
        PsiphonSettings.fromJson({'enabled': true, 'network': 'x'}),
        isNull,
      );
    });

    test('a network with only keys the phone owns is no network', () {
      expect(
        PsiphonSettings.fromJson(
          block({
            'network': {'DataRootDirectory': '/x', 'EgressRegion': 'CA'},
          }),
        ),
        isNull,
      );
    });

    test('kept with enabled false: a test device can still be let in', () {
      final s = PsiphonSettings.fromJson(block({'enabled': false}))!;
      expect(s.enabled, isFalse);
      expect(s.network, network);
    });

    test('the defaults, for every field that is missing', () {
      final s = PsiphonSettings.fromJson({'network': network})!;
      expect(s.enabled, isFalse);
      expect(s.egressRegion, '');
      expect(s.establishTimeout, const Duration(seconds: 60));
      expect(s.afterRounds, 0);
      expect(s.everyRounds, 1);
      expect(s.stages, {'all_closed', 'failed', 'cut_off'});
      expect(s.tv, isFalse);
    });

    test('the values the backend sends', () {
      final s = PsiphonSettings.fromJson(
        block({
          'egress_region': 'CA',
          'establish_timeout_seconds': 90,
          'after_rounds': 2,
          'every_rounds': 3,
          'stages': ['no_internet', 'all_closed'],
          'tv': true,
        }),
      )!;
      expect(s.enabled, isTrue);
      expect(s.egressRegion, 'CA');
      expect(s.establishTimeout, const Duration(seconds: 90));
      expect(s.afterRounds, 2);
      expect(s.everyRounds, 3);
      expect(s.stages, {'no_internet', 'all_closed'});
      expect(s.tv, isTrue);
    });

    test('a value that cannot be used takes the default, and the block '
        'stays', () {
      final s = PsiphonSettings.fromJson(
        block({
          'enabled': 'yes',
          'egress_region': 'ca',
          'establish_timeout_seconds': 0,
          'after_rounds': -1,
          'every_rounds': 0,
          'stages': 'all_closed',
          'tv': 'true',
        }),
      )!;
      expect(s.enabled, isFalse);
      expect(s.egressRegion, '');
      expect(s.establishTimeout, const Duration(seconds: 60));
      expect(s.afterRounds, 0);
      expect(s.everyRounds, 1);
      expect(s.stages, PsiphonSettings.defaultStages);
      expect(s.tv, isFalse);
      for (final region in ['CAN', 'C', 'C1', 12]) {
        expect(
          PsiphonSettings.fromJson(
            block({'egress_region': region}),
          )!.egressRegion,
          '',
        );
      }
      for (final timeout in [1.5, '60', 100000]) {
        expect(
          PsiphonSettings.fromJson(
            block({'establish_timeout_seconds': timeout}),
          )!.establishTimeout,
          const Duration(seconds: 60),
        );
      }
    });

    test('stages keeps only the words the app knows', () {
      final s = PsiphonSettings.fromJson(
        block({
          'stages': ['failed', 'allowance', 7, 'stopped', 'cut_off'],
        }),
      )!;
      expect(s.stages, {'failed', 'cut_off'});
      expect(
        PsiphonSettings.fromJson(block({'stages': const []}))!.stages,
        isEmpty,
      );
    });

    test('the tunnel gets the network, and the region only when one is '
        'set', () {
      final plain = PsiphonSettings.fromJson(block())!;
      expect(jsonDecode(plain.tunnelConfig), network);

      final canada = PsiphonSettings.fromJson(block({'egress_region': 'CA'}))!;
      expect(jsonDecode(canada.tunnelConfig), {
        ...network,
        'EgressRegion': 'CA',
      });
    });

    test('keys the phone owns never reach the tunnel from the block', () {
      final s = PsiphonSettings.fromJson(
        block({
          'network': {
            ...network,
            for (final k in PsiphonSettings.deviceKeys) k: 'x',
          },
        }),
      )!;
      final config = jsonDecode(s.tunnelConfig) as Map;
      for (final k in PsiphonSettings.deviceKeys) {
        expect(config.containsKey(k), isFalse, reason: k);
      }
      expect(config['SponsorId'], 'FEDCBA9876543210');
    });

    test('the round rule: from after_rounds on, every every_rounds', () {
      final every = PsiphonSettings.fromJson(block())!;
      expect(
        [for (var r = 0; r < 4; r++) every.allowsRound(r)],
        [true, true, true, true],
      );
      final later = PsiphonSettings.fromJson(
        block({'after_rounds': 2, 'every_rounds': 3}),
      )!;
      expect(
        [for (var r = 0; r < 9; r++) later.allowsRound(r)],
        [false, false, true, false, false, true, false, false, true],
      );
    });

    test('kept and read back the same', () {
      final s = PsiphonSettings.fromJson(
        block({
          'egress_region': 'DE',
          'establish_timeout_seconds': 45,
          'after_rounds': 1,
          'every_rounds': 2,
          'stages': ['failed'],
          'tv': true,
        }),
      )!;
      final again = PsiphonSettings.fromJson(
        jsonDecode(jsonEncode(s.toJson())),
      )!;
      expect(again.toJson(), s.toJson());
    });

    test('start_after_ms: none when it is missing, zero, or out of the '
        'backend\'s range', () {
      expect(PsiphonSettings.fromJson(block())!.startAfter, isNull);
      for (final ms in [0, -1, 2999, 120001, 5000.0, '5000', null, true]) {
        expect(
          PsiphonSettings.fromJson(block({'start_after_ms': ms}))!.startAfter,
          isNull,
          reason: '$ms',
        );
      }
      expect(
        PsiphonSettings.fromJson(block({'start_after_ms': 3000}))!.startAfter,
        const Duration(seconds: 3),
      );
      expect(
        PsiphonSettings.fromJson(block({'start_after_ms': 12500}))!.startAfter,
        const Duration(milliseconds: 12500),
      );
      expect(
        PsiphonSettings.fromJson(block({'start_after_ms': 120000}))!.startAfter,
        const Duration(minutes: 2),
      );
    });

    test('start_after_ms is kept between launches, and a block without it '
        'is saved as before', () {
      final s = PsiphonSettings.fromJson(block({'start_after_ms': 8000}))!;
      final again = PsiphonSettings.fromJson(
        jsonDecode(jsonEncode(s.toJson())),
      )!;
      expect(again.startAfter, const Duration(seconds: 8));
      expect(again.toJson(), s.toJson());
      expect(
        PsiphonSettings.fromJson(block())!.toJson().keys,
        isNot(contains('start_after_ms')),
      );
    });

    test('AppConfig reads the block, and a bad one keeps the rest of the '
        'config', () {
      expect(configWith(block()).psiphon, isNotNull);
      final bad = configWith('on');
      expect(bad.psiphon, isNull);
      expect(bad.supportEmail, 'support@example.com');
      expect(configWith(null).psiphon, isNull);
    });
  });

  group('kept between launches', () {
    test('off before the backend has ever answered', () async {
      final state = AppConfigState(fetch: unreachable, retryGaps: const []);
      await state.load();
      expect(PsiphonSettings.current, isNull);
    });

    test(
      'turned on by the backend and put back before the next fetch',
      () async {
        await AppConfigState(fetch: () async => configWith(block())).load();
        expect(PsiphonSettings.current, isNotNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey(AppConfigState.psiphonKey), isTrue);

        PsiphonSettings.current = null;
        // The next launch, while its fetch is in flight: the tap that needs
        // the backup network is on a line that blocks our calls.
        final answer = Completer<AppConfig>();
        final loading = AppConfigState(fetch: () => answer.future).load();
        await pumpEventQueue();
        expect(PsiphonSettings.current?.network, network);

        answer.complete(configWith(block()));
        await loading;
        expect(PsiphonSettings.current, isNotNull);
      },
    );

    test('kept when the next launch cannot reach the backend', () async {
      await AppConfigState(
        fetch: () async => configWith(block({'egress_region': 'CA'})),
      ).load();
      PsiphonSettings.current = null;

      await AppConfigState(fetch: unreachable, retryGaps: const []).load();
      expect(PsiphonSettings.current?.egressRegion, 'CA');
    });

    test('a config with the block off, or without it, removes it here and '
        'on the next launch', () async {
      for (final off in [
        null,
        {'enabled': false, 'network': null},
      ]) {
        SharedPreferences.setMockInitialValues({});
        await AppConfigState(fetch: () async => configWith(block())).load();
        await AppConfigState(fetch: () async => configWith(off)).load();
        expect(PsiphonSettings.current, isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey(AppConfigState.psiphonKey), isFalse);

        await AppConfigState(fetch: unreachable, retryGaps: const []).load();
        expect(PsiphonSettings.current, isNull);
      }
    });

    test('a saved copy that cannot be read leaves it off', () async {
      SharedPreferences.setMockInitialValues({
        AppConfigState.psiphonKey: '{not json',
      });
      await AppConfigState(fetch: unreachable, retryGaps: const []).load();
      expect(PsiphonSettings.current, isNull);
    });
  });

  group('the per-device answer', () {
    test('read from /configs/dedicated, and null from a backend without the '
        'field', () {
      expect(answer(psiphon: true).psiphon, isTrue);
      expect(answer(psiphon: false).psiphon, isFalse);
      expect(answer().psiphon, isNull);
      expect(
        DedicatedConfigs.fromJson({
          'configs': const <String>[],
          'quota': const {},
          'psiphon': 'true',
        }).psiphon,
        isNull,
      );
    });

    test('kept with the rest of the answer for the next launch', () async {
      final first = DedicatedState(
        fetch: ({viaTunnel}) async {
          return answer(psiphon: true);
        },
      );
      await first.refresh();
      expect(first.psiphon, isTrue);
      expect(first.psiphonDevice.allowed, isTrue);
      expect(first.psiphonDevice.quotaFresh, isTrue);
      // The save is not awaited by the refresh.
      await pumpEventQueue();

      final next = DedicatedState(
        fetch: ({viaTunnel}) async => throw Exception('no route'),
      );
      await next.refresh();
      expect(next.psiphon, isTrue);
      expect(next.psiphonDevice.quotaFresh, isFalse);
    });

    test('a later answer that says no replaces a yes', () async {
      var says = true;
      final state = DedicatedState(
        fetch: ({viaTunnel}) async => answer(psiphon: says),
      );
      await state.refresh();
      says = false;
      await state.refresh();
      expect(state.psiphon, isFalse);
    });

    test(
      'an answer from a backend without the field keeps the last one',
      () async {
        bool? says = true;
        final state = DedicatedState(
          fetch: ({viaTunnel}) async => answer(psiphon: says),
        );
        await state.refresh();
        says = null;
        await state.refresh();
        expect(state.psiphon, isTrue);
      },
    );

    test('a phone that never had the field has no answer', () async {
      final state = DedicatedState(fetch: ({viaTunnel}) async => answer());
      await state.refresh();
      expect(state.psiphon, isNull);
      expect(state.psiphonDevice.allowed, isNull);
    });

    // The backend says no to every device whose allowance is spent
    // (vpn_blocked_at). Taken at its word, that no outlasted the block: a
    // phone that could not reach the backend after the refill kept the
    // backup network off on exactly the day it needed it.
    test('an answer with the allowance spent leaves the last answer as it '
        'was, and the block keeps the network off meanwhile', () async {
      final answers = [
        answer(psiphon: true),
        answer(psiphon: false, blocked: true),
      ];
      final state = DedicatedState(
        fetch: ({viaTunnel}) async => answers.removeAt(0),
      );
      await state.refresh();
      await state.refresh();

      expect(state.psiphon, isTrue);
      expect(state.psiphonDevice.allowed, isTrue);
      expect(state.psiphonDevice.blocked, isTrue);
    });

    test('a phone whose first answer has the allowance spent has no answer '
        'yet', () async {
      final state = DedicatedState(
        fetch: ({viaTunnel}) async => answer(psiphon: false, blocked: true),
      );
      await state.refresh();
      expect(state.psiphon, isNull);
    });

    test('the next launch after the refill, with the backend out of reach, '
        'lets the device use the network again', () async {
      var clock = DateTime.now();
      final answers = [
        answer(psiphon: true),
        answer(psiphon: false, blocked: true),
      ];
      final first = DedicatedState(
        now: () => clock,
        fetch: ({viaTunnel}) async => answers.removeAt(0),
      );
      await first.refresh();
      await first.refresh();
      // The save is not awaited by the refresh.
      await pumpEventQueue();

      // Past the refill time of the blocked answer (answer: in 3 hours).
      clock = clock.add(const Duration(hours: 4));
      final next = DedicatedState(
        now: () => clock,
        fetch: ({viaTunnel}) async => throw Exception('no route'),
      );
      await next.refresh();

      expect(next.psiphon, isTrue);
      expect(next.isBlocked, isFalse);
      final device = next.psiphonDevice;
      expect(device.allowed, isTrue);
      expect(device.blocked, isFalse);
      expect(device.quotaSpent, isFalse);
    });

    test('a no from before the block is kept through it too', () async {
      var clock = DateTime.now();
      final answers = [
        answer(psiphon: false),
        answer(psiphon: false, blocked: true),
      ];
      final first = DedicatedState(
        now: () => clock,
        fetch: ({viaTunnel}) async => answers.removeAt(0),
      );
      await first.refresh();
      await first.refresh();
      await pumpEventQueue();

      clock = clock.add(const Duration(hours: 4));
      final next = DedicatedState(
        now: () => clock,
        fetch: ({viaTunnel}) async => throw Exception('no route'),
      );
      await next.refresh();

      expect(next.psiphon, isFalse);
    });

    // The shape _save writes for an answer with the allowance spent: the
    // answer as it came, with the psiphon field as the phone held it.
    test('a kept answer whose allowance has refilled still says whether the '
        'device may use the network', () async {
      SharedPreferences.setMockInitialValues({
        DedicatedState.prefSaved: jsonEncode({
          'at': DateTime.now().toUtc().toIso8601String(),
          'body': {
            'configs': const <String>[],
            'quota': {
              'unlimited': false,
              'limit_bytes': 100,
              'used_bytes': 100,
              'remaining_bytes': 0,
              'blocked': true,
              'resets_at': DateTime.now()
                  .toUtc()
                  .subtract(const Duration(hours: 1))
                  .toIso8601String(),
            },
            'psiphon': true,
          },
        }),
      });
      final state = DedicatedState();
      await state.restoreSaved();
      expect(state.psiphon, isTrue);
    });

    test(
      'the device facts carry the allowance as the phone last heard it',
      () async {
        final state = DedicatedState(
          fetch: ({viaTunnel}) async => answer(psiphon: false, blocked: true),
        );
        await state.refresh();
        final device = state.psiphonDevice;
        expect(device.blocked, isTrue);
        expect(device.quotaSpent, isTrue);
      },
    );

    test('an account deletion forgets it', () async {
      final state = DedicatedState(
        fetch: ({viaTunnel}) async => answer(psiphon: true),
      );
      await state.refresh();
      state.reset();
      expect(state.psiphon, isNull);
    });
  });

  group('what the allowance says', () {
    test('spent, or nothing left on a metered allowance', () {
      expect(PsiphonDevice(quota: quota()).quotaSpent, isFalse);
      expect(PsiphonDevice(quota: quota(blocked: true)).quotaSpent, isTrue);
      expect(
        const PsiphonDevice(
          quota: QuotaStatus(
            unlimited: false,
            limitBytes: 100,
            usedBytes: 100,
            remainingBytes: 0,
            blocked: false,
          ),
        ).quotaSpent,
        isTrue,
      );
      // Unmetered: nothing to run out of.
      expect(
        const PsiphonDevice(
          quota: QuotaStatus(
            unlimited: true,
            limitBytes: 0,
            usedBytes: 5,
            remainingBytes: 0,
            blocked: false,
          ),
        ).quotaSpent,
        isFalse,
      );
      expect(const PsiphonDevice().quotaSpent, isFalse);
    });
  });
}
