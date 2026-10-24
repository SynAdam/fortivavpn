import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/design_system.dart';
import '../core/state/billing_state.dart';
import '../data/models/billing.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/play_billing.dart';
import '../utils/app_date.dart';
import '../utils/number_localizer.dart';
import '../widgets/readable_width.dart';
import '../widgets/outside_link.dart';
import '../widgets/redeem_code_dialog.dart';
import '../widgets/remote_refresh_button.dart';

export '../data/models/billing.dart' show PremiumSource;

/// Premium: whether this device has it and until when, its key, and the
/// ways to buy it that the backend allows.
///
/// Reached from Settings > Account, the quota card and the spent-allowance
/// notice, as BillingState.tile and offersAllowed allow, from the offers
/// the backend turns on (BillingState.upsellOn), and from the Premium pill
/// of a Premium device. Every price, length and billing period on it comes
/// from the backend or from Google Play: the app names none of its own.
/// What is on sale follows the backend's answer alone, the same in every
/// country.
///
/// The headline follows what the user tapped ([source]): "No daily limit"
/// from anything about the daily limit, "Unlock Helsinki with Premium"
/// from a locked location in Helsinki. Under the plans it says the free plan keeps working
/// without Premium, as Google Play asks.
///
/// Every copy of the app shows this same screen: Google Play's plans,
/// Restore purchases, the link to manage or cancel the subscription, and,
/// when the backend allows it, "Enter a code". Each Play plan says how
/// often Play bills for it and that it renews until the user cancels, and
/// the screen links to Google Play's page for managing or canceling the
/// subscription, as Google Play's subscriptions policy asks. Restore
/// purchases and that link stay while sales are off, as long as the
/// backend lets the phone restore.
///
/// The Play parts need a copy that can use Google Play Billing
/// (BillingState.playSupported), which only the copy Google Play signed
/// can. Any other copy, such as the APK posted in the Telegram channel,
/// shows "Enter a code" and one line saying that buying through Google
/// Play needs the Google Play version. No copy shows, names or links any
/// other way to pay, as Google Play's payments policy asks.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({
    super.key,
    this.source = PremiumSource.settings,
    this.place,
  });

  /// Where the screen was opened from. A purchase made here carries it.
  final PremiumSource source;

  /// The city of the locked location it was opened from, or null.
  final String? place;

  /// Open the screen from [source].
  static Future<void> open(
    BuildContext context, {
    PremiumSource source = PremiumSource.settings,
    String? place,
  }) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ReadableWidth(
        child: PremiumScreen(source: source, place: place),
      ),
    ),
  );

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  /// Restore and Manage in a quiet tone, so the crest's color stays on the
  /// buttons that buy.
  static final ButtonStyle _quiet = TextButton.styleFrom(
    foregroundColor: AppDesign.textSecondary,
  );

  late final BillingState _billing;

  /// The plan whose Buy was tapped here, for the spinner in that button
  /// while Play's sheet is open and the purchase is confirmed.
  Plan? _buying;

  @override
  void initState() {
    super.initState();
    _billing = context.read<BillingState>()..premiumScreenOpened(widget.source);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _billing.refresh();
    });
  }

  @override
  void dispose() {
    _billing.premiumScreenClosed(widget.source);
    super.dispose();
  }

  String _headline(S l10n) {
    final city = widget.place;
    if (widget.source == PremiumSource.lockedServer && city != null) {
      return l10n.premiumHeadlineLocked(city);
    }
    if (widget.source.aboutTheLimit) return l10n.premiumHeadlineLimit;
    return l10n.premiumHeadline;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final billing = context.watch<BillingState>();
    // The spinner follows only a purchase started from a Buy here. Once
    // Play's flow ends it is forgotten, so a later confirmation (after a
    // restore, say) puts no spinner on a plan tapped long before.
    if (!billing.playBusy) _buying = null;
    final premium = billing.premium;
    final code = premium.code;
    final endedAt = premium.active ? null : billing.renewal?.endedAt;

    return Scaffold(
      backgroundColor: AppDesign.canvas,
      appBar: AppBar(
        title: Text(l10n.premiumTitle),
        backgroundColor: AppDesign.canvas,
        actions: [RemoteRefreshButton(onRefresh: billing.refresh)],
      ),
      body: RefreshIndicator(
        onRefresh: billing.refresh,
        color: AppDesign.brandBright,
        backgroundColor: AppDesign.surfaceHigh,
        child: ListView(
          padding: AppDesign.clearOfNavBar(
            context,
            const EdgeInsets.fromLTRB(16, 8, 16, 24),
          ),
          children: [
            // A device with Premium sees its status first. The others see
            // the offer: the shield, the headline and the pitch.
            if (premium.active)
              _StatusCard(premium: premium)
            else ...[
              _PremiumHero(title: _headline(l10n), body: l10n.premiumPitch),
              if (endedAt != null) ...[
                const SizedBox(height: 20),
                _StatusCard(premium: premium, endedAt: endedAt),
              ],
            ],
            if (code != null) ...[
              const SizedBox(height: 12),
              PremiumKeyCard(
                code: code,
                moveLimit: billing.moveLimit,
                moveWindowDays: billing.moveWindowDays,
              ),
            ],
            const SizedBox(height: 24),
            ..._body(context, l10n, billing),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, S l10n, BillingState billing) {
    if (!billing.hasLoaded) {
      // Before the first load has even started, as well as during it.
      if (billing.isLoading || !billing.loadFailed) {
        return const [Center(child: CircularProgressIndicator())];
      }
      return [
        PremiumNote(
          text: l10n.premiumLoadFailed,
          tone: PremiumNoteTone.problem,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: billing.refresh,
            child: Text(l10n.premiumRetry),
          ),
        ),
      ];
    }
    if (!billing.enabled) {
      // Nothing is on sale, and a copy that can use Google Play may still
      // restore what the Google account already pays for.
      return [
        if (!billing.premium.active) PremiumNote(text: l10n.premiumOff),
        ..._playRails(context, l10n, billing),
      ];
    }
    return [
      if (billing.playSupported)
        ..._playRails(context, l10n, billing)
      else if (billing.rails.googlePlay) ...[
        // Google Play sells here, but not in this copy. The line names no
        // other way to pay.
        PremiumNote(text: l10n.premiumNeedsPlayVersion),
        const SizedBox(height: 8),
      ],
      if (!billing.premium.active)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 12, 4, 0),
          child: Text(
            l10n.premiumFreeStays,
            textAlign: TextAlign.center,
            style: AppDesign.textTheme.bodySmall?.copyWith(
              color: AppDesign.textTertiary,
            ),
          ),
        ),
      if (billing.rails.codes) ...[
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => showRedeemCodeDialog(context),
          icon: const Icon(Icons.vpn_key_outlined, size: 18),
          label: Text(l10n.premiumEnterCode),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
      ],
    ];
  }

  /// Google Play's plans, with Play's prices and how often each bills,
  /// Restore purchases, and the link to manage or cancel the subscription.
  ///
  /// All of it needs a copy that can use Google Play Billing
  /// (BillingState.playSupported). The plans need Play sales on
  /// (Rails.googlePlay). Restore needs Play sales or Play restores on
  /// (Rails.playRestore). The link shows wherever Restore does, and on a
  /// device whose Premium comes from Play.
  List<Widget> _playRails(BuildContext context, S l10n, BillingState billing) {
    if (!billing.playSupported) return const [];
    final sell = billing.enabled && billing.rails.googlePlay;
    final restore = sell || billing.rails.playRestore;
    final manage = restore || billing.premium.source == 'google_play';
    if (!sell && !manage) return const [];
    final plans = sell ? billing.playPlans : const <Plan>[];
    final subscribed = plans.any(billing.playSubscribedTo);
    final restoring = billing.isRestoring;
    return [
      if (sell) ...[
        PremiumSectionTitle(text: l10n.premiumChoosePlan),
        if (plans.isEmpty)
          billing.playLoading
              ? const Center(child: CircularProgressIndicator())
              : PremiumNote(text: l10n.premiumPlayUnavailable)
        else ...[
          for (final plan in plans) _playPlanCard(context, l10n, billing, plan),
          if (plans.any((p) => billing.playProductFor(p)?.renews ?? false))
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 8),
              child: Text(
                l10n.premiumPlayCancelNote,
                style: AppDesign.textTheme.bodySmall?.copyWith(
                  color: AppDesign.textTertiary,
                ),
              ),
            ),
        ],
      ] else
        const SizedBox(height: 8),
      ?_playFlowLine(l10n, billing.playFlow),
      if (subscribed) ...[
        PremiumNote(text: l10n.premiumPlaySubscribed),
        const SizedBox(height: 4),
      ],
      if (restore || manage) const SizedBox(height: 4),
      if (restore)
        Center(
          // Not disabled while it runs: a disabled button loses a TV
          // remote's focus. A second tap is ignored instead.
          child: TextButton.icon(
            onPressed: () {
              if (billing.isRestoring) return;
              _restore(billing);
            },
            icon: restoring
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.restore_rounded, size: 18),
            label: Text(l10n.premiumRestore),
            style: _quiet,
          ),
        ),
      if (manage)
        Center(
          child: TextButton.icon(
            onPressed: () => _manage(billing),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(l10n.premiumManageSubscription),
            style: _quiet,
          ),
        ),
    ];
  }

  /// One Play plan. A plan this phone already subscribes to is not sold
  /// again: Play holds one base plan of a product per account at a time.
  /// The one it is on reads "Current plan", and the others of that product
  /// have no button.
  Widget _playPlanCard(
    BuildContext context,
    S l10n,
    BillingState billing,
    Plan plan,
  ) {
    final product = billing.playProductFor(plan)!;
    final period = product.renews
        ? PlayPeriod.parse(product.billingPeriod)
        : null;
    final current = billing.isCurrentPlayPlan(plan);
    final Widget? action;
    if (current || billing.playSubscribedTo(plan)) {
      action = null;
    } else {
      final busy = billing.playBusy && _buying?.code == plan.code;
      action = FilledButton(
        // Not disabled while a purchase runs: a disabled button loses a TV
        // remote's focus. BillingState ignores a second purchase anyway.
        onPressed: () {
          if (billing.playBusy) return;
          setState(() => _buying = plan);
          billing.buyOnPlay(plan);
        },
        style: FilledButton.styleFrom(minimumSize: const Size(104, 52)),
        child: busy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppDesign.onBrand,
                ),
              )
            : Text(l10n.premiumBuy),
      );
    }
    return PremiumPlanCard(
      // With Play's period on the card, a length from the backend next to
      // it would read like a pass that ends, so the title names none.
      title: period != null
          ? l10n.premiumPlanNoDays
          : premiumPlanTitle(context, plan),
      prices: [product.price],
      note: premiumRenewalLine(context, product),
      current: current ? l10n.premiumCurrentPlan : null,
      action: action,
    );
  }

  Future<void> _manage(BillingState billing) async {
    final l10n = S.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await openOutside(billing.playManageUrl);
    } catch (e) {
      debugPrint('Premium: could not open Google Play ($e)');
    }
    if (!opened) showPremiumToast(messenger, l10n.premiumPlayUnavailable);
  }

  Widget? _playFlowLine(S l10n, PlayFlow flow) {
    final (text, tone) = switch (flow) {
      PlayFlow.idle || PlayFlow.buying => (null, PremiumNoteTone.neutral),
      PlayFlow.pending => (l10n.premiumPlayPending, PremiumNoteTone.waiting),
      PlayFlow.confirming => (
        l10n.premiumPlayConfirming,
        PremiumNoteTone.waiting,
      ),
      PlayFlow.done => (l10n.premiumNowOn, PremiumNoteTone.success),
      PlayFlow.retrying => (l10n.premiumPlayRetrying, PremiumNoteTone.waiting),
      PlayFlow.refused => (l10n.premiumPlayRefused, PremiumNoteTone.problem),
      PlayFlow.notAvailable => (
        l10n.premiumPlayNotAvailable,
        PremiumNoteTone.problem,
      ),
      PlayFlow.failed => (l10n.premiumPlayFailed, PremiumNoteTone.problem),
    };
    if (text == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: PremiumNote(text: text, tone: tone),
    );
  }

  Future<void> _restore(BillingState billing) async {
    final l10n = S.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await billing.restorePlay();
    final text = switch (outcome) {
      RestoreOutcome.restored => l10n.premiumRestoreDone,
      RestoreOutcome.nothing => l10n.premiumRestoreNone,
      RestoreOutcome.unavailable => l10n.premiumPlayUnavailable,
      RestoreOutcome.notAvailable => l10n.premiumNotAvailable,
      RestoreOutcome.failed => l10n.premiumRestoreFailed,
    };
    showPremiumToast(messenger, text);
  }
}

