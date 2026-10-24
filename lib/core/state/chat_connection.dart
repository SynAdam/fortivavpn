import '../../services/vpn_service.dart';
import 'connect_flow.dart';

// What a support chat message says about the connection. main.dart hands
// these to SupportState as its `connected` and `searching`.

/// Whether a message says the phone is connected: the tunnel is up, its
/// traffic check has passed, and it has not been found carrying nothing
/// (VpnService.stalled).
///
/// The backend reads `connected` before `searching`. Found in review on
/// 2026-10-24: a tunnel found dead stays up while StallRecovery looks for
/// another door, so a message sent then said connected, while the home
/// screen said the app was looking for another way. Users often write to
/// the chat at exactly that moment.
bool chatConnected(VpnService vpn) =>
    vpn.isConnected && !vpn.isVerifying && !vpn.stalled;

/// Whether a message says the app is still looking for a way in: the
/// connect button's work (ConnectFlow.searching), a dial, a tunnel being
/// checked, or a tunnel found carrying nothing (VpnService.stalled).
///
/// A tunnel found dead stays up while StallRecovery first asks whether the
/// phone reaches a site abroad, before its search starts. Found in review
/// on 2026-10-24: a message sent then said not connected and not
/// searching, which the backend reads as off. So a tunnel that is up always
/// reads as connected or as searching.
bool chatSearching(VpnService vpn, ConnectFlow flow) =>
    flow.searching || vpn.isConnecting || vpn.isVerifying || vpn.stalled;
