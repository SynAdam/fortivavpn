import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/device_place.dart';
import '../../services/ip_info_service.dart';
import '../locale_suggestion.dart';

/// Provider that manages the app's locale (language) selection.
///
/// Persists the chosen locale to SharedPreferences and exposes the list
/// of supported locales that both the first-run picker and the Settings
/// picker read from.
class LocaleState extends ChangeNotifier {
  LocaleState({DevicePlace? place, Future<String?> Function()? backendCountry})
    : _place = place ?? DevicePlace(),
      _backendCountry = backendCountry ?? _fetchBackendCountry;

  static const String _prefLocale = 'pref_locale';

  /// Reads the SIM card's country for the first-run suggestion.
  final DevicePlace _place;

  /// Asks the backend which country it saw the request come from. Tests
  /// pass their own to check when the lookup is made.
  final Future<String?> Function() _backendCountry;

  /// Our own backend, which answers with the country it saw the request
  /// arrive from. Null on any failure, and every caller here treats this
  /// as a hint, so an absent answer is an absent hint.
  static Future<String?> _fetchBackendCountry() async {
    final info = await IpInfoService.fetchIpInfo();
    return info?.countryCode;
  }

  /// Where the chosen language's code is saved. Read by the background
  /// check for messages, which has no LocaleState.
  static const String prefKey = _prefLocale;

  Locale? _locale; // null = not chosen yet

  Locale? get locale => _locale;

  /// Whether the user has ever picked a language.
  ///
  /// This is what gates the first-run screen. It is deliberately not
  /// "is _locale null": a device that has chosen English is a device that
  /// has chosen, and it must never be asked again.
  bool _hasChosen = false;
  bool get hasChosen => _hasChosen;

  /// True until [loadLocale] has run, so the app does not flash the
  /// picker at someone who chose a language months ago.
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  /// Human-readable names for each supported locale, written in that
  /// language. A picker that lists "Persian" in English is useless to
  /// exactly the person who needs it.
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'de': 'Deutsch',
    'ja': '日本語',
    'ko': '한국어',
    'fr': 'Français',
    'ar': 'العربية',
    'ru': 'Русский',
    'fa': 'فارسی',
    'tr': 'Türkçe',
    'hi': 'हिन्दी',
    'ur': 'اردو',
    'pt': 'Português',
    'es': 'Español',
    'id': 'Bahasa Indonesia',
    'vi': 'Tiếng Việt',
    'uk': 'Українська',
    'uz': 'Oʻzbekcha',
    'zh': '简体中文',
  };

  /// All locales the app supports
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('de'),
    Locale('ja'),
    Locale('ko'),
    Locale('fr'),
    Locale('ar'),
    Locale('ru'),
    Locale('fa'),
    Locale('tr'),
    Locale('hi'),
    Locale('ur'),
    Locale('pt'),
    Locale('es'),
    Locale('id'),
    Locale('vi'),
    Locale('uk'),
    Locale('uz'),
    Locale('zh'),
  ];

  /// Load persisted locale on startup
  Future<void> loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefLocale);
      if (code != null && supportedLanguages.containsKey(code)) {
        _locale = Locale(code);
        _hasChosen = true;
      }
    } catch (_) {
      // A broken preference store must not stop the app launching. The
      // worst case is being asked for a language once more than needed.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get the current locale code string (e.g., 'en', 'fa')
  String get currentLocaleCode => _locale?.languageCode ?? 'en';

  /// The language to pre-select in the first-run picker.
  ///
  /// On a phone set to English or to a language the app does not ship,
  /// leads with the SIM card's country, then the phone's region, so
  /// someone in Iran running an English phone set to the US is offered
  /// Persian. A phone set to a shipped language other than English keeps
  /// the answer its own settings give. Falls back to the phone's language,
  /// which is what keeps a French speaker in Canada on French. Reaches for
  /// the backend's country only when the SIM and the phone's region say
  /// nothing, because that request costs a round trip and may not answer
  /// at all in the places this app matters most.
  Future<String> suggestedLanguage({Locale? deviceLocale}) async {
    final device = deviceLocale ?? _platformLocale();
    final supported = supportedLanguages.keys;
    final simCountry = await _place.simCountry();

    String? ipCountry;
    if (LocaleSuggestion.needsCountryLookup(
      deviceLocale: device,
      supported: supported,
      simCountry: simCountry,
    )) {
      ipCountry = await _backendCountry();
    }

    return LocaleSuggestion.resolve(
      deviceLocale: device,
      supported: supported,
      simCountry: simCountry,
      ipCountry: ipCountry,
    );
  }

  Locale? _platformLocale() {
    try {
      return WidgetsBinding.instance.platformDispatcher.locale;
    } catch (_) {
      return null;
    }
  }

  /// Set a new locale and persist it.
  ///
  /// Records that a choice was made even when the language is unchanged,
  /// because confirming the suggested language on the first-run screen is
  /// still a choice and must stop the app asking again.
  Future<void> setLocale(Locale newLocale) async {
    _locale = newLocale;
    _hasChosen = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLocale, newLocale.languageCode);
    } catch (_) {
      // The language still applies for this session; it just will not
      // survive a relaunch. Better than refusing to switch at all.
    }
  }

  /// Reset to system default
  Future<void> resetToSystem() async {
    _locale = null;
    _hasChosen = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefLocale);
    } catch (_) {
      // Ignored for the same reason as above.
    }
  }
}
