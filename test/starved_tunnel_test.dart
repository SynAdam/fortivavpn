import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/failure_verdict.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tunnel that came up and carried nothing: what the service tells the
/// connect flow about it.
///
/// In the 24 hours to 10:15 Tehran on 2026-10-20, 28 of 44 such failures
/// had a diagnosis that found no internet, and 7 of those 28 had their
/// checks fail within 16 to 200 ms, while the tunnel may still have been
/// going down. The flow needs the verdict to end the tap at "no internet",
/// and the verdict has to be the failure's own.

/// A diagnosis that answers from [answers], one per call, and records
/// what the platform had said by then.
class _Diagnostics extends ConnectDiagnostics {
  _Diagnostics(this.answers, this.calls);

  final List<Map<String, dynamic>> answers;
  final List<String> calls;

  /// The platform calls made before each diagnosis started.
  final seenBefore = <List<String>>[];

  /// When set, a diagnosis waits for it.
  Completer<void>? hold;

  @override
  Future<Map<String, dynamic>> collect({
    String? host,
    int port = 443,
    String? sni,
  }) async {
    seenBefore.add(List.of(calls));
    final answer = answers.isEmpty ? <String, dynamic>{} : answers.removeAt(0);
    await hold?.future;
    return answer;
  }

  @override
  Future<Map<String, dynamic>> platformReport() async => const {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.vpn.fortivavpn/tunnel');
  const offline = {'control': 'fail', 'control_home': 'fail'};
  const blocked = {
    'control': 'ok',
    'dns': 'skipped',
    'tcp': 'timeout',
    'tls': 'skipped',
  };

  late List<String> calls;
  // What getStatus answers, call by call; "disconnected" once empty.
  late List<String> statuses;

  VpnService service(_Diagnostics diagnostics) => VpnService(
    events: VpnEventReporter(send: (_, _, _) async {}),
    diagnostics: diagnostics,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    statuses = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getStatus') {
            final status = statuses.isEmpty
                ? 'disconnected'
                : statuses.removeAt(0);
            calls.add('getStatus:$status');
            return status;
          }
          calls.add(call.method);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'the diagnosis waits until the platform says the tunnel is down',
    () async {
      statuses = ['connected', 'connected', 'connected'];
      final diagnostics = _Diagnostics([offline], calls);
      final vpn = service(diagnostics);

      await vpn.reportVerifyFailure('edge', null, 'nope');

      expect(diagnostics.seenBefore, hasLength(1));
      expect(diagnostics.seenBefore.single, [
        'disconnect',
        'getStatus:connected',
        'getStatus:connected',
        'getStatus:connected',
        'getStatus:disconnected',
      ]);
    },
  );

  test('a tunnel that will not say it is down holds the diagnosis for '
      'about two seconds, no more', () async {
    statuses = List.filled(100, 'connected');
    final diagnostics = _Diagnostics([offline], calls);
    final vpn = service(diagnostics);
    final clock = Stopwatch()..start();

    await vpn.reportVerifyFailure('edge', null, 'nope');

    expect(diagnostics.seenBefore, hasLength(1));
    expect(clock.elapsed, lessThan(const Duration(seconds: 4)));
    expect(clock.elapsed, greaterThan(const Duration(seconds: 2)));
  });

  test('after a failed check through the tunnel the service says so, and '
      'gives the diagnosis its verdict', () async {
    final vpn = service(_Diagnostics([offline], calls));

    vpn.debugFailVerification('Server not working, try another');

    expect(vpn.failedAfterUp, isTrue);
    expect(vpn.status, VpnStatus.error);
    expect(await vpn.failureSettled(), FailureVerdict.noInternet);
    expect(vpn.failureVerdict, FailureVerdict.noInternet);
  });

  test('a late diagnosis does not answer for a newer failure', () async {
    final diagnostics = _Diagnostics([offline, blocked], calls);
    final vpn = service(diagnostics);

    diagnostics.hold = Completer<void>();
    vpn.debugFailVerification('first');
    // The first failure's diagnosis is held; the second one starts.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final firstSettled = vpn.failureSettled();
    final firstHold = diagnostics.hold!;
    diagnostics.hold = null;
    vpn.debugFailVerification('second');
    final secondSettled = vpn.failureSettled();

    expect(
      await secondSettled.timeout(const Duration(seconds: 5)),
      FailureVerdict.serverUnreachable,
    );
    firstHold.complete();
    // Asked before the second failure, it waits for the first one's own.
    expect(
      await firstSettled.timeout(const Duration(seconds: 5)),
      FailureVerdict.noInternet,
    );
  });

  test('a failure that never comes back answers null after the wait', () async {
    final diagnostics = _Diagnostics([offline], calls)
      ..hold = Completer<void>();
    final vpn = service(diagnostics);

    vpn.debugFailVerification('nope');

    expect(
      await vpn.failureSettled(wait: const Duration(milliseconds: 50)),
      isNull,
    );
  });
}
