import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tunnel that comes up in twelve seconds and one that comes up in two
/// are both reported as connected, so a carrier that has started shaping
/// us is invisible until users say the app feels slow. The timeline turns
/// that into a number, and the resolver separates DNS interference from a
/// transport block. These tests pin both onto the events that carry them.
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
  _Recorded(this.type, this.diag);
  final VpnEventType type;
  final Map<String, dynamic>? diag;
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
    events.add(_Recorded(type, diag));
  }
}

class _FakeDiagnostics extends ConnectDiagnostics {
  @override
  Future<Map<String, dynamic>> collect({
    String? host,
    int port = 443,
    String? sni,
  }) async => {'control': 'ok', 'tcp': 'timeout'};

  @override
  Future<Map<String, dynamic>> platformReport() async => {
    'carrier': 'Irancell',
    'network': 'mobile',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.vpn.fortivavpn/tunnel');

  late _CapturingReporter reporter;
  late VpnService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    reporter = _CapturingReporter();
    service = VpnService(events: reporter, diagnostics: _FakeDiagnostics());
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('the attempt timeline', () {
    test('is not reported when no attempt has been made', () async {
      await service.reportConnected('edge.fortivavpn.com', null);

      final diag = reporter.events.single.diag;
      expect(diag, containsPair('carrier', 'Irancell'));
      expect(diag?.containsKey('timeline'), isFalse);
    });

    test('counts from the tap, and rides on the success', () async {
      await service.connect(_server);
      service.applyNativeStatus('connected');
      await service.reportConnected('edge.fortivavpn.com', null);

      final timeline =
          reporter.events.last.diag?['timeline'] as Map<String, int>?;
      expect(timeline, isNotNull);
      expect(timeline!['tunnel_ms'], isNotNull);
      // From the tap, so it cannot be negative and cannot predate the
      // attempt it belongs to.
      expect(timeline['tunnel_ms'], greaterThanOrEqualTo(0));
    });

    test('keeps the first mark when the platform repeats itself', () async {
      await service.connect(_server);
      service.applyNativeStatus('connected');
      final first = service.debugTimeline['tunnel_ms'];

      await Future<void>.delayed(const Duration(milliseconds: 20));
      service.applyNativeStatus('connected');

      expect(service.debugTimeline['tunnel_ms'], first);
    });

    test('starts again on the next tap', () async {
      await service.connect(_server);
      service.applyNativeStatus('connected');
      expect(service.debugTimeline, contains('tunnel_ms'));

      await service.connect(_server);
      expect(service.debugTimeline, isEmpty);
    });

    test('says how far a stalled attempt got', () async {
      await service.connect(_server);
      service.applyNativeStatus('connected');
      await service.reportVerifyFailure(
        'edge.fortivavpn.com',
        _server.connectionUri,
        'Server not working, try another',
      );

      final event = reporter.events.last;
      expect(event.type, VpnEventType.verifyFailed);
      // The diagnosis and the timeline both, so "came up then carried
      // nothing" is distinguishable from "never came up".
      expect(event.diag, containsPair('tcp', 'timeout'));
      expect(
        (event.diag?['timeline'] as Map<String, int>?)?['tunnel_ms'],
        isNotNull,
      );
    });
  });

  group('the resolver', () {
    test('is the user\'s setting where there is no native side', () async {
      SharedPreferences.setMockInitialValues({
        ConnectDiagnostics.prefRemoteDns: '9.9.9.9,149.112.112.112',
      });
      // No channel: the same shape as iOS, where nothing answers.
      final report = await ConnectDiagnostics().platformReport();
      expect(report['resolver'], '9.9.9.9,149.112.112.112');
    });

    test('is left out rather than guessed when nothing is set', () async {
      final report = await ConnectDiagnostics().platformReport();
      expect(report.containsKey('resolver'), isFalse);
    });

    test('is blank-tolerant', () async {
      SharedPreferences.setMockInitialValues({
        ConnectDiagnostics.prefRemoteDns: '   ',
      });
      final report = await ConnectDiagnostics().platformReport();
      expect(report.containsKey('resolver'), isFalse);
    });

    test('takes the platform over the preference when both exist', () async {
      SharedPreferences.setMockInitialValues({
        ConnectDiagnostics.prefRemoteDns: '9.9.9.9',
      });
      const native = MethodChannel('test/native');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            native,
            (call) async => {'resolver': '1.1.1.1', 'carrier': 'Irancell'},
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(native, null),
      );

      final report = await ConnectDiagnostics(channel: native).platformReport();
      // The core's real setting wins: the preference is what the user
      // asked for, the platform reports what the core is running with,
      // defaults included.
      expect(report['resolver'], '1.1.1.1');
    });
  });
}
