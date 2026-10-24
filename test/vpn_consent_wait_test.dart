import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The first connect on a phone shows Android's VPN permission dialog. The
/// time the user spends on it is theirs: until 2026-10-02 the 20 second
/// watchdog failed the attempt while the dialog was still open, and the
/// tunnel came up under an error once they tapped OK. 18 times on 13
/// phones in the 14 days before.
const _server = Server(
  id: 'dedicated-0',
  name: 'Fortiva DE',
  country: 'Germany',
  city: 'Nuremberg',
  connectionUri: 'vless://u@edge.example.com:8443?security=reality&sni=x#DE',
  flagEmoji: '🌍',
  isDedicated: true,
  door: 'xhttp-reality',
);

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

/// A tunnel that waits on the permission dialog for [dialog], then comes up.
class _FakeVpn extends VpnService {
  _FakeVpn(this.dialog)
    : super(events: VpnEventReporter(send: (_, _, _) async {}));

  final Duration dialog;
  bool _waiting = false;
  VpnStatus _fakeStatus = VpnStatus.disconnected;

  @override
  VpnStatus get status => _fakeStatus;

  @override
  bool get awaitingPermission => _waiting;

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
    _fakeStatus = VpnStatus.connecting;
    _waiting = dialog > Duration.zero;
    notifyListeners();
    await Future.delayed(dialog);
    _waiting = false;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 10));
    _fakeStatus = VpnStatus.connected;
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

  const channel = MethodChannel('com.vpn.fortivavpn/tunnel');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the service watchdog', () {
    late Completer<void> answered;
    late String nativeStatus;

    setUp(() {
      nativeStatus = 'disconnected';
    });

    /// Installs the platform inside the fake clock, so its replies run on it.
    void install() {
      answered = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'connect':
                // Returns when the user has answered the dialog.
                await answered.future;
                return null;
              case 'getStatus':
                return nativeStatus;
              default:
                return null;
            }
          });
    }

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    VpnService service() => VpnService(
      events: VpnEventReporter(send: (_, _, _) async {}),
      diagnostics: _FakeDiagnostics(),
    );

    test('does not fail an attempt while the dialog is open', () {
      fakeAsync((async) {
        install();
        final vpn = service();
        unawaited(vpn.connect(_server).catchError((_) {}));
        async.flushMicrotasks();
        vpn.applyNativeStatus('awaiting_permission');

        async.elapse(const Duration(seconds: 70));

        expect(vpn.status, VpnStatus.connecting);
        expect(vpn.errorMessage, isNull);
        expect(vpn.awaitingPermission, isTrue);
        vpn.dispose();
      });
    });

    test('gives the start its full time once the user answers', () {
      fakeAsync((async) {
        install();
        final vpn = service();
        unawaited(vpn.connect(_server).catchError((_) {}));
        async.flushMicrotasks();
        vpn.applyNativeStatus('awaiting_permission');
        async.elapse(const Duration(seconds: 50));

        answered.complete();
        // The platform's reply travels through the messenger, not a
        // microtask.
        async.elapse(const Duration(milliseconds: 1));
        expect(vpn.awaitingPermission, isFalse);

        async.elapse(const Duration(seconds: 19));
        expect(vpn.status, VpnStatus.connecting);

        // A start that then says nothing at all is still caught.
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(vpn.status, VpnStatus.error);
        vpn.dispose();
      });
    });

    test('asks the platform when the dialog event was missed', () {
      fakeAsync((async) {
        nativeStatus = 'awaiting_permission';
        install();
        final vpn = service();
        unawaited(vpn.connect(_server).catchError((_) {}));
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 45));
        async.flushMicrotasks();

        expect(vpn.status, VpnStatus.connecting);
        expect(vpn.awaitingPermission, isTrue);
        vpn.dispose();
      });
    });

    test('still fails a start that never answers, with no dialog', () {
      fakeAsync((async) {
        install();
        final vpn = service();
        unawaited(vpn.connect(_server).catchError((_) {}));
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 21));
        async.flushMicrotasks();

        expect(vpn.status, VpnStatus.error);
        vpn.dispose();
      });
    });
  });

  group('the connect flow deadline', () {
    ConnectFlow flow(_FakeVpn vpn) => ConnectFlow(
      vpn: vpn,
      memory: PathMemory(),
      finder: PathFinder(probe: (_) async => 120, internet: () async => true),
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
      attemptTimeout: const Duration(milliseconds: 100),
    );

    test(
      'waits for a user reading the dialog longer than the deadline',
      () async {
        final vpn = _FakeVpn(const Duration(milliseconds: 300));
        final f = flow(vpn);

        await f.connect([_server]);

        expect(f.stage, ConnectStage.done);
        expect(f.chosen?.pathKey, _server.pathKey);
      },
    );

    test('still gives up on a tunnel that takes too long by itself', () async {
      // Same total wait, but no dialog: the tunnel itself is slow.
      final vpn = _SlowVpn(const Duration(milliseconds: 300));
      final f = flow(vpn);

      await f.connect([_server]);

      expect(f.stage, isNot(ConnectStage.done));
    });
  });
}

/// A tunnel that takes [delay] to come up with no dialog in the way.
class _SlowVpn extends _FakeVpn {
  _SlowVpn(this.delay) : super(Duration.zero);

  final Duration delay;

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {
    _fakeStatus = VpnStatus.connecting;
    notifyListeners();
    await Future.delayed(delay);
    if (_fakeStatus != VpnStatus.connecting) return;
    _fakeStatus = VpnStatus.connected;
    notifyListeners();
  }
}
