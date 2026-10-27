import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/referral_service.dart';
import '../core/design_system.dart';
import '../core/form_factor.dart';
import '../core/haptics.dart';
import '../core/state/app_config_state.dart';
import '../core/state/billing_state.dart';
import '../core/state/dedicated_state.dart';
import '../core/state/invite_events.dart';
import '../core/state/invite_prompt.dart';
import '../core/state/referral_state.dart';
import '../data/models/billing.dart';
import '../l10n/generated/app_localizations.dart';
import '../screens/invite_screen.dart';
import '../screens/invite_tree_intro_screen.dart';
import '../screens/premium_screen.dart';
import '../utils/number_localizer.dart';
import 'invite_send.dart';
import 'invite_slots.dart';
import 'quota_card.dart';
import 'readable_width.dart';
import 'ui/sheet_handle.dart';

/// What a tap on Connect shows once the daily data is used up, and what
/// the home screen shows by itself once per refill.
///
/// The header says the data is used up and when it resets. Then, while
/// invites can still add data, comes the invite card: what the next friend
/// adds, a Share button that sends the invite from the sheet itself, and
/// links to the invite screen and, under the tree rule, to the step by step
/// introduction. Invites are the free way to more data, so Share is the
/// sheet's one filled button. Premium follows as an outlined button, and
/// only when BillingState.upsellOn allows it. Where invites cannot add more
/// (a TV, invites off, or invites already at the most) the sheet is as it
/// was: the header and Premium as the filled button.
///
/// The variant is decided once, as the sheet opens, so no button changes
/// its look under the user's finger. A status that loads while the sheet
/// is open fills in the amount, or, when it says invites add no more,
/// turns the card into that one line.
///
/// The home screen opens it for every phone, unless the app config turns
/// it off (FeatureFlags.limitSheet, which only `limit_sheet: false` does).
/// It never opens on a TV. The backend's upsell block naming `limit_sheet`
/// turns on the Premium row alone, through BillingState.upsellOn.
Future<void> showLimitSheet(BuildContext context) async {
  final billing = context.read<BillingState?>();
  final offers = billing?.upsellOn(UpsellSurface.limitSheet) ?? false;
  final referrals = context.read<ReferralState?>();
  final events = context.read<InviteEvents?>();
  final inviteLed =
      referrals != null &&
      (context.read<AppConfigState?>()?.referralsEnabled ?? false) &&
      !FormFactor.isTv &&
      !referrals.invitesAddNoMore;
  if (inviteLed) {
    // The status mints the code. The sheet never waits for it: the amount
    // fills in when it lands, and Share waits for it only when tapped.
    if (referrals.status == null && !referrals.isLoading) {
      unawaited(referrals.refresh());
    }
    events?.log(InviteSurface.limitSheetOffer, InviteAction.shown);
  }
  if (offers) billing!.logUpsell(UpsellSurface.limitSheet, UpsellAction.shown);
  final outcome = _Outcome();
  final picked = await showModalBottomSheet<_Pick>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _LimitSheet(
      offerPremium: offers,
      inviteLed: inviteLed,
      outcome: outcome,
      events: events,
    ),
  );
  if (inviteLed &&
      picked != _Pick.invites &&
      picked != _Pick.intro &&
      !outcome.shared) {
    events?.log(InviteSurface.limitSheetOffer, InviteAction.dismissed);
  }
  if (!context.mounted) return;
  switch (picked) {
    case _Pick.premium:
      billing?.logUpsell(UpsellSurface.limitSheet, UpsellAction.tapped);
      await PremiumScreen.open(context, source: PremiumSource.limitSheet);
    case _Pick.invites:
      if (offers) {
        billing?.logUpsell(UpsellSurface.limitSheet, UpsellAction.dismissed);
      }
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const ReadableWidth(
            child: InviteScreen(entry: InviteEntry.limitSheet),
          ),
        ),
      );
    case _Pick.intro:
      if (offers) {
        billing?.logUpsell(UpsellSurface.limitSheet, UpsellAction.dismissed);
      }
      await InviteTreeIntroScreen.open(context);
    case null:
      if (offers) {
        billing?.logUpsell(UpsellSurface.limitSheet, UpsellAction.dismissed);
      }
  }
}

enum _Pick { invites, intro, premium }

/// What happened on the sheet that its opener needs after it closes.
class _Outcome {
  /// A share from the sheet opened something.
  bool shared = false;
}

class _LimitSheet extends StatefulWidget {
  const _LimitSheet({
    required this.offerPremium,
    required this.inviteLed,
    required this.outcome,
    required this.events,
  });

  final bool offerPremium;

