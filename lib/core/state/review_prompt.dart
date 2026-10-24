import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/vpn_event_reporter.dart';
import '../../services/tunnel_channels.dart';

/// Asks people the app works for to rate it on Google Play, through Play's
/// own in-app review card. See NimusAI/fortiva-vpn-clients#191.
///
/// Google's rules decide most of the shape. Nothing is shown before the
/// card and nothing asks how the user feels about the app, because Google
/// forbids both. The card is never behind a button either: the Settings
/// item opens the store listing instead.
///
/// What keeps unhappy users from being asked is when this fires: only on a
/// Play install, only after verified connects on several different days,
/// never within a day of a failed attempt or a drop, and only once the
/// current tunnel has been up for a while. Play never says whether the card
/// appeared or what the user chose, so this counts asks, not ratings, and
/// stops after a few.
///
/// Nothing here may get in the way of connecting. Every failure is caught
/// and logged, and the outcome hook only writes to preferences.
class ReviewPrompt extends ChangeNotifier {
  ReviewPrompt({
    Future<String?> Function()? installer,
    Future<Object?> Function()? request,
    Future<bool> Function()? openListing,
    DateTime Function()? clock,
    Future<SharedPreferences> Function()? prefs,
  }) : _installer = installer ?? _platformInstaller,
       _request = request ?? _platformRequest,
       _openListing = openListing ?? _platformOpenListing,
       _clock = clock ?? DateTime.now,
       _prefs = prefs ?? SharedPreferences.getInstance {
    unawaited(_resolveInstaller());
  }

  /// Where the record of good days, the last failure and the asks lives.
  static const stateKey = 'review_prompt_state';

  /// The package that installs from Google Play. Only an account that
  /// installed the app from Play can rate it, so any other installer (the
  /// channel APK, a file manager) never gets the card.
  static const playInstaller = 'com.android.vending';

  /// Different Tehran days with a verified connect before the first ask.
  /// Connects come in bursts (retries, server switches), so counting
  /// connects would ask on the first day; days pick people who came back.
  static const minDays = 3;

  /// How long after a failed attempt or a drop nothing is asked.
  static const quietAfterFailure = Duration(hours: 24);

  /// How long the current tunnel must have been up before an ask.
  static const minSession = Duration(minutes: 5);

  /// The shortest gap between two asks. Play shows the card at most about
  /// once a month and says nothing when it does not, so asking more often
  /// spends nothing but the chance to ask at a better time.
  static const askGap = Duration(days: 90);

  /// Asks per install, ever.
  static const maxAsks = 3;

  static final _channel = TunnelChannels.method;

  final Future<String?> Function() _installer;
  final Future<Object?> Function() _request;
  final Future<bool> Function() _openListing;
  final DateTime Function() _clock;
  final Future<SharedPreferences> Function() _prefs;

  bool? _fromPlay;
  bool _askedThisRun = false;

  /// The last queued change to the saved record. See [_update].
  Future<void> _writing = Future.value();

  /// Whether this install came from Google Play. False until known.
  bool get fromPlay => _fromPlay ?? false;

  /// Whether the card was asked for in this run of the app. Nothing else
  /// pops up after it in the same run.
  bool get askedThisRun => _askedThisRun;

  /// The calendar day in Tehran, which is how every Fortiva report counts
  /// days. Iran has kept UTC+3:30 all year since 2022.
  static String tehranDay(DateTime t) => t
      .toUtc()
      .add(const Duration(hours: 3, minutes: 30))
      .toIso8601String()
      .substring(0, 10);

  Future<void> _resolveInstaller() async {
    try {
      _fromPlay = await _installer() == playInstaller;
    } catch (e) {
      debugPrint('ReviewPrompt: installer unknown ($e)');
      _fromPlay = false;
    }
    notifyListeners();
  }

