import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/data/models/connection_data.dart';
import 'package:fortiva_vpn/data/models/door_outbound.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/ping_service.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/utils/tls_fragment.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A door entry of the /configs/dedicated answer may carry the backend's
/// own outbound for the door (variant loop contract v2, section 2). Android
/// then dials that outbound wherever it would build one from the door's
/// link. These tests check what the app reads and what it hands to the
/// native side: exactly what origin/main sends for doors without one, and
/// the outbound beside the link for doors with one.

const _uuid = 'b831381d-6324-4d53-ad4f-8cda48b30811';

const _reality =
    'vless://$_uuid@203.0.113.7:8443?type=xhttp&security=reality'
    '&sni=www.samsung.com&pbk=key&fp=chrome#Row13';
const _tls =
    'vless://$_uuid@198.51.100.215:443?type=ws&security=tls'
    '&sni=cdn.example.site&path=%2Fws&fragment=tlshello,10-20,1-2#Row13';
const _realityV6 =
    'vless://$_uuid@[2001:db8::7]:8443?type=xhttp&security=reality'
    '&sni=www.samsung.com&pbk=key&fp=chrome#Row13';

/// A TLS door link that names no split: Android adds the app's own.
const _tlsBare =
    'vless://$_uuid@198.51.100.215:443?type=ws&security=tls'
    '&sni=cdn.example.site&path=%2Fws#Row13';

final Map<String, dynamic> _outbound = {
  'tag': 'proxy',
  'protocol': 'hysteria',
  'settings': {'version': 2, 'address': '203.0.113.7', 'port': 443},
  'streamSettings': {
    'network': 'hysteria',
    'hysteriaSettings': {'version': 2, 'auth': 'secret'},
  },
};

final Map<String, dynamic> _helper = {
  'tag': 'fragment',
  'protocol': 'freedom',
  'settings': {
    'fragment': {'packets': 'tlshello', 'length': '100-200'},
  },
};

Map<String, dynamic> _path(
  String uri,
  String door, {
  Object? outbound,
  Object? helpers,
}) => {
  'server_id': 13,
  'inbound_id': 2,
  'door': door,
  'label': door,
  'uri': uri,
  'preferred': door == 'xhttp-reality',
  'outbound': ?outbound,
  'helper_outbounds': ?helpers,
};

/// An answer with the three doors, the first and the last with the
/// backend's outbound when [withOutbounds].
Map<String, dynamic> _answer({bool withOutbounds = false}) => {
  'configs': [_reality],
  'paths': [
    _path(
      _reality,
      'xhttp-reality',
      outbound: withOutbounds ? _outbound : null,
      helpers: withOutbounds ? [_helper] : null,
    ),
    _path(_tls, 'ws-tls'),
    _path(
      _realityV6,
      'xhttp-reality-v6',
      outbound: withOutbounds ? _outbound : null,
    ),
  ],
  'quota': {
    'unlimited': false,
    'limit_bytes': 100,
    'used_bytes': 10,
    'remaining_bytes': 90,
    'blocked': false,
  },
};

class _FakeDiagnostics extends ConnectDiagnostics {
  @override
  Future<Map<String, dynamic>> collect({
    String? host,
    int port = 443,
    String? sni,
  }) async => const {};

