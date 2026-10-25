import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/invite_home.dart';

/// The home screen with the invite link on the data line, alone and beside
/// "Get unlimited", in Persian, Arabic and Urdu, right to left, with the
/// Arabic-script font the app ships and its taller lines, at the sizes the
/// "Get unlimited" layout is held to (home_offer_layout_rtl_test.dart).
void main() {
  setUpAll(() => loadShippedFonts(rtl: true));
  for (final premium in [false, true]) {
    inviteLinkLayoutTests(
      ['fa', 'ar', 'ur'],
      [
        (const Size(320, 640), 1.3),
        (const Size(360, 640), 1.0),
        (const Size(320, 568), 1.0),
      ],
      premium: premium,
    );
  }
}
