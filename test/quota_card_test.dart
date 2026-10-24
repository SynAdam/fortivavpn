import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/design_system.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/widgets/quota_card.dart';

/// The allowance card reads like a fuel gauge: the bar and the text show
/// what is left, so "resets in 13 hours" describes the bar it sits next
/// to. On 2026-10-05 a user with 362 MB of 10 GB used saw a nearly empty
/// bar beside "refills in 13 hours" and took the allowance for spent.
void main() {
  QuotaStatus quota({required int usedMb, bool blocked = false}) => QuotaStatus(
    unlimited: false,
    limitBytes: 10 << 30,
    usedBytes: usedMb << 20,
    remainingBytes: (10 << 30) - (usedMb << 20),
    blocked: blocked,
    resetsAt: DateTime.now().add(const Duration(hours: 13, minutes: 30)),
  );

  Widget wrap(QuotaStatus q, {String locale = 'en'}) => MaterialApp(
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    locale: Locale(locale),
    home: Scaffold(body: QuotaCard(quota: q)),
  );

  double bar(WidgetTester tester) => tester
      .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
      .value!;

  testWidgets('a little used is a nearly full bar and most of it left', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(quota(usedMb: 362)));

    expect(bar(tester), closeTo(0.965, 0.001));
    expect(find.text('9.6 GB of 10.0 GB left'), findsOneWidget);
    expect(find.text('Resets in 13h'), findsOneWidget);
  });

  testWidgets('a spent allowance is an empty bar with nothing left', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(quota(usedMb: 10 << 10, blocked: true)));

    expect(bar(tester), 0);
    expect(find.text('0 B of 10.0 GB left'), findsOneWidget);
    expect(find.text('Daily limit reached'), findsOneWidget);
  });

  testWidgets('reads in Persian, in Persian digits', (tester) async {
    await tester.pumpWidget(wrap(quota(usedMb: 362), locale: 'fa'));

    // Each amount is isolated with its unit (U+2068 to U+2069), so the
    // right to left line keeps "9.6 GB" in one piece. The decimal sign is
    // the Persian one (U+066B): a period between Persian zeros, which are
    // small rings, read as one more dot.
    String amount(String text) => '\u2068$text\u2069';
    expect(
      find.text('${amount('۹٫۶ GB')} از ${amount('۱۰٫۰ GB')} باقی مانده'),
      findsOneWidget,
    );
    expect(find.textContaining(RegExp('[0-9]')), findsNothing);
    expect(find.textContaining('.'), findsNothing);
  });

  testWidgets('Arabic gets its own digits and decimal sign; English keeps '
      'the period', (tester) async {
    BuildContext? arabic;
    BuildContext? english;
    Widget probe(String locale, void Function(BuildContext) keep) =>
        Localizations(
          locale: Locale(locale),
          delegates: S.localizationsDelegates,
          child: Builder(
            builder: (context) {
              keep(context);
              return const SizedBox();
            },
          ),
        );
    await tester.pumpWidget(
      Column(
        children: [
          probe('ar', (c) => arabic = c),
          probe('en', (c) => english = c),
        ],
      ),
    );

    final size = (9 << 30) + (600 << 20);
    expect(QuotaCard.localizedBytes(size, arabic!), '٩٫٦ GB');
    expect(QuotaCard.localizedBytes(size, english!), '9.6 GB');
  });

  // The amount left is what the card is for (the fuel gauge rule), so it is
  // the loudest line, and the label above it is the quiet one.
  testWidgets('the amount left is louder than the label', (tester) async {
    await tester.pumpWidget(wrap(quota(usedMb: 362)));

    final label = tester.widget<Text>(find.text('Daily data')).style!;
    final left = tester
        .widget<Text>(find.text('9.6 GB of 10.0 GB left'))
        .style!;
    expect(left.fontSize!, greaterThan(label.fontSize!));
    expect(left.color, AppDesign.textPrimary);
    expect(label.color, AppDesign.textSecondary);
    // Amounts and the reset time change in place: tabular figures in Latin.
    expect(left.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(
      tester.widget<Text>(find.text('Resets in 13h')).style!.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('a spent allowance names the limit in the error color', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(quota(usedMb: 10 << 10, blocked: true)));

    expect(
      tester.widget<Text>(find.text('Daily limit reached')).style!.color,
      AppDesign.error,
    );
  });

  group('the bar reads like a fuel gauge', () {
    Color barColor(WidgetTester tester) =>
        (tester
                    .widget<LinearProgressIndicator>(
                      find.byType(LinearProgressIndicator),
                    )
                    .valueColor!
                as AlwaysStoppedAnimation<Color>)
            .value;

    for (final (usedMb, color, name) in [
      (362, AppDesign.protected, 'plenty left'),
      (8 << 10, AppDesign.warning, 'the last quarter'),
      (10 << 10, AppDesign.error, 'nothing left'),
    ]) {
      testWidgets(name, (tester) async {
        await tester.pumpWidget(wrap(quota(usedMb: usedMb)));
        expect(barColor(tester), color);
      });
    }
  });

  test('an allowance reads as people say it', () {
    expect(QuotaCard.formatAllowance(20 << 30), '20 GB');
    expect(QuotaCard.formatAllowance((5 << 30) + (512 << 20)), '5.5 GB');
    expect(QuotaCard.formatAllowance(500 << 20), '500 MB');
  });

  group('the refill time is in the language\'s own digits', () {
    final at = QuotaStatus(
      unlimited: false,
      limitBytes: 100,
      usedBytes: 100,
      remainingBytes: 0,
      blocked: true,
      resetsAt: DateTime.now().add(const Duration(hours: 23, minutes: 30)),
    );
    final soon = QuotaStatus(
      unlimited: false,
      limitBytes: 100,
      usedBytes: 100,
      remainingBytes: 0,
      blocked: true,
      resetsAt: DateTime.now().add(const Duration(minutes: 42, seconds: 30)),
    );
    final latin = RegExp('[0-9]');

    for (final (locale, digits) in [('fa', '۲۳'), ('ur', '۲۳'), ('ar', '٢٣')]) {
      test(locale, () {
        // Persian showed "23" in Latin digits on the red server card on
        // 2026-10-08. Every place that says when the data refills reads
        // it from here.
        final l10n = lookupS(Locale(locale));
        final hours = QuotaCard.resetLabel(l10n, at);
        expect(hours, contains(digits));
        expect(hours, isNot(contains(latin)));
        expect(QuotaCard.resetLabel(l10n, soon), isNot(contains(latin)));
      });
    }

    test('en keeps its digits', () {
      expect(
        QuotaCard.resetLabel(lookupS(const Locale('en')), at),
        'Resets in 23h',
      );
    });
  });
}
