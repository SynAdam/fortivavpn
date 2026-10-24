import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/models/stall_watch_settings.dart';

/// What the tunnel carried since its counters were last read.
typedef TunnelCounts = ({int up, int down});

/// Why a [StallWatch] looked, and what it saw before it called the tunnel
/// dead.
class StallFinding {
  const StallFinding({
    required this.trigger,
    required this.probes,
    required this.quietFor,
    this.up,
    this.down,
  });

  /// What started the checks: [StallWatch.triggerCounters],
  /// [StallWatch.triggerThrottle] or [StallWatch.triggerResume].
  final String trigger;

  /// How many checks through the tunnel failed in a row.
  final int probes;

  /// How long since the tunnel last brought anything down, as far as this
  /// watch saw.
  final Duration quietFor;

  /// The bytes of the reading that started the checks, when one did.
  final int? up;
  final int? down;

  /// For the report. Counts and seconds only.
  Map<String, dynamic> get facts => {
    'stall_trigger': trigger,
    'stall_probes': probes,
    'stall_quiet_s': quietFor.inSeconds,
    'stall_up_bytes': ?up,
    'stall_down_bytes': ?down,
  };
}

/// Tells a tunnel that is up but carries nothing from one that is idle.
///
/// A tunnel can stay "connected" for a long time after its server stops
/// answering (NimusAI/fortiva-vpn-clients#289). A phone on home Wi-Fi
/// showed Connected for about 45 minutes with nothing coming back, until
/// the user disconnected by hand. The app had the counters that said so,
/// sent them in a heartbeat, and did nothing with them.
///
/// Every [interval] this reads the counters ([read]). A tunnel whose apps
/// sent something ([minUp] or more) and got almost nothing back (under
/// [minDown]) is checked through the tunnel itself ([probe]), up to
/// [checks] times [checkGap] apart. Only when every check fails
/// is it called dead, once, through [onStall]. A reading with nothing sent
/// is an idle phone and costs nothing: no check runs. A reading with data
/// coming back is a live tunnel, whatever the checks would say.
///
/// The checks are what decide, and the counters only say when one is worth
/// making. An upload with no answer yet reads like a stall on the counters
/// and passes the first check.
///
/// [resumed] runs the same checks when the app comes to the front while a
/// tunnel is up. Someone opening the app with a tunnel up is often someone
/// whose internet stopped, and on a phone that froze the app in the
/// background, the periodic reading never ran.
///
/// A tunnel can also be throttled rather than dead: it brings back a
/// trickle, enough for a 204 page and over [minDown], too little to load
/// anything. On 2026-10-21, over 48 hours, the watch caught 29 of 49 dead
/// stretches and 4 of 161 throttled ones. With the throttle trigger on
/// (StallWatchSettings.throttle), a reading that sent something and got
/// back far less than the session's own normal is checked too, and with a
/// download check (StallWatchSettings.probeBytes) a check passes only when
/// a real download arrives in time.
///
/// A throttle finding does not end the session where [onThrottle] is
/// given. On 2026-10-23 the throttle trigger ended 106 sessions on 72
/// phones, and the next session carried about half as much whether it
/// moved to another door or not. The finding goes to [onThrottle], which
/// reports it, and leaves the tunnel only for a door a check finds faster,
/// or when a check does not find its door open (StallRecovery). The watch
/// keeps watching, and the throttle trigger rests for its cooldown, as
/// after a check that passed.
///
/// Every number comes from the app config's `stall_watch` block
/// (StallWatchSettings), with the numbers the app was built with when there
/// is none. The constants below are those built-in numbers, which the
/// background Keeper still uses.
///
/// Counters come from the Android core only. With no reading ([read]
/// returns null), the watch does nothing.
class StallWatch {
  StallWatch({
    required this.read,
    required this.probe,
    required this.onStall,
    this.onChange,
    this.onThrottle,
    Duration? interval,
    Duration? checkGap,
    int? checks,
    Duration? resumeGap,
    StallWatchSettings Function()? settings,
    DateTime Function()? now,
  }) : _interval = interval,
       _checkGap = checkGap,
       _checks = checks,
       _resumeGap = resumeGap,
       _settingsOf = settings ?? (() => StallWatchSettings.current),
       _now = now ?? DateTime.now;