  @override
  Future<Map<String, dynamic>> platformReport() async => const {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TlsFragment.spec = TlsFragment.builtIn;
    TlsFragment.doorSpec = null;
    DoorOutbounds.adopt(const {});
    calls = [];
    messenger.setMockMethodCallHandler(tunnel, (call) async {
      calls.add(call);
      if (call.method == 'getStatus') return 'disconnected';
      if (call.method == 'realPing') return 180;
      if (call.method == 'realPingDetail') return {'ms': 180};
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(tunnel, null);
    TlsFragment.spec = TlsFragment.builtIn;
    TlsFragment.doorSpec = null;
    DoorOutbounds.adopt(const {});
    ConnectionData.current = ConnectionData.off;
  });

  Future<DedicatedState> adopted(Map<String, dynamic> body) async {
    final state = DedicatedState(
      fetch: ({bool? viaTunnel}) async => DedicatedConfigs.fromJson(body),
    );
    await state.refresh();
    return state;
  }

  group('reading a door entry', () {
    test('a door without an outbound has none', () {
      expect(DedicatedPath.fromJson(_path(_reality, 'r')).outbound, isNull);
      expect(DoorOutbound.fromPath(const {}), isNull);
    });

    test('a door with one keeps it as the backend wrote it', () {
      final o = DedicatedPath.fromJson(
        _path(_reality, 'r', outbound: _outbound, helpers: [_helper]),
      ).outbound!;
      expect(o.outbound, _outbound);
      expect(o.helpers, [_helper]);
      expect(jsonDecode(o.native), {
        'outbound': _outbound,
        'helper_outbounds': [_helper],
      });
      expect(DoorOutbound.fromPath({'outbound': _outbound})!.helpers, isEmpty);
    });

    test('an outbound the app cannot use is none, and the door keeps its '
        'link', () {
      final bad = <Map<String, dynamic>>[
        {'outbound': 'vless://x'},
        {'outbound': <String, dynamic>{}},
        {
          'outbound': {'protocol': 'vless'},
        },
        {
          'outbound': {'tag': 'proxy'},
        },
        {
          'outbound': {'tag': ' ', 'protocol': 'vless'},
        },
        {'outbound': _outbound, 'helper_outbounds': _helper},
        {
          'outbound': _outbound,
          'helper_outbounds': ['fragment'],
        },
        {
          'outbound': _outbound,
          'helper_outbounds': [
            {'tag': 'fragment'},
          ],
        },
        {
          'outbound': _outbound,
          'helper_outbounds': [_helper, _helper],
        },
        for (final tag in ['proxy', 'proxy@2', 'direct', 'block', 'dns-out'])
          {
            'outbound': _outbound,
            'helper_outbounds': [
              {'tag': tag, 'protocol': 'freedom'},
            ],
          },
      ];
      for (final json in bad) {
        expect(DoorOutbound.fromPath(json), isNull, reason: '$json');
        final p = DedicatedPath.fromJson(_path(_reality, 'r')..addAll(json));
        expect(p.outbound, isNull);
        expect(p.uri, _reality);
      }
    });

    test('the doors are the same servers with or without outbounds', () async {
      final plain = await adopted(_answer());
      final withOutbounds = await adopted(_answer(withOutbounds: true));
      expect(
        [for (final s in withOutbounds.paths) s.toJson()],
        [for (final s in plain.paths) s.toJson()],
      );
      expect(
        [for (final s in withOutbounds.servers) s.toJson()],
        [for (final s in plain.servers) s.toJson()],
      );
    });
  });

  group('the device state', () {
    test('takes in the outbounds of its doors, by link', () async {
      await adopted(_answer(withOutbounds: true));
      expect(jsonDecode(DoorOutbounds.nativeFor(_reality, _reality)!), {
        'outbound': _outbound,
        'helper_outbounds': [_helper],
      });
      expect(DoorOutbounds.nativeFor(_tls, _tls), isNull);
      expect(DoorOutbounds.nativeFor(_realityV6, _realityV6), isNotNull);
    });

    test('a later answer without them drops them', () async {
      await adopted(_answer(withOutbounds: true));
      await adopted(_answer());
      expect(DoorOutbounds.nativeFor(_reality, _reality), isNull);
    });

    test('keeps them with the doors in its saved copy', () async {
      await adopted(_answer(withOutbounds: true));
      await pumpEventQueue();
      DoorOutbounds.adopt(const {});

      // A launch that cannot reach the backend.
      final offline = DedicatedState(
        fetch: ({bool? viaTunnel}) async =>
            throw ApiException(statusCode: 0, message: 'No internet'),
      );
      await offline.refresh();

      expect(offline.fromSaved, isTrue);
      expect(DoorOutbounds.nativeFor(_reality, _reality), isNotNull);
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString(DedicatedState.prefSaved)!);
      final paths = (saved as Map)['body']['paths'] as List;
      expect((paths.first as Map)['outbound'], _outbound);
      expect((paths.first as Map)['helper_outbounds'], [_helper]);
    });

    test('an account deletion drops them', () async {
      final state = await adopted(_answer(withOutbounds: true));
      state.reset();
      expect(DoorOutbounds.nativeFor(_reality, _reality), isNull);
    });
  });

