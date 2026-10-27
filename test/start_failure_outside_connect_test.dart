import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A "failed" from the platform is a connect failure only while a connect
/// of this app waits for its start.
///
/// The tunnel can also be started by the quick settings tile, the widget,
/// the notification's restart button or Android itself, and a start the
/// app's own watchdog already failed can still report. Each of those was
/// filed as a connect_failed row. On a run of the app that had made no
/// connect, the row had no attempt id, and the Live page counted it as a
/// failed tap: 16 of them in the week to 2026-10-27.
///
/// Only the row goes. The screen shows the failure as it did before.

class _Row {
  _Row(this.type, this.attemptId, this.diag);
  final VpnEventType type;
  final String? attemptId;
  final Map<String, dynamic>? diag;
}

class _Reporter extends VpnEventReporter {
  _Reporter() : super(send: (_, _, _) async {});

  final rows = <_Row>[];

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
    rows.add(_Row(type, attemptId, diag));
  }
}

class _Diagnostics extends ConnectDiagnostics {
  @override
  Future<Map<String, dynamic>> collect({
    String? host,
    int port = 443,
    String? sni,
  }) async => {'control': 'ok'};

  @override
  Future<Map<String, dynamic>> platformReport() async => {'network': 'mobile'};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.vpn.fortivavpn/tunnel');
  const door = Server(
    id: 'dedicated-0',
    name: 'Fortiva DE',
    country: 'Germany',
    city: 'Nuremberg',
    connectionUri: 'vless://u@198.51.100.20:443?security=reality#DE',
    flagEmoji: '',
    isDedicated: true,
    door: 'xhttp-reality',
  );
  late _Reporter reporter;
  late VpnService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    reporter = _Reporter();
    service = VpnService(events: reporter, diagnostics: _Diagnostics());
  });

  tearDown(() {
    service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Iterable<_Row> failures() =>
      reporter.rows.where((r) => r.type == VpnEventType.connectFailed);

  test('a start no connect asked for files nothing, and the screen shows '
      'it as before', () async {
    // The app has made no connect on this run: the tile or Android started
    // the tunnel, and its start failed.
    service.applyNativeStatus('failed:core:already_running');
    await pumpEventQueue();

    expect(failures(), isEmpty);
    expect(service.status, VpnStatus.error);
    expect(
      service.errorMessage,
      'The tunnel did not start. Try another location.',
    );
  });

  test('a bare failure with no connect files nothing either', () async {
    service.applyNativeStatus('failed');
    await pumpEventQueue();

    expect(failures(), isEmpty);
    expect(service.status, VpnStatus.error);
  });

  test('a stop the platform refused is no connect failure', () async {
    // The tunnel is up, the user stops it, and the platform's stop throws.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'disconnect') {
            throw PlatformException(code: 'STOP', message: 'stop failed');
          }
          return null;
        });
    await service.connect(door, attemptId: 'd' * 32);
    service.applyNativeStatus('connected');

    await expectLater(service.disconnect(), throwsA(isA<PlatformException>()));
    await pumpEventQueue();

    expect(failures(), isEmpty);
    expect(service.status, VpnStatus.error);
  });

  test('a late failure of a start already failed is not filed twice', () async {
    await service.connect(door, attemptId: 'a' * 32);
    service.applyNativeStatus('failed:core:startup_failed');
    await pumpEventQueue();
    expect(failures(), hasLength(1));
    expect(service.status, VpnStatus.error);

    // The same start, or another one nobody waits for, fails again.
    service.applyNativeStatus('failed:tun2socks:fd_not_sent');
    await pumpEventQueue();

    expect(failures(), hasLength(1));
    expect(failures().single.diag, containsPair('native_step', 'core'));
    expect(service.status, VpnStatus.error);
  });

  test('a failure before the first connect of a run has its attempt id is '
      'not filed', () async {
    // A tunnel this run of the app did not start, with nothing saved about
    // it, so no attempt id: the tile or Android brought it up.
    service.applyNativeStatus('connected');
    await pumpEventQueue();
    expect(service.status, VpnStatus.connected);

    // The first connect takes that tunnel down before it takes its own id,
    // and a start of the old tunnel reports a failure meanwhile. The status
    // reads "connecting", but no connect of this run has an attempt id yet.
    final dial = service.connect(door, attemptId: 'e' * 32);
    await pumpEventQueue();
    expect(service.status, VpnStatus.connecting);
    service.applyNativeStatus('failed:core:already_running');
    await pumpEventQueue();

    expect(failures(), isEmpty);
    await dial;
  });

  test('a failure while the connect waits for its start is filed under its '
      'attempt', () async {
    await service.connect(door, attemptId: 'b' * 32);
    expect(service.status, VpnStatus.connecting);

    service.applyNativeStatus('failed:interface:establish_error');
    await pumpEventQueue();

    expect(failures().single.attemptId, 'b' * 32);
    expect(service.status, VpnStatus.error);
  });

  test(
    'a failure while the new tunnel is still being checked is filed',
    () async {
      // The watchdog can find the interface up before the start has finished
      // (tun2socks), and the start can still fail after that.
      await service.connect(door, attemptId: 'c' * 32);
      service.applyNativeStatus('connected');
      expect(service.isVerifying, isTrue);

      service.applyNativeStatus('failed:tun2socks:fd_not_sent');
      await pumpEventQueue();

      expect(failures().single.attemptId, 'c' * 32);
      expect(service.status, VpnStatus.error);
      expect(service.isVerifying, isFalse);
    },
  );
}
