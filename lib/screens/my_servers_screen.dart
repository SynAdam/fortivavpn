import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/design_system.dart';
import '../core/haptics.dart';
import '../core/page_transitions.dart';
import '../core/return_home.dart';
import '../core/state/app_config_state.dart';
import '../core/state/billing_state.dart';
import '../core/state/connect_flow.dart';
import '../core/state/dedicated_state.dart';
import '../core/state/dial_server.dart';
import '../core/state/referral_state.dart';
import '../core/state/server_state.dart';
import '../data/models/billing.dart';
import '../data/models/server.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/vpn_service.dart';
import '../utils/vless_link.dart';
import '../widgets/premium_offers.dart';
import '../widgets/quota_card.dart';
import '../widgets/remote_refresh_button.dart';
import '../widgets/server_card.dart';
import '../widgets/server_title.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/pressable.dart';
import '../widgets/ui/signal_bars.dart';
import 'premium_screen.dart';
import 'server_list_screen.dart';

/// The servers that belong to this device.
///
/// Distinct from the public lists: these are provisioned for this install
/// alone, one per reachable server, and metered against a rolling 24h
/// allowance. Because they are not shared, they are far less likely to be
/// blocked than a link that has circulated publicly.
///
/// This is the app's server picker, not a reference screen. Choosing one
/// here is what the connect button on the home screen will use, and it
/// takes effect immediately when the tunnel is already up. A pick goes
/// straight back to the home screen.
class MyServersScreen extends StatefulWidget {
  const MyServersScreen({super.key});

  @override
  State<MyServersScreen> createState() => _MyServersScreenState();
}

class _MyServersScreenState extends State<MyServersScreen> {
  /// Space between the blocks of the screen, and between two rows.
  static const double _blockGap = AppDesign.space12;
  static const double _rowGap = AppDesign.space8;

