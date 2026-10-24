import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/design_system.dart';
import 'package:fortiva_vpn/core/state/message_state.dart';
import 'package:fortiva_vpn/data/models/connection_info.dart';
import 'package:fortiva_vpn/data/models/in_app_message.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/failure_verdict.dart';
import 'package:fortiva_vpn/widgets/language_picker.dart';
import 'package:fortiva_vpn/widgets/power_button.dart';
import 'package:fortiva_vpn/widgets/ui/signal_bars.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/invite_home.dart';

/// The parts of the home screen whose size is part of its height budget,
/// and the looks the redesign settled: a fixed top bar, the server card
/// with its flag in a disc and the reply time as signal bars, tonal
/// shortcuts, the bell's count, the tonal error bar and the data line in
/// the language's own digits.

/// A tunnel that failed with a diagnosis.
class _Failed extends FakeVpn {
  _Failed() : super(VpnStatus.error);

  @override
  String? get errorMessage => 'Server not working, try another';
  @override
  Map<String, dynamic>? get lastDiagnosis => const {'control': 'ok'};
  @override
  FailureVerdict? get failureVerdict => FailureVerdict.blockedTls;
}

/// A failure that only the phone's VPN settings can fix, so the bar has
/// an action to tap.
class _NeedsSettings extends _Failed {
  @override
  bool get errorNeedsVpnSettings => true;
}

/// A tunnel that can be up and carrying nothing.
class _Stalls extends FakeVpn {
  _Stalls() : super(VpnStatus.disconnected);

  bool dead = false;

  void stall() {
    dead = true;
    notifyListeners();
  }

  @override
  bool get stalled => dead && status == VpnStatus.connected;
}

MessageState _unread(int count) => MessageState(
  fetch: (_, _) async => MessagesPage.fromJson({
    'server_time': DateTime.now().toUtc().toIso8601String(),
    'messages': [
      for (var id = 1; id <= count; id++)
        {
          'id': id,
          'language': 'en',
          'title': 'News $id',
          'body': 'Body $id.',
          'sent_at': DateTime.now()
              .toUtc()
              .subtract(const Duration(minutes: 1))
              .toIso8601String(),
          'ends_at': DateTime.now()
              .toUtc()
              .add(const Duration(days: 7))
              .toIso8601String(),
        },
    ],
  }),
  post: (_, _) async {},
  deviceId: () async => 'DEV-1',
  register: () async {},
  language: () => 'en',
  flushDelay: const Duration(days: 1),
);

/// The shared server with [flag], the globe the app stores for no country.
class _NoCountry extends FakeServers {
  _NoCountry(this.flag);

  final String flag;

