import 'dart:ui';

/// Picks the language to offer someone the first time they open the app.
///
/// This is a suggestion, never a decision. Whatever comes out of here is
/// the row that starts selected in the first-run picker, with every
/// language visible next to it. Getting it wrong costs one tap; getting
/// it right means a user in Tehran never has to read English to find
/// Persian.
///
/// On a phone set to English, or to a language the app does not ship, the
/// SIM card's country leads, then the phone's region. Many people in Iran
/// run their phone in English with the region set to the US or the UK, and
/// would still rather use the app in Persian. Their SIM still says Iran,
/// and another VPN does not change it.
///
/// A phone already set to a language the app ships, other than English,
/// keeps the answer it got before the SIM was read. The SIM is not used for
/// it, because its owner already picked a language we have. An Iranian in
/// Turkey with a phone in Persian and a Turkish SIM is offered Persian.
///
/// A country that maps to nothing falls through to the phone's language,
/// which is what keeps a French-speaking Canadian on French.
class LocaleSuggestion {
  LocaleSuggestion._();

  /// Countries where a language other than English is the obvious offer.
  ///
  /// Only non-English entries are listed. An unlisted country is not a
  /// gap: it means "no strong regional signal", and the phone's own
  /// language answers better than a map ever could.
  static const Map<String, String> _byCountry = {
    // Persian
    'IR': 'fa',
    'AF': 'fa', // Dari, close enough to read comfortably
    // Arabic
    'SA': 'ar', 'AE': 'ar', 'EG': 'ar', 'IQ': 'ar', 'JO': 'ar',
    'KW': 'ar', 'QA': 'ar', 'BH': 'ar', 'OM': 'ar', 'YE': 'ar',
    'SY': 'ar', 'LB': 'ar', 'LY': 'ar', 'DZ': 'ar', 'MA': 'ar',
    'TN': 'ar', 'SD': 'ar', 'PS': 'ar', 'MR': 'ar',

    // Turkish
    'TR': 'tr',

    // Russian, including the countries where it is the shared second
    // language rather than the first.
    'RU': 'ru', 'BY': 'ru', 'KZ': 'ru', 'KG': 'ru', 'TJ': 'ru',
    'TM': 'ru', 'AM': 'ru', 'MD': 'ru',

    // German
    'DE': 'de', 'AT': 'de', 'CH': 'de', 'LI': 'de',

    // French
    'FR': 'fr', 'BE': 'fr', 'LU': 'fr', 'MC': 'fr', 'SN': 'fr',
    'CI': 'fr', 'ML': 'fr', 'BF': 'fr', 'NE': 'fr', 'GN': 'fr',
    'CD': 'fr', 'CG': 'fr', 'GA': 'fr', 'CM': 'fr', 'MG': 'fr',
    'HT': 'fr',

    // Portuguese
    'PT': 'pt', 'BR': 'pt', 'AO': 'pt', 'MZ': 'pt', 'CV': 'pt',
    'GW': 'pt', 'ST': 'pt', 'TL': 'pt',

    // Spanish
    'ES': 'es', 'MX': 'es', 'AR': 'es', 'CO': 'es', 'PE': 'es', 'VE': 'es',
    'CL': 'es', 'EC': 'es', 'GT': 'es', 'CU': 'es', 'BO': 'es', 'DO': 'es',
    'HN': 'es', 'PY': 'es', 'SV': 'es', 'NI': 'es', 'CR': 'es', 'PA': 'es',
    'UY': 'es', 'PR': 'es', 'GQ': 'es',

    // The rest
    'JP': 'ja',
    'KR': 'ko', 'KP': 'ko',
    'IN': 'hi',
    'PK': 'ur',
    'ID': 'id',
    'CN': 'zh',
    'UA': 'uk',
    'UZ': 'uz',
    'VN': 'vi',
  };

  /// The language a country suggests, or null when it suggests nothing.
  static String? forCountry(String? countryCode) {
    if (countryCode == null || countryCode.length != 2) return null;
    return _byCountry[countryCode.toUpperCase()];
  }

  /// Resolve the language to pre-select, most trusted signal first.
  ///
  /// [simCountry] is the SIM card's country, null on a phone without one
  /// and on Windows and most TVs. A roaming SIM still names its home
  /// country, which is the language its owner reads. It is used only when
  /// [simLeads] is true for the phone. [deviceLocale] is the
  /// phone's own setting, which carries both a language and a region.
  /// [ipCountry] is what the backend saw the request arrive from, used
  /// only when the SIM and the phone's region say nothing: it costs a
  /// round trip, it is wrong whenever a tunnel is already up, and in the
  /// places this app matters most it may not answer at all.
  static String resolve({
    required Locale? deviceLocale,
    required Iterable<String> supported,
    String? simCountry,
    String? ipCountry,
  }) {
    final fromSim = _fromSim(deviceLocale, supported, simCountry);
    if (fromSim != null) return fromSim;

    final fromDeviceRegion = forCountry(deviceLocale?.countryCode);
    if (fromDeviceRegion != null && supported.contains(fromDeviceRegion)) {
      return fromDeviceRegion;
    }

    final fromIp = forCountry(ipCountry);
    if (fromIp != null && supported.contains(fromIp)) return fromIp;

    // No regional signal. The phone's own language is now the best thing
    // we have, and it is what keeps a French speaker in Canada on French.
    final deviceLanguage = deviceLocale?.languageCode;
    if (deviceLanguage != null && supported.contains(deviceLanguage)) {
      return deviceLanguage;
    }

    return 'en';
  }

  /// Whether the country lookup is worth making at all.
  ///
  /// Only when neither the SIM nor the phone's region told us anything.
  /// Everywhere else the answer is already known and a request that may
  /// hang for ten seconds behind a national firewall buys nothing.
  static bool needsCountryLookup({
    required Locale? deviceLocale,
    required Iterable<String> supported,
    String? simCountry,
  }) {
    if (_fromSim(deviceLocale, supported, simCountry) != null) return false;

    final fromDeviceRegion = forCountry(deviceLocale?.countryCode);
    return fromDeviceRegion == null || !supported.contains(fromDeviceRegion);
  }

  /// Whether the SIM card's country may lead for this phone.
  ///
  /// True when the phone has no locale, is set to English, or is set to a
  /// language the app does not ship. False when the phone is set to a
  /// shipped language other than English, so that phone keeps the answer
  /// its own settings give.
  static bool simLeads({
    required Locale? deviceLocale,
    required Iterable<String> supported,
  }) {
    final language = deviceLocale?.languageCode;
    return language == null ||
        language == 'en' ||
        !supported.contains(language);
  }

  /// The shipped language the SIM gives, or null when the SIM may not lead
  /// or gives nothing the app ships.
  static String? _fromSim(
    Locale? deviceLocale,
    Iterable<String> supported,
    String? simCountry,
  ) {
    if (!simLeads(deviceLocale: deviceLocale, supported: supported)) {
      return null;
    }
    final fromSim = forCountry(simCountry);
    if (fromSim == null || !supported.contains(fromSim)) return null;
    return fromSim;
  }
}
