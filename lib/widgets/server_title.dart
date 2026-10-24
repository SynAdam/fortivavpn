import 'package:flutter/widgets.dart';

import '../data/models/server.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/number_localizer.dart';

/// What a tile, a toast, a checklist row or the home card calls a server.
///
/// One of ours, or this device's own, goes by its name. A community link
/// goes by its country when the link says one, and otherwise by its number
/// in the list, in the phone's language. Never by the label of whoever
/// posted it, and never by its host: neither says anything a user can act
/// on, and both say more than a screen should. The backup network goes by
/// what it is, in the phone's language.
String serverTitle(BuildContext context, Server server) {
  if (server.isPsiphon) return S.of(context)!.backupNetworkTitle;
  if (!server.isCommunity || server.country.isNotEmpty) return server.name;
  return _numbered(context, server.communityNumber);
}

/// [serverTitle] for a name that was saved earlier, such as a session in
/// the activity list: a stored "Community 3" or backup network is shown in
/// the phone's language, any other name as it is.
String storedServerTitle(BuildContext context, String name) {
  if (name == Server.psiphonName) return S.of(context)!.backupNetworkTitle;
  final number = Server.communityNumberOf(name);
  return number == null ? name : _numbered(context, number);
}

String _numbered(BuildContext context, int number) {
  final digits = NumberLocalizer.localize('$number', context);
  return S.of(context)!.communityServerNumber(digits);
}
