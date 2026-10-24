import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A shaped tunnel looks connected and passes a trickle. "Connected" on
/// its own therefore says nothing on day one of a shaping campaign, and
/// these tests pin the reading that tells the difference.
const _server = Server(
  id: 'dedicated-0',
  name: 'Fortiva DE',
  country: 'Germany',
  city: 'Falkenstein',
  connectionUri: 'vless://u@edge.fortivavpn.com:8443?security=reality&sni=x#DE',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
  isDedicated: true,
);

class _Recorded {
  _Recorded(this.type, this.diag, this.bytesDown);
  final VpnEventType type;
  final Map<String, dynamic>? diag;
  final int? bytesDown;
}

class _CapturingReporter extends VpnEventReporter {
  _CapturingReporter()
    : super(
        send: (_, _, _) async {},
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.4.0',
        platform: 'android',
        osVersion: '14',
        networkType: () async => 'mobile',
      );

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
    events.add(_Recorded(type, diag, bytesDown));
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

  late _CapturingReporter reporter;
  late VpnService service;
  late List<MethodCall> calls;
  late Map<String, Object?>? stats;
  late Map<String, Object?>? sample;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    stats = {
      'bytes_up': 1000,
      'bytes_down': 900000,
      'carrier': 'Irancell',
      'network': 'mobile',
      'metered': true,
    };
    sample = {'bytes': 256000, 'ms': 2000};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'tunnelStats' => stats,
            'throughputSample' => sample,
            _ => null,
          };
        });
    reporter = _CapturingReporter();
    service = VpnService(events: reporter, diagnostics: _FakeDiagnostics());
    // The tunnel is up and already verified, which is the state the
    // sampler is armed in: this is the path a relaunch over a running
    // tunnel takes.
    service.applyNativeStatus('connected');
  });

  tearDown(() {
    // Leaves no armed sampler or heartbeat behind for the next test.
    service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('a metered network is measured with a smaller object', () async {
    await service.sampleThroughput();

    final ask = calls.firstWhere((c) => c.method == 'throughputSample');
    expect((ask.arguments as Map)['bytes'], VpnService.throughputBytesMetered);
  });

  test('an unmetered network is measured with the full object', () async {
    stats = {...stats!, 'metered': false, 'network': 'wifi'};
    await service.sampleThroughput();

    final ask = calls.firstWhere((c) => c.method == 'throughputSample');
    expect((ask.arguments as Map)['bytes'], VpnService.throughputBytes);
  });

  test('the reading rides on a heartbeat, with the carrier', () async {
    await service.sampleThroughput();

    final beat = reporter.events.single;
    expect(beat.type, VpnEventType.heartbeat);
    expect(beat.diag, containsPair('throughput_kbps', 1024));
    expect(beat.diag, containsPair('carrier', 'Irancell'));
    expect(beat.bytesDown, 900000);
  });

  test('with standby doors, the beat carries what the core measured', () async {
    service.debugDoors = [
      Server.fromDedicatedPath(
        uri: 'vless://u@hel:443?type=tcp#hel',
        door: 'xhttp-reality',
        doorLabel: 'xhttp-reality',
        serverId: 7,
      ),
    ];
    stats = {
      ...stats!,
      'door_index': 0,
      'door_status': jsonEncode({
        'switch_count': 2,
        'switches': [],
        'doors': [
          {'index': 0, 'state': 'alive', 'delay_ms': 310, 'fail_ratio': 0.25},
        ],
      }),
    };
    await service.sampleThroughput();

    final beat = reporter.events.single;
    expect(beat.diag, containsPair('switch_count', 2));
    expect(beat.diag?['door_states'], [
      {
        'index': 0,
        'state': 'alive',
        'delay_ms': 310,
        'fail_ratio': 0.25,
        'door': 'xhttp-reality',
        'server_id': 7,
      },
    ]);
  });

  test('it is taken once, however often the tunnel settles', () async {
    await service.sampleThroughput();
    await service.sampleThroughput();

    expect(calls.where((c) => c.method == 'throughputSample'), hasLength(1));
    expect(reporter.events, hasLength(1));
  });

  test('a new attempt is a new session', () async {
    await service.sampleThroughput();
    await service.connect(_server);
    service.applyNativeStatus('connected');
    await service.sampleThroughput();

    expect(calls.where((c) => c.method == 'throughputSample'), hasLength(2));
  });

  test("it steps aside for the user's own speed test", () async {
    service.speedTestRunning = () => true;
    await service.sampleThroughput();

    expect(calls.any((c) => c.method == 'throughputSample'), isFalse);
    expect(reporter.events, isEmpty);
  });

  test('a platform that cannot measure sends nothing', () async {
    sample = null;
    await service.sampleThroughput();

    expect(reporter.events, isEmpty);
  });

  test('a reading of zero bytes is not reported as zero speed', () async {
    // A stalled download and a slow one are different facts, and only one
    // of them is a measurement.
    sample = {'bytes': 0, 'ms': 4000};
    await service.sampleThroughput();

    expect(reporter.events, isEmpty);
  });

  test('no counters means no beat to hang the reading on', () async {
    stats = null;
    await service.sampleThroughput();

    expect(calls.any((c) => c.method == 'throughputSample'), isFalse);
    expect(reporter.events, isEmpty);
  });
}
