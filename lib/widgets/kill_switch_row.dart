import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design_system.dart';
import '../core/form_factor.dart';
import '../core/state/app_config_state.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/vpn_service.dart';
import 'ui/sheet_handle.dart';

/// The Settings row about Android's own block of all internet while no VPN
/// is connected (Always-on VPN with Block connections without VPN), built
/// by [builder] with a callback that opens the steps.
///
/// The app turns nothing on and stores nothing: the row points the user to
/// Android's VPN settings, and the choice stays theirs. It shows only when
/// the backend turns it on (FeatureFlags.enableKillSwitch), on an Android
/// phone with Android 8.0 or later, the first with the block, and never on
/// a TV. It builds nothing otherwise, so the row it builds brings its own
/// divider (SettingsScreen).
class KillSwitchStatus extends StatefulWidget {
  const KillSwitchStatus({
    super.key,
    required this.builder,
    @visibleForTesting this.shown,
    @visibleForTesting this.sdkInt,
    @visibleForTesting this.openSettings,
  });

  final Widget Function(BuildContext context, VoidCallback open) builder;

  /// Whether this platform shows the row at all. Android phones only by
  /// default.
  final bool Function()? shown;

  /// The phone's Android API level. Read from the platform by default.
  final Future<int> Function()? sdkInt;

  /// Opens Android's VPN settings. VpnService.openSystemVpnSettings by
  /// default.
  final Future<bool> Function()? openSettings;

  /// The first API level with Block connections without VPN (Android 8.0).
  static const firstSdk = 26;

  /// Stands in for the platform's answer in tests of screens that hold
  /// the row, which cannot pass [sdkInt] to it.
  @visibleForTesting
  static Future<int> Function()? sdkIntForTest;

  @override
  State<KillSwitchStatus> createState() => _KillSwitchStatusState();
}

class _KillSwitchStatusState extends State<KillSwitchStatus> {
  /// The API level, read once per run of the app.
  static int? _knownSdk;

  int? _sdk;

  bool get _shown =>
      widget.shown?.call() ??
      (defaultTargetPlatform == TargetPlatform.android && !FormFactor.isTv);

  @override
  void initState() {
    super.initState();
    if (_shown) unawaited(_read());
  }

  Future<void> _read() async {
    final custom = widget.sdkInt ?? KillSwitchStatus.sdkIntForTest;
    int? sdk;
    try {
      sdk = custom != null
          ? await custom()
          : (_knownSdk ??=
                (await DeviceInfoPlugin().androidInfo).version.sdkInt);
    } catch (e) {
      // The row stays hidden: without the level it cannot say whether the
      // phone has the setting.
      debugPrint('KillSwitchStatus: could not read the Android version ($e)');
      sdk = null;
    }
    if (mounted && sdk != _sdk) setState(() => _sdk = sdk);
  }

  void _open() {
    unawaited(
      showKillSwitchSheet(
        context,
        openSettings: widget.openSettings ?? VpnService.openSystemVpnSettings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final on =
        context.watch<AppConfigState?>()?.flags.enableKillSwitch ?? false;
    final sdk = _sdk;
    if (!_shown || !on || sdk == null || sdk < KillSwitchStatus.firstSdk) {
      return const SizedBox.shrink();
    }
    return widget.builder(context, _open);
  }
}

/// The steps to turn on Android's block of connections without a VPN, and
/// how to undo it, with the button that opens Android's VPN settings. The
/// sheet stays open while those settings are up, so the steps are still
/// there when the user comes back.
Future<void> showKillSwitchSheet(
  BuildContext context, {
  required Future<bool> Function() openSettings,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _KillSwitchSheet(openSettings: openSettings),
  );
}

class _KillSwitchSheet extends StatelessWidget {
  const _KillSwitchSheet({required this.openSettings});

  final Future<bool> Function() openSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
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
                l10n.killSwitchTitle,
                style: AppDesign.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppDesign.space16),
            Text(
              l10n.killSwitchSteps,
              style: AppDesign.textTheme.bodyMedium?.copyWith(
                color: AppDesign.textPrimary,
              ),
            ),
            const SizedBox(height: AppDesign.space12),
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
                    l10n.killSwitchUndo,
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
              label: Text(l10n.openVpnSettings),
            ),
          ],
        ),
      ),
    );
  }
}
