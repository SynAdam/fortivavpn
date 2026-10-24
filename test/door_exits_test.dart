import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The core's door group is told which server each door sends traffic out
/// from, so a failover can stay on the server it is on. Failovers used to
/// leave one server's direct door for another server while the first
/// server's own Cloudflare door was in the same group.
Server door(String host, String door, {int? serverId}) => Server(
  id: 'dedicated-$host-$door',
  name: host,
  country: '',
  city: host,
  connectionUri: 'vless://u@$host:443?type=tcp#$host',
  flagEmoji: '🌍',
  isDedicated: true,
  door: door,
  serverId: serverId,
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

  test('each door goes with its server, in the order of the doors', () async {
    await service.connect(
      door('direct10', 'xhttp-reality', serverId: 10),
      standby: [
        door('cdn10', 'ws-tls', serverId: 10),
        door('cdn11', 'ws-tls', serverId: 11),
      ],
    );

    expect((sent['alternates'] as List).length, 2);
    expect(sent['exits'], ['10', '10', '11']);
  });

  test('a copy at another address has its server\'s exit', () async {
    // The "-b" door is the same server at its second IPv4 address. The
    // exit is the server id, not the address, so a failover from the first
    // address to the second keeps the user's traffic leaving from that
    // server.
    await service.connect(
      door('203.0.113.10', 'xhttp-reality', serverId: 10),
      standby: [
        door('203.0.113.20', 'xhttp-reality-b', serverId: 10),
        door('[2001:db8:f20::10]', 'xhttp-reality-v6', serverId: 10),
        door('cdn10', 'ws-tls', serverId: 10),
        door('198.51.100.11', 'xhttp-reality', serverId: 11),
      ],
    );

    expect(sent['exits'], ['10', '10', '10', '10', '11']);
  });

  test('a door not on one of our servers has no exit', () async {
    await service.connect(
      door('direct10', 'xhttp-reality', serverId: 10),
      standby: [door('community', 'ws-tls')],
    );

    expect(sent['exits'], ['10', '']);
  });

  test('one door sends no exits', () async {
    await service.connect(door('direct10', 'xhttp-reality', serverId: 10));

    expect(sent.containsKey('link'), isTrue);
    expect(sent.containsKey('exits'), isFalse);
  });
}
