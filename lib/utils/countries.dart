import '../data/country_names.dart';

/// Country names in the app's languages, from the CLDR tables in
/// countryNameTables.
///
/// The app used to hold 56 English names. Every other code showed as two
/// bare letters (BY, PE, IQ), and a Persian or German screen showed
/// "United States". The tables cover every ISO 3166-1 alpha-2 code and XK
/// in each of the app's 18 languages.
abstract final class CountryNames {
  /// The language a name falls back to when the app's language has no
  /// table.
  static const fallbackLanguage = 'en';

  /// Never shown as a server's country: Iran. A server at an Iranian
  /// address is a relay whose exit the app cannot place, and the backend
  /// never labels a link with it either.
  static const neverAServerCountry = {'IR'};

  static Map<String, String> get _english =>
      countryNameTables[fallbackLanguage]!;

  /// Whether [code] is a country's code the tables name, in any case.
  static bool isCountry(String code) =>
      _english.containsKey(code.toUpperCase());

  /// Whether [code] may be shown as the country a server is in: a country
  /// the tables name, other than Iran.
  static bool isServerCountry(String code) {
    final upper = code.toUpperCase();
    return _english.containsKey(upper) && !neverAServerCountry.contains(upper);
  }

  /// The name of [code] in [language] (a language code such as `fa`), in
  /// English when the app has no table for [language]. Null when [code]
  /// is no country the tables name.
  static String? nameOf(String code, String language) {
    final table = countryNameTables[language] ?? _english;
    return table[code.toUpperCase()];
  }

  /// The code of an English country name the app stored earlier, such as a
  /// community link's name in the session log. Covers the CLDR names and
  /// the one name earlier versions stored differently ("Turkey"). Null for
  /// any other text.
  static String? codeOfEnglishName(String name) => _byEnglishName[name];

  static final Map<String, String> _byEnglishName = {
    for (final entry in _english.entries) entry.value: entry.key,
    'Turkey': 'TR',
  };
}
