import 'package:flutter_test/flutter_test.dart';

import 'helpers/invite_home.dart';

/// The home screen with the invite card in Persian, Arabic and Urdu, right
/// to left, with an Arabic-script font in place of the phone's own
/// (clients #271).
void main() {
  setUpAll(() => loadShippedFonts(rtl: true));
  inviteLayoutTests(['fa', 'ar', 'ur']);
}