  /// From remote config (`feature_flags.stall_watch`), on unless the
  /// backend sends false. See AppConfigState.
  static bool enabled = true;

  /// Stands in for the platform check in tests, which run on a desktop.
  @visibleForTesting
  static bool? androidOverride;

  /// Whether the watch can run here: only the Android core gives counters,
  /// and on Android the app is left out of its own tunnel, so the search
  /// that follows a stall reaches the doors around the dead tunnel.
  static bool get supported => androidOverride ?? Platform.isAndroid;

  static const defaultInterval = Duration(minutes: 1);
  static const defaultCheckGap = Duration(seconds: 10);
  static const defaultChecks = 3;

  /// The least time between two looks started by [resumed]: switching
  /// between apps should not send a check each time.
  static const defaultResumeGap = Duration(minutes: 2);

  /// Bytes sent in one reading before a reading with nothing back is worth
  /// a check. Below it the phone is idle.
  static const minUp = 1024;

  /// Bytes back in one reading that say the tunnel lives.
  static const minDown = 1024;

  static const triggerCounters = 'counters';
  static const triggerThrottle = 'throttle';
  static const triggerResume = 'resume';

  /// The counters since the last read, or null when there is no reading.
  final Future<TunnelCounts?> Function() read;

  /// One check through the tunnel: true as soon as anything answers.
  final Future<bool> Function() probe;

  /// Told once per [start] that the tunnel is dead.
  final void Function(StallFinding finding) onStall;

  /// Told that the throttle trigger's checks all failed on a tunnel that
  /// still brings data back. Null calls [onStall] instead, as builds up to
  /// 2.2.0 do.
  /// Unlike [onStall], the watch goes on: it can be told again, once each
  /// throttle cooldown at most, and still finds a tunnel that dies.
  final void Function(StallFinding finding)? onThrottle;

  /// Told when [doubting] changes, so a screen can say the connection is
  /// being checked.
  final void Function()? onChange;

  final Duration? _interval;
  final Duration? _checkGap;
  final int? _checks;
  final Duration? _resumeGap;
  final StallWatchSettings Function() _settingsOf;
  final DateTime Function() _now;

  StallWatchSettings get _settings => _settingsOf();
  Duration get interval => _interval ?? _settings.interval;
  Duration get checkGap => _checkGap ?? _settings.checkGap;
  int get checks => _checks ?? _settings.checks;
  Duration get resumeGap => _resumeGap ?? _settings.resumeGap;

  Timer? _timer;

  /// Bumped by [start] and [stop], so checks that outlive their tunnel
  /// report nothing.
  int _session = 0;
  bool _checking = false;
  bool _fired = false;
  DateTime? _lastData;
  DateTime? _lastResumeLook;

  /// Bytes back in this session's last readings that sent something, oldest
  /// first, for the throttle trigger's normal.
  final List<int> _downs = [];

  /// Until when the throttle trigger rests after one of its checks passed.
  DateTime? _throttleRest;

  /// Failed checks in the check that runs now.
  int _failedNow = 0;

  /// Whether a tunnel is up and being watched.
  bool get active => _timer != null;

  /// Whether this tunnel was called dead.
  bool get fired => _fired;

  /// Whether a check runs now and one of its tries has failed already: the
  /// tunnel may be dead or throttled. A check that passes at its first try
  /// is never shown, so a healthy tunnel never looks in doubt.
  bool get doubting => _checking && _failedNow > 0;

  /// A tunnel is up and carries traffic, as far as the app knows.
  void start() {
    if (_timer != null) return;
    _session++;
    _fired = false;
    _checking = false;
    _failedNow = 0;
    _lastData = _now();
    _lastResumeLook = null;
    _downs.clear();
    _throttleRest = null;
    _timer = Timer.periodic(interval, (_) => unawaited(_tick()));
  }

