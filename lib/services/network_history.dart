import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What this phone saw of each network over time (backend issue #365,
/// items 3 and 9): when it first met the network, on how many days, and per
/// door when it last worked and last failed there.
///
/// The backend sees the checks a phone sends, but not the ones that never
/// arrived, which on a network that cuts us off are most of them, and it
/// cannot tell a network it has not seen from one the phone has known for
/// a month. So each check row says, from here: how long ago this phone
/// first met the network ([NetworkFacts.ageDays]), on how many days before
/// ([NetworkFacts.daysSeen]; 0 is a network it never met), and how long
/// ago this door last worked and last failed on it, and any door worked.
///
/// A mobile network is its carrier (`mobile:<carrier>`). A Wi-Fi network is
/// its key for the backend in this period (`wifi-period:<key>`, see
/// WifiKeys.shared), so its history starts again with every new key: the
/// backend gets one key per period, and nothing sent with it reaches back
/// to the period before, where it could join the two keys. So the age and
/// days of a Wi-Fi network count from the start of the period at most, and
/// a Wi-Fi network has facts only while the backend sets a period. A door is its server row and name (ConnectTrace.doorKey), or
/// its host and name when the row is not known. Everything stays on
/// the phone: only the counts and ages above are sent, never a key of this
/// store. At most [maxNetworks] networks and [maxDoors] doors per network
/// are kept, the least recent going first.
class NetworkHistory {
  NetworkHistory({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static final instance = NetworkHistory();

  static const storageKey = 'fortiva_network_history';

  /// The networks kept, and the doors kept per network.
  static const maxNetworks = 30;
  static const maxDoors = 40;

  /// The distinct days kept per network, newest first.
  static const visitsKept = 30;

  final DateTime Function() _now;

  /// The facts for each of [results] on [network] as they stood before
  /// this batch, in order. Then the batch is recorded: each door's result,
  /// and today as a day the network was seen.
  ///
  /// [keep], when given, is asked right before the batch is stored: a
  /// batch whose network key was made before an account deletion is not
  /// written after the deletion removed this store.
  Future<List<NetworkFacts>> factsThenNote(
    String network,
    List<({String door, bool ok})> results, {
    bool Function()? keep,
  }) async {
    final now = _now().toUtc();
    final all = await _load();
    final entry = Map<String, dynamic>.from(all[network] ?? const {});
    final first = _at(entry['first']);
    final days = _days(entry);
    final netOk = _at(entry['ok']);
    final doors = _doors(entry);
    final out = [
      for (final r in results)
        NetworkFacts(
          ageDays: first == null ? null : now.difference(first).inDays,
          daysSeen: days.length,
          doorOkSeconds: _ago(now, _at((doors[r.door] as Map?)?['ok'])),
          doorFailSeconds: _ago(now, _at((doors[r.door] as Map?)?['fail'])),
          networkOkSeconds: _ago(now, netOk),
        ),
    ];

    final stamp = now.toIso8601String();
    entry['first'] = (first ?? now).toIso8601String();
    entry['at'] = stamp;
    final today = _day(now);
    entry['days'] = [
      today,
      ...days.where((d) => d != today),
    ].take(visitsKept).toList();
    for (final r in results) {
      final door = Map<String, dynamic>.from(
        (doors[r.door] as Map?) ?? const {},
      );
      door[r.ok ? 'ok' : 'fail'] = stamp;
      doors[r.door] = door;
      if (r.ok) entry['ok'] = stamp;
    }
    entry['doors'] = _newest(doors, maxDoors);
    all[network] = entry;
    if (keep != null && !keep()) return out;
    await _store(Map.fromEntries(_newestEntries(all, maxNetworks)));
    return out;
  }

  /// Forget everything. Account deletion, and tests.
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (_) {}
  }

  static int? _ago(DateTime now, DateTime? at) {
    if (at == null) return null;
    final s = now.difference(at).inSeconds;
    return s < 0 ? 0 : s;
  }

  static DateTime? _at(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toUtc() : null;

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static List<String> _days(Map<String, dynamic> entry) {
    final raw = entry['days'];
    return raw is List ? raw.whereType<String>().toList() : <String>[];
  }

  static Map<String, dynamic> _doors(Map<String, dynamic> entry) {
    final raw = entry['doors'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  /// The [keep] doors used most lately: by their latest result.
  static Map<String, dynamic> _newest(Map<String, dynamic> doors, int keep) {
    DateTime last(Object? v) {
      final m = v is Map ? v : const {};
      final a = _at(m['ok']);
      final b = _at(m['fail']);
      if (a == null) return b ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (b == null) return a;
      return a.isAfter(b) ? a : b;
    }

    final sorted = doors.entries.toList()
      ..sort((x, y) => last(y.value).compareTo(last(x.value)));
    return Map.fromEntries(sorted.take(keep));
  }

  static Iterable<MapEntry<String, Map<String, dynamic>>> _newestEntries(
    Map<String, Map<String, dynamic>> all,
    int keep,
  ) {
    DateTime last(Map<String, dynamic> e) =>
        _at(e['at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final sorted = all.entries.toList()
      ..sort((x, y) => last(y.value).compareTo(last(x.value)));
    return sorted.take(keep);
  }

  Future<Map<String, Map<String, dynamic>>> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final e in decoded.entries)
          if (e.value is Map)
            e.key.toString(): Map<String, dynamic>.from(e.value as Map),
      };
    } catch (e) {
      debugPrint('NetworkHistory: could not read the history: $e');
      return {};
    }
  }

  Future<void> _store(Map<String, Map<String, dynamic>> all) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(all));
    } catch (e) {
      debugPrint('NetworkHistory: could not write the history: $e');
    }
  }
}

/// One check's network facts, as they stood before the check. See
/// [NetworkHistory].
@immutable
class NetworkFacts {
  const NetworkFacts({
    this.ageDays,
    this.daysSeen = 0,
    this.doorOkSeconds,
    this.doorFailSeconds,
    this.networkOkSeconds,
  });

  /// Whole days since the phone first met the network; null when it never
  /// had.
  final int? ageDays;

  /// On how many distinct days, of the last [NetworkHistory.visitsKept],
  /// the phone met the network before; 0 for a network it never met.
  final int daysSeen;

  /// Seconds since this door last worked, last failed, and since any door
  /// last worked, on this network. Null when it never did.
  final int? doorOkSeconds;
  final int? doorFailSeconds;
  final int? networkOkSeconds;

  /// The row keys the backend reads.
  /// Every key [toRow] can write, with `net_key`: what a door check row
  /// says about a network.
  static const rowKeys = [
    'net_key',
    'net_age_d',
    'net_days',
    'door_ok_s',
    'door_fail_s',
    'net_ok_s',
  ];

  Map<String, dynamic> toRow() => {
    'net_age_d': ?ageDays,
    'net_days': daysSeen,
    'door_ok_s': ?doorOkSeconds,
    'door_fail_s': ?doorFailSeconds,
    'net_ok_s': ?networkOkSeconds,
  };
}
