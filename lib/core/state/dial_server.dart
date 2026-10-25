import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../data/models/server.dart';
import '../../services/vpn_service.dart';
import 'connect_flow.dart';
import 'dedicated_state.dart';
import 'server_state.dart';

/// The server the connect button dials.
///
/// A shared link the user picked by hand comes first, because they
/// reach for that list when our own servers are not working on their
/// carrier, and overruling them would put them straight back on the
/// blocked server. Otherwise this device's own whenever provisioning
/// has produced one, and a shared link only as a fallback while that is
/// still pending.
///
/// Nothing at all while the allowance is spent: the shared links are
/// unmetered, so falling back to them would turn the daily limit into a
/// suggestion.
Server? activeServer(DedicatedState dedicated, ServerState servers) {
  if (dedicated.isBlocked) return null;
  if (servers.isChosen) return servers.selectedServer;
  return dedicated.selectedServer ?? servers.selectedServer;
}

/// Re-read this device's servers and allowance, and take down a tunnel
/// that the allowance no longer covers.
///
/// The tunnel outlives the app: on Android the VPN service keeps running
/// across a relaunch, so the screen can come up already connected through
/// a shared link the user picked up before the window was spent. Nothing
/// meters that link, so only the app can end it.
Future<void> refreshAllowance({
  required VpnService vpn,
  required DedicatedState dedicated,
}) async {
  // The backend orders the doors for the network the request came from,
  // which it can only tell when the request went around the tunnel. On
  // Android this app is excluded from its own tunnel, so that is always;
  // on iOS only while disconnected.
  await dedicated.refresh(
    viaTunnel: Platform.isAndroid ? false : vpn.isConnected,
  );
  if (!dedicated.isBlocked) return;
  if (vpn.isConnected || vpn.isConnecting) vpn.disconnect();
}

/// What a tap on the connect button does while the tunnel is down.
///
/// The home screen's button and the Connect button on the forced update
/// dialog both run this, so a user who has to update gets online through
/// exactly the servers, doors and fallbacks the home screen would use.
///
/// [server] is what the button would dial, usually [activeServer]. Null
/// means there is nothing to connect through yet. Over the allowance, the
/// only thing a tap can usefully do is ask whether the window has refilled
/// since the last look; before provisioning has come back, ask for it
/// again rather than leaving a dead button or opening an empty picker.
///
/// A shared link that only stands in for servers that have not loaded is
/// not a pick. Those servers are asked for again first: a new install
/// whose one request at launch failed tapped nine times that evening,
/// and every tap dialled the fallback link. [onWaitingForOwn] is told
/// when that wait starts and ends, so the caller can show the button as
/// busy, and [stillWanted] is asked after it, so a screen that has gone
/// away does not dial.
/// How long a tap with no servers of its own waits for them before it
/// dials the shared links. Long enough for a phone whose network carries
/// our calls; on one that cuts them, the fetch would take every route's
/// timeout in turn.
const ownServersWait = Duration(seconds: 8);

Future<void> connectFromButton(
  Server? server, {
  required VpnService vpn,
  required ConnectFlow flow,
  required DedicatedState dedicated,
  required ServerState servers,
  void Function(bool waiting)? onWaitingForOwn,
  bool Function()? stillWanted,
}) async {
  if (server == null) {
    unawaited(refreshAllowance(vpn: vpn, dedicated: dedicated));
    if (!dedicated.isBlocked) servers.loadServers();
    return;
  }
  flow.reset();

  if (!server.isDedicated && !servers.isChosen && dedicated.paths.isEmpty) {
    onWaitingForOwn?.call(true);
    try {
      // At most [ownServersWait]: a network that cuts our calls makes the
      // fetch wait out every route, about ten seconds each, and the user
      // waits for nothing. The fetch carries on, and the shared links are
      // raced meanwhile.
      await refreshAllowance(
        vpn: vpn,
        dedicated: dedicated,
      ).timeout(ownServersWait, onTimeout: () {});
    } finally {
      onWaitingForOwn?.call(false);
    }
    if (!(stillWanted?.call() ?? true)) return;
    final active = activeServer(dedicated, servers);
    // Null once the refresh finds the allowance spent.
    if (active == null) return;
    server = active;
  }

  // This device's own servers: the flow picks the door, tries the
  // remembered one first, and shows the checklist only when it has to.
  // The selection follows the door it lands on.
  await dialServer(
    server,
    vpn: vpn,
    flow: flow,
    dedicated: dedicated,
    servers: servers,
  );
}

