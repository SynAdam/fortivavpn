import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/splash_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'helpers/app_theme.dart';

/// The splash (lib/screens/splash_screen.dart): it holds for the same time
/// as before, shows the plain mark, and draws no frames once its intro has
/// played, so a phone is not kept busy while it waits.
void main() {
  setUpAll(
    () => PackageInfo.setMockInitialValues(
      appName: 'Fortiva',
      packageName: 'com.vpn.fortivavpn',
      version: '1.11.0',
      buildNumber: '71',
      buildSignature: '',
    ),
  );

  Future<void> pump(
    WidgetTester tester, {
    required VoidCallback onFinished,
    Locale locale = const Locale('en'),
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        theme: appThemeFor(locale),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: SplashScreen(onFinished: onFinished),
      ),
    );
  }

  testWidgets('hands over to the app once, after the same hold as before', (
    tester,
  ) async {
    expect(SplashScreen.hold, const Duration(milliseconds: 1900));
    var finished = 0;
    await pump(tester, onFinished: () => finished++);

    await tester.pump(const Duration(milliseconds: 1899));
    expect(finished, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(finished, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(finished, 1);
  });

  testWidgets('draws nothing more once the intro has played', (tester) async {
    await pump(tester, onFinished: () {});
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue, reason: 'the intro');

    await tester.pump(SplashScreen.intro);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(SplashScreen.hold);
  });

  testWidgets('with reduced motion, shows everything at once and still', (
    tester,
  ) async {
    await pump(tester, onFinished: () {}, reduceMotion: true);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    final fades = tester.widgetList<FadeTransition>(
      find.descendant(
        of: find.byType(SplashScreen),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(fades, isNotEmpty);
    for (final fade in fades) {
      expect(fade.opacity.value, 1);
    }
    await tester.pump(SplashScreen.hold);
  });

  testWidgets('shows the plain mark, decoded at the size it is drawn', (
    tester,
  ) async {
    await pump(tester, onFinished: () {});
    final image = tester.widget<Image>(find.byType(Image));
    final asset = image.image;
    expect(asset, isA<ResizeImage>());
    final resized = asset as ResizeImage;
    expect((resized.imageProvider as AssetImage).assetName, contains('mark'));
    expect(
      resized.width,
      (SplashScreen.markSize * tester.view.devicePixelRatio).round(),
    );
    expect(image.width, SplashScreen.markSize);
    await tester.pump(SplashScreen.hold);
  });

  testWidgets('the wordmark\'s letters sit on the centre line', (tester) async {
    await pump(tester, onFinished: () {});
    await tester.pump(SplashScreen.intro);
    final word = find.text('FORTIVA');
    expect(
      tester.widget<Text>(word).style!.letterSpacing,
      SplashScreen.wordmarkSpacing,
    );
    final box = tester.getRect(word);
    final screen = tester.getRect(find.byType(SplashScreen));
    expect(box.center.dx, moreOrLessEquals(screen.center.dx, epsilon: 0.5));

    // The letters as drawn, not the box: read the pixels in the word's
    // rows and find the first and last lit column. This does not depend
    // on where the engine puts the spacing, so a padding added to make up
    // for it, or a change in the engine, shows here as the word off
    // centre.
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find
          .ancestor(
            of: find.byType(SplashScreen),
            matching: find.byType(RepaintBoundary),
          )
          .first,
    );
    final origin = boundary.localToGlobal(Offset.zero);
    const ratio = 2.0;
    final ink = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: ratio);
      final bytes = (await image.toByteData())!;
      final top = ((box.top - origin.dy) * ratio).floor();
      final bottom = ((box.bottom - origin.dy) * ratio).ceil();
      int? first;
      int? last;
      for (var y = top; y < bottom; y++) {
        for (var x = 0; x < image.width; x++) {
          // The red channel: the letters are near white, the background
          // near black, so half way tells them apart.
          if (bytes.getUint8((y * image.width + x) * 4) > 128) {
            first = first == null || x < first ? x : first;
            last = last == null || x > last ? x : last;
          }
        }
      }
      image.dispose();
      return (first!, last!);
    });
    final (first, last) = ink!;
    final inkCentre = origin.dx + (first + last + 1) / 2 / ratio;
    expect(inkCentre, moreOrLessEquals(screen.center.dx, epsilon: 0.5));
    await tester.pump(SplashScreen.hold);
  });

  testWidgets('the version is in the language\'s own digits', (tester) async {
    await pump(tester, onFinished: () {}, locale: const Locale('fa'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(SplashScreen.intro);
    expect(find.textContaining('۱.۱۱.۰'), findsOneWidget);
    expect(find.textContaining('1.11.0'), findsNothing);
    await tester.pump(SplashScreen.hold);
  });
}
