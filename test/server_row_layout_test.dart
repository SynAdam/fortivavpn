import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/design_system.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/my_servers_screen.dart';
import 'package:fortiva_vpn/screens/server_list_screen.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/server_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/app_theme.dart';
import 'helpers/invite_home.dart' show FakeVpn;

/// Your servers on a narrow phone, drawn with the fonts the app ships.
///
/// The name of the server in use is the one thing its row has to show. In
/// a Row beside the Persian "In use" pill, the latency and Copy link, a
/// 360dp phone (a common size in Iran) cut "Nuremberg" to "N...". The test
/// font draws every glyph as a full square, so these sizes only mean
/// something with the real Inter and Vazirmatn.
const _nuremberg = Server(
  id: 'dedicated-1',
  name: 'Nuremberg',
  country: 'Germany',
  city: 'Nuremberg',
  connectionUri: 'vless://u@203.0.113.9:443?security=reality#DE',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
  isDedicated: true,
);

const _helsinki = Server(
  id: 'dedicated-2',
  name: 'Helsinki',
  country: 'Finland',
  city: 'Helsinki',
  connectionUri: 'vless://u@203.0.113.10:443?security=reality#FI',
  flagEmoji: '\u{1F1EB}\u{1F1EE}',
  isDedicated: true,
);

class _FakeDedicated extends DedicatedState {
  @override
  List<Server> get servers => const [_nuremberg, _helsinki];

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
  int? pingFor(String serverId) => serverId == _nuremberg.id ? 258 : null;

  @override
  bool isPinging(String serverId) => false;

  @override
  Future<void> pingServer(Server server) async {}
}

class _FakeServers extends ServerState {
  @override
  bool get isLoading => false;

  @override
  Future<void> loadServers({bool forceRefresh = false}) async {}

  @override
  Future<void> pingServer(Server server) async {}
}

/// Inter under "Inter" and Vazirmatn under "Vazirmatn", as the app
/// declares them, so Latin names in a Persian row fall back as they do on
/// a phone.
Future<void> _loadFonts() async {
  for (final family in ['Inter', 'Vazirmatn']) {
    final loader = FontLoader(family);
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      final file = File('assets/fonts/$family/$family-$weight.ttf');
      loader.addFont(
        file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    }
    await loader.load();
  }
}

/// VpnService polls its native side once, 2s after it is made. Clear the
/// tree and let that timer run, so no test ends with it pending.
Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const screen = Size(360, 800);

  Future<void> pumpMyServers(
    WidgetTester tester,
    Locale locale, {
    VpnStatus status = VpnStatus.connected,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(value: _FakeDedicated()),
          ChangeNotifierProvider<ServerState>.value(value: _FakeServers()),
          ChangeNotifierProvider<VpnService>.value(value: FakeVpn(status)),
        ],
        child: MaterialApp(
          locale: locale,
          theme: appThemeFor(locale),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: const MyServersScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  for (final locale in const [Locale('en'), Locale('fa')]) {
    final name = locale.languageCode;

    testWidgets('$name: the name of the server in use is not cut at 360dp', (
      tester,
    ) async {
      await pumpMyServers(tester, locale);

      final title = tester.renderObject<RenderParagraph>(
        find.text('Nuremberg'),
      );
      expect(title.didExceedMaxLines, isFalse);

      // The pill stays whole and inside its row, beside or under the name.
      final row = tester.getRect(
        find.ancestor(
          of: find.text('Nuremberg'),
          matching: find.byType(ServerRow),
        ),
      );
      final pill = tester.getRect(find.byType(InUseBadge));
      expect(pill.left, greaterThanOrEqualTo(row.left));
      expect(pill.right, lessThanOrEqualTo(row.right));
      final label = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(InUseBadge),
          matching: find.byType(RichText),
        ),
      );
      expect(label.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
      await _done(tester);
    });

    testWidgets('$name: Test all ends on the 16dp content line', (
      tester,
    ) async {
      await pumpMyServers(tester, locale);

      final pill = tester.getRect(find.byType(OutlinedButton));
      final card = tester.getRect(find.byType(ServerRow).first);
      if (name == 'fa') {
        expect(pill.left, moreOrLessEquals(16, epsilon: 0.5));
      } else {
        expect(pill.right, moreOrLessEquals(screen.width - 16, epsilon: 0.5));
      }
      expect(card.left, moreOrLessEquals(16, epsilon: 0.5));
      expect(card.right, moreOrLessEquals(screen.width - 16, epsilon: 0.5));
      await _done(tester);
    });

    testWidgets('$name: the Shared servers chevron lines up with Copy link', (
      tester,
    ) async {
      await pumpMyServers(tester, locale);

      final chevron = tester.getCenter(
        find.byIcon(Icons.chevron_right_rounded),
      );
      final copy = tester.getCenter(find.byIcon(Icons.copy_rounded).first);
      expect(chevron.dx, moreOrLessEquals(copy.dx, epsilon: 0.5));
      await _done(tester);
    });
  }

  testWidgets('the community list puts Test all on the same line', (
    tester,
  ) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(value: _FakeDedicated()),
          ChangeNotifierProvider<ServerState>.value(value: _FakeServers()),
          ChangeNotifierProvider<VpnService>.value(
            value: FakeVpn(VpnStatus.disconnected),
          ),
        ],
        child: MaterialApp(
          theme: appThemeFor(const Locale('en')),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: const ServerListScreen(),
        ),
      ),
    );
    await tester.pump();

    final pill = tester.getRect(find.byType(OutlinedButton));
    expect(pill.right, moreOrLessEquals(screen.width - 16, epsilon: 0.5));
    // The explainer and the search field stay put under the bar, so a bar
    // that changed tone as the list scrolls would draw a seam above them.
    expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor, isNull);
    await _done(tester);
  });

  // The list starts right under the bar, so the bar takes the card tone
  // once a row scrolls under it, as on Settings and History.
  testWidgets('Your servers\' app bar follows the list under it', (
    tester,
  ) async {
    await pumpMyServers(tester, const Locale('en'));
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
      same(AppDesign.appBarColor),
    );
    await _done(tester);
  });

  // Mint means protected. With the VPN off the chosen row is still marked,
  // by its edge and its pill, in steel.
  testWidgets('with the VPN off the chosen row is not drawn as protected', (
    tester,
  ) async {
    await pumpMyServers(
      tester,
      const Locale('en'),
      status: VpnStatus.disconnected,
    );

    expect(tester.widget<InUseBadge>(find.byType(InUseBadge)).live, isFalse);
    expect(
      tester.widget<ServerRow>(find.byType(ServerRow).first).live,
      isFalse,
    );
    await _done(tester);
  });
}
