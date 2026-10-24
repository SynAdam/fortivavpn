import '../data/models/server.dart';
import 'vless_link.dart';

/// The host a link dials, without the port.
///
/// Its own file so the flow and the sweep can both name hosts in
/// reports without importing each other.
class VlessLinkHost {
  const VlessLinkHost._();

  /// Read from the link, not from [Server.pathKey]: the key names the
  /// server the link reaches, and a report names the address it dialled.
  static String of(Server s) => VlessLink.hostname(s.connectionUri);
}
