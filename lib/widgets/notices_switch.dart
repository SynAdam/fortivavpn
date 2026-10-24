import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/design_system.dart';
import '../core/form_factor.dart';
import '../core/state/notice_permission_prompt.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/notice_channel.dart';

/// Whether messages from the Fortiva team can arrive as notifications, for
/// [builder], with a way to turn them on.
///
/// Read again each time the app comes back to the front, because the user
/// may have changed it in the system settings meanwhile. Builds nothing off
/// Android or on a TV, where the app shows messages inside itself only.
class NoticesStatus extends StatefulWidget {
  const NoticesStatus({
    super.key,
    required this.builder,
    @visibleForTesting this.read,
    @visibleForTesting this.turnOn,
    @visibleForTesting this.shown,
  });

  final Widget Function(
    BuildContext context,
    NoticePermission state,
    Future<void> Function() turnOn,
  )
  builder;

  final Future<NoticePermission> Function()? read;
  final Future<NoticePermission> Function()? turnOn;

  /// Whether this platform shows the status at all. Android phones only by
  /// default.
  final bool Function()? shown;

  @override
  State<NoticesStatus> createState() => _NoticesStatusState();
}

class _NoticesStatusState extends State<NoticesStatus> {
  NoticePermission? _state;
  late final AppLifecycleListener _lifecycle;

  bool get _shown =>
      widget.shown?.call() ??
      (defaultTargetPlatform == TargetPlatform.android && !FormFactor.isTv);

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

  Future<void> _read() async {
    if (!_shown) return;
    final state = await (widget.read ?? NoticeChannel.permission)();
    if (mounted && state != _state) setState(() => _state = state);
  }

  Future<void> _turnOn() async {
    final turnOn = widget.turnOn ?? NoticePermissionPrompt.instance.turnOn;
    await turnOn();
    // Android's dialog answers here; the system page answers on resume.
    await _read();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (!_shown || state == null) return const SizedBox.shrink();
    return widget.builder(context, state, _turnOn);
  }
}

/// A short card at the top of the Messages screen while messages cannot
/// arrive as notifications, with a button that turns them on. The user who
/// opens Messages cares about messages, so this is the place to offer it.
/// "Not now" keeps it away for [quietFor]; the Settings row stays.
class NoticesOffCard extends StatefulWidget {
  const NoticesOffCard({
    super.key,
    @visibleForTesting this.read,
    @visibleForTesting this.turnOn,
    @visibleForTesting this.shown,
    @visibleForTesting this.now,
  });

  final Future<NoticePermission> Function()? read;
  final Future<NoticePermission> Function()? turnOn;
  final bool Function()? shown;
  final DateTime Function()? now;

  static const hiddenAtKey = 'notices_off_card_hidden_at';

  /// How long "Not now" keeps the card away.
  static const quietFor = Duration(days: 7);

  /// Whether "Not now" was tapped less than [quietFor] ago.
  static Future<bool> _hidden(DateTime now) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.get(hiddenAtKey);
      final at = value is String ? DateTime.tryParse(value)?.toUtc() : null;
      return at != null && !at.isAfter(now) && now.difference(at) < quietFor;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _hide(DateTime now) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(hiddenAtKey, now.toIso8601String());
    } catch (e) {
      debugPrint('NoticesOffCard: could not save the choice ($e)');
    }
  }

  @override
  State<NoticesOffCard> createState() => _NoticesOffCardState();
}

class _NoticesOffCardState extends State<NoticesOffCard> {
  /// Unknown until read, and then hidden or not.
  bool _hidden = true;

  DateTime _now() => (widget.now ?? DateTime.now)().toUtc();

  @override
  void initState() {
    super.initState();
    unawaited(
      NoticesOffCard._hidden(_now()).then((hidden) {
        if (mounted && hidden != _hidden) setState(() => _hidden = hidden);
      }),
    );
  }

  Future<void> _notNow() async {
    setState(() => _hidden = true);
    await NoticesOffCard._hide(_now());
  }

  @override
  Widget build(BuildContext context) {
    Widget card(
      BuildContext context,
      NoticePermission state,
      Future<void> Function() turnOn,
    ) {
      if (_hidden || state == NoticePermission.granted) {
        return const SizedBox.shrink();
      }
      final l10n = S.of(context)!;
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 0),
        child: NoticeCard(
          icon: Icons.notifications_off_outlined,
          iconColor: AppDesign.steelLight,
          text: l10n.noticesOffCard,
          actions: [
            TextButton(
              onPressed: () => unawaited(_notNow()),
              style: TextButton.styleFrom(
                foregroundColor: AppDesign.textSecondary,
              ),
              child: Text(l10n.backgroundNotNow),
            ),
            FilledButton.tonal(
              onPressed: () => unawaited(turnOn()),
              style: NoticeCard.actionStyle,
              child: Text(l10n.noticesTurnOn),
            ),
          ],
        ),
      );
    }

    return NoticesStatus(
      builder: card,
      read: widget.read,
      turnOn: widget.turnOn,
      shown: widget.shown,
    );
  }
}

/// The card look the Messages screen's notices share (this one and
/// BackgroundCard): a quiet raised surface with a hairline edge, an icon,
/// the text, and the buttons at the end, which wrap to a second line when
/// a language's labels do not fit side by side.
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.text,
    this.hint,
    required this.actions,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  /// A smaller line under [text].
  final String? hint;
  final List<Widget> actions;

  /// The card's own action: a raised tone, not the brand fill, so the
  /// card does not read as an offer. The app theme gives every
  /// FilledButton the brand fill, the tonal kind included.
  static final ButtonStyle actionStyle = FilledButton.styleFrom(
    backgroundColor: AppDesign.surfaceHighest,
    foregroundColor: AppDesign.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    return Container(
      padding: const EdgeInsets.all(AppDesign.space16),
      decoration: BoxDecoration(
        color: AppDesign.surfaceLow,
        borderRadius: AppDesign.borderRadiusLarge,
        border: Border.all(color: AppDesign.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppDesign.space2),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: AppDesign.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: AppDesign.textTheme.bodyMedium?.copyWith(
                        color: AppDesign.textPrimary,
                      ),
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: AppDesign.space6),
                      Text(
                        hint,
                        style: AppDesign.textTheme.bodySmall?.copyWith(
                          color: AppDesign.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.space12),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppDesign.space8,
            runSpacing: AppDesign.space4,
            children: actions,
          ),
        ],
      ),
    );
  }
}
