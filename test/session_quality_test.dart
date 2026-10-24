import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/account_service.dart';
import 'package:fortiva_vpn/data/models/connection_data.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A heartbeat that says how good the session was, not only that it was
/// up (backend #365): the tunnel process's readings, how long since the
/// session was verified, its moves and failovers. And the two faults in
/// what the beats carried: bytes counted twice after the speed sample, and
/// beats with no door or attempt after the app was reopened.
Server door(String host, String door, {required int serverId}) => Server(
  id: 'dedicated-$host:443',
  name: host,
  country: '',
  city: host,
  connectionUri: 'vless://u@$host:443?type=tcp#$host',
  flagEmoji: '\u{1F30D}',
  isDedicated: true,
  door: door,
  doorLabel: door,
  serverId: serverId,
);

final hel = door('hel', 'xhttp-reality', serverId: 7);
final fsn = door('fsn', 'ws-tls', serverId: 8);
final nbg = door('nbg', 'xhttp-reality', serverId: 9);

class _Recorded {
  _Recorded({
    required this.type,
    required this.door,
    required this.attemptId,
    required this.strategy,
    required this.serverHost,
    required this.diag,
    required this.bytesUp,
    required this.bytesDown,
  });
  final VpnEventType type;
  final String? door;
  final String? attemptId;
  final Map<String, dynamic>? strategy;
  final String? serverHost;
  final Map<String, dynamic>? diag;
  final int? bytesUp;
  final int? bytesDown;
}

class _CapturingReporter extends VpnEventReporter {
  _CapturingReporter() : super(send: (_, _, _) async {});

  final events = <_Recorded>[];

  Iterable<_Recorded> get beats =>
      events.where((e) => e.type == VpnEventType.heartbeat);

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
    events.add(
      _Recorded(
        type: type,
        door: door,
        attemptId: attemptId,
        strategy: strategy,
        serverHost: serverHost,
        diag: diag,
        bytesUp: bytesUp,
        bytesDown: bytesDown,
      ),
    );
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.vpn.fortivavpn/tunnel');

  late List<MethodCall> calls;
  late List<Map<String, Object?>?> replies;
  late Map<String, Object?>? sample;
  late _CapturingReporter reporter;
  late VpnService service;

  /// The next stats reply. Each read takes the first one queued, and the
  /// last one is repeated once the queue is down to it.
  void reply(Map<String, Object?>? stats) => replies.add(stats);

  Map<String, Object?> stats(int up, int down, [Map<String, Object?>? more]) =>
      {'bytes_up': up, 'bytes_down': down, 'network': 'mobile', ...?more};

