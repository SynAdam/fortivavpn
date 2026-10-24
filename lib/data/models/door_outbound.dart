import 'dart:convert';

import 'package:flutter/foundation.dart';

/// The backend's own outbound for one of this phone's doors: `outbound` and
/// `helper_outbounds` of a door entry in the /configs/dedicated answer
/// (variant loop contract v2, section 2).
///
/// With it the backend can serve any protocol and setting the core
/// supports without an app release. The Android side dials a door that has
/// one with this JSON as it came, wherever it would build an outbound from
/// the door's link: the tunnel, the doors that stand by in it, and door
/// checks (android handler/DoorOutbounds.kt). The link stays what the app
/// shows, keeps and logs.
///
/// A door without one is dialled from its link exactly as before.
class DoorOutbound {
  const DoorOutbound._(this.outbound, this.helpers);

  /// The outbound, as the backend wrote it.
  final Map<String, dynamic> outbound;

  /// The outbounds it refers to, such as the splitter tagged `fragment`.
  final List<Map<String, dynamic>> helpers;

  /// The app's own outbound tags, which a helper may not take: a helper
  /// under one would stand in for a door, or for the app's direct, block or
  /// DNS outbound.
  static bool _reserved(String tag) =>
      tag == 'proxy' ||
      tag.startsWith('proxy@') ||
      tag == 'direct' ||
      tag == 'block' ||
      tag == 'dns-out';

  /// The outbound of the door entry [json], or null when it has none or
  /// one the app cannot use: an outbound that is not an object, or has no
  /// tag or protocol, or helpers that are not a list of such objects, share
  /// a tag or take one of the app's own. An unusable one is logged, and the
  /// door is dialled from its link.
  static DoorOutbound? fromPath(Map<dynamic, dynamic> json) {
    final outbound = json['outbound'];
    if (outbound == null) return null;
    if (!_named(outbound)) return _unusable('no outbound object with a tag');
    final list = json['helper_outbounds'];
    if (list != null && list is! List) {
      return _unusable('helper_outbounds is not a list');
    }
    final helpers = <Map<String, dynamic>>[];
    final tags = <String>{};
    for (final helper in (list as List?) ?? const []) {
      if (!_named(helper)) return _unusable('a helper has no tag');
      final tag = (helper as Map)['tag'] as String;
      if (_reserved(tag)) return _unusable('a helper takes an app tag');
      if (!tags.add(tag)) return _unusable('two helpers share a tag');
      helpers.add(Map<String, dynamic>.from(helper));
    }
    return DoorOutbound._(Map<String, dynamic>.from(outbound as Map), helpers);
  }

  static bool _named(Object? o) =>
      o is Map && _text(o['tag']) && _text(o['protocol']);

  static bool _text(Object? v) => v is String && v.trim().isNotEmpty;

  static DoorOutbound? _unusable(String why) {
    debugPrint('DoorOutbound: the backend\'s outbound cannot be used ($why)');
    return null;
  }

  /// What the native side takes for this door, as JSON text.
  String get native =>
      jsonEncode({'outbound': outbound, 'helper_outbounds': helpers});
}

/// The outbounds of this phone's doors, by the door's link as the backend
/// sent it. DedicatedState sets them each time it takes in the doors, as it
/// sets TlsFragment.doorSpec.
class DoorOutbounds {
  DoorOutbounds._();

  static Map<String, DoorOutbound> _byLink = const {};

  /// Takes in the outbounds of the latest doors, dropping the rest.
  static void adopt(Map<String, DoorOutbound> byLink) =>
      _byLink = Map.unmodifiable(byLink);

  /// What the native side takes for the door whose link is [link], dialled
  /// as [sent], or null to dial the link.
  ///
  /// Null unless the app dials the link as the backend wrote it. A link the
  /// app rewrites before it dials (TlsFragment.apply adds the app's split
  /// to a TLS link that names none) is not the link the outbound was built
  /// from, so it is dialled as before.
  static String? nativeFor(String link, String sent) =>
      sent == link ? _byLink[link]?.native : null;
}
