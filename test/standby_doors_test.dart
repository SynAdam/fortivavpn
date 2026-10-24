import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/ipv6_reach.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/ping_service.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/utils/standby_doors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Standby doors: which ones ride along with a connect, and what the flow
/// records when the core leaves the dialled door for one of them.
Server door(String host, String? door, {int? serverId}) => Server(
  id: door == null ? 'shared-$host' : 'dedicated-$host:443',
  name: host,
  country: '',
  city: host,
  connectionUri: 'vless://u@$host:443?type=tcp#$host',
  flagEmoji: '🌍',
  isDedicated: door != null,
  door: door,
  doorLabel: door,
  serverId: serverId,
);

/// One server's five doors as the backend hands them out from 2026-10-07:
/// the direct door at the server's IPv4 address, its "-b" copy at a second
/// IPv4 address, its "-v6" copy at the IPv6 address, and two Cloudflare
/// doors, both dialled at the one Cloudflare address.
class FiveDoors {
  FiveDoors(this.id, {required this.v4, required this.b, required this.v6})
    : name = 'server$id.example.site';

  final int id;
  final String v4, b, v6, name;

  static const _reality =
      'type=xhttp&security=reality&sni=www.samsung.com&pbk=KEYKEYKEYKEY'
      '&fp=chrome#Fortiva%20DE%20Nuremberg';

  Server _door(String door, String uri) => Server.fromDedicatedPath(
    uri: uri,
    door: door,
    doorLabel: door,
    serverId: id,
  );

  Server get direct => _door('xhttp-reality', 'vless://u@$v4:8443?$_reality');
  Server get second => _door('xhttp-reality-b', 'vless://u@$b:8443?$_reality');
  Server get ipv6 =>
      _door('xhttp-reality-v6', 'vless://u@[$v6]:8443?$_reality');
  Server get cdnWs => _door(
    'ws-tls',
    'vless://u@104.16.0.1:443?type=ws&security=tls&sni=$name&host=$name'
        '&path=%2Fws#Fortiva%20DE%20Nuremberg',
  );
  Server get cdnUpgrade => _door(
    'httpupgrade-tls',
    'vless://u@104.16.0.1:443?type=httpupgrade&security=tls&sni=$name'
        '&host=$name&path=%2Fup#Fortiva%20DE%20Nuremberg',
  );

  /// In the order the backend lists them on a carrier where the direct
  /// doors work.
  List<Server> get all => [direct, second, ipv6, cdnWs, cdnUpgrade];
}

final ten = FiveDoors(
  10,
  v4: '203.0.113.10',
  b: '203.0.113.20',
  v6: '2001:db8:f20::10',
);
final eleven = FiveDoors(
  11,
  v4: '198.51.100.11',
  b: '198.51.100.21',
  v6: '2001:db8:f20::11',
);

List<String> keys(List<Server> doors) => [for (final d in doors) d.pathKey];

/// A tunnel that always comes up, and reports being on [landsOn] when the
/// core was given that door to stand by.
class _FakeVpn extends VpnService {
  _FakeVpn({this.landsOn})
    : super(events: VpnEventReporter(send: (_, _, _) async {}));

  final Server? landsOn;
  final dialled = <String>[];
  final standbySent = <List<String>>[];
  Server? _active;
  VpnStatus _fakeStatus = VpnStatus.disconnected;

  @override
  VpnStatus get status => _fakeStatus;

  @override
  bool get isConnected => _fakeStatus == VpnStatus.connected;

  @override
  bool get isConnecting => _fakeStatus == VpnStatus.connecting;

  @override
  bool get isVerifying => false;

