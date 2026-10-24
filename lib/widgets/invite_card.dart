import 'package:flutter/material.dart';

import '../core/design_system.dart';
import '../data/models/invite_prompt_rules.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/invite_share.dart';
import '../utils/number_localizer.dart';

export '../services/invite_share.dart' show InviteTarget;

/// The invite card on the home screen, after good connection days: a title,
/// one line with the reward after it when the backend gives one, and four
/// buttons (Telegram, WhatsApp, Copy link, Other apps). See InvitePrompt
/// and _HomeInviteCard for when it shows.
///
/// It sits where PremiumOfferCard does and looks like it, and is kept as
/// short: the buttons go in one row, with a label on two lines where one
/// does not fit a quarter of the width, or in two rows with the icon beside
/// the label when even two lines do not fit. Every button is a 48dp tap
/// target in each layout. They always show: a messenger that is not
/// installed falls back to the share sheet. No brand logo, and no state
/// messenger anywhere.
class InviteCard extends StatelessWidget {
  const InviteCard({
    super.key = const Key('invite-card'),
    required this.title,
    required this.body,
    required this.onTarget,
    required this.onClose,
    this.rewardLine,
    this.busyTarget,
    this.margin = EdgeInsets.zero,
  });

  final String title;
  final String body;

  /// The Premium days a friend gives, as a sentence, or null for no line.
  final String? rewardLine;

  /// The button waiting for the referral status, drawn with a spinner.
  final InviteTarget? busyTarget;
  final ValueChanged<InviteTarget> onTarget;
  final VoidCallback onClose;
  final EdgeInsetsGeometry margin;

  /// The reward line for [rules]: the days when the backend names them, a
  /// line with no number when it does not, and none when the device earns
  /// nothing more (at the cap).
  static String? rewardLineFor(BuildContext context, InvitePromptRules rules) {
    if (!rules.earns) return null;
    final l10n = S.of(context)!;
    final days = rules.rewardPremiumDays;
    if (days == null) return l10n.inviteCardRewardNoAmount;
    return NumberLocalizer.localize(l10n.inviteCardReward(days), context);
  }

  /// Space between the card's edge and its text, on each side.
  static const double _sidePadding = 12;

  /// Room the title leaves at its end for the close button over it.
  static const double _closeRoom = 32;

  /// Space above the title.
  static const double _topPadding = 8;

