import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/utils/standby_doors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A move to a standby door in the middle of a session: the event that
/// records it, the selection that follows it, and a backend that does not
/// know the event yet.
Server door(String host, String door, {required int serverId}) => Server(
  id: 'dedicated-$host:443',
  name: host,
  country: '',
  city: host,
  connectionUri: 'vless://u@$host:443?type=tcp#$host',
  flagEmoji: '🌍',
  isDedicated: true,
  door: door,
  doorLabel: door,
  serverId: serverId,
);

final hel1 = door('hel', 'xhttp-reality', serverId: 7);
final hel2 = door('hel', 'ws-tls', serverId: 7);
final fsn1 = door('fsn', 'xhttp-reality', serverId: 8);

class _Recorded {
  _Recorded(this.type, this.door, this.serverHost, this.diag, this.at);
  final VpnEventType type;
  final String? door;
  final String? serverHost;
  final Map<String, dynamic>? diag;
  final DateTime? at;
}

class _CapturingReporter extends VpnEventReporter {
  _CapturingReporter() : super(send: (_, _, _) async {});

  final events = <_Recorded>[];

  @override
  Future<void> record(
    VpnEventType type, {
    String? serverHost,
    String? door,
    String? attemptId,
    Map<String, dynamic>? strategy,
    Duration? duration,
    String? error,
    Map<String, dynamic>? diag,
    int? bytesUp,
    int? bytesDown,
    DateTime? at,
  }) async {
    events.add(_Recorded(type, door, serverHost, diag, at));
  }
}

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

/// A tunnel that comes up on the dialled door and can be moved later, the
/// way the core moves it when that door stops answering.
class _FakeVpn extends VpnService {
  _FakeVpn() : super(events: VpnEventReporter(send: (_, _, _) async {}));

  Server? _active;
  VpnStatus _fakeStatus = VpnStatus.disconnected;

  @override
  VpnStatus get status => _fakeStatus;

  @override
  bool get isConnected => _fakeStatus == VpnStatus.connected;

  @override
  bool get isConnecting => _fakeStatus == VpnStatus.connecting;

  @override
  bool get isVerifying => false;

