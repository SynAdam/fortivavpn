import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/design_system.dart';
import '../core/form_factor.dart';
import '../core/state/billing_state.dart';
import '../data/models/billing.dart';
import '../data/models/server.dart';
import '../l10n/generated/app_localizations.dart';
import '../screens/premium_screen.dart';
import 'server_card.dart' show FlagDisc, ServerRow;
import 'ui/pressable.dart';
import 'ui/sheet_handle.dart';

/// The places that offer Premium, outside the Premium screen itself.
///
/// Each one shows only when BillingState.upsellOn says its surface is on,
/// and draws nothing without a BillingState above it, so a screen built
/// without payments looks as it did before. The crest's color means an
/// offer, and protected green means Premium is on. None of them names a
/// number of its own.

/// Notes once per run that [surface] was on screen, then draws [child].
class UpsellShown extends StatefulWidget {
  const UpsellShown({super.key, required this.surface, required this.child});

  final UpsellSurface surface;
  final Widget child;

  @override
  State<UpsellShown> createState() => _UpsellShownState();
}

class _UpsellShownState extends State<UpsellShown> {
  @override
  void initState() {
    super.initState();
    context.read<BillingState?>()?.logUpsell(
      widget.surface,
      UpsellAction.shown,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The small pill in the home top bar: a "Premium" offer outlined in the
/// crest's color, or a protected "Premium" that says it is on. Nothing on a
/// TV, and no offer while [calm] is false (a connect under way, an error on
/// screen).
///
/// The Premium-on pill is status, not an offer, so it follows Premium
/// itself (Premium.active) and nothing else: the backend sends no upsell
/// block to a Premium device, so the block cannot be what turns it on. It
/// names no price and opens the Premium screen.
class PremiumTopChip extends StatelessWidget {
  const PremiumTopChip({super.key, required this.calm});

  final bool calm;

  @override
  Widget build(BuildContext context) {
    final billing = context.watch<BillingState?>();
    if (billing == null || FormFactor.isTv) return const SizedBox.shrink();
    final l10n = S.of(context)!;
    if (billing.premium.active) {
      return _Pill(
        label: l10n.premiumTitle,
        icon: Icons.all_inclusive_rounded,
        accent: AppDesign.accentTeal,
        fill: AppDesign.protectedContainer,
        onTap: () => PremiumScreen.open(context),
      );
    }
    if (!calm || !billing.upsellOn(UpsellSurface.topChip)) {
      return const SizedBox.shrink();
    }
    return UpsellShown(
      surface: UpsellSurface.topChip,
      child: _Pill(
        label: l10n.premiumTitle,
        icon: Icons.workspace_premium_outlined,
        accent: AppDesign.brandBright,
        outlined: true,
        onTap: () {
          billing.logUpsell(UpsellSurface.topChip, UpsellAction.tapped);
          PremiumScreen.open(context, source: PremiumSource.topChip);
        },
      ),
    );
  }
}

/// The pill itself: [height] tall to the eye, with the 48dp tap target a
/// Material button pads around it. The padding is no taller than the top
/// bar's own buttons, so the bar keeps its height.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.fill = Colors.transparent,
    this.outlined = false,
  });

  static const double height = 30;

