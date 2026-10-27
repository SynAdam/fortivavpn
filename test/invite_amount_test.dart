import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/referral_service.dart';
import 'package:fortiva_vpn/core/state/referral_state.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/invite_screen.dart';
import 'package:provider/provider.dart';

/// The "How it works" card on the invite screen names what one friend
/// earns. A no-break space (\u00A0 below) joins each amount to its unit,
/// so a line never ends between them. The number comes from the backend only, because a number
/// written into the app stays wrong on every phone until the next release
/// reaches it. The app used to say 250 MB here.
ReferralStatus _status({int? perReferral, int? maxBonus, int bonusBytes = 0}) =>
    ReferralStatus(
      code: 'AB3D7K',
      shareUrl: 'https://fortivavpn.com/i/AB3D7K',
      invitedCount: 0,
      confirmedCount: 0,
      bonusBytes: bonusBytes,
      bonusPerReferralBytes: perReferral,
      maxBonusBytes: maxBonus,
    );

class _FakeReferral extends ReferralState {
  final ReferralStatus _fixed;
  _FakeReferral(this._fixed);

  @override
  ReferralStatus? get status => _fixed;

  @override
  bool get isLoading => false;

  @override
  Future<void> refresh() async {}
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    ReferralStatus status, {
    String locale = 'en',
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ReferralState>.value(
        value: _FakeReferral(status),
        child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: Locale(locale),
          home: const InviteScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the card shows the amount the backend sends', (tester) async {
    await pump(tester, _status(perReferral: 1 << 30));

    expect(
      find.text(
        'Share your code. When someone installs the app, enters it, and '
        'uses the VPN for a while, you get 1\u00A0GB added to your daily data. '
        'It stays on your account.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('an amount under 1 GB reads in MB', (tester) async {
    await pump(tester, _status(perReferral: 500 << 20));

    expect(find.textContaining('you get 500\u00A0MB added'), findsOneWidget);
  });

  testWidgets('without an amount from the backend, none is named', (
    tester,
  ) async {
    await pump(tester, _status());

    expect(
      find.text(
        'Share your code. When someone installs the app, enters it, and '
        'uses the VPN for a while, you get more data every day. It stays '
        'on your account.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining(RegExp(r'250\sMB')), findsNothing);
    expect(find.textContaining('added to your daily data'), findsNothing);
  });

  testWidgets('reads in Persian with Persian digits', (tester) async {
    await pump(tester, _status(perReferral: 1 << 30), locale: 'fa');

    expect(
      find.textContaining('۱\u00A0GB به دیتای روزانه شما'),
      findsOneWidget,
    );
  });

  testWidgets('Persian without an amount names none', (tester) async {
    await pump(tester, _status(), locale: 'fa');

    expect(
      find.textContaining('دیتای روزانه شما بیشتر می‌شود'),
      findsOneWidget,
    );
    expect(find.textContaining('GB'), findsNothing);
  });

  testWidgets('the card names the daily limit the backend sends', (
    tester,
  ) async {
    await pump(tester, _status(perReferral: 1 << 30, maxBonus: 10 << 30));

    expect(
      find.text('You can earn up to 10\u00A0GB a day from invites.'),
      findsOneWidget,
    );
  });

  testWidgets('without a limit from the backend, none is named', (
    tester,
  ) async {
    await pump(tester, _status(perReferral: 1 << 30));

    expect(find.textContaining('up to'), findsNothing);
  });

  testWidgets('the limit reads in Persian with Persian digits', (tester) async {
    await pump(
      tester,
      _status(perReferral: 1 << 30, maxBonus: 10 << 30),
      locale: 'fa',
    );

    expect(
      find.text('از دعوت دوستان حداکثر ۱۰\u00A0GB در روز می‌گیرید.'),
      findsOneWidget,
    );
  });

  testWidgets('the earned bonus reads as a whole number', (tester) async {
    await pump(tester, _status(perReferral: 1 << 30, bonusBytes: 2 << 30));

    expect(find.text('+2\u00A0GB a day'), findsOneWidget);
    expect(find.textContaining(RegExp(r'2\.0\sGB')), findsNothing);
  });

  testWidgets('the earned bonus reads in Persian with Persian digits', (
    tester,
  ) async {
    await pump(
      tester,
      _status(perReferral: 1 << 30, bonusBytes: 2 << 30),
      locale: 'fa',
    );

    expect(find.text('+۲\u00A0GB در روز'), findsOneWidget);
  });

  // An amount with a fraction writes its decimal sign as the quota card
  // does: the momayyez between Persian digits.
  testWidgets('a fraction of a GB writes the Persian decimal mark', (
    tester,
  ) async {
    await pump(
      tester,
      _status(perReferral: 3 << 29, bonusBytes: 3 << 29),
      locale: 'fa',
    );

    expect(find.text('+۱\u066B۵\u00A0GB در روز'), findsOneWidget);
    expect(
      find.textContaining('۱\u066B۵\u00A0GB به دیتای روزانه شما'),
      findsOneWidget,
    );
    expect(find.textContaining('۱.۵'), findsNothing);
  });

  testWidgets('a fraction of a GB keeps its point in English', (tester) async {
    await pump(tester, _status(perReferral: 3 << 29, bonusBytes: 3 << 29));

    expect(find.text('+1.5\u00A0GB a day'), findsOneWidget);
    expect(find.textContaining('you get 1.5\u00A0GB added'), findsOneWidget);
  });

  testWidgets('Korean puts no particle right after the amount', (tester) async {
    await pump(tester, _status(perReferral: 1 << 30), locale: 'ko');

    expect(find.textContaining('하루 데이터가 1\u00A0GB 늘어나고'), findsOneWidget);
    expect(find.textContaining('GB이'), findsNothing);
  });
}
