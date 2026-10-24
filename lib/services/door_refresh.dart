import 'dart:async';

import 'package:flutter/foundation.dart';

/// Fetches this device's own servers again while a tunnel stays up.
///
/// A fresh IPv4 door address can be blocked within hours, and the backend
/// then moves the door to a new address. A phone holds the links it fetched
/// at launch, or after its last failed connect, for as long as the app
/// runs. A session of a few hours therefore ends holding addresses that
/// have since been replaced, and the next tap starts on them: the
/// remembered door fails, the checklist goes through the rest of the stale
/// addresses, and only that failure makes the app ask for its servers
/// again. A tap that finds every door closed is also one of the slowest.
///
/// So while a tunnel is up, [refresh] runs every [interval]. The call goes
/// the way every API call does, around the tunnel first, so the backend
/// orders the doors for the phone's own network when it can. The tunnel in
/// use is not touched: the new links are what the next tap dials.
class DoorRefresh {
  DoorRefresh({
    required Future<void> Function() refresh,
    this.interval = defaultInterval,
  }) : _refresh = refresh;

  /// Often enough to catch most moves within a session, and one call per
  /// connected phone that often costs the backend nothing it notices.
  static const defaultInterval = Duration(minutes: 45);

  final Future<void> Function() _refresh;
  final Duration interval;
  Timer? _timer;
  bool _running = false;

  /// Whether a tunnel is up and the timer runs.
  bool get active => _timer != null;

  /// A tunnel came up: start the timer, unless it runs already.
  void connected() {
    _timer ??= Timer.periodic(interval, (_) => _tick());
  }

  /// The tunnel went down: stop. A fetch already on its way finishes.
  void disconnected() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => disconnected();

  Future<void> _tick() async {
    // One at a time: a slow network must not stack them up.
    if (_running) return;
    _running = true;
    try {
      await _refresh();
    } catch (e) {
      debugPrint('DoorRefresh: could not fetch the servers again ($e)');
    } finally {
      _running = false;
    }
  }
}
