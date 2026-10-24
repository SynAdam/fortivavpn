import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every failure the app reports has to carry the checks that say why.
///
/// The collector and the field that carries it were both built, and for two
/// weeks nothing called them, so 576 verification failures in one day reached
/// the backend with no diagnosis and no verdict. These tests fail if that
/// wiring is ever cut again.

class _Recorded {
  _Recorded(
    this.type,
    this.diag,
    this.error,
    this.host,
    this.attemptId,
    this.strategy,
    this.door,
  );
  final VpnEventType type;
  final Map<String, dynamic>? diag;
  final String? error;
  final String? host;
  final String? attemptId;
  final Map<String, dynamic>? strategy;
  final String? door;
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
    events.add(
      _Recorded(type, diag, error, serverHost, attemptId, strategy, door),
    );
  }
}

class _FakeDiagnostics extends ConnectDiagnostics {
  static const answer = {'control': 'ok', 'tcp': 'timeout'};
  static const platformAnswer = {'carrier': 'Irancell', 'network': 'mobile'};

  bool throwOnCollect = false;

  /// When set, a diagnosis waits for it, the way a real one takes seconds.
  Completer<void>? hold;
  int collectCalls = 0;
  int platformCalls = 0;
  String? lastHost;
  int? lastPort;
  String? lastSni;

  @override
  Future<Map<String, dynamic>> collect({
    String? host,
    int port = 443,
    String? sni,
  }) async {
    collectCalls++;
    lastHost = host;
    lastPort = port;
    lastSni = sni;
    if (throwOnCollect) throw StateError('probe blew up');
    await hold?.future;
    // The real collect() folds the platform report in alongside the
    // probes, so a fake that returns the probes alone would hide the one
    // key a success must never arrive without.
    return {...platformAnswer, ...answer};
  }