  VpnService newService() =>
      VpnService(events: reporter, diagnostics: _FakeDiagnostics());

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    replies = [];
    sample = {'bytes': 256000, 'ms': 2000};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'tunnelStats':
              if (replies.isEmpty) return null;
              return replies.length > 1 ? replies.removeAt(0) : replies.first;
            case 'throughputSample':
              return sample;
            case 'getStatus':
              return 'disconnected';
            default:
              return null;
          }
        });
    reporter = _CapturingReporter();
    service = newService();
  });

  tearDown(() {
    service.dispose();
    ConnectionData.current = ConnectionData.off;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Iterable<MethodCall> statsCalls() =>
      calls.where((c) => c.method == 'tunnelStats');

  group('the heartbeat', () {
    setUp(() => service.applyNativeStatus('connected'));

    test('asks as the heartbeat, and carries the readings as sent', () async {
      final session = {
        'interval_ms': 300000,
        'up_total': 52000,
        'down_total': 9100000,
        'samples': 290,
        'busy_samples': 41,
        'tput_med_kbps': 3800,
        'tput_p90_kbps': 9100,
        'stalls': 1,
        'stall_ms': 9000,
        'first_down_ms': 1000,
        'doors': [
          [0, 52000, 9100000],
        ],
      };
      reply(stats(1200, 640000, {'session': session}));

      await service.sendHeartbeat();

      expect(statsCalls().single.arguments, {'beat': true});
      final beat = reporter.beats.single;
      expect(beat.diag?['session'], session);
      // Totals ride only inside the readings: the beat's own bytes are
      // still the bytes since the last read.
      expect(beat.bytesUp, 1200);
      expect(beat.bytesDown, 640000);
    });

    test('with the readings off there is no block, and the rest is as '
        'before', () async {
      reply(stats(10, 20));

      await service.sendHeartbeat();

      final diag = reporter.beats.single.diag!;
      expect(diag.containsKey('session'), isFalse);
      expect(diag.containsKey('verified_s'), isFalse);
      expect(diag['moves'], 0);
      expect(diag['failovers'], 0);
      expect(diag['network'], 'mobile');
    });

    test('says how long ago the session was verified', () async {
      service.debugVerifiedAt = DateTime.now().subtract(
        const Duration(seconds: 95),
      );
      reply(stats(10, 20));

      await service.sendHeartbeat();

      expect(
        reporter.beats.single.diag?['verified_s'],
        inInclusiveRange(94, 96),
      );
    });

    test('counts the moves since the connect, and the failovers among '
        'them, with the group state', () async {
      service.debugDoors = [hel, fsn, nbg];
      final t0 = DateTime.utc(2026, 10, 16, 8).millisecondsSinceEpoch;
      final status = jsonEncode({
        'state': 'degraded',
        'switch_count': 3,
        'switches': [
          {'from': null, 'to': 0, 'reason': 'startup', 'at': t0},
          {'from': 0, 'to': 2, 'reason': 'faster', 'at': t0 + 60000},
          {'from': 2, 'to': 1, 'reason': 'failover', 'at': t0 + 120000},
        ],
        'doors': [
          {'index': 1, 'state': 'alive'},
        ],
      });
      reply(stats(10, 20, {'door_index': 1, 'door_status': status}));

      await service.sendHeartbeat();
      await service.sendHeartbeat();

      final [first, second] = reporter.beats.toList();
      expect(first.diag?['moves'], 2);
      expect(first.diag?['failovers'], 1);
      expect(first.diag?['group_state'], 'degraded');
      expect(first.door, 'ws-tls');
      // The same moves read again are not counted again.
      expect(second.diag?['moves'], 2);
      expect(second.diag?['failovers'], 1);
    });

    test('a new connect starts the counts again', () async {
      service.debugDoors = [hel, fsn];
      service.followDoor({'door_index': 1});
      service.debugVerifiedAt = DateTime.now();

      await service.connect(hel);
      service.applyNativeStatus('connected');
      // Not verified in this test: the check would need a network.
      service.debugVerifying = false;
      reply(stats(10, 20));
      await service.sendHeartbeat();

      final diag = reporter.beats.single.diag!;
      expect(diag['moves'], 0);
      expect(diag.containsKey('verified_s'), isFalse);
    });
  });

  group('the speed sample', () {
    setUp(() => service.applyNativeStatus('connected'));

    test('its bytes go on one beat, not two', () async {
      reply(stats(1000, 900000));
      reply(stats(30, 5000));

      await service.sampleThroughput();
      await service.sendHeartbeat();

      final [sampled, periodic] = reporter.beats.toList();
      expect(sampled.diag, contains('throughput_kbps'));
      expect(sampled.bytesDown, 900000);
      expect(sampled.bytesUp, 1000);
      // Before the fix this beat sent 905000: the sample's bytes again.
      expect(periodic.bytesDown, 5000);
      expect(periodic.bytesUp, 30);
    });

    test('bytes read for a sample that could not measure go on the next '
        'beat', () async {
      sample = null;
      reply(stats(1000, 900000));
      reply(stats(30, 5000));

      await service.sampleThroughput();
      await service.sendHeartbeat();

      final beat = reporter.beats.single;
      expect(beat.bytesDown, 905000);
      expect(beat.bytesUp, 1030);
    });

    test('bytes read before it go on its beat, once', () async {
      reply(stats(1, 700));
      reply(stats(1000, 900000));
      reply(stats(30, 5000));

      // The update dialog reads the counters too.
      await service.tunnelBytesDown();
      await service.sampleThroughput();
      await service.sendHeartbeat();

      final [sampled, periodic] = reporter.beats.toList();
      expect(sampled.bytesDown, 900700);
      expect(periodic.bytesDown, 5000);
    });

    test('its read does not ask as the heartbeat', () async {
      reply(stats(1000, 900000));

      await service.sampleThroughput();

      expect(statsCalls().single.arguments, isNull);
    });
  });

  group('reopened over a running tunnel', () {
    /// A tunnel this app brought up and verified on [hel], which the core
    /// then moved to [fsn] because [hel] failed. Returns the attempt's
    /// strategy for [fsn], as the move's row carried it.
    Future<Map<String, dynamic>?> upAndMoved() async {
      await service.connect(hel, standby: [fsn], attemptId: 'attempt-1');
      service.applyNativeStatus('connected');
      service.debugVerifying = false;
      final t0 = DateTime.utc(2026, 10, 16, 8).millisecondsSinceEpoch;
      service.followDoor({
        'door_index': 1,
        'door_status': jsonEncode({
          'state': 'ok',
          'switches': [
            {'from': 0, 'to': 1, 'reason': 'failover', 'at': t0},
          ],
          'doors': [],
        }),
      });
      await pumpEventQueue();
      return reporter.events
          .lastWhere((e) => e.type == VpnEventType.doorSwitched)
          .strategy;
    }

    /// The app opened again: a new service finds the tunnel up.
    Future<VpnService> reopen() async {
      service.dispose();
      service = newService();
      service.applyNativeStatus('connected');
      await pumpEventQueue();
      return service;
    }

    test('beats keep the door, attempt, strategy and host', () async {
      final strategy = await upAndMoved();
      expect(strategy, isNotNull);

      final reopened = await reopen();
      reply(stats(10, 20, {'door_index': 1}));
      await reopened.sendHeartbeat();

      final beat = reporter.beats.single;
      expect(beat.attemptId, 'attempt-1');
      expect(beat.door, 'ws-tls');
      expect(beat.serverHost, 'fsn');
      expect(beat.strategy, strategy);
      expect(beat.diag?['moves'], 1);
      expect(beat.diag?['failovers'], 1);
    });

    test('a reopened app knows which door the tunnel is on, for the search '
        'after a dead tunnel', () async {
      await upAndMoved();
      reply(stats(10, 20, {'door_index': 1}));

      final reopened = await reopen();
      await pumpEventQueue();

      // No list of doors, only the key the attempt kept.
      expect(reopened.activeDoor, isNull);
      expect(reopened.activeDoorKey, fsn.pathKey);
    });

    test(
      'a core that moved while the app was closed leaves it no door key',
      () async {
        await upAndMoved();
        reply(stats(10, 20, {'door_index': 0}));

        final reopened = await reopen();
        await pumpEventQueue();

        expect(reopened.activeDoorKey, isNull);
      },
    );

    test('a core that moved while the app was closed is on a door the app '
        'cannot name', () async {
      await upAndMoved();

      final reopened = await reopen();
      reply(stats(10, 20, {'door_index': 0}));
      await reopened.sendHeartbeat();

      final beat = reporter.beats.single;
      expect(beat.attemptId, 'attempt-1');
      expect(beat.door, isNull);
      expect(beat.serverHost, isNull);
      expect(beat.strategy, isNull);
    });

    test(
      'a door the app cannot name is kept as none for the next reopen',
      () async {
        await upAndMoved();

        final reopened = await reopen();
        reply(stats(10, 20, {'door_index': 0}));
        await reopened.sendHeartbeat();
        await pumpEventQueue();

        final prefs = await SharedPreferences.getInstance();
        final saved =
            jsonDecode(prefs.getString('vpn_connected_attempt')!)
                as Map<String, dynamic>;
        expect(saved['attempt_id'], 'attempt-1');
        expect(saved['door_index'], 0);
        expect(saved, isNot(contains('door')));
        expect(saved, isNot(contains('server_host')));
        expect(saved, isNot(contains('link')));

        // Opened once more, with nothing read before the tunnel drops: the
        // drop must not name the door the core left.
        replies.clear();
        reporter.events.clear();
        await reopen();
        service.applyNativeStatus('disconnected');
        await pumpEventQueue();

        final drop = reporter.events.singleWhere(
          (e) => e.type == VpnEventType.dropped,
        );
        expect(drop.attemptId, 'attempt-1');
        expect(drop.door, isNull);
        expect(drop.serverHost, isNull);
      },
    );

    test(
      'the door put back is read at once, before a drop can name it',
      () async {
        await upAndMoved();
        reply(stats(10, 20, {'door_index': 0}));

        await reopen();
        expect(statsCalls(), hasLength(1));
        service.applyNativeStatus('disconnected');
        await pumpEventQueue();

        final drop = reporter.events.singleWhere(
          (e) => e.type == VpnEventType.dropped,
        );
        expect(drop.attemptId, 'attempt-1');
        expect(drop.door, isNull);
        expect(drop.serverHost, isNull);
      },
    );

    test('the bytes of that read go on the next beat, once', () async {
      await upAndMoved();
      reply(stats(10, 20, {'door_index': 1}));
      reply(stats(1, 2, {'door_index': 1}));

      final reopened = await reopen();
      await reopened.sendHeartbeat();

      final beat = reporter.beats.single;
      expect(beat.door, 'ws-tls');
      expect(beat.bytesUp, 11);
      expect(beat.bytesDown, 22);
    });

    test('nothing is read when no attempt was kept', () async {
      await reopen();

      expect(statsCalls(), isEmpty);
    });

    test('the attempt is forgotten when the tunnel goes down', () async {
      await upAndMoved();
      service.applyNativeStatus('disconnected');
      await pumpEventQueue();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('vpn_connected_attempt'), isNull);
    });
  });

  group('an account deleted while the tunnel is up', () {
    final t0 = DateTime.utc(2026, 10, 16, 8).millisecondsSinceEpoch;

    String group(List<Map<String, Object>> switches) =>
        jsonEncode({'state': 'ok', 'switches': switches, 'doors': []});

    test('stays deleted when the core moves door after it', () async {
      await service.connect(hel, standby: [fsn, nbg], attemptId: 'attempt-1');
      service.applyNativeStatus('connected');
      service.debugVerifying = false;
      final first = {'from': 0, 'to': 1, 'reason': 'failover', 'at': t0};
      service.followDoor({
        'door_index': 1,
        'door_status': group([first]),
      });
      await pumpEventQueue();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('vpn_connected_attempt'), isNotNull);

      // What AccountService.deleteAccount does to the saved settings. It
      // leaves the tunnel up.
      for (final key in AccountService.accountPrefKeys) {
        await prefs.remove(key);
      }
      reply(
        stats(10, 20, {
          'door_index': 2,
          'door_status': group([
            first,
            {'from': 1, 'to': 2, 'reason': 'failover', 'at': t0 + 1000},
          ]),
        }),
      );
      await service.sendHeartbeat();
      await pumpEventQueue();

      // The move is still followed and reported.
      expect(reporter.beats.single.serverHost, 'nbg');
      expect(reporter.beats.single.diag?['moves'], 2);
      // But nothing of the deleted account is written back.
      for (final key in [
        'vpn_connected_server_id',
        'vpn_connected_server_name',
        'vpn_connected_start_time',
        'vpn_connected_attempt',
      ]) {
        expect(prefs.containsKey(key), isFalse, reason: key);
      }
    });
  });

  group('the settings on connect', () {
    Future<Map<Object?, Object?>> connectArgs() async {
      await service.connect(hel);
      return calls.lastWhere((c) => c.method == 'connect').arguments
          as Map<Object?, Object?>;
    }

    test('carry the backend\'s numbers to the tunnel', () async {
      ConnectionData.current = const ConnectionData(
        sessionSample: Duration(seconds: 2),
        stallAfter: Duration(seconds: 8),
        busyBytes: 50000,
      );

      final args = await connectArgs();

      expect(args['session_sample_ms'], 2000);
      expect(args['session_stall_ms'], 8000);
      expect(args['session_busy_bytes'], 50000);
    });

    test('are zero when the backend sent none, so none lingers', () async {
      final args = await connectArgs();

      expect(args['session_sample_ms'], 0);
      expect(args['session_stall_ms'], 0);
      expect(args['session_busy_bytes'], 0);
    });

    test('are zero without a stall length', () async {
      ConnectionData.current = const ConnectionData(
        sessionSample: Duration(seconds: 2),
        busyBytes: 50000,
      );

      final args = await connectArgs();

      expect(args['session_sample_ms'], 0);
      expect(args['session_busy_bytes'], 0);
    });
  });
}
