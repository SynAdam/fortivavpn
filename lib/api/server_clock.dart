import 'dart:io';

import 'package:flutter/foundation.dart';

/// The backend's clock, as far as this phone has heard it.
///
/// A phone's own clock can be hours off, by mistake or on purpose: setting
/// it a day ahead is a known way to try to get round a daily limit. Times
/// the backend sends (when an allowance refills, when a relay list or the
/// fallback file was made) are compared with this instead, once any answer
/// from the backend has carried its time. Until then it is the phone's own
/// clock.
///
/// Kept as the backend's time when it was heard plus a monotonic stopwatch
/// since, not as an offset from the phone's clock, so changing the phone's
/// clock afterwards does not move it.
class ServerClock {
  ServerClock._();

  static DateTime? _heardAt;
  static Duration _phoneOffset = Duration.zero;
  static final Stopwatch _since = Stopwatch();

  /// Whether an answer from the backend has given its time in this run.
  static bool get known => _heardAt != null;

  /// How far the backend's clock was ahead of this phone's when it was
  /// heard, or zero while no answer has said. For turning a time this phone
  /// stamped back then into the backend's time.
  static Duration get offset => _phoneOffset;

  /// Take the time from an answer's Date header, read at [phoneNow]. A
  /// header that cannot be read is ignored.
  static void heard(String? dateHeader, DateTime phoneNow) {
    if (dateHeader == null) return;
    try {
      final server = HttpDate.parse(dateHeader);
      _heardAt = server;
      _phoneOffset = server.difference(phoneNow.toUtc());
      _since
        ..reset()
        ..start();
    } catch (_) {}
  }

  /// The backend's time now, in UTC, or [phone] (by default this phone's
  /// clock) while nothing has been heard.
  ///
  /// The stopwatch does not run while the phone sleeps, so after a night
  /// asleep this can be hours behind. That only makes a time stamped with
  /// it earlier than it was. For a deadline, use [notBefore].
  static DateTime now([DateTime? phone]) {
    final heardAt = _heardAt;
    if (heardAt == null) return (phone ?? DateTime.now()).toUtc();
    return heardAt.add(_since.elapsed);
  }

  /// The backend's time now for deciding whether a deadline has passed:
  /// the later of [now] and the phone's clock turned into the backend's.
  ///
  /// [now] alone stops while the phone sleeps, and a phone cut off from us
  /// that slept past its allowance's reset time would stay blocked for as
  /// many hours as it slept. The phone's clock does count sleep. A clock
  /// moved forward by hand can end a block early this way, but only for an
  /// answer the backend could not confirm since, and only for the shared
  /// links: the backend meters our own servers itself.
  static DateTime notBefore([DateTime? phone]) {
    final byPhone = (phone ?? DateTime.now()).toUtc().add(offset);
    final heard = now(phone);
    return byPhone.isAfter(heard) ? byPhone : heard;
  }

  @visibleForTesting
  static void resetForTest() {
    _heardAt = null;
    _phoneOffset = Duration.zero;
    _since
      ..stop()
      ..reset();
  }
}
