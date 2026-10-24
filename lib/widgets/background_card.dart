import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/design_system.dart';
import '../core/form_factor.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/notice_channel.dart';
import '../services/notice_pull.dart';
import '../services/stored_from_background.dart';
import 'notices_switch.dart';

/// What on this phone may stop the background checks for messages, as
/// Android reports it (NoticeChannel.background).
class BackgroundFacts {
  const BackgroundFacts({
    this.brand = '',
    this.optimized = false,
    this.restricted = false,
    this.bucket,
    this.dataSaver = false,
    this.bootedAt,
  });

  final String brand;

  /// When the phone last started. Nothing schedules the checks again after
  /// a restart until some part of the app starts, so a gap that began
  /// before it says nothing about the battery settings.
  final DateTime? bootedAt;

  /// Battery optimization applies to the app, as it does to every app
  /// until the user changes it.
  final bool optimized;

  /// The user restricted the app's background use.
  final bool restricted;

  /// The app's standby bucket. [restrictedBucket] holds its background work
  /// to about once a day.
  final int? bucket;

  /// Data Saver is on and blocks the app's background data on mobile.
  final bool dataSaver;

  static const restrictedBucket = 45;

  /// Makers whose phones stop an app's background work by default, or when
  /// it is swiped away, unless the user lets it run. Samsung is not here:
  /// it only puts apps to sleep that go unused for days, which the
  /// [BackgroundReason.noRecentCheck] rule catches.
  static const strictMakers = [
    'xiaomi',
    'redmi',
    'poco',
    'huawei',
    'honor',
    'oppo',
    'realme',
    'oneplus',
    'vivo',
    'iqoo',
  ];

  bool get strictMaker => strictMakers.any(brand.contains);

  static BackgroundFacts fromMap(Map<String, Object?> map) => BackgroundFacts(
    brand: (map['brand'] as String? ?? '').toLowerCase(),
    optimized: map['optimized'] == true,
    restricted: map['restricted'] == true,
    bucket: map['bucket'] is int ? map['bucket'] as int : null,
    dataSaver: map['data_saver'] == true,
    bootedAt: map['booted_at'] is int
        ? DateTime.fromMillisecondsSinceEpoch(
            map['booted_at'] as int,
            isUtc: true,
          )
        : null,
  );
}

/// Why the app asks the user to let it run in the background.
enum BackgroundReason {
  /// The user restricted it, or Android put it in the restricted bucket.
  restricted,

  /// Data Saver blocks its background data on mobile.
  dataSaver,

  /// No background check ran for a day.
  noRecentCheck,

  /// A maker that stops background work by default (Xiaomi and others).
  strictMaker,
}

/// The rule for the card, apart from the screen so it can be tested.
///
/// [lastCheck] is when a background check last ran (NoticePull.lastCheckKey)
/// and [watchSince] when the app first looked, for a phone where none ever
/// ran. Closed or used in the last [quietFor], the card stays away. The
/// maker card shows once only: whether the user then allowed it cannot be
/// read on those phones, and [BackgroundReason.noRecentCheck] tells if not.
BackgroundReason? backgroundReason(
  BackgroundFacts facts, {
  required DateTime now,
  DateTime? lastCheck,
  DateTime? watchSince,
  DateTime? hiddenAt,
  DateTime? openedAt,
}) {
  bool within(DateTime? at, Duration span) =>
      at != null && !at.isAfter(now) && now.difference(at) < span;
  if (within(hiddenAt, quietFor) || within(openedAt, quietFor)) return null;
  if (facts.restricted || facts.bucket == BackgroundFacts.restrictedBucket) {
    return BackgroundReason.restricted;
  }
  if (facts.dataSaver) return BackgroundReason.dataSaver;
  final since = lastCheck ?? watchSince;
  final booted = facts.bootedAt;
  final restartedSince =
      since != null && booted != null && booted.isAfter(since);
  if (since != null &&
      !since.isAfter(now) &&
      !restartedSince &&
      now.difference(since) >= checkGap) {
    return BackgroundReason.noRecentCheck;
  }
  if (facts.strictMaker &&
      facts.optimized &&
      hiddenAt == null &&
      openedAt == null) {
    return BackgroundReason.strictMaker;
  }
  return null;
}

/// How long without a background check counts as the phone stopping them.
const checkGap = Duration(days: 1);

/// How long a closed or used card stays away.
const quietFor = Duration(days: 7);

/// The card at the top of the Messages screen that asks the user to let
/// Fortiva run in the background, on phones where something stops the
/// background checks. Android phones only, and only while notifications
/// are allowed: otherwise NoticesOffCard asks for that first.
class BackgroundCard extends StatefulWidget {
  const BackgroundCard({
    super.key,
    @visibleForTesting this.facts,
    @visibleForTesting this.notificationsOn,
    @visibleForTesting this.open,
    @visibleForTesting this.shown,
    @visibleForTesting this.now,
  });

