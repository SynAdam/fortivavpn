import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/services/failure_verdict.dart';

/// The app now tells the user what the diagnosis found instead of "Server
/// not working, try another". These are the rules behind that sentence,
/// and they are the backend's own rules, so the screen and our monitoring
/// cannot disagree about the same failure.
void main() {
  group('reading a diagnosis', () {
    test('a failed control fetch is the phone, not us', () {
      expect(
        verdictFor(diag: {'control': 'fail', 'tcp': 'timeout'}),
        FailureVerdict.noInternet,
      );
    });

    test('a failed control fetch with a site inside the country reached is '
        'a cut way abroad, still not us', () {
      expect(
        verdictFor(
          diag: {'control': 'fail', 'control_home': 'ok', 'tcp': 'timeout'},
        ),
        FailureVerdict.cutOff,
      );
      expect(
        verdictFor(diag: {'control': 'fail', 'control_home': 'fail'}),
        FailureVerdict.noInternet,
      );
      // The phone's connection works, so "check your internet" is wrong.
      expect(actionFor(FailureVerdict.cutOff), FailureAction.none);
    });

    test('no internet outranks every other check', () {
      // Every probe below would otherwise read as a block. A phone with no
      // internet cannot have measured any of them meaningfully.
      expect(
        verdictFor(
          diag: {
            'control': 'fail',
            'dns': 'timeout',
            'tcp': 'timeout',
            'tls': 'skipped',
          },
        ),
        FailureVerdict.noInternet,
      );
    });

    test('a missing VPN permission is read before the probes', () {
      // The probes run outside the tunnel: they can all pass and still say
      // nothing about why the platform would not start the VPN.
      expect(
        verdictFor(
          diag: {
            'control': 'ok',
            'vpn_permission': false,
            'dns': 'ok',
            'tcp': 'ok',
            'tls': 'ok',
          },
        ),
        FailureVerdict.needsPermission,
      );
    });

    test('an always-on VPN is read out of the error text', () {
      expect(
        verdictFor(
          diag: {'control': 'ok'},
          error: 'Another app is set as always-on VPN',
        ),
        FailureVerdict.needsPermission,
      );
      expect(
        verdictFor(diag: {'control': 'ok'}, error: 'VPN permission denied'),
        FailureVerdict.needsPermission,
      );
    });

    test('TCP timing out on a working network is an unreachable server', () {
      expect(
        verdictFor(
          diag: {
            'control': 'ok',
            'dns': 'ok',
            'tcp': 'timeout',
            'tls': 'skipped',
          },
        ),
        FailureVerdict.serverUnreachable,
      );
    });

    test('a server dialled by address has no name to resolve', () {
      // dns "skipped" is not a failure: it means the link carried an IP.
      expect(
        verdictFor(
          diag: {
            'control': 'ok',
            'dns': 'skipped',
            'tcp': 'timeout',
            'tls': 'skipped',
          },
        ),
        FailureVerdict.serverUnreachable,
      );
    });

    test('a cut handshake is filtering', () {
      for (final tls in ['reset', 'timeout']) {
        expect(
          verdictFor(
            diag: {'control': 'ok', 'dns': 'ok', 'tcp': 'ok', 'tls': tls},
          ),
          FailureVerdict.blockedTls,
          reason: 'tls: $tls',
        );
      }
    });

    test('every probe passing and no traffic is throttling', () {
      expect(
        verdictFor(
          diag: {'control': 'ok', 'dns': 'ok', 'tcp': 'ok', 'tls': 'ok'},
        ),
        FailureVerdict.throttled,
      );
    });

    test('a refused handshake is not called filtering', () {
      // "handshake" is a certificate or protocol disagreement, which is
      // our own misconfiguration and not a censor. Claiming filtering
      // there would send the user to try servers that will all fail.
      expect(
        verdictFor(
          diag: {'control': 'ok', 'dns': 'ok', 'tcp': 'ok', 'tls': 'handshake'},
        ),
        FailureVerdict.unknown,
      );
    });

    test('a DNS failure is not guessed at', () {
      expect(
        verdictFor(
          diag: {
            'control': 'ok',
            'dns': 'timeout',
            'tcp': 'timeout',
            'tls': 'skipped',
          },
        ),
        FailureVerdict.unknown,
      );
    });

    test('no diagnosis means no sentence, rather than a wrong one', () {
      expect(verdictFor(diag: null), isNull);
      expect(verdictFor(diag: const {}), isNull);
      expect(verdictFor(diag: const {}, error: 'Unexpected error'), isNull);
    });

    test('a diagnosis that never reached the control is unknown', () {
      // Collected but incomplete: something to say, but not which of the
      // causes it was.
      expect(
        verdictFor(diag: {'carrier': 'Irancell', 'network': 'mobile'}),
        FailureVerdict.unknown,
      );
    });
  });

  group('where the app deliberately differs from the backend', () {
    // The backend needs a fresh panel reading before it will call either
    // of these anything. The app has no panel, so it would say "unknown"
    // on every real failure if it copied that condition. Both sentences
    // below are true from the probes alone: neither claims the server is
    // up, only that the phone could not reach it or could not use it.
    test('an unreachable server is named without a panel reading', () {
      expect(
        verdictFor(
          diag: {
            'control': 'ok',
            'dns': 'ok',
            'tcp': 'timeout',
            'tls': 'skipped',
          },
        ),
        FailureVerdict.serverUnreachable,
      );
    });

    test('throttling is named without a panel reading', () {
      expect(
        verdictFor(
          diag: {'control': 'ok', 'dns': 'ok', 'tcp': 'ok', 'tls': 'ok'},
        ),
        FailureVerdict.throttled,
      );
    });

    test('blocked and down are one sentence, because the advice is one', () {
      // The backend splits these on the panel: blocked_ip when the server
      // is up, server_down when it is not. The user does the same thing
      // either way, so the app does not pretend to know which.
      expect(
        verdictFor(
          diag: {
            'control': 'ok',
            'dns': 'ok',
            'tcp': 'timeout',
            'tls': 'skipped',
          },
        ),
        FailureVerdict.serverUnreachable,
      );
      expect(
        actionFor(FailureVerdict.serverUnreachable),
        FailureAction.tryAnotherServer,
      );
    });
  });

  group('the action that fits', () {
    test('each verdict leads somewhere the user can act', () {
      expect(actionFor(FailureVerdict.noInternet), FailureAction.checkInternet);
      expect(
        actionFor(FailureVerdict.needsPermission),
        FailureAction.openVpnSettings,
      );
      expect(
        actionFor(FailureVerdict.serverUnreachable),
        FailureAction.tryAnotherServer,
      );
      expect(
        actionFor(FailureVerdict.blockedTls),
        FailureAction.tryAnotherServer,
      );
      expect(
        actionFor(FailureVerdict.throttled),
        FailureAction.tryAnotherServer,
      );
      expect(actionFor(FailureVerdict.unknown), FailureAction.none);
    });

    test('every verdict has an action, so none can be added silently', () {
      for (final v in FailureVerdict.values) {
        expect(() => actionFor(v), returnsNormally, reason: v.name);
      }
    });
  });
}
