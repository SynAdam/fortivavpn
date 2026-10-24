import 'package:flutter/foundation.dart';

import '../data/models/app_config.dart';
import 'state/app_config_state.dart';
import 'update_check.dart';

/// When to check the running build against the backend's version rules.
///
/// The check used to run once per launch, and only when the launch fetch
/// landed. An app sent to the background and brought back is not launched
/// again, so a minimum raised in between did not reach that user until the
/// app was closed for good. Now the check runs at launch and on every
/// return to the foreground.
///
/// Each time, the check runs first on the rules already on the phone, and
/// again once a fetch has ended. A phone whose every route to us is
/// blocked spends over a minute failing through the fetch's retries, and
/// the saved rules exist for exactly that phone, so they must not wait for
/// the fetch.
///
/// A return to the foreground fetches the config again only when the copy
/// in hand is older than [configFreshFor], so a minimum raised a minute ago
/// is seen without a fetch on every app switch. A fetch that fails leaves
/// the rules [AppConfigState] kept from the last one that landed.
class UpdateGate {
  UpdateGate({
    required AppConfigState config,
    required Future<void> Function(ForceUpdate? rules) check,
    required UpdateOpens opens,
    DateTime Function()? now,
  }) : _config = config,
       _check = check,
       _opens = opens,
       _now = now ?? DateTime.now;

  /// How old the config can be before a return to the foreground fetches
  /// it again.
  static const configFreshFor = Duration(minutes: 5);

  final AppConfigState _config;
  final Future<void> Function(ForceUpdate? rules) _check;
  final UpdateOpens _opens;
  final DateTime Function() _now;

  /// The app has launched and [fetching] is the launch fetch. Checks on the
  /// rules saved by an earlier launch at once, and again when [fetching]
  /// has ended, landed or not. A phone the backend has never answered has
  /// no saved rules, and only the second check runs.
  Future<void> launched(Future<void> fetching) async {
    await _config.restoreSaved();
    if (_config.versionRules != null) await _run();
    await fetching;
    await _run();
  }

  /// The app left the foreground.
  void hidden() => _opens.wentToBackground();

  /// The app is back in the foreground.
  Future<void> resumed() async {
    _opens.cameBack();
    await _run();
    if (!isStale(_config.loadedAt, _now())) return;
    // Retries inside, and never throws. A fetch that fails leaves the rules
    // from the last one that landed, which the check then uses again.
    await _config.load();
    await _run();
  }

  Future<void> _run() async {
    try {
      await _check(_config.versionRules);
    } catch (e) {
      debugPrint('UpdateGate: the update check failed ($e)');
    }
  }

  /// Whether a config fetched at [loadedAt] is too old to trust at [now].
  /// Never fetched is stale, and so is a time in the future, which means
  /// the clock moved back. The size probe asks the same before it runs.
  static bool isStale(DateTime? loadedAt, DateTime now) {
    if (loadedAt == null) return true;
    final age = now.difference(loadedAt);
    return age.isNegative || age >= configFreshFor;
  }
}
