import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/widgets/server_title.dart';

/// What every screen calls a server. A community link with no country is
/// named by its number in the phone's language and digits, never by the
/// label of whoever posted it or by its host. Names saved earlier, such as
/// the activity list's sessions, are shown the same way.
void main() {
  Future<String> titleIn(
    WidgetTester tester,
    Locale locale,
    String Function(BuildContext) build,
  ) async {
    late String out;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Builder(
          builder: (context) {
            out = build(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return out;
  }

  final flagless = Server.fromConnectionUri(
    'vless://uuid@203.0.113.9:443?security=tls#@someone 1234',
    index: 2,
  );
  final flagged = Server.fromConnectionUri(
    'vless://uuid@203.0.113.9:443#\u{1F1E9}\u{1F1EA} @someone',
    index: 2,
  );
  const ours = Server(
    id: '7',
    name: 'DE-Falkenstein',
    country: 'Germany',
    city: 'Falkenstein',
    connectionUri: 'vless://uuid@h:443',
    flagEmoji: '',
  );

  testWidgets('a flagless link is its number, in English', (tester) async {
    expect(
      await titleIn(
        tester,
        const Locale('en'),
        (c) => serverTitle(c, flagless),
      ),
      'Community server 3',
    );
  });

  testWidgets('and in Persian, with Persian digits', (tester) async {
    expect(
      await titleIn(
        tester,
        const Locale('fa'),
        (c) => serverTitle(c, flagless),
      ),
      'سرور عمومی ۳',
    );
  });

  testWidgets('never the poster or the host', (tester) async {
    final title = await titleIn(
      tester,
      const Locale('en'),
      (c) => serverTitle(c, flagless),
    );
    expect(title, isNot(contains('someone')));
    expect(title, isNot(contains('203.0.113.9')));
  });

  testWidgets('a link with a flag is its country', (tester) async {
    expect(
      await titleIn(tester, const Locale('fa'), (c) => serverTitle(c, flagged)),
      'Germany',
    );
  });

  testWidgets('our servers keep their names', (tester) async {
    expect(
      await titleIn(tester, const Locale('fa'), (c) => serverTitle(c, ours)),
      'DE-Falkenstein',
    );
  });

  testWidgets('a stored fallback name is shown in the phone language', (
    tester,
  ) async {
    expect(
      await titleIn(
        tester,
        const Locale('ar'),
        (c) => storedServerTitle(c, 'Community 12'),
      ),
      'خادم المجتمع ١٢',
    );
  });

  testWidgets('any other stored name is shown as it is', (tester) async {
    for (final name in [
      'Nuremberg',
      'Community',
      'My Community 2',
      'Unknown',
    ]) {
      expect(
        await titleIn(
          tester,
          const Locale('fa'),
          (c) => storedServerTitle(c, name),
        ),
        name,
      );
    }
  });

  test('the fallback name and its parser agree', () {
    expect(Server.communityFallbackName(7), 'Community 7');
    expect(Server.communityNumberOf(Server.communityFallbackName(7)), 7);
    expect(Server.communityNumberOf('Community 7 extra'), isNull);
    expect(
      Server.communityNumberOf('Community 99999999999999999999999'),
      isNull,
    );
    expect(flagless.name, Server.communityFallbackName(3));
  });
}
