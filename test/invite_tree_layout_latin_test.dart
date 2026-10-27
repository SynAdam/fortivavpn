import 'package:flutter_test/flutter_test.dart';

import 'helpers/invite_home.dart';
import 'helpers/invite_tree.dart';

/// The invite screen under the tree rule on small phones, in English,
/// German and Russian, whose words run long, with the fonts the app ships
/// (backend #548).
void main() {
  setUpAll(() => loadShippedFonts(rtl: false));
  inviteTreeLayoutTests(['en', 'de', 'ru']);
}