  final Future<BackgroundFacts?> Function()? facts;
  final Future<bool> Function()? notificationsOn;
  final Future<void> Function()? open;
  final bool Function()? shown;
  final DateTime Function()? now;

  static const watchSinceKey = 'notices_background_watch_since';
  static const hiddenAtKey = 'notices_background_hidden_at';
  static const openedAtKey = 'notices_background_opened_at';

  /// Open the screen and remember it, for the card and the Settings row.
  static Future<void> openSettings({DateTime Function()? now}) async {
    await NoticeChannel.openBackground();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        openedAtKey,
        (now ?? DateTime.now)().toUtc().toIso8601String(),
      );
    } catch (e) {
      debugPrint('BackgroundCard: could not save the time ($e)');
    }
  }

  /// When the app first looked, saved now if it never did.
  static Future<DateTime> _watchSince(
    SharedPreferences prefs,
    DateTime now,
  ) async {
    final saved = prefs.get(watchSinceKey);
    final at = saved is String ? DateTime.tryParse(saved)?.toUtc() : null;
    if (at != null) return at;
    await prefs.setString(watchSinceKey, now.toIso8601String());
    return now;
  }

  /// Keep the card away for [quietFor].
  static Future<void> _hide(DateTime now) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(hiddenAtKey, now.toIso8601String());
    } catch (e) {
      debugPrint('BackgroundCard: could not save the choice ($e)');
    }
  }

  @override
  State<BackgroundCard> createState() => _BackgroundCardState();
}

class _BackgroundCardState extends State<BackgroundCard> {
  BackgroundReason? _reason;
  late final AppLifecycleListener _lifecycle;

  bool get _shown =>
      widget.shown?.call() ??
      (defaultTargetPlatform == TargetPlatform.android && !FormFactor.isTv);

  DateTime _now() => (widget.now ?? DateTime.now)().toUtc();

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_read()));
    if (_shown) unawaited(_read());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  static DateTime? _time(SharedPreferences prefs, String key) {
    final value = prefs.get(key);
    return value is String ? DateTime.tryParse(value)?.toUtc() : null;
  }

  Future<void> _read() async {
    try {
      if (!_shown) return;
      final on =
          await (widget.notificationsOn ??
              () async =>
                  await NoticeChannel.permission() ==
                  NoticePermission.granted)();
      final facts =
          await (widget.facts ??
              () async {
                final map = await NoticeChannel.background();
                return map == null ? null : BackgroundFacts.fromMap(map);
              })();
      final prefs = await SharedPreferences.getInstance();
      // The background check writes its time from another engine. Only that
      // key: a reload of every stored value dropped what this engine saved
      // meanwhile (StoredFromBackground).
      await StoredFromBackground.refresh(prefs, const [
        NoticePull.lastCheckKey,
      ]);
      final now = _now();
      final watchSince = await BackgroundCard._watchSince(prefs, now);
      final reason = !on || facts == null
          ? null
          : backgroundReason(
              facts,
              now: now,
              lastCheck: _time(prefs, NoticePull.lastCheckKey),
              watchSince: watchSince,
              hiddenAt: _time(prefs, BackgroundCard.hiddenAtKey),
              openedAt: _time(prefs, BackgroundCard.openedAtKey),
            );
      if (mounted && reason != _reason) setState(() => _reason = reason);
    } catch (e) {
      debugPrint('BackgroundCard: could not read the phone ($e)');
    }
  }

  Future<void> _allow() async {
    final open = widget.open;
    if (open != null) {
      await open();
    } else {
      await BackgroundCard.openSettings(now: _now);
    }
    if (mounted) setState(() => _reason = null);
  }

  Future<void> _notNow() async {
    if (mounted) setState(() => _reason = null);
    await BackgroundCard._hide(_now());
  }

  @override
  Widget build(BuildContext context) {
    if (_reason == null) return const SizedBox.shrink();
    final l10n = S.of(context)!;
    final data = _reason == BackgroundReason.dataSaver;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 0),
      child: NoticeCard(
        icon: Icons.battery_alert_outlined,
        // Something on the phone holds the messages back: a warning, in
        // the warning tone rather than the brand's, which means an offer.
        iconColor: AppDesign.warning,
        text: data ? l10n.backgroundCardData : l10n.backgroundCard,
        hint: data ? l10n.backgroundHintData : l10n.backgroundHint,
        actions: [
          TextButton(
            onPressed: () => unawaited(_notNow()),
            style: TextButton.styleFrom(
              foregroundColor: AppDesign.textSecondary,
            ),
            child: Text(l10n.backgroundNotNow),
          ),
          FilledButton.tonal(
            onPressed: () => unawaited(_allow()),
            style: NoticeCard.actionStyle,
            child: Text(l10n.backgroundAllow),
          ),
        ],
      ),
    );
  }
}
