import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import '../core/design_system.dart';
import '../data/models/connection_session.dart';
import '../services/session_tracker.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/app_date.dart';
import '../utils/number_localizer.dart';
import '../widgets/server_card.dart';
import '../widgets/server_title.dart';
import '../widgets/ui/section_label.dart';

/// History: the connections this phone has made, as SessionTracker keeps
/// them on the phone.
///
/// Three totals, the time connected on each of the most recent days, and
/// the latest connections. Every word and number is in the app's language.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  /// How many of the latest connections the list shows.
  static const int _listedSessions = 20;

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<SessionTracker>();
    final l10n = S.of(context)!;

    return Scaffold(
      backgroundColor: AppDesign.canvas,
      appBar: AppBar(
        title: Text(l10n.connectionAnalytics),
        backgroundColor: AppDesign.appBarColor,
      ),
      body: tracker.sessions.isEmpty
          ? _buildEmptyState(l10n)
          : ListView(
              padding: AppDesign.clearOfNavBar(
                context,
                const EdgeInsets.fromLTRB(16, 8, 16, 24),
              ),
              children: [
                _buildOverviewCards(context, tracker),
                const SizedBox(height: AppDesign.space24),
                SectionLabel(l10n.historyRecentDays),
                _WeekChart(tracker: tracker),
                const SizedBox(height: AppDesign.space24),
                SectionLabel(l10n.recentSessions),
                _SessionList(
                  sessions: tracker.sessions.take(_listedSessions).toList(),
                ),
              ],
            ),
    );
  }

  /// [d] as hours and minutes, minutes, or seconds, in the app's language
  /// and digits.
  static String durationText(BuildContext context, Duration d) {
    final l10n = S.of(context)!;
    final String text;
    if (d.inHours > 0) {
      final minutes = d.inMinutes.remainder(60);
      text = minutes == 0
          ? l10n.supportDurationWholeHours(d.inHours)
          : l10n.supportDurationHours(d.inHours, minutes);
    } else if (d.inMinutes > 0) {
      text = l10n.supportDurationMinutes(d.inMinutes);
    } else {
      text = l10n.durationSeconds(d.inSeconds);
    }
    return NumberLocalizer.localize(text, context);
  }

  /// [d] in its largest whole unit, for the narrow label over a chart bar.
  static String shortDurationText(BuildContext context, Duration d) {
    final l10n = S.of(context)!;
    final String text;
    if (d.inHours > 0) {
      text = l10n.supportDurationWholeHours((d.inMinutes / 60).round());
    } else if (d.inMinutes > 0) {
      text = l10n.supportDurationMinutes(d.inMinutes);
    } else {
      text = l10n.durationSeconds(d.inSeconds);
    }
    return NumberLocalizer.localize(text, context);
  }

  /// The weekday names for [days] in the app's language.
  ///
  /// The short names where they are short. Persian and Arabic write the
  /// whole name even in the short form, which does not fit seven to a row,
  /// so those get the one letter form that calendars use. That form is
  /// used only when it is in the language's own script and names every
  /// day apart: Urdu's is the English S, M, T, W, T, F, S, so Urdu keeps
  /// its short names, and the chart scales them down to fit.
  static List<String> weekdayLabels(BuildContext context, List<DateTime> days) {
    String tag;
    try {
      tag = Localizations.localeOf(context).toLanguageTag();
    } catch (_) {
      tag = 'en';
    }
    List<String> format(String pattern, String locale) => [
      for (final d in days) DateFormat(pattern, locale).format(d),
    ];
    try {
      final short = format('E', tag);
      if (short.every((name) => name.characters.length <= 4)) return short;
      final narrow = format('EEEEE', tag);
      final latin = RegExp('[A-Za-z]');
      final ownScript =
          short.any(latin.hasMatch) || !narrow.any(latin.hasMatch);
      final distinct = narrow.toSet().length == narrow.length;
      return ownScript && distinct ? narrow : short;
    } catch (_) {
      return format('E', 'en');
    }
  }

  /// The clock time [when] in the phone's own format.
  static String clockText(BuildContext context, DateTime when) {
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(when),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return NumberLocalizer.localize(time, context);
  }

  /// When a connection started: today, yesterday or the date, with the time.
  static String startedText(BuildContext context, DateTime when) {
    final l10n = S.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(when.year, when.month, when.day);
    final time = clockText(context, when);
    if (date == today) return l10n.today(time);
    if (date == today.subtract(const Duration(days: 1))) {
      return l10n.yesterdayAt(time);
    }
    return l10n.dateAt(appDate(context, when), time);
  }

  Widget _buildEmptyState(S l10n) {
    final text = AppDesign.textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppDesign.surfaceLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.insights_rounded,
                size: 32,
                color: AppDesign.steelMid,
              ),
            ),
            const SizedBox(height: AppDesign.space16),
            Text(
              l10n.noDataYet,
              textAlign: TextAlign.center,
              style: text.titleMedium,
            ),
            const SizedBox(height: AppDesign.space8),
            Text(
              l10n.connectToStart,
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards(BuildContext context, SessionTracker tracker) {
    final l10n = S.of(context)!;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.hub_outlined,
              label: l10n.connectionsLabel,
              value: NumberLocalizer.localize(
                '${tracker.totalSessions}',
                context,
              ),
            ),
          ),
          const SizedBox(width: AppDesign.space8),
          Expanded(
            child: _StatTile(
              icon: Icons.timer_outlined,
              label: l10n.totalTime,
              value: AnalyticsScreen.durationText(
                context,
                tracker.totalConnectionTime,
              ),
            ),
          ),
          const SizedBox(width: AppDesign.space8),
          Expanded(
            child: _StatTile(
              icon: Icons.av_timer_rounded,
              label: l10n.historyAverage,
              value: AnalyticsScreen.durationText(
                context,
                tracker.averageSessionDuration,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One total: an icon, the number, and what it counts.
///
/// The number is the largest thing on the tile and its caption sits right
/// under it, so each tile reads as one fact. The number wraps instead of
/// shrinking, so a long Persian duration stays as large as the count
/// beside it. The tiles keep one height, set by the tallest.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = AppDesign.textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesign.space12,
        vertical: AppDesign.space16,
      ),
      decoration: BoxDecoration(
        color: AppDesign.surfaceLow,
        borderRadius: AppDesign.borderRadiusLarge,
      ),
      child: Column(
        children: [
          Icon(icon, color: AppDesign.steelMid, size: 20),
          const SizedBox(height: AppDesign.space8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: text.titleLarge?.copyWith(
              color: AppDesign.textPrimary,
              fontFeatures: AppDesign.numberFeatures,
            ),
          ),
          const SizedBox(height: AppDesign.space4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Time connected on each of the most recent days, one bar a day, oldest
/// first in reading order.
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.tracker});

  final SessionTracker tracker;

  /// The tallest bar, for the busiest day.
  static const double _barHeight = 100;
  static const double _stubHeight = 4;

  @override
  Widget build(BuildContext context) {
    final daily = tracker.dailyConnectionTime;
    final days = daily.keys.toList();
    final names = AnalyticsScreen.weekdayLabels(context, days);
    final most = daily.values.fold<int>(
      1,
      (max, d) => d.inSeconds > max ? d.inSeconds : max,
    );
    final text = AppDesign.textTheme;
    final now = DateTime.now();
    final grow = AppMotion.reduced(context) ? Duration.zero : AppMotion.slow;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      decoration: BoxDecoration(
        color: AppDesign.surfaceLow,
        borderRadius: AppDesign.borderRadiusLarge,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Builder(
                builder: (context) {
                  final day = days[i];
                  final time = daily[day]!;
                  final seconds = time.inSeconds;
                  final share = seconds / most;
                  final isToday =
                      day.year == now.year &&
                      day.month == now.month &&
                      day.day == now.day;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDesign.space2,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          height: 18,
                          child: seconds > 0
                              ? FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    AnalyticsScreen.shortDurationText(
                                      context,
                                      time,
                                    ),
                                    maxLines: 1,
                                    style: text.labelSmall?.copyWith(
                                      color: AppDesign.textSecondary,
                                      fontFeatures: AppDesign.numberFeatures,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: AppDesign.space4),
                        AnimatedContainer(
                          duration: grow,
                          curve: AppMotion.emphasizedDecelerate,
                          height: seconds > 0
                              ? (_barHeight * share).clamp(8.0, _barHeight)
                              : _stubHeight,
                          decoration: BoxDecoration(
                            color: seconds > 0
                                ? AppDesign.protected
                                : AppDesign.surfaceHighest,
                            borderRadius: BorderRadius.circular(
                              AppDesign.radiusXSmall,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDesign.space8),
                        // Urdu's short names are up to six letters, and a
                        // name too wide for its bar is drawn smaller.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            names[i],
                            maxLines: 1,
                            style: text.labelSmall?.copyWith(
                              color: isToday
                                  ? AppDesign.textPrimary
                                  : AppDesign.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// The latest connections as one grouped card, rows divided by hairlines
/// that start under the text, the way Settings groups its rows.
class _SessionList extends StatelessWidget {
  const _SessionList({required this.sessions});

  final List<ConnectionSession> sessions;

  /// From the row's start edge to its text: the padding, the flag and
  /// the gap after it.
  static const double _textInset =
      _SessionRow.paddingStart + _SessionRow.flagSize + AppDesign.space12;

  @override
  Widget build(BuildContext context) {
    // No clip: the rows paint nothing of their own over the card's fill.
    return Container(
      decoration: BoxDecoration(
        color: AppDesign.surfaceLow,
        borderRadius: AppDesign.borderRadiusLarge,
      ),
      child: Column(
        children: [
          for (final (i, session) in sessions.indexed) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: _textInset,
                color: AppDesign.hairline,
              ),
            _SessionRow(session: session),
          ],
        ],
      ),
    );
  }
}

/// One past connection: where, when, and for how long.
class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final ConnectionSession session;

  static const double paddingStart = 16;
  static const double flagSize = 40;

  @override
  Widget build(BuildContext context) {
    final text = AppDesign.textTheme;
    final latency = session.avgLatencyMs;
    final flag = session.serverFlagEmoji;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(paddingStart, 12, 16, 12),
        child: Row(
          children: [
            // A session saved with no country gets the steel globe, not the
            // one full-color picture on the screen: FlagDisc draws it for
            // the stored globe.
            FlagDisc(flag: flag, size: flagSize),
            const SizedBox(width: AppDesign.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    storedServerTitle(context, session.serverName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(
                      color: AppDesign.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppDesign.space2),
                  Text(
                    AnalyticsScreen.startedText(context, session.startTime),
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDesign.space12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AnalyticsScreen.durationText(context, session.duration),
                  style: text.labelLarge?.copyWith(
                    fontFeatures: AppDesign.numberFeatures,
                  ),
                ),
                if (latency != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppDesign.space2),
                    child: Text(
                      NumberLocalizer.localize('$latency ms', context),
                      // The number before its unit in every language, as
                      // the server lists and home show a reply time.
                      textDirection: TextDirection.ltr,
                      style: text.bodySmall?.copyWith(
                        fontFeatures: AppDesign.numberFeatures,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
