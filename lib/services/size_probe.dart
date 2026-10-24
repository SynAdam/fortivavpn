import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/api_routes.dart';
import '../data/models/app_config.dart';
import 'delivery_log.dart';
import 'door_sweep.dart';
import 'network_keys.dart';
import 'report_queue.dart';
import 'vpn_event_reporter.dart';
import 'vpn_service.dart' show newAttemptId;

/// One transfer: when it started, how long it took, the HTTP status when an
/// answer came, and what went wrong, or null when the size arrived whole.
typedef _Reading = ({String at, int ms, int? status, String? error});

/// One way the size probe reaches the backend: the phone's own network, or
/// one relay. Never the tunnel.
class SizeProbeRoute {
  const SizeProbeRoute({required this.name, required this.base, this.relay});

  /// "direct", or "relay:" and the relay's host, as the rows name it.
  final String name;

  /// The address the probe's paths go under.
  final String base;

  /// The relay, when this route is one. Its certificate is pinned.
  final ApiRelay? relay;
}

/// Measures which sizes of transfer get through to the backend from this
/// network, on each route the app has.
///
/// A line can carry every small call from a phone and none of its larger
/// uploads, on any route, after a smaller batch got out earlier. Whether
/// that is the size, and where the line is, cannot be read from the
/// phone's reports, because the reports are what is cut.
/// This downloads each of the config's down sizes and uploads each of its
/// up sizes, on the direct route and on every relay the app knows, and
/// records each transfer: the size, whether it arrived whole, and how long
/// it took. The readings go out as size probe rows, in uploads under 1 KB.
///
/// Every number comes from the app config's `size_probe` block: the sizes,
/// the wait for each transfer, and how often one network is measured. With
/// no block, nothing runs.
///
/// It stays out of the user's way:
///
/// * it never starts while a connect is under way, and stops between
///   transfers when one starts;
/// * it never goes through the tunnel. Android leaves this app out of its
///   own tunnel, so the direct route is the phone's own line even while a
///   user is connected. Where the app's requests do go through the tunnel,
///   it does not run while one is up;
/// * at most once per network per `min_interval_minutes`, counted from the
///   last run that finished, with the network known by its transport and
///   carrier (the key the door memory uses);
/// * nothing runs while the user has turned sharing off.
///
/// Its readings have to be of one known network, because the backend files
/// a row under the carrier the batch is sent from unless the row's network
/// type rules that carrier out. So:
///
/// * with no network, nothing runs and nothing is marked. Every transfer
///   would fail at once, and the failures would be filed under whichever
///   carrier the phone sent them from later;
/// * a route during which the network changed is dropped, and the run stops
///   unmarked, so the new network is measured on its own.
///
/// And its settings have to be the backend's current ones, so turning the
/// probe off reaches a phone that has stayed alive in the background: a
/// config older than UpdateGate.configFreshFor is fetched again before a
/// run, and with no fresh config nothing runs.
///
/// The transfers are of random bytes, which carry nothing, to and from
/// GET and POST /api/v1/probe/bytes.
class SizeProbeRunner {
  SizeProbeRunner({
    required SizeProbeSettings? Function() settings,
    required bool Function() busy,
    bool Function()? throughTunnel,
    bool Function()? stale,
    Future<void> Function()? reload,
    Future<String> Function()? network,
    NetworkTypeProbe? networkType,
    Future<List<SizeProbeRoute>> Function()? routes,
    http.Client Function(SizeProbeRoute route, Duration timeout)? client,
    ReportQueue? results,
    DateTime Function()? now,
    String Function()? newId,
    Random? random,
  }) : _settings = settings,
       _busy = busy,
       _throughTunnel = throughTunnel ?? (() => false),
       _stale = stale ?? (() => false),
       _reload = reload ?? (() async {}),
       _network = network ?? _defaultNetwork,
       _networkType = networkType ?? VpnEventReporter.currentNetworkType,
       _routes = routes ?? defaultRoutes,
       _client = client ?? defaultClient,
       _results = results ?? ReportQueue.sizeProbes(),
       _now = now ?? DateTime.now,
       _newId = newId ?? newAttemptId,
       _random = random ?? Random();

