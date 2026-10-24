import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design_system.dart';
import '../core/page_transitions.dart';
import '../core/state/message_state.dart';
import '../l10n/generated/app_localizations.dart';
import '../screens/inbox_screen.dart';
import '../utils/number_localizer.dart';

/// The bell in the home screen's header, with the number of unread
/// messages, that opens the inbox.
///
/// Its own widget, so the home screen never reads MessageState itself. It
/// draws nothing when there is no MessageState above it or when reading it
/// fails: a broken bell must never take the connect button with it.
class MessageBell extends StatelessWidget {
  const MessageBell({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      final messages = context.watch<MessageState?>();
      if (messages == null) return const SizedBox.shrink();
      final unread = messages.unreadCount;
      final l10n = S.of(context)!;
      return IconButton(
        onPressed: () => Navigator.push(
          context,
          SlideUpFadeTransition(page: const InboxScreen()),
        ),
        tooltip: l10n.messagesTooltip,
        iconSize: 24,
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              color: AppDesign.textSecondary,
            ),
            if (unread > 0)
              // Centred on the bell's top end corner, inside the button.
              PositionedDirectional(
                top: -6,
                end: -7,
                child: _UnreadCount(
                  NumberLocalizer.localize('$unread', context),
                ),
              ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('MessageBell: not shown ($e)');
      return const SizedBox.shrink();
    }
  }
}

/// The number of unread messages on the bell: a brand pill with white
/// figures, set off from the bell by a ring in the background color, so it
/// reads as a sticker on the bell and not part of its outline.
class _UnreadCount extends StatelessWidget {
  const _UnreadCount(this.count);

  final String count;

  /// The pill's height without the ring.
  static const double size = 16;

  /// The ring's width.
  static const double ring = 2;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: size + 2 * ring,
        minHeight: size + 2 * ring,
      ),
      // The ring adds its own width inside the edge.
      padding: const EdgeInsets.symmetric(horizontal: AppDesign.space4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppDesign.brand,
        borderRadius: BorderRadius.circular(AppDesign.radiusFull),
        border: Border.all(color: AppDesign.canvas, width: ring),
      ),
      // A count in a fixed pill: it keeps its size at any text size.
      child: Text(
        count,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: AppDesign.onBrand,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1,
          fontFeatures: AppDesign.numberFeatures,
        ),
      ),
    );
  }
}
