import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'network_keys.dart';
import 'path_memory.dart';
import 'tunnel_channels.dart';

/// One door check, reduced to what it says about IPv6: the address the
/// door dials, whether data came back, and the reason it failed.
typedef DoorReading = ({String host, bool ok, String? error});

/// Whether the phone can dial an IPv6 address on the network it is on.
///
/// The standby group leaves out the doors dialled at an IPv6 address when
/// it cannot (see StandbyDoors.pick). Two sources answer, and neither sends
/// anything over the network:
///
/// 1. The platform: on Android, whether the phone's network has a global
///    IPv6 address and an IPv6 default route ([platformRoute]).
/// 2. The last door checks on this network ([learn]). A door dialled at an
///    IPv6 address fails at once with "tcp unreachable" on a network with
///    no IPv6 route, as on a home line with no IPv6.
///
/// The platform answer is used when there is one, because it describes the
/// network the phone is on right now. The checks are kept per network key
/// ("wifi", "mobile:Irancell"), and every wifi network shares one key.
/// With neither, the answer is yes, which is what the app assumed before.
class Ipv6Reach {
  Ipv6Reach({Future<bool?> Function()? route, DateTime Function()? now})
    : _route = route ?? platformRoute,
      _now = now ?? DateTime.now;

  /// Where the last reading for each network is kept.
  static const storageKey = 'fortiva_ipv6_reach';

  /// How long a reading from door checks is trusted: as long as a
  /// remembered door is.
  static const fresh = PathMemory.fresh;

  /// How many networks keep a reading. The oldest goes first.
  static const maxNetworks = 20;

  final Future<bool?> Function() _route;
  final DateTime Function() _now;

  /// Whether doors dialled at an IPv6 address can work on [network].
  /// Never throws.
  Future<bool> usable(String network) async {
    try {
      final route = await _route();
      if (route != null) return route;
    } catch (e) {
      debugPrint('Ipv6Reach: route check failed: $e');
    }
    return await _recall(network) ?? true;
  }

  /// Keep what [checks] on [network] say about IPv6, when they say
  /// anything (see [fromChecks]). Never throws.
  Future<void> learn(String network, Iterable<DoorReading> checks) async {
    final works = fromChecks(checks);
    if (works == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = _decode(prefs.getString(storageKey));
      all.remove(network);
      all[network] = {'ok': works, 'at': _now().toUtc().toIso8601String()};
      while (all.length > maxNetworks) {
        all.remove(all.keys.first);
      }
      if (!NetworkKeys.mayKeep(network)) return;
      await prefs.setString(storageKey, jsonEncode(all));
    } catch (e) {
      debugPrint('Ipv6Reach: could not store a reading: $e');
    }
  }

  /// What door checks say about IPv6 on the network they ran on.
  ///
  /// Only checks of doors dialled at an IPv6 address count. True when one
  /// of them carried data, or its TCP connection got an answer or timed
  /// out: the phone had a route, whether or not the door was open. False
  /// when each of them that says how its TCP connection went says
  /// "unreachable": the phone has no route to an IPv6 address. Null when
  /// none of them says either.
  ///
  /// The reason starts with "tcp" and the outcome when the phone could tell
  /// (DoorCheckFailed in ping_service.dart).
  static bool? fromChecks(Iterable<DoorReading> checks) {
    bool? found;
    for (final check in checks) {
      if (InternetAddress.tryParse(check.host)?.type !=
          InternetAddressType.IPv6) {
        continue;
      }
      if (check.ok) return true;
      final tcp = _tcpOutcome.firstMatch(check.error ?? '')?.group(1);
      if (tcp == null) continue;
      if (tcp != 'unreachable') return true;
      found = false;
    }
    return found;
  }

  static final _tcpOutcome = RegExp(r'^tcp (\w+)');

  /// Asks the platform whether the phone's network has an IPv6 route.
  ///
  /// Only Android answers (MainActivity.ipv6Route). It reads the network's
  /// own settings and sends nothing. Null on other platforms, and when the
  /// platform cannot tell.
  static Future<bool?> platformRoute() async {
    if (!Platform.isAndroid) return null;
    try {
      return await TunnelChannels.method.invokeMethod<bool>('ipv6Route');
    } catch (_) {
      return null;
    }
  }

  Future<bool?> _recall(String network) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entry = _decode(prefs.getString(storageKey))[network];
      if (entry is! Map) return null;
      final ok = entry['ok'];
      final at = DateTime.tryParse(entry['at']?.toString() ?? '');
      if (ok is! bool || at == null) return null;
      if (_now().difference(at) > fresh) return null;
      return ok;
    } catch (e) {
      debugPrint('Ipv6Reach: could not read readings: $e');
      return null;
    }
  }

  static Map<String, dynamic> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
  }
}
