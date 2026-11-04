import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/dial_server.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/my_servers_screen.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/invite_home.dart' show FakeVpn;

/// "In use" names what carries the tunnel, as the home card does. After a
/// fallback onto a community link, Your servers marked our Nuremberg server
/// "In use" while the home card said COMMUNITY SERVER (emulator test,
/// 2026-11-04).
const _nuremberg = Server(
  id: 'dedicated-198.51.100.7:443',
  name: 'Nuremberg',
  country: 'Germany',
  city: 'Nuremberg',
  connectionUri: 'vless://u@198.51.100.7:443?security=reality#DE',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
  isDedicated: true,
);

const _link = Server(
  id: '${Server.communityIdPrefix}0',
  name: 'Japan',
  country: 'Japan',
  city: '',
  connectionUri: 'vless://u@203.0.113.10:443?security=tls#jp',
  flagEmoji: '\u{1F1EF}\u{1F1F5}',
);

class _Dedicated extends DedicatedState {
  @override
  List<Server> get servers => const [_nuremberg];
  @override
  bool get hasServers => true;
  @override
  bool get isBlocked => false;
  @override
  bool get isLoading => false;
  @override
  QuotaStatus? get quota => null;
  @override
  Server? get selectedServer => _nuremberg;
  @override
  Future<void> refresh({bool? viaTunnel}) async {}
  @override
  int? pingFor(String serverId) => null;
  @override
  bool isPinging(String serverId) => false;
}

/// The shared lists, with [_link] chosen when [chosen] is true, as the
/// connect fallback leaves it.
class _Servers extends ServerState {
  _Servers({required this.chosen});
  final bool chosen;
  @override
  Server? get selectedServer => _link;
  @override
  bool get isChosen => chosen;
  @override
  bool get isLoading => false;
  @override
  Future<void> loadServers({bool forceRefresh = false}) async {}
}

/// A tunnel the core moved onto [link] by itself, or one through the
/// backup network.
class _Vpn extends FakeVpn {
  _Vpn(super.status, {this.link, this.psiphon = false});
  final Server? link;
  final bool psiphon;
  @override
  Server? get communityDoorInUse => link;
  @override
  bool get onPsiphon => psiphon;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('serverInUse', () {
    test('our server, when nothing else carries the tunnel', () {
      final vpn = _Vpn(VpnStatus.connected);
      expect(
        serverInUse(vpn, _Dedicated(), _Servers(chosen: false))?.id,
        _nuremberg.id,
      );
      vpn.dispose();
    });

    test('the community link the fallback chose, connected or not', () {
      for (final status in [VpnStatus.connected, VpnStatus.disconnected]) {
        final vpn = _Vpn(status);
        expect(
          serverInUse(vpn, _Dedicated(), _Servers(chosen: true))?.id,
          _link.id,
          reason: '$status',
        );
        vpn.dispose();
      }
    });

    test('the community link the core moved to by itself', () {
      final vpn = _Vpn(VpnStatus.connected, link: _link);
      expect(
        serverInUse(vpn, _Dedicated(), _Servers(chosen: false))?.id,
        _link.id,
      );
      vpn.dispose();
    });

    test('none of either list through the backup network', () {
      final vpn = _Vpn(VpnStatus.connected, psiphon: true);
      expect(serverInUse(vpn, _Dedicated(), _Servers(chosen: false)), isNull);
      vpn.dispose();
    });
  });

  group('Your servers', () {
    Future<void> pump(WidgetTester tester, VpnService vpn, ServerState s) =>
        tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<DedicatedState>.value(value: _Dedicated()),
              ChangeNotifierProvider<ServerState>.value(value: s),
              ChangeNotifierProvider<VpnService>.value(value: vpn),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: S.localizationsDelegates,
              supportedLocales: S.supportedLocales,
              home: const MyServersScreen(),
            ),
          ),
        );

    /// VpnService polls its native side once, 2s after it is made.
    Future<void> done(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    }

    testWidgets('marks our server while it carries the tunnel', (tester) async {
      await pump(tester, _Vpn(VpnStatus.connected), _Servers(chosen: false));
      await tester.pump();
      expect(find.text('In use'), findsOneWidget);
      await done(tester);
    });

    testWidgets('marks nothing while a community link carries it', (
      tester,
    ) async {
      await pump(tester, _Vpn(VpnStatus.connected), _Servers(chosen: true));
      await tester.pump();
      expect(find.text('Nuremberg'), findsOneWidget);
      expect(find.text('In use'), findsNothing);
      await done(tester);
    });

    testWidgets('and nothing after it, while the next tap dials the link', (
      tester,
    ) async {
      await pump(tester, _Vpn(VpnStatus.disconnected), _Servers(chosen: true));
      await tester.pump();
      expect(find.text('In use'), findsNothing);
      await done(tester);
    });

    testWidgets('and nothing through the backup network', (tester) async {
      await pump(
        tester,
        _Vpn(VpnStatus.connected, psiphon: true),
        _Servers(chosen: false),
      );
      await tester.pump();
      expect(find.text('In use'), findsNothing);
      await done(tester);
    });
  });
}
