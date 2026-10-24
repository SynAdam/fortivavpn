import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' show DartPluginRegistrant, Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/bootstrap.dart';
import '../core/state/app_config_state.dart';
import '../core/state/locale_state.dart';
import '../l10n/generated/app_localizations.dart';
import 'stall_watch.dart';
import 'vpn_event_reporter.dart';

/// The keeper's run, started by KeeperJobService on Android with no screen
/// when the app's own engine is gone and the tunnel runs on. Runs one
/// [Keeper] and tells the service it is done, whatever happens.
@pragma('vm:entry-point')
Future<void> keeperMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    await ApiConfig.readAppBuild();
    // The relays the fallback file named, from what earlier runs saved.
    await Bootstrap.instance.restore();
    ApiClient.tunnelSocksPort = KeeperChannel.socksPort;
    await Keeper().run().timeout(Keeper.budget);
  } catch (e) {
    debugPrint('Keeper: the run failed ($e)');
  } finally {
    await KeeperChannel.done();
  }
}

/// What the keeper's engine asks KeeperJobService.
abstract final class KeeperChannel {
  static const _channel = MethodChannel('com.vpn.fortivavpn/keeper');

  /// The tunnel's SOCKS port while a tunnel is up, else null.
  static Future<int?> socksPort() async {
    try {
      return await _channel.invokeMethod<int>('socksPort');
    } catch (e) {
      debugPrint('KeeperChannel: no SOCKS port ($e)');
      return null;
    }
  }

  /// The tunnel's counters since they were last read, with the carrier
  /// and network, as the app's engine gets them; null with no tunnel or
  /// no answer.
  static Future<Map<String, dynamic>?> tunnelStats() async {
    try {
      final raw = await _channel
          .invokeMethod<Map<Object?, Object?>>('tunnelStats')
          .timeout(const Duration(seconds: 5));
      return raw?.map((k, v) => MapEntry(k.toString(), v));
    } catch (e) {
      debugPrint('KeeperChannel: no counters ($e)');
      return null;
    }
  }

  /// Whether a request through the tunnel gets an answer.
  static Future<bool> testConnection() async {
    try {
      return await _channel
              .invokeMethod<bool>('testConnection')
              .timeout(const Duration(seconds: 8)) ??
          false;
    } catch (e) {
      return false;
    }
  }

