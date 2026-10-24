import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The core's door group is told the backend's penalty for each door, and
/// adds it to the door's score. A Cloudflare door can answer its probes
/// fast and still be left far more often than an IPv6 Reality door, and
/// the core kept choosing such doors.
Server door(String host, String door, {int penaltyMs = 0}) => Server(
  id: 'dedicated-$host-$door',
  name: host,
  country: '',
  city: host,
  connectionUri: 'vless://u@$host:443?type=tcp#$host',
  flagEmoji: '',
  isDedicated: true,
  door: door,
  serverId: 10,
  penaltyMs: penaltyMs,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.vpn.fortivavpn/tunnel');
  late Map<Object?, Object?> sent;
  late VpnService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sent = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'connect') {
            sent = Map.of(call.arguments as Map<Object?, Object?>);
          }
          return call.method == 'getStatus' ? 'disconnected' : null;
        });
    service = VpnService(
      events: VpnEventReporter(send: (_, _, _) async {}),
      diagnostics: _FakeDiagnostics(),
    );
  });

  tearDown(() {
    service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('each door goes with its penalty, in the order of the doors', () async {
    await service.connect(
      door('203.0.113.10', 'xhttp-reality'),
      standby: [
        door('cdn10', 'ws-tls', penaltyMs: 1200),
        door('[2001:db8:f20::10]', 'xhttp-reality-v6'),
      ],
    );

    expect((sent['alternates'] as List).length, 2);
    expect(sent['penalties'], [0, 1200, 0]);
  });

  test('the dialled door\'s own penalty goes first', () async {
    await service.connect(
      door('cdn10', 'ws-tls', penaltyMs: 1200),
      standby: [door('203.0.113.10', 'xhttp-reality')],
    );

    expect(sent['penalties'], [1200, 0]);
  });

  test('doors without a penalty send none', () async {
    await service.connect(
      door('203.0.113.10', 'xhttp-reality'),
      standby: [door('cdn10', 'ws-tls')],
    );

    expect(sent.containsKey('exits'), isTrue);
    expect(sent.containsKey('penalties'), isFalse);
  });

  test('one door sends no penalties, even one it has', () async {
    await service.connect(door('cdn10', 'ws-tls', penaltyMs: 1200));

    expect(sent.containsKey('link'), isTrue);
    expect(sent.containsKey('penalties'), isFalse);
  });
}