  /// The sheet leads with the invite card. Decided as it opened.
  final bool inviteLed;
  final _Outcome outcome;
  final InviteEvents? events;

  @override
  State<_LimitSheet> createState() => _LimitSheetState();
}

class _LimitSheetState extends State<_LimitSheet> {
  /// Share is waiting for the status to load.
  bool _busy = false;

  /// The status could not be loaded for a Share tap.
  bool _failed = false;

  /// A share from this sheet opened something.
  bool _shared = false;

  static bool _usable(ReferralStatus? status) =>
      status != null && status.code.isNotEmpty && status.shareUrl.isNotEmpty;

  /// Share the invite from the sheet. The status loads first when it is
  /// not here yet, joining a load already under way. The sheet stays open,
  /// because a pair needs two friends. Never throws.
  Future<void> _share() async {
    if (_busy) return;
    AppHaptics.light();
    try {
      final referrals = context.read<ReferralState?>();
      if (referrals == null) return;
      var status = referrals.status;
      if (!_usable(status)) {
        setState(() {
          _busy = true;
          _failed = false;
        });
        await referrals.refresh();
        if (!mounted) return;
        status = referrals.status;
        setState(() {
          _busy = false;
          _failed = !_usable(status);
        });
        if (!_usable(status) || referrals.invitesAddNoMore) return;
      }
      if (_failed) setState(() => _failed = false);
      final opened = await sendInvite(context, status!);
      if (!mounted || !opened) return;
      widget.events?.log(InviteSurface.limitSheetOffer, InviteAction.otherApps);
      try {
        unawaited(context.read<InvitePrompt?>()?.shared());
      } catch (e) {
        debugPrint('LimitSheet: invite card not ended ($e)');
      }
      widget.outcome.shared = true;
      setState(() => _shared = true);
    } catch (e) {
      debugPrint('LimitSheet: share failed ($e)');
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final quota = context.watch<DedicatedState>().quota;
    final refill = quota == null ? '' : QuotaCard.resetLabel(l10n, quota);
    final media = MediaQuery.of(context);
    // On a short screen or with large text the small drawing gives its
    // room to the words.
    final roomy = media.size.height >= 600 && media.textScaler.scale(10) < 13;
    final reduced = AppMotion.reduced(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppDesign.space24,
          0,
          AppDesign.space24,
          AppDesign.space12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: AppDesign.space8),
            _Header(
              title: l10n.premiumLimitSheetTitle,
              reset: refill.isEmpty ? l10n.myServersBlockedWait : refill,
              disc: roomy ? 44 : 40,
            ),
            const SizedBox(height: AppDesign.space16),
            if (widget.inviteLed) ...[
              _InviteCard(
                drawing: roomy,
                reduced: reduced,
                busy: _busy,
                failed: _failed,
                shared: _shared,
                onShare: () => unawaited(_share()),
                onInvites: () => Navigator.pop(context, _Pick.invites),
                onIntro: () => Navigator.pop(context, _Pick.intro),
              ),
              const SizedBox(height: AppDesign.space12),
            ],
            if (widget.offerPremium) ...[
              if (widget.inviteLed)
                _PremiumOutlined(
                  onTap: () => Navigator.pop(context, _Pick.premium),
                )
              else
                _PremiumFilled(
                  onTap: () => Navigator.pop(context, _Pick.premium),
                ),
              const SizedBox(height: AppDesign.space8),
            ],
            TextButton(
              key: const Key('limit-sheet-not-now'),
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: AppDesign.textSecondary,
              ),
              child: Text(l10n.premiumNotNow),
            ),
          ],
        ),
      ),
    );
  }
}