  /// Whether the app's own engine runs again.
  static Future<bool> appRunning() async {
    try {
      return await _channel.invokeMethod<bool>('appRunning') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Tell the user the tunnel carries nothing. Whether it was posted.
  static Future<bool> showStalled({
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('showStalled', {
            'title': title,
            'body': body,
            'channelName': channelName,
            'channelDescription': channelDescription,
          }) ??
          false;
    } catch (e) {
      debugPrint('KeeperChannel: notification not posted ($e)');
      return false;
    }
  }

  static Future<void> done() async {
    try {
      await _channel.invokeMethod<void>('done');
    } catch (_) {}
  }
}

/// The heartbeat and the dead tunnel check for a tunnel the app's engine no
/// longer watches (Keeper on the Android side starts this every five
/// minutes while the app stays away).
///
/// The heartbeat says what the app's would: the bytes since the counters
/// were last read, the carrier and network, the session's readings and the
/// attempt the app saved (VpnService keeps it for an app reopened over its
/// tunnel), with `keeper` in diag so the backend can tell them apart.
///
/// The dead tunnel check is the app's (StallWatch): data sent and almost
/// nothing back since the last read, then up to [checks] requests through
/// the tunnel [checkGap] apart. When every one fails, the session is
/// reported dropped as stalled, as the app reports it, and the user gets a
/// notification. The tunnel stays up: moving to another path needs the
/// app, and opening it from the notification does that. No more
/// heartbeats are sent for that attempt until it carries data again.
class Keeper {
  Keeper({
    VpnEventReporter? reporter,
    Future<Map<String, dynamic>?> Function()? stats,
    Future<bool> Function()? probe,
    Future<bool> Function()? appRunning,
    Future<void> Function(String language)? notify,
    Future<void> Function(Duration)? wait,
    DateTime Function()? now,
  }) : _reporter =
           reporter ??
           (VpnEventReporter()..reportsGoThroughTunnel = () => false),
       _stats = stats ?? KeeperChannel.tunnelStats,
       _probe = probe ?? KeeperChannel.testConnection,
       _appRunning = appRunning ?? KeeperChannel.appRunning,
       _notify = notify ?? _showStalled,
       _wait = wait ?? Future<void>.delayed,
       _now = now ?? DateTime.now;

  final VpnEventReporter _reporter;
  final Future<Map<String, dynamic>?> Function() _stats;
  final Future<bool> Function() _probe;
  final Future<bool> Function() _appRunning;
  final Future<void> Function(String language) _notify;
  final Future<void> Function(Duration) _wait;
  final DateTime Function() _now;

  /// The longest one run may take; KeeperJobService gives it a little more.
  static const budget = Duration(seconds: 75);

  /// Requests through the tunnel before it is called dead, and the gap
  /// between them: the app's StallWatch values.
  static const checks = StallWatch.defaultChecks;
  static const checkGap = StallWatch.defaultCheckGap;

  /// The attempt a run already found dead, so later runs neither report it
  /// again nor send heartbeats for it.
  static const stalledKey = 'keeper_stalled_attempt';

  /// The attempt VpnService saves for an app reopened over its tunnel, and
  /// when the connection began.
  static const attemptKey = 'vpn_connected_attempt';
  static const startTimeKey = 'vpn_connected_start_time';

  Future<void> run() async {
    final stats = await _stats();
    if (stats == null) return;
    final up = (stats['bytes_up'] as num?)?.toInt();
    final down = (stats['bytes_down'] as num?)?.toInt();
    if (up == null || down == null) return;
    // The app came back while this started: it reads its own from here.
    if (await _appRunning()) return;

    final prefs = await SharedPreferences.getInstance();
    final attempt = _attempt(prefs);
    final attemptId = attempt['attempt_id'] as String?;
    final stalledBefore =
        attemptId != null && prefs.getString(stalledKey) == attemptId;
    if (stalledBefore && down >= StallWatch.minDown) {
      // Found dead earlier, carrying again: a session again.
      await prefs.remove(stalledKey);
    }
    final dead = stalledBefore && down < StallWatch.minDown;
    if (!dead) {
      await _reporter.record(
        VpnEventType.heartbeat,
        door: attempt['door'] as String?,
        attemptId: attemptId,
        strategy: _map(attempt['strategy']),
        serverHost: attempt['server_host'] as String?,
        duration: _duration(prefs),
        bytesUp: up,
        bytesDown: down,
        diag: _beatFacts(stats, attempt),
      );
    }

    final watch = prefs.getBool(AppConfigState.stallWatchOffKey) != true;
    if (watch &&
        !stalledBefore &&
        up >= StallWatch.minUp &&
        down < StallWatch.minDown) {
      await _check(prefs, stats, attempt, up, down);
    }
    await _reporter.flush();
  }

  Future<void> _check(
    SharedPreferences prefs,
    Map<String, dynamic> stats,
    Map<String, dynamic> attempt,
    int up,
    int down,
  ) async {
    for (var i = 0; i < checks; i++) {
      if (i > 0) await _wait(checkGap);
      if (await _probe()) return;
      if (await _appRunning()) return;
    }
    final attemptId = attempt['attempt_id'] as String?;
    await prefs.setString(stalledKey, attemptId ?? '');
    await _reporter.record(
      VpnEventType.dropped,
      door: attempt['door'] as String?,
      attemptId: attemptId,
      strategy: _map(attempt['strategy']),
      serverHost: attempt['server_host'] as String?,
      error: 'stalled',
      diag: {
        ..._network(stats),
        'stall_trigger': 'keeper',
        'stall_probes': checks,
        'stall_up_bytes': up,
        'stall_down_bytes': down,
        'drop_reason': 'stalled',
        'keeper': true,
      },
    );
    await _notify(prefs.getString(LocaleState.prefKey) ?? 'en');
  }

  Map<String, dynamic> _beatFacts(
    Map<String, dynamic> stats,
    Map<String, dynamic> attempt,
  ) {
    final verified = DateTime.tryParse(
      attempt['verified_at']?.toString() ?? '',
    );
    final session = stats['session'];
    return {
      ..._network(stats),
      if (verified != null)
        'verified_s': max(0, _now().difference(verified).inSeconds),
      if (attempt['moves'] is num) 'moves': attempt['moves'],
      if (attempt['failovers'] is num) 'failovers': attempt['failovers'],
      if (session is Map)
        'session': {
          for (final entry in session.entries)
            entry.key.toString(): entry.value,
        },
      'keeper': true,
    };
  }

  static Map<String, dynamic> _network(Map<String, dynamic> stats) => {
    if (stats['carrier'] != null) 'carrier': stats['carrier'],
    if (stats['network'] != null) 'network': stats['network'],
  };

  static Map<String, dynamic> _attempt(SharedPreferences prefs) {
    try {
      final decoded = jsonDecode(prefs.getString(attemptKey) ?? '');
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return const {};
  }

  Duration? _duration(SharedPreferences prefs) {
    final start = DateTime.tryParse(prefs.getString(startTimeKey) ?? '');
    if (start == null) return null;
    final d = _now().difference(start);
    return d.isNegative ? null : d;
  }

  static Map<String, dynamic>? _map(Object? value) =>
      value is Map ? value.cast<String, dynamic>() : null;

  /// The notification, in the language the user chose in the app.
  static Future<void> _showStalled(String language) async {
    S? s;
    try {
      s = lookupS(Locale(language));
    } catch (_) {
      s = null;
    }
    await KeeperChannel.showStalled(
      title: s?.appTitle ?? 'Fortiva',
      body: s?.homeStalled ?? 'Connected, but no data is getting through',
      channelName: s?.noticeChannelName ?? 'Messages from Fortiva',
      channelDescription:
          s?.noticeChannelDescription ?? 'News and messages from the team',
    );
  }
}
