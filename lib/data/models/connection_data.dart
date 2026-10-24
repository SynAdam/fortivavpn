/// What the backend asks the phone to measure about its connections, from
/// the app config's `connection_data` block (backend issue #365).
///
/// - [timedChecks]: check doors with the core's timed check
///   (`Fortivacore.checkDoorTimed`), which also says how far a check got:
///   the TCP connect, the first byte back, the reply, bytes each way.
/// - [networkKeys]: tell Wi-Fi networks apart on the phone, so the door that
///   worked is remembered per network instead of once for every Wi-Fi.
/// - [networkKeyPeriod]: how long one network's key sent to the backend
///   stays the same before it changes. Null sends no key.
/// - [sessionSample], [stallAfter], [busyBytes]: how often the tunnel's
///   byte counters are read during a session, how long data sent with
///   nothing coming back counts as a stall, and how many bytes down in one
///   reading count it as busy. Null [sessionSample] turns the readings off.
///
/// Every number comes from the backend. A block that is missing, or a
/// value that cannot be read, turns that part off: the app has no period,
/// threshold or switch of its own to fall back on. Read without a cast, so
/// a bad value never throws away the rest of the config.
class ConnectionData {
  const ConnectionData({
    this.timedChecks = false,
    this.networkKeys = false,
    this.networkKeyPeriod,
    this.sessionSample,
    this.stallAfter,
    this.busyBytes = 0,
  });

  final bool timedChecks;
  final bool networkKeys;
  final Duration? networkKeyPeriod;
  final Duration? sessionSample;
  final Duration? stallAfter;
  final int busyBytes;

  /// Everything off: what a phone the backend has never answered runs on.
  static const off = ConnectionData();

  /// The settings in force, read by the checks, the network key and the
  /// tunnel, which live outside the widget tree. Set by AppConfigState.
  static ConnectionData current = off;

  /// Whether the session readings run: a period, and a stall length.
  bool get sessionReadings => sessionSample != null && stallAfter != null;

  static ConnectionData fromJson(Object? json) {
    if (json is! Map) return off;
    return ConnectionData(
      timedChecks: json['timed_checks'] == true,
      networkKeys: json['network_keys'] == true,
      networkKeyPeriod: _days(json['network_key_days']),
      sessionSample: _millis(json['session_sample_ms']),
      stallAfter: _millis(json['session_stall_ms']),
      busyBytes: _whole(json['session_busy_bytes']) ?? 0,
    );
  }

  static int? _whole(Object? value) => value is int && value > 0 ? value : null;

  static Duration? _days(Object? value) {
    final n = _whole(value);
    return n == null ? null : Duration(days: n);
  }

  static Duration? _millis(Object? value) {
    final n = _whole(value);
    return n == null ? null : Duration(milliseconds: n);
  }

  Map<String, dynamic> toJson() => {
    if (timedChecks) 'timed_checks': true,
    if (networkKeys) 'network_keys': true,
    if (networkKeyPeriod != null) 'network_key_days': networkKeyPeriod!.inDays,
    if (sessionSample != null)
      'session_sample_ms': sessionSample!.inMilliseconds,
    if (stallAfter != null) 'session_stall_ms': stallAfter!.inMilliseconds,
    if (busyBytes > 0) 'session_busy_bytes': busyBytes,
  };

  @override
  bool operator ==(Object other) =>
      other is ConnectionData &&
      other.timedChecks == timedChecks &&
      other.networkKeys == networkKeys &&
      other.networkKeyPeriod == networkKeyPeriod &&
      other.sessionSample == sessionSample &&
      other.stallAfter == stallAfter &&
      other.busyBytes == busyBytes;

  @override
  int get hashCode => Object.hash(
    timedChecks,
    networkKeys,
    networkKeyPeriod,
    sessionSample,
    stallAfter,
    busyBytes,
  );
}
