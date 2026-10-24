import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/dial_server.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tap while the app is connecting, or checking a tunnel that just came
/// up, stops it at once. On 2026-10-07 the screen sat on "Checking
/// connection" and a tap on the button did nothing.
///
/// A stop is only a stop if nothing the connect started can undo it: no
/// door checked or dialled after it, no late "connected" from the platform
/// put back on screen, and no failure shown or reported for it.
Server door(String host, String door) => Server(
  id: 'dedicated-$host:443',
  name: host,
  country: '',
  city: host,
  connectionUri: 'vless://u@$host:443?type=tcp#$host',
  flagEmoji: '',
  isDedicated: true,
  door: door,
);

/// A tunnel whose start waits for the test to end it, the way a slow start
/// keeps the screen on "Connecting".
class _SlowVpn extends VpnService {
  _SlowVpn() : super(events: VpnEventReporter(send: (_, _, _) async {}));

  final dialled = <String>[];
  final attemptIds = <String?>[];
  int stops = 0;
  Completer<bool>? _start;
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
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {
    dialled.add(server.pathKey);
    attemptIds.add(attemptId);
    _fakeStatus = VpnStatus.connecting;
    notifyListeners();
    final up = await (_start = Completer<bool>()).future;
    _fakeStatus = up ? VpnStatus.connected : VpnStatus.error;
    notifyListeners();
  }

  /// Ends the start in flight, up or failed.
  void finishStart({required bool up}) => _start?.complete(up);

  @override
  Future<void> disconnect() async {
    stops++;
    _fakeStatus = VpnStatus.disconnected;
    notifyListeners();
  }

  @override
  void clearError() {
    if (_fakeStatus == VpnStatus.error) _fakeStatus = VpnStatus.disconnected;
    notifyListeners();
  }
}

/// The door memory, with one read or write held until the test lets it go.
class _HeldMemory extends PathMemory {
  Completer<void>? recallGate;
  Completer<void>? rememberGate;
  final reached = <String>[];

  @override
  Future<String?> recall(String network) async {
    reached.add('recall');
    await recallGate?.future;
    return super.recall(network);
  }

  @override
  Future<void> remember(
    String network,
    String pathKey, {
    Iterable<String>? holding,
  }) async {
    reached.add('remember');
    await rememberGate?.future;
    return super.remember(network, pathKey, holding: holding);
  }
}

class _Recorded {
  _Recorded(this.type, this.error);
  final VpnEventType type;
  final String? error;
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
    events.add(_Recorded(type, error));
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

  final hel1 = door('hel', 'tcp-reality');
  final hel2 = door('hel', 'xhttp-reality');
  final fsn1 = door('fsn', 'tcp-reality');
  final paths = [hel1, hel2, fsn1];

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the connect flow, stopped', () {
    late List<String> probed;
    late Map<String, Completer<int>> probeGates;
    late int probesInFlight;
    late int mostInFlight;
    late int sharedAsked;
    late int allowanceAsked;
    late List<List<Map<String, dynamic>>> sentChecks;

    setUp(() {
      probed = [];
      probeGates = {};
      probesInFlight = 0;
      mostInFlight = 0;
      sharedAsked = 0;
      allowanceAsked = 0;
      sentChecks = [];
    });

