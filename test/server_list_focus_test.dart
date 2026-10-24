import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/server_list_screen.dart';
import 'package:provider/provider.dart';

import 'helpers/app_theme.dart';

/// A TV remote's focus stays on its server while Test all re-sorts the
/// community list.
///
/// Results arrive one by one during a run, and each one can move rows.
/// The rows are keyed by server, so a row that moves must keep its element,
/// and with it the focus. A row rebuilt in its new place dropped the focus,
/// which jumped back to another control on every result.
void main() {
  Server community(int n, String country) => Server(
    id: '${Server.communityIdPrefix}$n',
    name: country,
    country: country,
    city: '',
    connectionUri: 'vless://u$n@203.0.113.$n:443?security=reality#$country',
    flagEmoji: '',
  );

  final austria = community(0, 'Austria');
  final belgium = community(1, 'Belgium');
  final canada = community(2, 'Canada');

  Future<_Servers> pump(WidgetTester tester) async {
    final servers = _Servers([austria, belgium, canada]);
    await tester.pumpWidget(
      ChangeNotifierProvider<ServerState>.value(
        value: servers,
        child: MaterialApp(
          theme: appThemeFor(null),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: const Locale('en'),
          home: const ServerListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return servers;
  }

  /// The focus node of the row that names [title].
  FocusNode rowFocus(WidgetTester tester, String title) =>
      Focus.of(tester.element(find.text(title)));

  testWidgets('a focused row keeps focus when a result moves it down', (
    tester,
  ) async {
    final servers = await pump(tester);
    final node = rowFocus(tester, 'Belgium')..requestFocus();
    await tester.pump();
    expect(node.hasPrimaryFocus, isTrue);

    // Canada becomes the fastest and leads the list, Austria is tested,
    // and the untested Belgium moves from the second row to the third.
    servers.report({austria.id: 300, canada.id: 100});
    await tester.pump();

    expect(FocusManager.instance.primaryFocus, same(node));
    expect(rowFocus(tester, 'Belgium'), same(node));
  });

  testWidgets('a focused row keeps focus when it becomes the fastest', (
    tester,
  ) async {
    final servers = await pump(tester);
    servers.report({austria.id: 300, canada.id: 100});
    await tester.pump();
    final node = rowFocus(tester, 'Belgium')..requestFocus();
    await tester.pump();

    servers.report({belgium.id: 20});
    await tester.pump();

    expect(find.text('Fastest'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Belgium')).dy,
      lessThan(tester.getTopLeft(find.text('Canada')).dy),
      reason: 'Belgium leads the list now',
    );
    expect(FocusManager.instance.primaryFocus, same(node));
    expect(rowFocus(tester, 'Belgium'), same(node));
  });

  testWidgets('focus on the fastest row stays with its server when another '
      'server overtakes it', (tester) async {
    final servers = await pump(tester);
    servers.report({canada.id: 100});
    await tester.pump();
    final node = rowFocus(tester, 'Canada')..requestFocus();
    await tester.pump();

    servers.report({austria.id: 40});
    await tester.pump();

    expect(FocusManager.instance.primaryFocus, same(node));
    expect(rowFocus(tester, 'Canada'), same(node));
  });
}

/// The community list with results the test hands it.
class _Servers extends ServerState {
  _Servers(this.list);

  final List<Server> list;
  final _pings = <String, int>{};

  void report(Map<String, int> results) {
    _pings.addAll(results);
    notifyListeners();
  }

  @override
  List<Server> get communityServers => list;

  @override
  bool get isLoading => false;

  @override
  bool get isLoadingCommunity => false;

  @override
  bool get communityLoadFailed => false;

  @override
  Future<void> loadServers({bool forceRefresh = false}) async {}

  @override
  Future<void> refreshServers() async {}

  @override
  int? getPingResult(String serverId) => _pings[serverId];
}
