import 'package:flutter/material.dart';

import '../core/design_system.dart';
import '../core/form_factor.dart';
import '../l10n/generated/app_localizations.dart';

/// A refresh button for an app bar, on a TV only.
///
/// A list that refreshes by being pulled down cannot be refreshed with a
/// remote. On a phone the pull is there and this draws nothing.
class RemoteRefreshButton extends StatefulWidget {
  const RemoteRefreshButton({super.key, required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  State<RemoteRefreshButton> createState() => _RemoteRefreshButtonState();
}

class _RemoteRefreshButtonState extends State<RemoteRefreshButton> {
  bool _busy = false;

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onRefresh();
    } catch (e) {
      debugPrint('RemoteRefreshButton: refresh failed ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FormFactor.isTv) return const SizedBox.shrink();
    return IconButton(
      // Not disabled while busy: a disabled button loses the remote's
      // focus, which then jumps elsewhere on the screen.
      onPressed: _refresh,
      tooltip: S.of(context)!.refresh,
      icon: _busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppDesign.steelLight,
              ),
            )
          : const Icon(
              Icons.refresh_rounded,
              color: AppDesign.textSecondary,
              size: 22,
            ),
    );
  }
}
