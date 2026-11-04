import 'package:flutter/widgets.dart';

import '../data/models/server.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/countries.dart';
import '../utils/number_localizer.dart';

/// What a tile, a toast, a checklist row or the home card calls a server.
///
/// One of ours, or this device's own, goes by its name. A community link
/// goes by its country when the link says one, and otherwise by its number
/// in the list, both in the phone's language. Never by the label of whoever
/// posted it, and never by its host: neither says anything a user can act
/// on, and both say more than a screen should. The backup network goes by
/// what it is, in the phone's language.
String serverTitle(BuildContext context, Server server) {
  if (server.isPsiphon) return S.of(context)!.backupNetworkTitle;
  if (!server.isCommunity) return server.name;
  final country = serverCountry(context, server);
  if (country.isNotEmpty) return country;
  return _numbered(context, server.communityNumber);
}

/// The country [server] is in, in the app's language (Server.countryIn).
/// Empty when it names none.
String serverCountry(BuildContext context, Server server) =>
    server.countryIn(appLanguage(context));

/// The language the app is shown in, as a language code such as `fa`.
String appLanguage(BuildContext context) =>
    Localizations.localeOf(context).languageCode;

/// [serverTitle] for a name that was saved earlier, such as a session in
/// the activity list: a stored "Community 3" or backup network is shown in
/// the phone's language, and so is a community link's country, which is
/// stored in English. Any other name is shown as it is.
String storedServerTitle(BuildContext context, String name) {
  if (name == Server.psiphonName) return S.of(context)!.backupNetworkTitle;
  final number = Server.communityNumberOf(name);
  if (number != null) return _numbered(context, number);
  final code = CountryNames.codeOfEnglishName(name);
  if (code == null || !CountryNames.isServerCountry(code)) return name;
  return CountryNames.nameOf(code, appLanguage(context)) ?? name;
}

String _numbered(BuildContext context, int number) {
  final digits = NumberLocalizer.localize('$number', context);
  return S.of(context)!.communityServerNumber(digits);
}
