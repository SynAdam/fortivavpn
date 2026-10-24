import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/connection_info.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/widgets/ui/signal_bars.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/invite_home.dart';

/// The server card's heading says whose server this is, which is why the
/// card is there, so it is never cut, in any language, beside a reply time
/// or a timeout. The reply time sits on the heading's line when both fit,
/// which leaves the place under it the whole width, and on the place's
/// line when they do not.

const _ownServer = Server(
  id: 'own-1',
  name: 'Own',
  country: 'Germany',
  city: 'Falkenstein',
  connectionUri: 'vless://u@10.0.0.1:443#own',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
  isDedicated: true,
);

const _communityServer = Server(
  id: '${Server.communityIdPrefix}1',
  name: 'Community 1',
  country: 'Germany',
  city: 'Falkenstein',
  connectionUri: 'vless://u@10.0.0.2:443#c',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
);

/// This device's own server, selected, with [ping] as its reply time.
class _Own extends FakeDedicated {
  _Own(this.ping);

  final int ping;

  @override
  Server? get selectedServer => _ownServer;
  @override
  int? pingFor(String serverId) => ping;
}

/// The shared list with [server] selected and [ping] as its reply time.
class _Servers extends FakeServers {
  _Servers(this.server, this.ping);

  final Server server;
  final int ping;

  @override
  Server? get selectedServer => server;
  @override
  int? getPingResult(String serverId) => ping;
}

const _languages = [
  'ar', 'de', 'en', 'es', 'fa', 'fr', 'hi', 'id', 'ja', //
  'ko', 'pt', 'ru', 'tr', 'uk', 'ur', 'uz', 'vi', 'zh',
];

void main() {
  setUpAll(() => loadShippedFonts(rtl: false));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockTunnel([]);
  });
  tearDown(unmockTunnel);

  /// The paragraph that draws [text] inside the server card.
  RenderParagraph paragraph(WidgetTester tester, String text) =>
      tester.renderObject<RenderParagraph>(
        find.descendant(of: find.text(text), matching: find.byType(RichText)),
      );

  for (final locale in _languages) {
    for (final ping in [42, -1]) {
      final when = ping < 0 ? 'beside a timeout' : 'beside a reply time';
      testWidgets('[$locale] no server heading is cut $when', (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final l10n = lookupS(Locale(locale));
        for (final (heading, dedicated, servers) in [
          (l10n.yourServer, _Own(ping), null),
          (l10n.ourServer, null, _Servers(sharedServer, ping)),
          (l10n.communityServer, null, _Servers(_communityServer, ping)),
        ]) {
          await pumpInviteHome(
            tester,
            vpn: FakeVpn(VpnStatus.disconnected),
            dedicated: dedicated,
            servers: servers,
            locale: locale,
          );
          expect(tester.takeException(), isNull, reason: heading);
          expect(find.byType(LatencyChip), findsOneWidget, reason: heading);
          expect(
            paragraph(tester, heading).didExceedMaxLines,
            isFalse,
            reason: heading,
          );
          await inviteHomeDone(tester);
        }
      });
    }
  }

  Rect rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder);

  testWidgets('a short heading has the reply time beside it, and the place '
      'shows in full', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpInviteHome(tester, vpn: FakeVpn(VpnStatus.disconnected));
    final chip = rectOf(tester, find.byType(LatencyChip));
    final heading = rectOf(tester, find.text('OUR SERVER'));
    expect(chip.center.dy, moreOrLessEquals(heading.center.dy, epsilon: 0.5));
    expect(chip.left, greaterThan(heading.right));
    expect(
      paragraph(tester, 'Falkenstein, Germany').didExceedMaxLines,
      isFalse,
    );
    await inviteHomeDone(tester);
  });

  testWidgets('a heading too long for the reply time beside it keeps its '
      'line, and the reply time moves to the place line', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpInviteHome(
      tester,
      vpn: FakeVpn(VpnStatus.disconnected),
      locale: 'vi',
    );
    final heading = lookupS(const Locale('vi')).ourServer;
    expect(paragraph(tester, heading).didExceedMaxLines, isFalse);
    final chip = rectOf(tester, find.byType(LatencyChip));
    final place = rectOf(tester, find.text('Falkenstein, Germany'));
    expect(chip.center.dy, moreOrLessEquals(place.center.dy, epsilon: 0.5));
    expect(chip.left, greaterThan(place.right));
    await inviteHomeDone(tester);
  });

  testWidgets('in a right to left language the reply time is at the end of '
      'the line, which is the left', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpInviteHome(
      tester,
      vpn: FakeVpn(VpnStatus.disconnected),
      locale: 'fa',
    );
    final chip = rectOf(tester, find.byType(LatencyChip));
    final heading = rectOf(tester, find.text('سرور ما'));
    expect(chip.right, lessThan(heading.left));
    await inviteHomeDone(tester);
  });
}