  @override
  Server? get activeDoor => _active;

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {
    _fakeStatus = VpnStatus.connecting;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 5));
    _active = server;
    _fakeStatus = VpnStatus.connected;
    notifyListeners();
  }

  String? _reason;

  @override
  String? get switchReason => _reason;

  void moveTo(Server s, {String? reason}) {
    _active = s;
    _reason = reason;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _fakeStatus = VpnStatus.disconnected;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StandbyDoors.enabled = true;
    StandbyDoors.androidOverride = true;
  });

  tearDown(() {
    StandbyDoors.enabled = false;
    StandbyDoors.androidOverride = null;
  });

  group('the service', () {
    late _CapturingReporter reporter;
    late VpnService service;

    setUp(() {
      reporter = _CapturingReporter();
      service = VpnService(events: reporter, diagnostics: _FakeDiagnostics());
      service.debugDoors = [hel1, hel2, fsn1];
    });

    tearDown(() => service.dispose());

    test('reports a move made while connected, naming both doors', () async {
      service.applyNativeStatus('connected');

      service.followDoor({'door_index': 2});
      await Future<void>.delayed(Duration.zero);

      final e = reporter.events.singleWhere(
        (e) => e.type == VpnEventType.doorSwitched,
      );
      expect(e.door, 'xhttp-reality');
      expect(e.serverHost, 'fsn');
      expect(e.diag, {
        'from_door': 'xhttp-reality',
        'from_host': 'hel',
        'from_server_id': 7,
        'door_index': 2,
        'server_id': 8,
        'doors': 3,
      });
      expect(service.activeDoor?.pathKey, fsn1.pathKey);
    });

    test('says nothing when the core is still on the same door', () async {
      service.applyNativeStatus('connected');

      service.followDoor({'door_index': 0});
      await Future<void>.delayed(Duration.zero);

      expect(
        reporter.events.where((e) => e.type == VpnEventType.doorSwitched),
        isEmpty,
      );
    });

    test(
      'a move before the tunnel is verified is followed, not reported',
      () async {
        // The connected event that follows names the door in use.
        service.followDoor({'door_index': 1});
        await Future<void>.delayed(Duration.zero);

        expect(service.activeDoor?.pathKey, hel2.pathKey);
        expect(
          reporter.events.where((e) => e.type == VpnEventType.doorSwitched),
          isEmpty,
        );
      },
    );

    test('a move found while verifying is followed, not reported', () async {
      // The connected event that follows verification names the door in use.
      service.applyNativeStatus('connected');
      service.debugVerifying = true;

      service.followDoor({'door_index': 2});
      await Future<void>.delayed(Duration.zero);

      expect(service.activeDoor?.pathKey, fsn1.pathKey);
      expect(
        reporter.events.where((e) => e.type == VpnEventType.doorSwitched),
        isEmpty,
      );
    });

    group('with the core\'s list of moves', () {
      final t0 = DateTime.utc(2026, 10, 2, 21, 43, 16);

      Map<String, dynamic> move(int? from, int to, String reason, int min) => {
        'from': from,
        'to': to,
        'reason': reason,
        'at': t0.add(Duration(minutes: min)).millisecondsSinceEpoch,
      };

      Map<String, dynamic> reply(int door, List<Map<String, dynamic>> moves) =>
          {
            'door_index': door,
            'carrier': 'Irancell',
            'network': 'mobile',
            'door_status': jsonEncode({
              'state': 'ok',
              'switch_count': moves.length,
              'switches': moves,
              'doors': [
                {'index': 0, 'state': 'alive', 'delay_ms': 310},
                {'index': 2, 'state': 'alive', 'delay_ms': 180},
              ],
            }),
          };

      List<_Recorded> switches() => [
        for (final e in reporter.events)
          if (e.type == VpnEventType.doorSwitched) e,
      ];

      test('reports every move since the last read, with its reason and '
          'when it happened', () async {
        service.applyNativeStatus('connected');

        // Out and back between two heartbeats: the door in use is the one
        // the tunnel started on, and both moves still happened.
        service.followDoor(
          reply(0, [
            move(null, 0, 'startup', 0),
            move(0, 2, 'faster', 1),
            move(2, 0, 'failover', 3),
          ]),
        );
        await Future<void>.delayed(Duration.zero);

        final [out, back] = switches();
        expect(out.door, 'xhttp-reality');
        expect(out.serverHost, 'fsn');
        expect(out.at, t0.add(const Duration(minutes: 1)));
        expect(out.diag?['reason'], 'faster');
        expect(out.diag?['from_host'], 'hel');
        expect(out.diag?['door_index'], 2);
        // Both servers by id: two servers' Cloudflare doors share a name
        // and an address, and a move between them changes the exit.
        expect(out.diag?['from_index'], 0);
        expect(out.diag?['from_server_id'], 7);
        expect(out.diag?['server_id'], 8);
        expect(out.diag?['carrier'], 'Irancell');
        expect(out.diag?['switch_count'], 3);
        expect(out.diag?['door_states'], [
          {
            'index': 0,
            'state': 'alive',
            'delay_ms': 310,
            'door': 'xhttp-reality',
            'server_id': 7,
          },
          {
            'index': 2,
            'state': 'alive',
            'delay_ms': 180,
            'door': 'xhttp-reality',
            'server_id': 8,
          },
        ]);
        expect(back.serverHost, 'hel');
        expect(back.at, t0.add(const Duration(minutes: 3)));
        expect(back.diag?['reason'], 'failover');
        expect(service.activeDoor?.pathKey, hel1.pathKey);
      });

      test('a move already reported is not reported again', () async {
        service.applyNativeStatus('connected');
        final first = [move(0, 2, 'faster', 1)];

        service.followDoor(reply(2, first));
        service.followDoor(reply(2, first));
        service.followDoor(reply(0, [...first, move(2, 0, 'faster', 12)]));
        await Future<void>.delayed(Duration.zero);

        expect([for (final e in switches()) e.diag?['door_index']], [2, 0]);
      });

      test('a move made while verifying is never reported', () async {
        // The connected event that follows verification names the door.
        service.applyNativeStatus('connected');
        service.debugVerifying = true;
        final early = move(0, 1, 'faster', 0);
        service.followDoor(reply(1, [early]));

        service.debugVerifying = false;
        service.followDoor(reply(0, [early, move(1, 0, 'failover', 4)]));
        await Future<void>.delayed(Duration.zero);

        expect(switches().single.diag?['reason'], 'failover');
      });

      test('keeps why the core left the door, for the flow', () async {
        service.applyNativeStatus('connected');

        service.followDoor(reply(2, [move(0, 2, 'faster', 1)]));
        expect(service.switchReason, 'faster');

        service.followDoor(
          reply(0, [move(0, 2, 'faster', 1), move(2, 0, 'failover', 15)]),
        );
        expect(service.switchReason, 'failover');
      });
    });

    test('a door index outside the group is ignored', () async {
      service.applyNativeStatus('connected');

      service.followDoor({'door_index': 9});
      await Future<void>.delayed(Duration.zero);

      expect(service.activeDoor?.pathKey, hel1.pathKey);
      expect(reporter.events, isEmpty);
    });
  });

  group('the connect flow after the tunnel is up', () {
    late _FakeVpn vpn;
    late ConnectFlow flow;

    setUp(() {
      vpn = _FakeVpn();
      flow = ConnectFlow(
        vpn: vpn,
        memory: PathMemory(),
        finder: PathFinder(
          probe: (p) async => p.pathKey == hel1.pathKey ? 150 : -1,
          internet: () async => true,
        ),
        reporter: VpnEventReporter(
          send: (_, _, _) async {},
          sendProbes: (_, _, _) async {},
          deviceId: () async => 'DEV-1',
          appVersion: () async => '1.6.4',
          platform: 'android',
          networkType: () async => 'mobile',
        ),
        networkKey: () async => 'mobile:Irancell',
        carrier: () async => 'Irancell',
        attemptTimeout: const Duration(seconds: 2),
      );
    });

    tearDown(() => flow.dispose());

    test('the selection follows a move to another server', () async {
      Server? switchedTo;
      await flow.connect(
        [hel1, hel2, fsn1],
        preferred: hel1,
        onSwitchedServer: (s) => switchedTo = s,
      );
      expect(flow.stage, ConnectStage.done);
      expect(switchedTo, isNull);

      vpn.moveTo(fsn1);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(switchedTo?.pathKey, fsn1.pathKey);
      expect(flow.chosen?.pathKey, fsn1.pathKey);
      // The next connect on this network starts where the tunnel ended up.
      expect(await PathMemory().recall('mobile:Irancell'), fsn1.pathKey);
    });

    test(
      'a move to another door of the same server keeps the selection',
      () async {
        var switches = 0;
        await flow.connect(
          [hel1, hel2, fsn1],
          preferred: hel1,
          onSwitchedServer: (_) => switches++,
        );

        vpn.moveTo(hel2);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(switches, 0);
        expect(flow.chosen?.pathKey, hel2.pathKey);
        expect(await PathMemory().recall('mobile:Irancell'), hel2.pathKey);
      },
    );

    Future<Set<String>> failedToday() async {
      final prefs = await SharedPreferences.getInstance();
      final all = jsonDecode(prefs.getString(PathMemory.storageKey) ?? '{}');
      final fails = (all['mobile:Irancell'] as Map?)?['fails'] as Map? ?? {};
      return {for (final key in fails.keys) key as String};
    }

    test('a door left for a faster one is not counted as failed', () async {
      await flow.connect([hel1, hel2, fsn1], preferred: hel1);

      vpn.moveTo(hel2, reason: 'faster');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(await failedToday(), isNot(contains(hel1.pathKey)));
      expect(await PathMemory().recall('mobile:Irancell'), hel2.pathKey);
    });

    test('a door the core left because it failed is counted', () async {
      await flow.connect([hel1, hel2, fsn1], preferred: hel1);

      vpn.moveTo(hel2, reason: 'failover');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(await failedToday(), contains(hel1.pathKey));
    });

    test('nothing is followed once the tunnel is down', () async {
      Server? switchedTo;
      await flow.connect(
        [hel1, hel2, fsn1],
        preferred: hel1,
        onSwitchedServer: (s) => switchedTo = s,
      );
      await vpn.disconnect();

      vpn.moveTo(fsn1);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(switchedTo, isNull);
    });
  });

  group('a backend that refuses an event', () {
    late List<List<String>> delivered;

    VpnEventReporter reporter(Object? Function(List<String> types) answer) =>
        VpnEventReporter(
          send: (_, events, _) async {
            final types = [for (final e in events) e['type'] as String];
            final error = answer(types);
            if (error != null) throw error;
            delivered.add(types);
          },
          deviceId: () async => 'DEV-1',
          appVersion: () async => '1.6.4',
          platform: 'android',
          osVersion: '14',
          networkType: () async => 'mobile',
        );

    setUp(() => delivered = []);

    test('drops only the refused event, and delivers the rest', () async {
      // An older backend does not know door_switched and answers 422 for
      // any batch that holds one.
      final r = reporter(
        (types) => types.contains('door_switched')
            ? ApiException(statusCode: 422, message: 'unknown type')
            : null,
      );
      await r.record(VpnEventType.connected);
      await r.record(VpnEventType.doorSwitched);
      await r.record(VpnEventType.heartbeat);
      await r.flush();

      expect(
        delivered.expand((b) => b),
        containsAll(['connected', 'heartbeat']),
      );
      expect(delivered.expand((b) => b), isNot(contains('door_switched')));
      expect(await r.pending(), 0);
    });

    test('an event recorded late carries the time it happened', () async {
      final sent = <Map<String, dynamic>>[];
      final r = VpnEventReporter(
        send: (_, events, _) async => sent.addAll(events),
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.4',
        platform: 'android',
        networkType: () async => 'mobile',
      );
      final happened = DateTime.utc(2026, 10, 2, 21, 44, 16);

      await r.record(VpnEventType.doorSwitched, at: happened);
      await r.flush();

      expect(sent.single['client_ts'], happened.toIso8601String());
    });

    test('keeps everything when the backend cannot be reached', () async {
      final r = reporter(
        (_) => ApiException(statusCode: 0, message: 'No internet connection'),
      );
      await r.record(VpnEventType.doorSwitched);
      await r.record(VpnEventType.heartbeat);
      await r.flush();

      expect(delivered, isEmpty);
      expect(await r.pending(), 2);
    });

    test('an event recorded while a batch is in flight is kept', () async {
      // The bug of 2026-10-02: the flush stored its own copy of the queue,
      // read before the send, over the one holding the new event.
      final release = Completer<void>();
      var sends = 0;
      final r = VpnEventReporter(
        send: (_, events, _) async {
          sends++;
          if (sends == 1) await release.future;
          delivered.add([for (final e in events) e['type'] as String]);
        },
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.4',
        platform: 'android',
        osVersion: '14',
        networkType: () async => 'mobile',
      );
      await r.record(VpnEventType.doorSwitched);
      // That record started a flush, which is now waiting on the backend.
      await r.record(VpnEventType.connected);
      release.complete();
      await r.flush();

      expect(delivered.expand((b) => b), ['door_switched', 'connected']);
      expect(await r.pending(), 0);
    });

    test('two records at the same moment are both kept', () async {
      final r = reporter(
        (_) => ApiException(statusCode: 0, message: 'offline'),
      );
      await Future.wait([
        r.record(VpnEventType.doorSwitched),
        r.record(VpnEventType.connected),
        r.record(VpnEventType.heartbeat),
      ]);

      expect(await r.pending(), 3);
    });

    test('keeps everything when the backend fails', () async {
      final r = reporter(
        (_) => ApiException(statusCode: 502, message: 'Bad gateway'),
      );
      await r.record(VpnEventType.heartbeat);
      await r.flush();

      expect(await r.pending(), 1);
    });
  });
}