  /// The close button's tap target, square in the corner.
  static const double _closeTarget = 48;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final reward = rewardLine;
    final buttons = [
      (InviteTarget.telegram, Icons.send_rounded, l10n.inviteSendTelegram),
      (InviteTarget.whatsapp, Icons.chat_rounded, l10n.inviteSendWhatsApp),
      (InviteTarget.copyLink, Icons.link_rounded, l10n.inviteCopyLink),
      (InviteTarget.otherApps, Icons.ios_share_rounded, l10n.inviteOtherApps),
    ];
    // The shared card look of the home screen's cards. It stays as short
    // as it was: the card shows only where the power button keeps room
    // above it, so every line here costs a phone the card. The close
    // button sits over the corner instead of in a row of its own, and each
    // button's 48dp tap area reaches into the card's bottom edge.
    return Padding(
      padding: margin,
      child: Material(
        color: AppDesign.surfaceLow,
        shape: RoundedRectangleBorder(
          borderRadius: AppDesign.borderRadiusLarge,
          side: const BorderSide(color: AppDesign.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                _sidePadding,
                _topPadding,
                _sidePadding,
                2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The title and the line under it reach at least to the
                  // bottom of the close button's tap target, so on a wide
                  // screen, where the line fits on one row, the close button
                  // never covers the top of the last button.
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: _closeTarget - _topPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            end: _closeRoom - _sidePadding,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // A gift, the same either way round.
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.card_giftcard_rounded,
                                  size: 16,
                                  color: AppDesign.brandBright,
                                  textDirection: TextDirection.ltr,
                                ),
                              ),
                              const SizedBox(width: AppDesign.space6),
                              Expanded(
                                child: Text(
                                  title,
                                  style: AppDesign.textTheme.titleSmall
                                      ?.copyWith(
                                        color: AppDesign.textPrimary,
                                        height: 1.25,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // The reward line runs on from the body line, brighter,
                        // so the card is no taller for it.
                        Text.rich(
                          TextSpan(
                            text: body,
                            children: [
                              if (reward != null)
                                TextSpan(
                                  text: ' $reward',
                                  style: const TextStyle(
                                    color: AppDesign.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                          key: const Key('invite-card-body'),
                          style: AppDesign.textTheme.bodySmall?.copyWith(
                            color: AppDesign.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final scaler = MediaQuery.textScalerOf(context);
                      final direction = Directionality.of(context);
                      final room =
                          constraints.maxWidth / 4 -
                          2 * _TargetButton.sidePadding;
                      int? lines;
                      for (final count in const [1, 2]) {
                        if (buttons.every(
                          (b) =>
                              _labelFits(b.$3, scaler, direction, room, count),
                        )) {
                          lines = count;
                          break;
                        }
                      }
                      Widget button(
                        (InviteTarget, IconData, String) b, {
                        required bool stacked,
                        int lines = 1,
                      }) => _TargetButton(
                        target: b.$1,
                        icon: b.$2,
                        label: b.$3,
                        stacked: stacked,
                        lines: lines,
                        busy: busyTarget == b.$1,
                        onTap: () => onTarget(b.$1),
                      );
                      if (lines != null) {
                        // With a label on two lines the four buttons stand
                        // as tall as the tallest, so their tap areas match.
                        final row = Row(
                          key: const Key('invite-card-one-row'),
                          crossAxisAlignment: lines == 1
                              ? CrossAxisAlignment.center
                              : CrossAxisAlignment.stretch,
                          children: [
                            for (final b in buttons)
                              Expanded(
                                child: button(b, stacked: true, lines: lines),
                              ),
                          ],
                        );
                        return lines == 1 ? row : IntrinsicHeight(child: row);
                      }
                      // Two rows of two, each button with its icon beside
                      // the label: a label too long for two lines in a
                      // quarter of the width gets half of it.
                      return Column(
                        key: const Key('invite-card-two-rows'),
                        children: [
                          for (final pair in [
                            buttons.sublist(0, 2),
                            buttons.sublist(2),
                          ])
                            Row(
                              children: [
                                for (final b in pair)
                                  Expanded(child: button(b, stacked: false)),
                              ],
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            PositionedDirectional(
              top: 0,
              end: 0,
              // A full tap target in the corner, with the cross drawn level
              // with the title's first line.
              child: IconButton(
                key: const Key('invite-card-close'),
                onPressed: onClose,
                tooltip: l10n.inviteNotNowAction,
                icon: const Icon(Icons.close, size: 18),
                color: AppDesign.textTertiary,
                iconSize: 18,
                padding: const EdgeInsetsDirectional.only(top: 8, end: 10),
                alignment: AlignmentDirectional.topEnd,
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static TextStyle? get _labelStyle => AppDesign.textTheme.labelSmall?.copyWith(
    color: AppDesign.textPrimary,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Whether [label] fits in [room], the width a stacked button has for
  /// it, on at most [lines] lines with no word broken across two.
  static bool _labelFits(
    String label,
    TextScaler scaler,
    TextDirection direction,
    double room,
    int lines,
  ) {
    double width(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: _labelStyle),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    if (lines == 1) return width(label) <= room;
    if (label.split(' ').any((word) => width(word) > room)) return false;
    final painter = TextPainter(
      text: TextSpan(text: label, style: _labelStyle),
      textDirection: direction,
      textScaler: scaler,
      maxLines: lines,
    )..layout(maxWidth: room);
    final fits = !painter.didExceedMaxLines;
    painter.dispose();
    return fits;
  }
}

class _TargetButton extends StatelessWidget {
  const _TargetButton({
    required this.target,
    required this.icon,
    required this.label,
    required this.stacked,
    required this.busy,
    required this.onTap,
    this.lines = 1,
  });

  /// Space on each side of the label inside a stacked button.
  static const double sidePadding = 2;

  /// The least height of a button, its whole tap target.
  static const double minTarget = 48;

  /// The tonal plate behind each icon.
  static const double _plate = 24;

  final InviteTarget target;
  final IconData icon;
  final String label;

  /// The icon above the label (one row of four), else beside it.
  final bool stacked;

  /// The most lines the label of a stacked button takes.
  final int lines;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: _plate,
      height: _plate,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppDesign.surfaceHigh,
        borderRadius: AppDesign.borderRadiusXSmall,
      ),
      child: busy
          ? const SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          // Never mirrored in a right-to-left language: the send arrow and
          // the share mark mean the same either way.
          : Icon(
              icon,
              size: 16,
              color: AppDesign.steelLight,
              textDirection: TextDirection.ltr,
            ),
    );
    final text = Text(
      label,
      maxLines: stacked ? lines : 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: InviteCard._labelStyle,
    );
    return Semantics(
      button: true,
      child: InkWell(
        key: Key('invite-card-${target.name}'),
        // Never disabled while it waits: a disabled button loses a TV
        // remote's focus. The tap is ignored instead.
        onTap: () {
          if (!busy) onTap();
        },
        borderRadius: AppDesign.borderRadiusMedium,
        child: Padding(
          padding: stacked
              ? const EdgeInsets.symmetric(horizontal: sidePadding, vertical: 4)
              : const EdgeInsetsDirectional.fromSTEB(4, 2, 4, 2),
          // The plate and the label come to under 48dp: this makes the
          // whole tap target at least 48 in either layout.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: minTarget - (stacked ? 8 : 4),
            ),
            child: stacked
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [mark, const SizedBox(height: 2), text],
                  )
                : Row(
                    children: [
                      mark,
                      const SizedBox(width: AppDesign.space8),
                      Flexible(child: text),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