    ConnectFlow flow(
      VpnService vpn, {
      PathMemory? memory,
      Future<String?> Function()? carrier,
      ChecklistSettings? checklist,
    }) => ConnectFlow(
      vpn: vpn,
      memory: memory ?? PathMemory(),
      finder: PathFinder(
        probe: (p) async {
          probed.add(p.pathKey);
          probesInFlight++;
          if (probesInFlight > mostInFlight) mostInFlight = probesInFlight;
          try {
            return await (probeGates[p.pathKey]?.future ?? Future.value(-1));
          } finally {
            probesInFlight--;
          }
        },
        internet: () async => true,
      ),
      reporter: VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, probes, _) async {
          final checks = [
            for (final p in probes)
              if (p['source'] == 'diagnosis') p,
          ];
          if (checks.isNotEmpty) sentChecks.add(checks);
        },
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.13',
        platform: 'android',
        networkType: () async => 'mobile',
      ),
      networkKey: () async => 'mobile:Irancell',
      carrier: carrier ?? () async => 'Irancell',
      checklist: () => checklist,
      attemptTimeout: const Duration(seconds: 2),
    );

    Future<void> connect(ConnectFlow f) => f.connect(
      paths,
      preferred: hel1,
      shared: () async {
        sharedAsked++;
        return const [];
      },
      allowanceSpent: () async {
        allowanceAsked++;
        return false;
      },
    );

    /// Lets the flow run up to its next wait on something outside it.
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('while the tunnel is starting, ends the run there', () async {
      await PathMemory().remember('mobile:Irancell', hel1.pathKey);
      final vpn = _SlowVpn();
      final f = flow(vpn);

      final run = connect(f);
      await settle();
      expect(vpn.dialled, [hel1.pathKey]);
      expect(f.isBusy, isTrue);

      await stopConnecting(vpn: vpn, flow: f);
      expect(f.stage, ConnectStage.cancelled);
      expect(vpn.stops, 1);

      // The start the stop interrupted reports its failure late.
      vpn.finishStart(up: false);
      await run;

      expect(vpn.dialled, [hel1.pathKey]);
      expect(probed, isEmpty);
      expect(sharedAsked, 0);
      // Not asked: nothing failed before the stop.
      expect(allowanceAsked, 0);
      expect(f.stage, ConnectStage.cancelled);
      // The door was not marked failed: the user stopped it, it did not
      // fail.
      expect(await PathMemory().skippable('mobile:Irancell'), isEmpty);
      expect(await PathMemory().failedToday('mobile:Irancell'), isEmpty);
      // Stopped at once, well before FastPathSettings.forgetAfter, so it is
      // still the door to try first.
      expect(await PathMemory().recall('mobile:Irancell'), hel1.pathKey);
    });

    test('while the door memory is read, dials nothing', () async {
      await PathMemory().remember('mobile:Irancell', hel1.pathKey);
      final memory = _HeldMemory()..recallGate = Completer<void>();
      final vpn = _SlowVpn();
      final f = flow(vpn, memory: memory);

      final run = connect(f);
      while (!memory.reached.contains('recall')) {
        await settle();
      }
      await stopConnecting(vpn: vpn, flow: f);
      memory.recallGate!.complete();
      await run;

      expect(vpn.dialled, isEmpty);
      expect(probed, isEmpty);
      expect(f.isBusy, isFalse);
    });

    test('during a door check, does not dial the door the check finds '
        'open', () async {
      probeGates[hel1.pathKey] = Completer<int>();
      final vpn = _SlowVpn();
      final f = flow(vpn);

      final run = connect(f);
      while (probed.isEmpty) {
        await settle();
      }
      expect(f.stage, ConnectStage.diagnosing);

      await stopConnecting(vpn: vpn, flow: f);
      expect(f.stage, ConnectStage.cancelled);
      expect(f.showChecklist, isFalse);

      probeGates[hel1.pathKey]!.complete(120);
      await run;

      expect(probed, [hel1.pathKey]);
      expect(vpn.dialled, isEmpty);
      expect(sharedAsked, 0);
      expect(f.stage, ConnectStage.cancelled);
    });

    test('during a door check that comes back closed, sends no door '
        'checks', () async {
      probeGates[hel1.pathKey] = Completer<int>()..complete(-1);
      final second = probeGates[hel2.pathKey] = Completer<int>();
      final vpn = _SlowVpn();
      final f = flow(vpn);

      final run = connect(f);
      while (!probed.contains(hel2.pathKey)) {
        await settle();
      }
      await stopConnecting(vpn: vpn, flow: f);
      second.complete(-1);
      await run;
      for (var i = 0; i < 5; i++) {
        await settle();
      }

      // hel1 and hel2 closed, fsn1 never checked. Sent, these rows would
      // tell the backend this phone found every door closed.
      expect(probed, [hel1.pathKey, hel2.pathKey]);
      expect(sentChecks, isEmpty);
      expect(vpn.dialled, isEmpty);
    });

    test('door checks go out under the id of the tap that made them', () async {
      probeGates[hel1.pathKey] = Completer<int>()..complete(120);
      final carrier = Completer<String?>();
      final vpn = _SlowVpn();
      final f = flow(vpn, carrier: () => carrier.future);

      // The first tap finds hel1 open and dials it. Its report waits on the
      // carrier while the user stops and taps again.
      final first = connect(f);
      while (vpn.dialled.isEmpty) {
        await settle();
      }
      await stopConnecting(vpn: vpn, flow: f);
      vpn.finishStart(up: false);
      await first;

      final second = connect(f);
      while (vpn.dialled.length < 2) {
        await settle();
      }
      await stopConnecting(vpn: vpn, flow: f);
      vpn.finishStart(up: false);
      await second;

      carrier.complete('Irancell');
      while (sentChecks.length < 2) {
        await settle();
      }

      final firstId = vpn.attemptIds[0];
      final secondId = vpn.attemptIds[1];
      expect(firstId, isNot(secondId));
      expect(sentChecks[0].map((c) => c['attempt_id']), everyElement(firstId));
      expect(sentChecks[1].map((c) => c['attempt_id']), everyElement(secondId));
    });

    test('one at a time, a tap right after it waits for the check still in '
        'flight', () async {
      final firstGate = probeGates[hel1.pathKey] = Completer<int>();
      final vpn = _SlowVpn();
      // door_parallel 1: the search of 1.7.0.
      final f = flow(
        vpn,
        checklist: const ChecklistSettings(doors: DoorCheckSettings.oneAtATime),
      );

      final first = connect(f);
      while (probed.isEmpty) {
        await settle();
      }
      await stopConnecting(vpn: vpn, flow: f);

      // The second tap, before the first check has come back.
      final second = connect(f);
      for (var i = 0; i < 5; i++) {
        await settle();
      }
      expect(probed, [hel1.pathKey]);

      // The first check comes back. The second tap's checks start now,
      // never beside it, so two searches never write the same rows.
      probeGates[hel1.pathKey] = Completer<int>()..complete(-1);
      probeGates[hel2.pathKey] = Completer<int>()..complete(150);
      firstGate.complete(-1);
      await first;
      while (vpn.dialled.isEmpty) {
        await settle();
      }
      vpn.finishStart(up: true);
      await second;

      expect(mostInFlight, 1);
      expect(probed, [hel1.pathKey, hel1.pathKey, hel2.pathKey]);
      expect(vpn.dialled, [hel2.pathKey]);
      expect(f.stage, ConnectStage.done);
    });

    test('a tap right after it does not wait for the checks still in flight, '
        'and their answers change none of its rows', () async {
      final firstGate = probeGates[hel1.pathKey] = Completer<int>();
      final vpn = _SlowVpn();
      final f = flow(vpn);

      final first = connect(f);
      while (probed.isEmpty) {
        await settle();
      }
      await stopConnecting(vpn: vpn, flow: f);
      // Several checks at once: the search ended on the stop.
      await first.timeout(const Duration(seconds: 1));

      // The second tap, before the first check has come back.
      probeGates[hel1.pathKey] = Completer<int>()..complete(-1);
      probeGates[hel2.pathKey] = Completer<int>()..complete(150);
      final second = connect(f);
      while (vpn.dialled.isEmpty) {
        await settle();
      }
      expect(probed, [hel1.pathKey, hel1.pathKey, hel2.pathKey]);
      expect(mostInFlight, 2);

      // The first tap's check comes back late, open.
      var heard = 0;
      void count() => heard++;
      f.addListener(count);
      firstGate.complete(120);
      await settle();
      f.removeListener(count);
      expect(heard, 0);
      expect(f.checks.map((c) => c.state), [
        PathCheckState.blocked,
        PathCheckState.open,
        PathCheckState.pending,
      ]);

      vpn.finishStart(up: true);
      await second;

      expect(vpn.dialled, [hel2.pathKey]);
      expect(f.stage, ConnectStage.done);
    });

    test('after the tunnel is up, before the flow has recorded it, ends '
        'on the stop', () async {
      await PathMemory().remember('mobile:Irancell', hel2.pathKey);
      final memory = _HeldMemory()..rememberGate = Completer<void>();
      final vpn = _SlowVpn();
      final f = flow(vpn, memory: memory);

      final run = f.connect(paths, preferred: hel2);
      while (vpn.dialled.isEmpty) {
        await settle();
      }
      vpn.finishStart(up: true);
      while (!memory.reached.contains('remember')) {
        await settle();
      }

      await stopConnecting(vpn: vpn, flow: f);
      memory.rememberGate!.complete();
      await run;

      // Not "done": the tunnel this run brought up is the one the user
      // just took down.
      expect(f.stage, ConnectStage.cancelled);
      expect(vpn.status, VpnStatus.disconnected);
    });
  });

  group('the tunnel, stopped', () {
    const channel = MethodChannel('com.vpn.fortivavpn/tunnel');
    final a = door('edge-a.example', 'xhttp-reality');
    late List<String> calls;
    late _CapturingReporter reporter;

    setUp(() {
      calls = [];
      reporter = _CapturingReporter();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    /// Installs the platform inside the fake clock, so its replies run on
    /// it. Every call is recorded; the traffic check never passes. A dial
    /// or a stop is answered once [dialAnswer] or [stopAnswer] completes.
    void install({Future<void>? dialAnswer, Future<void>? stopAnswer}) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            switch (call.method) {
              case 'getStatus':
                return 'disconnected';
              case 'testConnection':
                return false;
              case 'connect':
                await dialAnswer;
                return null;
              case 'disconnect':
                await stopAnswer;
                return null;
              default:
                return null;
            }
          });
    }

    int stopsSent() => calls.where((c) => c == 'disconnect').length;

    VpnService service() =>
        VpnService(events: reporter, diagnostics: _FakeDiagnostics());

    /// The platform's reply travels through the messenger, not a
    /// microtask.
    void reply(FakeAsync async) =>
        async.elapse(const Duration(milliseconds: 1));

    Iterable<VpnEventType> types() => reporter.events.map((e) => e.type);

    test('while its traffic is checked, shows the stop at once and reports '
        'nothing as a failure', () {
      fakeAsync((async) {
        install();
        final vpn = service();
        unawaited(vpn.connect(a));
        reply(async);
        vpn.applyNativeStatus('connected');
        expect(vpn.isVerifying, isTrue);

        unawaited(vpn.disconnect());
        expect(vpn.status, VpnStatus.disconnecting);
        expect(vpn.isVerifying, isFalse);

        reply(async);
        vpn.applyNativeStatus('disconnected');
        async.elapse(const Duration(seconds: 40));

        expect(vpn.status, VpnStatus.disconnected);
        expect(vpn.errorMessage, isNull);
        expect(vpn.failureVerdict, isNull);
        expect(calls, contains('disconnect'));
        // Not a failure, not a drop, and no end to a session that was
        // never recorded as connected.
        expect(types(), isEmpty);
        vpn.dispose();
      });
    });

    test('before the dial reaches the platform, never sends it', () {
      fakeAsync((async) {
        install();
        final vpn = service();
        unawaited(vpn.connect(a));
        // The dial waits on the stored settings before it calls the
        // platform. The stop lands in that wait.
        expect(vpn.status, VpnStatus.connecting);
        unawaited(vpn.disconnect());
        expect(vpn.status, VpnStatus.disconnecting);

        async.elapse(const Duration(seconds: 30));

        expect(calls, isNot(contains('connect')));
        expect(vpn.status, VpnStatus.disconnected);
        expect(vpn.errorMessage, isNull);
        expect(types(), isEmpty);
        vpn.dispose();
      });
    });

    test('a start the platform finishes after the stop is stopped again, '
        'and not shown', () {
      fakeAsync((async) {
        install();
        final vpn = service();
        unawaited(vpn.connect(a));
        reply(async);
        expect(calls, contains('connect'));

        unawaited(vpn.disconnect());
        reply(async);
        final stopsBefore = calls.where((c) => c == 'disconnect').length;

        // The stop reached the platform before its service listened, so
        // the start carried on and now says it is up.
        vpn.applyNativeStatus('connected');
        reply(async);
        expect(vpn.status, isNot(VpnStatus.connected));
        expect(vpn.isVerifying, isFalse);
        expect(calls.where((c) => c == 'disconnect').length, stopsBefore + 1);

        // Or it says it failed. That is not a failure the user has.
        vpn.applyNativeStatus('failed');
        expect(vpn.status, isNot(VpnStatus.error));
        expect(vpn.errorMessage, isNull);

        async.elapse(const Duration(seconds: 30));
        expect(vpn.status, VpnStatus.disconnected);
        expect(types(), isEmpty);
        vpn.dispose();
      });
    });

    test('the next connect is not held by the last stop', () {
      fakeAsync((async) {
        install();
        final vpn = service();
        unawaited(vpn.connect(a));
        reply(async);
        unawaited(vpn.disconnect());
        reply(async);
        vpn.applyNativeStatus('disconnected');

        unawaited(vpn.connect(a));
        reply(async);
        vpn.applyNativeStatus('connected');

        expect(vpn.status, VpnStatus.connected);
        expect(vpn.isVerifying, isTrue);
        unawaited(vpn.disconnect());
        vpn.applyNativeStatus('disconnected');
        async.elapse(const Duration(seconds: 30));
        vpn.dispose();
      });
    });

    test('a "failed" from the stopped start, before the next dial reaches '
        'the platform, is not the next attempt\'s', () {
      fakeAsync((async) {
        var dialAnswer = Completer<void>()..complete();
        install(dialAnswer: dialAnswer.future);
        final vpn = service();
        unawaited(vpn.connect(a));
        reply(async);
        unawaited(vpn.disconnect());
        reply(async);
        vpn.applyNativeStatus('disconnected');

        // The user taps again at once. The platform has not answered the
        // dial yet, so its start has not begun.
        dialAnswer = Completer<void>();
        install(dialAnswer: dialAnswer.future);
        unawaited(vpn.connect(a));
        reply(async);
        expect(calls.where((c) => c == 'connect').length, 2);

        // The start the user stopped fails late.
        vpn.applyNativeStatus('failed');
        async.elapse(const Duration(seconds: 1));
        expect(vpn.status, VpnStatus.connecting);
        expect(vpn.errorMessage, isNull);
        expect(types(), isNot(contains(VpnEventType.connectFailed)));

        // Once the dial is answered, a failure is this attempt's own.
        dialAnswer.complete();
        reply(async);
        vpn.applyNativeStatus('failed');
        async.elapse(const Duration(seconds: 1));
        expect(vpn.status, VpnStatus.error);
        expect(types(), contains(VpnEventType.connectFailed));
        vpn.dispose();
      });
    });

    test('once the platform confirms the stop, a tunnel started elsewhere '
        'stays up', () {
      fakeAsync((async) {
        install();
        final vpn = service();
        unawaited(vpn.connect(a));
        reply(async);
        unawaited(vpn.disconnect());
        reply(async);
        vpn.applyNativeStatus('disconnected');
        final stops = stopsSent();

        // The quick settings tile starts the tunnel.
        vpn.applyNativeStatus('connected');
        reply(async);
        expect(stopsSent(), stops);
        expect(vpn.status, VpnStatus.connected);
        vpn.dispose();
      });
    });

    test('a stop the platform never confirms holds for one outcome', () {
      fakeAsync((async) {
        install();
        final vpn = service();
        unawaited(vpn.connect(a));
        reply(async);
        unawaited(vpn.disconnect());
        reply(async);

        // The stop was lost. The start comes up and is stopped again.
        vpn.applyNativeStatus('connected');
        reply(async);
        vpn.applyNativeStatus('disconnected');
        final stops = stopsSent();

        // Then the quick settings tile starts the tunnel.
        vpn.applyNativeStatus('connected');
        reply(async);
        expect(stopsSent(), stops);
        expect(vpn.status, VpnStatus.connected);
        vpn.dispose();
      });
    });

    test('a "disconnected" that comes before the platform answered the stop '
        'does not end the hold', () {
      fakeAsync((async) {
        final stopAnswer = Completer<void>();
        install(stopAnswer: stopAnswer.future);
        final vpn = service();
        unawaited(vpn.connect(a));
        reply(async);
        unawaited(vpn.disconnect());
        reply(async);

        // This one comes from an earlier teardown, not from the stop.
        vpn.applyNativeStatus('disconnected');
        stopAnswer.complete();
        reply(async);
        final stops = stopsSent();

        // The stop was lost, and the start comes up.
        vpn.applyNativeStatus('connected');
        reply(async);
        expect(stopsSent(), stops + 1);
        expect(vpn.status, isNot(VpnStatus.connected));
        async.elapse(const Duration(seconds: 30));
        vpn.dispose();
      });
    });

    test('after a door failed and before the next is tried, clears the '
        'failure', () {
      fakeAsync((async) {
        install();
        final vpn = service();
        unawaited(vpn.connect(a));
        reply(async);
        vpn.applyNativeStatus('failed');
        async.flushMicrotasks();
        expect(vpn.status, VpnStatus.error);
        final reported = reporter.events.length;

        unawaited(vpn.disconnect());

        expect(vpn.status, VpnStatus.disconnected);
        expect(vpn.errorMessage, isNull);
        reply(async);
        expect(calls.last, 'disconnect');
        // The failure was reported when it happened, and only then.
        async.elapse(const Duration(seconds: 30));
        expect(reporter.events.length, reported);
        vpn.dispose();
      });
    });
  });
}
