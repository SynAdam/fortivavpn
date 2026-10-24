import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/connection_info.dart';
import 'package:fortiva_vpn/widgets/power_button.dart';
import 'package:fortiva_vpn/widgets/power_face.dart';

import 'helpers/app_theme.dart';

/// The power button is the one control on home, and the one thing on it
/// that moves. These pin when it moves: the light only while busy and
/// seen, the success moment only for a connect the user watched land, and
/// nothing at all once it is idle or connected, so a phone left on the
/// home screen draws no frames for it. And they pin what it shows: the
/// shield's eyes, dark while off and green only once connected.
void main() {
  /// The haptic kinds played, in order: "HapticFeedbackType.mediumImpact"
  /// for a tap, "HapticFeedbackType.heavyImpact" for success.
  late List<String> haptics;
  late ThemeData theme;

  setUp(() {
    // One theme for the whole test: a new one on every rebuild would
    // animate between the two and hide what the button does.
    theme = appThemeFor(null);
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  const success = 'HapticFeedbackType.heavyImpact';
  const tap = 'HapticFeedbackType.mediumImpact';
  const shot = Key('shot');

  Widget host(
    Widget button, {
    bool reduce = false,
    bool tickers = true,
    TextDirection direction = TextDirection.ltr,
  }) => MaterialApp(
    theme: theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
      child: child!,
    ),
    home: TickerMode(
      enabled: tickers,
      child: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: Center(
            child: RepaintBoundary(key: shot, child: button),
          ),
        ),
      ),
    ),
  );

  PowerButton button(
    VpnStatus status, {
    bool verifying = false,
    PowerFace? face,
    bool celebrate = true,
    String? label,
    VoidCallback? onTap,
  }) => PowerButton(
    status: status,
    isVerifying: verifying,
    face: face,
    celebrate: celebrate,
    semanticLabel: label,
    onTap: onTap ?? () {},
  );

  /// Whether anything animates: a ticker that is running and not muted.
  bool moving(WidgetTester tester) => tester.binding.transientCallbackCount > 0;

  /// Nothing animates, and a frame drawn now asks for no other. The first
  /// frame after pumpWidget always asks for one more, and so can a frame in
  /// which an animation stopped, so this draws one before it looks.
  Future<void> expectStill(WidgetTester tester) async {
    await tester.pump();
    expect(moving(tester), isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
  }

  /// Decodes the button's pictures, as the splash screen does in the app.
  /// A widget test decodes nothing on its own, so without this the button
  /// draws nothing.
  Future<void> loadArt(WidgetTester tester) async {
    await tester.pumpWidget(host(const SizedBox()));
    final context = tester.element(find.byType(Scaffold));
    await tester.runAsync(() => PowerButton.precache(context));
  }

  /// The drawing under [shot], as RGBA bytes one logical pixel each.
  Future<({List<int> rgba, int width})> render(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(shot),
    );
    final image = (await tester.runAsync(() => boundary.toImage()))!;
    final data = await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    final width = image.width;
    image.dispose();
    return (rgba: data!.buffer.asUint8List().toList(), width: width);
  }

  /// The average color around [at], in the button's own coordinates.
  Color colorAt(({List<int> rgba, int width}) drawn, Offset at) {
    var r = 0, g = 0, b = 0, n = 0;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final i = ((at.dy.round() + dy) * drawn.width + at.dx.round() + dx) * 4;
        r += drawn.rgba[i];
        g += drawn.rgba[i + 1];
        b += drawn.rgba[i + 2];
        n++;
      }
    }
    return Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n);
  }

  double lightness(Color c) => (c.r + c.g + c.b) / 3;

  // The middles of the helmet's eyes in a button of the default size: the
  // left one (the picture's own left), and the right, its mirror image.
  // From tool/hero_art.py's canvas: the left eye at (362, 571) of 912 by
  // 1128, and the shield 908 high drawn 0.94 of the button's side.
  const leftEye = Offset(88.6, 111.6);
  const rightEye = Offset(131.2, 111.6);

  group('at rest', () {
    testWidgets('off draws no frames once built', (tester) async {
      await tester.pumpWidget(host(button(VpnStatus.disconnected)));
      await expectStill(tester);
      await tester.pump(const Duration(seconds: 1));
      await expectStill(tester);
    });

    testWidgets('a button built connected is still and does not celebrate', (
      tester,
    ) async {
      // The app opened on a tunnel that was already up: nothing landed
      // while the user watched, so there is nothing to celebrate.
      await tester.pumpWidget(host(button(VpnStatus.connected)));
      await expectStill(tester);
      await tester.pump(const Duration(seconds: 1));
      await expectStill(tester);
      expect(haptics, isEmpty);
    });

    for (final face in [PowerFace.stalled, PowerFace.failed, PowerFace.spent]) {
      testWidgets('${face.name} draws no frames once built', (tester) async {
        await tester.pumpWidget(
          host(button(VpnStatus.disconnected, face: face)),
        );
        await tester.pump(const Duration(seconds: 1));
        await expectStill(tester);
      });
    }

    testWidgets('with its pictures drawn, connected is still too', (
      tester,
    ) async {
      await loadArt(tester);
      await tester.pumpWidget(host(button(VpnStatus.connected)));
      await expectStill(tester);
      await tester.pump(const Duration(seconds: 1));
      await expectStill(tester);
    });
  });

  group('the busy light', () {
    testWidgets('sweeps while connecting and stops once connected', (
      tester,
    ) async {
      await tester.pumpWidget(host(button(VpnStatus.connecting)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(moving(tester), isTrue);
      await tester.pump(const Duration(seconds: 3));
      expect(moving(tester), isTrue);

      await tester.pumpWidget(host(button(VpnStatus.connected)));
      // The colors, the light's fade and the success moment all end within
      // a second; after that nothing runs.
      await tester.pump(const Duration(seconds: 1));
      await expectStill(tester);
    });

    testWidgets('sweeps while the tunnel is up but still being checked', (
      tester,
    ) async {
      // Verifying draws as busy, never as connected: the tunnel is not
      // known to work yet.
      await tester.pumpWidget(
        host(button(VpnStatus.connected, verifying: true)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(moving(tester), isTrue);
    });

    testWidgets('sweeps while the tunnel comes down, then stops', (
      tester,
    ) async {
      await tester.pumpWidget(host(button(VpnStatus.disconnecting)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(moving(tester), isTrue);

      await tester.pumpWidget(host(button(VpnStatus.disconnected)));
      await tester.pump(const Duration(seconds: 1));
      await expectStill(tester);
      expect(haptics, isEmpty);
    });

    testWidgets('stands still under reduce motion', (tester) async {
      await tester.pumpWidget(host(button(VpnStatus.connecting), reduce: true));
      await expectStill(tester);
      await tester.pump(const Duration(seconds: 1));
      await expectStill(tester);
    });

    testWidgets('waits while another screen covers it, and sweeps again on '
        'return', (tester) async {
      await tester.pumpWidget(
        host(button(VpnStatus.connecting), tickers: false),
      );
      await tester.pump(const Duration(seconds: 1));
      await expectStill(tester);

      await tester.pumpWidget(host(button(VpnStatus.connecting)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(moving(tester), isTrue);
    });
  });

  group('the eyes', () {
    testWidgets('the pictures share the canvas the button draws them on', (
      tester,
    ) async {
      // tool/hero_art.py draws all four on one canvas, 912 by 1128 of the
      // icon's pixels, and the button draws each over the same box. One
      // drawn on another canvas would put the eyes beside the visor.
      const aspect = 912 / 1128;
      for (final name in ['shield.webp', 'eyes.png', 'glow.png', 'halo.png']) {
        final size = await tester.runAsync(() async {
          final data = await rootBundle.load('assets/hero/$name');
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
          );
          final frame = await codec.getNextFrame();
          final size = Size(
            frame.image.width.toDouble(),
            frame.image.height.toDouble(),
          );
          frame.image.dispose();
          codec.dispose();
          return size;
        });
        expect(size!.aspectRatio, closeTo(aspect, 0.004), reason: name);
      }
    });

    testWidgets('are dark while off', (tester) async {
      await loadArt(tester);
      await tester.pumpWidget(host(button(VpnStatus.disconnected)));
      final drawn = await render(tester);
      for (final eye in [leftEye, rightEye]) {
        expect(lightness(colorAt(drawn, eye)), lessThan(0.15));
      }
    });

    testWidgets('burn protected green once connected', (tester) async {
      await loadArt(tester);
      await tester.pumpWidget(host(button(VpnStatus.connected)));
      final drawn = await render(tester);
      for (final eye in [leftEye, rightEye]) {
        final c = colorAt(drawn, eye);
        expect(lightness(c), greaterThan(0.7));
        // Green, not the white of the steel: green leads red clearly.
        expect(c.g - c.r, greaterThan(0.08));
      }
    });

    testWidgets('show the warning colors, never green, when the tunnel '
        'stalls or fails', (tester) async {
      await loadArt(tester);
      for (final face in [PowerFace.stalled, PowerFace.failed]) {
        await tester.pumpWidget(
          host(button(VpnStatus.connected, face: face, celebrate: false)),
        );
        await tester.pump(const Duration(seconds: 1));
        final c = colorAt(await render(tester), leftEye);
        expect(lightness(c), greaterThan(0.5), reason: face.name);
        expect(c.r, greaterThan(c.g), reason: face.name);
      }
    });

    testWidgets('are not green while connecting: a light sweeps from one '
        'to the other', (tester) async {
      await loadArt(tester);
      await tester.pumpWidget(host(button(VpnStatus.connecting)));
      // The light starts at the left eye's outer end and is over the left
      // eye for the first part of a sweep.
      await tester.pump(const Duration(milliseconds: 250));
      var drawn = await render(tester);
      final left = colorAt(drawn, leftEye);
      expect(lightness(left), greaterThan(lightness(colorAt(drawn, rightEye))));
      expect((left.g - left.r).abs(), lessThan(0.05));
      // Half a sweep later it is over the right eye.
      await tester.pump(const Duration(milliseconds: 1200));
      drawn = await render(tester);
      expect(
        lightness(colorAt(drawn, rightEye)),
        greaterThan(lightness(colorAt(drawn, leftEye))),
      );
    });
  });

  group('the success moment', () {
    Future<void> land(
      WidgetTester tester, {
      VpnStatus from = VpnStatus.connecting,
      bool verifying = false,
      PowerFace? fromFace,
      PowerFace? toFace,
      bool celebrate = true,
      bool reduce = false,
    }) async {
      await tester.pumpWidget(
        host(
          button(
            from,
            verifying: verifying,
            face: fromFace,
            celebrate: celebrate,
          ),
          reduce: reduce,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(
        host(
          button(VpnStatus.connected, face: toFace, celebrate: celebrate),
          reduce: reduce,
        ),
      );
    }

    testWidgets('plays once when a connect lands on screen', (tester) async {
      await land(tester);
      expect(haptics, [success]);
      // The eyes' flash and the ripple outlast the 350ms color change.
      await tester.pump(const Duration(milliseconds: 500));
      expect(moving(tester), isTrue);
      await tester.pump(const Duration(milliseconds: 500));
      await expectStill(tester);
      expect(haptics, [success]);
    });

    testWidgets('plays after the check that follows a connect', (tester) async {
      await land(tester, from: VpnStatus.connected, verifying: true);
      expect(haptics, [success]);
    });

    testWidgets('plays from the verifying face the home screen gives', (
      tester,
    ) async {
      await land(
        tester,
        from: VpnStatus.connected,
        fromFace: PowerFace.verifying,
        toFace: PowerFace.connected,
      );
      expect(haptics, [success]);
    });

    testWidgets('does not play when the connection came back by itself', (
      tester,
    ) async {
      await land(tester, celebrate: false);
      // Only the color change runs, and it is done well before the
      // ripple would be.
      await tester.pump(const Duration(milliseconds: 450));
      await expectStill(tester);
      expect(haptics, isEmpty);
    });

    testWidgets('does not play under reduce motion', (tester) async {
      await land(tester, reduce: true);
      await expectStill(tester);
      expect(haptics, isEmpty);
    });

    testWidgets('does not play when a stalled tunnel recovers', (tester) async {
      await land(
        tester,
        from: VpnStatus.connected,
        fromFace: PowerFace.stalled,
        toFace: PowerFace.connected,
      );
      await tester.pump(const Duration(milliseconds: 450));
      await expectStill(tester);
      expect(haptics, isEmpty);
    });

    testWidgets('does not play for a connect that landed while the app was '
        'in the background', (tester) async {
      void go(List<AppLifecycleState> states) {
        for (final state in states) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
      }

      await tester.pumpWidget(host(button(VpnStatus.connecting)));
      await tester.pump(const Duration(milliseconds: 300));
      // The user switches away while it connects. Frames stop, so the
      // connect that lands meanwhile is handled in the first frame back.
      go(const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);
      go(const [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await tester.pumpWidget(host(button(VpnStatus.connected)));
      await tester.pump(const Duration(milliseconds: 450));
      await expectStill(tester);
      expect(haptics, isEmpty);

      // The next connect the user watches gets its moment again.
      await tester.pumpWidget(host(button(VpnStatus.disconnected)));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(host(button(VpnStatus.connecting)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(host(button(VpnStatus.connected)));
      expect(haptics, [success]);
    });
  });

  group('a press', () {
    Finder pressScale() => find
        .descendant(
          of: find.byType(PowerButton),
          matching: find.byType(ScaleTransition),
        )
        .first;
    double scale(WidgetTester tester) =>
        tester.widget<ScaleTransition>(pressScale()).scale.value;
    Finder gestures() => find.descendant(
      of: find.byType(PowerButton),
      matching: find.byType(GestureDetector),
    );

    testWidgets('gives the tap haptic and calls onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(button(VpnStatus.disconnected, onTap: () => taps++)),
      );
      await tester.tap(find.byType(PowerButton));
      await tester.pump();
      expect(taps, 1);
      expect(haptics, [tap]);
    });

    testWidgets('the light over the shield takes no taps, and the corners '
        'beside the shield do', (tester) async {
      // The busy light is drawn over the shield. It must not take the hit,
      // or every test that taps the button is told something covers it.
      await tester.pumpWidget(host(button(VpnStatus.connecting)));
      final light = tester.renderObject(
        find
            .descendant(
              of: find.byType(PowerButton),
              matching: find.byType(CustomPaint),
            )
            .last,
      );
      final target = tester.renderObject(gestures());
      final middle = tester.hitTestOnBinding(
        tester.getCenter(find.byType(PowerButton)),
      );
      expect(middle.path.any((entry) => entry.target == light), isFalse);
      expect(middle.path.any((entry) => entry.target == target), isTrue);
      // The shield is narrower than the button. Reaching the control
      // should take no aim, so the square around it answers too.
      final corner = tester.hitTestOnBinding(
        tester.getTopLeft(find.byType(PowerButton)) + const Offset(6, 6),
      );
      expect(corner.path.any((entry) => entry.target == target), isTrue);
    });

    testWidgets('dips while held, springs back, then is still', (tester) async {
      await tester.pumpWidget(host(button(VpnStatus.disconnected)));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PowerButton)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(scale(tester), closeTo(0.95, 0.001));

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(scale(tester), greaterThan(0.95));
      await tester.pump(const Duration(milliseconds: 500));
      expect(scale(tester), closeTo(1, 0.002));
      await expectStill(tester);
    });

    testWidgets('is ignored while the tunnel comes down', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(button(VpnStatus.disconnecting, onTap: () => taps++)),
      );
      await tester.tap(find.byType(PowerButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 0);
      expect(haptics, isEmpty);
      expect(scale(tester), 1);
    });
  });

  group('to a screen reader', () {
    testWidgets('it is a button that says the status line', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        host(button(VpnStatus.disconnected, label: 'Tap to connect')),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Tap to connect')),
        containsSemantics(
          label: 'Tap to connect',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('it says it is not enabled while the tunnel comes down', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        host(button(VpnStatus.disconnecting, label: 'Disconnecting')),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Disconnecting')),
        containsSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      semantics.dispose();
    });
  });

  group('in a right to left language', () {
    Future<List<int>> sweepFrame(
      WidgetTester tester,
      TextDirection direction,
    ) async {
      await tester.pumpWidget(
        host(button(VpnStatus.connecting), direction: direction),
      );
      // Early in a sweep: the light is over the left eye, so a mirrored
      // drawing would put it on the right.
      await tester.pump(const Duration(milliseconds: 250));
      final drawn = await render(tester);
      await tester.pumpWidget(host(const SizedBox()));
      return drawn.rgba;
    }

    List<int> mirrored(List<int> rgba, int width) {
      final out = List<int>.filled(rgba.length, 0);
      final rows = rgba.length ~/ (width * 4);
      for (var y = 0; y < rows; y++) {
        for (var x = 0; x < width; x++) {
          final from = (y * width + x) * 4;
          final to = (y * width + (width - 1 - x)) * 4;
          for (var c = 0; c < 4; c++) {
            out[to + c] = rgba[from + c];
          }
        }
      }
      return out;
    }

    testWidgets('it draws exactly the same: neither the shield nor the '
        'sweep is mirrored', (tester) async {
      // The shield is the brand's picture, the same in every language, and
      // the light sweeps the same way everywhere.
      await loadArt(tester);
      final ltr = await sweepFrame(tester, TextDirection.ltr);
      final rtl = await sweepFrame(tester, TextDirection.rtl);
      expect(rtl, ltr);
      // And the drawing is not symmetric, so the comparison could catch a
      // mirror.
      expect(mirrored(ltr, PowerButton.defaultSize.toInt()), isNot(ltr));
    });
  });
}
