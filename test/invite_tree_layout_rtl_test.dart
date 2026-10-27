import 'package:flutter_test/flutter_test.dart';

import 'helpers/invite_home.dart';
import 'helpers/invite_tree.dart';

/// The invite screen under the tree rule on small phones, in Persian,
/// Arabic and Urdu, right to left, with an Arabic-script font in place of
/// the phone's own (backend #548).
void main() {
  setUpAll(() => loadShippedFonts(rtl: true));
  inviteTreeLayoutTests(['fa', 'ar', 'ur']);
}
