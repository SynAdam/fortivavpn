import '../data/models/connection_info.dart';

/// What the power button and the light behind it show. The home screen
/// works it out from the same signals as the status line, so the button
/// and the words never disagree.
enum PowerFace {
  off,
  connecting,
  verifying,
  connected,
  stalled,
  failed,
  spent,
  disconnecting,
}

/// The face for a bare tunnel [status], for a PowerButton that is given no
/// face. A tunnel that is up but still being checked draws as busy, never as
/// connected: it is not known to work yet.
PowerFace powerFaceFor(VpnStatus status, {required bool isVerifying}) {
  if (status == VpnStatus.disconnecting) return PowerFace.disconnecting;
  if (status == VpnStatus.error) return PowerFace.failed;
  if (status == VpnStatus.connecting || isVerifying) {
    return PowerFace.connecting;
  }
  if (status == VpnStatus.connected) return PowerFace.connected;
  return PowerFace.off;
}