/// What a tap on the connect button does while a connect is under way or
/// the tunnel is up: stop all of it, at once.
///
/// The flow is stopped first ([ConnectFlow.stop]), so its run is stale and
/// dials nothing more, checks no more doors and falls back on nothing.
/// Then the tunnel comes down, which also stops a start the platform has
/// not confirmed and the traffic check of one that is up. The status
/// changes inside this call, before the platform answers. A stop is not a
/// failure: it shows no error and reports nothing as one. A remembered
/// door whose dial the stop cut short after a while is forgotten for the
/// next tap, without counting as a failure, and so is one whose dial
/// failed while the search after it still ran.
///
/// The forced update dialog's Disconnect runs this too. The home screen
/// does not run it for the second tap of a double tap on its button; see
/// HomeScreen.doubleTapGuard.
Future<void> stopConnecting({
  required VpnService vpn,
  required ConnectFlow flow,
}) async {
  flow.stop();
  try {
    await vpn.disconnect();
  } catch (e) {
    debugPrint('stopConnecting: $e');
  }
}

/// Dial [server] the way the connect button does.
///
/// With servers of its own, the device goes through the connect flow:
/// [server]'s doors first, standby doors next to the one that opens, and
/// another server's doors when none of [server]'s work. [server]'s doors
/// go first only when the user picked it (see [_pickedOwn]); otherwise
/// the backend's door order is kept. A shared link
/// the user picked is dialled first, because they picked it, and the flow
/// then carries on through the device's own doors.
///
/// The servers screens used to dial a pick's one link directly. When that
/// link's TLS was being reset, the phone got "Server not working, try
/// another" again and again while other doors worked.
///
/// Without servers of its own, or over the allowance, [server] is dialled
/// on its own, as before.
///
/// [afterStall] when no one tapped: the tunnel stopped carrying data and
/// StallRecovery looks for another door. The screen says so while it
/// looks ([ConnectFlow.afterStall]).
Future<void> dialServer(
  Server server, {
  required VpnService vpn,
  required ConnectFlow flow,
  required DedicatedState dedicated,
  required ServerState servers,
  bool afterStall = false,
}) async {
  final paths = dedicated.isBlocked ? const <Server>[] : dedicated.paths;
  if (paths.isEmpty && !dedicated.isBlocked && !server.isDedicated) {
    // No servers of its own yet: the pick, then the other shared links.
    if (flow.isBusy) flow.cancel();
    final sharedReady = _lookForShared(servers);
    // A link the fallback chose is not the user's pick: on a handover to
    // our doors it is checked beside them (ownFirst), as on the normal path.
    final pickByFallback = servers.chosenByFallback;
    final pickIsChoice = servers.isChosen && !pickByFallback;
    await flow.connectShared(
      server,
      shared: () async {
        await sharedReady;
        // The shared links are unmetered: none while the allowance is spent.
        return dedicated.isBlocked ? const <Server>[] : sharedFallback(servers);
      },
      // The device's own servers, once they arrive. The run hands over to
      // them at once, rather than racing shared links while they sit here.
      own: () => dedicated.isBlocked ? const <Server>[] : dedicated.paths,
      // Read when the run hands over, after the servers and their saved
      // selection have arrived: a server of ours goes first only when the
      // user picked it (see _pickedOwn).
      preferredOwn: () => _pickedOwn(server, dedicated),
      selection: () => dedicated.selectedServer,
      pickIsChoice: pickIsChoice,
      pickByFallback: pickByFallback,
      blocked: () => dedicated.isBlocked,
      // Where the tap landed, not a pick, as in connect below.
      onSwitchedServer: (s) => dedicated.select(s, byUser: false),
      // The tunnel is on another shared link now, so the card names it
      // and the next tap tries it first.
      onShared: (s) => servers.selectServer(s, byFallback: true),
      allowanceSpent: () => askAllowance(vpn, dedicated),
      beforeRetry: () => _beforeRetry(vpn, dedicated, servers),
      afterStall: afterStall,
    );
    // A pick of the user's that failed while one of ours carried the
    // tunnel: the next tap goes straight to ours.
    if ((pickIsChoice || pickByFallback) &&
        flow.stage == ConnectStage.done &&
        (flow.chosen?.isDedicated ?? false)) {
      servers.clearChoice();
    }
    return;
  }
  if (paths.isEmpty) {
    // A tap may take the VPN slot from another app; the search after a
    // dead tunnel may not (VpnService.allowTakingSlot).
    if (!afterStall) vpn.allowTakingSlot();
    // Fire and forget, but a failed connect must not become an unhandled
    // async error: this runs from a screen tap, with nothing awaiting it.
    unawaited(
      vpn
          .connect(server)
          .catchError((Object e) => debugPrint('dialServer: $e')),
    );
    return;
  }
  // A pick made while the checklist runs replaces that run.
  if (flow.isBusy) flow.cancel();
  final picked = server.isDedicated ? null : server;
  // Looked for now, while the device's own doors are checked, so that a
  // fetch the fallback may need has all of that time to arrive, and the
  // fallback waits only for what is left of it.
  final sharedReady = _lookForShared(servers);
  await flow.connect(
    paths,
    preferred: _pickedOwn(server, dedicated),
    // What the card names now. A move the flow makes is compared with it,
    // so a retry that lands back on the first server moves the card too.
    selection: () => dedicated.selectedServer,
    picked: picked,
    // A link the fallback chose, not the user: our own doors get a look
    // beside it first.
    ownFirst: picked != null && servers.chosenByFallback,
    shared: () async {
      await sharedReady;
      return sharedFallback(servers);
    },
    // Where the tap landed, not a pick: the next tap keeps the backend's
    // door order (see _pickedOwn).
    onSwitchedServer: (s) => dedicated.select(s, byUser: false),
    // The tunnel is on a shared link now, so the card names it and the
    // next tap tries it first, as if the user had picked it, after a look
    // at our own doors.
    onShared: (s) => servers.selectServer(s, byFallback: true),
    allowanceSpent: () => askAllowance(vpn, dedicated),
    // A new list and this device's servers again, before each try after
    // nothing was open, and the doors as they then stand.
    beforeRetry: () => _beforeRetry(vpn, dedicated, servers),
    latest: () => dedicated.isBlocked ? const <Server>[] : dedicated.paths,
    afterStall: afterStall,
  );
  // The pick failed and one of ours carried the tunnel, so the next tap
  // goes straight to ours instead of dialling the dead link again.
  if (picked != null &&
      flow.stage == ConnectStage.done &&
      (flow.chosen?.isDedicated ?? false)) {
    servers.clearChoice();
  }
}