/// "30 days of unlimited data", with the plan's own length, or text that
/// names no length when the backend sent none.
String premiumPlanTitle(BuildContext context, Plan plan) {
  final l10n = S.of(context)!;
  final days = plan.days;
  if (days == null) return l10n.premiumPlanNoDays;
  return NumberLocalizer.localize(l10n.premiumPlanDays(days), context);
}

/// How often Play bills for [product] and that it renews until the user
/// cancels, such as "Billed every month. Renews automatically until you
/// cancel." The period is Play's own (PlayProduct.billingPeriod), so the
/// app names no number. A line with no period when Play gave none that
/// can be read, and null for a product that does not renew.
String? premiumRenewalLine(BuildContext context, PlayProduct product) {
  if (!product.renews) return null;
  final l10n = S.of(context)!;
  final period = PlayPeriod.parse(product.billingPeriod);
  if (period == null) return l10n.premiumRenewsNoPeriod;
  final count = period.count;
  final text = switch (period.unit) {
    PlayPeriodUnit.day => l10n.premiumRenewsDays(count),
    PlayPeriodUnit.week => l10n.premiumRenewsWeeks(count),
    PlayPeriodUnit.month => l10n.premiumRenewsMonths(count),
    PlayPeriodUnit.year => l10n.premiumRenewsYears(count),
  };
  return NumberLocalizer.localize(text, context);
}

