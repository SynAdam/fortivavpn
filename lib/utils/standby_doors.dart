import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/models/server.dart';
import 'shared_link.dart';
import 'vless_link.dart';
import 'vless_link_host.dart';

/// The doors the core holds next to the one it dials.
///
/// A tunnel through one door ends when that door is blocked, and the user
/// has to tap connect again and wait for a new search. With standby doors
/// the core moves a failed connection to the next door by itself, and sends
/// new ones through whichever door is healthy.
///
/// The backend turns it on in its remote config with `standby_doors`. Only
/// on Android and Windows, whose cores have the group that does this.
class StandbyDoors {
  StandbyDoors._();

  /// From remote config: the last one that landed, in this run of the app
  /// or an earlier one (AppConfigState). Off on a phone the backend has
  /// never answered.
  static bool enabled = false;

  /// Stands in for the platform check in tests, which run on a desktop.
  @visibleForTesting
  static bool? androidOverride;

  /// The most doors held next to the dialled one. Each costs a small probe
  /// every few minutes while the tunnel carries traffic, so the list is
  /// short. The Android and Windows cores enforce the same number.
  static const max = 4;

  /// The doors to hold next to [dialled], out of [paths], best first.
  ///
  /// Other doors of the same server come first, so a failover keeps the
  /// user on the server they chose when it can. They get at most [max] - 1
  /// slots when [paths] has a door of another server, and that door gets
  /// the last one, because a server that goes down takes all its doors
  /// with it. With five doors per server (two IPv4 addresses, one IPv6
  /// address and two Cloudflare doors) the dialled server alone would fill
  /// the group. Without another server, its own doors may take every slot.
  ///
  /// The dialled server's doors are ordered by address (see [_ownInOrder]),
  /// because a censor blocks an address and every door dialled at it fails
  /// together. Other servers' doors keep the order [paths] has them in,
  /// which is the backend's order for this carrier.
  ///
  /// When [ipv6] is false the phone has no IPv6 on this network, and doors
  /// dialled at an IPv6 address are left out. TCI home wifi has none, and
  /// such a door fails every check there with "tcp unreachable" while it
  /// takes a slot from a door that could carry the tunnel.
  ///
  /// [closed] holds the path keys of the doors the dial's own tap just
  /// found closed. They go after every other door, on the dialled server
  /// and among the rest, so they take a slot only when nothing else is
  /// left. Until 2.2.0 they took slots in the backend's order: a tap that
  /// found a server's other doors closed and dialled the one open door
  /// held those closed doors as its spares, and when that door was blocked
  /// later in the session the core had nowhere to go. A closed door is
  /// still better than an empty slot: a check can fail on a door the
  /// tunnel would carry, and the core measures its spares itself.
  ///
  /// Empty when the feature is off, on iOS, or when [dialled]
  /// is a shared or community link: those are not ours, and our doors are
  /// not a fallback the user asked for.
  static List<Server> pick(
    Server dialled,
    List<Server> paths, {
    bool? android,
    bool ipv6 = true,
    Set<String> closed = const {},
  }) {
    // Windows' core holds a door group as Android's does: the same
    // autoselect outbound, built from the same connect arguments.
    final onAndroid =
        android ??
        androidOverride ??
        (Platform.isAndroid || Platform.isWindows);
    if (!enabled || !onAndroid) return const [];
    if (dialled.door == null) return const [];

    final seen = <String>{dialled.pathKey};
    final own = <Server>[];
    final rest = <Server>[];
    for (final path in paths) {
      if (path.door == null || !seen.add(path.pathKey)) continue;
      if (!ipv6 && dialsIpv6(path)) continue;
      (path.sameServerAs(dialled) ? own : rest).add(path);
    }
    final ownSlots = rest.isEmpty ? max : max - 1;
    return [
      ..._closedLast(_ownInOrder(dialled, own), closed).take(ownSlots),
      ..._closedLast(rest, closed),
    ].take(max).toList();
  }

  /// [doors] in their order, with the ones in [closed] moved after the rest.
  static List<Server> _closedLast(List<Server> doors, Set<String> closed) {
    if (closed.isEmpty) return doors;
    return [
      for (final d in doors)
        if (!closed.contains(d.pathKey)) d,
      for (final d in doors)
        if (closed.contains(d.pathKey)) d,
    ];
  }

  /// The shared links to hold next to [dialled], a shared link the connect
  /// flow fell back on: the first [count] of [spares] that are not
  /// [dialled] and that the core can dial, at most [max] - 1.
  ///
  /// [pick] holds none next to a shared link, and a community link that
  /// died in the middle of a session ended the tunnel: community links
  /// live for hours, not days. These spares are links the same fallback
  /// found open, or had not reached yet, in its order, so the core moves
  /// to the next one by itself instead.
  ///
  /// Empty when the feature is off, on iOS, or with no [count].
  static List<Server> shared(
    Server dialled,
    List<Server> spares, {
    required int? count,
    bool? android,
  }) {
    final onAndroid =
        android ??
        androidOverride ??
        (Platform.isAndroid || Platform.isWindows);
    if (!enabled || !onAndroid || count == null || count <= 0) {
      return const [];
    }
    final seen = <String>{dialled.pathKey};
    return [
      for (final s in spares)
        if (!s.isDedicated &&
            SharedLink.usable(s.connectionUri) &&
            seen.add(s.pathKey))
          s,
    ].take(count < max ? count : max - 1).toList();
  }

  /// Whether [door] is dialled at an IPv6 address, such as the backend's
  /// "-v6" doors. Read from the link, not the door id.
  static bool dialsIpv6(Server door) =>
      InternetAddress.tryParse(VlessLinkHost.of(door))?.type ==
      InternetAddressType.IPv6;

  /// The dialled server's other doors, in the order they get its slots.
  ///
  /// 1. The dialled door at another address of the same family: the "-b"
  ///    copy when the first IPv4 door is dialled, and that door when the
  ///    copy is. When the dialled address is blocked in the middle of a
  ///    session, the core moves to the same server at its other address,
  ///    and the user's traffic keeps the same exit.
  /// 2. Each other door dialled at an address that no door before it is
  ///    dialled at, in the order of [own]: a Cloudflare door, the IPv6 copy.
  /// 3. The doors dialled at an address the group already holds. The second
  ///    Cloudflare door is one: every Cloudflare door is dialled at the same
  ///    Cloudflare address.
  static List<Server> _ownInOrder(Server dialled, List<Server> own) {
    final copies = <Server>[];
    final others = <Server>[];
    for (final door in own) {
      (_sameDoorElsewhere(door, dialled) ? copies : others).add(door);
    }
    final held = {VlessLinkHost.of(dialled)};
    final fresh = <Server>[];
    final again = <Server>[];
    for (final door in [...copies, ...others]) {
      (held.add(VlessLinkHost.of(door)) ? fresh : again).add(door);
    }
    return [...fresh, ...again];
  }

  /// Whether [door] is [dialled] at another address: the same settings
  /// ([VlessLink.strategy] leaves out the address and the credential), a
  /// different address, and both IPv4 or both IPv6.
  static bool _sameDoorElsewhere(Server door, Server dialled) =>
      VlessLinkHost.of(door) != VlessLinkHost.of(dialled) &&
      dialsIpv6(door) == dialsIpv6(dialled) &&
      mapEquals(
        VlessLink.strategy(door.connectionUri),
        VlessLink.strategy(dialled.connectionUri),
      );
}
