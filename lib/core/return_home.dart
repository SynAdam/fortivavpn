import 'package:flutter/widgets.dart';

/// Go back to the home screen after the user picked a server on a list.
///
/// Every server list calls this when a server is picked: Your servers, the
/// community list behind Shared servers, its search results and its
/// Fastest row. The home screen names the server in use and holds the
/// connect button, so a pick that leaves the user on the list looks like
/// it did nothing.
///
/// Every route above home is closed, not only the list. The community
/// list is opened from Your servers, and Your servers can be opened from
/// Settings, so a single pop left the user on another screen. Home is the
/// navigator's first route (MaterialApp.home in main.dart).
///
/// A snack bar shown before this call stays up on the home screen,
/// because the app has one ScaffoldMessenger above every route.
void returnHome(BuildContext context) {
  Navigator.of(context).popUntil((route) => route.isFirst);
}