  group('door checks', () {
    Map<Object?, Object?> args(MethodCall call) =>
        call.arguments as Map<Object?, Object?>;

    /// The arguments every door check sends for [link] on origin/main.
    Map<Object?, Object?> mainArgs(String link, {int? timeoutMs}) => {
      'link': link,
      'splitter': TlsFragment.builtIn,
      'timeoutMs': ?timeoutMs,
    };

    Future<void> checkAll(List<Server> doors) async {
      for (final d in doors) {
        await PingService().readDoor(d);
        await PingService().readDoor(
          d,
          coreTimeout: const Duration(seconds: 4),
        );
        await PingService().pingServer(d);
      }
    }

    test('a door without an outbound is checked exactly as before', () async {
      ConnectionData.current = const ConnectionData(timedChecks: true);
      final state = await adopted(_answer());
      calls.clear();
      await checkAll(state.paths);

      final expected = <List<Object?>>[
        for (final link in [_reality, _tls, _realityV6]) ...[
          [
            'realPingDetail',
            {...mainArgs(link), 'timed': true},
          ],
          [
            'realPingDetail',
            {...mainArgs(link, timeoutMs: 4000), 'timed': true},
          ],
          ['realPing', mainArgs(link)],
        ],
      ];
      expect([
        for (final c in calls) [c.method, args(c)],
      ], expected);
    });

    test('a door with one sends it beside its link, and the others send '
        'what they sent before', () async {
      final state = await adopted(_answer(withOutbounds: true));
      calls.clear();
      await checkAll(state.paths);

      final native = DoorOutbounds.nativeFor(_reality, _reality)!;
      final v6 = DoorOutbounds.nativeFor(_realityV6, _realityV6)!;
      final expected = <List<Object?>>[
        [
          'realPingDetail',
          {...mainArgs(_reality), 'doorOutbound': native},
        ],
        [
          'realPingDetail',
          {...mainArgs(_reality, timeoutMs: 4000), 'doorOutbound': native},
        ],
        [
          'realPing',
          {...mainArgs(_reality), 'doorOutbound': native},
        ],
        ['realPingDetail', mainArgs(_tls)],
        ['realPingDetail', mainArgs(_tls, timeoutMs: 4000)],
        ['realPing', mainArgs(_tls)],
        [
          'realPingDetail',
          {...mainArgs(_realityV6), 'doorOutbound': v6},
        ],
        [
          'realPingDetail',
          {...mainArgs(_realityV6, timeoutMs: 4000), 'doorOutbound': v6},
        ],
        [
          'realPing',
          {...mainArgs(_realityV6), 'doorOutbound': v6},
        ],
      ];
      expect([
        for (final c in calls) [c.method, args(c)],
      ], expected);
    });

    test('a link the app rewrites before it dials keeps to the link', () {
      DoorOutbounds.adopt({
        _tlsBare: DoorOutbound.fromPath({'outbound': _outbound})!,
      });
      // Android adds the app's split to a TLS link that names none, which
      // makes it a link the outbound was not built from.
      final sent = TlsFragment.apply(_tlsBare, android: true);
      expect(sent, isNot(_tlsBare));
      expect(DoorOutbounds.nativeFor(_tlsBare, sent), isNull);
      expect(DoorOutbounds.nativeFor(_tlsBare, _tlsBare), isNotNull);
    });
  });

  group('connect', () {
    late Map<Object?, Object?> sent;
    late VpnService service;

    setUp(() {
      sent = {};
      messenger.setMockMethodCallHandler(tunnel, (call) async {
        if (call.method == 'connect') {
          sent = Map.of(call.arguments as Map<Object?, Object?>);
        }
        return call.method == 'getStatus' ? 'disconnected' : null;
      });
      service = VpnService(
        events: VpnEventReporter(send: (_, _, _) async {}),
        diagnostics: _FakeDiagnostics(),
      );
    });

    tearDown(() => service.dispose());

    /// What origin/main sends to connect through [doors], the first dialled
    /// and the rest standing by.
    Map<Object?, Object?> mainConnect(List<Server> doors) => {
      'link': doors.first.connectionUri,
      if (doors.length > 1) ...{
        'alternates': [for (final d in doors.skip(1)) d.connectionUri],
        'exits': [for (final d in doors) d.serverId?.toString() ?? ''],
      },
      'session_sample_ms': 0,
      'session_stall_ms': 0,
      'session_busy_bytes': 0,
    };

    test('doors without outbounds connect exactly as before, alone or with '
        'standby doors', () async {
      final doors = (await adopted(_answer())).paths;

      await service.connect(doors.first);
      expect(sent, mainConnect(doors.take(1).toList()));

      await service.connect(doors.first, standby: doors.skip(1).toList());
      expect(sent, mainConnect(doors));

      await service.connect(doors[1], standby: [doors[2]]);
      expect(sent, mainConnect([doors[1], doors[2]]));
    });

    test('doors with outbounds send them in the order of the doors, "" for '
        'a door without one', () async {
      final doors = (await adopted(_answer(withOutbounds: true))).paths;
      final first = DoorOutbounds.nativeFor(_reality, _reality)!;
      final last = DoorOutbounds.nativeFor(_realityV6, _realityV6)!;

      await service.connect(doors.first, standby: doors.skip(1).toList());
      expect(sent, {
        ...mainConnect(doors),
        'doorOutbounds': [first, '', last],
      });

      await service.connect(doors.first);
      expect(sent, {
        ...mainConnect(doors.take(1).toList()),
        'doorOutbounds': [first],
      });

      // Only the door without one: nothing new is sent.
      await service.connect(doors[1]);
      expect(sent, mainConnect([doors[1]]));
    });
  });
}
