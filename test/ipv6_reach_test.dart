import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/services/ipv6_reach.dart';
import 'package:fortiva_vpn/services/network_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the phone can dial an IPv6 address on its network. The standby
/// group leaves the IPv6 doors out when it cannot.
DoorReading v6(bool ok, [String? error]) =>
    (host: '2001:db8:f20::10', ok: ok, error: error);

DoorReading v4(bool ok, [String? error]) =>
    (host: '203.0.113.10', ok: ok, error: error);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(NetworkKeys.resetForTest);

  test('after an account deletion an old Wi-Fi key is not kept', () async {
    NetworkKeys.close();
    NetworkKeys.reopen();
    final reach = Ipv6Reach();
    await reach.learn('wifi:0123456789abcdef', [v6(true)]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(Ipv6Reach.storageKey), isNull);
    await reach.learn('mobile:IR-MCI', [v6(true)]);
    expect(prefs.getString(Ipv6Reach.storageKey), contains('mobile:IR-MCI'));
  });

  group('what door checks say', () {
    test('an IPv6 door that failed with no route: no IPv6', () {
      expect(
        Ipv6Reach.fromChecks([
          v6(false, 'tcp unreachable; dial tcp: network is unreachable'),
          v6(false, 'tcp unreachable'),
        ]),
        isFalse,
      );
    });

    test('an IPv6 door that carried data: IPv6', () {
      expect(Ipv6Reach.fromChecks([v6(true)]), isTrue);
    });

    test('a TCP connection that timed out still had a route', () {
      // A blocked address looks like this. The phone has IPv6; the door is
      // closed, which the core's own probes find out.
      expect(Ipv6Reach.fromChecks([v6(false, 'tcp timeout; EOF')]), isTrue);
      expect(
        Ipv6Reach.fromChecks([
          v6(false, 'tcp unreachable'),
          v6(false, 'tcp ok 80ms; EOF'),
        ]),
        isTrue,
      );
    });

    test('says nothing without an IPv6 door or a TCP outcome', () {
      expect(Ipv6Reach.fromChecks([v4(false, 'tcp unreachable')]), isNull);
      expect(Ipv6Reach.fromChecks([v6(false, 'no answer')]), isNull);
      expect(Ipv6Reach.fromChecks([v6(false)]), isNull);
      expect(Ipv6Reach.fromChecks(const []), isNull);
    });
  });

  group('the answer for a connect', () {
    test('the platform decides when it can tell', () async {
      final reach = Ipv6Reach(route: () async => true);
      await reach.learn('wifi', [v6(false, 'tcp unreachable')]);
      expect(await reach.usable('wifi'), isTrue);
      expect(await Ipv6Reach(route: () async => false).usable('wifi'), isFalse);
    });

    test('otherwise the last checks on this network do', () async {
      final reach = Ipv6Reach(route: () async => null);
      await reach.learn('wifi', [v6(false, 'tcp unreachable')]);
      expect(await reach.usable('wifi'), isFalse);
      expect(await reach.usable('mobile:Irancell'), isTrue);

      await reach.learn('wifi', [v6(true)]);
      expect(await reach.usable('wifi'), isTrue);
    });

    test('checks that say nothing keep the last reading', () async {
      final reach = Ipv6Reach(route: () async => null);
      await reach.learn('wifi', [v6(false, 'tcp unreachable')]);
      await reach.learn('wifi', [v4(true)]);
      expect(await reach.usable('wifi'), isFalse);
    });

    test('a reading older than a day is not trusted', () async {
      var now = DateTime.utc(2026, 10, 7, 12);
      final reach = Ipv6Reach(route: () async => null, now: () => now);
      await reach.learn('wifi', [v6(false, 'tcp unreachable')]);
      now = now.add(Ipv6Reach.fresh + const Duration(minutes: 1));
      expect(await reach.usable('wifi'), isTrue);
    });

    test('a platform read that throws counts as no answer', () async {
      final reach = Ipv6Reach(route: () async => throw StateError('no'));
      await reach.learn('wifi', [v6(false, 'tcp unreachable')]);
      expect(await reach.usable('wifi'), isFalse);
    });

    test('with nothing to go on, IPv6 doors stay in', () async {
      expect(await Ipv6Reach(route: () async => null).usable('wifi'), isTrue);
    });

    test('keeps a bounded number of networks, newest last', () async {
      final reach = Ipv6Reach(route: () async => null);
      for (var i = 0; i <= Ipv6Reach.maxNetworks; i++) {
        await reach.learn('mobile:carrier$i', [v6(false, 'tcp unreachable')]);
      }
      expect(await reach.usable('mobile:carrier0'), isTrue);
      expect(
        await reach.usable('mobile:carrier${Ipv6Reach.maxNetworks}'),
        isFalse,
      );
    });
  });
}
