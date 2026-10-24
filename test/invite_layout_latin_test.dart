import 'package:flutter_test/flutter_test.dart';

import 'helpers/invite_home.dart';

/// The home screen with the invite card in German and Russian, whose words
/// run long, with the fonts the app ships (clients #271).
void main() {
  setUpAll(() => loadShippedFonts(rtl: false));
  inviteLayoutTests(['de', 'ru']);
}