/// The hourglass, then the title and when the data resets, in one block.
/// The wait is the news, so it leads, as a warning: the data is used up
/// for now, which is not an error.
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.reset, required this.disc});

  final String title;
  final String reset;
  final double disc;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ExcludeSemantics(
          child: Container(
            key: const Key('limit-sheet-hourglass'),
            width: disc,
            height: disc,
            decoration: const BoxDecoration(
              color: AppDesign.warningContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_empty_rounded,
              color: AppDesign.warning,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: AppDesign.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: AppDesign.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppDesign.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppDesign.space2),
              Text(
                reset,
                key: const Key('limit-sheet-reset'),
                style: AppDesign.textTheme.bodyMedium?.copyWith(
                  color: AppDesign.textSecondary,
                  fontFeatures: AppDesign.numberFeatures,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The invite card: a small drawing of one friend joining, what the next
/// friend adds, Share, and the links to the invite screen and the tree
/// introduction. Once the status says invites add no more, only that line.
class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.drawing,
    required this.reduced,
    required this.busy,
    required this.failed,
    required this.shared,
    required this.onShare,
    required this.onInvites,
    required this.onIntro,
  });

  final bool drawing;
  final bool reduced;
  final bool busy;
  final bool failed;
  final bool shared;
  final VoidCallback onShare;
  final VoidCallback onInvites;
  final VoidCallback onIntro;

  static const double _heroDisc = 40;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final referrals = context.watch<ReferralState?>();
    final status = referrals?.status;
    final noMore = referrals?.invitesAddNoMore ?? false;
    final tree = status?.isTree ?? false;
    final line = _amountLine(context, status);

    final Widget body;
    if (noMore) {
      body = Row(
        key: const Key('limit-sheet-invites-full'),
        children: [
          const ExcludeSemantics(child: _GiftDisc(size: _heroDisc)),
          const SizedBox(width: AppDesign.space12),
          Expanded(
            child: Text(
              l10n.premiumLimitInvitesFull,
              style: AppDesign.textTheme.bodyMedium?.copyWith(
                color: AppDesign.textSecondary,
              ),
            ),
          ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (drawing) ...[
            _OneFriendArt(reduced: reduced),
            const SizedBox(height: AppDesign.space12),
          ],
          Text(
            l10n.premiumLimitInvite,
            style: AppDesign.textTheme.titleMedium?.copyWith(
              color: AppDesign.textPrimary,
            ),
          ),
          const SizedBox(height: AppDesign.space4),
          Semantics(
            liveRegion: true,
            child: AnimatedSwitcher(
              duration: reduced ? Duration.zero : AppMotion.quick,
              layoutBuilder: (current, previous) => Stack(
                alignment: AlignmentDirectional.topStart,
                children: [...previous, ?current],
              ),
              child: Text(
                line,
                key: ValueKey(line),
                style: AppDesign.textTheme.bodyMedium?.copyWith(
                  color: AppDesign.textSecondary,
                  fontFeatures: AppDesign.numberFeatures,
                ),
              ),
            ),
          ),
          if (shared && tree) ...[
            const SizedBox(height: AppDesign.space4),
            Text(
              l10n.inviteTreeHowPair,
              key: const Key('limit-sheet-pair-line'),
              style: AppDesign.textTheme.bodySmall?.copyWith(
                color: AppDesign.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: AppDesign.space16),
          FilledButton.icon(
            key: const Key('limit-sheet-share'),
            onPressed: onShare,
            icon: busy
                ? const ExcludeSemantics(
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppDesign.onBrand,
                      ),
                    ),
                  )
                : const Icon(Icons.share_rounded, size: 18),
            label: Text(
              shared ? l10n.premiumLimitShareAgain : l10n.inviteShareAction,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppDesign.brand,
              foregroundColor: AppDesign.onBrand,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (failed) ...[
            const SizedBox(height: AppDesign.space8),
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.inviteLoadFailed,
                key: const Key('limit-sheet-error'),
                style: AppDesign.textTheme.bodySmall?.copyWith(
                  color: AppDesign.error,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppDesign.space4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppDesign.space8,
            children: [
              TextButton(
                key: const Key('limit-sheet-invites'),
                onPressed: onInvites,
                style: TextButton.styleFrom(
                  foregroundColor: AppDesign.textSecondary,
                  minimumSize: const Size(48, 48),
                ),
                child: Text(l10n.premiumLimitSeeInvites),
              ),
              if (status != null && tree)
                TextButton.icon(
                  key: const Key('limit-sheet-intro'),
                  onPressed: onIntro,
                  icon: const Icon(Icons.auto_stories_outlined, size: 18),
                  label: Text(l10n.inviteTreeIntroTitle),
                  style: TextButton.styleFrom(
                    foregroundColor: AppDesign.textSecondary,
                    minimumSize: const Size(48, 48),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    final card = Container(
      key: const Key('limit-sheet-invite-card'),
      padding: const EdgeInsets.all(AppDesign.space16),
      decoration: BoxDecoration(
        color: AppDesign.surfaceLow,
        borderRadius: AppDesign.borderRadiusLarge,
      ),
      child: body,
    );
    // AnimatedSize with no duration relays itself out during layout, so
    // under reduced motion the card changes size at once without it.
    if (reduced) return card;
    return AnimatedSize(
      duration: AppMotion.medium,
      curve: AppMotion.standard,
      alignment: AlignmentDirectional.topStart,
      child: card,
    );
  }

  /// What the next friend adds, from the status the backend sent. Every
  /// amount and day count is the backend's; with none, a line that names
  /// no number.
  static String _amountLine(BuildContext context, ReferralStatus? status) {
    final l10n = S.of(context)!;
    if (status == null) return l10n.premiumLimitInviteNoAmount;
    if (status.isTree) {
      final next = status.nextInviteBytes;
      return next == null
          ? l10n.premiumLimitInviteNoAmount
          : l10n.inviteTreeSheetNext(inviteAmountText(context, next));
    }
    var each = status.bonusPerReferralBytes;
    final most = status.maxBonusBytes;
    if (each != null && most != null) {
      each = math.min(each, most - status.bonusBytes);
    }
    if (each == null || each <= 0) return l10n.premiumLimitInviteNoAmount;
    final amount = inviteAmountText(context, each);
    final days = status.confirmActiveDays;
    if (days == null) return l10n.premiumLimitInviteNextNoDays(amount);
    return NumberLocalizer.localize(
      l10n.premiumLimitInviteNext(amount, days),
      context,
    );
  }
}

/// The user's gift in an ember disc, as on the invite screen.
class _GiftDisc extends StatelessWidget {
  const _GiftDisc({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppDesign.brandContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.card_giftcard_rounded,
        size: size / 2,
        color: AppDesign.brandBright,
      ),
    );
  }
}

/// One friend joining the user: a line draws in from the gift, the
/// friend's slot turns active, and a plus lands on the gift. It plays once
/// as the sheet opens, and starts at its last frame under reduced motion.
/// It shows a single friend, which is true under both invite rules.
class _OneFriendArt extends StatelessWidget {
  const _OneFriendArt({required this.reduced});

  final bool reduced;

  static const double _artHeight = 48;
  static const double _heroDisc = 40;
  static const double _lineWidth = 24;
  static const double _slotDisc = 28;
  static const double _badgeDisc = 12;

  double _part(
    double t,
    double from,
    double to, [
    Curve curve = Curves.linear,
  ]) => curve.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        key: const Key('limit-sheet-drawing'),
        height: _artHeight,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: reduced ? 1 : 0, end: 1),
          duration: reduced
              ? Duration.zero
              : const Duration(milliseconds: 1000),
          builder: (context, t, _) {
            final line = _part(t, 0.25, 0.55, AppMotion.emphasizedDecelerate);
            final slot = _part(t, 0.55, 0.85, AppMotion.emphasizedDecelerate);
            final badge = _part(t, 0.85, 1);
            return Row(
              children: [
                SizedBox(
                  width: _heroDisc,
                  height: _heroDisc,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const _GiftDisc(size: _heroDisc),
                      PositionedDirectional(
                        end: -2,
                        bottom: -2,
                        child: Container(
                          width: _badgeDisc,
                          height: _badgeDisc,
                          decoration: BoxDecoration(
                            color: AppDesign.protected.withValues(alpha: badge),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: 9,
                            color: AppDesign.onProtected.withValues(
                              alpha: badge,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: _lineWidth,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      width: _lineWidth * line,
                      height: 1.5,
                      color: AppDesign.outlineVariant,
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 0.6 + 0.4 * slot,
                  child: SlotDisc(
                    look: SlotLook.lerp(
                      SlotLook.of(TreeSlot.empty),
                      SlotLook.of(TreeSlot.active),
                      slot,
                    ),
                    size: _slotDisc,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Premium beside the invite card: outlined, so Share stays the sheet's
/// one filled button.
class _PremiumOutlined extends StatelessWidget {
  const _PremiumOutlined({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return OutlinedButton(
      key: const Key('limit-sheet-premium'),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        side: const BorderSide(color: AppDesign.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppDesign.space16,
          AppDesign.space8,
          AppDesign.space20,
          AppDesign.space8,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.all_inclusive_rounded,
            size: 22,
            color: AppDesign.brandBright,
          ),
          const SizedBox(width: AppDesign.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.premiumGetUnlimited,
                  style: AppDesign.textTheme.labelLarge?.copyWith(
                    color: AppDesign.textPrimary,
                  ),
                ),
                Text(
                  l10n.premiumNoDailyLimit,
                  style: AppDesign.textTheme.bodySmall?.copyWith(
                    color: AppDesign.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium on a sheet with no invite card: the one filled button, as it
/// always was.
class _PremiumFilled extends StatelessWidget {
  const _PremiumFilled({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: AppDesign.space4),
      child: FilledButton(
        key: const Key('limit-sheet-premium'),
        onPressed: onTap,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppDesign.space16,
            AppDesign.space8,
            AppDesign.space20,
            AppDesign.space8,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.all_inclusive_rounded, size: 22),
            const SizedBox(width: AppDesign.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.premiumGetUnlimited),
                  Text(
                    l10n.premiumNoDailyLimit,
                    style: AppDesign.textTheme.bodySmall?.copyWith(
                      color: AppDesign.onBrand,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
