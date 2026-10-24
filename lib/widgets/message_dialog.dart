import 'dart:async';

import 'package:flutter/material.dart';

import '../core/design_system.dart';
import '../core/state/message_state.dart';
import '../data/models/in_app_message.dart';
import '../l10n/generated/app_localizations.dart';
import 'outside_link.dart';

/// Text from a message, laid out in the language it is written in.
///
/// A Persian message reads right to left in an app set to English, and an
/// English one left to right in an app set to Persian. The font follows
/// the message too, because the app's Latin font has no Persian letters
/// and the other way round. A message in a joined script also gets no
/// letter spacing, even where the style around it has some (a button's
/// label in an English app), because spacing breaks the joins. Everything
/// around the text (dates, Close) follows the app language as usual.
class MessageText extends StatelessWidget {
  const MessageText(
    this.text, {
    super.key,
    required this.language,
    this.style,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final String language;
  final TextStyle? style;
  final TextAlign textAlign;

  static bool isRtl(String language) => AppDesign.isRtlLocale(Locale(language));

  @override
  Widget build(BuildContext context) {
    final locale = Locale(language);
    return Directionality(
      textDirection: isRtl(language) ? TextDirection.rtl : TextDirection.ltr,
      child: Text(
        text,
        textAlign: textAlign,
        style: (style ?? const TextStyle()).copyWith(
          fontFamily: AppDesign.fontFamilyForLocale(locale),
          fontFamilyFallback: AppDesign.fontFallbackForLocale(locale),
          letterSpacing: isRtl(language) ? 0 : null,
        ),
      ),
    );
  }
}

/// How the popup was closed.
enum _Answer { closed, clicked, replaced }

/// A message from the Fortiva team, popped up over the home screen.
///
/// The home screen decides when (see HomeScreen); this only shows it and
/// reports what the user did with it: `shown` when it appears, `clicked`
/// for the button, `dismissed` for Close, a tap outside or the back
/// gesture. Only one is ever on screen, and the update dialog takes its
/// place when it needs the screen (see [closeForUpdate]).
class MessageDialog {
  static Route<_Answer>? _open;

  /// Whether a message popup is on screen.
  static bool get isShowing => _open?.isActive ?? false;

  /// Show [message]. Completes when the popup is closed. Never throws.
  static Future<void> show(
    BuildContext context,
    InAppMessage message, {
    MessageState? state,
    Future<void> Function(Uri url)? open,
  }) async {
    if (isShowing) return;
    try {
      final navigator = Navigator.of(context, rootNavigator: true);
      final route = DialogRoute<_Answer>(
        context: context,
        barrierDismissible: true,
        themes: InheritedTheme.capture(from: context, to: navigator.context),
        builder: (context) => _MessageDialogBody(
          message: message,
          onButton: () {
            unawaited(state?.report(message, ReceiptKind.clicked));
            final link = message.link;
            if (link != null) unawaited((open ?? _openOutside)(link));
          },
        ),
      );
      _open = route;
      unawaited(state?.report(message, ReceiptKind.shown));
      final answer = await navigator.push(route);
      if (identical(_open, route)) _open = null;
      switch (answer) {
        case _Answer.clicked:
          break;
        case _Answer.replaced:
          // Closed by the app, not by the user, who may not have read it.
          unawaited(state?.returnToInbox(message.id));
        case _Answer.closed || null:
          unawaited(state?.report(message, ReceiptKind.dismissed));
      }
    } catch (e) {
      debugPrint('MessageDialog: could not show a message ($e)');
    }
  }

  /// Take the popup down to make way for the update dialog, which matters
  /// more: a user on a build we no longer support must see it. Nothing is
  /// reported as dismissed, and the message goes back to the inbox unread.
  static void closeForUpdate() {
    final route = _open;
    _open = null;
    if (route == null || !route.isActive) return;
    try {
      route.navigator?.removeRoute(route, _Answer.replaced);
    } catch (e) {
      debugPrint('MessageDialog: could not close a message ($e)');
    }
  }

  /// Forget the open popup, for tests that pump a new app each time.
  @visibleForTesting
  static void resetForTest() => _open = null;

  static Future<void> _openOutside(Uri url) async {
    try {
      await openOutside(url);
    } catch (e) {
      debugPrint('MessageDialog: could not open $url: $e');
    }
  }
}

class _MessageDialogBody extends StatelessWidget {
  const _MessageDialogBody({required this.message, required this.onButton});

  final InAppMessage message;
  final VoidCallback onButton;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final button = message.button;
    // The message's own language's type for its title and text.
    final type = AppDesign.textThemeForLocale(Locale(message.language));
    return AlertDialog(
      // The title and text scroll when they are taller than the screen, as
      // a long message is on a small phone with large text, so the buttons
      // below them always stay on screen.
      scrollable: true,
      title: message.title.isEmpty
          ? null
          : SizedBox(
              width: double.infinity,
              child: MessageText(
                message.title,
                language: message.language,
                style: type.titleLarge?.copyWith(color: AppDesign.textPrimary),
              ),
            ),
      content: SizedBox(
        width: double.infinity,
        child: MessageText(
          message.body,
          language: message.language,
          style: type.bodyMedium?.copyWith(
            fontSize: 15,
            color: AppDesign.textPrimary,
          ),
        ),
      ),
      actions: [
        // One full-width button per row, as on the update dialog: a 40
        // character label and Close do not fit side by side on a narrow
        // phone, and a column lays out the same way in either direction.
        // The message's own button is the one filled button; Close is
        // quiet beside it.
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (button != null) ...[
              FilledButton(
                onPressed: () {
                  onButton();
                  Navigator.of(context).pop(_Answer.clicked);
                },
                child: MessageText(
                  button,
                  language: message.language,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppDesign.space4),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(_Answer.closed),
              style: TextButton.styleFrom(
                foregroundColor: AppDesign.textSecondary,
              ),
              child: Text(s.messageClose),
            ),
          ],
        ),
      ],
    );
  }
}
