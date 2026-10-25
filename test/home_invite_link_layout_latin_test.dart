import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/invite_home.dart';

/// The home screen with the invite link on the data line, alone and beside
/// "Get unlimited", in English and Russian (long words), with the shipped
/// Latin font, at the sizes the "Get unlimited" layout is held to
/// (home_offer_layout_latin_test.dart).
///
/// Russian is left out at 1.3 text on a 320 wide phone: the invite link's
/// words take two lines there, and the column scrolls by a few points, as
/// it does with "Get unlimited" at 320x568.
void main() {
  setUpAll(() => loadShippedFonts(rtl: false));
  for (final premium in [false, true]) {
    inviteLinkLayoutTests(
      ['en', 'ru'],
      [(const Size(360, 640), 1.0), (const Size(412, 915), 1.3)],
      premium: premium,
    );
    inviteLinkLayoutTests(
      ['en'],
      [(const Size(320, 640), 1.3), (const Size(320, 568), 1.0)],
      premium: premium,
    );
  }
}
