import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/saved_tunnel.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/utils/standby_doors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The backend's switches for community links: calls on the relays while
/// the tunnel goes through a community server, and the move back to our
/// servers. Read from the config, kept between launches, and turned off by
/// a config without them.
Map<String, dynamic> _json({
  Map<String, dynamic> flags = const {},
  Map<String, dynamic> top = const {},
}) => {
  'privacy_policy_url': 'https://example.com/privacy',
  'terms_of_service_url': 'https://example.com/terms',
  'eula_url': 'https://example.com/eula',
  'support_email': 'support@example.com',
  'force_update': {
    for (final os in ['ios', 'android'])
      os: {
        'latest_version': '1.0.0',
        'minimum_version': '1.0.0',
        'update_url': 'https://example.com/update',
      },
  },
  'feature_flags': flags,
  ...top,
};

Server _own(String host, {String door = 'xhttp-reality'}) => Server(
  id: 'dedicated-$host:443',
  name: host,
  country: '',
  city: host,
  connectionUri: 'vless://u@$host:443?type=tcp#$host',
  flagEmoji: '',
  isDedicated: true,
  door: door,
  doorLabel: door,
);

Server _community(String host) => Server(
  id: '${Server.communityIdPrefix}$host',
  name: 'Community 1',
  country: '',
  city: '',
  connectionUri: 'vless://u@$host:443?type=tcp&security=tls#c',
  flagEmoji: '',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.relaysOnCommunity = false;
    StandbyDoors.enabled = false;
    StandbyDoors.moveBack = false;
    StandbyDoors.moveBackEvery = null;
    StandbyDoors.androidOverride = null;
  });

  tearDown(() {
    ApiClient.relaysOnCommunity = false;
    StandbyDoors.enabled = false;
    StandbyDoors.moveBack = false;
    StandbyDoors.moveBackEvery = null;
    StandbyDoors.androidOverride = null;
  });

  group('reading the config', () {
    FeatureFlags flags(Map<String, dynamic> f) =>
        AppConfig.fromJson(_json(flags: f)).featureFlags;

    test('without the keys every switch is off', () {
      final f = flags({});
      expect(f.apiViaRelaysOnCommunity, isFalse);
      expect(f.moveBackToOwn, isFalse);
      expect(f.moveBackEvery, isNull);
      expect(f.enableKillSwitch, isFalse);
      expect(const FeatureFlags().enableKillSwitch, isFalse);
    });

    test('the keys turn them on', () {
      final f = flags({
        'api_via_relays_on_community': true,
        'move_back_to_own': true,
        'move_back_every_s': 45,
        'enable_kill_switch': true,
      });
      expect(f.apiViaRelaysOnCommunity, isTrue);
      expect(f.moveBackToOwn, isTrue);
      expect(f.moveBackEvery, const Duration(seconds: 45));
      expect(f.enableKillSwitch, isTrue);
    });

    test('an interval below the floor, or not a whole number, is none', () {
      for (final v in [29, -1, 45.0, '60', null]) {
        expect(
          flags({'move_back_every_s': v}).moveBackEvery,
          isNull,
          reason: '$v',
        );
      }
      expect(
        flags({'move_back_every_s': 30}).moveBackEvery,
        const Duration(seconds: 30),
      );
    });

    test(
      'a value of the wrong type turns its switch off and keeps the rest',
      () {
        final config = AppConfig.fromJson(
          _json(
            flags: {
              'api_via_relays_on_community': 'true',
              'move_back_to_own': 1,
              'enable_kill_switch': 'true',
              'standby_doors': true,
            },
          ),
        );
        expect(config.featureFlags.apiViaRelaysOnCommunity, isFalse);
        expect(config.featureFlags.moveBackToOwn, isFalse);
        expect(config.featureFlags.enableKillSwitch, isFalse);
        expect(config.featureFlags.standbyDoors, isTrue);
        expect(config.forceUpdate.android.minimumVersion, '1.0.0');
      },
    );

    test('the keys are read at the top level too', () {
      final f = AppConfig.fromJson(
        _json(
          top: {
            'api_via_relays_on_community': true,
            'move_back_to_own': true,
            'move_back_every_s': 60,
          },
        ),
      ).featureFlags;
      expect(f.apiViaRelaysOnCommunity, isTrue);
      expect(f.moveBackToOwn, isTrue);
      expect(f.moveBackEvery, const Duration(seconds: 60));
    });

    test('they survive a round trip', () {
      final f = flags({
        'api_via_relays_on_community': true,
        'move_back_to_own': true,
        'move_back_every_s': 90,
      });
      final again = FeatureFlags.fromJson(f.toJson());
      expect(again.apiViaRelaysOnCommunity, isTrue);
      expect(again.moveBackToOwn, isTrue);
      expect(again.moveBackEvery, const Duration(seconds: 90));
    });
  });

  group('keeping them', () {
    final on = AppConfig.fromJson(
      _json(
        flags: {
          'api_via_relays_on_community': true,
          'move_back_to_own': true,
          'move_back_every_s': 60,
        },
      ),
    );
    Future<AppConfig> unreachable() async => throw Exception('no route');

    test('a config that lands puts them in force and saves them', () async {
      await AppConfigState(fetch: () async => on, retryGaps: const []).load();
      expect(ApiClient.relaysOnCommunity, isTrue);
      expect(StandbyDoors.moveBack, isTrue);
      expect(StandbyDoors.moveBackEvery, const Duration(seconds: 60));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppConfigState.relaysOnCommunityKey), isTrue);
      expect(jsonDecode(prefs.getString(AppConfigState.moveBackKey)!), {
        'every_s': 60,
      });
    });

    test('a launch whose fetch fails keeps the saved ones', () async {
      await AppConfigState(fetch: () async => on, retryGaps: const []).load();
      ApiClient.relaysOnCommunity = false;
      StandbyDoors.moveBack = false;
      StandbyDoors.moveBackEvery = null;
      await AppConfigState(fetch: unreachable, retryGaps: const []).load();
      expect(ApiClient.relaysOnCommunity, isTrue);
      expect(StandbyDoors.moveBack, isTrue);
      expect(StandbyDoors.moveBackEvery, const Duration(seconds: 60));
    });

    test('a config without the keys turns them off for good', () async {
      await AppConfigState(fetch: () async => on, retryGaps: const []).load();
      await AppConfigState(
        fetch: () async => AppConfig.fromJson(_json()),
        retryGaps: const [],
      ).load();
      expect(ApiClient.relaysOnCommunity, isFalse);
      expect(StandbyDoors.moveBack, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(AppConfigState.relaysOnCommunityKey), isFalse);
      expect(prefs.containsKey(AppConfigState.moveBackKey), isFalse);
    });

    test('the engines with no screen read the saved switch', () async {
      SharedPreferences.setMockInitialValues({
        AppConfigState.relaysOnCommunityKey: true,
      });
      await AppConfigState.restoreApiRouting();
      expect(ApiClient.relaysOnCommunity, isTrue);
    });
  });

  group('the saved tunnel, for the engines with no screen', () {
    String saved(Map<String, dynamic> facts) => jsonEncode(facts);

    test('a community source, or a community link among the doors, is '
        'community', () {
      expect(
        SavedTunnel.fromSaved(
          saved({
            'strategy': {'src': 'community_fallback'},
          }),
        ),
        isTrue,
      );
      expect(
        SavedTunnel.fromSaved(
          saved({
            'strategy': {'src': 'community_pick'},
          }),
        ),
        isTrue,
      );
      expect(
        SavedTunnel.fromSaved(
          saved({
            'strategy': {'src': 'own'},
            'community_held': true,
          }),
        ),
        isTrue,
      );
    });

    test('our own sources are not', () {
      for (final src in ['own', 'official_shared', 'psiphon']) {
        expect(
          SavedTunnel.fromSaved(
            saved({
              'strategy': {'src': src},
            }),
          ),
          isFalse,
        );
      }
    });

    test('nothing saved, or nothing readable, is not known', () async {
      expect(SavedTunnel.fromSaved(null), isNull);
      expect(SavedTunnel.fromSaved('{'), isNull);
      expect(SavedTunnel.fromSaved(saved({'door': 'x'})), isNull);
      expect(await SavedTunnel.onCommunity(), isNull);
      SharedPreferences.setMockInitialValues({
        VpnService.attemptKey: saved({
          'strategy': {'src': 'community_fallback'},
        }),
      });
      expect(await SavedTunnel.onCommunity(), isTrue);
    });
  });

  group('our doors behind a community link', () {
    final link = _community('203.0.113.50');
    final pool = [
      _own('198.51.100.1'),
      _own('198.51.100.1', door: 'ws-tls'),
      _own('198.51.100.2'),
      _own('2001:db8::2', door: 'xhttp-reality-v6'),
    ];

    test('none while the switch, standby doors or Android are off', () {
      StandbyDoors.androidOverride = true;
      StandbyDoors.enabled = true;
      expect(StandbyDoors.ownBehind(link, pool, slots: 3), isEmpty);
      StandbyDoors.moveBack = true;
      StandbyDoors.enabled = false;
      expect(StandbyDoors.ownBehind(link, pool, slots: 3), isEmpty);
      StandbyDoors.enabled = true;
      expect(
        StandbyDoors.ownBehind(link, pool, slots: 3, android: false),
        isEmpty,
      );
    });

    test('none behind one of our own doors', () {
      StandbyDoors.androidOverride = true;
      StandbyDoors.enabled = true;
      StandbyDoors.moveBack = true;
      expect(StandbyDoors.ownBehind(pool.first, pool, slots: 3), isEmpty);
    });

    test('distinct addresses first, in the slots given, IPv6 left out when '
        'the network has none', () {
      StandbyDoors.androidOverride = true;
      StandbyDoors.enabled = true;
      StandbyDoors.moveBack = true;
      final held = StandbyDoors.ownBehind(link, pool, slots: 2, ipv6: false);
      expect(held.map((s) => s.connectionUri), [
        pool[0].connectionUri,
        pool[2].connectionUri,
      ]);
      expect(StandbyDoors.ownBehind(link, pool, slots: 4), hasLength(4));
      expect(StandbyDoors.ownBehind(link, pool, slots: 0), isEmpty);
    });

    test('the connect names their positions and the interval', () {
      final spare = _community('203.0.113.51');
      expect(
        VpnService.moveBackArgs(link, [
          spare,
          pool[0],
          pool[2],
        ], every: const Duration(seconds: 60)),
        {
          'own_doors': [2, 3],
          'move_back_every_s': 60,
        },
      );
      expect(VpnService.moveBackArgs(link, [spare, pool[0]]), {
        'own_doors': [2],
      });
      expect(VpnService.moveBackArgs(link, [spare]), isEmpty);
      expect(VpnService.moveBackArgs(pool[0], [pool[2]]), isEmpty);
      expect(
        VpnService.moveBackArgs(link, [
          pool[0],
        ], every: const Duration(seconds: 10)),
        {
          'own_doors': [1],
        },
      );
    });
  });
}
