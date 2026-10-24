import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/services/notice_channel.dart';
import 'package:fortiva_vpn/widgets/notices_switch.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The card on the Messages screen that offers to turn notifications on
/// (lib/widgets/notices_switch.dart).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: Column(children: [child])),
      ),
    );
    await tester.pumpAndSettle();
  }

  const offText =
      'Turn on notifications to get messages from the Fortiva team even '
      'when the app is closed.';

  testWidgets('shown while they are off; Turn on turns them on and the card '
      'goes', (tester) async {
    var state = NoticePermission.ask;
    var taps = 0;
    await pump(
      tester,
      NoticesOffCard(
        shown: () => true,
        read: () async => state,
        turnOn: () async {
          taps++;
          state = NoticePermission.granted;
          return state;
        },
      ),
    );
    expect(find.text(offText), findsOneWidget);

    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.text(offText), findsNothing);
  });

  testWidgets('nothing while they are on', (tester) async {
    await pump(
      tester,
      NoticesOffCard(
        shown: () => true,
        read: () async => NoticePermission.granted,
      ),
    );
    expect(find.text(offText), findsNothing);
  });

  testWidgets('nothing where the app does not post notifications', (
    tester,
  ) async {
    await pump(
      tester,
      NoticesOffCard(
        shown: () => false,
        read: () async => NoticePermission.ask,
      ),
    );
    expect(find.text(offText), findsNothing);
  });

  testWidgets('read again when the app comes back from the system page', (
    tester,
  ) async {
    var state = NoticePermission.denied;
    await pump(
      tester,
      NoticesOffCard(shown: () => true, read: () async => state),
    );
    expect(find.text(offText), findsOneWidget);

    state = NoticePermission.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text(offText), findsNothing);
  });

  testWidgets('Not now keeps it away for a week; the Settings row stays', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 13, 12);
    Widget card() => NoticesOffCard(
      shown: () => true,
      read: () async => NoticePermission.denied,
      now: () => now,
    );
    await pump(tester, card());
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text(offText), findsNothing);

    now = now.add(const Duration(days: 6));
    await pump(tester, const SizedBox());
    await pump(tester, card());
    expect(find.text(offText), findsNothing);

    now = now.add(const Duration(days: 2));
    await pump(tester, const SizedBox());
    await pump(tester, card());
    expect(find.text(offText), findsOneWidget);
  });
}
