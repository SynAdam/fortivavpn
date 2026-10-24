import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../services/stall_watch.dart';
import '../../services/vpn_service.dart';
import 'connect_flow.dart';

/// Looks for another way in when the tunnel stops carrying data, without a
/// tap (NimusAI/fortiva-vpn-clients#289).
///
/// [VpnService] finds the dead tunnel and files the drop ([StallWatch]).
/// This then does what the user would have done: forgets the dead door as
/// the one to try first on this network, and runs the search the connect
/// button runs ([redial], dialServer with `afterStall`). The dead tunnel
/// stays up while the doors are checked: on Android the app is left out of
/// its own tunnel, so the checks reach them around it, and the core's
/// service keeps running for the door that replaces it. A door found open
/// replaces the tunnel. When none is, the dead tunnel is taken down, so the
/// phone and the screen say what is true while the search keeps trying
/// (ConnectFlow's retries).
///
/// It also asks the service to look whenever the app comes to the front
/// with a tunnel up ([VpnService.checkStall]).
///
/// A tunnel also stops carrying data when the phone's own internet goes
/// away: in the 72 hours to 2026-10-20 21:00 UTC, 248 of 493 dead tunnels
/// were found on a phone whose control fetch reached nothing. Then the
/// door is not at fault. So the phone's way abroad is asked first
/// ([ConnectFlow.reachesAbroad]): with it, the dead door is forgotten as
/// before; without it, the door is kept as the one to dial first once the
/// internet is back, and the search skips the fast path
/// ([ConnectFlow.noteOffline]). That search then ends at no internet, and
/// its wait asks for the way back every RetrySettings.recheck and tries at
/// once when it is back. Until 2.2.0 the door was forgotten either way,
/// and those phones were connected again a median of 15 minutes later.
///
/// A tunnel the stall watch found throttled rather than dead
/// (StallWatch.triggerThrottle) is left up, its door is not marked failed,
/// and no search runs, while a check finds its door open and no door
/// faster ([moveIfFaster]). On 2026-10-23 the throttle trigger ended 106
/// sessions on 72 phones, and the next session carried about half as much
/// whether it moved to another door or not. When a check of this
/// connect's doors finds one faster (ConnectFlow.checkThrottled), the
/// tunnel moves, as a dead one does, with that door dialled first. When
/// its door is not shown open, it is left as a dead one is, and the search
/// runs in full, as builds up to 2.2.0 do.
class StallRecovery with WidgetsBindingObserver {
  StallRecovery({
    required VpnService vpn,
    required ConnectFlow flow,
    required this.redial,
    bool watchApp = true,
  }) : _vpn = vpn,
       _flow = flow,
       _watchApp = watchApp {
    vpn.onStall = _onStall;
    vpn.onThrottle = _onThrottle;
    if (watchApp) WidgetsBinding.instance.addObserver(this);
  }

  final VpnService _vpn;
  final ConnectFlow _flow;
  final bool _watchApp;

  /// Runs the connect button's search through the doors as they stand.
  final Future<void> Function() redial;

  bool _running = false;

  /// Whether a recovery is under way.
  bool get running => _running;

  void _onStall() => unawaited(recover());

  void _onThrottle(StallFinding finding) => unawaited(moveIfFaster(finding));

  /// After the stall watch found the tunnel throttled: check this
  /// connect's doors beside the one in use (ConnectFlow.checkThrottled).
  /// The finding was reported already.
  ///
  /// The tunnel stays when its door checks open and no door checks faster.
  /// A move to a faster door puts that door first on this network
  /// (ConnectFlow.preferDoor). For a move, and when the door in use is not
  /// shown open, the tunnel is left as a dead one is
  /// (VpnService.leaveThrottled): the drop is filed, the door in use is
  /// marked failed, and the search runs ([recover]), which dials a door
  /// put first before the others. Without that, a phone whose doors are
  /// all closed to a new connection stays on a tunnel that opens nothing
  /// new while its old connections keep it above the dead tunnel's line.
  ///
  /// A tunnel the watch found dead while the doors were checked is
  /// recovered here: [recover] returned at once then, because this held
  /// it, and the watch tells once per tunnel.
  Future<void> moveIfFaster(StallFinding finding) async {
    bool usable() =>
        _vpn.isConnected && !_vpn.isVerifying && !_vpn.stalled && !_flow.isBusy;
    if (_running || !usable()) return;
    _running = true;
    final dialled = _vpn.activeDoorKey;
    // Not shown open, unless the check says so.
    ThrottleCheck check = (step: ThrottleStep.leave, door: null);
    try {
      check = await _flow.checkThrottled();
      final door = check.door;
      if (door != null && usable() && _vpn.activeDoorKey == dialled) {
        await _flow.preferDoor(door);
      }
    } catch (e) {
      debugPrint('StallRecovery: $e');
    } finally {
      _running = false;
    }
    if (_vpn.stalled) return recover();
    // The user stopped the tunnel, picked another server, or tapped, or the
    // core moved to another door, while the doors were checked.
    if (check.step == ThrottleStep.stay ||
        !usable() ||
        _vpn.activeDoorKey != dialled) {
      return;
    }
    _vpn.leaveThrottled(finding);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_vpn.isConnected || _vpn.isVerifying) return;
    unawaited(_vpn.checkStall());
  }

  /// Look for another door for the dead tunnel.
  Future<void> recover() async {
    if (_running || !_vpn.stalled) return;
    // A tap, a pick or a retry is under way, and it looks already.
    if (_flow.isBusy) return;
    _running = true;
    try {
      // Read first: the search below replaces the tunnel and its doors.
      final dead = _vpn.activeDoorKey;
      final online = await _flow.reachesAbroad();
      // The user stopped the tunnel, picked another server, or tapped,
      // while the phone's way abroad was asked.
      if (!_vpn.stalled || _flow.isBusy) return;
      if (!online) {
        _flow.noteOffline();
      } else if (dead != null) {
        await _flow.forgetStalledDoorKey(dead);
      }
      if (!_vpn.stalled) return;
      await redial();
      // Nothing opened on the first try, and the dead tunnel is still up.
      if (_vpn.stalled) await _vpn.dropStalled();
    } catch (e) {
      debugPrint('StallRecovery: $e');
    } finally {
      _running = false;
    }
  }

  void dispose() {
    if (_watchApp) WidgetsBinding.instance.removeObserver(this);
    if (_vpn.onStall == _onStall) _vpn.onStall = null;
    if (_vpn.onThrottle == _onThrottle) _vpn.onThrottle = null;
  }
}
