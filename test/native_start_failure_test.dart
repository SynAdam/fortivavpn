import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A failed start says where and why ("failed:core:port_in_use"), and the
/// app files both words with the failure.
///
/// Up to 2.3.0 every failed start but one sent nothing after "failed", so
/// all of them reached the backend as "The tunnel did not start" with no
/// cause: about 1,168 taps through the backup network and 45 taps on our
/// doors in the week to 2026-10-27.

class _Row {
  _Row(this.type, this.error, this.diag);
  final VpnEventType type;
  final String? error;
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
    rows.add(_Row(type, error, diag));
  }
}

class _Diagnostics extends ConnectDiagnostics {
  @override
  Future<Map<String, dynamic>> collect({
    String? host,
    int port = 443,
    String? sni,
  }) async => {'control': 'ok', 'network': 'mobile'};

  @override
  Future<Map<String, dynamic>> platformReport() async => {'network': 'mobile'};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('nativeStartFailure', () {
    Map<String, String> of(String raw) =>
        nativeStartFailure(splitNativeStatus(raw).reason);

    test('reads the step and the reason', () {
      expect(of('failed:core:port_in_use'), {
        'native_step': 'core',
        'native_reason': 'port_in_use',
      });
      expect(of('failed:psiphon:establish_timeout'), {
        'native_step': 'psiphon',
        'native_reason': 'establish_timeout',
      });
      expect(of('failed:tun2socks:fd_not_sent'), {
        'native_step': 'tun2socks',
        'native_reason': 'fd_not_sent',
      });
    });

    test('a bare failure gives nothing', () {
      expect(of('failed'), isEmpty);
      expect(of('failed:'), isEmpty);
      expect(nativeStartFailure(null), isEmpty);
    });

    test('a reason with no step is kept alone', () {
      expect(of('failed:not_prepared'), {'native_reason': 'not_prepared'});
    });

    test('every failed start of the tunnel service says why', () {
      // V2RayVpnService cannot run in a unit test, so this reads its
      // source. Each failure it sends carries a StartFailure message, or
      // VpnSlot.SLOT_TAKEN, never "" as every failure but one did up to
      // 2.3.0.
      final source = File(
        'android/app/src/main/java/com/vpn/fortivavpn/service/'
        'V2RayVpnService.kt',
      ).readAsStringSync();
      final sent = [
        for (final m in RegExp(
          r'MSG_STATE_START_FAILURE,\s*([^)\n]+)',
        ).allMatches(source))
          m.group(1)!.trim(),
      ];
      expect(sent, isNotEmpty);
      for (final content in sent) {
        expect(
          content.startsWith('StartFailure.message(') ||
              content == 'VpnSlot.SLOT_TAKEN',
          isTrue,
          reason: 'a failed start sends "$content"',
        );
      }
    });

    test('anything but short words gives nothing', () {
      // The native side sends fixed words only. Anything else is not
      // passed on, so no text from the phone can ride along.
      expect(of('failed:core:dial tcp 192.0.2.10:443'), isEmpty);
      expect(of('failed:core:192.0.2.10'), isEmpty);
      expect(of('failed:a:b:c'), isEmpty);
      expect(of('failed:core:${'x' * 40}'), isEmpty);
      expect(of('failed:{"why":"timeout"}'), isEmpty);
    });
  });

  group('a failed start', () {
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

    Future<_Row> failure() async {
      await pumpEventQueue();
      return reporter.rows.singleWhere(
        (r) => r.type == VpnEventType.connectFailed,
      );
    }

    test('files the step and the reason beside the diagnosis', () async {
      await service.connect(door, attemptId: 'a' * 32);
      service.applyNativeStatus('failed:core:port_in_use');

      final row = await failure();
      expect(row.diag, containsPair('native_step', 'core'));
      expect(row.diag, containsPair('native_reason', 'port_in_use'));
      expect(row.diag, containsPair('control', 'ok'));
      // The error is the text the user saw, so counts by error do not move.
      expect(row.error, 'The tunnel did not start. Try another location.');
      expect(service.status, VpnStatus.error);
    });

    test('a bare failure is filed as before', () async {
      await service.connect(door, attemptId: 'a' * 32);
      service.applyNativeStatus('failed');

      final row = await failure();
      expect(row.diag, isNot(contains('native_reason')));
      expect(row.diag, isNot(contains('native_step')));
      expect(row.error, 'The tunnel did not start. Try another location.');
    });

    test('a start another app\'s slot stopped is still no failure', () async {
      await service.connect(door, attemptId: 'a' * 32);
      service.applyNativeStatus('failed:$startFailedSlotTaken');
      await pumpEventQueue();

      expect(
        reporter.rows.where((r) => r.type == VpnEventType.connectFailed),
        isEmpty,
      );
      expect(service.lostSlot, isTrue);
    });
  });
}
