import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/door_sweep.dart';
import 'package:fortiva_vpn/services/ipv6_reach.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The checklist's last pass, replayed on one phone's morning.
///
/// The phone was on home wifi with no IPv6, and held two servers of eight
/// doors each. The first server dialled 198.51.100.204 and its "-b" copy
/// 198.51.100.203; the second dialled 198.51.100.205 and 198.51.100.200.
/// The first address of each server took no TCP connection, some doors
/// answered TCP and then nothing, and 198.51.100.200 was open: the
/// background sweep had found both of its doors open earlier that morning.
///
/// The door checks the phone sent show three checklists after that, all on
/// the first server's doors only, all ending at "all doors closed". The
/// first two checked doors until the 20 second budget ran out. The third
/// stopped with budget left, because every row after the ones it checked
/// was skipped for the day.
const sni = 'sni=www.samsung.com&pbk=key';

Server reality(int row, String host, int port, String door, String type) =>
    Server.fromDedicatedPath(
      uri: 'vless://u@$host:$port?type=$type&security=reality&$sni#Row$row',
      door: door,
      doorLabel: door,
      serverId: row,
    );

Server cloudflare(int row, String door, String type) =>
    Server.fromDedicatedPath(
      uri:
          'vless://u@198.51.100.215:443?type=$type&security=tls'
          '&sni=d$row.example.site&host=d$row.example.site#Row$row',
      door: door,
      doorLabel: door,
      serverId: row,
    );

/// One server's eight doors, in a backend order.
List<Server> serverDoors(int row, String a, String b, String v6) => [
  reality(row, a, 8443, 'xhttp-reality', 'xhttp'),
  reality(row, a, 2053, 'grpc-reality', 'grpc'),
  reality(row, b, 8443, 'xhttp-reality-b', 'xhttp'),
  reality(row, b, 2053, 'grpc-reality-b', 'grpc'),
  reality(row, '[$v6]', 8443, 'xhttp-reality-v6', 'xhttp'),
  reality(row, '[$v6]', 2053, 'grpc-reality-v6', 'grpc'),
  cloudflare(row, 'ws-tls', 'ws'),
  cloudflare(row, 'httpupgrade-tls', 'httpupgrade'),
];

final row1 = serverDoors(
  1,
  '198.51.100.204',
  '198.51.100.203',
  '2001:db8:f10::1',
);
final row2 = serverDoors(
  2,
  '198.51.100.205',
  '198.51.100.200',
  '2001:db8:f11::1',
);
final paths = [...row1, ...row2];

Server doorOf(List<Server> doors, String door) =>
    doors.firstWhere((d) => d.door == door);

final open2 = doorOf(row2, 'xhttp-reality-b');
final open2grpc = doorOf(row2, 'grpc-reality-b');

/// A shared link from the public list, for the fallback.
final estonia = Server(
  id: 'telegram-Estonia',
  name: 'Estonia',
  country: 'Estonia',
  city: '',
  connectionUri:
      'vless://s@ee.example:443?type=tcp&security=reality&$sni#Estonia',
  flagEmoji: '🌍',
);

/// A tunnel that comes up, verified, through the doors in [works], and
/// fails through everything else.
class _FakeVpn extends VpnService {
  _FakeVpn(this.works)
    : super(events: VpnEventReporter(send: (_, _, _) async {}));

  final Set<String> works;
  final dialled = <String>[];
  VpnStatus _fakeStatus = VpnStatus.disconnected;

  /// Whether a failed attempt failed because the user refused the VPN
  /// permission.
  bool refusePermission = false;

  @override
  bool get failedOnPermission => refusePermission;

  @override
  VpnStatus get status => _fakeStatus;

  @override
  bool get isConnected => _fakeStatus == VpnStatus.connected;

  @override
  bool get isConnecting => _fakeStatus == VpnStatus.connecting;

