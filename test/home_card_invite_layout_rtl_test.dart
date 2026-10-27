import 'package:flutter_test/flutter_test.dart';

import 'helpers/invite_home.dart';
import 'helpers/limit_sheet.dart';

/// The invite link on the spent server card in Persian, right to left,
/// with an Arabic-script font in place of the phone's own: the power button
/// stays on screen beside it.
void main() {
  setUpAll(() => loadShippedFonts(rtl: true));
  spentCardLayoutTests(['fa']);
}
