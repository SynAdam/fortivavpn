import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/invite_home.dart';

/// The home screen with the data line's "Get unlimited" offer in Persian,
/// Arabic and Urdu, right to left, with the Arabic-script font the app
/// ships and its taller lines.
void main() {
  setUpAll(() => loadShippedFonts(rtl: true));
  quotaOfferLayoutTests(
    ['fa', 'ar', 'ur'],
    [
      (const Size(320, 640), 1.3),
      (const Size(360, 640), 1.0),
      (const Size(320, 568), 1.0),
    ],
  );
}
