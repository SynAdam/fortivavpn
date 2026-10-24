/// How the stall watch ([StallWatch]) decides that a tunnel which is up
/// carries nothing or next to nothing, from the app config's `stall_watch`
/// block (the backend's STALL_WATCH_* settings).
///
/// - [interval]: how often the tunnel's counters are read.
/// - [checks], [checkGap]: how many checks through the tunnel, how far
///   apart, before the tunnel is called dead. Every one must fail.
/// - [resumeGap]: the least time between two looks when the app comes to
///   the front.
/// - [minUp], [minDown]: bytes sent in one reading before nothing back is
///   worth a check, and bytes back that say the tunnel lives.
/// - [probeBytes], [probeTimeout]: a check downloads [probeBytes] through
///   the tunnel and passes only when they all arrive within
///   [probeTimeout]. 0 is the older check, any answer to a 204 page, which
///   a throttled tunnel passes.
/// - [throttle], [throttleRatio], [throttleReadings], [throttleMinNormal],
///   [throttleCooldown]: also check a tunnel that brings data back, when a
///   reading that sent something got less than [throttleRatio] of the
///   session's own normal (the median of its last [throttleReadings] such
///   readings, once that is [throttleMinNormal] bytes or more). After such
///   a check passes, the throttle trigger rests for [throttleCooldown].
///
/// [builtIn] holds the numbers the app was built with before this block
/// existed, with the download check and the throttle trigger off, so a
/// phone the backend has not answered yet watches exactly as before. Read
/// without a cast, so a bad value falls back to its built-in one and never
/// throws away the rest of the config.
class StallWatchSettings {
  const StallWatchSettings({
    this.interval = const Duration(minutes: 1),
    this.checks = 3,
    this.checkGap = const Duration(seconds: 10),
    this.resumeGap = const Duration(minutes: 2),
    this.minUp = 1024,
    this.minDown = 1024,
    this.probeBytes = 0,
    this.probeTimeout = const Duration(seconds: 5),
    this.throttle = false,
    this.throttleRatio = 0.1,
    this.throttleReadings = 10,
    this.throttleMinNormal = 65536,
    this.throttleCooldown = const Duration(minutes: 5),
  });

  final Duration interval;
  final int checks;
  final Duration checkGap;
  final Duration resumeGap;
  final int minUp;
  final int minDown;
  final int probeBytes;
  final Duration probeTimeout;
  final bool throttle;
  final double throttleRatio;
  final int throttleReadings;
  final int throttleMinNormal;
  final Duration throttleCooldown;

  static const builtIn = StallWatchSettings();

  /// The settings in force, read by the watch, which lives outside the
  /// widget tree. Set by AppConfigState.
  static StallWatchSettings current = builtIn;

  static StallWatchSettings fromJson(Object? json) {
    if (json is! Map) return builtIn;
    const b = builtIn;
    return StallWatchSettings(
      interval: _seconds(json['interval_seconds']) ?? b.interval,
      checks: _positive(json['checks']) ?? b.checks,
      checkGap: _seconds(json['check_gap_seconds']) ?? b.checkGap,
      resumeGap: _seconds(json['resume_gap_seconds']) ?? b.resumeGap,
      minUp: _count(json['min_up_bytes']) ?? b.minUp,
      minDown: _count(json['min_down_bytes']) ?? b.minDown,
      probeBytes: _count(json['probe_bytes']) ?? b.probeBytes,
      probeTimeout: _millis(json['probe_timeout_ms']) ?? b.probeTimeout,
      throttle: json['throttle'] == true,
      throttleRatio: _ratio(json['throttle_ratio']) ?? b.throttleRatio,
      throttleReadings: _window(json['throttle_window']) ?? b.throttleReadings,
      throttleMinNormal:
          _count(json['throttle_min_normal_bytes']) ?? b.throttleMinNormal,
      throttleCooldown:
          _secondsOrZero(json['throttle_cooldown_seconds']) ??
          b.throttleCooldown,
    );
  }

  static int? _positive(Object? v) => v is int && v > 0 ? v : null;

  static int? _count(Object? v) => v is int && v >= 0 ? v : null;

  static int? _window(Object? v) => v is int && v >= 2 ? v : null;

  static double? _ratio(Object? v) =>
      v is num && v > 0 && v < 1 ? v.toDouble() : null;

  static Duration? _seconds(Object? v) {
    final n = _positive(v);
    return n == null ? null : Duration(seconds: n);
  }

  static Duration? _secondsOrZero(Object? v) {
    final n = _count(v);
    return n == null ? null : Duration(seconds: n);
  }

  static Duration? _millis(Object? v) {
    final n = _positive(v);
    return n == null ? null : Duration(milliseconds: n);
  }

  Map<String, dynamic> toJson() => {
    'interval_seconds': interval.inSeconds,
    'checks': checks,
    'check_gap_seconds': checkGap.inSeconds,
    'resume_gap_seconds': resumeGap.inSeconds,
    'min_up_bytes': minUp,
    'min_down_bytes': minDown,
    'probe_bytes': probeBytes,
    'probe_timeout_ms': probeTimeout.inMilliseconds,
    'throttle': throttle,
    'throttle_ratio': throttleRatio,
    'throttle_window': throttleReadings,
    'throttle_min_normal_bytes': throttleMinNormal,
    'throttle_cooldown_seconds': throttleCooldown.inSeconds,
  };
}
