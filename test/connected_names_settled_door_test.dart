import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The connected event names the door that carries the tunnel. With
/// standby doors the core's first pick is a guess it is still measuring
/// when the check through the tunnel passes: on 2026-11-04 a connected row
/// named a gRPC door whose port was blocked while XHTTP carried the
/// traffic, and the door_switched row came 29 seconds later. The event now
/// waits for the core to settle, and the move is in it, not in a row of its
/// own.
Server door(String host, String door) => Server(
  id: 'dedicated-$host:2083',
  name: host,
  country: '',
  city: host,
  connectionUri: 'vless://u@$host:2083?type=tcp#$host',
  flagEmoji: '🌍',
  isDedicated: true,
  door: door,
  doorLabel: door,
  serverId: 13,
);

final grpc = door('198.51.100.7', 'grpc-reality');
final xhttp = door('198.51.100.8', 'xhttp-reality');

class _Recorded {
  _Recorded(this.type, this.door, this.serverHost, this.diag);
  final VpnEventType type;
  final String? door;
  final String? serverHost;
  final Map<String, dynamic>? diag;
}

class _Reporter extends VpnEventReporter {
  _Reporter() : super(send: (_, _, _) async {});

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
    events.add(_Recorded(type, door, serverHost, diag));
  }
}

class _Diag extends ConnectDiagnostics {
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
  final t0 = DateTime.utc(2026, 11, 4, 10, 18, 14).millisecondsSinceEpoch;
  late List<Map<String, Object?>> replies;
  late _Reporter reporter;
  late VpnService service;
  final timers = <Timer>[];
  final gap = VpnService.doorSettleGap;
  final limit = VpnService.doorSettleLimit;

  Map<String, Object?> reply(
    int index,
    String state,
    List<Map<String, Object?>> moves,
  ) => {
    'bytes_up': 1,
    'bytes_down': 1,
    'door_index': index,
    'door_status': jsonEncode({
      'state': state,
      'switch_count': moves.length,
      'switches': moves,
      'doors': [],
    }),
  };

  Map<String, Object?> move(int? from, int to, int ms) => {
    'from': from,
    'to': to,
    'reason': 'startup',
    'at': t0 + ms,
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    VpnService.doorSettleGap = const Duration(milliseconds: 10);
    replies = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'tunnelStats':
              if (replies.isEmpty) return null;
              return replies.length > 1 ? replies.removeAt(0) : replies.first;
            case 'getStatus':
              return 'connected';
            default:
              return null;
          }
        });
    reporter = _Reporter();
    // VpnService starts timers of its own (a poll of the native side, the
    // check through the tunnel), which end with the test.
    service = runZoned(
      () => VpnService(events: reporter, diagnostics: _Diag()),
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          final t = parent.createTimer(zone, duration, callback);
          timers.add(t);
          return t;
        },
      ),
    );
    // Dialled on the gRPC door, with XHTTP standing by.
    await service.connect(grpc, standby: [xhttp], attemptId: 'a' * 32);
    service.applyNativeStatus('connected');
    // The check through the tunnel has passed; what follows is the report.
    service.debugVerifying = false;
    await pumpEventQueue();
    expect(service.activeDoor?.door, 'grpc-reality');
  });

  tearDown(() {
    service.dispose();
    for (final t in timers) {
      t.cancel();
    }
    timers.clear();
    VpnService.doorSettleGap = gap;
    VpnService.doorSettleLimit = limit;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<_Recorded> of(VpnEventType type) => [
    for (final e in reporter.events)
      if (e.type == type) e,
  ];

  test('names the door the core settles on, and reports no switch', () async {
    // The read after the check: the core is still on its first pick.
    service.followDoor(reply(0, 'starting', [move(null, 0, 0)]));
    expect(service.activeDoor?.door, 'grpc-reality');
    // Its probe of that door times out, and it moves to XHTTP.
    replies.add(reply(1, 'ok', [move(null, 0, 0), move(0, 1, 5500)]));

    await service.reportConnected('198.51.100.7', null);

    final connected = of(VpnEventType.connected).single;
    expect(connected.door, 'xhttp-reality');
    expect(connected.serverHost, '198.51.100.8');
    expect(connected.diag?['door_index'], 1);
    expect(connected.diag?['dialled_door'], 'grpc-reality');
    expect(of(VpnEventType.doorSwitched), isEmpty);
    expect(service.activeDoor?.door, 'xhttp-reality');
  });

  test('a move after it is reported as before', () async {
    service.followDoor(reply(0, 'starting', [move(null, 0, 0)]));
    replies.add(reply(1, 'ok', [move(null, 0, 0), move(0, 1, 5500)]));
    await service.reportConnected('198.51.100.7', null);

    service.followDoor(
      reply(0, 'ok', [move(null, 0, 0), move(0, 1, 5500), move(1, 0, 90000)]),
    );
    await pumpEventQueue();

    final switched = of(VpnEventType.doorSwitched).single;
    expect(switched.door, 'grpc-reality');
    expect(switched.diag?['from_door'], 'xhttp-reality');
  });

  test('a group that has settled is not waited for', () async {
    service.followDoor(reply(0, 'ok', [move(null, 0, 0)]));
    // A read now would move the door: none is made.
    replies.add(reply(1, 'ok', [move(null, 0, 0), move(0, 1, 5500)]));

    await service.reportConnected('198.51.100.7', null);

    final connected = of(VpnEventType.connected).single;
    expect(connected.door, 'grpc-reality');
    expect(connected.diag?.containsKey('door_index') ?? false, isFalse);
  });

  test('a core that never settles costs at most the limit', () async {
    VpnService.doorSettleLimit = const Duration(milliseconds: 300);
    service.followDoor(reply(0, 'starting', [move(null, 0, 0)]));
    replies.add(reply(0, 'starting', [move(null, 0, 0)]));

    final clock = Stopwatch()..start();
    await service.reportConnected('198.51.100.7', null);

    expect(clock.elapsed, lessThan(const Duration(seconds: 3)));
    expect(of(VpnEventType.connected).single.door, 'grpc-reality');
  });
}
