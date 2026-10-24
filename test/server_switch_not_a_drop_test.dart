import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A user who picks another server while connected has not lost a tunnel.
///
/// The live feed showed phones "dropped" every few seconds, reason
/// unknown. They were users moving between servers on the servers screen:
/// the old tunnel's teardown arrived while the app still said "connected"
/// and was reported as a drop, under the next attempt's door and id. Over
/// a third of the drops in two days were this.

class _Recorded {
  _Recorded(this.type, this.attemptId, this.door, this.host);
  final VpnEventType type;
  final String? attemptId;
  final String? door;
  final String? host;
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
    events.add(_Recorded(type, attemptId, door, serverHost));
  }
}

class _FakeDiagnostics extends ConnectDiagnostics {
  /// When set, a diagnosis waits for it, the way a real one takes a second.
  Completer<void>? hold;

  @override
  Future<Map<String, dynamic>> collect({
    String? host,
    int port = 443,
    String? sni,
  }) async {
    await hold?.future;
    return const {'carrier': 'Irancell', 'network': 'mobile', 'tcp': 'ok'};
  }

  @override
  Future<Map<String, dynamic>> platformReport() async => const {
    'carrier': 'Irancell',
    'network': 'mobile',
  };
}

Server _own(String host, String door) => Server(
  id: 'dedicated-$host',
  name: host,
  country: 'Germany',
  city: 'Nuremberg',
  connectionUri: 'vless://u@$host:443?security=reality&sni=www.sony.com#$host',
  flagEmoji: '',
  isDedicated: true,
  door: door,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.vpn.fortivavpn/tunnel');
  final a = _own('edge-a.example', 'xhttp-reality');
  final b = _own('edge-b.example', 'ws-tls');
  final idA = 'a' * 32;
  final idB = 'b' * 32;

  late _CapturingReporter reporter;
  late _FakeDiagnostics diagnostics;
  late VpnService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    reporter = _CapturingReporter();
    diagnostics = _FakeDiagnostics();
    service = VpnService(events: reporter, diagnostics: diagnostics);
  });

  tearDown(() {
    service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// Up and verified on [a], as the tunnel is once traffic has flowed.
  Future<void> connectedOnA() async {
    await service.connect(a, attemptId: idA);
    service.applyNativeStatus('connected');
    service.debugVerifying = false;
  }

  Iterable<_Recorded> ofType(VpnEventType type) =>
      reporter.events.where((e) => e.type == type);

  test('picking another server ends the session as the user\'s choice, '
      'under its own door and attempt', () async {
    await connectedOnA();

    final next = service.connect(b, attemptId: idB);
    // The platform confirms the old tunnel is down while the new one dials.
    service.applyNativeStatus('disconnected');
    await next;
    await Future<void>.delayed(Duration.zero);

    expect(ofType(VpnEventType.dropped), isEmpty);
    final ended = ofType(VpnEventType.disconnected).single;
    expect(ended.attemptId, idA);
    expect(ended.door, 'xhttp-reality');
    expect(ended.host, 'edge-a.example');
    expect(service.status, VpnStatus.connecting);
  });

  test('a pick while the tunnel is still being verified records no end '
      'for it', () async {
    await service.connect(a, attemptId: idA);
    service.applyNativeStatus('connected');
    expect(service.isVerifying, isTrue);

    final next = service.connect(b, attemptId: idB);
    service.applyNativeStatus('disconnected');
    await next;
    await Future<void>.delayed(Duration.zero);

    expect(ofType(VpnEventType.dropped), isEmpty);
    expect(ofType(VpnEventType.disconnected), isEmpty);
  });

  test('a real drop is still reported as one', () async {
    await connectedOnA();

    service.applyNativeStatus('disconnected:network_lost');
    await Future<void>.delayed(Duration.zero);

    final dropped = ofType(VpnEventType.dropped).single;
    expect(dropped.attemptId, idA);
    expect(dropped.door, 'xhttp-reality');
  });

  test('a drop keeps its own attempt when the next connect starts during '
      'its diagnosis', () async {
    await connectedOnA();
    diagnostics.hold = Completer<void>();

    service.applyNativeStatus('disconnected:network_lost');
    await service.connect(b, attemptId: idB);
    diagnostics.hold!.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final dropped = ofType(VpnEventType.dropped).single;
    expect(dropped.attemptId, idA);
    expect(dropped.door, 'xhttp-reality');
  });

  test('a success keeps its own attempt when the next connect starts during '
      'its report', () async {
    await service.connect(a, attemptId: idA);
    // The first success on a network of the day takes a full diagnosis.
    diagnostics.hold = Completer<void>();

    final report = service.reportConnected('edge-a.example', Duration.zero);
    await service.connect(b, attemptId: idB);
    diagnostics.hold!.complete();
    await report;

    final connected = ofType(VpnEventType.connected).single;
    expect(connected.attemptId, idA);
    expect(connected.door, 'xhttp-reality');
  });
}