  @override
  Server? get activeDoor => _active;

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {
    dialled.add(server.pathKey);
    standbySent.add([for (final s in standby) s.pathKey]);
    _fakeStatus = VpnStatus.connecting;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 5));
    final moved =
        landsOn != null && standby.any((s) => s.pathKey == landsOn!.pathKey);
    _active = moved ? landsOn : server;
    _fakeStatus = VpnStatus.connected;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _fakeStatus = VpnStatus.disconnected;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final hel1 = door('hel', 'tcp-reality', serverId: 7);
  final hel2 = door('hel', 'xhttp-reality', serverId: 7);
  final hel3 = door('hel', 'ws-tls', serverId: 7);
  final fsn1 = door('fsn', 'tcp-reality', serverId: 8);
  final fsn2 = door('fsn', 'xhttp-reality', serverId: 8);
  final fsn3 = door('fsn', 'ws-tls', serverId: 8);
  final shared = door('friend', null);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StandbyDoors.enabled = true;
    StandbyDoors.androidOverride = true;
  });

  tearDown(() {
    StandbyDoors.enabled = false;
    StandbyDoors.androidOverride = null;
  });

  group('which doors stand by', () {
    test('none while the backend has not turned it on', () {
      StandbyDoors.enabled = false;
      expect(StandbyDoors.pick(hel1, [hel1, hel2, fsn1]), isEmpty);
    });

    test('none off Android, whose core is the one with the group', () {
      expect(
        StandbyDoors.pick(hel1, [hel1, hel2, fsn1], android: false),
        isEmpty,
      );
    });

    test('the same server first, then the rest in the given order', () {
      final picked = StandbyDoors.pick(fsn1, [hel1, hel2, fsn1, fsn2]);
      expect(
        [for (final p in picked) p.pathKey],
        [fsn2.pathKey, hel1.pathKey, hel2.pathKey],
      );
    });

    test('never the dialled door, and never the same door twice', () {
      final picked = StandbyDoors.pick(hel1, [hel1, hel2, hel2, hel1, fsn1]);
      expect([for (final p in picked) p.pathKey], [hel2.pathKey, fsn1.pathKey]);
    });

    test('no more than the limit', () {
      final picked = StandbyDoors.pick(hel1, [
        hel1,
        hel2,
        hel3,
        fsn1,
        fsn2,
        fsn3,
      ]);
      expect(picked, hasLength(StandbyDoors.max));
      expect(picked.first.pathKey, hel2.pathKey);
    });

    test('doors the tap found closed go after the others, on the same '
        'server and among the rest', () {
      final picked = StandbyDoors.pick(
        hel1,
        [hel1, hel2, hel3, fsn1, fsn2],
        closed: {hel2.pathKey, fsn1.pathKey},
      );
      expect(keys(picked), [
        hel3.pathKey,
        hel2.pathKey,
        fsn2.pathKey,
        fsn1.pathKey,
      ]);
    });

    test('a shared link gets none, and is never one', () {
      expect(StandbyDoors.pick(shared, [hel1, hel2]), isEmpty);
      final picked = StandbyDoors.pick(hel1, [hel1, shared, hel2]);
      expect([for (final p in picked) p.pathKey], [hel2.pathKey]);
    });
  });

  group('a server with five doors', () {
    final fleet = [...ten.all, ...eleven.all];

    test('the links are what the backend serves', () {
      expect(StandbyDoors.dialsIpv6(ten.ipv6), isTrue);
      expect(StandbyDoors.dialsIpv6(ten.second), isFalse);
      expect(StandbyDoors.dialsIpv6(ten.cdnWs), isFalse);
      expect(ten.second.sameServerAs(ten.direct), isTrue);
      expect(ten.ipv6.sameServerAs(ten.direct), isTrue);
      expect(ten.second.pathKey, isNot(ten.direct.pathKey));
    });

    test('with IPv6, three doors of the server and one of another', () {
      // Before: the four other doors of [ten] filled the group, and a
      // server that went down took the whole group with it.
      expect(keys(StandbyDoors.pick(ten.direct, fleet)), [
        ten.second.pathKey,
        ten.ipv6.pathKey,
        ten.cdnWs.pathKey,
        eleven.direct.pathKey,
      ]);
    });

    test('a door found closed gives its slot to one not checked', () {
      // [ten]'s second address was found closed: its slot goes to the
      // second Cloudflare door, and it keeps none of the three.
      expect(
        keys(
          StandbyDoors.pick(ten.direct, fleet, closed: {ten.second.pathKey}),
        ),
        [
          ten.ipv6.pathKey,
          ten.cdnWs.pathKey,
          ten.cdnUpgrade.pathKey,
          eleven.direct.pathKey,
        ],
      );
    });

    test('closed doors still fill slots that nothing else would', () {
      expect(
        keys(
          StandbyDoors.pick(
            ten.direct,
            ten.all,
            closed: {for (final d in ten.all) d.pathKey},
          ),
        ),
        [
          ten.second.pathKey,
          ten.ipv6.pathKey,
          ten.cdnWs.pathKey,
          ten.cdnUpgrade.pathKey,
        ],
      );
    });

    test('without IPv6, the IPv6 doors are left out', () {
      // TCI home wifi: the IPv6 door would fail every check with "tcp
      // unreachable". The second Cloudflare door takes its slot.
      expect(keys(StandbyDoors.pick(ten.direct, fleet, ipv6: false)), [
        ten.second.pathKey,
        ten.cdnWs.pathKey,
        ten.cdnUpgrade.pathKey,
        eleven.direct.pathKey,
      ]);
    });

    test('another server\'s IPv6 door is left out too', () {
      final picked = StandbyDoors.pick(ten.direct, [
        ...ten.all,
        eleven.ipv6,
        eleven.direct,
      ], ipv6: false);
      expect(picked.last.pathKey, eleven.direct.pathKey);
      expect(picked.where(StandbyDoors.dialsIpv6), isEmpty);
    });

    test('the second address comes first, wherever the backend lists it', () {
      // On a carrier where Cloudflare ranks first, the backend lists the
      // direct doors last. The same door at the server's other address
      // still stands by first.
      final picked = StandbyDoors.pick(ten.direct, [
        ten.cdnWs,
        ten.cdnUpgrade,
        ten.ipv6,
        ten.direct,
        ten.second,
        ...eleven.all,
      ]);
      expect(keys(picked), [
        ten.second.pathKey,
        ten.cdnWs.pathKey,
        ten.ipv6.pathKey,
        eleven.direct.pathKey,
      ]);
    });

    test('dialling the second address, the first one stands by first', () {
      expect(keys(StandbyDoors.pick(ten.second, fleet, ipv6: false)), [
        ten.direct.pathKey,
        ten.cdnWs.pathKey,
        ten.cdnUpgrade.pathKey,
        eleven.direct.pathKey,
      ]);
    });

    test('a door at a new address goes before one at a held address', () {
      // Two direct doors at the dialled address: a block of that address
      // takes both, so the Cloudflare door stands by before the other one.
      final tcp = door('203.0.113.10', 'tcp-reality', serverId: 10);
      final xhttp = door('203.0.113.10', 'xhttp-reality', serverId: 10);
      final picked = StandbyDoors.pick(xhttp, [xhttp, tcp, ten.cdnWs]);
      expect(keys(picked), [ten.cdnWs.pathKey, tcp.pathKey]);
    });

    test('with no other server, its own doors take every slot', () {
      expect(keys(StandbyDoors.pick(ten.direct, ten.all)), [
        ten.second.pathKey,
        ten.ipv6.pathKey,
        ten.cdnWs.pathKey,
        ten.cdnUpgrade.pathKey,
      ]);
    });

    test('a server with fewer doors leaves its slots to other servers', () {
      final picked = StandbyDoors.pick(hel1, [hel1, hel2, fsn1, fsn2, fsn3]);
      expect(keys(picked), [
        hel2.pathKey,
        fsn1.pathKey,
        fsn2.pathKey,
        fsn3.pathKey,
      ]);
    });
  });

  group('the remote config flag', () {
    test('is off when the backend does not send it', () {
      expect(FeatureFlags.fromJson(const {}).standbyDoors, isFalse);
    });

    test('is read and written under standby_doors', () {
      final flags = FeatureFlags.fromJson(const {'standby_doors': true});
      expect(flags.standbyDoors, isTrue);
      expect(flags.toJson()['standby_doors'], isTrue);
    });
  });

  group('the connect flow', () {
    ConnectFlow flow(
      _FakeVpn vpn,
      Map<String, int> open, {
      Future<bool?> Function()? route,
      Future<int> Function(Server)? probe,
    }) => ConnectFlow(
      vpn: vpn,
      memory: PathMemory(),
      ipv6: Ipv6Reach(route: route ?? () async => null),
      finder: PathFinder(
        probe: probe ?? (p) async => open[p.pathKey] ?? -1,
        internet: () async => true,
      ),
      reporter: VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, _, _) async {},
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.2',
        platform: 'android',
        networkType: () async => 'mobile',
      ),
      networkKey: () async => 'mobile:Irancell',
      carrier: () async => 'Irancell',
      attemptTimeout: const Duration(seconds: 2),
    );

    test('sends the other doors along with the one it dials', () async {
      final vpn = _FakeVpn();
      final f = flow(vpn, {hel1.pathKey: 150});

      await f.connect([hel1, hel2, fsn1]);

      expect(f.stage, ConnectStage.done);
      expect(vpn.dialled, [hel1.pathKey]);
      expect(vpn.standbySent.single, [hel2.pathKey, fsn1.pathKey]);
    });

    test('sends none while the flag is off', () async {
      StandbyDoors.enabled = false;
      final vpn = _FakeVpn();
      final f = flow(vpn, {hel1.pathKey: 150});

      await f.connect([hel1, hel2, fsn1]);

      expect(vpn.standbySent.single, isEmpty);
    });

    test('remembers the door the core moved to, not the dialled one', () async {
      final vpn = _FakeVpn(landsOn: hel2);
      final f = flow(vpn, {hel1.pathKey: 150});

      await f.connect([hel1, hel2, fsn1]);

      expect(f.stage, ConnectStage.done);
      expect(f.chosen?.pathKey, hel2.pathKey);
      final memory = PathMemory();
      expect(await memory.recall('mobile:Irancell'), hel2.pathKey);
    });

    test('leaves the IPv6 doors out on a network without IPv6', () async {
      final vpn = _FakeVpn();
      final f = flow(vpn, {ten.direct.pathKey: 150}, route: () async => false);

      await f.connect([...ten.all, ...eleven.all], preferred: ten.direct);

      expect(vpn.dialled, [ten.direct.pathKey]);
      expect(vpn.standbySent.single, [
        ten.second.pathKey,
        ten.cdnWs.pathKey,
        ten.cdnUpgrade.pathKey,
        eleven.direct.pathKey,
      ]);
    });

    test('holds the IPv6 door where the network has IPv6', () async {
      final vpn = _FakeVpn();
      final f = flow(vpn, {ten.direct.pathKey: 150}, route: () async => true);

      await f.connect([...ten.all, ...eleven.all], preferred: ten.direct);

      expect(vpn.standbySent.single, [
        ten.second.pathKey,
        ten.ipv6.pathKey,
        ten.cdnWs.pathKey,
        eleven.direct.pathKey,
      ]);
    });

    test('the doors its own checks found closed stand by last', () async {
      // The checklist found [ten]'s three direct doors closed and its
      // first Cloudflare door open. Until 2.2.0 those three closed doors
      // were the tunnel's spares, and the core had nowhere to go when the
      // Cloudflare door failed later in the session.
      final vpn = _FakeVpn();
      final f = flow(vpn, {ten.cdnWs.pathKey: 150}, route: () async => true);

      await f.connect([...ten.all, ...eleven.all]);

      expect(vpn.dialled, [ten.cdnWs.pathKey]);
      expect(vpn.standbySent.single, [
        ten.cdnUpgrade.pathKey,
        ten.direct.pathKey,
        ten.second.pathKey,
        eleven.direct.pathKey,
      ]);
    });

    test('a dial with no checks of its own keeps the order as it is', () async {
      // The fast path: the checklist's rows are an earlier tap's.
      final vpn = _FakeVpn();
      final f = flow(vpn, {ten.cdnWs.pathKey: 150}, route: () async => true);
      await f.connect([...ten.all, ...eleven.all]);
      f.reset();
      vpn.dialled.clear();
      vpn.standbySent.clear();
      await vpn.disconnect();

      await f.connect([...ten.all, ...eleven.all]);

      expect(vpn.dialled, [ten.cdnWs.pathKey]);
      expect(vpn.standbySent.single, [
        ten.direct.pathKey,
        ten.second.pathKey,
        ten.ipv6.pathKey,
        eleven.direct.pathKey,
      ]);
    });

    test('learns from its checks when the platform cannot tell', () async {
      // Windows, or an Android read that failed. The backend lists the
      // IPv6 door first, and its check fails at once: no route.
      Future<int> probe(Server p) async {
        if (StandbyDoors.dialsIpv6(p)) {
          throw const DoorCheckFailed('tcp unreachable; dial failed');
        }
        return p.pathKey == ten.direct.pathKey ? 150 : -1;
      }

      final paths = [ten.ipv6, ...ten.all, ...eleven.all];
      final vpn = _FakeVpn();
      await flow(vpn, const {}, probe: probe).connect(paths);

      expect(vpn.dialled, [ten.direct.pathKey]);
      expect(vpn.standbySent.single, [
        ten.second.pathKey,
        ten.cdnWs.pathKey,
        ten.cdnUpgrade.pathKey,
        eleven.direct.pathKey,
      ]);
      expect(await Ipv6Reach().usable('mobile:Irancell'), isFalse);
    });

    test('a move to the second address stays on the same server', () async {
      // The "-b" door has its own address and its own id, and the server
      // id says it is [ten]. The selection does not move.
      final vpn = _FakeVpn(landsOn: ten.second);
      final f = flow(vpn, {ten.direct.pathKey: 150});
      Server? switchedTo;

      await f.connect(
        [...ten.all, ...eleven.all],
        preferred: ten.direct,
        onSwitchedServer: (s) => switchedTo = s,
      );

      expect(f.chosen?.pathKey, ten.second.pathKey);
      expect(switchedTo, isNull);
    });

    test('tells the screen when the core moved to another server', () async {
      final vpn = _FakeVpn(landsOn: fsn1);
      final f = flow(vpn, {hel1.pathKey: 150});
      Server? switchedTo;

      await f.connect(
        [hel1, hel2, fsn1],
        preferred: hel1,
        onSwitchedServer: (s) => switchedTo = s,
      );

      expect(f.chosen?.pathKey, fsn1.pathKey);
      expect(switchedTo?.pathKey, fsn1.pathKey);
    });

    test('follows the core off the server the checklist landed on', () async {
      // The checklist lands on fsn, and the core leaves fsn for nbg while
      // connecting. Up to 1.7.0 the selection moved to fsn before the dial,
      // the move to nbg was compared with hel, the server the tap started
      // on, and the card kept naming fsn while the tunnel was on nbg. Since
      // 2026-10-12 the selection moves once, after the tunnel is up, to the
      // server the tunnel is on.
      final nbg1 = door('nbg', 'tcp-reality', serverId: 9);
      final vpn = _FakeVpn(landsOn: nbg1);
      final f = flow(vpn, {fsn1.pathKey: 150});
      Server? selected = hel1;
      final switched = <Server>[];

      await f.connect(
        [hel1, fsn1, nbg1],
        preferred: hel1,
        selection: () => selected,
        onSwitchedServer: (s) => switched.add(selected = s),
      );

      expect(f.chosen?.pathKey, nbg1.pathKey);
      expect(keys(switched), [nbg1.pathKey]);
    });
  });
}
