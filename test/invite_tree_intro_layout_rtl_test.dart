import 'package:flutter_test/flutter_test.dart';

import 'helpers/invite_home.dart';
import 'helpers/limit_sheet.dart';

/// The introduction to the invite tree and its questions page on small
/// phones and with large text, in Persian, Arabic and Urdu, right to left,
/// with an Arabic-script font in place of the phone's own.
void main() {
  setUpAll(() => loadShippedFonts(rtl: true));
  introLayoutTests(['fa', 'ar', 'ur']);
  questionsLayoutTests(['fa', 'ar', 'ur']);
}
