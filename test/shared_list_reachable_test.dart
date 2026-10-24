import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/my_servers_screen.dart';
import 'package:fortiva_vpn/screens/server_list_screen.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The shared lists are reachable only through this screen.
///
/// The home card opens the device's own servers as soon as provisioning
/// has landed, and the Settings entry for the shared list was dropped, so
/// a link here is the last remaining way in. Losing it strands every
/// install that has dedicated servers on those servers alone, with no way
/// to reach the community list when they are blocked, which is the one
/// moment the fallback matters. These tests pin the door open.
const _dedicated = Server(
  id: 'dedicated-1',
  name: 'Falkenstein',
  country: 'Germany',
  city: 'Falkenstein',
  connectionUri: 'vless://u@198.51.100.201:443?security=reality#DE',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
  isDedicated: true,
);

class _FakeDedicated extends DedicatedState {
  final List<Server> _fixed;
  final bool _blocked;

  _FakeDedicated({List<Server> servers = const [], bool blocked = false})
    : _fixed = servers,
      _blocked = blocked;

  @override
  List<Server> get servers => _fixed;

  @override
  bool get hasServers => _fixed.isNotEmpty;

  @override
  bool get isBlocked => _blocked;

  @override
  bool get isLoading => false;

  @override
  QuotaStatus? get quota => null;

  @override
  Server? get selectedServer => _fixed.isEmpty ? null : _fixed.first;

  @override
  Future<void> refresh({bool? viaTunnel}) async {}

  @override
  int? pingFor(String serverId) => null;

  @override
  bool isPinging(String serverId) => false;

  @override
  Future<void> pingServer(Server server) async {}
}

/// An empty shared list is enough: the assertion is that the screen opens,
/// not what it holds.
class _FakeServers extends ServerState {
  @override
  bool get isLoading => false;

  @override
  Future<void> loadServers({bool forceRefresh = false}) async {}

  @override
  Future<void> pingServer(Server server) async {}
}

/// The screens read whether the tunnel is up, which makes the lazy
/// VpnService, and VpnService checks its native side once, 2s after it is
/// made. Clear the tree and let that run, so no test ends with the timer
/// pending.
Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpMyServers(
    WidgetTester tester,
    _FakeDedicated dedicated,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(value: dedicated),
          ChangeNotifierProvider<ServerState>.value(value: _FakeServers()),
          ChangeNotifierProvider<VpnService>(create: (_) => VpnService()),
        ],
        child: const MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: Locale('en'),
          home: MyServersScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  group('the way to the shared lists', () {
    testWidgets('is offered beside the device\'s own servers', (tester) async {
      await pumpMyServers(tester, _FakeDedicated(servers: const [_dedicated]));

      expect(find.text('Shared servers'), findsOneWidget);
      await _done(tester);
    });

    testWidgets('opens the community list, and only that', (tester) async {
      await pumpMyServers(tester, _FakeDedicated(servers: const [_dedicated]));

      await tester.tap(find.text('Shared servers'));
      await tester.pumpAndSettle();

      expect(find.byType(ServerListScreen), findsOneWidget);
      expect(find.text('Community'), findsOneWidget);
      await _done(tester);
    });

    // The screen behind this row used to carry an "Our servers" tab of
    // shared Fortiva links beside the community one. Reaching it from the
    // device's own list meant being shown a second, worse copy of the
    // servers just left behind, so that tab is gone. A regression would
    // put the duplicate back one tap from the original.
    testWidgets('does not show our servers a second time', (tester) async {
      await pumpMyServers(tester, _FakeDedicated(servers: const [_dedicated]));

      await tester.tap(find.text('Shared servers'));
      await tester.pumpAndSettle();

      expect(find.text('Our servers'), findsNothing);
      expect(find.byType(TabBar), findsNothing);
      await _done(tester);
    });

    testWidgets('survives a spent allowance, when it matters most', (
      tester,
    ) async {
      await pumpMyServers(tester, _FakeDedicated(blocked: true));

      expect(find.text('Shared servers'), findsOneWidget);
      await _done(tester);
    });

    testWidgets('survives provisioning having returned nothing', (
      tester,
    ) async {
      await pumpMyServers(tester, _FakeDedicated());

      expect(find.text('Shared servers'), findsOneWidget);
      await _done(tester);
    });
  });
}
