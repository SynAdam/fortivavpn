import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/referral_service.dart';
import '../core/design_system.dart';
import '../core/form_factor.dart';
import '../core/state/invite_events.dart';
import '../core/state/invite_prompt.dart';
import '../core/state/referral_state.dart';
import '../services/invite_share.dart';
import '../utils/number_localizer.dart';
import '../widgets/invite_code_dialog.dart';
import '../widgets/outside_link.dart';
import '../widgets/quota_card.dart';
import '../widgets/remote_refresh_button.dart';
import '../widgets/ui/pressable.dart';
import '../l10n/generated/app_localizations.dart';

/// The invite screen: this device's code, what it has earned, and a way
/// to share it.
///
/// Only the person sharing is rewarded. App Review rejects referral
/// programs that reward the person accepting an invitation, so nothing
/// on this screen or the claim dialog promises a new user anything.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key, this.entry = InviteEntry.settings});

  /// Where the screen was opened from, for the invite events.
  final InviteEntry entry;

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  /// Whether the first load has finished. Until then the screen shows that
  /// it is loading, not that loading failed: the load starts after the
  /// first frame, so that frame has no status and no load under way yet.
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    // The first call is what mints the code on the backend, which is why
    // a device that never opens this screen never consumes one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_firstLoad(context.read<ReferralState>()));
    });
    _log(switch (widget.entry) {
      InviteEntry.homeButton => InviteSurface.homeButton,
      InviteEntry.limitSheet => InviteSurface.limitSheet,
      InviteEntry.quotaLine => InviteSurface.quotaLine,
      InviteEntry.settings => InviteSurface.inviteScreen,
    }, InviteAction.shown);
  }

  Future<void> _firstLoad(ReferralState state) async {
    try {
      await state.refresh();
    } catch (e) {
      debugPrint('InviteScreen: first load failed ($e)');
    } finally {
      if (mounted) setState(() => _asked = true);
    }
  }

  /// Note an invite event while the user shares diagnostics. Never throws.
  void _log(InviteSurface surface, InviteAction action) {
    try {
      context.read<InviteEvents?>()?.log(surface, action);
    } catch (e) {
      debugPrint('InviteScreen: invite event not kept ($e)');
    }
  }

  /// A share or a copy here ends the invite card on the home screen for
  /// good.
  void _shared(InviteAction action) {
    _log(InviteSurface.inviteScreen, action);
    try {
      unawaited(context.read<InvitePrompt?>()?.shared());
    } catch (e) {
      debugPrint('InviteScreen: invite card not ended ($e)');
    }
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    _shared(InviteAction.copyLink);
    _toast(S.of(context)!.inviteCodeCopied);
  }

  Future<void> _share(ReferralStatus status) async {
    // A TV has no share sheet worth the name, and nothing on it to send an
    // invite through. The link goes to the user's phone as a QR code, and
    // is shared from there.
    final link = Uri.tryParse(status.shareUrl);
    if (FormFactor.isTv && link != null) {
      await LinkQrDialog.show(link);
      return;
    }
    final l10n = S.of(context)!;
    // sharePositionOrigin is what anchors the popover on iPad; without it
    // the share sheet has nowhere to point and iPadOS throws.
    final box = context.findRenderObject() as RenderBox?;
    // The share sheet hides the state messengers: the backend's list, or
    // the app's own while the backend sent none.
    final opened = await InviteShare.send(
      text: l10n.inviteShareMessage(status.code, status.shareUrl),
      target: InviteTarget.otherApps,
      exclude: status.shareExcludePackages.isEmpty
          ? null
          : status.shareExcludePackages,
      title: l10n.inviteTitle,
      origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
    if (!mounted || opened == InviteShareOutcome.none) return;
    _shared(InviteAction.otherApps);
  }

  void _toast(String message) {
    // The theme's snackbar colors: light text on the bar.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;

    return Scaffold(
      backgroundColor: AppDesign.canvas,
      appBar: AppBar(
        backgroundColor: AppDesign.canvas,
        title: Text(l10n.inviteTitle),
        actions: [
          RemoteRefreshButton(
            onRefresh: () => context.read<ReferralState>().refresh(),
          ),
        ],
      ),
      body: Consumer<ReferralState>(
        builder: (context, state, _) {
          if (!state.hasStatus && (state.isLoading || !_asked)) {
            return const Center(child: CircularProgressIndicator());
          }

          final status = state.status;
          if (status == null) {
            return _ErrorBody(
              message: l10n.inviteLoadFailed,
              retryLabel: l10n.inviteRetry,
              onRetry: () => context.read<ReferralState>().refresh(),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<ReferralState>().refresh(),
            color: AppDesign.brandBright,
            backgroundColor: AppDesign.surfaceHigh,
            child: ListView(
              padding: AppDesign.clearOfNavBar(
                context,
                const EdgeInsets.fromLTRB(16, 8, 16, 32),
              ),
              children: [
                _InviteHero(text: l10n.inviteSubtitle),
                const SizedBox(height: AppDesign.space24),
                _CodeCard(
                  code: status.code,
                  onCopy: () => _copy(status.code),
                  onShare: () => _share(status),
                ),
                const SizedBox(height: AppDesign.space12),
                _StatsRow(status: status),
                if (status.pendingCount > 0) ...[
                  const SizedBox(height: AppDesign.space8),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 4),
                    child: Text(
                      NumberLocalizer.localize(
                        l10n.invitePendingNote(status.pendingCount),
                        context,
                      ),
                      style: AppDesign.textTheme.bodySmall,
                    ),
                  ),
                ],
                // The code and what it has earned are one group, then How it
                // works, then the way in for a code from a friend.
                const SizedBox(height: AppDesign.space24),
                _HowItWorksCard(
                  bonus: _amount(context, status.bonusPerReferralBytes),
                  cap: _amount(context, status.maxBonusBytes),
                  days: status.confirmActiveDays,
                  premiumDays: status.earns ? status.rewardPremiumDays : null,
                  premiumMax: status.premiumDaysMax,
                ),
                const SizedBox(height: AppDesign.space24),
                if (status.hasClaimed)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 4),
                    child: Text(
                      l10n.inviteJoinedWith(status.claimedCode!),
                      style: AppDesign.textTheme.bodySmall,
                    ),
                  )
                else
                  _HaveACodeTile(
                    subtitle: inviteHaveCodeSubtitleText(
                      context,
                      status.claimWindowHours,
                    ),
                    onTap: () => showInviteCodeDialog(context),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A reward amount as the backend reports it, ready to show ("1 GB",
/// localized digits), or null when the backend did not say. The app never
/// states these numbers on its own, because a number written into the app
/// stays wrong on every phone until the next release reaches it. It used
/// to say 250 MB per friend here.
String? _amount(BuildContext context, int? bytes) {
  if (bytes == null) return null;
  return _amountText(context, bytes);
}

/// [bytes] as an amount with its unit ("1 GB") in the app's digits, and
/// with the same decimal sign as the quota card ("۱٫۵ GB"). A no-break
/// space joins the number to its unit, so a line never ends between them:
/// in Persian a lone "۱" at the end of one line and "GB" at the start of
/// the next read as two separate words.
String _amountText(BuildContext context, int bytes) =>
    NumberLocalizer.localizeAmount(
      QuotaCard.formatAllowance(bytes),
      context,
    ).replaceAll(' ', '\u00A0');

/// The space between the letters of the invite code.
///
/// The code is Latin letters and digits in every language, so it keeps
/// this spacing in Persian, Arabic and Urdu too: AppDesign.ls is for text
/// that may be in a joined script, and a code never is.
const double _codeLetterSpacing = 4;

/// The top of the invite screen: a gift in an ember disc over the
/// line that says what invites earn.
class _InviteHero extends StatelessWidget {
  const _InviteHero({required this.text});

  final String text;

  static const double _disc = 56;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppDesign.brandContainer,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: _disc,
              child: Icon(
                Icons.card_giftcard_rounded,
                size: 28,
                color: AppDesign.brandBright,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDesign.space12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: AppDesign.textTheme.titleMedium?.copyWith(
            color: AppDesign.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// The code on a recessed strip, then Share and Copy code.
class _CodeCard extends StatelessWidget {
  final String code;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  const _CodeCard({
    required this.code,
    required this.onCopy,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    // Spacing goes after every letter, the last one too, so the code is
    // moved over by the same amount to sit in the middle.
    const tracking = _codeLetterSpacing;
    // Unlike the other cards on this screen, the code card keeps a hairline
    // edge, because the design draws the code that way.
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppDesign.surfaceLow,
        borderRadius: AppDesign.borderRadiusLarge,
        border: Border.all(color: AppDesign.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.inviteYourCode,
            textAlign: TextAlign.center,
            style: AppDesign.textTheme.labelMedium?.copyWith(
              color: AppDesign.textTertiary,
            ),
          ),
          const SizedBox(height: AppDesign.space8),
          Container(
            padding: const EdgeInsets.fromLTRB(12 + tracking, 8, 12, 8),
            decoration: BoxDecoration(
              color: AppDesign.canvasDeep,
              borderRadius: AppDesign.borderRadiusMedium,
            ),
            // Latin letters and digits, the same in every language, read
            // left to right. The locale and the fonts to fall back on are
            // fixed to Latin ones, so the app's language cannot change the
            // code's face.
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontFamilyFallback: <String>[],
                  locale: Locale('en'),
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  letterSpacing: tracking,
                  color: AppDesign.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDesign.space16),
          LayoutBuilder(
            builder: (context, constraints) {
              final share = FilledButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.share_rounded, size: 18),
                label: Text(l10n.inviteShareAction),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              );
              const gap = AppDesign.space8;
              final half = (constraints.maxWidth - gap) / 2;
              final scaler = MediaQuery.textScalerOf(context);
              final side = [
                l10n.inviteShareAction,
                l10n.inviteCopyAction,
              ].every((label) => _fitsHalf(label, half, scaler, context));
              final copy = OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(l10n.inviteCopyAction),
                // Under Share it is a step lower than the one filled
                // button. Beside it, it is as tall, so the pair lines up.
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.fromHeight(side ? 52 : 48),
                ),
              );
              // Side by side where both labels fit half the card, as on a
              // tablet or in a short language; one above the other on most
              // phones, Share first.
              if (side) {
                return Row(
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: gap),
                    Expanded(child: share),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  share,
                  const SizedBox(height: gap),
                  copy,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Whether a button with [label] and its icon fits in [room] on one
  /// line: the theme's button text, its side padding, the icon and the gap
  /// after it.
  static bool _fitsHalf(
    String label,
    double room,
    TextScaler scaler,
    BuildContext context,
  ) {
    const chrome = 2 * 24 + 18 + 8;
    final painter = TextPainter(
      text: TextSpan(text: label, style: AppDesign.textTheme.labelLarge),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final fits = painter.width + chrome <= room;
    painter.dispose();
    return fits;
  }
}

class _StatsRow extends StatelessWidget {
  final ReferralStatus status;

  const _StatsRow({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final earned = status.bonusBytes > 0;
    final bonus = earned
        ? l10n.inviteBonusPerDay(_amountText(context, status.bonusBytes))
        : l10n.inviteNoBonusYet;
    String count(int n) => NumberLocalizer.localize('$n', context);

    // The three tiles stand as tall as the tallest, so their captions line
    // up whatever the bonus line wraps to.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Stat(
              label: l10n.inviteStatInvited,
              value: count(status.invitedCount),
            ),
          ),
          const SizedBox(width: AppDesign.space8),
          Expanded(
            child: _Stat(
              label: l10n.inviteStatEarning,
              value: count(status.confirmedCount),
            ),
          ),
          const SizedBox(width: AppDesign.space8),
          Expanded(
            flex: 2,
            child: _Stat(
              label: l10n.inviteStatBonus,
              value: bonus,
              phrase: true,
              highlight: earned,
            ),
          ),
        ],
      ),
    );
  }
}

/// One tonal tile: the value large, its caption under it.
class _Stat extends StatelessWidget {
  final String label;
  final String value;

  /// The value is words, not a count, so it is drawn smaller and may wrap.
  final bool phrase;
  final bool highlight;

  const _Stat({
    required this.label,
    required this.value,
    this.phrase = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle = phrase
        ? AppDesign.textTheme.titleMedium
        : AppDesign.textTheme.headlineSmall;
    return Container(
      padding: const EdgeInsets.all(AppDesign.space12),
      decoration: BoxDecoration(
        color: AppDesign.surfaceLow,
        borderRadius: AppDesign.borderRadiusMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            value,
            style: valueStyle?.copyWith(
              color: highlight ? AppDesign.protected : AppDesign.textPrimary,
              fontFeatures: AppDesign.numberFeatures,
            ),
          ),
          const SizedBox(height: AppDesign.space4),
          Text(
            label,
            style: AppDesign.textTheme.labelMedium?.copyWith(
              color: AppDesign.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  /// The per-friend reward, already formatted, or null to name no amount.
  final String? bonus;

  /// The most invites can add per day, already formatted, or null to
  /// leave the limit out.
  final String? cap;

  /// On how many different days a friend must use the VPN before the
  /// invite pays, or null to name no number.
  final int? days;

  /// The Premium days the next confirmed friend gives, or null for no line.
  final int? premiumDays;

  /// The most Premium days invites can give, or null for no line.
  final int? premiumMax;

  const _HowItWorksCard({
    required this.bonus,
    required this.cap,
    required this.days,
    this.premiumDays,
    this.premiumMax,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final max = cap;
    final body = switch ((bonus, days)) {
      (final String amount, final int days) => l10n.inviteHowItWorksBody(
        amount,
        days,
      ),
      (final String amount, null) => l10n.inviteHowItWorksBodyNoDays(amount),
      (null, final int days) => l10n.inviteHowItWorksBodyNoAmount(days),
      (null, null) => l10n.inviteHowItWorksBodyNoAmountNoDays,
    };
    // Each sentence on its own row with an icon for what it is about. The
    // sentences stay whole, as they were written.
    final rows = <(IconData, String)>[
      (Icons.group_add_outlined, NumberLocalizer.localize(body, context)),
      if (max != null)
        (Icons.add_circle_outline_rounded, l10n.inviteHowItWorksCap(max)),
      // Reward B: Premium days per confirmed friend, as the backend says.
      // Nothing while it is off.
      if (premiumDays case final days?)
        (
          Icons.card_giftcard_outlined,
          NumberLocalizer.localize(l10n.inviteHowItWorksPremium(days), context),
        ),
      if (premiumMax case final most?)
        (
          Icons.event_available_outlined,
          NumberLocalizer.localize(
            l10n.inviteHowItWorksPremiumCap(most),
            context,
          ),
        ),
    ];
    // The shared card look: a tone above the canvas, no edge.
    return Container(
      padding: const EdgeInsets.all(AppDesign.space16),
      decoration: BoxDecoration(
        color: AppDesign.surfaceLow,
        borderRadius: AppDesign.borderRadiusLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.inviteHowItWorks,
              style: AppDesign.textTheme.titleSmall?.copyWith(
                color: AppDesign.textPrimary,
              ),
            ),
          ),
          for (final (icon, text) in rows)
            Padding(
              padding: const EdgeInsets.only(top: AppDesign.space12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: AppDesign.steelLight),
                  const SizedBox(width: AppDesign.space12),
                  Expanded(
                    child: Text(text, style: AppDesign.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The way in for a code from a friend, drawn as a Settings row: the icon
/// in a small rounded square, the title and its line, and a chevron.
class _HaveACodeTile extends StatelessWidget {
  final String subtitle;
  final VoidCallback onTap;

  const _HaveACodeTile({required this.subtitle, required this.onTap});

  /// The Settings row's least height and icon square.
  static const double _minHeight = 64;
  static const double _iconBox = 36;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return Pressable(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minHeight),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: _iconBox,
                height: _iconBox,
                decoration: BoxDecoration(
                  color: AppDesign.surfaceHigh,
                  borderRadius: AppDesign.borderRadiusSmall,
                ),
                // Steel, as in Settings: the ember on this screen is the
                // gift at the top and the Share button.
                child: const Icon(
                  Icons.redeem_outlined,
                  size: 20,
                  color: AppDesign.steelLight,
                ),
              ),
              const SizedBox(width: AppDesign.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.inviteHaveCodeTitle,
                      style: AppDesign.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppDesign.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppDesign.space2),
                    Text(subtitle, style: AppDesign.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppDesign.space8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppDesign.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  const _ErrorBody({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDesign.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppDesign.surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: AppDesign.textTertiary,
                size: 26,
              ),
            ),
            const SizedBox(height: AppDesign.space16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppDesign.textTheme.bodyLarge?.copyWith(
                color: AppDesign.textSecondary,
              ),
            ),
            const SizedBox(height: AppDesign.space16),
            FilledButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}

/// Where the invite screen was opened from. [quotaLine] is the invite
/// link on the home data line.
enum InviteEntry { homeButton, limitSheet, quotaLine, settings }
