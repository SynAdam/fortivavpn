import 'dart:async';

import 'package:flutter/material.dart';

import '../core/design_system.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/number_localizer.dart';
import 'ui/sheet_handle.dart';

/// The home screen's card that offers the steps to give this SIM IPv6.
/// When it shows is ApnGuide's decision. It has the shared card look, with
/// the icon and the button in the protected green, the app's colour for a
/// working connection, so it does not read as an offer, which is ember.
class ApnGuideCard extends StatelessWidget {
  const ApnGuideCard({
    super.key,
    required this.onShowMe,
    required this.onNotNow,
    this.margin = EdgeInsets.zero,
  });

  final VoidCallback onShowMe;
  final VoidCallback onNotNow;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
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
                Icons.sim_card_outlined,
                color: AppDesign.protected,
                size: 20,
              ),
              const SizedBox(width: AppDesign.space12),
              Expanded(
                child: Text(
                  l10n.apnGuideTitle,
                  style: AppDesign.textTheme.titleSmall?.copyWith(
                    color: AppDesign.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.space6),
          Text(l10n.apnGuideBody, style: AppDesign.textTheme.bodyMedium),
          const SizedBox(height: AppDesign.space12),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: AppDesign.space8,
              runSpacing: AppDesign.space4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: onNotNow,
                  style: TextButton.styleFrom(
                    foregroundColor: AppDesign.textSecondary,
                  ),
                  child: Text(l10n.apnGuideNotNow),
                ),
                FilledButton(
                  onPressed: onShowMe,
                  style: _protectedTonal,
                  child: Text(l10n.apnGuideShowMe),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The guide's buttons: a dark green fill with light green text. The app
/// theme gives a FilledButton the brand fill, which is the offer look.
final ButtonStyle _protectedTonal = FilledButton.styleFrom(
  backgroundColor: AppDesign.protectedContainer,
  foregroundColor: AppDesign.protectedBright,
  iconColor: AppDesign.protectedBright,
);

/// The steps to set the APN protocol to "IPv4/IPv6", and the button that
/// opens the phone's APN screen.
///
/// [apn] is the access point the SIM uses, "mcinet" on Hamrah Aval and
/// "mtnirancell" on Irancell; null leaves it unnamed. The sheet stays open
/// while the APN screen is up, so the steps are still there when the user
/// comes back to look.
Future<void> showApnGuideSheet(
  BuildContext context, {
  required String? apn,
  required Future<bool> Function() openSettings,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ApnGuideSheet(apn: apn, openSettings: openSettings),
  );
}

class _ApnGuideSheet extends StatelessWidget {
  const _ApnGuideSheet({required this.apn, required this.openSettings});

  final String? apn;
  final Future<bool> Function() openSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final apn = this.apn;
    final steps = [
      l10n.apnGuideStepOpen(l10n.apnGuideOpenSettings),
      apn == null
          ? l10n.apnGuideStepAccessPointAny
          : l10n.apnGuideStepAccessPoint(apn),
      l10n.apnGuideStepProtocol,
      l10n.apnGuideStepSave,
      l10n.apnGuideStepRestart,
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: AppDesign.space8),
            Semantics(
              header: true,
              child: Text(
                l10n.apnGuideSheetTitle,
                style: AppDesign.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppDesign.space16),
            for (final (i, step) in steps.indexed)
              _Step(number: i + 1, text: step),
            const SizedBox(height: AppDesign.space4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: AppDesign.space2),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: AppDesign.textTertiary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: AppDesign.space8),
                Expanded(
                  child: Text(
                    l10n.apnGuideUndo,
                    style: AppDesign.textTheme.bodySmall?.copyWith(
                      color: AppDesign.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDesign.space20),
            FilledButton.icon(
              onPressed: () => unawaited(openSettings()),
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: Text(l10n.apnGuideOpenSettings),
              style: _protectedTonal,
            ),
          ],
        ),
      ),
    );
  }
}

/// One numbered step. The number is in the language's own digits, and the
/// text is left as it is, so "IPv4/IPv6" keeps its digits.
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  static const double _disc = 24;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesign.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: _disc,
            height: _disc,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppDesign.protectedContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              NumberLocalizer.localize('$number', context),
              style: AppDesign.textTheme.labelMedium?.copyWith(
                color: AppDesign.protected,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: AppDesign.space12),
          Expanded(
            child: Text(
              text,
              style: AppDesign.textTheme.bodyMedium?.copyWith(
                color: AppDesign.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
