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
import '../data/models/checklist_settings.dart';
import '../data/models/stall_watch_settings.dart';
import '../l10n/generated/app_localizations.dart';
import 'connect_diagnostics.dart';
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
    await Keeper.restoreSettings();
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

  /// Take away the notification [showStalled] posted. Nothing happens when
  /// none is shown.
  static Future<void> clearStalled() async {
    try {
      await _channel.invokeMethod<void>('clearStalled');
    } catch (e) {
      debugPrint('KeeperChannel: notification not cleared ($e)');
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
///
/// A tunnel also carries nothing while the phone's own network is down,
/// and then the tunnel is not at fault. In the 7 days to 2026-10-27 04:15
/// UTC, 121 of 170 keeper stalls reached the backend more than a minute
/// after they were written, so the phone could not reach it then, and 96
/// of the 170 tunnels carried data again on the same connection, a median
/// of 14 minutes later. So:
///
/// - With no network at all (`network` none in the counters, 46 of the
///   170), the tunnel is not checked.
/// - After every check through the tunnel failed, the phone must show it
///   is online: our API answered it on its own network during the run
///   (ApiClient.answeredSince, as the app counts it), or a site outside
///   the tunnel answered ([phoneReach]). When nothing did, nothing is
///   reported or shown and the next run looks again, up to
///   StallWatchSettings.keeperOfflineSkips runs in a row. Then the tunnel
///   is reported anyway, because some phones fail the site checks while
///   they are online.
/// - Once the phone is online, one more check through the tunnel must
///   fail, because the line can come back during the last one.
/// - A tunnel stopped while it was checked is not reported.
///
/// The mark that a tunnel was reported names the attempt and the tunnel
/// ([stalledTunnelKey]): one started again from the quick settings tile or
/// the widget, without the app, keeps the app's attempt or has none, and
/// it is checked and reported on its own. Until 2026-10-27 a tunnel with no
/// attempt was reported every 5 minutes, with the notification's sound.
///
/// The notification is taken away on the first run that finds the tunnel
/// carrying data. Until 2026-10-27 it stayed until the user swiped it: on
/// 2026-10-25 one stayed in a phone's shade all night over a tunnel that
/// carried data again four minutes after it was posted. The app also takes
/// it away when it comes to the front or the tunnel stops (MainActivity,
/// V2RayServiceManager.stopCoreLoop, V2RayVpnService.onDestroy).
class Keeper {
  Keeper({
    VpnEventReporter? reporter,
    Future<Map<String, dynamic>?> Function()? stats,
    Future<bool> Function()? probe,
    Future<String?> Function()? reach,
    bool Function(DateTime since)? answeredSince,
    Future<bool> Function()? tunnelUp,
    Future<bool> Function()? appRunning,
    Future<void> Function(String language)? notify,
    Future<void> Function()? clear,
    Future<void> Function(Duration)? wait,
    DateTime Function()? now,
  }) : _reporter =
           reporter ??
           (VpnEventReporter()..reportsGoThroughTunnel = () => false),
       _stats = stats ?? KeeperChannel.tunnelStats,
       _probe = probe ?? KeeperChannel.testConnection,
       _reach = reach ?? phoneReach,
       _answeredSince = answeredSince ?? ApiClient.answeredSince,
       _tunnelUp = tunnelUp ?? _socksListens,
       _appRunning = appRunning ?? KeeperChannel.appRunning,
       _notify = notify ?? _showStalled,
       _clear = clear ?? KeeperChannel.clearStalled,
       _wait = wait ?? Future<void>.delayed,
       _now = now ?? DateTime.now;

  final VpnEventReporter _reporter;
  final Future<Map<String, dynamic>?> Function() _stats;
  final Future<bool> Function() _probe;
  final Future<String?> Function() _reach;
  final bool Function(DateTime since) _answeredSince;
  final Future<bool> Function() _tunnelUp;
  final Future<bool> Function() _appRunning;
  final Future<void> Function(String language) _notify;
  final Future<void> Function() _clear;
  final Future<void> Function(Duration) _wait;
  final DateTime Function() _now;

  /// The longest one run may take; KeeperJobService gives it a little more.
  static const budget = Duration(seconds: 75);

  /// Requests through the tunnel before it is called dead, and the gap
  /// between them: the app's StallWatch values.
  static const checks = StallWatch.defaultChecks;
  static const checkGap = StallWatch.defaultCheckGap;

  /// The attempt a run already found dead, so later runs neither report it
  /// again nor send heartbeats for it. '' for a tunnel with no attempt.
  static const stalledKey = 'keeper_stalled_attempt';

  /// The tunnel ([stalledKey]'s attempt can outlive it): the counters'
  /// `tunnel`, which KeeperJobService reads from the VPN network Android
  /// made for that start of the tunnel.
  static const stalledTunnelKey = 'keeper_stalled_tunnel';

  /// Runs in a row that left a dead looking tunnel unreported because the
  /// phone looked offline, with the attempt and tunnel they were for.
  static const offlineSkipsKey = 'keeper_offline_skips';

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

    // Before the heartbeat goes: our API answering it on the phone's own
    // network shows the phone is online ([_check]).
    final started = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final attempt = _attempt(prefs);
    final attemptId = attempt['attempt_id'] as String?;
    final tunnel = stats['tunnel']?.toString();
    final stalledBefore = await _stalledBefore(prefs, attemptId, tunnel);
    if (down >= StallWatch.minDown) {
      // Carrying: a notification an earlier run posted is no longer true.
      await _clear();
      await prefs.remove(offlineSkipsKey);
      // Found dead earlier, carrying again: a session again.
      if (stalledBefore) await _unmark(prefs);
    }
    final dead = stalledBefore && down < StallWatch.minDown;
    final skips = _skips(prefs, attemptId, tunnel);
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
        diag: {
          ..._beatFacts(stats, attempt),
          if (down < StallWatch.minDown && skips > 0) 'offline_skips': skips,
        },
      );
    }

    final watch = prefs.getBool(AppConfigState.stallWatchOffKey) != true;
    // No network at all: nothing could carry, and the next run looks again.
    final noNetwork = stats['network'] == 'none';
    if (watch &&
        !stalledBefore &&
        !noNetwork &&
        up >= StallWatch.minUp &&
        down < StallWatch.minDown) {
      await _check(prefs, stats, attempt, up, down, started, skips);
    }
    await _reporter.flush();
  }

  /// Whether an earlier run reported this tunnel dead. A mark for the same
  /// attempt on another tunnel is from before the tunnel was started again
  /// and is removed, so the new one is checked on its own. With no attempt,
  /// only the tunnel tells one from the next.
  Future<bool> _stalledBefore(
    SharedPreferences prefs,
    String? attemptId,
    String? tunnel,
  ) async {
    final marked = prefs.getString(stalledKey);
    if (marked == null || marked != (attemptId ?? '')) return false;
    final markedTunnel = prefs.getString(stalledTunnelKey);
    if (markedTunnel == null || tunnel == null) return attemptId != null;
    if (markedTunnel == tunnel) return true;
    await _unmark(prefs);
    return false;
  }

  static Future<void> _mark(
    SharedPreferences prefs,
    String? attemptId,
    String? tunnel,
  ) async {
    await prefs.setString(stalledKey, attemptId ?? '');
    if (tunnel == null) {
      await prefs.remove(stalledTunnelKey);
    } else {
      await prefs.setString(stalledTunnelKey, tunnel);
    }
  }

  static Future<void> _unmark(SharedPreferences prefs) async {
    await prefs.remove(stalledKey);
    await prefs.remove(stalledTunnelKey);
  }

  static String _skipsFor(String? attemptId, String? tunnel) =>
      '${attemptId ?? ''}|${tunnel ?? ''}';

  /// [offlineSkipsKey]'s count for this attempt and tunnel, else 0.
  static int _skips(
    SharedPreferences prefs,
    String? attemptId,
    String? tunnel,
  ) {
    try {
      final saved = jsonDecode(prefs.getString(offlineSkipsKey) ?? '');
      if (saved is Map &&
          saved['for'] == _skipsFor(attemptId, tunnel) &&
          saved['runs'] is int) {
        return saved['runs'] as int;
      }
    } catch (_) {}
    return 0;
  }

  /// The backend's StallWatchSettings.keeperOfflineSkips, as the app saved
  /// it, or the built-in number.
  static int _skipLimit(SharedPreferences prefs) {
    try {
      final saved = prefs.getString(AppConfigState.stallWatchSettingsKey);
      if (saved != null) {
        return StallWatchSettings.fromJson(
          jsonDecode(saved),
        ).keeperOfflineSkips;
      }
    } catch (_) {}
    return StallWatchSettings.builtIn.keeperOfflineSkips;
  }

  Future<void> _check(
    SharedPreferences prefs,
    Map<String, dynamic> stats,
    Map<String, dynamic> attempt,
    int up,
    int down,
    DateTime started,
    int skips,
  ) async {
    for (var i = 0; i < checks; i++) {
      if (i > 0) await _wait(checkGap);
      if (await _probe()) {
        await prefs.remove(offlineSkipsKey);
        return;
      }
      if (await _appRunning()) return;
    }
    final attemptId = attempt['attempt_id'] as String?;
    final tunnel = stats['tunnel']?.toString();
    // Asked again after the sites: an answer can arrive while they run.
    final reached = _answeredSince(started)
        ? 'api'
        : await _reach() ?? (_answeredSince(started) ? 'api' : null);
    if (reached == null && skips < _skipLimit(prefs)) {
      // The phone's own network looks down: the next run looks again.
      await prefs.setString(
        offlineSkipsKey,
        jsonEncode({'for': _skipsFor(attemptId, tunnel), 'runs': skips + 1}),
      );
      return;
    }
    if (await _appRunning()) return;
    // The line can come back during the last check: the tunnel must fail
    // once more.
    if (await _probe()) {
      await prefs.remove(offlineSkipsKey);
      return;
    }
    if (await _appRunning()) return;
    // Stopped while it was checked, by the user or by Android.
    if (!await _tunnelUp()) return;
    await prefs.remove(offlineSkipsKey);
    await _mark(prefs, attemptId, tunnel);
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
        'stall_probes': checks + 1,
        // How the phone showed it is online (api, control, home, error),
        // or skip_limit when it never did.
        'stall_online': reached ?? 'skip_limit',
        if (skips > 0) 'stall_offline_skips': skips,
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

  /// Which site outside the tunnel the phone reaches: `control` for a
  /// control site abroad, else `home` for a site at home, which still
  /// answers when the routes abroad are cut, else null. The keeper is left
  /// out of the tunnel on Android, as the app is, so these go over the
  /// phone's own network. A captive portal does not count: the control
  /// sites must answer 204 themselves, and the home sites are HTTPS.
  static Future<String?> phoneReach() async {
    final diagnostics = ConnectDiagnostics();
    try {
      final control = await diagnostics.controlCheck(only204: true);
      if (control['control'] == 'ok') return 'control';
      final home = await diagnostics.homeCheck();
      return home['control_home'] == 'ok' ? 'home' : null;
    } catch (e) {
      debugPrint('Keeper: could not tell whether the phone is online ($e)');
      // Not known: the tunnel is reported as before this question.
      return 'error';
    }
  }

  /// Put the backend's control and home sites, as the app saved them, in
  /// force in the keeper's own engine, so [phoneReach] asks the sites the
  /// app asks. Nothing saved leaves the built-in ones. Never throws.
  static Future<void> restoreSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(AppConfigState.checklistKey);
      if (saved == null) return;
      ChecklistSettings.current = ChecklistSettings.fromJson(jsonDecode(saved));
    } catch (e) {
      debugPrint('Keeper: could not read the checklist ($e)');
    }
  }

  /// Whether the tunnel's core still listens.
  static Future<bool> _socksListens() async =>
      await KeeperChannel.socksPort() != null;

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
