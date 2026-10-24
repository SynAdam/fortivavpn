import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';

void main() {
  test('classifies socket errors the way the backend expects', () {
    String c(int code, String msg) => ConnectDiagnostics.classifySocketError(
      SocketException(msg, osError: OSError(msg, code)),
    );
    expect(c(104, 'Connection reset by peer'), 'reset');
    expect(c(111, 'Connection refused'), 'refused');
    expect(c(113, 'No route to host'), 'unreachable');
    expect(c(110, 'Connection timed out'), 'timeout');
    expect(c(1, 'something else'), 'fail');
  });

  test('reads Windows socket errors by number, whatever the language', () {
    String c(int code) => ConnectDiagnostics.classifySocketError(
      // Persian Windows words these in Persian, so no word can be matched.
      SocketException('x', osError: OSError('خطا', code)),
    );
    expect(c(10054), 'reset');
    expect(c(10061), 'refused');
    expect(c(10051), 'unreachable');
    expect(c(10065), 'unreachable');
    expect(c(10060), 'timeout');
  });

  test('a handshake cut mid-way reads as reset', () {
    expect(
      ConnectDiagnostics.classifyTlsError(
        HandshakeException('Connection reset by peer'),
      ),
      'reset',
    );
    expect(
      ConnectDiagnostics.classifyTlsError(
        HandshakeException('CERTIFICATE_VERIFY_FAILED'),
      ),
      'handshake',
    );
  });

  test('ip literals skip dns', () async {
    final d = ConnectDiagnostics();
    expect(await d.dnsCheck('198.51.100.202'), {'dns': 'skipped'});
    expect(ConnectDiagnostics.isIpLiteral('2001:db8:f21::1'), isTrue);
    expect(ConnectDiagnostics.isIpLiteral('example.com'), isFalse);
  });

  test(
    'collect without a host runs only the control and platform parts',
    () async {
      final d = ConnectDiagnostics();
      final out = await d.collect(host: null);
      expect(out.containsKey('tcp'), isFalse);
      expect(out.containsKey('dns'), isFalse);
      expect(out['control'], anyOf('ok', 'fail'));
      expect(out['diag_ms'], isA<int>());
    },
  );
}
