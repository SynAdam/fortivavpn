import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// When the reports waiting on the phone get another try, besides the
/// moments that already send them: a cold start, a new event, a late
/// register.
///
/// Those moments were not enough. A phone on a home line could not send a
/// failure event, and nothing from it arrived for hours, until it reached
/// us over another network. A tap that finds every door closed writes no
/// event, so between cold starts nothing tried to send its door checks
/// again, and nothing tried when the phone changed network. This adds
/// three more tries:
///
/// * a return to the foreground, the moment the user looks again;
/// * every [interval] while the app is in the foreground;
/// * a network change, in the foreground or not, because the next network
///   may carry what the last one cut.
///
/// A try with nothing waiting reads the stored queues and sends nothing.
class ReportSchedule {
  ReportSchedule({
    required Future<void> Function() flush,
    Stream<Object?>? networkChanges,
    this.interval = defaultInterval,
    this.settle = defaultSettle,
  }) : _flush = flush,
       _networkChanges = networkChanges ?? _connectivityChanges();

  /// How often the waiting reports are tried while the app is open. The
  /// heartbeat's period: often enough that a phone with the app open gets
  /// about a dozen tries inside the backend's 60 minute stuck window. On a
  /// line that cuts every upload, each try fails about two uploads (one
  /// door-check upload and one events batch, each tried on every route at
  /// 10 seconds a route), so about 24 failed uploads an hour while the app
  /// is open, and more when a report is queued during a try and the run
  /// goes round again (VpnEventReporter.maxRounds).
  static const defaultInterval = Duration(minutes: 5);

  /// How long after a network change the try waits. A switch arrives as a
  /// burst of changes, and the new network needs a moment before it
  /// carries traffic. Each change in the burst restarts the wait, so the
  /// burst makes one try.
  static const defaultSettle = Duration(seconds: 3);

  final Future<void> Function() _flush;
  final Stream<Object?> _networkChanges;
  final Duration interval;
  final Duration settle;

  StreamSubscription<Object?>? _changes;
  Timer? _timer;
  Timer? _settling;
  bool _disposed = false;

  static Stream<Object?> _connectivityChanges() {
    try {
      return Connectivity().onConnectivityChanged;
    } catch (e) {
      debugPrint('ReportSchedule: cannot watch the network: $e');
      return const Stream.empty();
    }
  }

  /// Start listening for network changes, and start the timer as if the
  /// app had just come to the foreground.
  void start() {
    if (_disposed || _changes != null) return;
    _changes = _networkChanges.listen(
      (_) => _networkChanged(),
      onError: (Object e) =>
          debugPrint('ReportSchedule: network watch failed: $e'),
    );
    foreground();
  }

  /// The app is in front of the user: try now, then every [interval].
  void foreground() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _try());
    _try();
  }

  /// The app went to the background. Network changes still trigger a try.
  void background() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _settling?.cancel();
    unawaited(_changes?.cancel());
  }

  void _networkChanged() {
    if (_disposed) return;
    _settling?.cancel();
    _settling = Timer(settle, _try);
  }

  void _try() {
    if (_disposed) return;
    unawaited(
      _flush().catchError((Object e) {
        debugPrint('ReportSchedule: flush failed: $e');
      }),
    );
  }
}
