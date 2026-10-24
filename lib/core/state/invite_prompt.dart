import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/invite_prompt_rules.dart';
import '../../services/vpn_event_reporter.dart';
import 'review_prompt.dart';

/// The invite card on the home screen: "Is Fortiva working well for you?
/// Send it to a friend", shown after good connection days, and rarely.
///
/// It keeps its own record of good days (Tehran days with a verified
/// connect), seeded once from the rating card's, which keeps only its latest
/// few. Every number that decides when it shows comes from the backend
/// (InvitePromptRules, the register answer's `invite_prompt`). With no block
/// the card never shows.
///
/// The home screen checks the rest: a calm screen, a checked tunnel, nothing
/// else shown in this run, and the rating card and the Premium card first.
/// The rating card and this card never share a run or a Tehran day, and
/// neither reads the other's answers.
///
/// Nothing here may get in the way of connecting. Every failure is caught
/// and logged.
class InvitePrompt extends ChangeNotifier {
  InvitePrompt({
    DateTime Function()? clock,
    Future<SharedPreferences> Function()? prefs,
  }) : _clock = clock ?? DateTime.now,
       _prefs = prefs ?? SharedPreferences.getInstance {
    unawaited(_loadFirst());
  }

  /// Where the record lives: good days, the last failure, the shows, and
  /// whether a share ended the card. Cleared when the account is deleted.
  static const inviteStateKey = 'invite_prompt_state';

  final DateTime Function() _clock;
  final Future<SharedPreferences> Function() _prefs;

  bool _shownThisRun = false;
  bool _hadGoodDay = false;
  bool _disposed = false;

  /// The last queued change to the saved record. See [_update].
  Future<void> _writing = Future.value();

  /// Whether the card showed in this run of the app. Nothing else pops up
  /// after it in the same run.
  bool get shownThisRun => _shownThisRun;

  /// Whether this install has had a verified connect on any day. False
  /// until the record has loaded.
  bool get hadGoodDay => _hadGoodDay;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _loadFirst() async {
    await _update((_) {});
    await _writing;
    try {
      final state = await _read();
      if (state.goodDays > 0 && !_hadGoodDay) {
        _hadGoodDay = true;
      }
    } catch (e) {
      debugPrint('InvitePrompt: could not load ($e)');
    }
    _notify();
  }

  /// Note one tunnel outcome. Called with the rating card's, from
  /// VpnService.onOutcome.
  void record(VpnEventType type) {
    final failed =
        type == VpnEventType.connectFailed ||
        type == VpnEventType.verifyFailed ||
        type == VpnEventType.dropped;
    if (type != VpnEventType.connected && !failed) return;
    final now = _clock();
    unawaited(
      _update((state) {
        if (failed) {
          state.failedAt = now;
          return;
        }
        final day = ReviewPrompt.tehranDay(now);
        if (state.lastGoodDay != day) {
          state.goodDays += 1;
          state.lastGoodDay = day;
        }
      }),
    );
    if (!failed && !_hadGoodDay) {
      _hadGoodDay = true;
      _notify();
    }
  }

  /// The Tehran day the card last showed, or null.
  Future<String?> lastShownDay() async {
    try {
      await _writing;
      return (await _read()).lastShownDay;
    } catch (e) {
      debugPrint('InvitePrompt: could not read ($e)');
      return null;
    }
  }