  @override
  Future<Map<String, dynamic>> platformReport() async {
    platformCalls++;
    return platformAnswer;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.vpn.fortivavpn/tunnel');
  const uri =
      'vless://uuid@edge.fortivavpn.com:8443?security=reality&sni=www.speedtest.net#DE';

  late _CapturingReporter reporter;
  late _FakeDiagnostics diagnostics;
  late VpnService service;
  late List<String> nativeCalls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    nativeCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          nativeCalls.add(call.method);
          return null;
        });
    reporter = _CapturingReporter();
    diagnostics = _FakeDiagnostics();
    service = VpnService(events: reporter, diagnostics: diagnostics);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('a verification failure carries the diagnosis', () async {
    await service.reportVerifyFailure(
      'edge.fortivavpn.com',
      uri,
      'Server not working, try another',
    );

    expect(reporter.events, hasLength(1));
    final event = reporter.events.single;
    expect(event.type, VpnEventType.verifyFailed);
    expect(event.host, 'edge.fortivavpn.com');
    expect(event.diag, containsPair('control', 'ok'));
    expect(event.diag, containsPair('tcp', 'timeout'));
  });

  test('the probes read the port and the sni out of the link', () async {
    await service.reportVerifyFailure('edge.fortivavpn.com', uri, 'nope');
    expect(diagnostics.lastHost, 'edge.fortivavpn.com');
    expect(diagnostics.lastPort, 8443);
    expect(diagnostics.lastSni, 'www.speedtest.net');
  });

  test('the tunnel comes down before anything is probed', () async {
    // On iOS the app's own traffic goes through the tunnel, so probing a
    // still-open dead tunnel would call a working network broken.
    await service.reportVerifyFailure('edge.fortivavpn.com', uri, 'nope');
    expect(nativeCalls, contains('disconnect'));
    expect(nativeCalls.indexOf('disconnect'), 0);
  });

  test('a connect failure carries the diagnosis', () async {
    await service.reportConnectFailure('edge.fortivavpn.com', uri, 'TIMEOUT');
    final event = reporter.events.single;
    expect(event.type, VpnEventType.connectFailed);
    expect(event.error, 'TIMEOUT');
    expect(event.diag, containsPair('control', 'ok'));
  });

  test('a drop carries both the diagnosis and its own reason', () async {
    await service.reportDrop(
      'edge.fortivavpn.com',
      uri,
      const Duration(minutes: 3),
      'network_lost',
    );
    final event = reporter.events.single;
    expect(event.type, VpnEventType.dropped);
    expect(event.diag, containsPair('drop_reason', 'network_lost'));
    expect(event.diag, containsPair('control', 'ok'));
  });

  test('the first success on a network is measured like a failure', () async {
    // Successes used to carry the platform report alone, so every DNS, TCP
    // and TLS timing we held came from an attempt that failed. Anything
    // learned from that learns "was measured, therefore failed".
    await service.reportConnected(
      'edge.fortivavpn.com',
      const Duration(seconds: 4),
    );
    final event = reporter.events.single;
    expect(event.type, VpnEventType.connected);
    // The carrier is the denominator every per-carrier failure rate needs,
    // and the backend cannot read it off a batch that left through the tunnel.
    expect(event.diag, containsPair('carrier', 'Irancell'));
    expect(event.diag, containsPair('tcp', 'timeout'));
    expect(diagnostics.collectCalls, 1);
  });

  test('later successes on the same network skip the probes', () async {
    // The checks cost about a second and the user is watching, so one
    // reading per network per day is the whole budget.
    await service.reportConnected('edge.fortivavpn.com', null);
    await service.reportConnected('edge.fortivavpn.com', null);
    await service.reportConnected('edge.fortivavpn.com', null);
    expect(diagnostics.collectCalls, 1);
    expect(reporter.events.length, 3);
    // Every one still carries the carrier, which is the part that must
    // never be sampled.
    for (final e in reporter.events) {
      expect(e.diag, containsPair('carrier', 'Irancell'));
    }
  });

  test('a success that cannot be measured is still reported', () async {
    diagnostics.throwOnCollect = true;
    await service.reportConnected('edge.fortivavpn.com', null);
    final event = reporter.events.single;
    expect(event.type, VpnEventType.connected);
    expect(event.diag, containsPair('carrier', 'Irancell'));
  });

  test('a diagnosis that throws still lets the failure be reported', () async {
    diagnostics.throwOnCollect = true;
    await service.reportVerifyFailure('edge.fortivavpn.com', uri, 'nope');
    final event = reporter.events.single;
    expect(event.type, VpnEventType.verifyFailed);
    expect(event.error, 'nope');
    expect(event.diag, isNull);
  });

  test('a failure with no link still reports what it can', () async {
    await service.reportConnectFailure(null, null, 'PERMISSION_DENIED');
    expect(diagnostics.lastPort, 443); // the default, not a crash
    expect(reporter.events.single.diag, containsPair('control', 'ok'));
  });

  test('a failure is reported under the attempt that failed', () async {
    // The connect flow dials the next door the moment one fails, while the
    // failed one is still being torn down and diagnosed. Read after that,
    // a dead shared link was reported under the own door that replaced it.
    const shared = Server(
      id: 'official-9',
      name: 'Fortiva DE Nuremberg (CDN)',
      country: 'Germany',
      city: 'Nuremberg',
      connectionUri:
          'vless://s@198.51.100.215:443?security=tls&type=ws&sni=files.example#cdn',
      flagEmoji: '',
    );
    const own = Server(
      id: 'dedicated-0',
      name: 'Fortiva DE',
      country: 'Germany',
      city: 'Nuremberg',
      connectionUri: uri,
      flagEmoji: '',
      isDedicated: true,
      door: 'xhttp-reality',
    );
    diagnostics.hold = Completer<void>();

    await service.connect(shared, attemptId: 'a' * 32);
    final report = service.reportVerifyFailure(
      '198.51.100.215',
      shared.connectionUri,
      'Server not working, try another',
    );
    await service.connect(own, attemptId: 'b' * 32);
    diagnostics.hold!.complete();
    await report;

    final failed = reporter.events.singleWhere(
      (e) => e.type == VpnEventType.verifyFailed,
    );
    expect(failed.attemptId, 'a' * 32);
    expect(failed.door, isNull);
    expect(failed.strategy?['sni'], 'files.example');
  });

  test(
    'a tunnel that comes up is not called working before its check',
    () async {
      // The connect flow takes "connected and not verifying" as a tunnel that
      // carries traffic. On 2026-09-28 a dead community link came up on an
      // emulator, the flow called it a success in that gap, the traffic
      // check failed a moment later, and the phone's own doors were never
      // tried.
      const link = Server(
        id: 'telegram-3',
        name: 'AD',
        country: 'Andorra',
        city: '',
        connectionUri: 'vless://u@203.0.113.225:443?security=reality#AD',
        flagEmoji: '',
      );
      await service.connect(link);
      final seen = <(VpnStatus, bool)>[];
      service.addListener(
        () => seen.add((service.status, service.isVerifying)),
      );

      service.applyNativeStatus('connected');

      expect(seen, isNotEmpty);
      expect(
        seen.where((s) => s.$1 == VpnStatus.connected && !s.$2),
        isEmpty,
        reason: 'connected was announced before the traffic check began',
      );
      await service.disconnect();
    },
  );
}
