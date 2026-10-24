import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/design_system.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/widgets/server_card.dart';
import 'package:fortiva_vpn/widgets/ui/signal_bars.dart';

import 'helpers/app_theme.dart';

/// The one row style both server lists use (ServerRow), and the controls
/// on it.
///
/// Your servers and the community list drew their rows two ways. These pin
/// the shared look where it carries meaning: the 72dp row, the edge and the
/// "In use" pill on the chosen row (protected only while the tunnel is up),
/// the 48dp Ping target that measures and never picks, the latency bars in
/// the shared colors, and a Test all control that a TV remote can keep
/// focus on during a run.
void main() {
  final community = Server(
    id: '${Server.communityIdPrefix}1',
    name: 'Germany',
    country: 'Germany',
    city: '',
    connectionUri:
        'vless://u@203.0.113.9:443?security=reality&type=tcp#Germany',
    flagEmoji: '\u{1F1E9}\u{1F1EA}',
  );

  Future<void> pump(WidgetTester tester, Widget child, {Locale? locale}) async {
    final shown = locale ?? const Locale('en');
    await tester.pumpWidget(
      MaterialApp(
        locale: shown,
        theme: appThemeFor(shown),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ShapeBorder? rowShape(WidgetTester tester) {
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(ServerRow),
            matching: find.byType(Material),
          )
          .first,
    );
    return material.shape;
  }

  testWidgets('a row is at least 72dp tall and keeps its subtitle text', (
    tester,
  ) async {
    await pump(
      tester,
      ServerCard(server: community, isSelected: false, onTap: () {}),
    );

    expect(
      tester.getSize(find.byType(ServerRow)).height,
      greaterThanOrEqualTo(ServerRow.minHeight),
    );
    expect(find.text('Germany'), findsOneWidget);
    expect(find.text('REALITY · 443'), findsOneWidget);
    expect(find.text('203.0.113.9'), findsNothing);
  });

  testWidgets('the chosen row has a protected edge and says In use', (
    tester,
  ) async {
    await pump(
      tester,
      ServerCard(server: community, isSelected: true, onTap: () {}),
    );

    final shape = rowShape(tester)! as RoundedRectangleBorder;
    expect(shape.side.color, AppDesign.protected);
    expect(shape.side.width, 1.5);
    // The same mark as on Your servers, beside the name, not a trailing
    // check that meant the same thing in another way.
    expect(find.text('In use'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('In use')).style?.color,
      AppDesign.protected,
    );
    expect(
      tester.getTopLeft(find.text('In use')).dx,
      greaterThan(tester.getTopRight(find.text('Germany')).dx),
    );
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });

  testWidgets('a row that is not chosen has no edge', (tester) async {
    await pump(
      tester,
      ServerCard(server: community, isSelected: false, onTap: () {}),
    );

    final shape = rowShape(tester)! as RoundedRectangleBorder;
    expect(shape.side, BorderSide.none);
    expect(find.text('In use'), findsNothing);
  });

  // Protected green means the tunnel is up, on home and here. With the VPN
  // off the chosen row still shows, by its edge and its pill, in steel.
  testWidgets('with the tunnel down the chosen row is steel, not protected', (
    tester,
  ) async {
    await pump(
      tester,
      ServerCard(
        server: community,
        isSelected: true,
        live: false,
        onTap: () {},
      ),
    );

    final shape = rowShape(tester)! as RoundedRectangleBorder;
    expect(shape.side.color, AppDesign.steelLight);
    expect(shape.side.width, 1.5);
    final pill = find.text('In use');
    expect(pill, findsOneWidget);
    expect(tester.widget<Text>(pill).style?.color, AppDesign.textSecondary);
    final fill = tester.widget<Container>(
      find.ancestor(of: pill, matching: find.byType(Container)).first,
    );
    expect((fill.decoration! as BoxDecoration).color, AppDesign.surfaceHighest);
  });

  testWidgets('a chosen Premium row keeps its Premium tag', (tester) async {
    await pump(
      tester,
      ServerCard(
        server: community.copyWith(isPremium: true),
        isSelected: true,
        onTap: () {},
      ),
    );

    expect(find.text('In use'), findsOneWidget);
    expect(find.text('PREMIUM'), findsOneWidget);
  });

  // Vazirmatn at labelSmall (11.5sp) drew the Persian pill 11dp tall, under
  // the 12.5sp floor for secondary text in Persian.
  testWidgets('the pills meet the Persian size floor', (tester) async {
    await pump(
      tester,
      ServerCard(
        server: community.copyWith(isPremium: true),
        isSelected: true,
        onTap: () {},
      ),
      locale: const Locale('fa'),
    );

    for (final pill in [
      find.descendant(of: find.byType(InUseBadge), matching: find.byType(Text)),
      find.text(lookupS(const Locale('fa')).proBadge),
    ]) {
      expect(pill, findsOneWidget);
      expect(
        tester.widget<Text>(pill).style!.fontSize,
        greaterThanOrEqualTo(12.5),
      );
    }
  });

  testWidgets('Ping has its own 48dp target and measures without picking', (
    tester,
  ) async {
    var picks = 0;
    var pings = 0;
    await pump(
      tester,
      ServerCard(
        server: community,
        isSelected: false,
        onTap: () => picks++,
        onPing: () => pings++,
      ),
    );

    final target = tester.getSize(
      find
          .ancestor(of: find.text('Ping'), matching: find.byType(InkWell))
          .first,
    );
    expect(target.width, greaterThanOrEqualTo(48));
    expect(target.height, greaterThanOrEqualTo(48));

    await tester.tap(find.text('Ping'));
    await tester.pump();
    expect(pings, 1);
    expect(picks, 0);

    await tester.tap(find.text('Germany'));
    await tester.pump();
    expect(picks, 1);
  });

  testWidgets('a result shows as signal bars in the shared latency color '
      'beside quiet milliseconds', (tester) async {
    await pump(
      tester,
      ServerCard(
        server: community,
        isSelected: false,
        onTap: () {},
        pingResult: 191,
      ),
    );

    expect(find.text('191 ms'), findsOneWidget);
    // Only the bars carry the color. A gold number on most rows read as a
    // warning on a server that works.
    final text = tester.widget<Text>(find.text('191 ms'));
    expect(text.style?.color, AppDesign.textSecondary);
    final bars = tester.widget<SignalBars>(find.byType(SignalBars));
    expect(bars.level, AppDesign.latencyLevel(191));
    expect(bars.color, AppDesign.latencyColor(191));
  });

  testWidgets('a timeout says so with no bars lit', (tester) async {
    await pump(
      tester,
      ServerCard(
        server: community,
        isSelected: false,
        onTap: () {},
        pingResult: -1,
      ),
    );

    expect(find.text('timeout'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('timeout')).style?.color,
      AppDesign.error,
    );
    expect(tester.widget<SignalBars>(find.byType(SignalBars)).level, 0);
  });

  testWidgets('a waiting row draws a still mark, not a spinner', (
    tester,
  ) async {
    await pump(
      tester,
      ServerCard(
        server: community,
        isSelected: false,
        onTap: () {},
        isQueued: true,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('the Premium tag reads dark on light, not white on the brand '
      'gradient', (tester) async {
    await pump(
      tester,
      ServerCard(
        server: community.copyWith(isPremium: true),
        isSelected: false,
        onTap: () {},
      ),
    );

    final tag = tester.widget<Text>(find.text('PREMIUM'));
    expect(tag.style?.color, AppDesign.onBrandContainer);
  });

  testWidgets('In use is a protected pill beside the name', (tester) async {
    await pump(
      tester,
      ServerRow(
        flag: '',
        title: 'Nuremberg',
        subtitle: '203.0.113.9:443',
        isSelected: true,
        onTap: () {},
        badge: const InUseBadge(label: 'In use'),
      ),
    );

    final badge = tester.widget<Text>(find.text('In use'));
    expect(badge.style?.color, AppDesign.protected);
    expect(
      tester.getTopLeft(find.text('In use')).dx,
      greaterThan(tester.getTopRight(find.text('Nuremberg')).dx),
    );
    // No flag: a globe stands in for it.
    expect(find.byIcon(Icons.public_rounded), findsOneWidget);
  });

  testWidgets('the row mirrors in Persian', (tester) async {
    await pump(
      tester,
      ServerRow(
        flag: '\u{1F1E9}\u{1F1EA}',
        title: 'Nuremberg',
        onTap: () {},
        trailing: const [Icon(Icons.copy_rounded)],
      ),
      locale: const Locale('fa'),
    );

    final flag = tester.getCenter(find.byType(FlagDisc));
    final copy = tester.getCenter(find.byIcon(Icons.copy_rounded));
    expect(flag.dx, greaterThan(copy.dx));
  });

  group('Test all', () {
    testWidgets('starts a run', (tester) async {
      var runs = 0;
      await pump(
        tester,
        TestAllButton(label: 'Test all', onTest: () => runs++),
      );

      expect(
        tester.getSize(find.byType(OutlinedButton)).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.text('Test all'));
      expect(runs, 1);
    });

    // A utility, not a primary action or an offer, so it is steel with the
    // control edge outline and never the brand color. Stop keeps the error
    // color.
    testWidgets('is a steel pill with the outline edge', (tester) async {
      await pump(tester, TestAllButton(label: 'Test all', onTest: () {}));

      final style = tester
          .widget<OutlinedButton>(find.byType(OutlinedButton))
          .style!;
      expect(style.foregroundColor!.resolve({}), AppDesign.steelLight);
      final side = style.side!.resolve({})!;
      expect(side.color, AppDesign.outline);
      expect(side.width, 1);
      expect(
        DefaultTextStyle.of(tester.element(find.text('Test all'))).style.color,
        AppDesign.steelLight,
      );
    });

    testWidgets('a run that cannot be stopped keeps the outline edge', (
      tester,
    ) async {
      // Pumped once: the spinner never settles.
      await tester.pumpWidget(
        MaterialApp(
          theme: appThemeFor(null),
          home: Scaffold(
            body: Center(
              child: TestAllButton(
                label: 'Test all',
                busy: true,
                busyLabel: 'Pinging...',
                onTest: () {},
              ),
            ),
          ),
        ),
      );

      final style = tester
          .widget<OutlinedButton>(find.byType(OutlinedButton))
          .style!;
      expect(style.side!.resolve({})!.color, AppDesign.outline);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a run that cannot be stopped stays enabled and ignores '
        'taps', (tester) async {
      var runs = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: appThemeFor(null),
          home: Scaffold(
            body: Center(
              child: TestAllButton(
                label: 'Test all',
                busy: true,
                busyLabel: 'Pinging...',
                onTest: () => runs++,
              ),
            ),
          ),
        ),
      );

      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNotNull);
      expect(find.text('Pinging...'), findsOneWidget);
      await tester.tap(find.text('Pinging...'));
      await tester.pump();
      expect(runs, 0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a run that can be stopped turns into Stop', (tester) async {
      var stops = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: appThemeFor(null),
          home: Scaffold(
            body: Center(
              child: TestAllButton(
                label: 'Test all',
                busy: true,
                busyLabel: 'Stop',
                onTest: () {},
                onStop: () => stops++,
              ),
            ),
          ),
        ),
      );

      final stop = tester.widget<Text>(find.text('Stop'));
      expect(
        DefaultTextStyle.of(tester.element(find.text('Stop'))).style.color,
        AppDesign.error,
        reason: '${stop.data} is drawn in the error color',
      );
      final side = tester
          .widget<OutlinedButton>(find.byType(OutlinedButton))
          .style!
          .side!
          .resolve({})!;
      expect(side.color, AppDesign.error.withValues(alpha: 0.7));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Stop'));
      await tester.pump();
      expect(stops, 1);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
