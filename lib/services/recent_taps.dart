import 'connect_trace.dart';

/// One tap on Connect, as [RecentTaps] keeps it.
class RecentTap {
  RecentTap._(this.began);

  /// When the tap began, on the phone's clock.
  final DateTime began;

  /// When it ended, and how. Both null while it runs.
  DateTime? ended;
  TraceOutcome? outcome;
}

/// How this phone's latest taps on Connect ended, in memory only, for the
/// support chat (clients C4 of the plan of 2026-10-23).
///
/// The chat's facts count the taps whose connect traces reached the
/// backend (taps_2h). A stuck phone sends its traces late: on 10-23 the
/// facts would have shown 10 of 18 taps for one stuck phone and 0 of 3 for
/// another. The app knows at once, so a message carries these too
/// (`recent_taps`), and the backend counts them beside the traces.
///
/// One entry per run of the connect flow: a tap, a pick of another server,
/// a try after a wait, the search after a dead tunnel. Each gets its
/// outcome when it ends, the same word its trace gets, whether or not the
/// backend has the trace on. VpnService.onOutcome is not the source: it
/// hears connects, failures and drops only, and misses the taps the facts
/// miss (stopped, no internet, nothing open).
///
/// Counts and seconds only: no door, no server, no address. Which taps are
/// recent enough to count, and how they are counted, a stop followed by
/// another tap within a minute included, is the backend's to decide
/// (support_context.recent_taps and recent_tap_counts), so no such number
/// lives here.
class RecentTaps {
  RecentTaps({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// The most taps kept, the most the backend reads.
  static const keep = 20;

  final DateTime Function() _clock;

  /// Oldest first.
  final List<RecentTap> _taps = [];

  /// A tap began now. [ended] gives it its outcome.
  RecentTap began() {
    final tap = RecentTap._(_clock());
    _taps.add(tap);
    _trim();
    return tap;
  }

  /// [tap] ended now with [outcome]. Once only: a later call changes
  /// nothing.
  void ended(RecentTap tap, TraceOutcome outcome) {
    if (tap.outcome != null) return;
    tap
      ..ended = _clock()
      ..outcome = outcome;
  }

  /// The taps as the message's `recent_taps`, newest first: `ago_s`, the
  /// seconds since it began, `took_s`, how long it ran (to now for a tap
  /// still running), and `outcome`, the trace's word for how it ended, left
  /// out for a tap still running.
  ///
  /// A tap that began after now on the phone's clock is left out: the
  /// clock moved back since, as when the network corrects a wrong clock,
  /// and its real age is not known. Sent as 0 seconds old, it would count
  /// as a tap of this moment. The clock is the phone's because Dart's
  /// Stopwatch reads a monotonic clock, which on Android does not count
  /// the time the phone sleeps, so a tap made before the phone slept would
  /// read younger than it is.
  List<Map<String, Object>> toContext() {
    final now = _clock();
    return [
      for (final tap in _taps.reversed)
        if (!tap.began.isAfter(now))
          {
            'ago_s': _seconds(now.difference(tap.began)),
            'took_s': _seconds((tap.ended ?? now).difference(tap.began)),
            if (tap.outcome case final outcome?) 'outcome': outcome.wire,
          },
    ];
  }

  static int _seconds(Duration d) => d.isNegative ? 0 : d.inSeconds;

  void _trim() {
    while (_taps.length > keep) {
      _taps.removeAt(0);
    }
  }
}
