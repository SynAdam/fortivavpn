import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design_system.dart';
import '../core/state/device_state.dart';
import '../core/state/message_state.dart';
import '../data/models/in_app_message.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/app_date.dart';
import '../widgets/background_card.dart';
import '../widgets/message_dialog.dart';
import '../widgets/notices_switch.dart';
import '../widgets/outside_link.dart';

/// Every current message from the Fortiva team, newest first.
///
/// Opening it checks for new messages at once, and counts everything listed
/// as seen: the badge clears and each message reports `shown`.
///
/// The small ID line at the bottom is this phone's number on our side, so
/// an operator can send a test message to their own phone.
///
/// While messages cannot arrive as notifications, a card at the top offers
/// to turn them on (NoticesOffCard). Once they can, a card asks to let the
/// app run in the background on phones that stop it (BackgroundCard).
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, this.open});

  /// Opens a button's link. Passed in by tests.
  final Future<void> Function(Uri url)? open;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  /// Messages already counted as seen while this screen is open.
  final _seen = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        unawaited(context.read<MessageState?>()?.refresh(force: true));
      } catch (e) {
        debugPrint('InboxScreen: could not check for messages ($e)');
      }
    });
  }

  /// Count what is on screen as seen, after the frame, because it changes
  /// the badge and that must not happen during a build.
  void _markSeen(MessageState state, List<InAppMessage> listed) {
    final fresh = [
      for (final m in listed)
        if (!_seen.contains(m.id)) m,
    ];
    if (fresh.isEmpty) return;
    _seen.addAll(fresh.map((m) => m.id));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(state.markAllRead());
      for (final m in fresh) {
        unawaited(state.report(m, ReceiptKind.shown));
      }
    });
  }

  Future<void> _tap(MessageState? state, InAppMessage message) async {
    final link = message.link;
    if (link == null) return;
    unawaited(state?.report(message, ReceiptKind.clicked));
    try {
      final open = widget.open;
      if (open != null) {
        await open(link);
      } else {
        await openOutside(link);
      }
    } catch (e) {
      debugPrint('InboxScreen: could not open $link: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    MessageState? state;
    var listed = const <InAppMessage>[];
    try {
      state = context.watch<MessageState?>();
      listed = state?.messages ?? const [];
      if (state != null) _markSeen(state, listed);
    } catch (e) {
      debugPrint('InboxScreen: could not read messages ($e)');
    }

    int? deviceRow;
    try {
      deviceRow = context.watch<DeviceState?>()?.device?.id;
    } catch (_) {}

    return Scaffold(
      backgroundColor: AppDesign.canvas,
      appBar: AppBar(
        title: Text(l10n.inboxTitle),
        backgroundColor: AppDesign.canvas,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const NoticesOffCard(),
            const BackgroundCard(),
            Expanded(
              child: listed.isEmpty
                  ? const _Empty()
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppDesign.space16),
                      itemCount: listed.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppDesign.space12),
                      itemBuilder: (context, i) => _MessageCard(
                        message: listed[i],
                        onButton: () => _tap(state, listed[i]),
                      ),
                    ),
            ),
            if (deviceRow != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 12),
                child: SelectableText(
                  'ID $deviceRow',
                  textDirection: TextDirection.ltr,
                  style: AppDesign.textTheme.labelSmall?.copyWith(
                    color: AppDesign.textTertiary,
                    fontWeight: FontWeight.w500,
                    fontFeatures: AppDesign.numberFeatures,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// No messages: a quiet bell and one line.
class _Empty extends StatelessWidget {
  const _Empty();

  static const double _disc = 56;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDesign.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppDesign.surfaceHigh,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: _disc,
                  child: Icon(
                    Icons.notifications_off_outlined,
                    size: 26,
                    color: AppDesign.textTertiary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDesign.space16),
            Text(
              l10n.inboxEmpty,
              textAlign: TextAlign.center,
              style: AppDesign.textTheme.bodyLarge?.copyWith(
                color: AppDesign.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One message as a card. The title, text and button are set in the
/// message's own language's type (its font, line height and spacing),
/// which may not be the app's; the date follows the app.
class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.onButton});

  final InAppMessage message;
  final VoidCallback onButton;

  /// The send date in the app's language, on the phone's calendar day.
  /// Persian shows it on the Iranian calendar (see appDate).
  String _date(BuildContext context) => appDate(context, message.sentAt);

  @override
  Widget build(BuildContext context) {
    final button = message.button;
    final type = AppDesign.textThemeForLocale(Locale(message.language));
    // The shared card look: a tone above the canvas, no edge.
    return Container(
      padding: const EdgeInsets.all(AppDesign.space16),
      decoration: BoxDecoration(
        color: AppDesign.surfaceLow,
        borderRadius: AppDesign.borderRadiusLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message.title.isNotEmpty) ...[
            MessageText(
              message.title,
              language: message.language,
              style: type.titleMedium?.copyWith(color: AppDesign.textPrimary),
            ),
            const SizedBox(height: AppDesign.space6),
          ],
          MessageText(
            message.body,
            language: message.language,
            style: type.bodyMedium?.copyWith(color: AppDesign.textPrimary),
          ),
          const SizedBox(height: AppDesign.space12),
          Text(
            _date(context),
            style: AppDesign.textTheme.bodySmall?.copyWith(
              color: AppDesign.textTertiary,
            ),
          ),
          if (button != null) ...[
            const SizedBox(height: AppDesign.space12),
            FilledButton.tonal(
              onPressed: onButton,
              style: FilledButton.styleFrom(
                backgroundColor: AppDesign.surfaceHigh,
                foregroundColor: AppDesign.textPrimary,
              ),
              child: MessageText(
                button,
                language: message.language,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
