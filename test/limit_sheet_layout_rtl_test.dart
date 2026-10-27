import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/invite_home.dart';
import 'helpers/limit_sheet.dart';

/// The limit sheet with its invite card on a small phone, at the default
/// text size and with large text, in Persian, Arabic and Urdu, right to
/// left, with an Arabic-script font in place of the phone's own.
void main() {
  setUpAll(() => loadShippedFonts(rtl: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));
  sheetLayoutTests(['fa', 'ar', 'ur']);
}
