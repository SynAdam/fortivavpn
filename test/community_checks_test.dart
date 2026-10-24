import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/community_checks.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/ping_service.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/utils/link_id.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The fallback and "Test all" check community links from phones in Iran,
/// and the backend hears what they found: POST
/// /api/v1/devices/{id}/community-checks. The endpoint may not exist yet,
/// so every failure has to be quiet, with one more try at most.

const _nl = 'vless://c@nl.example:443?type=tcp&security=reality#NL';
const _de = 'trojan://pw@de.example:8443?security=tls#DE';

CommunityCheck check(
  String link, {
  bool ok = true,
  int? ms = 300,
  String? error,
  CommunityCheckKind kind = CommunityCheckKind.fallback,
}) => CommunityCheck(
  link: link,
  kind: kind,
  ok: ok,
  ms: ms,
  error: error,
  at: DateTime.utc(2026, 10, 7, 10, 30),
);

/// [n] distinct links.
List<CommunityCheck> many(int n) => [
  for (var i = 0; i < n; i++) check('vless://u$i@h$i.example:443?type=tcp'),
];

class _Sent {
  _Sent(this.deviceId, this.checks, this.viaTunnel);
  final String deviceId;
  final List<Map<String, dynamic>> checks;
  final bool viaTunnel;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<_Sent> sent;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sent = [];
  });

  /// A reporter whose sender answers each upload with what [answer]
  /// returns for it: null for success, or the error to throw.
  CommunityChecks reporter({
    Object? Function(int call)? answer,
    bool? throughTunnel = false,
  }) {
    var calls = 0;
    return CommunityChecks(
      send: (deviceId, checks, viaTunnel) async {
        final error = answer?.call(calls++);
        sent.add(_Sent(deviceId, checks, viaTunnel));
        if (error != null) throw error;
      },
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.6.14',
      platform: 'android',
      networkType: () async => 'mobile',
      carrier: () async => 'MCI',
      throughTunnel: throughTunnel == null ? null : () => throughTunnel == true,
    );
  }

  group('the row', () {
    test('names the link without carrying it', () async {
      await reporter().report([check(_nl, ms: 412)], carrier: 'Irancell');

      final row = sent.single.checks.single;
      expect(row, {
        'lid': LinkId.of(_nl),
        'scheme': 'vless',
        'host': 'nl.example',
        'port': 443,
        'kind': 'fallback',
        'ok': true,
        'ms': 412,
        'error': null,
        'app_version': '1.6.14',
        'platform': 'android',
        'network_type': 'mobile',
        'carrier': 'Irancell',
        'client_ts': '2026-10-07T10:30:00.000Z',
      });
      expect(row.values.join(' '), isNot(contains('c@nl')));
    });

    test('a failed check keeps its reason and how long it took', () async {
      await reporter().report([
        check(_de, ok: false, ms: 4012, error: 'x' * 500),
      ]);

      final row = sent.single.checks.single;
      expect(row['scheme'], 'trojan');
      expect(row['port'], 8443);
      expect(row['ok'], isFalse);
      expect(row['ms'], 4012);
      expect((row['error'] as String).length, 200);
      // The reporter's own reading when the caller has none.
      expect(row['carrier'], 'MCI');
    });

    test('a link with no readable host sends null, not a guess', () {
      final row = CommunityChecks.row(
        check('ss://YWVzLTEyOC1nY206cHdAMS4yLjMuNDo4Mzg4', ms: -1),
        appVersion: '1',
        platform: 'android',
      )!;
      expect(row['scheme'], 'ss');
      expect(row['host'], isNull);
      expect(row['port'], isNull);
      expect(row['ms'], isNull);
      expect(row['network_type'], isNull);
    });

    test('a link of a kind the app never dials is not sent', () async {
      await reporter().report([check('hy2://pw@h:443'), check(_nl)]);
      expect(sent.single.checks.map((r) => r['scheme']), ['vless']);
    });
  });

  group('uploads', () {
    test('at most 16 checks each, in order', () async {
      await reporter().report(many(40));

      expect(sent.map((s) => s.checks.length), [16, 16, 8]);
      expect(sent.first.checks.first['lid'], LinkId.of(many(1).single.link));
      expect(sent.map((s) => s.deviceId).toSet(), {'DEV-1'});
    });

    test('always say they went around the tunnel', () async {
      await reporter().report(many(2));
      expect(sent.single.viaTunnel, isFalse);
    });

    test('the default sender posts to the endpoint, sent_at in UTC', () async {
      final posted = <(String, Map<String, dynamic>)>[];
      final r = CommunityChecks(
        post: (path, body) async => posted.add((path, body)),
        clock: () => DateTime.utc(2026, 10, 7, 11),
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.14',
        platform: 'android',
        networkType: () async => null,
        carrier: () async => null,
        throughTunnel: () => false,
      );

      await r.report(many(1));

      final (path, body) = posted.single;
      expect(path, '/api/v1/devices/DEV-1/community-checks');
      expect(body.keys, ['checks', 'via_tunnel', 'sent_at']);
      expect(body['via_tunnel'], isFalse);
      expect(body['sent_at'], '2026-10-07T11:00:00.000Z');
      expect(body['checks'], hasLength(1));
    });

    test('two reports go one after the other, not side by side', () async {
      final gate = Completer<void>();
      final order = <String>[];
      final r = CommunityChecks(
        send: (_, checks, _) async {
          order.add('start ${checks.length}');
          if (checks.length == 1) await gate.future;
          order.add('end ${checks.length}');
        },
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1',
        platform: 'android',
        networkType: () async => null,
        carrier: () async => null,
        throughTunnel: () => false,
      );

      final first = r.report(many(1));
      final second = r.report(many(2));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      gate.complete();
      await Future.wait([first, second]);

      expect(order, ['start 1', 'end 1', 'start 2', 'end 2']);
    });
  });

  group('what stops a report', () {
    test('the diagnostics switch turned off', () async {
      SharedPreferences.setMockInitialValues({
        VpnEventReporter.sharePrefKey: false,
      });
      await reporter().report(many(3));
      expect(sent, isEmpty);
    });

    test('the app\'s requests going through the tunnel', () async {
      await reporter(throughTunnel: true).report(many(3));
      expect(sent, isEmpty);
    });

    test('nobody having said where they go', () async {
      await reporter(throughTunnel: null).report(many(3));
      expect(sent, isEmpty);
    });

    test('the switch turned off between uploads', () async {
      final r = CommunityChecks(
        send: (_, checks, _) async {
          sent.add(_Sent('DEV-1', checks, false));
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(VpnEventReporter.sharePrefKey, false);
        },
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1',
        platform: 'android',
        networkType: () async => null,
        carrier: () async => null,
        throughTunnel: () => false,
      );

      await r.report(many(40));

      expect(sent, hasLength(1));
    });
  });

  group('failures are quiet', () {
    test('a backend without the endpoint: one try, then nothing', () async {
      final r = reporter(
        answer: (_) => ApiException(statusCode: 404, message: 'Not Found'),
      );

      await r.report(many(40));

      expect(sent, hasLength(1));
    });

    test('an upload the backend refuses is not sent again', () async {
      final r = reporter(
        answer: (_) => ApiException(statusCode: 422, message: 'invalid'),
      );

      await r.report(many(3));

      expect(sent, hasLength(1));
    });

    test('no answer: one more try, then the rest is dropped', () async {
      final r = reporter(answer: (_) => const SocketException('cut'));

      await r.report(many(40));

      expect(sent, hasLength(2));
      expect(sent[0].checks, sent[1].checks);
    });

    test('a fault on our side: one more try', () async {
      final r = reporter(
        answer: (_) => ApiException(statusCode: 502, message: 'bad gateway'),
      );

      await r.report(many(3));

      expect(sent, hasLength(2));
    });

    test('a second try that works carries on with the rest', () async {
      final r = reporter(
        answer: (call) =>
            call == 0 ? ApiException(statusCode: 503, message: 'busy') : null,
      );

      await r.report(many(20));

      expect(sent.map((s) => s.checks.length), [16, 16, 4]);
    });

    test('a failure never reaches the caller', () async {
      final r = CommunityChecks(
        send: (_, _, _) async => throw StateError('boom'),
        deviceId: () async => throw StateError('no id'),
        appVersion: () async => '1',
        platform: 'android',
        networkType: () async => null,
        carrier: () async => null,
        throughTunnel: () => false,
      );

      await expectLater(r.report(many(2)), completes);
    });

    test('a report after a failed one still goes', () async {
      final r = reporter(
        answer: (call) =>
            call < 2 ? ApiException(statusCode: 500, message: 'x') : null,
      );

      await r.report(many(1));
      await r.report(many(1));

      expect(sent, hasLength(3));
    });
  });

  group('the fallback reports what it checked', () {
    Server community(String uri, int index) =>
        Server.fromConnectionUri(uri, index: index);
    const own = Server(
      id: 'dedicated-hel.example:443',
      name: 'Helsinki',
      country: '',
      city: '',
      connectionUri: 'vless://u@hel.example:443?type=tcp#hel',
      flagEmoji: '',
      isDedicated: true,
      door: 'tcp-reality',
    );
    const official = Server(
      id: '12',
      name: 'DE',
      country: '',
      city: '',
      connectionUri: 'vless://s@official.example:443?type=tcp#de',
      flagEmoji: '',
    );

    test('every community link checked, with its result', () async {
      final dead = community(_de, 0);
      final open = community(_nl, 1);
      final f = ConnectFlow(
        vpn: _Tunnel({open.pathKey}),
        memory: PathMemory(),
        finder: PathFinder(
          probe: (p) async {
            if (p.pathKey == open.pathKey) return 512;
            throw const DoorCheckFailed('tcp ok 80ms; EOF');
          },
          internet: () async => true,
        ),
        reporter: VpnEventReporter(
          send: (_, _, _) async {},
          sendProbes: (_, _, _) async {},
        ),
        networkKey: () async => 'mobile:Irancell',
        carrier: () async => 'Irancell',
        communityChecks: reporter(),
        attemptTimeout: const Duration(seconds: 2),
      );

      await f.connect([own], shared: () async => [official, dead, open]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final rows = sent.single.checks;
      // Our own official link is not a community link.
      expect(rows.map((r) => r['lid']), [LinkId.of(_de), LinkId.of(_nl)]);
      expect(rows.map((r) => r['kind']).toSet(), {'fallback'});
      expect(rows[0]['ok'], isFalse);
      expect(rows[0]['error'], 'tcp ok 80ms; EOF');
      expect(rows[0]['ms'], isA<int>());
      expect(rows[1]['ok'], isTrue);
      expect(rows[1]['ms'], 512);
      expect(rows.map((r) => r['carrier']).toSet(), {'Irancell'});
    });

    test('a flow with no reporter sends nothing and still connects', () async {
      final open = community(_nl, 1);
      final f = ConnectFlow(
        vpn: _Tunnel({open.pathKey}),
        memory: PathMemory(),
        finder: PathFinder(
          probe: (p) async => p.pathKey == open.pathKey ? 300 : -1,
          internet: () async => true,
        ),
        reporter: VpnEventReporter(
          send: (_, _, _) async {},
          sendProbes: (_, _, _) async {},
        ),
        networkKey: () async => 'wifi',
        carrier: () async => null,
        attemptTimeout: const Duration(seconds: 2),
      );

      await f.connect([own], shared: () async => [open]);

      expect(f.stage, ConnectStage.done);
      expect(sent, isEmpty);
    });
  });

  group('"Test all" reports what it tested', () {
    const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() {
      messenger.setMockMethodCallHandler(tunnel, (call) async {
        final link = (call.arguments as Map)['link'] as String;
        return link.contains('nl.example') ? 220 : -1;
      });
    });
    tearDown(() => messenger.setMockMethodCallHandler(tunnel, null));

    test('the community links, as ping checks', () async {
      final state = ServerState(communityChecks: reporter());
      final nl = Server.fromConnectionUri(_nl);
      final de = Server.fromConnectionUri(_de, index: 1);
      // Refused by the test without dialling: not a check that ran.
      final broken = Server.fromConnectionUri('vless://short', index: 2);
      const ours = Server(
        id: '5',
        name: 'ours',
        country: '',
        city: '',
        connectionUri: 'vless://s@nl.example:443?type=tcp#ours',
        flagEmoji: '',
      );

      await state.pingServers([nl, de, broken, ours], tabIndex: 0);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final rows = sent.single.checks;
      expect(rows.map((r) => r['lid']), [LinkId.of(_nl), LinkId.of(_de)]);
      expect(rows.map((r) => r['kind']).toSet(), {'ping'});
      expect(rows[0]['ok'], isTrue);
      expect(rows[0]['ms'], 220);
      expect(rows[1]['ok'], isFalse);
      expect(rows[1]['ms'], isA<int>());
      expect(rows[1]['error'], isNull);
    });

    test('one link tested on its own', () async {
      final state = ServerState(communityChecks: reporter());

      await state.pingServer(Server.fromConnectionUri(_nl));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(sent.single.checks.single['kind'], 'ping');
      expect(PingService.canTest(_nl), isTrue);
    });
  });
}

/// A tunnel that comes up through the paths in [works] and fails through
/// everything else.
class _Tunnel extends VpnService {
  _Tunnel(this.works)
    : super(events: VpnEventReporter(send: (_, _, _) async {}));

  final Set<String> works;
  VpnStatus _fake = VpnStatus.disconnected;

  @override
  VpnStatus get status => _fake;

  @override
  bool get isConnected => _fake == VpnStatus.connected;

  @override
  bool get isConnecting => _fake == VpnStatus.connecting;

  @override
  bool get isVerifying => false;

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {
    _fake = VpnStatus.connecting;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    _fake = works.contains(server.pathKey)
        ? VpnStatus.connected
        : VpnStatus.error;
    notifyListeners();
  }

  @override
  void clearError() {
    if (_fake == VpnStatus.error) _fake = VpnStatus.disconnected;
    notifyListeners();
  }
}
