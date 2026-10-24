import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/design_system.dart';
import 'package:fortiva_vpn/core/state/referral_state.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/widgets/invite_code_dialog.dart';
import 'package:fortiva_vpn/widgets/redeem_code_dialog.dart';
import 'package:provider/provider.dart';

import 'helpers/app_theme.dart';

/// The two code dialogs: "Have an invite code?" and "Enter a code".
///
/// Apply in the invite dialog waits for something in the field. The code
/// field is centred, so what goes in it is a label on its top edge, and
/// the Paste button at its end is balanced at its start: the caret and the
/// code then sit in the middle of the whole field. Both dialogs come up at
/// the same width in every language.
void main() {
  // The app's own fonts, so labels and buttons have their real widths.
  setUpAll(() async {
    for (final family in ['Inter', 'Vazirmatn']) {
      final loader = FontLoader(family);
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        loader.addFont(
          File(
            'assets/fonts/$family/$family-$weight.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        );
      }
      await loader.load();
    }
    // Hindi as the app draws it. Without it, Devanagari falls back to the
    // test font, which draws every glyph a full em wide.
    final devanagari = FontLoader('NotoSansDevanagari')
      ..addFont(
        File(
          'assets/fonts/NotoSansDevanagari/NotoSansDevanagari-Variable.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    await devanagari.load();
  });

  /// A page on a phone of [size] with a button that opens [open], under
  /// the app's theme for [locale] when [themed].
  Future<void> openDialog(
    WidgetTester tester,
    Future<void> Function(BuildContext) open, {
    Locale locale = const Locale('en'),
    bool themed = true,
    double textScale = 1.0,
    Size size = const Size(411, 891),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<ReferralState>(
        create: (_) => ReferralState(),
        child: MaterialApp(
          locale: locale,
          theme: themed ? appThemeFor(locale) : null,
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => open(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> invite(BuildContext context) => showInviteCodeDialog(context);
  Future<void> redeem(BuildContext context) => showRedeemCodeDialog(context);

  final apply = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byWidgetPredicate((w) => w is FilledButton),
  );

  testWidgets('Apply in the invite dialog waits for something in the field', (
    tester,
  ) async {
    await openDialog(tester, invite, themed: false);
    final field = find.byKey(const Key('invite-code-field'));
    expect(tester.widget<FilledButton>(apply).onPressed, isNull);

    await tester.enterText(field, '   ');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(apply).onPressed,
      isNull,
      reason: 'spaces alone are not a code',
    );

    await tester.enterText(field, 'AB3D7K');
    await tester.pump();
    expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);

    await tester.enterText(field, '');
    await tester.pump();
    expect(tester.widget<FilledButton>(apply).onPressed, isNull);
  });

  // On a tablet there is room to centre the code in every language and
  // text size. The test draws the code in its own wide stand in font,
  // since it has no system monospace, and the words in the shipped fonts.
  for (final (name, open, label) in [
    ('invite', invite, 'Invite code'),
    ('redeem', redeem, 'Code'),
  ]) {
    for (final locale in const [Locale('en'), Locale('fa')]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets('[$name ${locale.languageCode} x$scale] the caret and the '
            'code sit in the middle of the whole field', (tester) async {
          await openDialog(
            tester,
            open,
            locale: locale,
            textScale: scale,
            size: const Size(800, 1280),
          );
          final decorator = tester.getRect(
            find.descendant(
              of: find.byType(TextField),
              matching: find.byType(InputDecorator),
            ),
          );
          final input = tester.getRect(find.byType(EditableText));
          expect(input.center.dx, moreOrLessEquals(decorator.center.dx));

          // The label is on the field's top edge, in the middle, and
          // nothing is drawn inside the empty field for the caret to cross.
          final field = tester.widget<TextField>(find.byType(TextField));
          expect(field.decoration?.hintText, isNull);
          final shown = lookupS(locale);
          final words = name == 'invite'
              ? shown.inviteEnterCodeHint
              : shown.redeemHint;
          if (locale.languageCode == 'en') expect(words, label);
          final labelRect = tester.getRect(find.text(words));
          expect(
            labelRect.center.dx,
            moreOrLessEquals(decorator.center.dx, epsilon: 0.5),
          );
          expect(labelRect.bottom, lessThan(input.top));

          await tester.enterText(find.byType(TextField), 'AB3D7K');
          await tester.pump();
          expect(
            tester.getRect(find.byType(EditableText)).center.dx,
            moreOrLessEquals(decorator.center.dx),
          );
        });
      }
    }

    // On a small phone with large text the balance gives way, so the code
    // keeps all the room the field has. Paste stays at the end.
    testWidgets('[$name fa x1.3 on a small phone] the code keeps the room', (
      tester,
    ) async {
      await openDialog(
        tester,
        open,
        locale: const Locale('fa'),
        textScale: 1.3,
        size: const Size(320, 568),
      );
      final decorator = tester.getRect(
        find.descendant(
          of: find.byType(TextField),
          matching: find.byType(InputDecorator),
        ),
      );
      final input = tester.getRect(find.byType(EditableText));
      final paste = tester.getRect(
        find.byKey(Key(name == 'invite' ? 'invite-paste' : 'redeem-paste')),
      );
      // Right to left: the start is on the right, Paste on the left. The
      // start keeps only the field's own padding and the gap to the code.
      expect(input.right, moreOrLessEquals(decorator.right - 20));
      expect(paste.left, moreOrLessEquals(decorator.left));
      expect(input.left, greaterThan(paste.right));
    });
  }

  // The action row sits in the same 24 as the content, so the buttons end
  // on the code field's edges. With the theme's 20 it stuck out 4 past the
  // field on each side. At larger text AlertDialog narrows the content's
  // side padding but not the actions', so there the buttons sit inside the
  // field's edges. On a small phone the buttons may stack, and they still
  // keep inside the field's edges and the screen: the words and the field
  // scroll above them. Before they scrolled, German at 1.3 text overflowed
  // the invite dialog on a 320 by 568 phone.
  for (final (name, open) in [('invite', invite), ('redeem', redeem)]) {
    testWidgets('[$name] the buttons end on the field\'s edges and fit a '
        'small phone at large text in every language', (tester) async {
      final actions = find.descendant(
        of: find.byType(OverflowBar),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      for (final (size, scale) in const [
        (Size(411, 891), 1.0),
        (Size(320, 568), 1.3),
        (Size(320, 568), 1.5),
        (Size(320, 568), 2.0),
      ]) {
        for (final locale in S.supportedLocales) {
          final reason = '$locale at ${size.width} x$scale';
          await openDialog(
            tester,
            open,
            locale: locale,
            textScale: scale,
            size: size,
          );
          expect(tester.takeException(), isNull, reason: reason);
          final rtl = const {'fa', 'ar', 'ur'}.contains(locale.languageCode);
          final field = tester.getRect(find.byType(TextField));
          expect(actions, findsNWidgets(2), reason: reason);
          for (var i = 0; i < 2; i++) {
            final rect = tester.getRect(actions.at(i));
            expect(
              rect.left,
              greaterThanOrEqualTo(field.left - 0.5),
              reason: reason,
            );
            expect(
              rect.right,
              lessThanOrEqualTo(field.right + 0.5),
              reason: reason,
            );
            expect(rect.top, greaterThanOrEqualTo(0), reason: reason);
            expect(rect.bottom, lessThanOrEqualTo(size.height), reason: reason);
          }
          // At the app's own text size Apply, the last action, ends on the
          // field's end edge.
          if (scale == 1.0) {
            final apply = tester.getRect(actions.last);
            expect(
              rtl ? apply.left : apply.right,
              moreOrLessEquals(rtl ? field.left : field.right, epsilon: 0.5),
              reason: reason,
            );
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
    });
  }

  // The field takes focus when the dialog opens, so on a phone the
  // keyboard comes up under it.
  for (final (name, open) in [('invite', invite), ('redeem', redeem)]) {
    testWidgets('[$name] Apply stays above the keyboard on a small phone', (
      tester,
    ) async {
      const keyboard = 260.0;
      for (final locale in const [Locale('en'), Locale('de'), Locale('fa')]) {
        for (final scale in const [1.0, 1.3]) {
          final reason = '$locale x$scale';
          await openDialog(
            tester,
            open,
            locale: locale,
            textScale: scale,
            size: const Size(320, 568),
          );
          tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: reason);
          final apply = tester.getRect(
            find.descendant(
              of: find.byType(OverflowBar),
              matching: find.byType(FilledButton),
            ),
          );
          expect(
            apply.bottom,
            lessThanOrEqualTo(568 - keyboard),
            reason: reason,
          );
          await tester.pumpWidget(const SizedBox());
          tester.view.resetViewInsets();
        }
      }
    });
  }

  testWidgets('both dialogs come up at the same full width in every '
      'language', (tester) async {
    final widths = <String, double>{};
    for (final locale in const [Locale('en'), Locale('fa'), Locale('de')]) {
      for (final (name, open) in [('invite', invite), ('redeem', redeem)]) {
        await openDialog(tester, open, locale: locale);
        final surface = find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Material),
            )
            .first;
        widths['$name ${locale.languageCode}'] = tester.getSize(surface).width;
        await tester.pumpWidget(const SizedBox());
      }
    }
    // A 411dp phone less the dialog's 40dp inset on each side.
    expect(widths.values.toSet(), {331}, reason: '$widths');
  });

  testWidgets('the Apply spinner is white on the ember fill, as on the '
      'speed test', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: CodeSendingSpinner())),
    );
    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.color, AppDesign.onBrand);
    expect(tester.getSize(find.byType(CodeSendingSpinner)), const Size(18, 18));
  });
}
