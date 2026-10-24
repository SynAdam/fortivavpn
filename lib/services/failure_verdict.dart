/// What a failed connection's diagnosis says went wrong, decided on the
/// phone so the user can be told something better than "try another".
///
/// The rules are the backend's, minus the one input the app does not
/// have. The backend reads the panel to separate "this server is up and
/// your network cannot reach it" from "this server is down"; nothing in
/// the app knows a server's health, so those two arrive here as one
/// verdict. That costs the user nothing: the advice for both is to try a
/// different server. Only our own monitoring needs them apart, and it
/// reads the panel.
///
/// Deliberately pure, and deliberately not the same code path the report
/// takes. The event still carries the raw `diag` and the backend still
/// decides the verdict it stores; this only decides what to say on the
/// screen. A phone that guesses wrong shows the wrong sentence, which is
/// a bad screen, not a bad statistic.
library;

enum FailureVerdict {
  /// The control fetch failed: the phone has no working internet, and
  /// nothing about our servers is being measured.
  noInternet,

  /// The control fetch failed and a site inside the country answered
  /// (`control_home`): the phone's network is up and its way abroad is cut.
  /// Nothing about our servers is being measured here either.
  cutOff,

  /// The VPN permission is missing, or another VPN holds always-on.
  /// The network was never tried.
  needsPermission,

  /// TCP to the server timed out while the phone's internet works. The
  /// server is either blocked on this network or down.
  serverUnreachable,

  /// TCP opened and the TLS handshake was cut. The signature of a filter
  /// reading the handshake rather than a server that is merely off.
  blockedTls,

  /// Every probe passed and the tunnel still carried nothing.
  throttled,

  /// A diagnosis that fits none of the rows above.
  unknown,
}

/// A DNS result that does not itself explain a failure. `skipped` means
/// the server was dialled by address, so there was no name to resolve.
const _dnsOk = {'ok', 'skipped'};

/// A handshake that was cut rather than refused. Both are what a filter
/// reading TLS looks like from here.
const _tlsCut = {'reset', 'timeout'};

final _deviceError = RegExp(r'permission|always[- ]on', caseSensitive: false);

/// Read one failure's diagnosis.
///
/// Returns null when there is nothing to read: no diagnosis was collected,
/// so the screen keeps whatever plain message it already had rather than
/// inventing a cause.
///
/// [online] is whether our API answered the phone on its own network
/// during the tap (ApiClient.answeredSince), an input the backend does not
/// have yet. Our API is abroad, so the phone had internet and its way
/// abroad was open: a failed control fetch is then read neither as no
/// internet nor as a cut way abroad, and the probes are read as they are
/// after a control fetch that passed. In the 4 days to 2026-10-23, about
/// 10 to 25 taps a day ended at no internet on phones our API was
/// answering.
FailureVerdict? verdictFor({
  Map<String, dynamic>? diag,
  String? error,
  bool online = false,
}) {
  final d = diag ?? const <String, dynamic>{};
  final control = d['control'];

  // Ordered before the empty check: a phone with no internet is the one
  // thing worth saying even when every other probe was skipped.
  if (control == 'fail' && !online) {
    return d['control_home'] == 'ok'
        ? FailureVerdict.cutOff
        : FailureVerdict.noInternet;
  }

  // Ordered before the probes because the probes run outside the tunnel.
  // They can all pass and still say nothing about why the platform would
  // not start the VPN.
  if (d['vpn_permission'] == false || _deviceError.hasMatch(error ?? '')) {
    return FailureVerdict.needsPermission;
  }

  if (d.isEmpty) return null;
  if (control != 'ok' && !online) return FailureVerdict.unknown;

  final dnsOk = _dnsOk.contains(d['dns']);
  final tcp = d['tcp'];
  final tls = d['tls'];

  if (dnsOk && tcp == 'timeout' && tls == 'skipped') {
    return FailureVerdict.serverUnreachable;
  }
  if (dnsOk && tcp == 'ok') {
    if (_tlsCut.contains(tls)) return FailureVerdict.blockedTls;
    if (tls == 'ok') return FailureVerdict.throttled;
  }
  return FailureVerdict.unknown;
}

/// What the user can usefully do about [verdict].
enum FailureAction {
  /// Nothing the app can do: the phone's own connection is the problem.
  checkInternet,

  /// Send them to the system VPN settings.
  openVpnSettings,

  /// Move to a different server, which is the fix for every block we can
  /// see from here.
  tryAnotherServer,

  /// No advice worth giving.
  none,
}

FailureAction actionFor(FailureVerdict verdict) => switch (verdict) {
  FailureVerdict.noInternet => FailureAction.checkInternet,
  // The phone's own connection works, and nothing on it would help.
  FailureVerdict.cutOff => FailureAction.none,
  FailureVerdict.needsPermission => FailureAction.openVpnSettings,
  FailureVerdict.serverUnreachable => FailureAction.tryAnotherServer,
  FailureVerdict.blockedTls => FailureAction.tryAnotherServer,
  FailureVerdict.throttled => FailureAction.tryAnotherServer,
  FailureVerdict.unknown => FailureAction.none,
};