  /// Where the "measured this network at this time" marks live.
  static const marksKey = 'fortiva_size_probe_marks';

  /// The network key of a phone with no network (ConnectFlow's key).
  static const noNetwork = 'none';

  final SizeProbeSettings? Function() _settings;
  final bool Function() _busy;
  final bool Function() _throughTunnel;

  /// Whether the settings in hand are too old to run on, and the fetch
  /// that replaces them.
  final bool Function() _stale;
  final Future<void> Function() _reload;
  final Future<String> Function() _network;
  final NetworkTypeProbe _networkType;
  final Future<List<SizeProbeRoute>> Function() _routes;
  final http.Client Function(SizeProbeRoute route, Duration timeout) _client;
  final ReportQueue _results;
  final DateTime Function() _now;
  final String Function() _newId;
  final Random _random;

  bool _running = false;

  /// Whether a run is going now.
  bool get running => _running;

  static Future<String> _defaultNetwork() async =>
      await VpnEventReporter.currentNetworkType() ?? 'unknown';

  /// The direct route, then each relay, as ApiClient tries them. A build
  /// pointed at a local backend has no relays, as in ApiClient.
  static Future<List<SizeProbeRoute>> defaultRoutes() async {
    final relays = ApiConfig.baseOverridden
        ? const <ApiRelay>[]
        : await ApiRelays.current();
    return [
      const SizeProbeRoute(name: 'direct', base: ApiConfig.baseUrl),
      for (final relay in relays)
        SizeProbeRoute(name: relayLabel(relay), base: relay.url, relay: relay),
    ];
  }

  /// A client for [route]: the relay's pinned client, or a plain one on the
  /// phone's own network.
  static http.Client defaultClient(SizeProbeRoute route, Duration timeout) {
    final relay = route.relay;
    if (relay != null) return relayClient(relay, timeout: timeout);
    return IOClient(HttpClient()..connectionTimeout = timeout);
  }

  /// Run once if the config asks for it and this network is due. Returns
  /// how many readings were queued. Never throws, and never runs twice at
  /// once.
  Future<int> maybeRun() async {
    if (_running) return 0;
    if (_settings() == null || !_free()) return 0;
    _running = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.get(VpnEventReporter.sharePrefKey) == false) return 0;
      // No network, or none the platform can name: see the class comment.
      final networkType = await _networkType();
      final network = await _network();
      if (networkType == null || network == noNetwork) return 0;
      var settings = _settings();
      if (settings == null || !_due(prefs, network, settings.minInterval)) {
        return 0;
      }
      // Fetched only once the network is due, so a phone that is not due
      // fetches nothing. The new settings may turn the probe off, or move
      // the interval.
      if (_stale()) {
        await _reload();
        if (_stale()) return 0;
        settings = _settings();
        if (settings == null ||
            !_free() ||
            !_due(prefs, network, settings.minInterval)) {
          return 0;
        }
      }

