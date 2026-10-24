import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// VpnService.trafficMisses: how many passes of the traffic check have
/// failed on the tunnel being checked now.
///
/// The connect flow leaves a dial of the remembered door for a door found
/// open beside it only while the tunnel has not come up, or once a pass
/// through it has failed. A working door usually passes on the first pass.
const _door = Server(
  id: 'dedicated-edge-a.example:443',
  name: 'edge-a',
  country: '',
  city: 'edge-a',
  connectionUri: 'vless://u@edge-a.example:443?type=tcp#edge-a',
  flagEmoji: '',
  isDedicated: true,
  door: 'xhttp-reality',
);

class _Quiet extends VpnEventReporter {
  _Quiet() : super(send: (_, _, _) async {});

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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => call.method == 'getStatus' ? 'disconnected' : null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// A service whose passes of the traffic check go as [passes] says, in
  /// order, and fail once it runs out.
  VpnService service(List<bool> passes) => VpnService(
    events: _Quiet(),
    diagnostics: _FakeDiagnostics(),
    trafficCheck: () async => passes.isEmpty ? false : passes.removeAt(0),
  );

  /// Dial [_door] and let the platform say the tunnel is up.
  void up(VpnService vpn, FakeAsync async) {
    unawaited(vpn.connect(_door));
    async.elapse(const Duration(milliseconds: 1));
    vpn.applyNativeStatus('connected');
  }

  test('counts each failed pass, and says none once the check passed', () {
    fakeAsync((async) {
      final vpn = service([false, false, true]);
      var heard = 0;
      vpn.addListener(() => heard++);
      up(vpn, async);
      expect(vpn.isVerifying, isTrue);
      expect(vpn.trafficMisses, 0);

      // The first pass runs after the 2 s settle, the next ones 1.5 s
      // apart.
      async.elapse(const Duration(milliseconds: 2050));
      expect(vpn.trafficMisses, 1);
      // Each failed pass is a change the flow hears of.
      final afterFirst = heard;
      async.elapse(const Duration(milliseconds: 1500));
      expect(vpn.trafficMisses, 2);
      expect(heard, greaterThan(afterFirst));

      async.elapse(const Duration(seconds: 2));
      expect(vpn.isVerifying, isFalse);
      expect(vpn.trafficMisses, 0);
      vpn.dispose();
    });
  });

  test('a new attempt starts from none', () {
    fakeAsync((async) {
      final vpn = service([false]);
      up(vpn, async);
      async.elapse(const Duration(milliseconds: 2050));
      expect(vpn.trafficMisses, 1);

      unawaited(vpn.disconnect());
      async.elapse(const Duration(milliseconds: 1));
      vpn.applyNativeStatus('disconnected');
      expect(vpn.trafficMisses, 0);

      up(vpn, async);
      expect(vpn.isVerifying, isTrue);
      expect(vpn.trafficMisses, 0);
      unawaited(vpn.disconnect());
      async.elapse(const Duration(seconds: 30));
      vpn.dispose();
    });
  });
}
