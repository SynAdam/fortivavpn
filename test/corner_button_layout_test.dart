import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/widgets/corner_button_layout.dart';

/// The column's top in a view [view] tall, for a column [column] tall and
/// no corner button (the chat is off), keeping [topRoom] above it.
Future<double> _top(
  WidgetTester tester, {
  required double view,
  required double column,
  double topRoom = 20,
}) async {
  const key = Key('column');
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 360,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: view),
            child: CornerButtonLayout(
              besideWidth: 220,
              topRoom: topRoom,
              button: const SizedBox.shrink(),
              content: SizedBox(key: key, width: 220, height: column),
            ),
          ),
        ),
      ),
    ),
  );
  return tester.getTopLeft(find.byKey(key)).dy;
}

/// The layout in a view [view] tall, 360 wide: a column of a top part
/// ([topKey], 150 tall) and a line under it (100 tall), [columnWidth] wide,
/// and a square corner button [button] wide (none when 0).
Future<RenderCornerButtonLayout> _layout(
  WidgetTester tester, {
  required double view,
  double columnWidth = 220,
  double button = 0,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 360,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: view),
            child: CornerButtonLayout(
              besideWidth: 220,
              topRoom: 20,
              button: SizedBox.square(dimension: button),
              content: Column(
                key: _columnKey,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(key: _topKey, width: columnWidth, height: 150),
                  SizedBox(width: columnWidth, height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return tester.renderObject<RenderCornerButtonLayout>(
    find.byType(CornerButtonLayout),
  );
}

const _columnKey = Key('column');
const _topKey = Key('top part');

void main() {
  group('CornerButtonLayout.fitsWith', () {
    // Each case: the view now, the change asked about, the column's width
    // and the corner button's size.
    const cases = [
      (600.0, -350.0, 220.0, 0.0),
      (600.0, -351.0, 220.0, 0.0),
      (300.0, -40.0, 220.0, 0.0),
      (240.0, 10.0, 220.0, 0.0),
      (240.0, 9.0, 220.0, 0.0),
      // A column too wide for the button beside it: the button goes under
      // it, and on a short view after it, out of view.
      (500.0, -150.0, 340.0, 48.0),
      (500.0, -180.0, 340.0, 48.0),
      (500.0, -251.0, 340.0, 48.0),
      (320.0, 100.0, 340.0, 48.0),
      // Beside a narrow column.
      (400.0, -150.0, 160.0, 48.0),
      (400.0, -151.0, 160.0, 48.0),
    ];

    testWidgets('tells, without a layout, whether the column would be in '
        'view in a taller or shorter view', (tester) async {
      for (final (view, change, width, button) in cases) {
        final why = 'view $view by $change, column $width, button $button';
        final told = (await _layout(
          tester,
          view: view,
          columnWidth: width,
          button: button,
        )).fitsWith(change);
        await _layout(
          tester,
          view: view + change,
          columnWidth: width,
          button: button,
        );
        final column = tester.getRect(find.byKey(_columnKey));
        final inView =
            column.top >= -0.5 && column.bottom <= view + change + 0.5;
        expect(told, inView, reason: why);
      }
      // The plain cases, spelled out.
      expect((await _layout(tester, view: 600)).fitsWith(-350), isTrue);
      expect((await _layout(tester, view: 600)).fitsWith(-351), isFalse);
    });

    testWidgets('with a part named, only the column down to that part '
        'counts', (tester) async {
      final layout = await _layout(tester, view: 400);
      final top = tester.renderObject<RenderBox>(find.byKey(_topKey));
      expect(layout.fitsWith(-200), isFalse);
      expect(layout.fitsWith(-200, through: top), isTrue);
      expect(layout.fitsWith(-251, through: top), isFalse);
      await _layout(tester, view: 200);
      final part = tester.getRect(find.byKey(_topKey));
      expect(part.bottom, lessThanOrEqualTo(200));
    });

    testWidgets('says yes when it cannot tell', (tester) async {
      final layout = await _layout(tester, view: 400);
      final elsewhere = RenderConstrainedBox(
        additionalConstraints: const BoxConstraints.tightFor(
          width: 10,
          height: 10,
        ),
      );
      expect(layout.fitsWith(-1000, through: elsewhere), isTrue);
    });
  });

  group('CornerButtonLayout top room', () {
    testWidgets('a column with room to spare stays centred', (tester) async {
      expect(await _top(tester, view: 600, column: 250), 175);
    });

    testWidgets('a column with a little room keeps the room above it', (
      tester,
    ) async {
      // Centred it would start 10 down, and the view would cut what the
      // power button draws above its edge.
      expect(await _top(tester, view: 270, column: 250), 20);
    });

    testWidgets('with less room than that it takes all there is, and stays '
        'in the view', (tester) async {
      expect(await _top(tester, view: 262, column: 250), 12);
      expect(await _top(tester, view: 250, column: 250), 0);
    });

    testWidgets('no room asked for centres as before', (tester) async {
      expect(await _top(tester, view: 270, column: 250, topRoom: 0), 10);
    });
  });
}