  /// Whether the card may show now, as far as the backend's rules and the
  /// record go. [upSince] is when the current tunnel came up, and
  /// [ratingAskDay] the Tehran day the rating card was last asked for. The
  /// screen checks the rest. Never throws.
  Future<bool> due({
    required InvitePromptRules? rules,
    required DateTime? upSince,
    required String? ratingAskDay,
  }) async {
    try {
      if (rules == null || _shownThisRun || upSince == null) return false;
      final now = _clock();
      if (now.difference(upSince) <
          Duration(minutes: rules.minSessionMinutes)) {
        return false;
      }
      if (ratingAskDay != null && ratingAskDay == ReviewPrompt.tehranDay(now)) {
        return false;
      }
      await _writing;
      final state = await _read();
      if (state.done) return false;
      if (state.goodDays < rules.minGoodDays) return false;
      if (state.shows >= rules.maxShows) return false;
      final failed = state.failedAt;
      if (failed != null &&
          now.difference(failed) <
              Duration(hours: rules.quietAfterFailureHours)) {
        return false;
      }
      final last = state.lastShownAt;
      if (last != null &&
          now.difference(last) < Duration(days: rules.everyDays)) {
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('InvitePrompt: could not decide ($e)');
      return false;
    }
  }

  /// The card is on screen. Counted at once, so an app that dies while it
  /// is up never shows it twice in a row.
  Future<void> shown() async {
    if (_shownThisRun) return;
    _shownThisRun = true;
    _notify();
    final now = _clock();
    await _update((state) {
      state.shows += 1;
      state.lastShownAt = now;
      state.lastShownDay = ReviewPrompt.tehranDay(now);
    });
  }

  /// A share or copy on the card or the invite screen: the card never
  /// shows again.
  Future<void> shared() => _update((state) => state.done = true);

  /// Change the saved record. Queued behind earlier changes, so two
  /// outcomes reported together never read the same old record and lose
  /// one of them. Never throws.
  Future<void> _update(void Function(_Record state) change) {
    return _writing = _writing.then((_) async {
      try {
        final state = await _read();
        change(state);
        await _write(state);
      } catch (e) {
        debugPrint('InvitePrompt: could not save ($e)');
      }
    });
  }

  /// The saved record. The first read seeds the good days from the rating
  /// card's record (ReviewPrompt.stateKey), which keeps its latest few.
  Future<_Record> _read() async {
    final prefs = await _prefs();
    final raw = prefs.getString(inviteStateKey);
    _Record state;
    if (raw == null) {
      state = _Record();
    } else {
      try {
        state = _Record.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('InvitePrompt: unreadable state, starting over ($e)');
        state = _Record();
      }
    }
    if (!state.seeded) {
      _seed(state, prefs.getString(ReviewPrompt.stateKey));
      state.seeded = true;
    }
    return state;
  }

  static void _seed(_Record state, String? review) {
    if (review == null) return;
    try {
      final json = jsonDecode(review);
      final days = [
        for (final d in (json is Map ? json['days'] : null) as List? ?? [])
          if (d is String) d,
      ]..sort();
      if (days.isEmpty) return;
      state.goodDays = days.length;
      state.lastGoodDay = days.last;
    } catch (e) {
      debugPrint('InvitePrompt: rating record unreadable ($e)');
    }
  }

  Future<void> _write(_Record state) async {
    final prefs = await _prefs();
    await prefs.setString(inviteStateKey, jsonEncode(state.toJson()));
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// What is kept between runs.
class _Record {
  _Record({
    this.goodDays = 0,
    this.lastGoodDay,
    this.failedAt,
    this.shows = 0,
    this.lastShownAt,
    this.lastShownDay,
    this.done = false,
    this.seeded = false,
  });

  int goodDays;
  String? lastGoodDay;
  DateTime? failedAt;
  int shows;
  DateTime? lastShownAt;
  String? lastShownDay;
  bool done;
  bool seeded;

  factory _Record.fromJson(Map<String, dynamic> json) => _Record(
    goodDays: json['good_days'] is int ? json['good_days'] as int : 0,
    lastGoodDay: json['last_good_day'] is String
        ? json['last_good_day'] as String
        : null,
    failedAt: _time(json['failed_at']),
    shows: json['shows'] is int ? json['shows'] as int : 0,
    lastShownAt: _time(json['last_shown_at']),
    lastShownDay: json['last_shown_day'] is String
        ? json['last_shown_day'] as String
        : null,
    done: json['done'] == true,
    seeded: json['seeded'] == true,
  );

  Map<String, dynamic> toJson() => {
    'good_days': goodDays,
    'last_good_day': ?lastGoodDay,
    if (failedAt != null) 'failed_at': failedAt!.millisecondsSinceEpoch,
    'shows': shows,
    if (lastShownAt != null)
      'last_shown_at': lastShownAt!.millisecondsSinceEpoch,
    'last_shown_day': ?lastShownDay,
    'done': done,
    'seeded': seeded,
  };

  static DateTime? _time(Object? v) =>
      v is int ? DateTime.fromMillisecondsSinceEpoch(v) : null;
}