  final String label;
  final IconData icon;
  final Color accent;
  final Color fill;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: accent,
        backgroundColor: fill,
        minimumSize: const Size(0, height),
        padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 12, 0),
        tapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
        shape: const StadiumBorder(),
        side: outlined ? BorderSide(color: accent) : BorderSide.none,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: AppDesign.space6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppDesign.textTheme.labelMedium?.copyWith(color: accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// An offer card in the app's shared card look: the Premium mark in the
/// crest's color, a title, a line, and "Get unlimited", with "Not now"
/// when [onNotNow] is set.
class PremiumOfferCard extends StatelessWidget {
  const PremiumOfferCard({
    super.key,
    required this.title,
    required this.body,
    required this.onGetUnlimited,
    this.onNotNow,
    this.margin = EdgeInsets.zero,
  });

  final String title;
  final String body;
  final VoidCallback onGetUnlimited;
  final VoidCallback? onNotNow;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final notNow = onNotNow;
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(AppDesign.space16),
      decoration: BoxDecoration(
        color: AppDesign.surfaceLow,
        borderRadius: AppDesign.borderRadiusLarge,
        border: Border.all(color: AppDesign.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                color: AppDesign.brandBright,
                size: 20,
              ),
              const SizedBox(width: AppDesign.space12),
              Expanded(
                child: Text(
                  title,
                  style: AppDesign.textTheme.titleSmall?.copyWith(
                    color: AppDesign.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.space8),
          Text(body, style: AppDesign.textTheme.bodyMedium),
          const SizedBox(height: AppDesign.space12),
          // The full width, so the buttons sit at the card's end: a Wrap
          // alone is only as wide as its buttons.
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: AppDesign.space8,
              runSpacing: AppDesign.space4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (notNow != null)
                  TextButton(
                    onPressed: notNow,
                    style: TextButton.styleFrom(
                      foregroundColor: AppDesign.textSecondary,
                    ),
                    child: Text(l10n.premiumNotNow),
                  ),
                FilledButton.icon(
                  onPressed: onGetUnlimited,
                  icon: const Icon(Icons.all_inclusive_rounded, size: 18),
                  label: Text(l10n.premiumGetUnlimited),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, AppDesign.space48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDesign.space20,
                    ),
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

/// The reminder before Premium that does not renew by itself ends, and the
/// note once after it ended, on the home screen.
///
/// The reminder shows while the end is within the backend's notice hours
/// (Renewal.reminderDue). The note after the end shows once per end: the
/// end is kept on the phone ([lapseSeenKey]) as soon as the note shows,
/// and it is closed for good with its close button. Both say the date and
/// nothing else: no copy has a Renew button, because a Google Play
/// subscription is renewed or turned back on in Google Play, and a key is
/// bought outside the app. Nothing on a TV, and nothing while [calm] is
/// false.
class RenewalCard extends StatefulWidget {
  const RenewalCard({super.key, required this.calm, this.now});

  final bool calm;

  /// The clock, for tests.
  final DateTime Function()? now;

  /// The end of Premium the note after the end was last shown for, as ISO
  /// text. Cleared when the account is deleted.
  static const lapseSeenKey = _RenewalCardState._seenKey;

  @override
  State<RenewalCard> createState() => _RenewalCardState();
}

class _RenewalCardState extends State<RenewalCard> {
  static const _seenKey = 'renewal_lapse_seen';

  /// What [RenewalCard.lapseSeenKey] held when this screen first looked,
  /// and whether it has been read.
  String? _seenBefore;
  bool _seenRead = false;
  bool _closed = false;
  String? _marked;

  @override
  void initState() {
    super.initState();
    unawaited(_readSeen());
  }

  Future<void> _readSeen() async {
    String? seen;
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = prefs.getString(_seenKey);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _seenBefore = seen;
      _seenRead = true;
    });
  }

  Future<void> _markSeen(String endedAt) async {
    if (_marked == endedAt) return;
    _marked = endedAt;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_seenKey, endedAt);
    } catch (e) {
      debugPrint('RenewalCard: could not note the end ($e)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final billing = context.watch<BillingState?>();
    if (billing == null || FormFactor.isTv || !widget.calm) {
      return const SizedBox.shrink();
    }
    final renewal = billing.renewal;
    if (renewal == null) return const SizedBox.shrink();
    final l10n = S.of(context)!;
    final now = (widget.now ?? DateTime.now)();
    final premium = billing.premium;
    final until = renewal.until;
    if (until != null && renewal.reminderDue(premium, now)) {
      return _shell(
        accent: AppDesign.accentTeal,
        icon: Icons.event_outlined,
        title: l10n.premiumEndsOn(premiumDate(context, until)),
      );
    }
    final endedAt = renewal.endedAt;
    if (premium.active || endedAt == null || !_seenRead || _closed) {
      return const SizedBox.shrink();
    }
    final key = endedAt.toUtc().toIso8601String();
    if (_seenBefore == key) return const SizedBox.shrink();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markSeen(key));
    return _shell(
      accent: AppDesign.textTertiary,
      icon: Icons.event_busy_outlined,
      title: l10n.premiumEndedOn(premiumDate(context, endedAt)),
      onClose: () => setState(() => _closed = true),
    );
  }

  /// The shared card look, kept as short as the line in it: this sits in
  /// the home footer, whose height the power button needs.
  Widget _shell({
    required Color accent,
    required IconData icon,
    required String title,
    VoidCallback? onClose,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsetsDirectional.only(
        start: AppDesign.space16,
        end: AppDesign.space4,
      ),
      decoration: BoxDecoration(
        color: AppDesign.surfaceLow,
        borderRadius: AppDesign.borderRadiusLarge,
        border: Border.all(color: AppDesign.hairline),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: AppDesign.space12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDesign.space12),
              child: Text(
                title,
                style: AppDesign.textTheme.bodyMedium?.copyWith(
                  color: AppDesign.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(
                Icons.close,
                color: AppDesign.textTertiary,
                size: 20,
              ),
            )
          else
            const SizedBox(width: AppDesign.space12),
        ],
      ),
    );
  }
}

/// A Premium location this device may not use yet, on My servers: flag,
/// city, the Premium tag and a lock. It sits between the rows of Your
/// servers, so it has their look (ServerRow): the same fill, corners,
/// padding, height and flag disc. Its city is a step dimmer, in the text
/// color rather than an Opacity layer. It carries no address. A tap opens
/// [showLockedServerSheet].
class LockedServerTile extends StatelessWidget {
  const LockedServerTile({super.key, required this.server});

  final LockedServer server;

  /// Above and below the row's content, as on ServerRow.
  static const double _rowPadding = 12;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return Pressable(
      onTap: () => showLockedServerSheet(context, server),
      color: AppDesign.surfaceLow,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDesign.space12,
        _rowPadding,
        AppDesign.space16,
        _rowPadding,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: ServerRow.minHeight - 2 * _rowPadding,
        ),
        child: Row(
          children: [
            FlagDisc(flag: Server.flagFor(server.countryCode)),
            const SizedBox(width: AppDesign.space12),
            Expanded(
              child: Text(
                server.city,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppDesign.textTheme.titleMedium?.copyWith(
                  color: AppDesign.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppDesign.space8),
            // Tinted, with light text on it: white on the old amber tag
            // read at about 2:1.
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDesign.space8,
                vertical: AppDesign.space2,
              ),
              decoration: const BoxDecoration(
                color: AppDesign.brandContainer,
                borderRadius: BorderRadius.all(
                  Radius.circular(AppDesign.radiusFull),
                ),
              ),
              child: Text(
                l10n.premiumLockedTag,
                style: AppDesign.textTheme.labelSmall?.copyWith(
                  color: AppDesign.onBrandContainer,
                ),
              ),
            ),
            const SizedBox(width: AppDesign.space12),
            const Icon(
              Icons.lock_outline_rounded,
              color: AppDesign.textTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// The sheet a locked location opens, such as "Unlock Helsinki with
/// Premium": what the location is, and the way to it.
Future<void> showLockedServerSheet(
  BuildContext context,
  LockedServer server,
) async {
  final billing = context.read<BillingState?>();
  final buy = await showModalBottomSheet<bool>(
    context: context,
    builder: (sheetContext) {
      final l10n = S.of(sheetContext)!;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
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
              Center(
                child: FlagDisc(
                  flag: Server.flagFor(server.countryCode),
                  size: 56,
                ),
              ),
              const SizedBox(height: AppDesign.space16),
              Text(
                l10n.premiumLockedTitle(server.city),
                textAlign: TextAlign.center,
                style: AppDesign.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppDesign.space8),
              Text(
                l10n.premiumLockedBody,
                textAlign: TextAlign.center,
                style: AppDesign.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppDesign.space24),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, true),
                icon: const Icon(Icons.all_inclusive_rounded, size: 18),
                label: Text(l10n.premiumGetUnlimited),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: AppDesign.space4),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                style: TextButton.styleFrom(
                  foregroundColor: AppDesign.textSecondary,
                ),
                child: Text(l10n.premiumNotNow),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (buy != true) {
    billing?.logUpsell(UpsellSurface.lockedServers, UpsellAction.dismissed);
    return;
  }
  billing?.logUpsell(UpsellSurface.lockedServers, UpsellAction.tapped);
  if (!context.mounted) return;
  await PremiumScreen.open(
    context,
    source: PremiumSource.lockedServer,
    place: server.city,
  );
}
