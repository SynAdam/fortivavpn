import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/server.dart';
import '../utils/tls_fragment.dart';
import '../utils/vless_link.dart';
import '../utils/vless_link_host.dart';
import 'connect_trace.dart';
import 'network_keys.dart';
import 'path_finder.dart';
import 'vpn_event_reporter.dart';

/// Checks every door on a schedule, whether or not anybody needed one.
///
/// The diagnosis in [PathFinder] only runs when a user could not connect,
/// and it stops at the first door that opens. Both are right for somebody
/// who is waiting. Both are wrong as a measurement: the rows it produces
/// are conditioned on failure, and a door that ranks below a working one
/// is never checked at all. In production that showed up as 216 readings
/// for the door everyone uses against 9 and 6 for the two we most wanted
/// to learn about.
///
/// So this runs the same probe over every door, in parallel, and reports
/// the lot. Parallel is safe and roughly six times faster: measured on a
/// device, six doors take about 1.5 seconds together against about 8.9
/// seconds one at a time, and the per door numbers come back the same.
///
/// It costs the user nothing they can see. The probe builds one outbound
/// in memory and fetches a small page through it, with no tunnel, no
/// permission and no listening socket, so a sweep cannot disturb a live
/// connection.
class DoorSweep {
  /// [read] tests a door and says how far the check got; [probe] only says
  /// how long it took. With neither, every door reads as closed.
  DoorSweep({
    DoorProbe? probe,
    DoorReader? read,
    InternetCheck? internet,
    VpnEventReporter? reporter,
    String Function()? newId,
    DateTime Function()? now,
    bool? appBypassesTunnel,
    this.interval = const Duration(hours: 6),
    this.probeTimeout = const Duration(seconds: 6),
  }) : _appBypassesTunnel = appBypassesTunnel ?? Platform.isAndroid,
       _read = doorReader(probe: probe, read: read),
       _internet = internet ?? _noInternet,
       _reporter = reporter ?? VpnEventReporter(),
       _newId = newId ?? _defaultId,
       _now = now ?? DateTime.now;

  /// Where the "swept this network at this time" marks live.
  static const storageKey = 'fortiva_door_sweep_marks';

  /// How many networks keep a mark. A phone that meets many networks must
  /// not grow this without bound.
  static const maxMarks = 20;

  /// A ceiling on one sweep, so a backend that starts returning many
  /// servers cannot turn this into a burst of probes.
  static const maxDoors = 12;

  /// Whether this app's own sockets leave around the tunnel rather than
  /// through it. True on Android, which excludes the app from the TUN.
  final bool _appBypassesTunnel;

  final DoorReader _read;
  final InternetCheck _internet;
  final VpnEventReporter _reporter;
  final String Function() _newId;
  final DateTime Function() _now;

  /// How long a network goes between sweeps.
  final Duration interval;

  /// How long one door gets. Longer than the diagnosis allows, because
  /// nobody is waiting on this one and a slow answer still beats none.
  final Duration probeTimeout;

  static Future<bool> _noInternet() async => false;
  static String _defaultId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(16);

  /// Whether a probe taken right now measures the carrier rather than the
  /// tunnel.
  ///
  /// On Android the app is excluded from the TUN, so its own sockets go
  /// out on the real network even while a user is connected. iOS has no
  /// equivalent and we have not confirmed what a probe measures there, so
  /// there a sweep waits until the tunnel is down. A reading taken through
  /// our own tunnel says nothing about whether a door is open, and would
  /// report every door as working.
  bool measuresRealNetwork({required bool connected}) =>
      _appBypassesTunnel || !connected;

  /// Probe every door in [paths], report the results and return them.
  /// The results are in the order of [paths], the first [maxDoors] of it.
  ///
  /// Does nothing and returns none when the network was swept recently,
  /// when the phone has no internet, or when a probe would measure the
  /// tunnel instead of the carrier. Never throws.
  ///
  /// [network] is the key a sweep is remembered against, the same one
  /// [PathMemory] uses: the transport and the carrier.
  Future<List<ProbeResult>> run(
    List<Server> paths, {
    required String network,
    required bool connected,
    String? carrier,
    bool force = false,
  }) async {
    try {
      if (paths.isEmpty) return const [];
      if (!measuresRealNetwork(connected: connected)) return const [];
      if (!force && !await _due(network)) return const [];

      // Without this a phone that simply lost its connection reports every
      // door as blocked, which reads exactly like a carrier that started
      // filtering all of them.
      if (!await _internet()) return const [];

      final doors = paths.take(maxDoors).toList();
      final sweepId = _newId();
      final results = await probeAll(doors);

      await _reporter.recordProbes(
        results,
        carrier: carrier,
        attemptId: sweepId,
        source: ProbeSource.sweep,
        network: network,
      );
      await _mark(network);
      return results;
    } catch (e) {
      debugPrint('DoorSweep: sweep failed: $e');
      return const [];
    }
  }

  /// Probe every door in [paths] at once, without reporting. A test point
  /// uses this for its own reports.
  Future<List<ProbeResult>> probeAll(List<Server> paths) =>
      Future.wait([for (final path in paths) _one(path)]);

  /// Probe one door alone, without reporting, giving it [timeout] (else
  /// [probeTimeout]). A paired door check uses this, one door at a time.
  Future<ProbeResult> probeOne(Server path, {Duration? timeout}) =>
      _one(path, timeout: timeout);

  Future<ProbeResult> _one(Server path, {Duration? timeout}) async {
    final started = DateTime.now();
    DoorOutcome reading;
    try {
      reading = await _read(path).timeout(timeout ?? probeTimeout);
    } catch (e) {
      reading = DoorOutcome(ms: -1, error: e.toString());
    }
    final ok = reading.open;
    return ProbeResult(
      door: path.door ?? '',
      ok: ok,
      serverHost: VlessLinkHost.of(path),
      ms: ok ? reading.ms : DateTime.now().difference(started).inMilliseconds,
      error: ok ? null : reading.error,
      tcpMs: reading.tcpMs,
      phase: reading.phase,
      timeline: reading.timeline ?? CheckTimeline(began: started),
      doorKey: ConnectTrace.doorKey(path),
      // What the check dialled with: the probe applies the same split.
      strategy: VlessLink.strategy(TlsFragment.apply(path.connectionUri)),
    );
  }

  Future<bool> _due(String network) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final marks = prefs.getStringList(storageKey) ?? const [];
      final cutoff = _now().subtract(interval);
      for (final mark in marks) {
        final at = mark.indexOf('@');
        if (at == -1 || mark.substring(0, at) != network) continue;
        final when = DateTime.tryParse(mark.substring(at + 1));
        if (when != null && when.isAfter(cutoff)) return false;
      }
      return true;
    } catch (e) {
      debugPrint('DoorSweep: could not read marks: $e');
      // Skip rather than sweep. A store that cannot be read is also one
      // that cannot record the sweep, which would mean sweeping on every
      // single connect.
      return false;
    }
  }

  Future<void> _mark(String network) async {
    try {
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
    } catch (e) {
      debugPrint('DoorSweep: could not store mark: $e');
    }
  }
}