/// A date in the app's language, on the phone's calendar day. Persian
/// shows it on the Jalali calendar (see appDate).
String premiumDate(BuildContext context, DateTime when) =>
    appDate(context, when);

/// A floating message at the bottom of the screen, in the app's style.
/// Its colors come from the theme's snackbar, so the text is light on the
/// bar.
void showPremiumToast(ScaffoldMessengerState messenger, String text) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
}

/// The top of the Premium screen: the shield over a soft glow of the
/// crest's color, the headline, and the line under it.
class _PremiumHero extends StatelessWidget {
  const _PremiumHero({required this.title, this.body});

  static const double _markSize = 56;

  /// The glow is wider than the mark's own box and paints past it, so it
  /// takes no height of its own: the plans stay on the first screen.
  static const double _glowSize = 96;

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final body = this.body;
    final pixels = MediaQuery.devicePixelRatioOf(context);
    return Column(
      children: [
        // Room for the glow above the mark, inside the list.
        const SizedBox(height: AppDesign.space12),
        SizedBox(
          height: _markSize,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              OverflowBox(
                maxWidth: _glowSize,
                maxHeight: _glowSize,
                child: SizedBox.square(
                  dimension: _glowSize,
                  // A static gradient, not a blur: the glow costs one
                  // paint. It fades to the crest's color at no alpha
                  // rather than to transparent black, which would grey the
                  // edge.
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.5,
                        colors: [
                          AppDesign.brand.withValues(alpha: 0.10),
                          AppDesign.brand.withValues(alpha: 0.10),
                          AppDesign.brand.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.55, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Image.asset(
                'assets/icon/fortiva_mark.png',
                width: _markSize,
                height: _markSize,
                cacheWidth: (_markSize * pixels).round(),
                // The app bar already says where this is.
                excludeFromSemantics: true,
                errorBuilder: (context, error, stack) =>
                    const SizedBox.square(dimension: _markSize),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppDesign.textTheme.headlineSmall,
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: AppDesign.space8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppDesign.textTheme.bodyMedium?.copyWith(
              color: AppDesign.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Whether this device has Premium, until when, and how it was paid; or,
/// after Premium ended, when it did.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.premium, this.endedAt});

  final Premium premium;

  /// When Premium ended, for a device without it now.
  final DateTime? endedAt;

  /// How it was paid. Premium paid outside Google Play reaches the app
  /// only as a key someone typed in, and no copy names a way to pay outside
  /// Play, so all of it says a key.
  String? _source(S l10n) => switch (premium.source) {
    'voucher' || 'crypto' || 'stars' => l10n.premiumSourceKey,
    'google_play' => l10n.premiumSourceGooglePlay,
    'manual' => l10n.premiumSourceManual,
    'referral' => l10n.premiumSourceInvite,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final active = premium.active;
    final until = premium.until;
    final ended = endedAt;
    final String? title;
    final List<String> lines;
    if (active) {
      title = l10n.premiumActiveTitle;
      lines = [
        until == null
            ? l10n.premiumActiveNoDate
            : l10n.premiumActiveUntil(premiumDate(context, until)),
        ?_source(l10n),
        if (premium.autoRenewing == true) l10n.premiumRenews,
      ];
    } else {
      title = null;
      lines = [
        if (ended != null) l10n.premiumEndedOn(premiumDate(context, ended)),
      ];
    }
    // Premium on is the protected tone, as the pill on home is. After the
    // end it is the plain card: a fact, not an alarm.
    return Container(
      padding: const EdgeInsets.all(AppDesign.space16),
      decoration: BoxDecoration(
        color: active ? AppDesign.protectedContainer : AppDesign.surfaceLow,
        borderRadius: AppDesign.borderRadiusLarge,
        border: active ? null : Border.all(color: AppDesign.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            active ? Icons.all_inclusive_rounded : Icons.event_busy_outlined,
            color: active ? AppDesign.protected : AppDesign.textTertiary,
            size: active ? 28 : 22,
          ),
          const SizedBox(width: AppDesign.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Semantics(
                    header: true,
                    child: Text(title, style: AppDesign.textTheme.titleLarge),
                  ),
                  const SizedBox(height: AppDesign.space4),
                ],
                for (final (i, line) in lines.indexed) ...[
                  if (i > 0) const SizedBox(height: AppDesign.space2),
                  Text(
                    line,
                    style: i == 0
                        ? AppDesign.textTheme.bodyMedium?.copyWith(
                            color: active
                                ? AppDesign.textPrimary
                                : AppDesign.textSecondary,
                          )
                        : AppDesign.textTheme.bodySmall?.copyWith(
                            color: AppDesign.textSecondary,
                          ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The access key with a Copy button, and what it is for.
///
/// The key is shown exactly as the backend sends it, left to right in
/// every language and with Latin digits, because it is typed into another
/// phone.
class PremiumKeyCard extends StatelessWidget {
  const PremiumKeyCard({
    super.key,
    required this.code,
    this.moveLimit,
    this.moveWindowDays,
  });

  final String code;
  final int? moveLimit;
  final int? moveWindowDays;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final moves = moveLimit;
    final days = moveWindowDays;
    return Container(
      padding: const EdgeInsets.all(AppDesign.space16),
      decoration: BoxDecoration(
        color: AppDesign.surfaceLow,
        borderRadius: AppDesign.borderRadiusLarge,
        border: Border.all(color: AppDesign.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumSectionTitle(
            text: l10n.premiumYourKey,
            start: 0,
            bottom: AppDesign.space12,
          ),
          PremiumCopyRow(value: code, large: true),
          const SizedBox(height: AppDesign.space12),
          Text(
            l10n.premiumKeyHint,
            style: AppDesign.textTheme.bodySmall?.copyWith(
              color: AppDesign.textSecondary,
            ),
          ),
          const SizedBox(height: AppDesign.space4),
          Text(
            moves == null || days == null
                ? l10n.premiumKeyMovesNoNumber
                : NumberLocalizer.localize(
                    l10n.premiumKeyMoves(moves, days),
                    context,
                  ),
            style: AppDesign.textTheme.bodySmall?.copyWith(
              color: AppDesign.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A value to type elsewhere, such as a key, on a recessed strip with a
/// Copy button. Always left to right, never with localized digits.
class PremiumCopyRow extends StatelessWidget {
  const PremiumCopyRow({
    super.key,
    required this.value,
    this.copyText,
    this.large = false,
  });

  final String value;

  /// What Copy puts on the clipboard, when it is not [value] itself.
  final String? copyText;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppDesign.canvasDeep,
        borderRadius: AppDesign.borderRadiusMedium,
      ),
      child: Row(
        children: [
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                value,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: large ? 17 : 14,
                  letterSpacing: AppDesign.ls(large ? 1.5 : 0.3),
                  color: AppDesign.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: copyText ?? value));
              showPremiumToast(messenger, l10n.premiumCopied);
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: Text(l10n.premiumCopy),
          ),
        ],
      ),
    );
  }
}

/// A small heading over a group on the Premium screens.
class PremiumSectionTitle extends StatelessWidget {
  const PremiumSectionTitle({
    super.key,
    required this.text,
    this.start = AppDesign.space4,
    this.bottom = AppDesign.space12,
  });

  final String text;

  /// The inset at the start: a little on the canvas, so the title lines up
  /// with the text inside the cards under it, and none inside a card.
  final double start;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(start: start, bottom: bottom),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: AppDesign.textTheme.titleSmall?.copyWith(
            color: AppDesign.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// One plan: its length, Play's price as the largest line, how often it
/// bills, and the button that buys it.
///
/// The button sits beside the price where the widest price fits there on
/// one line, so two plans, the cancel note and Restore fit on a phone's
/// first screen. Where it does not, on a narrow phone or with a large font,
/// the button goes under the price at the card's full width, so the price
/// is never broken across two lines.
class PremiumPlanCard extends StatelessWidget {
  const PremiumPlanCard({
    super.key,
    required this.title,
    required this.prices,
    this.note,
    this.current,
    this.action,
  });

  final String title;

  /// Each price as the store or the backend wrote it.
  final List<String> prices;

  /// A line under the prices, such as how often Google Play bills.
  final String? note;

  /// "Current plan" when this phone is on the plan, which then has a
  /// protected edge and a check in place of a button.
  final String? current;

  /// The button that buys the plan.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final current = this.current;
    final note = this.note;
    final trailing = current != null
        ? PremiumBadge(text: current, icon: Icons.check_rounded)
        : action;
    return Container(
      margin: const EdgeInsets.only(bottom: AppDesign.space12),
      padding: const EdgeInsets.all(AppDesign.space16),
      decoration: BoxDecoration(
        color: AppDesign.surfaceLow,
        borderRadius: AppDesign.borderRadiusLarge,
        border: current != null
            ? Border.all(color: AppDesign.protected, width: 1.5)
            : Border.all(color: AppDesign.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlanHead(
            gap: AppDesign.space12,
            // Buy takes the full width under the price; the Current plan
            // badge keeps its own size.
            stretch: current == null,
            title: Text(title, style: AppDesign.textTheme.titleMedium),
            prices: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final price in prices)
                  Padding(
                    padding: const EdgeInsets.only(top: AppDesign.space2),
                    // Play's price as Play wrote it, read left to right as
                    // Play formats it, at the start of the card in either
                    // direction. Always one line: a price wider than the
                    // whole card is drawn smaller rather than broken.
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          price,
                          maxLines: 1,
                          softWrap: false,
                          style: AppDesign.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: AppDesign.numberFeatures,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            trailing: trailing,
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: AppDesign.space8),
              child: Text(
                note,
                style: AppDesign.textTheme.bodySmall?.copyWith(
                  color: AppDesign.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The top of a plan card: the title with the prices under it, and the
/// button (or badge) at the end, centred on them both.
///
/// The button stays beside them only while the widest price fits next to
/// it on one line, and the title's longest word does too. Otherwise it
/// goes under the prices, at the full width when [stretch] is set. A Row cannot do this: it would wrap the price to
/// make room for the button.
class _PlanHead extends MultiChildRenderObjectWidget {
  _PlanHead({
    required Widget title,
    required Widget prices,
    required Widget? trailing,
    required this.gap,
    required this.stretch,
  }) : super(children: [title, prices, ?trailing]);

  final double gap;
  final bool stretch;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPlanHead(
    gap: gap,
    stretch: stretch,
    textDirection: Directionality.of(context),
  );

  @override
  void updateRenderObject(BuildContext context, _RenderPlanHead renderObject) {
    renderObject
      ..gap = gap
      ..stretch = stretch
      ..textDirection = Directionality.of(context);
  }
}

class _PlanHeadSlot extends ContainerBoxParentData<RenderBox> {}

class _RenderPlanHead extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PlanHeadSlot>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PlanHeadSlot> {
  _RenderPlanHead({
    required double gap,
    required bool stretch,
    required TextDirection textDirection,
  }) : _gap = gap,
       _stretch = stretch,
       _textDirection = textDirection;

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  bool _stretch;
  set stretch(bool value) {
    if (value == _stretch) return;
    _stretch = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PlanHeadSlot) {
      child.parentData = _PlanHeadSlot();
    }
  }

  RenderBox get _title => firstChild!;
  RenderBox get _prices => childAfter(_title)!;
  RenderBox? get _trailing => childAfter(_prices);

  /// Lays the children out with [layoutChild] for [constraints], places
  /// them when [place] is set, and returns the size.
  Size _layout(
    BoxConstraints constraints,
    ChildLayouter layoutChild, {
    required bool place,
  }) {
    final title = _title;
    final prices = _prices;
    final trailing = _trailing;
    final pricesWidth = prices.getMaxIntrinsicWidth(double.infinity);
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : math.max(title.getMaxIntrinsicWidth(double.infinity), pricesWidth) +
              (trailing == null
                  ? 0
                  : _gap + trailing.getMaxIntrinsicWidth(double.infinity));
    final rtl = _textDirection == TextDirection.rtl;
    void put(RenderBox child, Size size, double top, {bool end = false}) {
      if (!place) return;
      final atRight = rtl != end;
      (child.parentData! as _PlanHeadSlot).offset = Offset(
        atRight ? width - size.width : 0,
        top,
      );
    }

    final trailingSize = trailing == null
        ? Size.zero
        : layoutChild(trailing, BoxConstraints(maxWidth: width));
    // Beside the button the widest price must fit on one line, and the
    // title's longest word too, so neither is broken mid-word.
    final needed = math.max(
      pricesWidth,
      title.getMinIntrinsicWidth(double.infinity),
    );
    final beside =
        trailing == null || needed + _gap + trailingSize.width <= width;
    if (beside) {
      final room = BoxConstraints(
        maxWidth: trailing == null ? width : width - _gap - trailingSize.width,
      );
      final titleSize = layoutChild(title, room);
      final pricesSize = layoutChild(prices, room);
      final lead = titleSize.height + pricesSize.height;
      final height = math.max(lead, trailingSize.height);
      final top = (height - lead) / 2;
      put(title, titleSize, top);
      put(prices, pricesSize, top + titleSize.height);
      if (trailing != null) {
        put(
          trailing,
          trailingSize,
          (height - trailingSize.height) / 2,
          end: true,
        );
      }
      return constraints.constrain(Size(width, height));
    }
    final full = BoxConstraints(maxWidth: width);
    final titleSize = layoutChild(title, full);
    final pricesSize = layoutChild(prices, full);
    final under = _stretch
        ? layoutChild(trailing, BoxConstraints.tightFor(width: width))
        : trailingSize;
    put(title, titleSize, 0);
    put(prices, pricesSize, titleSize.height);
    final below = titleSize.height + pricesSize.height + _gap;
    put(trailing, under, below);
    return constraints.constrain(Size(width, below + under.height));
  }

  @override
  void performLayout() {
    size = _layout(constraints, ChildLayoutHelper.layoutChild, place: true);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _layout(constraints, ChildLayoutHelper.dryLayoutChild, place: false);

  @override
  double computeMinIntrinsicWidth(double height) {
    var widest = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      widest = math.max(widest, child.getMinIntrinsicWidth(height));
    }
    return widest;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final trailing = _trailing;
    return math.max(
          _title.getMaxIntrinsicWidth(height),
          _prices.getMaxIntrinsicWidth(height),
        ) +
        (trailing == null ? 0 : _gap + trailing.getMaxIntrinsicWidth(height));
  }

  @override
  double computeMinIntrinsicHeight(double width) => _layout(
    BoxConstraints(maxWidth: width),
    ChildLayoutHelper.dryLayoutChild,
    place: false,
  ).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}

/// A short label in place of a button, such as "Current plan".
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 10, 4),
      decoration: const BoxDecoration(
        color: AppDesign.protectedContainer,
        borderRadius: BorderRadius.all(Radius.circular(AppDesign.radiusFull)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppDesign.protected),
            const SizedBox(width: AppDesign.space4),
          ],
          Flexible(
            child: Text(
              text,
              style: AppDesign.textTheme.labelMedium?.copyWith(
                color: AppDesign.protected,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What a [PremiumNote] says about the state it describes.
enum PremiumNoteTone {
  /// A fact to know, such as what this copy cannot do.
  neutral,

  /// Something under way, such as a payment Play is still confirming.
  waiting,

  /// Done, such as Premium turning on.
  success,

  /// Something went wrong.
  problem,
}

/// A line of explanation on a tinted strip, with an icon for its tone so
/// it never relies on color alone.
class PremiumNote extends StatelessWidget {
  const PremiumNote({
    super.key,
    required this.text,
    this.tone = PremiumNoteTone.neutral,
  });

  final String text;
  final PremiumNoteTone tone;

  @override
  Widget build(BuildContext context) {
    final (fill, icon, iconColor) = switch (tone) {
      PremiumNoteTone.neutral => (
        AppDesign.surfaceLow,
        Icons.info_outline_rounded,
        AppDesign.textTertiary,
      ),
      PremiumNoteTone.waiting => (
        AppDesign.surfaceLow,
        Icons.schedule_rounded,
        AppDesign.steelLight,
      ),
      PremiumNoteTone.success => (
        AppDesign.protectedContainer,
        Icons.check_circle_rounded,
        AppDesign.protected,
      ),
      PremiumNoteTone.problem => (
        AppDesign.errorContainer,
        Icons.error_outline_rounded,
        AppDesign.error,
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 16, 12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: AppDesign.borderRadiusMedium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: AppDesign.space12),
          Expanded(
            child: Text(
              text,
              style: AppDesign.textTheme.bodyMedium?.copyWith(
                color: tone == PremiumNoteTone.problem
                    ? AppDesign.onErrorContainer
                    : AppDesign.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
