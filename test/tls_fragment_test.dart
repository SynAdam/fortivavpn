import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/utils/tls_fragment.dart';
import 'package:fortiva_vpn/utils/vless_link.dart';

// The CDN links Hamrah Aval and TCI reset by server name in September 2026.
const cdn =
    'vless://00000000-0000-4000-8000-000000000000@198.51.100.215:443'
    '?encryption=none&security=tls&sni=files.example.site&type=ws'
    '&host=files.example.site&path=%2F4138&fp=chrome#Fortiva%20DE';
const reality =
    'vless://00000000-0000-4000-8000-000000000000@198.51.100.209:443'
    '?security=reality&sni=www.example.com&type=xhttp&pbk=abc&sid=01#Fortiva';
const spec = 'tlshello,10-20,10-20';

void main() {
  test('a TLS link on Android carries the fragment before its remark', () {
    final got = TlsFragment.apply(cdn, spec: spec, android: true);
    expect(got, endsWith('&fragment=tlshello,10-20,10-20#Fortiva%20DE'));
    expect(VlessLink.param(got, 'fragment'), spec);
  });

  test('the fragment lands in the strategy the reports record', () {
    final got = TlsFragment.apply(cdn, spec: spec, android: true);
    expect(VlessLink.strategy(got)['fragment'], spec);
    expect(VlessLink.strategy(cdn).containsKey('fragment'), isFalse);
  });

  test('everything else in the link is kept', () {
    final got = TlsFragment.apply(cdn, spec: spec, android: true);
    expect(got.replaceFirst('&fragment=$spec', ''), cdn);
  });

  test('a Reality link is left alone', () {
    expect(TlsFragment.apply(reality, spec: spec, android: true), reality);
  });

  test('iOS is left alone: its core does not read the parameter', () {
    expect(TlsFragment.apply(cdn, spec: spec, android: false), cdn);
  });

  test('off, or a spec the core would not accept, leaves the link alone', () {
    for (final s in [
      '',
      'tlshello',
      '1-3,10-20,10-20',
      'tlshello,10-20,x',
      'tlshello,10-20,10-20;rm',
    ]) {
      expect(TlsFragment.apply(cdn, spec: s, android: true), cdn, reason: s);
    }
  });

  test('a spec whose length reaches 0 leaves the link alone', () {
    // The core refuses it ("LengthMin can't be 0") after putting the two
    // ends in order, so both ends are checked.
    for (final s in [
      'tlshello,0-20,1-2',
      'tlshello,20-0,1-2',
      'tlshello,0,0',
      'tlshello,0000,1-2',
    ]) {
      expect(TlsFragment.apply(cdn, spec: s, android: true), cdn, reason: s);
      expect(TlsFragment.usable(s), isFalse, reason: s);
    }
  });

  test('a gap of 0 is fine, and so is any length from 1', () {
    for (final s in [
      'tlshello,1-20,0',
      'tlshello,10-20,1-2',
      ' tlshello,5,9 ',
    ]) {
      expect(TlsFragment.usable(s), isTrue, reason: s);
    }
    expect(
      VlessLink.param(
        TlsFragment.apply(cdn, spec: 'tlshello,1-20,0', android: true),
        'fragment',
      ),
      'tlshello,1-20,0',
    );
  });

  test('a link that names its own fragment keeps it', () {
    final own = cdn.replaceFirst('#', '&fragment=tlshello,1-3,1-2#');
    expect(TlsFragment.apply(own, spec: spec, android: true), own);
  });

  test('an Encrypted Client Hello link is never split', () {
    final ech = cdn.replaceFirst('#', '&ech=${TlsFragment.echConfig}#');
    expect(TlsFragment.apply(ech, spec: spec, android: true), ech);
  });

  test('a test point writes ECH as ech plus no split', () {
    final ech = TlsFragment.withSpec(cdn, TlsFragment.echSpec);
    expect(ech, contains('ech=cloudflare-ech.com%2Budp%3A%2F%2F1.1.1.1'));
    expect(ech, contains('fragment=off'));
    // Switching back to a split drops neither param it should keep.
    final split = TlsFragment.withSpec(ech, 'tlshello,1-2,3-4');
    expect(split, contains('fragment=tlshello,1-2,3-4'));
    expect(split, isNot(contains('fragment=off')));
  });

  test('the strategy reports the ECH setting', () {
    final ech = cdn.replaceFirst('#', '&ech=${TlsFragment.echConfig}#');
    expect(VlessLink.strategy(ech), containsPair('ech', isNotEmpty));
  });

  test('a link with a finalmask is never split', () {
    final ff = cdn.replaceFirst('#', '&fm=${TlsFragment.ffMask}#');
    expect(TlsFragment.apply(ff, spec: spec, android: true), ff);
  });

  test('a test point writes F&F as mask, suites, unsafe and no split', () {
    final ff = TlsFragment.withSpec(cdn, TlsFragment.ffSpec);
    expect(VlessLink.param(ff, 'fp'), 'unsafe');
    expect(VlessLink.param(ff, 'fragment'), 'off');
    expect(VlessLink.param(ff, 'fm'), startsWith('{"tcp":[{"type":"fragment"'));
    expect(VlessLink.param(ff, 'cs')!.split(':'), hasLength(13));
    // The link's own fingerprint is replaced, not doubled.
    expect('&$ff'.split('fp=').length, 2);
    // Everything else in the link is kept.
    expect(VlessLink.param(ff, 'sni'), 'files.example.site');
    expect(ff, endsWith('#Fortiva%20DE'));
  });

  test('the strategy reports the F&F settings', () {
    final ff = TlsFragment.withSpec(cdn, TlsFragment.ffSpec);
    final strategy = VlessLink.strategy(ff);
    expect(strategy, containsPair('fm', isNotEmpty));
    expect(strategy, containsPair('cs', isNotEmpty));
    expect(strategy, containsPair('fp', 'unsafe'));
  });

  test('the remote flag is read from the config, off when absent', () {
    expect(FeatureFlags.fromJson({}).tlsFragment, '');
    expect(FeatureFlags.fromJson({'tls_fragment': spec}).tlsFragment, spec);
    expect(
      FeatureFlags.fromJson({'tls_fragment': spec}).toJson()['tls_fragment'],
      spec,
    );
  });
}
