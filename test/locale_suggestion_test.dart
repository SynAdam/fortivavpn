import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/locale_suggestion.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';

/// Tests for the language offered on a first launch.
///
/// On a phone set to English or to a language the app does not ship, the
/// SIM country leads, then the phone's region, then the backend's country.
/// A phone set to a shipped language other than English ignores the SIM.
/// The phone's own language is the fallback, and English is the floor.
/// Each of those has a case here because getting it wrong greets someone
/// with a screen they cannot read.
void main() {
  final supported = LocaleState.supportedLanguages.keys;

  String resolve(
    String? language,
    String? country, {
    String? ip,
    String? sim,
    Iterable<String>? languages,
  }) {
    return LocaleSuggestion.resolve(
      deviceLocale: language == null
          ? null
          : Locale.fromSubtags(languageCode: language, countryCode: country),
      supported: languages ?? supported,
      simCountry: sim,
      ipCountry: ip,
    );
  }

  bool needsLookup(String language, String? country, {String? sim}) {
    return LocaleSuggestion.needsCountryLookup(
      deviceLocale: Locale.fromSubtags(
        languageCode: language,
        countryCode: country,
      ),
      supported: supported,
      simCountry: sim,
    );
  }

  group('the SIM country leads', () {
    // Android reports the SIM country in lower case.
    test('an Iranian SIM on an English phone set to the US offers Persian', () {
      expect(resolve('en', 'US', sim: 'ir'), 'fa');
    });

    test('a Turkish SIM on an English phone set to the UK offers Turkish', () {
      expect(resolve('en', 'GB', sim: 'tr'), 'tr');
    });

    test('the SIM wins over a phone region that maps to a language', () {
      expect(resolve('en', 'DE', sim: 'ir'), 'fa');
    });

    test('the SIM wins over the backend country', () {
      // Another VPN that is already on makes the backend country its
      // server's. A roaming SIM still names its home country.
      expect(resolve('en', 'US', sim: 'ir', ip: 'DE'), 'fa');
      expect(resolve('en', null, sim: 'ir', ip: 'TR'), 'fa');
    });

    test('a SIM country that maps to nothing falls through to the region', () {
      expect(resolve('en', 'DE', sim: 'us'), 'de');
      expect(resolve('en', 'IR', sim: 'us'), 'fa');
    });

    test('then to the backend country', () {
      expect(resolve('en', null, sim: 'us', ip: 'IR'), 'fa');
    });

    test('then to the phone language', () {
      expect(resolve('fr', 'CA', sim: 'us'), 'fr');
      expect(resolve('ru', 'US', sim: 'us'), 'ru');
      expect(resolve('sv', 'SE', sim: 'us'), 'en');
    });

    test('a SIM country that is not a two-letter code is ignored', () {
      expect(resolve('en', 'DE', sim: ''), 'de');
      expect(resolve('en', 'DE', sim: 'IRN'), 'de');
    });

    test('a SIM language the app does not ship is skipped', () {
      expect(resolve('en', 'TR', sim: 'ir', languages: ['en', 'tr']), 'tr');
      expect(resolve('en', 'DE', sim: 'ir', languages: ['en', 'de']), 'de');
    });

    test('the SIM leads on a phone language the app does not ship', () {
      expect(resolve('sv', 'SE', sim: 'ir'), 'fa');
      expect(resolve('he', 'IL', sim: 'tr'), 'tr');
    });

    test('the SIM leads on a phone with no locale', () {
      expect(resolve(null, null, sim: 'ir'), 'fa');
    });
  });

  group('a phone in a shipped language other than English ignores the SIM', () {
    test('a Persian phone with a Turkish SIM keeps Persian', () {
      expect(resolve('fa', 'IR', sim: 'tr'), 'fa');
    });

    test('a Persian phone with a UAE SIM keeps Persian', () {
      expect(resolve('fa', 'IR', sim: 'ae'), 'fa');
    });

    test('a German phone with a Turkish SIM keeps German', () {
      expect(resolve('de', 'DE', sim: 'tr'), 'de');
    });

    test('an Arabic phone with an Iranian SIM keeps Arabic', () {
      expect(resolve('ar', 'IQ', sim: 'ir'), 'ar');
      expect(resolve('ar', 'US', sim: 'ir'), 'ar');
    });

    test('every such phone gives the same answer as with no SIM', () {
      final languages = supported.where((l) => l != 'en');
      for (final language in languages) {
        for (final region in [null, 'US', 'IR', 'TR', 'DE']) {
          for (final ip in [null, 'DE', 'IR']) {
            final noSim = resolve(language, region, ip: ip);
            for (final sim in ['ir', 'tr', 'ae', 'ru', 'us']) {
              expect(
                resolve(language, region, ip: ip, sim: sim),
                noSim,
                reason: '$language-$region backend $ip SIM $sim',
              );
            }
          }
        }
      }
    });
  });

  group('no SIM keeps every earlier answer', () {
    // Windows and most TVs have no SIM. The cases in the groups below run
    // without one as well; this table checks a passed null and a missing
    // argument give the same answer.
    const cases = [
      // language, region, backend country, expected
      ('en', 'IR', null, 'fa'),
      ('en', 'SA', null, 'ar'),
      ('en', 'TR', null, 'tr'),
      ('ru', 'UZ', null, 'uz'),
      ('en', 'CA', null, 'en'),
      ('fr', 'CA', null, 'fr'),
      ('ru', 'ZZ', null, 'ru'),
      ('sv', 'SE', null, 'en'),
      ('en', null, 'IR', 'fa'),
      ('en', 'IR', 'DE', 'fa'),
      ('en', null, null, 'en'),
    ];

    for (final (language, region, ip, expected) in cases) {
      test('$language-$region with backend $ip gives $expected', () {
        expect(resolve(language, region, ip: ip, sim: null), expected);
        expect(
          LocaleSuggestion.resolve(
            deviceLocale: Locale.fromSubtags(
              languageCode: language,
              countryCode: region,
            ),
            supported: supported,
            ipCountry: ip,
          ),
          expected,
        );
      });
    }

    test('no locale and no SIM lands on English', () {
      expect(resolve(null, null, sim: null), 'en');
    });
  });

  group('region leads', () {
    test('Iran offers Persian even on an English phone', () {
      expect(resolve('en', 'IR'), 'fa');
    });

    test('Saudi Arabia offers Arabic even on an English phone', () {
      expect(resolve('en', 'SA'), 'ar');
    });

    test('Turkey offers Turkish', () => expect(resolve('en', 'TR'), 'tr'));
    test('Germany offers German', () => expect(resolve('en', 'DE'), 'de'));
    test('Brazil offers Portuguese', () => expect(resolve('en', 'BR'), 'pt'));
    test('Japan offers Japanese', () => expect(resolve('en', 'JP'), 'ja'));
    test('Pakistan offers Urdu', () => expect(resolve('en', 'PK'), 'ur'));
    test(
      'Indonesia offers Indonesian',
      () => expect(resolve('en', 'ID'), 'id'),
    );
    test('China offers Chinese', () => expect(resolve('en', 'CN'), 'zh'));
    test('Ukraine offers Ukrainian', () => expect(resolve('en', 'UA'), 'uk'));
    test('Vietnam offers Vietnamese', () => expect(resolve('en', 'VN'), 'vi'));
    test('Mexico offers Spanish', () => expect(resolve('en', 'MX'), 'es'));
    test('Spain offers Spanish', () => expect(resolve('en', 'ES'), 'es'));

    test('Uzbekistan offers Uzbek, no longer Russian', () {
      expect(resolve('en', 'UZ'), 'uz');
      expect(resolve('ru', 'UZ'), 'uz');
    });

    test('the other Russian-speaking countries still offer Russian', () {
      for (final country in ['KZ', 'KG', 'TJ', 'TM', 'BY', 'AM', 'MD']) {
        expect(resolve('en', country), 'ru', reason: country);
      }
    });

    test('every Spanish-speaking country in the list offers Spanish', () {
      const countries = [
        'MX', 'ES', 'AR', 'CO', 'PE', 'VE', 'CL', 'EC', 'GT', 'CU', 'BO', //
        'DO', 'HN', 'PY', 'SV', 'NI', 'CR', 'PA', 'UY', 'PR', 'GQ',
      ];
      for (final country in countries) {
        expect(resolve('en', country), 'es', reason: country);
      }
    });

    test('Afghanistan offers Persian', () {
      expect(resolve('en', 'AF'), 'fa');
    });
  });

  group('the phone language is the fallback', () {
    test('Canada offers English on an English phone', () {
      expect(resolve('en', 'CA'), 'en');
    });

    test('Canada offers French on a French phone', () {
      // Quebec is the reason region alone is not enough. CA maps to
      // nothing, so the phone's own language decides.
      expect(resolve('fr', 'CA'), 'fr');
    });

    test('an unmapped country falls through to the phone language', () {
      expect(resolve('ru', 'ZZ'), 'ru');
    });

    test('a phone language we do not ship lands on English', () {
      expect(resolve('sv', 'SE'), 'en');
    });
  });

  group('the backend country is the last resort', () {
    test('used when the phone has no region', () {
      expect(resolve('en', null, ip: 'IR'), 'fa');
    });

    test('ignored when the phone region already answered', () {
      // A tunnel that is already up makes the IP country the exit
      // server's, so it must never override a region we trust more.
      expect(resolve('en', 'IR', ip: 'DE'), 'fa');
    });

    test('an unknown backend country changes nothing', () {
      expect(resolve('en', null, ip: null), 'en');
    });
  });

  group('nothing to go on', () {
    test('no locale at all lands on English', () {
      expect(resolve(null, null), 'en');
    });
  });

  group('forCountry', () {
    test('is case insensitive', () {
      expect(LocaleSuggestion.forCountry('ir'), 'fa');
      expect(LocaleSuggestion.forCountry('IR'), 'fa');
    });

    test('rejects anything that is not a two-letter code', () {
      expect(LocaleSuggestion.forCountry(null), isNull);
      expect(LocaleSuggestion.forCountry(''), isNull);
      expect(LocaleSuggestion.forCountry('IRN'), isNull);
    });

    test('returns null for a country with no strong signal', () {
      expect(LocaleSuggestion.forCountry('CA'), isNull);
      expect(LocaleSuggestion.forCountry('US'), isNull);
      expect(LocaleSuggestion.forCountry('GB'), isNull);
    });

    test('every mapped language is one the app actually ships', () {
      // A map entry pointing at a language with no translations would
      // hand someone an untranslated app on their very first screen.
      for (final country in [
        'IR',
        'SA',
        'TR',
        'UZ',
        'CN',
        'UA',
        'VN',
        'ID',
        'MX',
      ]) {
        expect(supported, contains(LocaleSuggestion.forCountry(country)));
      }
    });
  });

  group('needsCountryLookup', () {
    test('is false when the phone region already answered', () {
      // No point spending a round trip, and behind a national firewall
      // that request may not answer at all.
      expect(
        LocaleSuggestion.needsCountryLookup(
          deviceLocale: Locale.fromSubtags(
            languageCode: 'en',
            countryCode: 'IR',
          ),
          supported: supported,
        ),
        isFalse,
      );
    });

    test('is true when the phone region maps to nothing', () {
      expect(
        LocaleSuggestion.needsCountryLookup(
          deviceLocale: Locale.fromSubtags(
            languageCode: 'en',
            countryCode: 'CA',
          ),
          supported: supported,
        ),
        isTrue,
      );
    });

    test('is true when the phone has no region', () {
      expect(
        LocaleSuggestion.needsCountryLookup(
          deviceLocale: const Locale('en'),
          supported: supported,
        ),
        isTrue,
      );
    });

    test('is false when the SIM gives a language the app ships', () {
      expect(needsLookup('en', 'US', sim: 'ir'), isFalse);
      expect(needsLookup('en', null, sim: 'tr'), isFalse);
    });

    test('is true when neither the SIM nor the region gives one', () {
      expect(needsLookup('en', 'US', sim: 'us'), isTrue);
      expect(needsLookup('en', null, sim: 'us'), isTrue);
      expect(needsLookup('en', 'CA', sim: ''), isTrue);
      expect(needsLookup('en', 'CA'), isTrue);
    });

    test('is false when the SIM says nothing but the region does', () {
      expect(needsLookup('en', 'IR', sim: 'us'), isFalse);
      expect(needsLookup('en', 'IR'), isFalse);
    });

    test('ignores the SIM on a phone in a shipped non-English language', () {
      expect(needsLookup('de', 'US', sim: 'ir'), isTrue);
      expect(needsLookup('fa', null, sim: 'tr'), isTrue);
      expect(needsLookup('fa', 'IR', sim: 'tr'), isFalse);
    });

    test('is true when the SIM language is not shipped', () {
      expect(
        LocaleSuggestion.needsCountryLookup(
          deviceLocale: const Locale('en', 'US'),
          supported: const ['en', 'tr'],
          simCountry: 'ir',
        ),
        isTrue,
      );
    });
  });
}
