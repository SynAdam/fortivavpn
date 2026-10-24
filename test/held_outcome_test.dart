import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tap's connected event is in the queue as soon as the connection is
/// verified, before the reads its report waits for. On 2026-10-16 about
/// 0.7% of the taps whose trace said connected had no connected event: the
/// app's process ended before the platform report and the day's diagnosis
/// were done, and the event was never stored.

class _SlowDiagnostics extends ConnectDiagnostics {
  /// The platform report waits for this, as a closed app never finishes it.
  final platformDone = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> collect({
    String? host,
    int port = 443,
    String? sni,
  }) async => const {'control': 'ok'};

  @override
  Future<Map<String, dynamic>> platformReport() => platformDone.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.vpn.fortivavpn/tunnel');

  late List<Map<String, dynamic>> sent;
  late Duration sinceStart;

  VpnEventReporter reporter({Future<String?> Function()? networkType}) =>
      VpnEventReporter(
        post: (path, body) async {
          if (path.endsWith('/events')) {
            sent.addAll((body['events'] as List).cast<Map<String, dynamic>>());
          }
        },
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.11.0',
        platform: 'android',
        networkType: networkType ?? () async => 'mobile',
        queues: const [],
      );

  Future<List<Map<String, dynamic>>> stored() => reporter().queuedForTest();

  /// The steady clock the hold is measured on moves on by [by].
  void wait(Duration by) => sinceStart += by;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sent = [];
    sinceStart = const Duration(minutes: 5);
    VpnEventReporter.elapsed = () => sinceStart;
    VpnEventReporter.startNewRunForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('a held connected event', () {
    test('waits while it may be filled in, and the rest go round it', () async {
      final r = reporter();
      await r
          .hold(VpnEventType.connected, attemptId: 'tap-1', door: 'ws-tls')
          .stored;
      await r.record(VpnEventType.heartbeat, bytesUp: 10, bytesDown: 20);
      await r.flush();
      expect(sent.map((e) => e['type']), ['heartbeat']);
      expect(await stored(), hasLength(1));
    });

    test('is replaced by the full event, which keeps its time', () async {
      final r = reporter();
      final held = r.hold(
        VpnEventType.connected,
        attemptId: 'tap-1',
        door: 'ws-tls',
      );
      await held.stored;
      final heldAt = (await stored()).single['client_ts'];
      await r.recordHeld(
        held,
        VpnEventType.connected,
        attemptId: 'tap-1',
        door: 'ws-tls',
        diag: {'carrier': 'Irancell'},
      );
      await r.flush();
      final event = sent.single;
      expect(event['type'], 'connected');
      expect(event['client_ts'], heldAt);
      expect(event['carrier'], 'Irancell');
      expect((event['diag'] as Map?)?['held'], isNull);
      expect(event.keys.where((k) => k.startsWith('_')), isEmpty);
      expect(await stored(), isEmpty);
    });

    test('left by a run that ended is sent as it is, marked held', () async {
      await reporter()
          .hold(
            VpnEventType.connected,
            attemptId: 'tap-1',
            door: 'ws-tls',
            diag: {
              'timeline': {'tunnel_ms': 900},
            },
          )
          .stored;
      // The app was closed and opened again.
      VpnEventReporter.startNewRunForTest();
      await reporter().flush();
      final event = sent.single;
      expect(event['type'], 'connected');
      expect(event['attempt_id'], 'tap-1');
      final diag = event['diag'] as Map;
      expect(diag['held'], isTrue);
      expect(diag['timeline'], {'tunnel_ms': 900});
      expect(event.keys.where((k) => k.startsWith('_')), isEmpty);
    });

    test('not filled in within the time is sent, and a late record adds '
        'nothing', () async {
      final r = reporter();
      final held = r.hold(VpnEventType.connected, attemptId: 'tap-1');
      await held.stored;
      wait(VpnEventReporter.holdFor);
      await r.flush();
      expect(sent.single['diag'], {'held': true});
      await r.recordHeld(
        held,
        VpnEventType.connected,
        attemptId: 'tap-1',
        diag: {'carrier': 'Irancell'},
      );
      await r.flush();
      expect(sent, hasLength(1));
    });

    test(
      'a record while it is being sent as it was adds no second copy',
      () async {
        final gate = Completer<void>();
        var posts = 0;
        final r = VpnEventReporter(
          post: (path, body) async {
            if (!path.endsWith('/events')) return;
            if (posts++ == 0) await gate.future;
            sent.addAll((body['events'] as List).cast<Map<String, dynamic>>());
          },
          deviceId: () async => 'DEV-1',
          appVersion: () async => '1.11.0',
          platform: 'android',
          networkType: () async => 'mobile',
          queues: const [],
        );
        final held = r.hold(VpnEventType.connected, attemptId: 'tap-1');
        await held.stored;
        wait(VpnEventReporter.holdFor);
        final flushing = r.flush(); // the held row goes out as it was
        await Future<void>.delayed(Duration.zero);
        await r.recordHeld(
          held,
          VpnEventType.connected,
          attemptId: 'tap-1',
          diag: {'carrier': 'Irancell'},
        );
        gate.complete();
        await flushing;
        await r.flush();
        expect(sent.where((e) => e['type'] == 'connected'), hasLength(1));
        expect(await stored(), isEmpty);
      },
    );

    test('two holds of one tap are each filled by their own record, in any '
        'order', () async {
      final r = reporter();
      final a = r.hold(
        VpnEventType.connected,
        attemptId: 'tap-1',
        door: 'ws-tls',
      );
      await a.stored;
      wait(const Duration(seconds: 1));
      final b = r.hold(
        VpnEventType.connected,
        attemptId: 'tap-1',
        door: 'xhttp-reality',
      );
      await b.stored;
      final times = {for (final e in await stored()) e['door']: e['client_ts']};
      await r.recordHeld(
        b,
        VpnEventType.connected,
        attemptId: 'tap-1',
        door: 'xhttp-reality',
        diag: {'carrier': 'MCI'},
      );
      await r.recordHeld(
        a,
        VpnEventType.connected,
        attemptId: 'tap-1',
        door: 'ws-tls',
        diag: {'carrier': 'MCI'},
      );
      wait(VpnEventReporter.holdFor);
      await r.flush();
      expect(sent, hasLength(2));
      for (final e in sent) {
        expect(e['client_ts'], times[e['door']]);
        expect((e['diag'] as Map?)?['held'], isNull);
      }
    });

    test('a plain record with the same type and attempt is not taken for '
        'it', () async {
      final r = reporter();
      await r.hold(VpnEventType.connected, attemptId: 'tap-1').stored;
      await r.record(VpnEventType.heartbeat, attemptId: 'tap-1');
      await r.record(VpnEventType.connected, attemptId: 'tap-1', door: 'b');
      await r.flush();
      expect(sent.map((e) => e['type']), ['heartbeat', 'connected']);
      expect(sent.last['door'], 'b');
      expect(await stored(), hasLength(1)); // the hold still waits
    });

    test('is stored within a second when the network read hangs', () async {
      final r = reporter(networkType: () => Completer<String?>().future);
      final held = r.hold(VpnEventType.connected, attemptId: 'tap-1');
      expect(
        await held.stored.timeout(
          const Duration(seconds: 3),
          onTimeout: () => false,
        ),
        isTrue,
      );
      expect((await stored()).single.containsKey('network_type'), isFalse);
    });

    test('nothing is held while sharing is off', () async {
      SharedPreferences.setMockInitialValues({
        VpnEventReporter.sharePrefKey: false,
      });
      final held = reporter().hold(VpnEventType.connected, attemptId: 'x');
      expect(await held.stored, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(VpnEventReporter.storageKey), isNull);
    });
  });

