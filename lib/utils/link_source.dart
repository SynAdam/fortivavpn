import '../data/models/server.dart';
import 'link_id.dart';
import 'vless_link.dart';

/// Where the link an attempt dials came from, as the `src` of its
/// strategy says it.
///
/// The backend cannot tell from a connect event whether the user chose a
/// community link or the fallback dialled one after our own doors failed,
/// and the two answer different questions: a pick says what users reach
/// for, a fallback says what is left when everything of ours is blocked.
enum LinkSource {
  /// One of this device's own doors.
  own('own'),

  /// A shared link from our own official list.
  officialShared('official_shared'),

  /// A community link the user chose, or the one the app kept as the
  /// selection after a fallback and the user then connected through.
  communityPick('community_pick'),

  /// A community link the connect flow dialled on its own, after none of
  /// this device's doors carried a tunnel.
  communityFallback('community_fallback'),

  /// The backup network (Server.psiphon), which the connect flow dials by
  /// itself once nothing else connected. Not a link of ours: the backend
  /// files its sessions in a pool of their own.
  psiphon('psiphon');

  const LinkSource(this.wire);

  /// What the strategy carries.
  final String wire;

  /// Where [server] came from, when the caller says nothing more. A
  /// community link dialled this way is one the user chose.
  static LinkSource of(Server server) {
    if (server.isPsiphon) return psiphon;
    if (server.isDedicated || server.door != null) return own;
    if (server.isCommunity) return communityPick;
    return officialShared;
  }

  /// The strategy of an attempt that dials [server] as [dialled] (the link
  /// with the app's own changes applied, see TlsFragment): `src`, then for
  /// a community link its `lid`, then [VlessLink.strategy].
  ///
  /// The two come first because the backend keeps only the first 24 keys,
  /// and [VlessLink.strategy] has at most 18. The lid is read from the link
  /// as the list gave it, not from [dialled], so it matches the one the
  /// backend computes from the same list.
  ///
  /// The backup network has no link to read: its strategy is `src` and
  /// `egress`, the region its traffic leaves from, empty until the tunnel
  /// says (VpnService).
  Map<String, dynamic> strategy(Server server, String dialled) =>
      this == psiphon || server.isPsiphon
      ? {'src': psiphon.wire, 'egress': ''}
      : {
          'src': wire,
          if (server.isCommunity) 'lid': LinkId.of(server.connectionUri),
          ...VlessLink.strategy(dialled),
        };
}
