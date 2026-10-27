import 'package:flutter_test/flutter_test.dart';

import 'helpers/invite_home.dart';
import 'helpers/limit_sheet.dart';

/// The introduction to the invite tree on small phones and with large
/// text, in English, German and Russian, whose words run long, with the
/// fonts the app ships.
void main() {
  setUpAll(() => loadShippedFonts(rtl: false));
  introLayoutTests(['en', 'de', 'ru']);
}
