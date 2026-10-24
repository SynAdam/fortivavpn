import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/config_service.dart';
import '../data/models/server.dart';
import 'door_sweep.dart';
import 'network_keys.dart';
import 'vpn_event_reporter.dart';

/// Runs this phone's part of a carrier's paired door test.
///
/// The backend used to test a new ClientHello setting by giving it to part
/// of a carrier's phones and comparing them with the rest. A comparison of
/// two groups of phones needs about 49 phones in each to tell 30% from
/// 60%, and the groups rarely reached 5. Meanwhile the phones in the test
/// group used a setting nobody had checked.
///
/// Now no phone's links change. While a carrier has a paired test, the
/// backend sends each phone a [DoorPairCheck]: one of its TLS doors, and
/// the same link with the test's setting. After the phone connects, this
/// checks the door both ways, one after the other in random order, and
/// reports the two results together. Every phone then tries both settings
/// on its own cell at the same minute, so the backend can compare them
/// with a handful of phones.
///
/// The checks run one at a time, never side by side: a check beside
/// another can dial with the other's split (TestLink.kt). Both are sent
/// with source `experiment`, which the backend keeps out of the door order
/// it gives users, and one attempt id starting with [attemptPrefix], which
/// is how it finds the two halves of a round. The order they ran in is
/// their position in the report.
///
/// It costs the user two small checks at most once per network every
/// [DoorPairCheck.interval], and it never touches the tunnel.
class DoorPairRunner {
  DoorPairRunner({
    required DoorSweep sweep,
    required VpnEventReporter reporter,
    Random? random,
    DateTime Function()? now,
    Future<void> Function(Duration)? wait,
    String Function()? newId,
  }) : _sweep = sweep,
       _reporter = reporter,
       _random = random ?? Random(),
       _now = now ?? DateTime.now,
       _wait = wait ?? Future<void>.delayed,
       _newId = newId ?? _defaultId;

  /// Where the "ran a round on this network at this time" marks live.
  static const storageKey = 'fortiva_door_pair_marks';

  /// How many networks keep a mark.
  static const maxMarks = 20;

  /// The backend pairs the two checks of a round by this prefix.
  static const attemptPrefix = 'pair-';

  final DoorSweep _sweep;
  final VpnEventReporter _reporter;
  final Random _random;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _wait;
  final String Function() _newId;

  static String _defaultId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(16);

  /// One round of [pair] on [network], when [paths] holds the door it names
  /// and the network has not had a round within its interval. Returns the
  /// two results in the order they ran, or none. Never throws.
  Future<List<ProbeResult>> run(
    DoorPairCheck pair,
    List<Server> paths, {
    required String network,
    String? carrier,
  }) async {
    try {
      final door = paths
          .where(
            (p) =>
                !p.isCommunity &&
                p.serverId == pair.serverId &&
                p.door == pair.door,
          )
          .firstOrNull;
      if (door == null || door.connectionUri == pair.testUri) return const [];
      if (!await _due(network, pair.interval)) return const [];
      // Marked before the checks, so an app closed halfway does not run a
      // round on every connect.
      await _mark(network);

      final test = door.copyWith(connectionUri: pair.testUri);
      final order = _random.nextBool() ? [door, test] : [test, door];
      final results = <ProbeResult>[];
      for (final (i, path) in order.indexed) {
        if (i > 0) await _wait(pair.gap);
        results.add(await _sweep.probeOne(path, timeout: pair.timeout));
      }
      await _reporter.recordProbes(
        results,
        carrier: carrier,
        attemptId: '$attemptPrefix${_newId()}',
        source: ProbeSource.experiment,
      );
      return results;
    } catch (e) {
      debugPrint('DoorPairRunner: round failed: $e');
      return const [];
    }
  }

  Future<bool> _due(String network, Duration interval) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final marks = prefs.getStringList(storageKey) ?? const [];
      final cutoff = _now().subtract(interval);
      for (final mark in marks) {
        final at = mark.lastIndexOf('@');
        if (at == -1 || mark.substring(0, at) != network) continue;
        final when = DateTime.tryParse(mark.substring(at + 1));
        if (when != null && when.isAfter(cutoff)) return false;
      }
      return true;
    } catch (e) {
      // A store that cannot be read cannot record a round either, which
      // would mean a round on every connect.
      debugPrint('DoorPairRunner: could not read marks: $e');
      return false;
    }
  }

  Future<void> _mark(String network) async {
    final prefs = await SharedPreferences.getInstance();
    final marks = (prefs.getStringList(storageKey) ?? const [])
        .where((m) => !m.startsWith('$network@'))
        .toList();
    marks.add('$network@${_now().toUtc().toIso8601String()}');
    while (marks.length > maxMarks) {
      marks.removeAt(0);
    }
    if (!NetworkKeys.mayKeep(network)) return;
    await prefs.setStringList(storageKey, marks);
  }
}
