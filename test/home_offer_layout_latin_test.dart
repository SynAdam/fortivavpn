import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/invite_home.dart';

/// The home screen with the data line's "Get unlimited" offer, in English
/// and Russian (long words), with the shipped Latin font.
///
/// Russian is left out at 320x568: there the column scrolls with the offer
/// on, as it already did before the redesign.
void main() {
  setUpAll(() => loadShippedFonts(rtl: false));
  quotaOfferLayoutTests(
    ['en', 'ru'],
    [(const Size(320, 640), 1.3), (const Size(360, 640), 1.0)],
  );
  quotaOfferLayoutTests(['en'], [(const Size(320, 568), 1.0)]);
  // Russian at 1.5 text on a 320 wide phone: nothing fits beside the
  // amounts.
  quotaOfferUnderTest('ru', const Size(320, 640), 1.5);
}