  group('the connected event of a tap', () {
    test('is in the queue as soon as the connection is verified, and the '
        'next run sends it when the app was closed', () async {
      final diagnostics = _SlowDiagnostics();
      final service = VpnService(events: reporter(), diagnostics: diagnostics);
      // The platform report never finishes: the app is closed meanwhile.
      unawaited(service.reportConnected('edge.example', null));
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final queued = await stored();
      expect(queued.single['type'], 'connected');

      VpnEventReporter.startNewRunForTest();
      await reporter().flush();
      expect(sent.single['type'], 'connected');
      expect((sent.single['diag'] as Map)['held'], isTrue);
    });

    test('goes once, filled in, when the reads finish', () async {
      final diagnostics = _SlowDiagnostics();
      final events = reporter();
      final service = VpnService(events: events, diagnostics: diagnostics);
      final report = service.reportConnected('edge.example', null);
      await Future<void>.delayed(Duration.zero);
      diagnostics.platformDone.complete({'carrier': 'MCI'});
      await report;
      await events.flush();
      expect(await stored(), isEmpty);
      // Nothing is left to go out later either.
      wait(VpnEventReporter.holdFor);
      await events.flush();
      final connected = sent.where((e) => e['type'] == 'connected').toList();
      expect(connected, hasLength(1));
      expect(connected.single['carrier'], 'MCI');
      expect((connected.single['diag'] as Map?)?['held'], isNull);
    });

    test('a failure is recorded only once complete, never held', () async {
      final events = reporter();
      final service = VpnService(
        events: events,
        diagnostics: _SlowDiagnostics(),
      );
      await service.reportConnectFailure('edge.example', null, 'timeout');
      await events.flush();
      final failed = sent.where((e) => e['type'] == 'connect_failed').toList();
      expect(failed, hasLength(1));
      expect((failed.single['diag'] as Map?)?['held'], isNull);
      expect(await stored(), isEmpty);
    });
  });
}
