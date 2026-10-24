import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/billing.dart';
import 'billing_state.dart';

/// The calm Premium card on the home screen: one quiet offer, shown only
/// after a connection has worked, and rarely.
///
/// It follows the rating card's rules (see ReviewPrompt): the tunnel is up
/// and checked, nothing else is on screen or waiting, no message popped up
/// and no rating card was asked for in this run, and the allowance is not
/// spent. The home screen checks those. This decides the rest from the
/// backend's numbers: the card is on for this device
/// (BillingState.upsellOn), the last card was at least
/// Upsell.promptEveryHours ago, and fewer than Upsell.promptMax have been
/// shown. With either number missing it never shows.
///
/// Once the device has Premium, from a purchase, a key or a gift, the card
/// never shows again, even after Premium ends.
///
/// Nothing here may get in the way of connecting. Every failure is caught
/// and logged.
class PremiumPrompt extends ChangeNotifier {
  PremiumPrompt({
    BillingState? billing,
    DateTime Function()? clock,
    Future<SharedPreferences> Function()? prefs,
  }) : _billing = billing,
       _clock = clock ?? DateTime.now,
       _prefs = prefs ?? SharedPreferences.getInstance {
    billing?.addListener(_billingChanged);
    _billingChanged();
  }

  /// When the last card showed, how many have, and whether Premium ended
  /// them for good: `{last: ISO, count: int, done: bool}`. Cleared when the
  /// account is deleted.
  static const premiumStateKey = 'premium_prompt_state';

  final BillingState? _billing;
  final DateTime Function() _clock;
  final Future<SharedPreferences> Function() _prefs;

  bool _shownThisRun = false;
  bool _doneNoted = false;

  /// The last queued change to the saved record. See [_update].
  Future<void> _writing = Future.value();

  /// Whether the card showed in this run of the app. Nothing else pops up
  /// after it in the same run.
  bool get shownThisRun => _shownThisRun;

  void _billingChanged() {
    final billing = _billing;
    if (billing == null || _doneNoted || !billing.premium.active) return;
    _doneNoted = true;
    unawaited(_update((state) => state.done = true));
  }

  /// Whether the card may show now, as far as the backend and the record
  /// go. The screen checks the rest. Never throws.
  Future<bool> due(BillingState billing) async {
    try {
      if (_shownThisRun || !billing.upsellOn(UpsellSurface.calmCard)) {
        return false;
      }
      final every = billing.upsell?.promptEveryHours;
      final most = billing.upsell?.promptMax;
      if (every == null || most == null) return false;
      await _writing;
      final state = await _read();
      if (state.done || state.count >= most) return false;
      final last = state.last;
      if (last != null && _clock().difference(last) < Duration(hours: every)) {
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('PremiumPrompt: could not decide ($e)');
      return false;
    }
  }

  /// The card is on screen. Counted at once, so an app that dies while it
  /// is up never shows it twice in a row.
  Future<void> shown() async {
    if (_shownThisRun) return;
    _shownThisRun = true;
    notifyListeners();
    final now = _clock();
    await _update((state) {
      state.count += 1;
      state.last = now;
    });
  }

  /// Change the saved record. Queued behind earlier changes. Never throws.
  Future<void> _update(void Function(_Record state) change) {
    return _writing = _writing.then((_) async {
      try {
        final state = await _read();
        change(state);
        await _write(state);
      } catch (e) {
        debugPrint('PremiumPrompt: could not save ($e)');
      }
    });
  }

  Future<_Record> _read() async {
    final prefs = await _prefs();
    final raw = prefs.getString(premiumStateKey);
    if (raw == null) return _Record();
    try {
      return _Record.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('PremiumPrompt: unreadable state, starting over ($e)');
      return _Record();
    }
  }

  Future<void> _write(_Record state) async {
    final prefs = await _prefs();
    await prefs.setString(premiumStateKey, jsonEncode(state.toJson()));
  }

  @override
  void dispose() {
    _billing?.removeListener(_billingChanged);
    super.dispose();
  }
}

/// What is kept between runs.
class _Record {
  _Record({this.last, this.count = 0, this.done = false});

  DateTime? last;
  int count;
  bool done;

  factory _Record.fromJson(Map<String, dynamic> json) {
    final last = json['last'];
    final count = json['count'];
    return _Record(
      last: last is String ? DateTime.tryParse(last) : null,
      count: count is int ? count : 0,
      done: json['done'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    if (last != null) 'last': last!.toUtc().toIso8601String(),
    'count': count,
    'done': done,
  };
}
