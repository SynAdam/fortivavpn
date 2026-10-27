import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/invite_home.dart';
import 'helpers/limit_sheet.dart';

/// The limit sheet with its invite card on a small phone, at the default
/// text size and with large text, in English, German and Russian, with the
/// fonts the app ships.
void main() {
  setUpAll(() => loadShippedFonts(rtl: false));
  setUp(() => SharedPreferences.setMockInitialValues({}));
  sheetLayoutTests(['en', 'de', 'ru']);
}