  @override
  void initState() {
    super.initState();
    // Provisioning happens server-side on first call, so this is what
    // actually creates the device's clients. Idempotent thereafter.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DedicatedState>().refresh();
    });
  }

  Future<void> _copy(Server server) async {
    await Clipboard.setData(ClipboardData(text: server.connectionUri));
    if (!mounted) return;
    _toast(S.of(context)!.linkCopied);
  }

  /// Move this device onto another of its servers.
  ///
  /// A live tunnel is rebuilt on the new server rather than left running
  /// on the old one, because a picker that silently defers until the next
  /// connection is indistinguishable from one that does nothing.
  ///
  /// Any shared server the user had picked is given up here, since this
  /// is the only way back off one.
  ///
  /// The screen then goes back to the home screen (see [returnHome]), and
  /// the toast is shown there.
  void _select(Server server) {
    final l10n = S.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final dedicated = context.read<DedicatedState>();
    final servers = context.read<ServerState>();
    final vpn = context.read<VpnService>();
    final flow = context.read<ConnectFlow>();

    servers.clearChoice();
    // A pick: its doors go first on later taps too, until a tap lands on
    // another server (DedicatedState.selectedByUser).
    dedicated.select(server);
    // A live tunnel, or a connect checklist still running, moves onto the new
    // server through the flow, so the move gets this server's other doors and
    // the fallback the connect button has. See dialServer.
    if (vpn.isConnected || vpn.isConnecting || flow.isBusy) {
      unawaited(
        _moveOnto(server, vpn, flow, dedicated, servers, l10n, messenger),
      );
    } else {
      _showToast(messenger, l10n.myServersMoved(serverTitle(context, server)));
    }
    returnHome(context);
  }

  /// Move onto [picked] through the flow, then name the server that actually
  /// carried the tunnel. The flow lands on another of our servers, or on a
  /// shared link, when none of [picked]'s doors work, so the toast must not
  /// promise the pick when it fell back to a different one.
  ///
  /// This screen has closed by the time the move ends, so the toast goes
  /// through [messenger], which sits above every route, and shows on the
  /// home screen. It is left out when the tunnel is neither up nor coming
  /// up: the move failed and the home screen's error bar says why, or the
  /// user stopped it there.
  Future<void> _moveOnto(
    Server picked,
    VpnService vpn,
    ConnectFlow flow,
    DedicatedState dedicated,
    ServerState servers,
    S l10n,
    ScaffoldMessengerState messenger,
  ) async {
    await dialServer(
      picked,
      vpn: vpn,
      flow: flow,
      dedicated: dedicated,
      servers: servers,
    );
    if (!messenger.mounted) return;
    if (!vpn.isConnected && !vpn.isConnecting) return;
    // The backup network carried it when nothing else would. It never
    // moves the selection, so the selection would name the pick. Or a
    // shared link carried it when none of our own doors would, and the
    // selection followed it there.
    final landed = vpn.onPsiphon
        ? Server.psiphon
        : servers.isChosen
        ? servers.selectedServer
        : dedicated.selectedServer;
    // The screen has closed by now; the messenger sits under the app's
    // localizations, so its context still names the server in the
    // phone's language.
    _showToast(
      messenger,
      l10n.myServersMoved(serverTitle(messenger.context, landed ?? picked)),
    );
  }

  /// Whether invites can add no more daily data on this device: the config
  /// has arrived and invites are off, or this device has already earned
  /// the most that invites give (ReferralStatus.maxBonusBytes). Anything
  /// not known counts as no. The invite status is loaded by the invite
  /// screen, so before the user has opened it, invites still count as a
  /// free way to more data, and they come before Premium.
  bool _invitesSpent(BuildContext context) {
    final config = context.watch<AppConfigState?>();
    if (config?.config == null) return false;
    if (!config!.referralsEnabled) return true;
    final status = context.watch<ReferralState?>()?.status;
    final most = status?.maxBonusBytes;
    return status != null && most != null && status.bonusBytes >= most;
  }

  void _toast(String message) =>
      _showToast(ScaffoldMessenger.of(context), message);

  static void _showToast(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;

    return Scaffold(
      backgroundColor: AppDesign.canvas,
      appBar: AppBar(
        title: Text(l10n.myServersTitle),
        centerTitle: true,
        backgroundColor: AppDesign.appBarColor,
        // With Test all's own end padding, the pill ends on the 16dp line
        // the cards and the back arrow sit on, in both directions.
        actionsPadding: const EdgeInsetsDirectional.only(end: AppDesign.space8),
        actions: [
          RemoteRefreshButton(
            onRefresh: () => context.read<DedicatedState>().refresh(),
          ),
          Consumer<DedicatedState>(
            builder: (context, state, _) {
              if (!state.hasServers) return const SizedBox.shrink();
              return TestAllButton(
                label: l10n.pingAll,
                busy: state.isPingingAll,
                busyLabel: l10n.pinging,
                onTest: () {
                  AppHaptics.light();
                  state.pingAll();
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<DedicatedState>(
        builder: (context, state, _) {
          if (state.isLoading && !state.hasServers) {
            return const Center(
              child: CircularProgressIndicator(color: AppDesign.steelLight),
            );
          }

          final selectedId = state.selectedServer?.id;
          // "Get unlimited" shows only when this copy can buy something
          // here (BillingState.canBuy), this device is not Premium and the
          // backend sent an upsell block (BillingState.offersAllowed). With
          // sales on and only the code box offered, or in a copy that
          // cannot buy through Google Play, it stays hidden, because
          // nothing can be bought.
          // Read as optional, so a screen built without payments (an older
          // test, a build that never made the state) simply has no action.
          final billing = context.watch<BillingState?>();
          final upsell = billing?.offersAllowed ?? false;
          VoidCallback? from(PremiumSource source) =>
              upsell ? () => PremiumScreen.open(context, source: source) : null;
          // Premium is the next step once invites can add no more data
          // (_invitesSpent), when the backend turns the card on. The card
          // says the user already has the most free data, which is not
          // true while invites can still add some.
          final nextStep =
              _invitesSpent(context) &&
              (billing?.upsellOn(UpsellSurface.myServersCard) ?? false);
          final locked =
              billing != null && billing.upsellOn(UpsellSurface.lockedServers)
              ? billing.upsell?.lockedServers ?? const <LockedServer>[]
              : const <LockedServer>[];

          return RefreshIndicator(
            onRefresh: state.refresh,
            color: AppDesign.steelLight,
            backgroundColor: AppDesign.surfaceHigh,
            child: ListView(
              padding: AppDesign.clearOfNavBar(
                context,
                const EdgeInsets.all(16),
              ),
              children: [
                const _Explainer(),
                const SizedBox(height: _blockGap),
                if (state.quota != null)
                  QuotaCard(
                    quota: state.quota!,
                    onGetUnlimited: from(PremiumSource.quotaCard),
                  ),
                if (state.quota != null) const SizedBox(height: _blockGap),
                if (nextStep) ...[
                  UpsellShown(
                    surface: UpsellSurface.myServersCard,
                    child: PremiumOfferCard(
                      title: l10n.premiumNextStepTitle,
                      body: l10n.premiumNextStepBody,
                      onGetUnlimited: () {
                        billing!.logUpsell(
                          UpsellSurface.myServersCard,
                          UpsellAction.tapped,
                        );
                        PremiumScreen.open(
                          context,
                          source: PremiumSource.myServersCard,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: _blockGap),
                ],
                if (state.errorMessage != null) ...[
                  _ErrorBanner(message: state.errorMessage!),
                  const SizedBox(height: _blockGap),
                ],
                if (state.isBlocked)
                  _BlockedNotice(
                    onGetUnlimited: from(PremiumSource.spentNotice),
                  )
                else if (!state.hasServers)
                  _EmptyNotice(onRetry: state.refresh)
                else ...[
                  ...state.servers.map(
                    // Keyed on the outer widget, the one the list keys
                    // its children by, so a row that moves keeps its
                    // element and a TV remote's focus.
                    (server) => Padding(
                      key: ValueKey(server.id),
                      padding: const EdgeInsets.only(bottom: _rowGap),
                      child: _ServerTile(
                        server: server,
                        isSelected: server.id == selectedId,
                        latencyMs: state.pingFor(server.id),
                        isPinging: state.isPinging(server.id),
                        onSelect: () => _select(server),
                        onCopy: () => _copy(server),
                      ),
                    ),
                  ),
                  // Premium locations, locked. Each sits apart from this
                  // device's own servers and carries no address.
                  if (locked.isNotEmpty)
                    UpsellShown(
                      surface: UpsellSurface.lockedServers,
                      child: Column(
                        children: [
                          for (final server in locked)
                            Padding(
                              padding: const EdgeInsets.only(bottom: _rowGap),
                              child: LockedServerTile(server: server),
                            ),
                        ],
                      ),
                    ),
                ],
                // Set apart from the rows above it, so the way out does
                // not read as one more server to pick.
                const SizedBox(height: AppDesign.space16),
                const _SharedServersLink(),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Says what makes this list different from the public one.
///
/// Without it the screen is just another location picker: the servers are
/// the same protocol in the same cities, and nothing on a tile shows that
/// the credentials behind them were issued to this device alone. It is a
/// calm note rather than a box, because it is read once and the rows below
/// are what the screen is for.
class _Explainer extends StatelessWidget {
  const _Explainer();

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppDesign.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            // Centers the icon on the first line of text.
            padding: EdgeInsets.only(top: 3),
            child: Icon(
              Icons.info_outline_rounded,
              color: AppDesign.textTertiary,
              size: 14,
            ),
          ),
          const SizedBox(width: AppDesign.space8),
          Expanded(
            child: Text(
              l10n.myServersExplainer,
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

/// An icon in a tinted disc, at the head of a notice.
class _NoticeMark extends StatelessWidget {
  const _NoticeMark({
    required this.icon,
    required this.color,
    required this.fill,
  });

  final IconData icon;
  final Color color;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

/// The way out to the shared lists.
///
/// The home card opens this screen rather than the shared one as soon as
/// the device has servers of its own, and the Settings entry for the
/// shared list is gone, so without a link here the "Our servers" and
/// "Community" tabs are unreachable for the whole life of the install.
/// They are the fallback when a dedicated server is blocked or the daily
/// allowance is spent, which is exactly when nobody can afford to go
/// looking for them.
///
/// It is drawn as an outlined row on the canvas, not a filled one like the
/// server rows, because a tap here leaves for another list and does not
/// pick a server.
class _SharedServersLink extends StatelessWidget {
  const _SharedServersLink();

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final text = AppDesign.textTheme;
    return Pressable(
      onTap: () => Navigator.push(
        context,
        SlideUpFadeTransition(page: const ServerListScreen()),
      ),
      color: AppDesign.canvas,
      border: const BorderSide(color: AppDesign.outlineVariant),
      // The chevron sits in a 48dp box with 4dp after it, so its center
      // lines up with the Copy link buttons on the rows above.
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 4, 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppDesign.surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.public_rounded,
                color: AppDesign.steelLight,
                size: 20,
              ),
            ),
            const SizedBox(width: AppDesign.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.sharedServersTitle, style: text.titleMedium),
                  const SizedBox(height: AppDesign.space2),
                  Text(
                    l10n.sharedServersSubtitle,
                    style: text.bodySmall?.copyWith(
                      color: AppDesign.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDesign.space8),
            const SizedBox(
              width: 48,
              child: Center(
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppDesign.textTertiary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of this device's servers, shown by place rather than by raw URI.
class _ServerTile extends StatelessWidget {
  final Server server;
  final bool isSelected;
  final int? latencyMs;
  final bool isPinging;
  final VoidCallback onSelect;
  final VoidCallback onCopy;

  const _ServerTile({
    required this.server,
    required this.isSelected,
    required this.latencyMs,
    required this.isPinging,
    required this.onSelect,
    required this.onCopy,
  });

  String get _endpoint => VlessLink.host(server.connectionUri);

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final ms = latencyMs;
    // Protected green on the chosen row only while the tunnel is up. Read
    // as optional, so a screen built without the VPN (a test) keeps the
    // protected look.
    final live = context.select<VpnService?, bool>(
      (vpn) => vpn?.isConnected ?? true,
    );
    return ServerRow(
      flag: server.flagEmoji,
      title: serverTitle(context, server),
      subtitle: _endpoint,
      isSelected: isSelected,
      live: live,
      onTap: onSelect,
      badge: isSelected
          ? InUseBadge(label: l10n.myServersInUse, live: live)
          : null,
      // The Copy link button carries its own space at the end.
      endPadding: AppDesign.space4,
      trailing: [
        if (isPinging)
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppDesign.steelLight,
            ),
          )
        else if (ms != null)
          LatencyChip(ms: ms, timeoutLabel: l10n.timeout),
        IconButton(
          onPressed: onCopy,
          icon: const Icon(
            Icons.copy_rounded,
            color: AppDesign.textSecondary,
            size: 18,
          ),
          tooltip: l10n.copyLink,
        ),
      ],
    );
  }
}

class _BlockedNotice extends StatelessWidget {
  /// Opens the Premium screen, or null when it is not offered.
  final VoidCallback? onGetUnlimited;

  const _BlockedNotice({this.onGetUnlimited});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final text = AppDesign.textTheme;
    return AppCard(
      child: Column(
        children: [
          const _NoticeMark(
            icon: Icons.hourglass_empty_rounded,
            color: AppDesign.warning,
            fill: AppDesign.warningContainer,
          ),
          const SizedBox(height: AppDesign.space12),
          Text(
            l10n.myServersBlockedTitle,
            textAlign: TextAlign.center,
            style: text.titleSmall?.copyWith(color: AppDesign.textPrimary),
          ),
          const SizedBox(height: AppDesign.space6),
          Text(
            l10n.myServersBlockedWait,
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          if (onGetUnlimited != null) ...[
            const SizedBox(height: AppDesign.space16),
            FilledButton.icon(
              onPressed: onGetUnlimited,
              icon: const Icon(Icons.all_inclusive_rounded, size: 18),
              label: Text(l10n.premiumGetUnlimited),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyNotice extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _EmptyNotice({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return AppCard(
      child: Column(
        children: [
          const _NoticeMark(
            icon: Icons.cloud_off_rounded,
            color: AppDesign.steelMid,
            fill: AppDesign.surfaceHigh,
          ),
          const SizedBox(height: AppDesign.space12),
          Text(
            l10n.myServersEmpty,
            textAlign: TextAlign.center,
            style: AppDesign.textTheme.titleSmall?.copyWith(
              color: AppDesign.textPrimary,
            ),
          ),
          const SizedBox(height: AppDesign.space8),
          TextButton(onPressed: onRetry, child: Text(l10n.myServersRetry)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppDesign.errorContainer,
        borderRadius: AppDesign.borderRadiusMedium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppDesign.error,
            size: 20,
          ),
          const SizedBox(width: AppDesign.space12),
          Expanded(
            child: Text(
              message,
              style: AppDesign.textTheme.bodyMedium?.copyWith(
                color: AppDesign.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