  @override
  bool get isVerifying => false;

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {
    dialled.add(server.pathKey);
    _fakeStatus = VpnStatus.connecting;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 5));
    _fakeStatus = works.contains(server.pathKey)
        ? VpnStatus.connected
        : VpnStatus.error;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _fakeStatus = VpnStatus.disconnected;
    notifyListeners();
  }

  @override
  void clearError() {
    if (_fakeStatus == VpnStatus.error) _fakeStatus = VpnStatus.disconnected;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// When the phone's first checklist ran, mid-morning in Tehran.
  final checklistAt = DateTime.utc(2026, 10, 5, 7, 24);

  /// The backend's block, as the backend would send it.
  ChecklistSettings settings({
    int doors = 16,
    int parallel = 4,
    int? sweptMinutes = 180,
    SkipSettings? skip,
  }) => ChecklistSettings(
    lastPass: LastPassSettings(
      doors: doors,
      parallel: parallel,
      timeout: const Duration(seconds: 1),
      sweptOpenFor: sweptMinutes == null
          ? null
          : Duration(minutes: sweptMinutes),
    ),
    skip: skip,
  );

  late DateTime clock;
  late List<String> probed;
  late List<List<Map<String, dynamic>>> reported;
  late Set<String> openHere;

  PathMemory memory() => PathMemory(now: () => clock);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clock = checklistAt;
    probed = [];
    reported = [];
    openHere = {'198.51.100.200'};
  });

  /// A checklist that ends where the phone's second one did, after the
  /// first server's eight doors, because its budget runs out there. The
  /// phone's logs do not say why its checklists stopped; a budget spent on
  /// slow doors is one way, and doors skipped for the day are the other
  /// (see the group below). Every check answers at once except the first
  /// server's last door, which takes longer than the whole budget, the way
  /// a door that answers TCP and then nothing waits out its time.
  ///
  /// [hold] runs at the start of each check and the check waits for it.
  ConnectFlow flow(
    _FakeVpn vpn, {
    ChecklistSettings? checklist,
    bool ipv6 = false,
    bool internet = true,
    DoorSweep? sweep,
    Duration budget = const Duration(milliseconds: 150),
    Future<void> Function(Server door)? hold,
  }) => ConnectFlow(
    vpn: vpn,
    memory: memory(),
    finder: PathFinder(
      probe: (p) async {
        probed.add(p.pathKey);
        await hold?.call(p);
        if (p == doorOf(row1, 'httpupgrade-tls')) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
        final host = Uri.parse(p.connectionUri).host;
        return openHere.contains(host) ? 168 : -1;
      },
      internet: () async => internet,
      budget: budget,
    ),
    reporter: VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, probes, _) async => reported.add(probes),
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.6.17',
      platform: 'android',
      networkType: () async => 'wifi',
    ),
    sweep: sweep,
    ipv6: Ipv6Reach(route: () async => ipv6),
    networkKey: () async => 'wifi',
    carrier: () async => null,
    checklist: () => checklist,
    attemptTimeout: const Duration(seconds: 2),
  );

  /// The sweep, 24 minutes before the first checklist, found both doors at
  /// 198.51.100.200 open.
  Future<void> sweptEarlier() async {
    await PathMemory(
      now: () => DateTime.utc(2026, 10, 5, 7, 0),
    ).markSwept('wifi', [open2.pathKey, open2grpc.pathKey]);
  }

  List<Map<String, dynamic>> rows() => [for (final b in reported) ...b];

  group('one phone on home wifi, a checklist cut by its budget', () {
    test('with no checklist block it ends at "all doors closed", as '
        'before', () async {
      await sweptEarlier();
      final vpn = _FakeVpn({open2.pathKey});
      final f = flow(vpn);

      await f.connect(paths, preferred: row1.first);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.nothingOpen);
      expect(vpn.dialled, isEmpty);
      // The first server's eight doors, and none of the second's.
      expect(probed, [for (final d in row1) d.pathKey]);
      expect(rows(), hasLength(8));
      expect(rows().every((r) => r['ok'] == false), isTrue);
    });

    test('the last pass finds the address the sweep found open, and the '
        'tunnel comes up through it', () async {
      await sweptEarlier();
      final vpn = _FakeVpn({open2.pathKey});
      final switched = <Server>[];
      final f = flow(vpn, checklist: settings());

      await f.connect(
        paths,
        preferred: row1.first,
        onSwitchedServer: switched.add,
      );
      await pumpEventQueue();

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, open2);
      expect(vpn.dialled, [open2.pathKey]);
      // The selection follows to the second server.
      expect(switched.single.serverId, 2);
      expect(probed.take(8), [for (final d in row1) d.pathKey]);
      // Four at once: the two doors the sweep found open first, then one
      // door at each address no row had dialled.
      expect(probed.skip(8), [
        open2.pathKey,
        open2grpc.pathKey,
        doorOf(row2, 'xhttp-reality').pathKey,
        doorOf(row2, 'ws-tls').pathKey,
      ]);

      // Reported like the checklist's own rows: in the order the checks
      // ran, under the tap's attempt id, in uploads under the upload size
      // (VpnEventReporter.probeUploadBytes), each row once.
      final sent = reported.expand((upload) => upload).toList();
      expect(sent.map((r) => r['position']), [for (var i = 1; i <= 12; i++) i]);
      expect(sent.map((r) => r['source']).toSet(), {'diagnosis'});
      expect(sent.map((r) => r['attempt_id']).toSet(), hasLength(1));
      expect(sent[8]['door'], 'xhttp-reality-b');
      expect(sent[8]['server_host'], '198.51.100.200');
      expect(sent[8]['ok'], isTrue);
      expect(sent.where((r) => r['ok'] == true), hasLength(2));
      // The rows keep their place on screen and show their result.
      expect(f.checks.map((c) => c.path), paths);
      expect(f.checks[8].state, PathCheckState.blocked);
      expect(f.checks[10].state, PathCheckState.open);
    });

    test('the order: the swept doors, one door per new address, then the '
        'other doors, and no IPv6 door on a network with no IPv6', () async {
      await sweptEarlier();
      openHere = {};
      final f = flow(_FakeVpn({}), checklist: settings(parallel: 1));

      await f.connect(paths, preferred: row1.first);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.nothingOpen);
      expect(probed.skip(8), [
        for (final d in [
          'xhttp-reality-b',
          'grpc-reality-b',
          'xhttp-reality',
          'ws-tls',
          'grpc-reality',
          'httpupgrade-tls',
        ])
          doorOf(row2, d).pathKey,
      ]);
      // The IPv6 doors stay pending, and are not reported.
      for (final d in ['xhttp-reality-v6', 'grpc-reality-v6']) {
        final row = f.checks.firstWhere((c) => c.path == doorOf(row2, d));
        expect(row.state, PathCheckState.pending);
      }
      expect(rows(), hasLength(14));
    });

    test('the remembered door whose tunnel failed on this tap goes last, '
        'even when the sweep found it open', () async {
      // The sweep found the first server's first door open, it carried the
      // tunnel, and on this tap its tunnel failed on the fast path.
      await PathMemory(
        now: () => DateTime.utc(2026, 10, 5, 7, 0),
      ).markSwept('wifi', [row1.first.pathKey]);
      await memory().remember('wifi', row1.first.pathKey);
      openHere = {};
      final vpn = _FakeVpn({});
      final f = flow(vpn, checklist: settings(parallel: 1));

      await f.connect(paths, preferred: row1.first);

      expect(vpn.dialled, [row1.first.pathKey]);
      // The checklist puts it last, and its budget ends after the first
      // server's seven other doors.
      expect(probed.take(7), [for (final d in row1.skip(1)) d.pathKey]);
      expect(probed.skip(7), hasLength(7));
      expect(probed.last, row1.first.pathKey);
    });

    test('no last pass on a phone with no internet, and no row sent', () async {
      await sweptEarlier();
      final f = flow(
        _FakeVpn({open2.pathKey}),
        checklist: settings(),
        internet: false,
      );

      await f.connect(paths, preferred: row1.first);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.noInternet);
      // The search's own doors, checked beside the control fetch. The last
      // pass, which would reach the second server's open door, did not run.
      expect(probed, isNotEmpty);
      final row1Keys = {for (final d in row1) d.pathKey};
      expect(probed.every(row1Keys.contains), isTrue);
      expect(rows(), isEmpty);
    });

    test('a stop during the last pass still sends the checklist\'s own '
        'rows', () async {
      await sweptEarlier();
      final lastPass = Completer<void>();
      final release = Completer<void>();
      final f = flow(
        _FakeVpn({open2.pathKey}),
        checklist: settings(),
        hold: (door) async {
          if (door.serverId != 2) return;
          if (!lastPass.isCompleted) lastPass.complete();
          await release.future;
        },
      );

      final tap = f.connect(paths, preferred: row1.first);
      await lastPass.future;
      f.cancel();
      release.complete();
      await tap;
      await pumpEventQueue();

      expect(f.stage, ConnectStage.cancelled);
      // The first server's eight rows, all closed, as a build without the
      // last pass sent them. None of the last pass's rows.
      expect(rows(), hasLength(8));
      expect(rows().every((r) => r['ok'] == false), isTrue);
      expect(
        rows().map((r) => r['server_host']).toSet(),
        isNot(anyOf(contains('198.51.100.200'), contains('198.51.100.205'))),
      );
    });

    test('on a network with IPv6 the IPv6 door is a new address like any '
        'other', () async {
      await sweptEarlier();
      openHere = {};
      final f = flow(
        _FakeVpn({}),
        checklist: settings(parallel: 1),
        ipv6: true,
      );

      await f.connect(paths, preferred: row1.first);

      expect(probed.skip(8), [
        for (final d in [
          'xhttp-reality-b',
          'grpc-reality-b',
          'xhttp-reality',
          'xhttp-reality-v6',
          'ws-tls',
          'grpc-reality',
          'grpc-reality-v6',
          'httpupgrade-tls',
        ])
          doorOf(row2, d).pathKey,
      ]);
    });

    test('a sweep older than the backend\'s window does not change the '
        'order', () async {
      await sweptEarlier();
      openHere = {};
      final f = flow(
        _FakeVpn({}),
        checklist: settings(parallel: 1, sweptMinutes: 20),
      );

      await f.connect(paths, preferred: row1.first);

      expect(probed.skip(8).take(3), [
        doorOf(row2, 'xhttp-reality').pathKey,
        doorOf(row2, 'xhttp-reality-b').pathKey,
        doorOf(row2, 'ws-tls').pathKey,
      ]);
    });

    test(
      'the most doors one last pass checks comes from the backend',
      () async {
        await sweptEarlier();
        openHere = {};
        final f = flow(_FakeVpn({}), checklist: settings(doors: 2));

        await f.connect(paths, preferred: row1.first);
        await pumpEventQueue();

        expect(f.stage, ConnectStage.nothingOpen);
        expect(probed.skip(8), [open2.pathKey, open2grpc.pathKey]);
        expect(
          f.checks.where((c) => c.state == PathCheckState.pending),
          hasLength(6),
        );
        // Every door closed: the rows go out in pieces, all of them closed.
        expect(rows(), hasLength(10));
        expect(rows().every((r) => r['ok'] == false), isTrue);
      },
    );

    test('no last pass once the allowance is spent', () async {
      await sweptEarlier();
      final f = flow(_FakeVpn({open2.pathKey}), checklist: settings());

      await f.connect(
        paths,
        preferred: row1.first,
        allowanceSpent: () async => true,
      );

      expect(f.stage, ConnectStage.idle);
      expect(probed, hasLength(8));
    });
  });

  test('the phone\'s third checklist: the rows skipped for the day hold the '
      'open address, and the last pass finds it', () async {
    // Every row after the six it checked was skipped: the first server's
    // grpc doors and all of the second's, the two at 198.51.100.200 among
    // them.
    clock = DateTime.utc(2026, 10, 5, 8, 2, 55);
    await sweptEarlier();
    final m = memory();
    final skippedToday = [
      doorOf(row1, 'grpc-reality'),
      doorOf(row1, 'grpc-reality-v6'),
      ...row2,
    ];
    for (final d in skippedToday) {
      for (var i = 0; i < 3; i++) {
        await m.markFailed('wifi', d.pathKey);
      }
    }
    final row1Checked = [
      for (final d in row1)
        if (!skippedToday.contains(d)) d.pathKey,
    ];

    // As the phone ran it: six checks, then "all doors closed". The phone
    // had no shared link to fall back on.
    final before = flow(
      _FakeVpn({open2.pathKey}),
      budget: const Duration(seconds: 5),
    );
    await before.connect(paths, preferred: row1.first, shared: () async => []);
    expect(before.stage, ConnectStage.nothingOpen);
    expect(probed, row1Checked);

    // With the backend's block: the same six, then the last pass. Every
    // row it checks was skipped, so the shared links go first, and with
    // none the open door is dialled.
    probed.clear();
    final vpn = _FakeVpn({open2.pathKey});
    final after = flow(
      vpn,
      checklist: settings(),
      budget: const Duration(seconds: 5),
    );
    await after.connect(paths, preferred: row1.first, shared: () async => []);

    expect(after.stage, ConnectStage.done);
    expect(vpn.dialled, [open2.pathKey]);
    expect(probed.take(6), row1Checked);
    expect(probed.skip(6).take(2), [open2.pathKey, open2grpc.pathKey]);
  });

  group('a door skipped for the day', () {
    Future<void> failThreeTimes(Server door) async {
      final m = memory();
      for (var i = 0; i < 3; i++) {
        await m.markFailed('wifi', door.pathKey);
      }
    }

    test('is checked by the last pass, and carries the tunnel', () async {
      // Both doors at 198.51.100.200 failed three times this morning.
      await failThreeTimes(open2);
      await failThreeTimes(open2grpc);
      final vpn = _FakeVpn({open2.pathKey});
      final f = flow(
        vpn,
        checklist: settings(),
        budget: const Duration(seconds: 5),
      );

      await f.connect(paths, preferred: row1.first);

      expect(f.stage, ConnectStage.done);
      expect(vpn.dialled, [open2.pathKey]);
      // The checklist checked every other door and skipped these two. The
      // last pass checked them, the first door at their address first.
      final skipped = {open2.pathKey, open2grpc.pathKey};
      expect(probed.take(14).toSet().intersection(skipped), isEmpty);
      expect(probed.skip(14), [open2.pathKey, open2grpc.pathKey]);
    });

    test('with no checklist block stays skipped, as before', () async {
      await failThreeTimes(open2);
      await failThreeTimes(open2grpc);
      final vpn = _FakeVpn({open2.pathKey});
      final f = flow(vpn, budget: const Duration(seconds: 5));

      await f.connect(paths, preferred: row1.first);

      expect(f.stage, ConnectStage.nothingOpen);
      expect(probed, isNot(contains(open2.pathKey)));
      expect(f.checks[10].state, PathCheckState.skipped);
    });

    test('still saves the check when another door opens', () async {
      // The case the skip exists for: a door that keeps failing costs no
      // check while another door works.
      await failThreeTimes(open2);
      openHere = {'198.51.100.203', '198.51.100.200'};
      final open1 = doorOf(row1, 'xhttp-reality-b');
      final vpn = _FakeVpn({open1.pathKey});
      final f = flow(vpn, checklist: settings());

      await f.connect(paths, preferred: row1.first);

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, open1);
      expect(probed, isNot(contains(open2.pathKey)));
      expect(f.checks[10].state, PathCheckState.skipped);
    });

    test('goes behind the rows the checklist\'s budget did not reach, even '
        'when the sweep found it open', () async {
      await sweptEarlier();
      await failThreeTimes(open2);
      await failThreeTimes(open2grpc);
      final vpn = _FakeVpn({open2.pathKey});
      final f = flow(vpn, checklist: settings(parallel: 1));

      await f.connect(paths, preferred: row1.first);

      expect(f.stage, ConnectStage.done);
      expect(vpn.dialled, [open2.pathKey]);
      expect(probed.take(8), [for (final d in row1) d.pathKey]);
      expect(probed.skip(8), [
        for (final d in [
          'xhttp-reality',
          'ws-tls',
          'grpc-reality',
          'httpupgrade-tls',
          'xhttp-reality-b',
        ])
          doorOf(row2, d).pathKey,
      ]);
    });

    test('waits behind a shared link that is open, when no other door of '
        'this device is', () async {
      // The case the skip exists for, with every other door closed: its
      // check passes, its tunnel fails, and a shared link works. Without
      // the block the skip keeps it out and the shared link connects. The
      // last pass must not put it back in front of that link.
      Future<List<String>> dialled(ChecklistSettings? checklist) async {
        SharedPreferences.setMockInitialValues({});
        probed.clear();
        await failThreeTimes(open2);
        await failThreeTimes(open2grpc);
        openHere = {'198.51.100.200', 'ee.example'};
        final vpn = _FakeVpn({estonia.pathKey});
        final onShared = <Server>[];
        final f = flow(
          vpn,
          checklist: checklist,
          budget: const Duration(seconds: 5),
        );
        await f.connect(
          paths,
          preferred: row1.first,
          shared: () async => [estonia],
          onShared: onShared.add,
        );
        expect(f.stage, ConnectStage.done);
        expect(f.chosen, estonia);
        expect(onShared, [estonia]);
        return vpn.dialled;
      }

      expect(await dialled(null), [estonia.pathKey]);
      expect(probed, isNot(contains(open2.pathKey)));

      expect(await dialled(settings()), [estonia.pathKey]);
      // The last pass did check it, and found it open.
      expect(probed.indexOf(open2.pathKey), lessThan(probed.length - 1));
      expect(probed.last, estonia.pathKey);
    });

    test('is dialled when the shared links are closed', () async {
      await failThreeTimes(open2);
      await failThreeTimes(open2grpc);
      final vpn = _FakeVpn({open2.pathKey});
      final f = flow(
        vpn,
        checklist: settings(),
        budget: const Duration(seconds: 5),
      );
      // The stages on screen (clients #342): the skipped door's dial is our
      // servers' turn after the shared links, so they read pending while
      // the links are checked.
      final ownWhileLinks = <StageState>{};
      f.addListener(() {
        if (f.route == RouteKind.community) {
          ownWhileLinks.add(f.stageState(RouteKind.own));
        }
      });

      await f.connect(
        paths,
        preferred: row1.first,
        shared: () async => [estonia],
      );

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, open2);
      expect(vpn.dialled, [open2.pathKey]);
      expect(probed.last, estonia.pathKey);
      expect(ownWhileLinks, {StageState.pending});
      expect(f.stageState(RouteKind.own), StageState.connected);
    });

    test(
      'is dialled when a shared link was open and its tunnel failed',
      () async {
        await failThreeTimes(open2);
        await failThreeTimes(open2grpc);
        openHere = {'198.51.100.200', 'ee.example'};
        final vpn = _FakeVpn({open2.pathKey});
        final f = flow(
          vpn,
          checklist: settings(),
          budget: const Duration(seconds: 5),
        );

        await f.connect(
          paths,
          preferred: row1.first,
          shared: () async => [estonia],
        );

        expect(f.stage, ConnectStage.done);
        expect(vpn.dialled, [estonia.pathKey, open2.pathKey]);
      },
    );

    test('ends on its failure, and does not fall back a second time', () async {
      await failThreeTimes(open2);
      await failThreeTimes(open2grpc);
      final vpn = _FakeVpn({});
      final f = flow(
        vpn,
        checklist: settings(),
        budget: const Duration(seconds: 5),
      );

      await f.connect(
        paths,
        preferred: row1.first,
        shared: () async => [estonia],
      );

      expect(f.stage, ConnectStage.failed);
      expect(f.chosen, open2);
      expect(vpn.dialled, [open2.pathKey]);
      expect(probed.where((k) => k == estonia.pathKey), hasLength(1));
    });

    test('is not dialled after the VPN permission was refused', () async {
      await failThreeTimes(open2);
      await failThreeTimes(open2grpc);
      openHere = {'198.51.100.200', 'ee.example'};
      final vpn = _FakeVpn({open2.pathKey})..refusePermission = true;
      final f = flow(
        vpn,
        checklist: settings(),
        budget: const Duration(seconds: 5),
      );

      await f.connect(
        paths,
        preferred: row1.first,
        shared: () async => [estonia],
      );

      expect(f.stage, ConnectStage.failed);
      expect(vpn.dialled, [estonia.pathKey]);
    });

    test('is checked again once the backend\'s skip time has passed', () async {
      clock = checklistAt.subtract(const Duration(minutes: 40));
      await failThreeTimes(open2);
      await failThreeTimes(open2grpc);
      clock = checklistAt;
      final vpn = _FakeVpn({open2.pathKey});
      final f = flow(
        vpn,
        checklist: ChecklistSettings(
          skip: const SkipSettings(failures: 3, skipFor: Duration(minutes: 30)),
        ),
        budget: const Duration(seconds: 5),
      );

      await f.connect(paths, preferred: row1.first);

      // No last pass in this block: the main pass reached it.
      expect(f.stage, ConnectStage.done);
      expect(vpn.dialled, [open2.pathKey]);
    });

    test('is still skipped inside the backend\'s skip time', () async {
      clock = checklistAt.subtract(const Duration(minutes: 10));
      await failThreeTimes(open2);
      await failThreeTimes(open2grpc);
      clock = checklistAt;
      final f = flow(
        _FakeVpn({open2.pathKey}),
        checklist: ChecklistSettings(
          skip: const SkipSettings(failures: 3, skipFor: Duration(minutes: 30)),
        ),
        budget: const Duration(seconds: 5),
      );

      await f.connect(paths, preferred: row1.first);

      expect(f.stage, ConnectStage.nothingOpen);
      expect(probed, isNot(contains(open2.pathKey)));
    });
  });

  group('the only door that ever carried traffic here', () {
    test('is not skipped, whatever its failures', () async {
      final m = memory();
      await m.remember('wifi', open2.pathKey);
      for (var i = 0; i < 3; i++) {
        await m.markFailed('wifi', open2.pathKey);
        await m.markFailed('wifi', open2grpc.pathKey);
      }
      final vpn = _FakeVpn({open2.pathKey});
      final f = flow(vpn, budget: const Duration(seconds: 5));

      await f.connect(paths, preferred: row1.first);

      expect(f.stage, ConnectStage.done);
      expect(vpn.dialled, [open2.pathKey]);
      // Its twin never carried traffic, so the skip still holds for it.
      expect(f.checks[11].state, PathCheckState.skipped);
    });

    test(
      'is skipped like any door once another door has worked here',
      () async {
        final m = memory();
        await m.remember('wifi', open2.pathKey);
        await m.remember('wifi', doorOf(row1, 'xhttp-reality').pathKey);
        for (var i = 0; i < 3; i++) {
          await m.markFailed('wifi', open2.pathKey);
          await m.markFailed('wifi', open2grpc.pathKey);
        }
        final f = flow(
          _FakeVpn({open2.pathKey}),
          budget: const Duration(seconds: 5),
        );

        await f.connect(paths, preferred: row1.first);

        expect(f.stage, ConnectStage.nothingOpen);
        expect(probed, isNot(contains(open2.pathKey)));
      },
    );
  });

  test('a sweep after a connect keeps the doors it found open', () async {
    final sweepReports = <List<Map<String, dynamic>>>[];
    final sweep = DoorSweep(
      probe: (p) async =>
          Uri.parse(p.connectionUri).host == '198.51.100.200' ? 150 : -1,
      internet: () async => true,
      reporter: VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, probes, _) async => sweepReports.add(probes),
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.17',
        platform: 'android',
        networkType: () async => 'wifi',
      ),
      appBypassesTunnel: true,
    );
    final vpn = _FakeVpn({open2.pathKey});
    final f = flow(vpn, sweep: sweep, budget: const Duration(seconds: 5));

    await f.connect(paths, preferred: row2.first);
    // The sweep runs after the connect and is not awaited by it.
    for (var i = 0; i < 100 && sweepReports.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await pumpEventQueue();

    expect(f.stage, ConnectStage.done);
    expect(sweepReports, isNotEmpty);
    expect(await memory().sweptOpen('wifi', const Duration(minutes: 1)), {
      open2.pathKey,
      open2grpc.pathKey,
    });
  });
}