  /// Note one tunnel outcome. Set as VpnService.onOutcome.
  void record(VpnEventType type) {
    final failed =
        type == VpnEventType.connectFailed ||
        type == VpnEventType.verifyFailed ||
        type == VpnEventType.dropped;
    if (type != VpnEventType.connected && !failed) return;
    final now = _clock();
    _update((state) {
      if (failed) {
        state.failedAt = now;
        return;
      }
      final day = tehranDay(now);
      if (!state.days.contains(day)) state.days.add(day);
      // Only whether there have been enough is ever read.
      while (state.days.length > minDays) {
        state.days.removeAt(0);
      }
    });
  }

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
        debugPrint('ReviewPrompt: could not save ($e)');
      }
    });
  }

  /// Whether this install may be asked now, as far as the record goes.
  /// [upSince] is when the current tunnel came up; the screen checks the
  /// rest (on screen, calm, nothing else showing).
  Future<bool> due({required bool enabled, required DateTime? upSince}) async {
    try {
      if (!enabled || _askedThisRun || upSince == null) return false;
      if (_fromPlay == null) await _resolveInstaller();
      if (!fromPlay) return false;
      final now = _clock();
      if (now.difference(upSince) < minSession) return false;
      await _writing;
      final state = await _read();
      if (state.days.length < minDays) return false;
      if (state.asks >= maxAsks) return false;
      final asked = state.askedAt;
      if (asked != null && now.difference(asked) < askGap) return false;
      final failed = state.failedAt;
      if (failed != null && now.difference(failed) < quietAfterFailure) {
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('ReviewPrompt: could not decide ($e)');
      return false;
    }
  }

  /// The Tehran day the card was last asked for, or null. The home screen
  /// reads it so the invite card never shows on that day. Never throws.
  Future<String?> lastAskDay() async {
    try {
      await _writing;
      final asked = (await _read()).askedAt;
      return asked == null ? null : tehranDay(asked);
    } catch (e) {
      debugPrint('ReviewPrompt: could not read ($e)');
      return null;
    }
  }

  /// Ask Play for the card. The ask is counted before the call, so an app
  /// that dies while the card is up never asks twice in a row.
  Future<void> ask() async {
    if (_askedThisRun) return;
    _askedThisRun = true;
    final now = _clock();
    await _update((state) {
      state.asks += 1;
      state.askedAt = now;
    });
    try {
      final answer = await _request();
      debugPrint('ReviewPrompt: asked ($answer)');
    } catch (e) {
      debugPrint('ReviewPrompt: ask failed ($e)');
    }
  }

  /// Open the store listing, for the Settings item. Never the card: Google
  /// says a button must go to the store.
  Future<void> openListing() async {
    try {
      if (await _openListing()) return;
    } catch (e) {
      debugPrint('ReviewPrompt: could not open the Play Store ($e)');
    }
    try {
      await launchUrl(
        Uri.parse(
          'https://play.google.com/store/apps/details?id=com.vpn.fortivavpn',
        ),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('ReviewPrompt: could not open the listing ($e)');
    }
  }

  Future<_Record> _read() async {
    final prefs = await _prefs();
    final raw = prefs.getString(stateKey);
    if (raw == null) return _Record();
    try {
      return _Record.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('ReviewPrompt: unreadable state, starting over ($e)');
      return _Record();
    }
  }

  Future<void> _write(_Record state) async {
    final prefs = await _prefs();
    await prefs.setString(stateKey, jsonEncode(state.toJson()));
  }

  static Future<String?> _platformInstaller() async =>
      (await PackageInfo.fromPlatform()).installerStore;

  static Future<Object?> _platformRequest() =>
      _channel.invokeMethod<Object?>('requestReview');

  static Future<bool> _platformOpenListing() async =>
      await _channel.invokeMethod<bool>('openPlayListing') ?? false;
}

/// What is kept between runs.
class _Record {
  _Record({List<String>? days, this.failedAt, this.askedAt, this.asks = 0})
    : days = days ?? [];

  /// Tehran days with a verified connect, oldest first, at most
  /// [ReviewPrompt.minDays].
  final List<String> days;
  DateTime? failedAt;
  DateTime? askedAt;
  int asks;

  factory _Record.fromJson(Map<String, dynamic> json) => _Record(
    days: [
      for (final d in json['days'] as List? ?? const [])
        if (d is String) d,
    ],
    failedAt: _time(json['failed_at']),
    askedAt: _time(json['asked_at']),
    asks: json['asks'] is int ? json['asks'] as int : 0,
  );

  Map<String, dynamic> toJson() => {
    'days': days,
    if (failedAt != null) 'failed_at': failedAt!.millisecondsSinceEpoch,
    if (askedAt != null) 'asked_at': askedAt!.millisecondsSinceEpoch,
    'asks': asks,
  };

  static DateTime? _time(Object? v) =>
      v is int ? DateTime.fromMillisecondsSinceEpoch(v) : null;
}