      final attemptId = _newId();
      var queued = 0;
      var finished = true;
      for (final route in await _routes()) {
        final (rows, stopped) = await _measure(
          route,
          settings,
          networkType: networkType,
          attemptId: attemptId,
        );
        // The network changed during this route, so its rows are dropped.
        if (await _network() != network) {
          finished = false;
          break;
        }
        // Stored route by route, so an app closed mid-run keeps what it
        // measured.
        await _results.add(rows);
        queued += rows.length;
        if (stopped) {
          finished = false;
          break;
        }
      }
      // A run cut short by a connect or a change of network is not marked,
      // so the next try measures this network again.
      if (finished) await _mark(prefs, network);
      if (queued > 0) unawaited(_results.flush(queued: true));
      return queued;
    } catch (e) {
      debugPrint('SizeProbeRunner: run failed: $e');
      return 0;
    } finally {
      _running = false;
    }
  }

  /// Whether nothing the user is waiting on is under way, and the direct
  /// route is the phone's own line.
  bool _free() => !_busy() && !_throughTunnel();

  /// Every transfer of [settings] on [route]. The second value is true when
  /// it stopped early because a connect started.
  Future<(List<Map<String, dynamic>>, bool)> _measure(
    SizeProbeRoute route,
    SizeProbeSettings settings, {
    required String? networkType,
    required String attemptId,
  }) async {
    final rows = <Map<String, dynamic>>[];
    final client = _client(route, settings.timeout);
    try {
      for (final (direction, sizes) in [
        ('down', settings.downSizes),
        ('up', settings.upSizes),
      ]) {
        for (final size in sizes) {
          if (!_free()) return (rows, true);
          final reading = direction == 'down'
              ? await _download(client, route, size, settings.timeout)
              : await _upload(client, route, size, settings.timeout);
          rows.add({
            'direction': direction,
            'size': size,
            'ok': reading.error == null,
            'ms': reading.ms,
            'error': reading.error,
            'route': route.name,
            'network_type': networkType,
            'client_ts': reading.at,
            'attempt_id': attemptId,
          });
          // An answer other than 200 crossed the line whole, so it says
          // nothing about the size: a relay that does not pass the path on
          // yet (404), a rate limit (429), or a backend being deployed
          // (502). Every later size would get the same answer, and would
          // read as a size cut where the answer began. The one row keeps
          // the cause visible.
          final status = reading.status;
          if (status != null && status != 200) return (rows, false);
        }
      }
      return (rows, false);
    } finally {
      client.close();
    }
  }

  Future<_Reading> _download(
    http.Client client,
    SizeProbeRoute route,
    int size,
    Duration timeout,
  ) => _timed(() async {
    final response = await client
        .get(
          Uri.parse('${route.base}/api/v1/probe/bytes?n=$size'),
          headers: ApiConfig.headers,
        )
        .timeout(timeout);
    final got = response.bodyBytes.length;
    return (response.statusCode, got == size ? null : 'received $got of $size');
  });

  Future<_Reading> _upload(
    http.Client client,
    SizeProbeRoute route,
    int size,
    Duration timeout,
  ) => _timed(() async {
    final body = Uint8List(size);
    for (var i = 0; i < size; i++) {
      body[i] = _random.nextInt(256);
    }
    final response = await client
        .post(
          Uri.parse('${route.base}/api/v1/probe/bytes'),
          headers: {
            ...ApiConfig.headers,
            'Content-Type': 'application/octet-stream',
          },
          body: body,
        )
        .timeout(timeout);
    Object? received;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) received = decoded['received'];
    } catch (_) {}
    return (
      response.statusCode,
      received == size ? null : 'received $received of $size',
    );
  });

  /// Run one transfer, which gives the status and whether the size was
  /// wrong: when it started, how long it took, and null or what went
  /// wrong. A failed route is named as DeliveryLog names one.
  Future<_Reading> _timed(
    Future<(int status, String? wrongSize)> Function() transfer,
  ) async {
    final at = _now().toUtc().toIso8601String();
    final watch = Stopwatch()..start();
    int? status;
    String? error;
    try {
      final (code, wrongSize) = await transfer();
      status = code;
      error = code == 200 ? wrongSize : 'status $code';
    } catch (e) {
      error = DeliveryLog.errorClass(e) ?? 'error';
    }
    return (
      at: at,
      ms: watch.elapsedMilliseconds,
      status: status,
      error: error,
    );
  }

  bool _due(SharedPreferences prefs, String network, Duration interval) {
    final cutoff = _now().subtract(interval);
    for (final mark in prefs.getStringList(marksKey) ?? const <String>[]) {
      final at = mark.lastIndexOf('@');
      if (at == -1 || mark.substring(0, at) != network) continue;
      final when = DateTime.tryParse(mark.substring(at + 1));
      if (when != null && when.isAfter(cutoff)) return false;
    }
    return true;
  }

  Future<void> _mark(SharedPreferences prefs, String network) async {
    final marks = [
      for (final m in prefs.getStringList(marksKey) ?? const <String>[])
        if (!m.startsWith('$network@')) m,
    ];
    marks.add('$network@${_now().toUtc().toIso8601String()}');
    while (marks.length > DoorSweep.maxMarks) {
      marks.removeAt(0);
    }
    if (!NetworkKeys.mayKeep(network)) return;
    await prefs.setStringList(marksKey, marks);
  }
}
