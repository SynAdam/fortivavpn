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

void main() {
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
