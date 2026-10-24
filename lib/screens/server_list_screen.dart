import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/design_system.dart';
import '../core/haptics.dart';
import '../core/return_home.dart';
import '../core/state/connect_flow.dart';
import '../core/state/dedicated_state.dart';
import '../core/state/dial_server.dart';
import '../core/state/server_state.dart';
import '../data/models/server.dart';
import '../services/vpn_service.dart';
import '../widgets/remote_refresh_button.dart';
import '../widgets/server_card.dart';
import '../widgets/server_title.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/server_sort.dart';

/// The community servers: whatever the crawler found in public Telegram
/// channels.
///
/// Servers Fortiva runs are not here. Every device is provisioned its own
/// set, and MyServersScreen is where those are listed and picked, so an
/// "Our servers" tab beside this one showed the user a second, shared
/// copy of the thing they had just been looking at. Two lists that both
/// claimed to be ours, one of them worse, is a question the screen should
/// not have been asking.
///
/// What is left is the one list that is genuinely somewhere else: links
/// anyone can post, worth reaching for when our own servers are blocked,
/// and carrying no promise about speed or uptime.
class ServerListScreen extends StatefulWidget {
  const ServerListScreen({super.key});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  /// The key ServerState files this screen's ping run under.
  ///
  /// It was the tab index while there were two tabs. With one list left
  /// the number means nothing in itself, but a run and the cancel that
  /// stops it have to name the same slot, so it is written down once
  /// rather than repeated at three call sites.
  static const _pingKey = 1;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Server> _filterAndSort(List<Server> servers, ServerState serverState) {
    var filtered = servers.toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((s) {
        // The title as the row shows it, so a Persian user finds
        // «سرور عمومی ۳» by typing what they see.
        return serverTitle(context, s).toLowerCase().contains(q) ||
            s.name.toLowerCase().contains(q) ||
            s.country.toLowerCase().contains(q) ||
            s.city.toLowerCase().contains(q) ||
            s.remark.toLowerCase().contains(q);
      }).toList();
    }

