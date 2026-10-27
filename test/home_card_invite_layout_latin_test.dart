import 'package:flutter_test/flutter_test.dart';

import 'helpers/invite_home.dart';
import 'helpers/limit_sheet.dart';

/// The invite link on the spent server card in English and German, whose
/// words run long, with the fonts the app ships: the power button stays on
/// screen beside it.
void main() {
  setUpAll(() => loadShippedFonts(rtl: false));
  spentCardLayoutTests(['en', 'de']);
}
