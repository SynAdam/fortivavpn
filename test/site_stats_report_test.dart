import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The sites a session reached only count if they are actually sent, and
/// production showed they were not: a drain ran on the five minute beat and
/// nowhere else, so every session shorter than that reported nothing. Device
/// 689 sent ten beats and nine site reports, the missing one being the early
/// beat; devices whose sessions lasted under a minute sent none at all.
class _CapturingReporter extends VpnEventReporter {
  _CapturingReporter()
    : super(
        send: (_, _, _) async {},
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.6',
        platform: 'android',
        osVersion: '14',
        networkType: () async => 'mobile',
      );

  /// Each call's counts, so a test can see what one drain sent.
  final reported = <Map<String, int>>[];

  /// When false, the send fails the way a dead network fails it.
  bool accept = true;

  /// When set, a send waits on this before finishing, so a test can hold one
  /// in flight and start another drain underneath it.
  Completer<void>? gate;

  /// How many sends are in flight at once. The whole point of serialising is
  /// that this never exceeds one.
  int inFlight = 0;
  int maxInFlight = 0;

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
  }) async {}

  @override
  Future<bool> reportDomains(Map<String, int> counts) async {
    if (counts.isEmpty) return true;
    inFlight++;
    maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
    try {
      if (gate != null) await gate!.future;
      if (!accept) return false;
      reported.add(Map.of(counts));
      return true;
    } finally {
      inFlight--;
    }
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
  late Map<String, Object?>? drained;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    drained = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return switch (call.method) {
            'tunnelStats' => {
              'bytes_up': 1000,
              'bytes_down': 900000,
              'carrier': 'Irancell',
              'network': 'mobile',
              'metered': false,
            },
            'throughputSample' => {'bytes': 1000000, 'ms': 2000},
            // One drain's worth, then nothing, the way the native cursor
            // behaves: a line already read is never returned twice.
            'drainSiteStats' => () {
              final out = drained;
              drained = null;
              return out;
            }(),
            _ => null,
          };
        });
    reporter = _CapturingReporter();
    service = VpnService(events: reporter, diagnostics: _FakeDiagnostics());
    service.applyNativeStatus('connected');
  });

  tearDown(() {
    service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'a session that ends before the first beat still reports its sites',
    () async {
      drained = {'bbc.com': 5, 'github.com': 2};

      // Under five minutes, so no periodic beat ever ran. This is the shape of
      // most real sessions and it used to report nothing at all.
      service.applyNativeStatus('disconnected');
      await Future<void>.delayed(Duration.zero);

      expect(reporter.reported.single, {'bbc.com': 5, 'github.com': 2});
    },
  );

  test('the early throughput beat reports sites too', () async {
    drained = {'bbc.com': 3};

    await service.sampleThroughput();

    expect(reporter.reported.single, {'bbc.com': 3});
  });

  test(
    'counts the backend refused are kept and go out with the next drain',
    () async {
      reporter.accept = false;
      drained = {'bbc.com': 2};
      await service.sampleThroughput();
      expect(reporter.reported, isEmpty);

      // The drain already moved the native cursor, so these counts exist
      // nowhere else: losing them here would lose the session.
      reporter.accept = true;
      drained = {'bbc.com': 1, 'github.com': 4};
      service.applyNativeStatus('disconnected');
      await Future<void>.delayed(Duration.zero);

      expect(reporter.reported.single, {'bbc.com': 3, 'github.com': 4});
    },
  );

  test('overlapping drains never send the same counts twice', () async {
    // The backend adds what it is sent, so a site in two snapshots is a site
    // counted twice on the dashboard this feeds.
    final gate = Completer<void>();
    reporter.gate = gate;

    drained = {'bbc.com': 5};
    final first = service.sampleThroughput();
    await Future<void>.delayed(Duration.zero);

    // A second drain starts while the first send is still in flight.
    drained = {'cnn.com': 3};
    service.applyNativeStatus('disconnected');
    await Future<void>.delayed(Duration.zero);

    gate.complete();
    await first;
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(reporter.maxInFlight, 1, reason: 'drains must not overlap');
    final total = <String, int>{};
    for (final r in reporter.reported) {
      r.forEach((k, v) => total[k] = (total[k] ?? 0) + v);
    }
    expect(total, {'bbc.com': 5, 'cnn.com': 3});
  });

  test('a send keeps counts that arrived while it was in flight', () async {
    final gate = Completer<void>();
    reporter.gate = gate;
    reporter.accept = false;

    drained = {'bbc.com': 5};
    final first = service.sampleThroughput();
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    await first;

    // That send failed, so those counts must still go out next time.
    reporter.accept = true;
    reporter.gate = null;
    drained = {'cnn.com': 3};
    service.applyNativeStatus('disconnected');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final total = <String, int>{};
    for (final r in reporter.reported) {
      r.forEach((k, v) => total[k] = (total[k] ?? 0) + v);
    }
    expect(total, {'bbc.com': 5, 'cnn.com': 3});
  });

  test('a drain that found nothing sends nothing', () async {
    drained = null;

    await service.sampleThroughput();

    expect(reporter.reported, isEmpty);
  });
}