    return sortForDisplay(filtered, (s) => serverState.getPingResult(s.id));
  }

  /// Make [server] the one the home screen connects through, and go back
  /// to it.
  ///
  /// A live tunnel is rebuilt on the new server rather than left on the
  /// old one: a picker that only takes effect on the next connection is
  /// indistinguishable from one that does nothing. Going back is what
  /// makes the choice visible, since the home card is where the server
  /// in use is named. It goes all the way home (see [returnHome]): this
  /// list is usually opened from Your servers, and one pop left the user
  /// there.
  void _choose(Server server) {
    AppHaptics.selection();
    final l10n = S.of(context)!;
    final vpn = context.read<VpnService>();
    final servers = context.read<ServerState>();
    final flow = context.read<ConnectFlow>();
    final messenger = ScaffoldMessenger.of(context);

    servers.selectServer(server);
    if (vpn.isConnected || vpn.isConnecting || flow.isBusy) {
      // Through the flow, so a pick that does not work falls through to
      // this device's own doors, as on the connect button. See dialServer.
      // A checklist still running (isBusy) is replaced by this pick.
      unawaited(
        dialServer(
          server,
          vpn: vpn,
          flow: flow,
          dedicated: context.read<DedicatedState>(),
          servers: servers,
        ),
      );
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.myServersMoved(serverTitle(context, server))),
          duration: const Duration(seconds: 2),
        ),
      );
    returnHome(context);
  }

  /// A hairline of progress under the app bar while the list is tested.
  ///
  /// The title stays the title. A counter in its place made the screen
  /// look as if it had navigated somewhere, and progress is a bar's job.
  PreferredSizeWidget _progressBar() {
    const barHeight = 2.0;
    return PreferredSize(
      preferredSize: const Size.fromHeight(barHeight),
      child: Consumer<ServerState>(
        builder: (context, serverState, _) {
          final testing = serverState.isPingingTab(_pingKey);
          final total = serverState.pingTotal;
          return SizedBox(
            height: barHeight,
            child: testing
                ? LinearProgressIndicator(
                    value: total == 0 ? null : serverState.pingProgress / total,
                    minHeight: barHeight,
                    color: AppDesign.steelLight,
                    backgroundColor: AppDesign.surfaceHigh,
                  )
                : const SizedBox.shrink(),
          );
        },
      ),
    );
  }

  Server? _getFastestInList(List<Server> servers, ServerState serverState) {
    Server? best;
    int bestLatency = 999999;
    for (final s in servers) {
      final lat = serverState.getPingResult(s.id);
      if (lat != null && lat > 0 && lat < bestLatency) {
        bestLatency = lat;
        best = s;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    // Protected green on the chosen row only while the tunnel is up. Read
    // as optional, so a screen built without the VPN (a test) keeps the
    // protected look.
    final live = context.select<VpnService?, bool>(
      (vpn) => vpn?.isConnected ?? true,
    );

    return Scaffold(
      backgroundColor: AppDesign.canvas,
      appBar: AppBar(
        title: Text(l10n.tabCommunity),
        centerTitle: true,
        // The bar keeps the canvas color (not AppDesign.appBarColor): the
        // explainer and the search field stay put between it and the list,
        // so a bar that changed tone as the list scrolls would draw a seam
        // above them.
        // With Test all's own end padding, the pill ends on the 16dp line
        // the rows and the search field sit on, in both directions.
        actionsPadding: const EdgeInsetsDirectional.only(end: AppDesign.space8),
        actions: [
          // Before Test all, as on Your servers, so Test all is the last
          // action on both lists. Draws nothing on a phone.
          RemoteRefreshButton(
            onRefresh: () => context.read<ServerState>().refreshServers(),
          ),
          Consumer<ServerState>(
            builder: (context, serverState, _) {
              return TestAllButton(
                label: l10n.pingAll,
                busy: serverState.isPingingTab(_pingKey),
                busyLabel: l10n.stop,
                onTest: () {
                  AppHaptics.light();
                  serverState.pingServers(
                    serverState.communityServers,
                    tabIndex: _pingKey,
                  );
                },
                onStop: () {
                  AppHaptics.light();
                  serverState.cancelPing(tabIndex: _pingKey);
                },
              );
            },
          ),
        ],
        bottom: _progressBar(),
      ),
      body: Column(
        children: [
          // What these are, before the list. A community link is not a
          // server we run, and the row alone does not say so.
          const Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20, 12, 16, 0),
            child: _CommunityExplainer(),
          ),

          // Search
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: AppDesign.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: l10n.searchServers,
                hintStyle: AppDesign.textTheme.bodyLarge?.copyWith(
                  color: AppDesign.textTertiary,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppDesign.textTertiary,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).clearButtonTooltip,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppDesign.textTertiary,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppDesign.surfaceLow,
                border: OutlineInputBorder(
                  borderRadius: AppDesign.borderRadiusMedium,
                  borderSide: const BorderSide(color: AppDesign.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppDesign.borderRadiusMedium,
                  borderSide: const BorderSide(color: AppDesign.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppDesign.borderRadiusMedium,
                  borderSide: const BorderSide(
                    color: AppDesign.steelLight,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),

          Expanded(
            child: Consumer<ServerState>(
              builder: (context, serverState, _) {
                // Only the very first load gets a spinner in place of the
                // list. A refresh keeps the rows in view under the pull
                // indicator, instead of blanking them for a second.
                if (serverState.isLoading && !serverState.hasServers) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppDesign.steelLight,
                    ),
                  );
                }

                // An empty list is one of three things, and only an answer
                // with no links in it is "no servers yet". A load that is
                // still running, or one that failed with nothing kept from
                // before, says so instead.
                if (serverState.communityServers.isEmpty) {
                  if (serverState.isLoadingCommunity) {
                    return _refreshable(
                      serverState,
                      _scrollableCenter(
                        const CircularProgressIndicator(
                          color: AppDesign.steelLight,
                        ),
                      ),
                    );
                  }
                  if (serverState.communityLoadFailed) {
                    return _refreshable(
                      serverState,
                      _scrollableCenter(
                        _LoadFailed(onRetry: serverState.retryCommunityServers),
                      ),
                    );
                  }
                }

                return _refreshable(
                  serverState,
                  _buildServerTab(
                    serverState.communityServers,
                    serverState,
                    emptyIcon: Icons.people_outline_rounded,
                    emptyMessage: l10n.noCommunityServers,
                    live: live,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Pull to refresh.
  ///
  /// Both lists are cached, and community links go stale within hours,
  /// so this is the one screen where being able to ask again matters.
  Widget _refreshable(ServerState serverState, Widget child) {
    return RefreshIndicator(
      onRefresh: serverState.refreshServers,
      color: AppDesign.steelLight,
      backgroundColor: AppDesign.surfaceHigh,
      child: child,
    );
  }

  /// An empty list that can still be pulled, since an empty list is when
  /// a refresh is wanted most.
  Widget _emptyState({required IconData icon, required String message}) {
    return _scrollableCenter(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EmptyMark(icon: icon),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppDesign.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// [child] in the middle of a view that the pull to refresh can drag.
  ///
  /// At least as tall as the view, and taller when [child] needs it, so a
  /// short view (the keyboard open over the search field) scrolls rather
  /// than cutting off the bottom of [child].
  Widget _scrollableCenter(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        ],
      ),
    );
  }

  Widget _buildServerTab(
    List<Server> servers,
    ServerState serverState, {
    required IconData emptyIcon,
    required String emptyMessage,
    required bool live,
  }) {
    final l10n = S.of(context)!;
    final filtered = _filterAndSort(servers, serverState);
    final fastest = _getFastestInList(servers, serverState);

    if (servers.isEmpty) {
      return _emptyState(icon: emptyIcon, message: emptyMessage);
    }

    if (filtered.isEmpty) {
      return _emptyState(
        icon: Icons.search_off_rounded,
        message: l10n.noResultsFor(_searchQuery),
      );
    }

    // The fastest server leads the list in its own row, so it is not
    // repeated among the others.
    final rows = fastest == null
        ? filtered
        : [
            for (final s in filtered)
              if (s.id != fastest.id) s,
          ];
    final lead = fastest != null ? 1 : 0;

    // Where each server's row is now. Results re-sort the list during
    // Test all, and the lead row changes hands. With this the list moves a
    // row's element along with its server instead of rebuilding it in
    // place, so a TV remote's focus stays on the server it was on.
    final indexOf = <String, int>{
      if (fastest != null) fastest.id: 0,
      for (var i = 0; i < rows.length; i++) rows[i].id: i + lead,
    };

    return ListView.builder(
      // A short list must still give the pull gesture something to drag.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppDesign.clearOfNavBar(
        context,
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      itemCount: rows.length + lead,
      findChildIndexCallback: (key) =>
          key is ValueKey<String> ? indexOf[key.value] : null,
      itemBuilder: (context, index) {
        if (fastest != null && index == 0) {
          return _buildRow(
            fastest,
            serverState,
            live: live,
            gap: AppDesign.space16,
            heading: _fastestHeading(),
          );
        }
        return _buildRow(rows[index - lead], serverState, live: live);
      },
    );
  }

  /// One server's row. The key is on the outermost widget, the one the
  /// list keys its children by, and the lead row is the same widget with
  /// a heading, so a row keeps its element when it moves.
  Widget _buildRow(
    Server server,
    ServerState serverState, {
    required bool live,
    double gap = AppDesign.space8,
    Widget? heading,
  }) {
    return Padding(
      key: ValueKey(server.id),
      padding: EdgeInsets.only(bottom: gap),
      child: ServerCard(
        server: server,
        isSelected: server.id == serverState.selectedServer?.id,
        isPinging: serverState.isPinging(server.id),
        isQueued: serverState.isQueued(server.id),
        pingResult: serverState.getPingResult(server.id),
        heading: heading,
        live: live,
        onPing: () {
          AppHaptics.light();
          serverState.pingServer(server);
        },
        onTap: () => _choose(server),
      ),
    );
  }

  /// The small heading over the quickest server the last test found.
  Widget _fastestHeading() {
    final l10n = S.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Steel, not the protected green: it marks a place in the list,
        // not a state of the connection.
        const Icon(Icons.bolt_rounded, size: 14, color: AppDesign.steelLight),
        const SizedBox(width: AppDesign.space4),
        Flexible(
          child: Text(
            l10n.fastestServer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: serverRowLabelStyle(context),
          ),
        ),
      ],
    );
  }
}

/// The quiet mark over an empty or failed list: an icon in a steel disc.
class _EmptyMark extends StatelessWidget {
  const _EmptyMark({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        color: AppDesign.surfaceLow,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 28, color: AppDesign.steelMid),
    );
  }
}

/// What the list says when it could not be loaded and nothing is kept
/// from before: that, and a button to try again.
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  /// The key of this message, for tests.
  static const messageKey = Key('community-load-failed');

  /// The key of the button, for tests.
  static const retryKey = Key('community-load-retry');

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _EmptyMark(icon: Icons.cloud_off_rounded),
          const SizedBox(height: 16),
          Text(
            l10n.communityLoadFailed,
            key: messageKey,
            textAlign: TextAlign.center,
            style: AppDesign.textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: retryKey,
            onPressed: () {
              AppHaptics.light();
              onRetry();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l10n.communityRetry),
          ),
        ],
      ),
    );
  }
}

/// One short line saying where these servers come from and when to reach
/// for them. A calm note, not a box: it is read once, then the list is
/// what matters.
class _CommunityExplainer extends StatelessWidget {
  const _CommunityExplainer();

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final style = AppDesign.textTheme.bodySmall?.copyWith(
      color: AppDesign.textSecondary,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Centers the icon on the first line of text.
          padding: const EdgeInsets.only(top: 3),
          child: const Icon(
            Icons.info_outline_rounded,
            color: AppDesign.textTertiary,
            size: 14,
          ),
        ),
        const SizedBox(width: AppDesign.space8),
        Expanded(child: Text(l10n.communityTabExplainer, style: style)),
      ],
    );
  }
}
