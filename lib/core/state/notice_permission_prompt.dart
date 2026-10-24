import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/notice_channel.dart';
import '../form_factor.dart';

/// When the app asks Android for permission to show messages from the
/// Fortiva team as notifications, and how a user turns them on later.
///
/// Android 13 and later show no notification from an app until the user
/// allows it, so without this no message reaches the shade there. The app
/// asks by itself at most [maxAsks] times, [askAgainAfter] apart, at a calm
/// moment HomeScreen picks: a user who closed the dialog or said no once is
/// asked once more on a later day, as Android allows. The Settings row and
/// the card on the Messages screen ([turnOn]) stay for anyone who wants
/// them on later.
class NoticePermissionPrompt {
  NoticePermissionPrompt({
    Future<NoticePermission> Function()? permission,
    Future<NoticePermission> Function()? ask,
    Future<bool> Function()? rationale,
    Future<bool> Function()? openSettings,
    Future<SharedPreferences> Function()? prefs,
    bool Function()? isTv,
    DateTime Function()? now,
  }) : _permission = permission ?? NoticeChannel.permission,
       _ask = ask ?? NoticeChannel.askPermission,
       _rationale = rationale ?? NoticeChannel.rationale,
       _openSettings = openSettings ?? NoticeChannel.openSettings,
       _prefs = prefs ?? SharedPreferences.getInstance,
       _isTv = isTv ?? (() => FormFactor.isTv),
       _now = now ?? DateTime.now;

  static NoticePermissionPrompt instance = NoticePermissionPrompt();

  /// How many times the app showed Android's dialog by itself.
  static const asksKey = 'notices_permission_asks';

  /// When it last did, in UTC.
  static const lastAskKey = 'notices_permission_last_ask';

  /// Two, because Android shows its dialog at most twice: after a second
  /// "Don't allow" it answers at once without asking.
  static const maxAsks = 2;

  /// A user who closed the dialog without answering, or said no once, is
  /// asked again after this long, not in the same week's every run.
  static const askAgainAfter = Duration(days: 3);

  final Future<NoticePermission> Function() _permission;
  final Future<NoticePermission> Function() _ask;
  final Future<bool> Function() _rationale;
  final Future<bool> Function() _openSettings;
  final Future<SharedPreferences> Function() _prefs;
  final bool Function() _isTv;
  final DateTime Function() _now;

  bool _askedThisRun = false;
  bool _settled = false;

  /// Whether the question was asked in this run, by the app or from the
  /// user's tap. Nothing else pops up after it in the same run.
  bool get askedThisRun => _askedThisRun;

  /// Whether [due] has said no for the rest of this run.
  bool get settledThisRun => _settled;

  /// Whether the app may ask by itself now. Once it says no, it says no for
  /// the rest of the run, so the screen does not ask Android again on every
  /// change of the tunnel's state. Never throws.
  Future<bool> due() async {
    if (_askedThisRun || _settled) return false;
    try {
      // A TV has no shade to speak of, and its remote is awkward on the
      // system dialog.
      if (_isTv()) return _settle();
      final prefs = await _prefs();
      final asks = prefs.getInt(asksKey) ?? 0;
      if (asks >= maxAsks) return _settle();
      final last = DateTime.tryParse(prefs.getString(lastAskKey) ?? '');
      if (asks > 0 &&
          last != null &&
          _now().toUtc().difference(last) < askAgainAfter) {
        return _settle();
      }
      if (await _permission() != NoticePermission.ask) return _settle();
      return true;
    } catch (e) {
      debugPrint('NoticePermissionPrompt: could not tell ($e)');
      return _settle();
    }
  }

  bool _settle() {
    _settled = true;
    return false;
  }

  /// Show Android's dialog and return what it says afterwards. The ask is
  /// counted before the dialog shows, so a crash or a killed app does not
  /// ask more often. Allowed, or off in the system settings, ends the app's
  /// own asking; closed or refused leaves the second ask for a later day.
  /// Never throws.
  Future<NoticePermission> ask() async {
    _askedThisRun = true;
    _settled = true;
    try {
      final prefs = await _prefs();
      await prefs.setInt(asksKey, (prefs.getInt(asksKey) ?? 0) + 1);
      await prefs.setString(lastAskKey, _now().toUtc().toIso8601String());
      final answer = await _ask();
      if (answer != NoticePermission.ask) await prefs.setInt(asksKey, maxAsks);
      return answer;
    } catch (e) {
      debugPrint('NoticePermissionPrompt: could not ask ($e)');
      return NoticePermission.denied;
    }
  }

  /// For the Settings row and the Messages card: turn notifications on as
  /// far as the app can. Shows Android's dialog when it still would (never
  /// asked, or refused once), else opens the system page for this app's
  /// notifications, where the user can turn them on whatever they answered
  /// before. Returns the state before the system page opens, so the caller
  /// reads it again when the app comes back. Never throws.
  Future<NoticePermission> turnOn() =>
      _turningOn ??= _turnOn().whenComplete(() => _turningOn = null);

  /// A tap while Android's dialog or the system page is up waits for the
  /// same answer, rather than counting a second ask or opening the page
  /// over the dialog.
  Future<NoticePermission>? _turningOn;

  Future<NoticePermission> _turnOn() async {
    try {
      final state = await _permission();
      if (state == NoticePermission.granted) return state;
      if (state == NoticePermission.ask) {
        // Android's dialog shows when the app never asked, or the user
        // refused once. Otherwise it may not: after a second refusal
        // Android answers without one, and the system page is the way.
        final prefs = await _prefs();
        final neverAsked = (prefs.getInt(asksKey) ?? 0) == 0;
        if (neverAsked || await _rationale()) return ask();
      }
      _askedThisRun = true;
      await _openSettings();
      return state;
    } catch (e) {
      debugPrint('NoticePermissionPrompt: could not turn them on ($e)');
      return NoticePermission.denied;
    }
  }
}
