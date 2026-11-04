import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/dial_server.dart';
import 'package:fortiva_vpn/data/models/connection_data.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/invite_home.dart';
import 'helpers/limit_sheet.dart';

/// A tunnel that holds our doors behind a community link can move from one
/// of ours back to the link while the app is closed. The selection then
/// still names our door, and the reopened app must name the link, never
/// "YOUR SERVER" (VpnService.communityDoorInUse).
const community = Server(
  id: '${Server.communityIdPrefix}0',
  name: 'Community 1',
  country: '',
  city: '',
  connectionUri: 'vless://u@203.0.113.10:443?type=tcp&security=tls#c',
  flagEmoji: '',
);

const own = Server(
  id: 'dedicated-198.51.100.7:443',
  name: 'own',
  country: 'Germany',
  city: 'Falkenstein',
  connectionUri: 'vless://u@198.51.100.7:443?type=tcp#own',
  flagEmoji: '',
  isDedicated: true,
  door: 'xhttp-reality',
  doorLabel: 'xhttp-reality',
  serverId: 7,
);

class _Reporter extends VpnEventReporter {
  _Reporter() : super(send: (_, _, _) async {});
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

class _Diag extends ConnectDiagnostics {
  @override
  Future<Map<String, dynamic>> collect({
    String? host,
    int port = 443,
    String? sni,
  }) async => const {};
  @override
  Future<Map<String, dynamic>> platformReport() async => const {};
}

/// A reopened app's tunnel, as the home screen reads it.
class _ReopenedVpn extends FakeVpn {
  _ReopenedVpn(this.link) : super(VpnStatus.connected);
  final Server? link;
  @override
  Server? get communityDoorInUse => link;
}

/// After the move back the selection is our door.
class _OwnSelected extends FakeDedicated {
  @override
  Server? get selectedServer => own;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.vpn.fortivavpn/tunnel');
  late List<Map<String, Object?>> replies;
  final timers = <Timer>[];
  final made = <VpnService>[];

  VpnService newService() {
    final s = runZoned(
      () => VpnService(events: _Reporter(), diagnostics: _Diag()),
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          final t = parent.createTimer(zone, duration, callback);
          timers.add(t);
          return t;
        },
      ),
    );
    made.add(s);
    return s;
  }

  group('a reopened app knows the community link the core is on', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      replies = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'tunnelStats':
                if (replies.isEmpty) return null;
                return replies.length > 1 ? replies.removeAt(0) : replies.first;
              case 'getStatus':
                return 'disconnected';
              default:
                return null;
            }
          });
    });

    tearDown(() {
      for (final s in made) {
        s.dispose();
      }
      made.clear();
      for (final t in timers) {
        t.cancel();
      }
      timers.clear();
      ConnectionData.current = ConnectionData.off;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    /// The fallback dials [community] with [own] behind it, and the core
    /// moves back to [own] while the app is on screen.
    Future<void> movedBack() async {
      final first = newService();
      await first.connect(
        community,
        standby: [own],
        attemptId: 'a' * 32,
        source: LinkSource.communityFallback,
      );
      first.applyNativeStatus('connected');
      first.debugVerifying = false;
      expect(first.communityDoorInUse?.id, community.id);
      final t0 = DateTime.utc(2026, 11, 4, 8).millisecondsSinceEpoch;
      first.followDoor({
        'door_index': 1,
        'door_status': jsonEncode({
          'state': 'ok',
          'switches': [
            {'from': 0, 'to': 1, 'reason': 'recovered', 'at': t0},
          ],
          'doors': [],
        }),
      });
      await pumpEventQueue();
      expect(first.activeDoor?.pathKey, own.pathKey);
      expect(first.communityDoorInUse, isNull);
      final prefs = await SharedPreferences.getInstance();
      final saved =
          jsonDecode(prefs.getString(VpnService.attemptKey)!)
              as Map<String, dynamic>;
      expect(saved['community_doors'], [
        {'at': 0, 'id': community.id, 'uri': community.connectionUri},
      ]);
    }

    test('back on the link, the reopened app names it', () async {
      await movedBack();
      // Our door failed while the app was closed: the core is on the link.
      replies.add({'bytes_up': 1, 'bytes_down': 1, 'door_index': 0});
      final reopened = newService();
      var heard = 0;
      reopened.addListener(() => heard++);
      reopened.applyNativeStatus('connected');
      await pumpEventQueue();
      expect(reopened.activeDoor, isNull);
      final link = reopened.communityDoorInUse;
      expect(link?.isCommunity, isTrue);
      expect(link?.id, community.id);
      expect(link?.connectionUri, community.connectionUri);
      expect(heard, greaterThan(0));
    });

    test('still on our door, the reopened app names no link', () async {
      await movedBack();
      replies.add({'bytes_up': 1, 'bytes_down': 1, 'door_index': 1});
      final reopened = newService();
      reopened.applyNativeStatus('connected');
      await pumpEventQueue();
      expect(reopened.communityDoorInUse, isNull);
    });
  });

  group('the home screen of the reopened app', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockTunnel([]);
    });
    tearDown(unmockTunnel);

    testWidgets('names the community link the tunnel is on, not our server', (
      tester,
    ) async {
      screenFor(tester);
      final dedicated = _OwnSelected();
      final servers = FakeServers();
      expect(activeServer(dedicated, servers)?.id, own.id);
      await pumpInviteHome(
        tester,
        vpn: _ReopenedVpn(community),
        dedicated: dedicated,
        servers: servers,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('COMMUNITY SERVER'), findsOneWidget);
      expect(
        find.text('A public server shared by others. Fortiva does not run it.'),
        findsOneWidget,
      );
      expect(find.text('Connected through a community server'), findsOneWidget);
      expect(find.text('YOUR SERVER'), findsNothing);
      expect(
        find.text('Yours alone. No one else connects through it.'),
        findsNothing,
      );
      await inviteHomeDone(tester);
    });

    testWidgets('on our door it still says YOUR SERVER', (tester) async {
      screenFor(tester);
      await pumpInviteHome(
        tester,
        vpn: _ReopenedVpn(null),
        dedicated: _OwnSelected(),
        servers: FakeServers(),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('YOUR SERVER'), findsOneWidget);
      expect(find.text('COMMUNITY SERVER'), findsNothing);
      expect(find.text('Connected through a community server'), findsNothing);
      await inviteHomeDone(tester);
    });
  });
}
