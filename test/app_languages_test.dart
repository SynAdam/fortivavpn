import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';

/// English is the app's default language and its fallback, and every list of
/// the app's languages names all of them.
void main() {
  group('a phone in a language the app does not have', () {
    test('the generated list starts with English', () {
      expect(S.supportedLocales.first, const Locale('en'));
    });

    // The same call MaterialApp makes when no language has been chosen.
    Locale resolved(List<Locale> phone) =>
        basicLocaleListResolution(phone, S.supportedLocales);

    test('gets English', () {
      expect(resolved(const [Locale('sv', 'SE')]), const Locale('en'));
    });

    test('with no language at all gets English', () {
      expect(resolved(const []), const Locale('en'));
    });

    test('a language the app has is kept', () {
      for (final locale in S.supportedLocales) {
        expect(resolved([locale]), locale);
      }
    });
  });

  group('the language page in Android settings', () {
    List<String> listed() => RegExp(r'<locale\s+android:name="([^"]+)"')
        .allMatches(
          File(
            'android/app/src/main/res/xml/locales_config.xml',
          ).readAsStringSync(),
        )
        .map((m) => m.group(1)!)
        .toList();

    test('lists the same languages as the app, in the same order', () {
      expect(listed(), LocaleState.supportedLanguages.keys.toList());
    });

    test('starts with English', () => expect(listed().first, 'en'));
  });
}
