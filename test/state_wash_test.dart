import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/design_system.dart';
import 'package:fortiva_vpn/widgets/power_face.dart';
import 'package:fortiva_vpn/widgets/state_wash.dart';

import 'helpers/app_theme.dart';

/// The light behind the home screen's hero: tinted by the button's face,
/// never in the way of the layout, and still once it has changed.
void main() {
  late ThemeData theme;
  setUp(() => theme = appThemeFor(null));

  const shot = Key('shot');
  const box = Key('box');

  Widget host(
    PowerFace face, {
    bool reduce = false,
    Alignment alignment = StateWash.center,
  }) => MaterialApp(
    theme: theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: RepaintBoundary(
          key: shot,
          child: ColoredBox(
            color: Colors.black,
            child: StateWash(
              face: face,
              alignment: alignment,
              child: const SizedBox(key: box, width: 200, height: 160),
            ),
          ),
        ),
      ),
    ),
  );

  bool moving(WidgetTester tester) => tester.binding.transientCallbackCount > 0;

  Future<void> expectStill(WidgetTester tester) async {
    await tester.pump();
    expect(moving(tester), isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
  }

  /// The pixel at ([x], [y]) of the rendered box, as RGBA.
  Future<List<int>> pixelAt(WidgetTester tester, int x, int y) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(shot),
    );
    final data = await tester.runAsync(() async {
      final image = await boundary.toImage();
      return image.toByteData(format: ui.ImageByteFormat.rawRgba);
    });
    final at = (y * 200 + x) * 4;
    return data!.buffer.asUint8List().sublist(at, at + 4);
  }

  testWidgets('leaves its child the size it was', (tester) async {
    await tester.pumpWidget(host(PowerFace.connected));
    expect(tester.getSize(find.byKey(box)), const Size(200, 160));
    expect(tester.getSize(find.byType(StateWash)), const Size(200, 160));
  });

  test('the tint follows the face', () {
    Color at(Color color, double alpha) => color.withValues(alpha: alpha);
    expect(StateWash.tintFor(PowerFace.off), at(AppDesign.steelMid, 0.05));
    expect(
      StateWash.tintFor(PowerFace.connecting),
      at(AppDesign.steelLight, 0.06),
    );
    expect(
      StateWash.tintFor(PowerFace.verifying),
      StateWash.tintFor(PowerFace.connecting),
    );
    expect(
      StateWash.tintFor(PowerFace.connected),
      at(AppDesign.protected, 0.11),
    );
    expect(StateWash.tintFor(PowerFace.stalled), at(AppDesign.warning, 0.07));
    expect(StateWash.tintFor(PowerFace.failed), at(AppDesign.error, 0.07));
    expect(StateWash.tintFor(PowerFace.spent).a, 0);
    expect(
      StateWash.tintFor(PowerFace.disconnecting),
      at(AppDesign.steelMid, 0.05),
    );
  });

  testWidgets('lights the button\'s spot green when protected, and nothing '
      'when the data is used up', (tester) async {
    // The button sits at (0, -0.35) of the box: 52px down a 160px box.
    await tester.pumpWidget(host(PowerFace.connected));
    final lit = await pixelAt(tester, 100, 52);
    expect(lit[1], greaterThan(lit[0]), reason: 'green over red: $lit');
    expect(lit[1], greaterThan(10), reason: 'a visible tint: $lit');
    final corner = await pixelAt(tester, 0, 159);
    expect(corner[1], lessThan(lit[1]), reason: 'it falls off: $corner');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host(PowerFace.spent));
    expect(await pixelAt(tester, 100, 52), [0, 0, 0, 255]);
  });

  testWidgets('centres the light where the layout puts the button', (
    tester,
  ) async {
    // Lower in the box, as on a wide screen: (0, 0.5) is 120px down a
    // 160px box.
    await tester.pumpWidget(
      host(PowerFace.connected, alignment: const Alignment(0, 0.5)),
    );
    final lit = await pixelAt(tester, 100, 120);
    final above = await pixelAt(tester, 100, 52);
    expect(lit[1], greaterThan(above[1]), reason: '$lit over $above');
  });

  testWidgets('crossfades on a change of face, then is still', (tester) async {
    await tester.pumpWidget(host(PowerFace.off));
    await expectStill(tester);

    await tester.pumpWidget(host(PowerFace.connected));
    await tester.pump(const Duration(milliseconds: 200));
    expect(moving(tester), isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    await expectStill(tester);
  });

  testWidgets('changes at once under reduce motion', (tester) async {
    await tester.pumpWidget(host(PowerFace.off, reduce: true));
    await tester.pumpWidget(host(PowerFace.connected, reduce: true));
    expect(moving(tester), isFalse);
    await expectStill(tester);
  });
}
