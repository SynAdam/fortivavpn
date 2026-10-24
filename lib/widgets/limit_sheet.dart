import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design_system.dart';
import '../core/state/app_config_state.dart';
import '../core/state/billing_state.dart';
import '../core/state/dedicated_state.dart';
import '../data/models/billing.dart';
import '../l10n/generated/app_localizations.dart';
import '../screens/invite_screen.dart';
import '../screens/premium_screen.dart';
import 'quota_card.dart';
import 'readable_width.dart';
import 'ui/pressable.dart';
import 'ui/sheet_handle.dart';

/// What a tap on Connect shows once the daily data is used up, and what
/// the home screen shows by itself once per refill.
///
/// Before this a tap then did nothing anyone could see. The sheet says
/// when the data resets, then offers invites, the free way to more data,
/// when they are on, and only then Premium, as the one filled button. The
/// Premium button needs BillingState.upsellOn, so a phone the backend keeps
/// from offers gets the same sheet without it.
///
/// The home screen opens it for every phone, unless the app config turns
/// it off (FeatureFlags.limitSheet, which only `limit_sheet: false` does).
/// It never opens on a TV. The backend's upsell block naming `limit_sheet`
/// turns on the Premium row alone, through BillingState.upsellOn.
Future<void> showLimitSheet(BuildContext context) async {
  final billing = context.read<BillingState?>();
  final offers = billing?.upsellOn(UpsellSurface.limitSheet) ?? false;
  if (offers) billing!.logUpsell(UpsellSurface.limitSheet, UpsellAction.shown);
  final picked = await showModalBottomSheet<_Pick>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _LimitSheet(offerPremium: offers),
  );
  if (!context.mounted) return;
  switch (picked) {
    case _Pick.premium:
      billing?.logUpsell(UpsellSurface.limitSheet, UpsellAction.tapped);
      await PremiumScreen.open(context, source: PremiumSource.limitSheet);
    case _Pick.invite:
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
    case null:
      if (offers) {
        billing?.logUpsell(UpsellSurface.limitSheet, UpsellAction.dismissed);
      }
  }
}

enum _Pick { invite, premium }

class _LimitSheet extends StatelessWidget {
  const _LimitSheet({required this.offerPremium});

  /// The plate behind the hourglass.
  static const double _badgeSize = 56;

  final bool offerPremium;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final quota = context.watch<DedicatedState>().quota;
    final refill = quota == null ? '' : QuotaCard.resetLabel(l10n, quota);
    final invites = context.watch<AppConfigState?>()?.referralsEnabled ?? false;
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
            // The wait is the news here, so it leads, as a warning: the
            // data is spent for now, which is not an error.
            Center(
              child: Container(
                width: _badgeSize,
                height: _badgeSize,
                decoration: const BoxDecoration(
                  color: AppDesign.warningContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_empty_rounded,
                  color: AppDesign.warning,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: AppDesign.space16),
            Text(
              l10n.premiumLimitSheetTitle,
              textAlign: TextAlign.center,
              style: AppDesign.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppDesign.space8),
            Text(
              l10n.premiumLimitWait,
              textAlign: TextAlign.center,
              style: AppDesign.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDesign.space2),
            Text(
              refill.isEmpty ? l10n.myServersBlockedWait : refill,
              textAlign: TextAlign.center,
              style: AppDesign.textTheme.titleSmall?.copyWith(
                color: AppDesign.textPrimary,
                fontFeatures: AppDesign.numberFeatures,
              ),
            ),
            const SizedBox(height: AppDesign.space24),
            // The free way to more data first, then Premium.
            if (invites)
              _Row(
                icon: Icons.card_giftcard_outlined,
                title: l10n.premiumLimitInvite,
                onTap: () => Navigator.pop(context, _Pick.invite),
              ),
            if (offerPremium)
              Padding(
                padding: const EdgeInsets.only(top: AppDesign.space4),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _Pick.premium),
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
              ),
            const SizedBox(height: AppDesign.space8),
            TextButton(
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

/// One free way to more data: a tonal row with a chevron.
class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesign.space8),
      child: Pressable(
        onTap: onTap,
        color: AppDesign.surfaceHigh,
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppDesign.space16,
          AppDesign.space12,
          AppDesign.space12,
          AppDesign.space12,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Row(
            children: [
              Icon(icon, color: AppDesign.steelLight, size: 22),
              const SizedBox(width: AppDesign.space12),
              Expanded(
                child: Text(title, style: AppDesign.textTheme.labelLarge),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppDesign.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