  @override
  Server? get selectedServer => Server(
    id: sharedServer.id,
    name: sharedServer.name,
    country: sharedServer.country,
    city: sharedServer.city,
    connectionUri: sharedServer.connectionUri,
    flagEmoji: flag,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockTunnel([]);
  });
  tearDown(unmockTunnel);

  Finder scrollArea() => find
      .ancestor(
        of: find.byType(PowerButton),
        matching: find.byType(SingleChildScrollView),
      )
      .first;

  for (final scale in [1.0, 2.0]) {
    testWidgets('the top bar and the shortcuts keep their height at $scale '
        'text', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpInviteHome(
        tester,
        vpn: FakeVpn(VpnStatus.disconnected),
        config: await inviteConfig(),
      );
      expect(tester.takeException(), isNull);
      // The bar is 56 tall, so nothing in it takes room from the button.
      expect(tester.getRect(scrollArea()).top, 56);
      for (final label in ['Speed test', 'Invite friends']) {
        final shortcut = find
            .ancestor(of: find.text(label), matching: find.byType(InkWell))
            .first;
        expect(tester.getSize(shortcut).height, 52, reason: label);
        // The server card's hairline edge.
        final material = tester.widget<Material>(
          find.ancestor(of: shortcut, matching: find.byType(Material)).first,
        );
        final shape = material.shape! as RoundedRectangleBorder;
        expect(shape.side.color, AppDesign.hairline, reason: label);
      }
      await inviteHomeDone(tester);
    });
  }

  for (final locale in ['en', 'fa']) {
    testWidgets('[$locale] the top bar sits on the card\'s edge, with even '
        'gaps between its buttons', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final messages = _unread(1);
      await messages.refresh();
      await pumpInviteHome(
        tester,
        vpn: FakeVpn(VpnStatus.disconnected),
        messages: messages,
        locale: locale,
      );
      final rtl = locale == 'fa';
      // The last button's box: its glyph keeps a few dp of clear space
      // inside it, which brings the glyph to the server card's 20dp edge.
      final settings = tester.getRect(
        find.ancestor(
          of: find.byIcon(Icons.tune_rounded),
          matching: find.byType(IconButton),
        ),
      );
      expect(rtl ? settings.left : 412 - settings.right, 4);
      // The pill fills its target, so it keeps 8 from the bell's.
      final pill = tester.getRect(find.byType(LanguageButton));
      final bell = tester.getRect(
        find.ancestor(
          of: find.byIcon(Icons.notifications_none_rounded),
          matching: find.byType(IconButton),
        ),
      );
      expect(rtl ? pill.left - bell.right : bell.left - pill.right, 8);
      await inviteHomeDone(tester);
    });
  }

  testWidgets('the shield shows once: the top bar has no mark, since the '
      'power button is the shield', (tester) async {
    await pumpInviteHome(tester, vpn: FakeVpn(VpnStatus.disconnected));
    bool isMark(Widget widget) {
      if (widget is! Image) return false;
      var image = widget.image;
      if (image is ResizeImage) image = image.imageProvider;
      return image is AssetImage &&
          image.assetName == 'assets/icon/fortiva_mark.png';
    }

    expect(find.byWidgetPredicate(isMark), findsNothing);
    expect(find.byType(PowerButton), findsOneWidget);
    await inviteHomeDone(tester);
  });

  testWidgets('the server card: the flag in a disc, the reply time as bars', (
    tester,
  ) async {
    await pumpInviteHome(tester, vpn: FakeVpn(VpnStatus.disconnected));
    final flag = find.text('\u{1F1E9}\u{1F1EA}');
    expect(flag, findsOneWidget);
    final disc = find
        .ancestor(of: flag, matching: find.byType(DecoratedBox))
        .first;
    expect(tester.getSize(disc), const Size.square(40));
    final decoration =
        tester.widget<DecoratedBox>(disc).decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, AppDesign.surfaceHigh);

    // The reply time is its own Text, beside signal bars in its color.
    expect(find.text('42 ms'), findsOneWidget);
    final chip = tester.widget<LatencyChip>(find.byType(LatencyChip));
    expect(chip.ms, 42);
    expect(
      find.descendant(
        of: find.byType(LatencyChip),
        matching: find.byType(SignalBars),
      ),
      findsOneWidget,
    );
    // "City, Country" is still one Text inside the card's tap target.
    expect(
      find.ancestor(
        of: find.text('Falkenstein, Germany'),
        matching: find.byType(InkWell),
      ),
      findsWidgets,
    );
    await inviteHomeDone(tester);
  });

  // The globe a server with no country stores is a full-color picture, so
  // the disc draws the steel globe for it, as History does.
  for (final globe in const ['\u{1F310}', '\u{1F30D}']) {
    testWidgets('a server with no country shows the steel globe '
        '(${globe.runes.first.toRadixString(16)})', (tester) async {
      await pumpInviteHome(
        tester,
        vpn: FakeVpn(VpnStatus.disconnected),
        servers: _NoCountry(globe),
      );
      expect(find.text(globe), findsNothing);
      // The disc's globe, beside the 14dp one in the OUR SERVER heading.
      final icon = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.public_rounded && w.size == 20,
      );
      expect(icon, findsOneWidget);
      expect(tester.widget<Icon>(icon).color, AppDesign.textTertiary);
      final disc = find
          .ancestor(of: icon, matching: find.byType(DecoratedBox))
          .first;
      expect(tester.getSize(disc), const Size.square(40));
      expect(
        (tester.widget<DecoratedBox>(disc).decoration as BoxDecoration).color,
        AppDesign.surfaceHigh,
      );
      await inviteHomeDone(tester);
    });
  }

  Material cardMaterial(WidgetTester tester) => tester.widget<Material>(
    find
        .ancestor(of: find.text('OUR SERVER'), matching: find.byType(Material))
        .first,
  );

  testWidgets('the server card is calm until the tunnel is up through it', (
    tester,
  ) async {
    final vpn = _Stalls();
    await pumpInviteHome(tester, vpn: vpn);
    var shape = cardMaterial(tester).shape! as RoundedRectangleBorder;
    expect(shape.side.color, AppDesign.hairline);
    expect(cardMaterial(tester).color, AppDesign.surfaceLow);

    vpn.become(VpnStatus.connected);
    await tester.pump();
    shape = cardMaterial(tester).shape! as RoundedRectangleBorder;
    expect(shape.side.color, AppDesign.protected.withValues(alpha: 0.35));

    // Up but carrying nothing: the button warns, and the card does not say
    // the tunnel works.
    vpn.stall();
    await tester.pump();
    shape = cardMaterial(tester).shape! as RoundedRectangleBorder;
    expect(shape.side.color, AppDesign.hairline);
    vpn.become(VpnStatus.disconnected);
    await inviteHomeDone(tester);
  });

  testWidgets('the bell counts in a brand pill ringed in the canvas color', (
    tester,
  ) async {
    final messages = _unread(2);
    await messages.refresh();
    await pumpInviteHome(
      tester,
      vpn: FakeVpn(VpnStatus.disconnected),
      messages: messages,
    );
    expect(find.byTooltip('Messages'), findsOneWidget);
    final count = find.text('2');
    expect(count, findsOneWidget);
    final pill = find
        .ancestor(of: count, matching: find.byType(Container))
        .first;
    // 16 tall inside a 2dp ring.
    expect(tester.getSize(pill).height, 20);
    expect(tester.getSize(pill).width, greaterThanOrEqualTo(20));
    final decoration =
        tester.widget<Container>(pill).decoration! as BoxDecoration;
    expect(decoration.color, AppDesign.brand);
    expect(decoration.border, Border.all(color: AppDesign.canvas, width: 2));
    final style = tester.widget<Text>(count).style!;
    expect(style.color, AppDesign.onBrand);
    expect(style.fontSize, 11);
    expect(style.fontWeight, FontWeight.w700);
    await inviteHomeDone(tester);
  });

  testWidgets('the error bar is a tonal card with a 48dp close button', (
    tester,
  ) async {
    await pumpInviteHome(tester, vpn: _Failed());
    final message = find.textContaining('being cut while it is being set up');
    expect(message, findsOneWidget);
    final bar = tester.widget<Container>(
      find.ancestor(of: message, matching: find.byType(Container)).first,
    );
    final decoration = bar.decoration! as BoxDecoration;
    expect(decoration.color, AppDesign.errorContainer);
    expect(decoration.borderRadius, AppDesign.borderRadiusLarge);

    final close = find.widgetWithIcon(IconButton, Icons.close);
    expect(close, findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
    // Details is a text button now, 48 tall.
    final details = find.widgetWithText(TextButton, 'Details');
    expect(details, findsOneWidget);
    expect(tester.getSize(details).height, 48);
    await inviteHomeDone(tester);
  });

  testWidgets('the error bar\'s action is drawn in the tone color', (
    tester,
  ) async {
    await pumpInviteHome(tester, vpn: _NeedsSettings());
    final action = find.widgetWithText(TextButton, 'Open VPN settings');
    expect(action, findsOneWidget);
    expect(tester.getSize(action).height, 48);
    final style = tester.widget<TextButton>(action).style!;
    expect(style.foregroundColor!.resolve({}), AppDesign.error);
    await inviteHomeDone(tester);
  });

  testWidgets('the data line is in Persian digits, each amount kept whole', (
    tester,
  ) async {
    await pumpInviteHome(
      tester,
      vpn: FakeVpn(VpnStatus.disconnected),
      locale: 'fa',
    );
    final line = find.textContaining('امروز مصرف شده');
    expect(line, findsOneWidget);
    final text = tester.widget<Text>(line).data!;
    expect(text, contains('\u2068۱۰ MB\u2069'));
    expect(text, contains('\u2068۱۰۰ MB\u2069'));
    expect(text, isNot(contains(RegExp('[0-9]'))));
    await inviteHomeDone(tester);
  });

  testWidgets('the data line writes the Persian decimal mark', (tester) async {
    await pumpInviteHome(
      tester,
      vpn: FakeVpn(VpnStatus.disconnected),
      dedicated: FakeDedicated(
        QuotaStatus(
          unlimited: false,
          limitBytes: 20 << 30,
          usedBytes: 3 << 29,
          remainingBytes: (20 << 30) - (3 << 29),
          blocked: false,
        ),
      ),
      locale: 'fa',
    );
    final text = tester
        .widget<Text>(find.textContaining('امروز مصرف شده'))
        .data!;
    expect(text, contains('\u2068۱\u066B۵ GB\u2069'));
    expect(text, contains('\u2068۲۰\u066B۰ GB\u2069'));
    expect(text, isNot(contains('.')));
    await inviteHomeDone(tester);
  });
}
