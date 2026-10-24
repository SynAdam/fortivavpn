import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/checklist_settings.dart';
import 'network_keys.dart';

/// What this phone learned about which door works on which network.
///
/// A diagnosis costs the user fifteen seconds of watching a checklist, so
/// the app avoids one whenever it can. The way it avoids one is memory:
/// the last door that carried traffic on this network is tried first, with
/// no checks at all, and only when that fails does the checklist appear.
///
/// Memory is per network, not per phone. A phone on Irancell at work and
/// on home wifi at night keeps two entries, because the door that is open
/// on one is routinely blocked on the other. The key is whatever
/// [ConnectFlow] can read about the network: the transport and the carrier.
///
/// Alongside the remembered door, a count of how many times each door
/// failed today on this network. A door that failed three times is skipped
/// in the next diagnosis and tried again tomorrow, so a censor's morning
/// does not cost every connect of the day three seconds. The backend can
/// set both numbers instead ([SkipSettings]), and then the skip ends a set
/// time after the door's latest failure.
///
/// The skip never hides the only door that ever carried traffic on this
/// network (see [skippable]), and the doors the background sweep found
/// open are kept for the checklist's last pass (see [sweptOpen]).
class PathMemory {
  PathMemory({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const storageKey = 'fortiva_path_memory';

  /// How long a remembered door is trusted without a fresh check.
  static const fresh = Duration(hours: 24);

  /// Failures on one network before a door is skipped for the day.
  static const maxFailsPerDay = 3;

  /// The networks kept. With a key per Wi-Fi network (NetworkKeys) a phone
  /// can meet many; the ones it met least lately go first.
  static const maxNetworks = 40;

  final DateTime Function() _now;

  /// The door to try first on [network], or null when there is nothing
  /// worth trusting: no memory, or one older than [fresh].
  ///
  /// A Wi-Fi network that this phone has no fresh memory of gets the
  /// newest door another Wi-Fi network remembers. That covers a network
  /// with a key of its own (`wifi:<key>`, see NetworkKeys) and the plain
  /// "wifi" of older builds and of a phone whose key cannot be read. That
  /// is what it got when every Wi-Fi network shared one entry, so a new
  /// network's first tap is no worse than before, and a known one's is
  /// better: it starts from its own door. A door that already failed on
  /// [network] since the other network remembered it is not lent again:
  /// the failure is written to [network] only, so the door stays fresh
  /// where it came from.
  Future<String?> recall(String network) async {
    final all = await _load();
    final own = _fresh(all[network]);
    if (own != null || !_isWifi(network)) return own?.$1;
    final entry = all[network] ?? const <String, dynamic>{};
    final here = _failsOf(entry);
    (String, DateTime)? best;
    for (final e in all.entries) {
      if (e.key == network || !_isWifi(e.key)) continue;
      final found = _fresh(e.value);
      if (found == null || _failedSince(here[found.$1], found.$2)) continue;
      // Nor one forgotten here since ([forget]).
      if (_forgotSince(entry, found.$1, found.$2)) continue;
      if (best == null || found.$2.isAfter(best.$2)) best = found;
    }
    return best?.$1;
  }

  static bool _isWifi(String network) =>
      network == 'wifi' || network.startsWith('wifi:');

  /// Whether [entry], one network's memory, forgot [pathKey] at or after
  /// [since] ([forget]).
  static bool _forgotSince(
    Map<String, dynamic> entry,
    String pathKey,
    DateTime since,
  ) {
    final forgot = entry['forgot'];
    if (forgot is! Map || forgot['key'] != pathKey) return false;
    final at = DateTime.tryParse(forgot['at']?.toString() ?? '');
    return at != null && !at.isBefore(since);
  }

  /// Whether [fail], one door's failure record, came at or after [since].
  /// A record from before failures had a time counts when it is today's.
  bool _failedSince(Object? fail, DateTime since) {
    if (fail is! Map) return false;
    final at = DateTime.tryParse(fail['at']?.toString() ?? '');
    if (at != null) return !at.isBefore(since);
    return fail['day'] == _today();
  }

  /// The remembered door of [entry] and when it carried traffic, when that
  /// is within [fresh].
  (String, DateTime)? _fresh(Map<String, dynamic>? entry) {
    if (entry == null) return null;
    final key = entry['key'];
    final at = DateTime.tryParse(entry['at']?.toString() ?? '');
    if (key is! String || key.isEmpty || at == null) return null;
    if (_now().difference(at) > fresh) return null;
    return (key, at);
  }

  /// Record that [pathKey] carried traffic on [network] just now. Clears
  /// the day's failure count for it: a door that works is not a door that
  /// failed.
  ///
  /// Also adds it to the doors that ever carried traffic on [network],
  /// which [skippable] reads. [holding] is every door the phone holds now.
  /// When it is given, doors outside it leave that record: they are doors
  /// the backend no longer gives, such as a door at an address that was
  /// replaced, and the record would otherwise grow with every address the
  /// phone ever used.
  Future<void> remember(
    String network,
    String pathKey, {
    Iterable<String>? holding,
  }) async {
    final all = await _load();
    final entry = Map<String, dynamic>.from(all[network] ?? const {});
    final now = _now().toUtc().toIso8601String();
    entry['key'] = pathKey;
    entry['at'] = now;
    final fails = _failsOf(entry);
    fails.remove(pathKey);
    entry['fails'] = fails;
    final held = holding?.toSet();
    final carried = _carriedOf(entry)
      ..removeWhere((key, _) => held != null && !held.contains(key))
      ..[pathKey] = now;
    entry['carried'] = carried;
    all[network] = entry;
    if (!NetworkKeys.mayKeep(network)) return;
    await _store(all);
  }

  /// Make [pathKey] the door to try first on [network], as [recall] gives
  /// it, without saying it carried traffic: its failures and the doors that
  /// carried traffic stay as they are. For a door a check found faster than
  /// the one a throttled tunnel is on (ConnectFlow.preferDoor). The fast
  /// path dials it next, and a dial that fails forgets it as any does.
  Future<void> prefer(String network, String pathKey) async {
    final all = await _load();
    final entry = Map<String, dynamic>.from(all[network] ?? const {});
    entry['key'] = pathKey;
    entry['at'] = _now().toUtc().toIso8601String();
    all[network] = entry;
    if (!NetworkKeys.mayKeep(network)) return;
    await _store(all);
  }

  /// The shared link that last carried traffic on [network], or null.
  ///
  /// Kept apart from [recall]: that one is the device's own door, which
  /// the fast path dials, and a shared link must never take its place.
  /// This one is only read when every own door failed, to pick the shared
  /// link worth trying first.
  Future<String?> recallShared(String network) async {
    final shared = (await _load())[network]?['shared'];
    if (shared is! Map) return null;
    final key = shared['key'];
    final at = DateTime.tryParse(shared['at']?.toString() ?? '');
    if (key is! String || key.isEmpty || at == null) return null;
    if (_now().difference(at) > fresh) return null;
    return key;
  }

  /// Record that the shared link [pathKey] carried traffic on [network].
  Future<void> rememberShared(String network, String pathKey) async {
    final all = await _load();
    final entry = Map<String, dynamic>.from(all[network] ?? const {});
    entry['shared'] = {'key': pathKey, 'at': _now().toUtc().toIso8601String()};
    final fails = _failsOf(entry);
    fails.remove(pathKey);
    entry['fails'] = fails;
    all[network] = entry;
    if (!NetworkKeys.mayKeep(network)) return;
    await _store(all);
  }

  /// Record one failure of [pathKey] on [network]. Forgets it as the
  /// remembered door, so the next connect diagnoses rather than trying
  /// the same dead door again.
  Future<void> markFailed(String network, String pathKey) async {
    final all = await _load();
    final entry = Map<String, dynamic>.from(all[network] ?? const {});
    if (entry['key'] == pathKey) {
      entry.remove('key');
      entry.remove('at');
    }
    final shared = entry['shared'];
    if (shared is Map && shared['key'] == pathKey) entry.remove('shared');
    final fails = _failsOf(entry);
    final today = _today();
    final current = fails[pathKey];
    final n = current is Map && current['day'] == today
        ? (current['n'] as num? ?? 0).toInt()
        : 0;
    // The time of the latest failure, for a skip that lasts a set time
    // after it ([SkipSettings.skipFor]).
    fails[pathKey] = {
      'day': today,
      'n': n + 1,
      'at': _now().toUtc().toIso8601String(),
    };
    entry['fails'] = fails;
    all[network] = entry;
    if (!NetworkKeys.mayKeep(network)) return;
    await _store(all);
  }

  /// Forget [pathKey] as the door to try first on [network], without
  /// counting a failure. The next tap on [network] starts with the
  /// checklist. Nothing else about the door changes: its failures today,
  /// and whether it ever carried traffic here ([skippable]), stay as they
  /// were.
  ///
  /// For a remembered door the user stopped while the app was still
  /// dialling it (ConnectFlow.stop). About a third of those dials were of
  /// doors that worked, so the stop is no proof the door is dead, and a
  /// failure would count it towards being skipped for the day. But the
  /// user gave up on it, and dialling it first again costs the next tap
  /// the same wait.
  ///
  /// Also for a remembered door the fast path left for a door found open
  /// beside it, and for one whose dial failed by itself in a tap stopped or
  /// replaced before the failure was written down (ConnectFlow.cancel).
  ///
  /// On Wi-Fi, [recall] lends a network with no door of its own the door
  /// another Wi-Fi network remembers. The forgotten door is not lent back
  /// to [network], as a door that failed there is not, until another
  /// network remembers it again after this.
  Future<void> forget(String network, String pathKey) async {
    final all = await _load();
    final entry = Map<String, dynamic>.from(all[network] ?? const {});
    if (entry['key'] == pathKey) {
      entry
        ..remove('key')
        ..remove('at');
    }
    entry['forgot'] = {'key': pathKey, 'at': _now().toUtc().toIso8601String()};
    all[network] = entry;
    if (!NetworkKeys.mayKeep(network)) return;
    await _store(all);
  }

  /// Record that a check on [network] found each of [pathKeys] closed.
  ///
  /// For shared links. Unlike [markFailed] this never makes a link
  /// skippable: a closed check only sends it to the back of the next
  /// fallback (see [failedToday]), so that each tap checks links the last
  /// one did not. A remembered shared link among them is forgotten.
  ///
  /// The time of each link's latest closed check is kept beside the day's
  /// list, for a stay at the back that the backend sets
  /// ([FallbackSettings.closedFor]).
  Future<void> markClosed(String network, Iterable<String> pathKeys) async {
    if (pathKeys.isEmpty) return;
    final all = await _load();
    final entry = Map<String, dynamic>.from(all[network] ?? const {});
    final today = _today();
    final closed = entry['closed'];
    final keys = <String>{
      if (closed is Map && closed['day'] == today && closed['keys'] is List)
        ...(closed['keys'] as List).whereType<String>(),
      ...pathKeys,
    };
    final now = _now().toUtc().toIso8601String();
    final at = <String, String>{
      if (closed is Map && closed['day'] == today && closed['at'] is Map)
        for (final e in (closed['at'] as Map).entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      for (final key in pathKeys) key: now,
    };
    entry['closed'] = {'day': today, 'keys': keys.toList(), 'at': at};
    final shared = entry['shared'];
    if (shared is Map && pathKeys.contains(shared['key'])) {
      entry.remove('shared');
    }
    all[network] = entry;
    if (!NetworkKeys.mayKeep(network)) return;
    await _store(all);
  }

  /// Everything on [network] that a check found closed today, or that
  /// failed today at least once.
  ///
  /// With [within], only what was found closed or failed in that long
  /// before now. A record an older build wrote carries no time, and then it
  /// counts for the day, as it did.
  Future<Set<String>> failedToday(String network, {Duration? within}) async {
    final entry = (await _load())[network];
    if (entry == null) return const {};
    final today = _today();
    final since = within == null ? null : _now().subtract(within);
    final closed = entry['closed'];
    final closedAt = closed is Map && closed['at'] is Map
        ? closed['at'] as Map
        : const {};
    bool closedLately(String key) {
      if (since == null) return true;
      final at = DateTime.tryParse(closedAt[key]?.toString() ?? '');
      return at == null || !at.isBefore(since);
    }

    return {
      if (closed is Map && closed['day'] == today && closed['keys'] is List)
        ...(closed['keys'] as List).whereType<String>().where(closedLately),
      for (final e in _failsOf(entry).entries)
        if (e.value is Map &&
            e.value['day'] == today &&
            (since == null || _failedSince(e.value, since)))
          e.key,
    };
  }

  /// The doors a diagnosis on [network] should not bother checking now.
  ///
  /// With no [rule], a door is skipped once it failed [maxFailsPerDay]
  /// times today, until the UTC day ends. With one, once it failed
  /// [SkipSettings.failures] times today, until [SkipSettings.skipFor] has
  /// passed since its latest failure. A failure written by an older build
  /// carries no time, and then the skip lasts the day, as it did.
  ///
  /// [holding] is every door the phone holds now. When exactly one of them
  /// ever carried traffic on [network], that door is never skipped,
  /// whatever its failures, because it is the one door known to work here.
  /// One phone on home wifi had an address that carried its tunnel twice
  /// in one morning, and three checklists in between left it out and ended
  /// at "all doors closed".
  Future<Set<String>> skippable(
    String network, {
    Iterable<String>? holding,
    SkipSettings? rule,
  }) async {
    final entry = (await _load())[network];
    if (entry == null) return const {};
    final today = _today();
    final now = _now();
    final out = <String>{};
    _failsOf(entry).forEach((key, value) {
      if (value is! Map || value['day'] != today) return;
      final n = (value['n'] as num? ?? 0).toInt();
      if (rule == null) {
        if (n >= maxFailsPerDay) out.add(key);
        return;
      }
      if (n < rule.failures) return;
      final at = DateTime.tryParse(value['at']?.toString() ?? '');
      if (at == null || now.difference(at) < rule.skipFor) out.add(key);
    });
    if (holding != null) {
      final carried = _carriedOf(entry);
      final known = holding.toSet().where(carried.containsKey).toList();
      if (known.length == 1) out.remove(known.single);
    }
    return out;
  }

  /// Record what a background sweep on [network] found: [open] are the
  /// doors that carried data. Replaces the last sweep's record.
  Future<void> markSwept(String network, Iterable<String> open) async {
    final all = await _load();
    final entry = Map<String, dynamic>.from(all[network] ?? const {});
    entry['swept'] = {
      'at': _now().toUtc().toIso8601String(),
      'open': open.toSet().toList(),
    };
    all[network] = entry;
    if (!NetworkKeys.mayKeep(network)) return;
    await _store(all);
  }

  /// The doors the last sweep on [network] found open, when that sweep
  /// ran less than [within] ago. Empty otherwise.
  Future<Set<String>> sweptOpen(String network, Duration within) async {
    final swept = (await _load())[network]?['swept'];
    if (swept is! Map) return const {};
    final at = DateTime.tryParse(swept['at']?.toString() ?? '');
    if (at == null || _now().difference(at) >= within) return const {};
    final open = swept['open'];
    return open is List ? open.whereType<String>().toSet() : const {};
  }

  /// Forget everything. Account deletion, and tests.
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (_) {}
  }

  String _today() {
    final d = _now().toUtc();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static Map<String, dynamic> _failsOf(Map<String, dynamic> entry) {
    final raw = entry['fails'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  /// The latest time anything was written for a network.
  static DateTime _lastTouched(Map<String, dynamic> entry) {
    var last = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    void see(Object? v) {
      final at = DateTime.tryParse(v?.toString() ?? '');
      if (at != null && at.isAfter(last)) last = at;
    }

    see(entry['at']);
    for (final part in ['swept', 'shared']) {
      final m = entry[part];
      if (m is Map) see(m['at']);
    }
    for (final v in _failsOf(entry).values) {
      if (v is Map) see(v['at']);
    }
    _carriedOf(entry).values.forEach(see);
    final closed = entry['closed'];
    if (closed is Map) see(closed['day']);
    return last;
  }

  /// The doors that ever carried traffic on a network, with when each one
  /// last did.
  static Map<String, dynamic> _carriedOf(Map<String, dynamic> entry) {
    final raw = entry['carried'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
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
      debugPrint('PathMemory: could not read memory: $e');
      return {};
    }
  }

  Future<void> _store(Map<String, Map<String, dynamic>> all) async {
    if (all.length > maxNetworks) {
      final newest = all.entries.toList()
        ..sort(
          (a, b) => _lastTouched(b.value).compareTo(_lastTouched(a.value)),
        );
      all = Map.fromEntries(newest.take(maxNetworks));
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(all));
    } catch (e) {
      debugPrint('PathMemory: could not write memory: $e');
    }
  }
}
