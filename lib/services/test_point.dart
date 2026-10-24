import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/state/dedicated_state.dart';
import '../data/models/server.dart';
import '../utils/tls_fragment.dart';
import '../utils/vless_link.dart';
import 'connect_diagnostics.dart';
import 'door_sweep.dart';
import 'path_finder.dart';
import 'ping_service.dart';
import 'tunnel_channels.dart';
import 'vpn_event_reporter.dart';

/// Turns a spare phone inside Iran into a test point.
///
/// Everything else the backend learns about a door comes from users, so
/// when users stop trying, or a carrier has few of them, nothing is known.
/// A phone the backend marks as a test point is sent a [TestPointConfig],
/// and from then on, every [TestPointConfig.interval] while the app runs:
///
/// * it fetches its links again, so a moved address is picked up;
/// * it checks every door, reported as [ProbeResult]s with source
///   `testpoint`;
/// * it checks each split in [TestPointConfig.specs] on each TLS door,
///   reported with source `experiment`. The backend keeps those out of the
///   order it gives users and uses them to pick which split to test first.
///
/// Android only: the app is excluded from its own tunnel there, so a check
/// measures the carrier even while connected. The phone has to stay on
/// with the app open; Android's "stay awake while charging" does that.
class TestPointRunner extends ChangeNotifier {
  TestPointRunner(
    this._dedicated, {
    DoorSweep? sweep,
    VpnEventReporter? reporter,
    InternetCheck? internet,
    Future<String?> Function()? carrier,
    String Function()? newId,
    DateTime Function()? now,
    bool? android,
  }) : _reporter = reporter ?? VpnEventReporter(),
       _internet = internet ?? _defaultInternet,
       _carrier = carrier ?? _defaultCarrier,
       _newId = newId ?? _defaultId,
       _now = now ?? DateTime.now,
       _android = android ?? Platform.isAndroid {
    _sweep = sweep ?? DoorSweep(read: _defaultRead, reporter: _reporter);
    _dedicated.addListener(_follow);
    _follow();
  }

  /// At most this many split checks in one round.
  static const maxVariants = 16;

  final DedicatedState _dedicated;
  final VpnEventReporter _reporter;
  final InternetCheck _internet;
  final Future<String?> Function() _carrier;
  final String Function() _newId;
  final DateTime Function() _now;
  final bool _android;
  late final DoorSweep _sweep;

  Timer? _timer;
  Duration? _interval;
  bool _running = false;
  DateTime? _lastCheck;
  int _open = 0;
  int _total = 0;

  /// Whether this phone is a test point right now.
  bool get active => _timer != null;

  /// When the last round finished, and how many doors were open in it.
  DateTime? get lastCheck => _lastCheck;
  int get openDoors => _open;
  int get totalDoors => _total;

  void _follow() {
    final config = _dedicated.testPoint;
    if (config == null || !_android) {
      if (_timer != null) {
        _timer!.cancel();
        _timer = null;
        _interval = null;
        notifyListeners();
      }
      return;
    }
    if (_timer != null && _interval == config.interval) return;
    _timer?.cancel();
    _interval = config.interval;
    _timer = Timer.periodic(config.interval, (_) => unawaited(runOnce()));
    notifyListeners();
    unawaited(runOnce());
  }

  /// One round: fetch links, check every door, then every split. Never
  /// throws, and never overlaps with a round still running.
  Future<void> runOnce() async {
    if (_running) return;
    _running = true;
    try {
      await _dedicated.refresh(viaTunnel: false);
      final config = _dedicated.testPoint;
      if (config == null) return;
      if (!await _internet()) return;
      final doors = _dedicated.paths.take(DoorSweep.maxDoors).toList();
      if (doors.isEmpty) return;
      final carrier = await _carrier();

      final checks = await _sweep.probeAll(doors);
      await _reporter.recordProbes(
        checks,
        carrier: carrier,
        attemptId: _newId(),
        source: ProbeSource.testpoint,
      );

      final variants = <Server>[
        for (final door in doors)
          // Read from the link, not from the door id, so a copy of a door
          // at another address ("-b", "-v6") is what its link says it is.
          if (VlessLink.security(door.connectionUri) == 'tls')
            for (final spec in config.specs)
              door.copyWith(
                connectionUri: TlsFragment.withSpec(door.connectionUri, spec),
              ),
      ].take(maxVariants).toList();
      if (variants.isNotEmpty) {
        await _reporter.recordProbes(
          await _sweep.probeAll(variants),
          carrier: carrier,
          attemptId: _newId(),
          source: ProbeSource.experiment,
        );
      }

      _lastCheck = _now();
      _open = checks.where((c) => c.ok).length;
      _total = checks.length;
      notifyListeners();
    } catch (e) {
      debugPrint('TestPointRunner: round failed: $e');
    } finally {
      _running = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dedicated.removeListener(_follow);
    super.dispose();
  }

  static final _channel = TunnelChannels.method;

  static Future<DoorOutcome> _defaultRead(Server path) =>
      PingService().readDoor(path, timeout: const Duration(seconds: 6));

  static Future<bool> _defaultInternet() async {
    final r = await ConnectDiagnostics(channel: _channel).controlCheck();
    return r['control'] == 'ok';
  }

  static Future<String?> _defaultCarrier() async {
    try {
      final report = await ConnectDiagnostics(
        channel: _channel,
      ).platformReport();
      final c = report['carrier'] ?? report['sim_carrier'];
      return c is String && c.isNotEmpty ? c : null;
    } catch (_) {
      return null;
    }
  }

  static String _defaultId() =>
      'tp-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
}
