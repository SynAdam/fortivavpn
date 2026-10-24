import 'package:flutter/material.dart';

import '../api/config_service.dart';
import '../core/design_system.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/number_localizer.dart';

/// Shows the device's rolling 24h allowance.
///
/// Deliberately explicit about *when* the window resets rather than only
/// how much is left: "you have 40 MB" is alarming on its own, "40 MB, and
/// it resets at 18:20" is a wait rather than a dead end.
///
/// The bar and the text show what is left, like a fuel gauge. The bar used
/// to show what was used. On 2026-10-05 a user with 362 MB of 10 GB used saw
/// a nearly empty bar next to "refills in 13 hours", took it as a spent
/// allowance, and reported that the app stops working until it refills.
///
/// The time line says the allowance "resets", in every language, never that
/// it fills up. On 2026-10-09 a user whose connect failed saw a full 21 GB
/// bar next to «تا ۲۲ ساعت دیگر پر می‌شود» ("fills up in 22 hours") and
/// took it to mean they had to wait 22 hours to use the app.
/// test/quota_reset_wording_test.dart keeps the old words out.
class QuotaCard extends StatelessWidget {
  final QuotaStatus quota;

  /// Opens the Premium screen. Null hides the "Get unlimited" action,
  /// which is the case unless this copy can buy something here, this
  /// device is not Premium, and the backend sent an upsell block
  /// (BillingState.offersAllowed).
  final VoidCallback? onGetUnlimited;

  const QuotaCard({super.key, required this.quota, this.onGetUnlimited});

  static String formatBytes(int bytes) {
    if (bytes >= 1 << 30) return '${(bytes / (1 << 30)).toStringAsFixed(1)} GB';
    if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).toStringAsFixed(0)} MB';
    if (bytes >= 1 << 10) return '${(bytes / (1 << 10)).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  /// [bytes] as [formatBytes] writes it, in the language's own digits and
  /// with the decimal sign those digits take. Persian, Arabic and Urdu write
  /// it as «٫» (U+066B): an ASCII period between Persian zeros, which are
  /// drawn as small rings, read as one more dot in "۲۰.۰ GB".
  ///
  /// NumberLocalizer.localizeAmount holds that rule, so this card, the home
  /// "used today" line and the other amounts write the sign the same way.
  static String localizedBytes(int bytes, BuildContext context) =>
      NumberLocalizer.localizeAmount(formatBytes(bytes), context);

  /// An allowance as people say it: "20 GB", not "20.0 GB".
  static String formatAllowance(int bytes) {
    if (bytes >= 1 << 30 && bytes % (1 << 30) == 0) return '${bytes >> 30} GB';
    return formatBytes(bytes);
  }

  /// When the window resets, as a short phrase; empty when the backend
  /// did not say. Static so the home screen can say the same thing in the
  /// same words when it has to explain why the button does nothing.
  ///
  /// The number is written in the language's own digits (NumberLocalizer),
  /// so Persian reads "۲۳", not "23". Every place that shows the reset
  /// (this card, the spent server card on home, the limit sheet and the
  /// update dialog) goes through here.
  static String resetLabel(S l10n, QuotaStatus quota) {
    final resets = quota.resetsAt;
    if (resets == null) return '';
    final remaining = resets.toLocal().difference(DateTime.now());
    if (remaining.isNegative) return l10n.quotaResetsShortly;
    final String text;
    if (remaining.inHours >= 1) {
      text = l10n.quotaResetsInHours(remaining.inHours);
    } else {
      final minutes = remaining.inMinutes < 1 ? 1 : remaining.inMinutes;
      text = l10n.quotaResetsInMinutes(minutes);
    }
    final language = l10n.localeName.split(RegExp('[_-]')).first;
    return NumberLocalizer.localizeForLocale(text, language);
  }

  /// Below this share of the allowance left, the bar turns to the warning
  /// color, like a fuel gauge's last quarter. A look of the bar, not a
  /// rule of the service.
  static const double _lowShareLeft = 0.25;

  /// The bar's color for [left], the share of the allowance left: protected
  /// while there is plenty, the warning color in the last quarter, the
  /// error color when nothing is left.
  static Color barColor(double left, {required bool blocked}) {
    if (blocked || left <= 0) return AppDesign.error;
    if (left <= _lowShareLeft) return AppDesign.warning;
    return AppDesign.protected;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final text = AppDesign.textTheme;
    if (quota.unlimited) {
      return _shell(
        child: Row(
          children: [
            const Icon(
              Icons.all_inclusive_rounded,
              color: AppDesign.protected,
              size: 20,
            ),
            const SizedBox(width: AppDesign.space12),
            Expanded(
              child: Text(
                l10n.quotaUnlimited,
                style: text.titleSmall?.copyWith(color: AppDesign.textPrimary),
              ),
            ),
          ],
        ),
      );
    }

    final blocked = quota.blocked;
    final left = (1 - quota.usedFraction).clamp(0.0, 1.0);
    final color = barColor(left, blocked: blocked);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // In the language's own digits, and each amount isolated with its unit,
    // so a right to left line keeps "5.0 GB" in one piece.
    String amount(int bytes) {
      final shown = localizedBytes(bytes, context);
      return rtl ? '\u2068$shown\u2069' : shown;
    }

    final onGetUnlimited = this.onGetUnlimited;
    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The label is the quiet line and the amount left is the loud
          // one, because the amount is what the card is for. A spent
          // allowance says so in the error color, beside the empty bar.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  blocked ? l10n.quotaLimitReached : l10n.quotaDaily,
                  style: text.labelMedium?.copyWith(
                    color: blocked ? AppDesign.error : AppDesign.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppDesign.space8),
              Text(
                resetLabel(l10n, quota),
                style: text.bodySmall?.copyWith(
                  color: AppDesign.textTertiary,
                  fontFeatures: AppDesign.numberFeatures,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.space12),
          LinearProgressIndicator(
            value: left,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            backgroundColor: AppDesign.surfaceHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          const SizedBox(height: AppDesign.space8),
          Text(
            l10n.quotaLeftOf(
              amount(
                (quota.limitBytes - quota.usedBytes).clamp(0, quota.limitBytes),
              ),
              amount(quota.limitBytes),
            ),
            style: text.titleMedium?.copyWith(
              color: AppDesign.textPrimary,
              fontFeatures: AppDesign.numberFeatures,
            ),
          ),
          // Broken out rather than folded into the total, so a user who
          // invited someone can see the invite is what raised the number.
          if (quota.hasReferralBonus) ...[
            const SizedBox(height: AppDesign.space4),
            Text(
              l10n.quotaBonusIncluded(amount(quota.bonusBytes)),
              style: text.bodySmall?.copyWith(color: AppDesign.protected),
            ),
          ],
          if (onGetUnlimited != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: onGetUnlimited,
                icon: const Icon(Icons.all_inclusive_rounded, size: 18),
                label: Text(l10n.premiumGetUnlimited),
                style: TextButton.styleFrom(
                  foregroundColor: AppDesign.brandBright,
                  minimumSize: const Size(48, 48),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The shared card look: the low surface and the large radius, as the
  /// notices on Your servers. No hairline: the card is a step lighter than
  /// the canvas it sits on, and an edge is only for equal surfaces (spec
  /// 2.3).
  Widget _shell({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(AppDesign.space16),
      decoration: BoxDecoration(
        color: AppDesign.surfaceLow,
        borderRadius: AppDesign.borderRadiusLarge,
      ),
      child: child,
    );
  }
}
