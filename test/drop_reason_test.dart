import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';

void main() {
  test('a bare status has no reason', () {
    expect(splitNativeStatus('connected'), (status: 'connected', reason: null));
    expect(splitNativeStatus('disconnected'), (
      status: 'disconnected',
      reason: null,
    ));
  });

  test('a teardown Android could explain carries its reason', () {
    for (final reason in const [
      'revoked',
      'replaced',
      'killed',
      'network_lost',
    ]) {
      expect(splitNativeStatus('disconnected:$reason'), (
        status: 'disconnected',
        reason: reason,
      ));
    }
  });

  test('the status still parses when the reason is empty or padded', () {
    expect(splitNativeStatus('disconnected:'), (
      status: 'disconnected',
      reason: null,
    ));
    expect(splitNativeStatus('  DISCONNECTED : Killed '), (
      status: 'disconnected',
      reason: 'killed',
    ));
  });
}
