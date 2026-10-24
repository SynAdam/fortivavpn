import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design_system.dart';
import '../core/haptics.dart';
import '../core/page_transitions.dart';
import '../core/state/support_state.dart';
import '../l10n/generated/app_localizations.dart';
import '../screens/support_screen.dart';
import 'chatbot_glyph.dart';
import 'focus_ring.dart';
import 'tappable.dart';

/// Open the support chat.
void openSupportChat(BuildContext context) {
  Navigator.push(context, SlideUpFadeTransition(page: const SupportScreen()));
}

/// The round chatbot button at the bottom of the home screen, with a dot
/// when a reply arrived that the user has not seen.
///
/// Its own widget, so the home screen never reads SupportState itself, and
/// it rebuilds only when the chat turns on or off or the dot comes or goes,
/// never on a fetch of the conversation. It draws nothing until the backend
/// says the chat is on for this phone, and nothing when reading the state
/// fails: a broken button must never take the connect button with it.
class ChatbotButton extends StatelessWidget {
  const ChatbotButton({super.key});

  /// The width and height of the button.
  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    final shown = context.select<SupportState?, ({bool on, bool unread})>((
      support,
    ) {
      try {
        if (support == null || !support.enabled) {
          return (on: false, unread: false);
        }
        return (on: true, unread: support.unseenReplies > 0);
      } catch (e) {
        debugPrint('ChatbotButton: not shown ($e)');
        return (on: false, unread: false);
      }
    });
    if (!shown.on) return const SizedBox.shrink();
    return _ChatbotFab(unread: shown.unread);
  }
}

class _ChatbotFab extends StatefulWidget {
  const _ChatbotFab({required this.unread});

  final bool unread;

  @override
  State<_ChatbotFab> createState() => _ChatbotFabState();
}

class _ChatbotFabState extends State<_ChatbotFab>
    with SingleTickerProviderStateMixin {
  /// Grows the button in once, when it first appears. Still afterwards.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _entrance,
    curve: Curves.easeOutBack,
  );

  @override
  void initState() {
    super.initState();
    // After the frame it first appears in, so it never holds up that frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _entrance.value = 1;
      } else {
        unawaited(_entrance.forward());
      }
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _open() {
    AppHaptics.light();
    openSupportChat(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final label = l10n.supportTooltip;
    const size = ChatbotButton.size;
    return ScaleTransition(
      scale: _scale,
      child: Semantics(
        button: true,
        label: label,
        // The dot is the only sign of a reply not seen yet, so a screen
        // reader says it in words.
        value: widget.unread ? l10n.supportUnreadReply : null,
        excludeSemantics: true,
        onTap: _open,
        child: Tooltip(
          message: label,
          excludeFromSemantics: true,
          // A round button gets a round focus ring on a TV, as the power
          // button does.
          child: FocusRingCircle(
            child: SizedBox.square(
              dimension: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // A tonal disc with a plain shadow. No colored glow: on
                  // the home screen color means the connection's state.
                  DecoratedBox(
                    decoration: _disc,
                    child: Material(
                      type: MaterialType.transparency,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: const ValueKey('chatbot-button'),
                        onTap: _open,
                        // A little stronger than the theme's ripple, which
                        // is tuned for flat surfaces and faint on a
                        // gradient.
                        splashColor: Colors.white.withValues(alpha: 0.12),
                        child: const Center(
                          child: ChatbotGlyph(
                            size: size * 0.54,
                            color: AppDesign.onChatbot,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.unread)
                    PositionedDirectional(
                      top: 2,
                      end: 2,
                      child: Container(
                        key: const ValueKey('chatbot-unread'),
                        width: _dotSize,
                        height: _dotSize,
                        decoration: BoxDecoration(
                          color: AppDesign.brand,
                          shape: BoxShape.circle,
                          // A ring in the page's color cuts the dot out of
                          // the disc's edge.
                          border: Border.all(color: AppDesign.canvas, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The unread dot, its ring included.
  static const double _dotSize = 12;

  /// One step darker than the power button's face at rest. In the chat's
  /// steel (ChatbotAvatar.steelDisc) it was the lightest thing on the idle
  /// home screen, so the eye went to the corner before the main control.
  /// The chat keeps the steel for the assistant's face; the glyph here
  /// stays in the same steel.
  static final BoxDecoration _disc = ChatbotAvatar.steelDisc.copyWith(
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppDesign.surfaceHigh, AppDesign.surface],
    ),
    border: Border.all(color: AppDesign.outlineVariant),
    boxShadow: AppDesign.shadowMedium,
  );
}

/// "Ask support" under a failed connection on the home screen. While the
/// failure is on screen, and diagnostics sharing is on, a message sent from
/// the chat says what the failure was, so the user does not have to
/// describe it. Draws nothing while the chat is off.
class AskSupportLink extends StatelessWidget {
  const AskSupportLink({super.key, required this.color});

  final Color color;

  /// Above and below the words inside the tap target, at least. At most
  /// text sizes the 48dp target leaves more than this.
  static const double _air = 4;

  @override
  Widget build(BuildContext context) {
    try {
      final support = context.watch<SupportState?>();
      if (support == null || !support.enabled) return const SizedBox.shrink();
      final l10n = S.of(context)!;
      // The indent is outside the tap target, so a TV remote's focus ring
      // goes round the words and not the space before them. The words sit
      // in the middle of the 48dp target, so the ring has as much air
      // above them as below. The air under them is the bar's own bottom
      // padding: the bar adds none of its own under this link.
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: 28),
        child: Tappable(
          onTap: () => openSupportChat(context),
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: kMinInteractiveDimension,
              minHeight: kMinInteractiveDimension,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 1,
              heightFactor: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: _air),
                child: Text(
                  l10n.supportAskAction,
                  style: AppDesign.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('AskSupportLink: not shown ($e)');
      return const SizedBox.shrink();
    }
  }
}
