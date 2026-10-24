/// Whether the build a user is running is still the one we want them on.
///
/// The backend reports two versions per platform and they mean different
/// things. ``minimum_version`` is the oldest build we will still support: a
/// user below it is shown a dialog they cannot dismiss, because carrying on
/// is not something we can make work. ``latest_version`` is what is in the
/// store: a user below that is offered an update and can say later.
///
/// The comparison is deliberately forgiving. A version string that does not
/// parse means no prompt at all, never a forced one: a typo in an environment
/// variable must not be able to lock every user out of the app. For the same
/// reason a minimum newer than the latest release is not enforced, because no
/// user could ever satisfy it.
library;

enum UpdateNeed {
  /// Running the latest, or close enough that we say nothing.
  none,

  /// A newer build is in the store. Later puts the offer off until the
  /// next time the app is opened; see [UpdateOpens].
  optional,

  /// Below the minimum we support. The dialog cannot be dismissed.
  required,
}

class UpdateCheck {
  /// Compare two dotted version strings numerically.
  ///
  /// Returns a negative number when [a] is older than [b], zero when they
  /// are equal, positive when newer, and null when either cannot be read.
  /// Numeric per part, so 1.10.0 is correctly newer than 1.9.0, which a
  /// string comparison gets backwards. Missing parts count as zero, so
  /// "1.4" and "1.4.0" are the same version.
  static int? compare(String? a, String? b) {
    final left = _parts(a);
    final right = _parts(b);
    if (left == null || right == null) return null;
    for (
      var i = 0;
      i < (left.length > right.length ? left.length : right.length);
      i++
    ) {
      final l = i < left.length ? left[i] : 0;
      final r = i < right.length ? right[i] : 0;
      if (l != r) return l - r;
    }
    return 0;
  }

  static List<int>? _parts(String? value) {
    if (value == null) return null;
    // A build suffix is not part of the version: 1.4.1+41 and 1.4.1 are the
    // same release, and the store never shows the build number.
    final trimmed = value.trim().split('+').first.split('-').first;
    if (trimmed.isEmpty) return null;
    final parts = <int>[];
    for (final piece in trimmed.split('.')) {
      final n = int.tryParse(piece);
      if (n == null || n < 0) return null;
      parts.add(n);
    }
    return parts.isEmpty ? null : parts;
  }

  /// What to show the user, if anything.
  ///
  /// [serverSaysRequired] is the backend's own `update_required` flag, which
  /// is honoured even when the version maths disagrees, so a build can be
  /// pulled without waiting for a release that changes the numbers.
  ///
  /// A [minimum] newer than [latest] is a mistake in the backend's numbers,
  /// for example a minimum raised before the release reached the store. It
  /// is ignored and the user is only offered [latest], because forcing an
  /// update to a build nobody can download leaves the user with an app they
  /// cannot use and no way out of it.
  static UpdateNeed decide({
    required String? current,
    required String? latest,
    required String? minimum,
    bool serverSaysRequired = false,
  }) {
    if (_parts(current) == null) return UpdateNeed.none;

    final minimumAboveLatest = (compare(minimum, latest) ?? 0) > 0;
    final belowMinimum = compare(current, minimum);
    if (!minimumAboveLatest && belowMinimum != null && belowMinimum < 0) {
      return UpdateNeed.required;
    }
    if (serverSaysRequired) return UpdateNeed.required;

    final belowLatest = compare(current, latest);
    if (belowLatest != null && belowLatest < 0) return UpdateNeed.optional;
    return UpdateNeed.none;
  }
}

/// Which time the app has been opened, so that Later lasts until the next
/// one.
///
/// Later used to hold the optional offer back for 24 hours. On 2026-10-06
/// many devices were still on old builds, and the offer now comes back
/// every time the app is opened. Later only puts it away for the rest of
/// the current visit.
///
/// An open is a cold start, or coming back to the app after at least
/// [newOpenAfter] in the background. A quick switch to another app and back,
/// such as reading a code from a message, is the same visit, because asking
/// again then would feel like the dialog ignoring the answer it was just
/// given.
///
/// Kept in memory only. A cold start is a new open by definition, so there
/// is nothing worth saving between launches.
class UpdateOpens {
  UpdateOpens({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// How long the app has to stay in the background for coming back to be
  /// a new open.
  static const newOpenAfter = Duration(minutes: 15);

  final DateTime Function() _now;

  int _open = 0;
  int? _answeredIn;
  DateTime? _hiddenSince;

  /// The app left the foreground. Only the first call of a stay in the
  /// background counts, because Android reports several steps on the way
  /// out and the stay starts at the first.
  void wentToBackground() => _hiddenSince ??= _now();

  /// The app is back in the foreground. True when this starts a new open.
  ///
  /// A clock that moved backwards while the app was away also starts one,
  /// because the elapsed time cannot be known and asking again is the side
  /// to err on.
  bool cameBack() {
    final since = _hiddenSince;
    _hiddenSince = null;
    if (since == null) return false;
    final away = _now().difference(since);
    if (away.isNegative || away >= newOpenAfter) {
      _open++;
      return true;
    }
    return false;
  }

  /// The user answered the optional offer in this open: Later, one of the
  /// update buttons, or a tap outside the dialog.
  void optionalAnswered() => _answeredIn = _open;

  /// Whether the optional offer was already answered in this open.
  bool get optionalHeld => _answeredIn == _open;
}