/// The server of this device's own whose doors a tap tries first, or null
/// to keep the backend's door order.
///
/// Only one the user chose: picked on the servers screen or from the error
/// bar's offer ([DedicatedState.selectedByUser]), or passed to [dialServer]
/// as a server other than the one selected. A server the connect flow
/// moved the selection to is only where an earlier tap landed, maybe on
/// another network. With its doors first, every one of them was checked
/// before any other server's door, the ones the backend ranks bad for the
/// carrier included. Taps then started on servers whose IPv4 addresses
/// rarely passed on the phone's carrier while another server's mostly did,
/// and some of them failed.
///
/// For a shared link [server], the server of this device's own behind it
/// is the selection, and it counts only when the user picked it.
Server? _pickedOwn(Server server, DedicatedState dedicated) {
  final selected = dedicated.selectedServer;
  final byUser = dedicated.selectedByUser;
  if (!server.isDedicated) return byUser ? selected : null;
  if (selected == null || !server.sameServerAs(selected)) return server;
  return byUser ? server : null;
}

/// The shared links the connect flow falls back on when none of this
/// device's own doors carry a tunnel.
///
/// The official ones first, since we run them. Then the community links in
/// the backend's order, and the ones whose test on this phone failed last.
///
/// The backend's order is for the phone's carrier: links a phone on it got
/// through most recently first. This phone's own test results used to go
/// before it, fastest first, but a result can be hours old. A link another
/// phone on the same carrier got through lately passes a fallback check
/// far more often than one with no recent success, and most checks were of
/// the second kind. The phone's results reach the backend as community
/// checks, so the backend's order already counts them.
@visibleForTesting
List<Server> sharedFallback(ServerState servers) {
  final community = servers.communityServers;
  bool failed(Server s) => (servers.getPingResult(s.id) ?? 1) <= 0;
  return [
    ...servers.officialServers,
    ...community.where((s) => !failed(s)),
    ...community.where(failed),
  ];
}