  /// The tunnel went down, or is being verified again.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _session++;
    _checking = false;
  }

  void dispose() => stop();

  /// The app came to the front.
  Future<void> resumed() async {
    if (!active || _checking || _fired) return;
    final last = _lastResumeLook;
    final now = _now();
    if (last != null && now.difference(last) < resumeGap) return;
    _lastResumeLook = now;
    final session = _session;
    final counts = await _read();
    if (session != _session) return;
    // Data came back since the last reading: the tunnel lives.
    if (counts != null && counts.down >= _settings.minDown) {
      _lastData = _now();
      return;
    }
    await _check(triggerResume, counts, session);
  }

  @visibleForTesting
  Future<void> tick() => _tick();

  Future<void> _tick() async {
    if (_checking || _fired) return;
    final session = _session;
    final counts = await _read();
    if (session != _session || counts == null) return;
    final settings = _settings;
    if (counts.down >= settings.minDown) {
      _lastData = _now();
      final throttled = _throttled(counts, settings);
      _remember(counts, settings);
      if (throttled) await _check(triggerThrottle, counts, session);
      return;
    }
    // Nothing sent, nothing back: an idle phone, not a dead tunnel.
    if (counts.up < settings.minUp) return;
    _remember(counts, settings);
    await _check(triggerCounters, counts, session);
  }

  /// Whether [counts] brought back far less than this session's normal
  /// while the phone was sending. Judged only once half the window of
  /// readings is known and the normal is big enough to say anything.
  bool _throttled(TunnelCounts counts, StallWatchSettings settings) {
    if (!settings.throttle || counts.up < settings.minUp) return false;
    final rest = _throttleRest;
    if (rest != null && _now().isBefore(rest)) return false;
    if (_downs.length < (settings.throttleReadings + 1) ~/ 2) return false;
    final normal = median(_downs);
    if (normal < settings.throttleMinNormal) return false;
    return counts.down < normal * settings.throttleRatio;
  }

  void _remember(TunnelCounts counts, StallWatchSettings settings) {
    if (counts.up < settings.minUp) return;
    _downs.add(counts.down);
    while (_downs.length > settings.throttleReadings) {
      _downs.removeAt(0);
    }
  }

  @visibleForTesting
  static double median(List<int> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid].toDouble()
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// What one download check says, from the platform's sample (bytes and
  /// ms, and status when the page answered with something other than 200):
  /// true when all [want] bytes came, false when they did not, and null
  /// when the check page itself refused, which says nothing about the
  /// tunnel, so the caller falls back to the older check.
  static bool? downloadPassed(Map<Object?, Object?>? sample, int want) {
    if (sample == null) return false;
    final status = (sample['status'] as num?)?.toInt();
    if (status != null && status != 200) return null;
    final bytes = (sample['bytes'] as num?)?.toInt() ?? 0;
    return bytes >= want;
  }

  Future<TunnelCounts?> _read() async {
    try {
      return await read();
    } catch (e) {
      debugPrint('StallWatch: could not read the counters ($e)');
      return null;
    }
  }

  Future<void> _check(String trigger, TunnelCounts? counts, int session) async {
    if (_checking) return;
    _checking = true;
    _failedNow = 0;
    final tries = checks;
    try {
      for (var i = 0; i < tries; i++) {
        if (i > 0) await Future<void>.delayed(checkGap);
        if (session != _session) return;
        var flows = false;
        try {
          flows = await probe();
        } catch (e) {
          debugPrint('StallWatch: check failed to run ($e)');
        }
        if (session != _session) return;
        if (flows) {
          _lastData = _now();
          if (trigger == triggerThrottle) {
            _throttleRest = _now().add(_settings.throttleCooldown);
          }
          return;
        }
        _failedNow++;
        if (_failedNow == 1) _changed();
      }
      final since = _lastData;
      final finding = StallFinding(
        trigger: trigger,
        probes: tries,
        quietFor: since == null ? Duration.zero : _now().difference(since),
        up: counts?.up,
        down: counts?.down,
      );
      final throttled = onThrottle;
      if (trigger == triggerThrottle && throttled != null) {
        _throttleRest = _now().add(_settings.throttleCooldown);
        throttled(finding);
        return;
      }
      _fired = true;
      onStall(finding);
    } finally {
      final wasDoubting = _failedNow > 0;
      if (session == _session) {
        _checking = false;
        _failedNow = 0;
        if (wasDoubting) _changed();
      }
    }
  }

  void _changed() {
    try {
      onChange?.call();
    } catch (e) {
      debugPrint('StallWatch: change listener failed ($e)');
    }
  }
}
