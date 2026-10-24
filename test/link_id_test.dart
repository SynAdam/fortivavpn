import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/utils/link_id.dart';

/// The lid names one shared link in a report, and the backend computes the
/// same value from the list it serves. The two only meet if both hash the
/// same bytes, so the vector below is fixed: SHA-256 of
/// "vless://a@b:1?x=1" starts 5084e78b9eb4.
void main() {
  test('the fixed vector', () {
    expect(LinkId.of('vless://a@b:1?x=1'), '5084e78b9eb4');
  });

  test('the label after # is not part of it', () {
    expect(LinkId.of('vless://a@b:1?x=1#name'), '5084e78b9eb4');
    expect(LinkId.of('vless://a@b:1?x=1#'), '5084e78b9eb4');
    expect(LinkId.of('vless://a@b:1?x=1#a#b'), '5084e78b9eb4');
  });

  test('whitespace around the link is not part of it', () {
    expect(LinkId.of('  vless://a@b:1?x=1\n'), '5084e78b9eb4');
    expect(LinkId.of('vless://a@b:1?x=1 #name'), '5084e78b9eb4');
  });

  test('twelve lower-case hex characters', () {
    for (final link in [
      'vless://a@b:1?x=1',
      'vmess://eyJhZGQiOiIxLjIuMy40In0=',
      'trojan://PW@HOST:443',
    ]) {
      expect(LinkId.of(link), matches(RegExp(r'^[0-9a-f]{12}$')));
    }
  });

  test('any other byte makes another link', () {
    expect(LinkId.of('vless://a@b:1?x=2'), isNot('5084e78b9eb4'));
    expect(LinkId.of('VLESS://a@b:1?x=1'), isNot('5084e78b9eb4'));
    expect(
      LinkId.of('vless://a@b:1?x=1&y=2'),
      isNot(LinkId.of('vless://a@b:1?x=1&y=3')),
    );
  });

  test('the same answer every time it is asked', () {
    const link = 'ss://YWVzLTEyOC1nY206cHc@1.2.3.4:8388#a';
    expect(LinkId.of(link), LinkId.of(link));
  });
}
