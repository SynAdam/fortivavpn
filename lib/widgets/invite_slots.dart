import 'package:flutter/material.dart';

import '../api/referral_service.dart';
import '../core/design_system.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/number_localizer.dart';
import 'quota_card.dart';

/// The pieces the invite screen, the limit sheet and the introduction to
/// the invite tree share: how a slot looks, a pair of slots, and an amount
/// as the backend sent it.

/// A reward amount as the backend reports it, ready to show ("1 GB",
/// localized digits), or null when the backend did not say. The app never
/// states these numbers on its own, because a number written into the app
/// stays wrong on every phone until the next release reaches it. It used
/// to say 250 MB per friend here.
String? inviteAmount(BuildContext context, int? bytes) {
  if (bytes == null) return null;
  return inviteAmountText(context, bytes);
}

/// [bytes] as an amount with its unit ("1 GB") in the app's digits, and
/// with the same decimal sign as the quota card ("۱٫۵ GB"). A no-break
/// space joins the number to its unit, so a line never ends between them:
/// in Persian a lone "۱" at the end of one line and "GB" at the start of
/// the next read as two separate words.
String inviteAmountText(BuildContext context, int bytes) =>
    NumberLocalizer.localizeAmount(
      QuotaCard.formatAllowance(bytes),
      context,
    ).replaceAll(' ', ' ');

/// How one kind of slot is drawn: its fill, its edge, its icon and the
/// icon's color.
@immutable
class SlotLook {
  const SlotLook({
    required this.fill,
    required this.edge,
    required this.icon,
    required this.iconColor,
  });

  final Color fill;
  final Color edge;
  final IconData icon;
  final Color iconColor;

  /// Filled for an active friend, outlined with a person for a friend who
  /// is not active now, and a faint ring with a plus when open.
  static SlotLook of(TreeSlot slot) => switch (slot) {
    TreeSlot.active => const SlotLook(
      fill: AppDesign.protected,
      edge: AppDesign.protected,
      icon: Icons.person_rounded,
      iconColor: AppDesign.onProtected,
    ),
    TreeSlot.joined => const SlotLook(
      fill: AppDesign.surfaceHigh,
      edge: AppDesign.steelMid,
      icon: Icons.person_outline_rounded,
      iconColor: AppDesign.textSecondary,
    ),
    TreeSlot.empty => const SlotLook(
      fill: Colors.transparent,
      edge: AppDesign.outlineVariant,
      icon: Icons.add_rounded,
      iconColor: AppDesign.textTertiary,
    ),
  };

  /// The look part way from [a] to [b]. The icon changes half way.
  static SlotLook lerp(SlotLook a, SlotLook b, double t) => SlotLook(
    fill: Color.lerp(a.fill, b.fill, t)!,
    edge: Color.lerp(a.edge, b.edge, t)!,
    icon: t < 0.5 ? a.icon : b.icon,
    iconColor: Color.lerp(a.iconColor, b.iconColor, t)!,
  );
}

/// A slot drawn as a disc in [look], saying nothing to a screen reader.
class SlotDisc extends StatelessWidget {
  const SlotDisc({super.key, required this.look, this.size = 32});

  final SlotLook look;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: look.fill,
        shape: BoxShape.circle,
        border: Border.all(color: look.edge, width: 1.5),
      ),
      child: Icon(look.icon, size: size * 0.55, color: look.iconColor),
    );
  }
}

/// One slot drawn as a disc. A screen reader reads its state, unless
/// [labelled] is false, as in a drawing whose slots are only examples.
class SlotMark extends StatelessWidget {
  const SlotMark({
    super.key,
    required this.slot,
    this.size = 32,
    this.labelled = true,
  });

  final TreeSlot slot;
  final double size;
  final bool labelled;

  static String label(S l10n, TreeSlot slot) => switch (slot) {
    TreeSlot.active => l10n.inviteTreeSlotActive,
    TreeSlot.joined => l10n.inviteTreeSlotNotActive,
    TreeSlot.empty => l10n.inviteTreeSlotEmpty,
  };

  @override
  Widget build(BuildContext context) {
    final disc = ExcludeSemantics(
      child: SlotDisc(look: SlotLook.of(slot), size: size),
    );
    if (!labelled) return disc;
    return Semantics(label: label(S.of(context)!, slot), child: disc);
  }
}

/// What the kinds of slot look like: active first, then not active now,
/// then open. [states] picks which of them, in that order.
class SlotLegend extends StatelessWidget {
  const SlotLegend({super.key, this.states = TreeSlot.values});

  final List<TreeSlot> states;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    // A key, not content: a screen reader hears each slot's state on the
    // slot itself.
    return ExcludeSemantics(
      child: Wrap(
        spacing: AppDesign.space12,
        runSpacing: AppDesign.space4,
        children: [
          for (final slot in TreeSlot.values.reversed)
            if (states.contains(slot))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SlotMark(slot: slot, size: 16, labelled: false),
                  const SizedBox(width: AppDesign.space4),
                  Text(
                    SlotMark.label(l10n, slot),
                    style: AppDesign.textTheme.labelMedium?.copyWith(
                      color: AppDesign.textTertiary,
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}

/// A pair of slots in one rounded capsule. The discs sit in a row, so the
/// first slot is on the start side in both directions.
///
/// [discBuilder] draws a disc in place of a [SlotMark], for a drawing that
/// moves its slots from one look to another.
class PairCapsule extends StatelessWidget {
  const PairCapsule({
    super.key,
    required this.slots,
    this.discSize = 32,
    this.gap = 4,
    this.padding = 6,
    this.fill = AppDesign.surfaceHigh,
    this.edge,
    this.labelled = true,
    this.discBuilder,
  });

  final List<TreeSlot> slots;
  final double discSize;
  final double gap;
  final double padding;
  final Color fill;
  final Color? edge;
  final bool labelled;
  final Widget Function(int index, TreeSlot slot)? discBuilder;

  @override
  Widget build(BuildContext context) {
    final edge = this.edge;
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppDesign.radiusFull),
        border: edge == null ? null : Border.all(color: edge, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, slot) in slots.indexed) ...[
            if (i > 0) SizedBox(width: gap),
            discBuilder?.call(i, slot) ??
                SlotMark(slot: slot, size: discSize, labelled: labelled),
          ],
        ],
      ),
    );
  }
}