/// What a tap that keeps searching does before each new try: a new public
/// list, and this device's own servers asked for again, both at once and
/// each within a bounded wait.
///
/// The servers too since 1.9.0. A tap can keep searching for hours, and
/// in that time the backend can move a blocked server to a new address;
/// a try that dialled the old doors would never find it. A phone that
/// cannot reach the backend gives up on them after [ownServersWait].
Future<void> _beforeRetry(
  VpnService vpn,
  DedicatedState dedicated,
  ServerState servers,
) async {
  Future<void> own() async {
    try {
      await refreshAllowance(
        vpn: vpn,
        dedicated: dedicated,
      ).timeout(ownServersWait, onTimeout: () {});
    } catch (e) {
      debugPrint('dialServer: could not ask for the servers again: $e');
    }
  }

  await Future.wait([own(), _lookForShared(servers, refresh: true)]);
}

/// Look for the public list: the one in memory, else the one saved on the
/// phone, else one fetch with a bounded wait. With [refresh], a fetch
/// whatever the list in memory. See [ServerState.communityForFallback].
///
/// Started when the tap starts and not awaited until every own door has
/// failed, so it must never complete with an error.
Future<void> _lookForShared(ServerState servers, {bool refresh = false}) async {
  try {
    await servers.communityForFallback(refresh: refresh);
  } catch (e) {
    debugPrint('dialServer: could not look for the public list: $e');
  }
}

/// Whether the backend now says this device has used up its allowance.
///
/// The connect flow asks when this device's own servers fail. The answer
/// on screen is the one from launch, and an allowance can run out in the
/// middle of a session. A tunnel the allowance no longer covers is taken
/// down, because nothing meters a shared link the user may be on.
///
/// Throws [AllowanceUnanswered] when the request got no answer to read the
/// allowance from and the one in memory is not spent, so the flow asks
/// again at its next check rather than taking that as a no for the whole
/// try (ConnectFlow._spent). The refresh itself never throws: it keeps
/// the error for the screen (DedicatedState.lastRefreshErred).
@visibleForTesting
Future<bool> askAllowance(VpnService vpn, DedicatedState dedicated) async {
  // The backend orders the doors for the network the request came from,
  // which it can only tell when the request went around the tunnel. On
  // Android this app is excluded from its own tunnel, so that is always;
  // on iOS only while disconnected.
  await dedicated.refresh(
    viaTunnel: Platform.isAndroid ? false : vpn.isConnected,
  );
  if (dedicated.isBlocked) {
    if (vpn.isConnected || vpn.isConnecting) vpn.disconnect();
    return true;
  }
  if (dedicated.lastRefreshErred) throw const AllowanceUnanswered();
  return false;
}

/// The backend gave no answer to read the allowance from ([askAllowance]).
class AllowanceUnanswered implements Exception {
  const AllowanceUnanswered();

  @override
  String toString() => 'AllowanceUnanswered: no answer about the allowance';
}
