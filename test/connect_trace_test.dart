import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_trace.dart';
import 'package:fortiva_vpn/services/delivery_log.dart';
import 'package:fortiva_vpn/services/ipv6_reach.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/report_queue.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The connect trace, replayed on one phone's morning.
///
/// The phone was on home wifi with no IPv6, and held two servers of eight
/// doors each. The first server dialled 198.51.100.204 and its "-b" copy
/// 198.51.100.203; the second dialled 198.51.100.205 and 198.51.100.200.
/// The first address of each server took no TCP connection, some doors
/// answered TCP and then cut the handshake or said nothing, and
/// 198.51.100.200 was open: the sweep had found both of its doors open
/// earlier that morning. Its checklists that morning checked only the
/// first server's doors, and nothing the phone sent said why the second
/// server was never tried.
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

/// Every address and name a link of this replay dials or asks for. None of
/// them may be in an upload.
const addresses = [
  '198.51.100.204',
  '198.51.100.203',
  '198.51.100.205',
  '198.51.100.200',
  '198.51.100.215',
  '2001:db8:f10::1',
  '2001:db8:f11::1',
  'example.site',
  'ee.example',
];

Server doorOf(List<Server> doors, String door) =>
    doors.firstWhere((d) => d.door == door);

final open2 = doorOf(row2, 'xhttp-reality-b');
final open2grpc = doorOf(row2, 'grpc-reality-b');

/// A link from the public list.
final estonia = Server(
  id: 'telegram-Estonia',
  name: 'Estonia',
  country: 'Estonia',
  city: '',
  connectionUri:
      'vless://s@ee.example:443?type=tcp&security=reality&$sni#Estonia',
  flagEmoji: '',
);

/// What a check of a door at [host] found on that home wifi.
DoorOutcome homeWifiReading(String host) {
  if (host == '198.51.100.200') {
    return const DoorOutcome(ms: 168, tcpMs: 60, phase: 'ok');
  }
  if (host == '198.51.100.204' || host == '198.51.100.205') {
    return const DoorOutcome(
      ms: -1,
      error: 'tcp timeout; no answer in 3000 ms',
      phase: 'tcp',
    );
  }
  if (host.contains(':')) {
    return const DoorOutcome(ms: -1, error: 'tcp unreachable', phase: 'tcp');
  }
  if (host == '198.51.100.203') {
    return const DoorOutcome(ms: -1, error: 'tcp ok 80ms; EOF', tcpMs: 80);
  }
  return const DoorOutcome(
    ms: -1,
    error: 'tcp ok 40ms; no answer in 3000 ms',
    tcpMs: 40,
  );
}

/// A tunnel that comes up, verified, through the doors in [works], and
/// fails through everything else.
class _FakeVpn extends VpnService {
  _FakeVpn(this.works)
    : super(
        events: VpnEventReporter(send: (_, _, _) async {}, queues: const []),
      );

  final Set<String> works;
  final dialled = <String>[];
  VpnStatus _fakeStatus = VpnStatus.disconnected;

  bool refusePermission = false;

  /// A dial that says connecting and then never settles, the way a tunnel
  /// on a line that cuts it after the handshake can wait.
  bool hang = false;

  /// Completes when the first dial starts.
  final firstDial = Completer<void>();

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
    if (!firstDial.isCompleted) firstDial.complete();
    if (hang) return;
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

/// A step as (door, kind, stage, result, reason), for comparing.
typedef Step = (String, String, String, String, String?);

Step step(String door, String kind, String stage, String result, [String? r]) =>
    (door, kind, stage, result, r);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The second of the phone's three checklists that morning.
  final tapAt = DateTime.utc(2026, 10, 5, 7, 57);

  late DateTime clock;
  late List<({String path, Map<String, dynamic> body})> posts;
  late List<Map<String, dynamic>> tried;
  late Object? Function()? fail;
  late List<List<Map<String, dynamic>>> probes;
  late ReportQueue queue;

  ChecklistSettings settings({
    int doors = 16,
    int parallel = 4,
    DoorCheckSettings? doorChecks,
  }) => ChecklistSettings(
    lastPass: LastPassSettings(
      doors: doors,
      parallel: parallel,
      timeout: const Duration(seconds: 1),
      sweptOpenFor: const Duration(minutes: 180),
    ),
    doors: doorChecks,
  );

  ConnectTraces traces({bool Function()? on}) => ConnectTraces(
    queue: queue,
    enabled: on ?? () => true,
    networkType: () async => 'wifi',
    linkFacts: () async => const {'transport': 'wifi', 'link_mtu': 1500},
    clock: () => clock,
  );

  PathMemory memory() => PathMemory(now: () => clock);

  /// The checklist that ran out of time on the first server: every check
  /// answers at once except that server's last door, which waits longer
  /// than the whole budget, the way a door that answers TCP and then
  /// nothing waits out its time. [hold] runs at the start of each check.
  /// [network], when given, reads the network key instead of "wifi".
  ConnectFlow flow(
    _FakeVpn vpn, {
    ChecklistSettings? checklist,
    ConnectTraces? trace,
    bool internet = true,
    bool? home,
    Future<String> Function()? network,
    Duration budget = const Duration(milliseconds: 150),
    Duration attemptTimeout = const Duration(seconds: 2),
    Future<void> Function(Server door)? hold,
  }) => ConnectFlow(
    vpn: vpn,
    memory: memory(),
    finder: PathFinder(
      read: (p) async {
        await hold?.call(p);
        if (p == doorOf(row1, 'httpupgrade-tls')) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
        return homeWifiReading(Uri.parse(p.connectionUri).host);
      },
      internet: () async => internet,
      home: home == null ? null : () async => home,
      budget: budget,
    ),
    reporter: VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, rows, _) async => probes.add(rows),
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.6.19',
      platform: 'android',
      networkType: () async => 'wifi',
      queues: const [],
    ),
    ipv6: Ipv6Reach(route: () async => false),
    networkKey: network ?? () async => 'wifi',
    carrier: () async => null,
    checklist: () => checklist,
    traces: trace ?? traces(),
    attemptTimeout: attemptTimeout,
  );

  Future<void> sweptEarlier() async {
    await PathMemory(
      now: () => DateTime.utc(2026, 10, 5, 7, 0),
    ).markSwept('wifi', [open2.pathKey, open2grpc.pathKey]);
  }

  /// Wait until the trace a tap queued has been sent, or has failed to.
  Future<void> settle() async {
    await pumpEventQueue();
    await queue.flush();
    await pumpEventQueue();
  }

  /// Every item sent, in the order sent.
  List<Map<String, dynamic>> items() => [
    for (final p in posts)
      for (final item in p.body['items'] as List)
        (item as Map).cast<String, dynamic>(),
  ];

  /// The steps of the items sent, in part order.
  List<Map<String, dynamic>> stepsOf(List<Map<String, dynamic>> sent) {
    final sorted = [...sent]
      ..sort((a, b) => (a['part'] as int).compareTo(b['part'] as int));
    return [
      for (final item in sorted)
        for (final s in item['steps'] as List)
          (s as Map).cast<String, dynamic>(),
    ];
  }

  List<Step> shape(List<Map<String, dynamic>> steps) => [
    for (final s in steps)
      (
        s['door'] as String,
        s['kind'] as String,
        s['stage'] as String,
        s['result'] as String,
        s['reason'] as String?,
      ),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReportQueue.resetForTest();
    clock = tapAt;
    posts = [];
    tried = [];
    fail = null;
    probes = [];
    queue = ReportQueue.connectTraces(
      post: (path, body) async {
        final copy = (jsonDecode(jsonEncode(body)) as Map)
            .cast<String, dynamic>();
        tried.add(copy);
        final error = fail?.call();
        if (error != null) throw error;
        posts.add((path: path, body: copy));
      },
      deviceId: () async => 'DEV-1',
      register: () async {},
      clock: () => clock,
    );
  });

  group('one phone on home wifi', () {
    test('a checklist cut by its budget, then the last pass finds the second '
        'server: the trace names every door, the ones never tried '
        'included', () async {
      await sweptEarlier();
      final vpn = _FakeVpn({open2.pathKey});
      final f = flow(vpn, checklist: settings());

      await f.connect(paths, preferred: row1.first);
      await settle();

      expect(f.stage, ConnectStage.done);
      expect(vpn.dialled, [open2.pathKey]);

      final sent = items();
      // More than one upload holds this tap, and each part is numbered.
      expect(sent.length, greaterThan(1));
      expect(sent.map((i) => i['part']).toList()..sort(), [
        for (var i = 0; i < sent.length; i++) i,
      ]);
      // One attempt id, the one the tap's door checks carry.
      final attemptId = probes.first.first['attempt_id'];
      expect(attemptId, isA<String>());
      for (final item in sent) {
        expect(item.keys, [
          'attempt_id',
          'part',
          'client_ts',
          'network_type',
          'transport',
          'outcome',
          'chosen',
          'steps',
        ]);
        expect(item['attempt_id'], attemptId);
        expect(item['client_ts'], '2026-10-05T07:57:00.000Z');
        expect(item['network_type'], 'wifi');
        expect(item['transport'], 'wifi');
        expect(item['outcome'], 'connected');
        expect(item['chosen'], '2:xhttp-reality-b');
      }

      final steps = stepsOf(sent);
      for (final s in steps) {
        // A check or a dial this tap ran says when it began; a door it
        // left, and the sweep's hint, do not.
        final ran = s['result'] != 'skipped' && s['stage'] != 'sweep_hint';
        expect(s.keys, [
          'door',
          'kind',
          'stage',
          'result',
          'reason',
          'ms',
          if (ran) 'at',
        ]);
      }
      expect(shape(steps), [
        // The first server's eight doors, checked one at a time and all
        // closed.
        step('1:xhttp-reality', 'a', 'checklist', 'fail', 'tcp'),
        step('1:grpc-reality', 'a', 'checklist', 'fail', 'tcp'),
        step('1:xhttp-reality-b', 'b', 'checklist', 'fail', 'other'),
        step('1:grpc-reality-b', 'b', 'checklist', 'fail', 'other'),
        step('1:xhttp-reality-v6', 'v6', 'checklist', 'fail', 'tcp'),
        step('1:grpc-reality-v6', 'v6', 'checklist', 'fail', 'tcp'),
        step('1:ws-tls', 'cdn', 'checklist', 'fail', 'timeout'),
        step('1:httpupgrade-tls', 'cdn', 'checklist', 'fail', 'timeout'),
        // The budget ran out before the second server: what the phone's
        // door checks never said.
        for (final d in row2)
          step(
            '2:${d.door}',
            ConnectTrace.kindOf(d),
            'checklist',
            'skipped',
            'budget',
          ),
        // The sweep had found the second server's second address open.
        step('2:xhttp-reality-b', 'b', 'sweep_hint', 'ok'),
        step('2:grpc-reality-b', 'b', 'sweep_hint', 'ok'),
        // The last pass, four at once, finds it.
        step('2:xhttp-reality-b', 'b', 'last_pass', 'ok'),
        step('2:grpc-reality-b', 'b', 'last_pass', 'ok'),
        step('2:xhttp-reality', 'a', 'last_pass', 'fail', 'tcp'),
        step('2:ws-tls', 'cdn', 'last_pass', 'fail', 'timeout'),
        step('2:xhttp-reality-b', 'b', 'dial', 'ok'),
      ]);
      // Times: a check and a dial have one, a door not tried has none.
      expect(steps.first['ms'], isA<int>());
      expect(steps[8]['ms'], isNull);
      expect(steps[18]['ms'], 168);
      expect(steps.last['ms'], isA<int>());

      for (final p in posts) {
        expect(p.path, '/api/v1/devices/DEV-1/connect-traces');
        expect(p.body.keys, ['items', 'sent_at']);
        final raw = jsonEncode(p.body);
        expect(
          utf8.encode(raw).length,
          lessThanOrEqualTo(VpnEventReporter.probeUploadBytes),
        );
        for (final a in addresses) {
          expect(raw, isNot(contains(a)));
        }
      }
      expect(await queue.pending(), isEmpty);
    });

    test('the third checklist: the rows skipped for the day say so, and '
        'the last pass finds the open address among them', () async {
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
      final vpn = _FakeVpn({open2.pathKey});
      final f = flow(
        vpn,
        checklist: settings(),
        budget: const Duration(seconds: 5),
      );

      await f.connect(paths, preferred: row1.first, shared: () async => []);
      await settle();

      expect(f.stage, ConnectStage.done);
      final sent = items();
      expect(sent.map((i) => i['outcome']).toSet(), {'connected'});
      expect(sent.map((i) => i['client_ts']).toSet(), {
        '2026-10-05T08:02:55.000Z',
      });
      final steps = shape(stepsOf(sent));
      expect(steps.take(16), [
        step('1:xhttp-reality', 'a', 'checklist', 'fail', 'tcp'),
        step('1:grpc-reality', 'a', 'checklist', 'skipped', 'skipped_today'),
        step('1:xhttp-reality-b', 'b', 'checklist', 'fail', 'other'),
        step('1:grpc-reality-b', 'b', 'checklist', 'fail', 'other'),
        step('1:xhttp-reality-v6', 'v6', 'checklist', 'fail', 'tcp'),
        step(
          '1:grpc-reality-v6',
          'v6',
          'checklist',
          'skipped',
          'skipped_today',
        ),
        step('1:ws-tls', 'cdn', 'checklist', 'fail', 'timeout'),
        step('1:httpupgrade-tls', 'cdn', 'checklist', 'fail', 'timeout'),
        for (final d in row2)
          step(
            '2:${d.door}',
            ConnectTrace.kindOf(d),
            'checklist',
            'skipped',
            'skipped_today',
          ),
      ]);
      expect(steps.skip(16), [
        step('2:xhttp-reality-b', 'b', 'sweep_hint', 'ok'),
        step('2:grpc-reality-b', 'b', 'sweep_hint', 'ok'),
        step('2:xhttp-reality-b', 'b', 'last_pass', 'ok'),
        step('2:grpc-reality-b', 'b', 'last_pass', 'ok'),
        step('2:xhttp-reality', 'a', 'last_pass', 'fail', 'tcp'),
        step('2:ws-tls', 'cdn', 'last_pass', 'fail', 'timeout'),
        // No shared link to try first, so the skipped door is dialled.
        step('2:xhttp-reality-b', 'b', 'dial', 'ok'),
      ]);
    });
  });

  test('a last pass that finds nothing says which rows it left out and '
      'why', () async {
    await sweptEarlier();
    // 198.51.100.200 closed too on this tap.
    final f = ConnectFlow(
      vpn: _FakeVpn({}),
      memory: memory(),
      finder: PathFinder(
        read: (p) async {
          if (p == doorOf(row1, 'httpupgrade-tls')) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
          final host = Uri.parse(p.connectionUri).host;
          return host == '198.51.100.200'
              ? const DoorOutcome(ms: -1, error: 'tcp refused', phase: 'tcp')
              : homeWifiReading(host);
        },
        internet: () async => true,
        budget: const Duration(milliseconds: 150),
      ),
      reporter: VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, _, _) async {},
        queues: const [],
      ),
      ipv6: Ipv6Reach(route: () async => false),
      networkKey: () async => 'wifi',
      carrier: () async => null,
      checklist: () => settings(doors: 2),
      traces: traces(),
      attemptTimeout: const Duration(seconds: 2),
    );

    await f.connect(paths, preferred: row1.first);
    await settle();

    expect(f.stage, ConnectStage.nothingOpen);
    final sent = items();
    expect(sent.map((i) => i['outcome']).toSet(), {'all_closed'});
    expect(sent.map((i) => i['chosen']).toSet(), {null});
    final steps = shape(stepsOf(sent));
    expect(steps.skip(16), [
      step('2:xhttp-reality-b', 'b', 'sweep_hint', 'ok'),
      step('2:grpc-reality-b', 'b', 'sweep_hint', 'ok'),
      step('2:xhttp-reality-b', 'b', 'last_pass', 'fail', 'refused'),
      step('2:grpc-reality-b', 'b', 'last_pass', 'fail', 'refused'),
      // Past the backend's number of doors for one last pass.
      step('2:xhttp-reality', 'a', 'last_pass', 'skipped', 'budget'),
      step('2:ws-tls', 'cdn', 'last_pass', 'skipped', 'budget'),
      step('2:grpc-reality', 'a', 'last_pass', 'skipped', 'budget'),
      step('2:httpupgrade-tls', 'cdn', 'last_pass', 'skipped', 'budget'),
      // Dialled at IPv6, on a network with none.
      step('2:xhttp-reality-v6', 'v6', 'last_pass', 'skipped', 'no_ipv6'),
      step('2:grpc-reality-v6', 'v6', 'last_pass', 'skipped', 'no_ipv6'),
    ]);
  });

  group('parts', () {
    Map<String, dynamic> aStep(int i) => TraceStep(
      door: '${1000 + i}:httpupgrade-tls-v6',
      kind: 'v6',
      stage: TraceStage.checklist,
      result: TraceResult.skipped,
      reason: TraceReason.skippedToday,
      ms: 30000 + i,
    ).toJson();

    final head = {
      'attempt_id': 'f' * 64,
      'client_ts': '2026-10-05T07:57:00.123456Z',
      'network_type': 'mobile',
      'transport': 'cellular',
      'outcome': 'all_closed',
      'chosen': '1000:httpupgrade-tls-v6',
    };

    test('a long trace is cut into parts that each fit an upload under '
        '1 KB, with the same attempt id, in order', () {
      final steps = [for (var i = 0; i < 60; i++) aStep(i)];
      final parts = ConnectTrace.parts(head, steps);

      expect(parts.length, greaterThan(5));
      expect(parts.map((p) => p['part']), [
        for (var i = 0; i < parts.length; i++) i,
      ]);
      for (final p in parts) {
        expect(p['attempt_id'], 'f' * 64);
        expect(p['outcome'], 'all_closed');
        expect(
          ReportQueue.uploadBytes([p]),
          lessThanOrEqualTo(VpnEventReporter.probeUploadBytes),
        );
        expect(p['steps'], isNotEmpty);
      }
      expect([for (final p in parts) ...p['steps'] as List], steps);
      // Each part holds as many steps as fit: one more would not.
      for (final (i, p) in parts.indexed) {
        if (i == parts.length - 1) break;
        final next = (parts[i + 1]['steps'] as List).first;
        final fuller = {
          ...p,
          'steps': [...p['steps'] as List, next],
        };
        expect(
          ReportQueue.uploadBytes([fuller]),
          greaterThan(VpnEventReporter.probeUploadBytes),
        );
      }
    });

    test('a trace with no steps is one part', () {
      final parts = ConnectTrace.parts(head, const []);
      expect(parts, hasLength(1));
      expect(parts.single['part'], 0);
      expect(parts.single['steps'], isEmpty);
    });

    test('every upload the queue sends stays under 1 KB', () async {
      final trace = ConnectTrace(attemptId: 'a' * 32, startedAt: tapAt);
      for (final d in [...paths, ...paths, ...paths]) {
        trace.add(
          d,
          TraceStage.checklist,
          TraceResult.fail,
          reason: TraceReason.timeout,
          ms: 3012,
        );
      }
      trace.end(TraceOutcome.allClosed);
      await traces().send(trace);
      await settle();

      expect(posts.length, greaterThan(4));
      for (final p in posts) {
        expect(
          utf8.encode(jsonEncode(p.body)).length,
          lessThanOrEqualTo(VpnEventReporter.probeUploadBytes),
        );
      }
      expect(stepsOf(items()), hasLength(48));
    });
  });

  group('the backend\'s switch', () {
    test('off: a whole tap queues nothing and sends nothing', () async {
      await sweptEarlier();
      final f = flow(
        _FakeVpn({open2.pathKey}),
        checklist: settings(),
        trace: traces(on: () => false),
      );

      await f.connect(paths, preferred: row1.first);
      await settle();

      expect(f.stage, ConnectStage.done);
      expect(await queue.pending(), isEmpty);
      expect(tried, isEmpty);
      // The door checks still go, as before.
      expect(probes, isNotEmpty);
    });

    test('turned off during a tap: the tap queues nothing', () async {
      var on = true;
      final f = flow(
        _FakeVpn({open2.pathKey}),
        checklist: settings(),
        trace: traces(on: () => on),
        hold: (_) async => on = false,
      );

      await f.connect(paths, preferred: row2.first);
      await settle();

      expect(await queue.pending(), isEmpty);
      expect(tried, isEmpty);
    });

    test('the default follows ConnectTraces.enabled, which is off until a '
        'config turns it on', () {
      addTearDown(() => ConnectTraces.enabled = false);
      final t = ConnectTraces(queue: queue);
      expect(ConnectTraces.enabled, isFalse);
      expect(t.start('x'), isNull);
      ConnectTraces.enabled = true;
      expect(t.start('x'), isNotNull);
    });

    test('the config block: only enabled true turns it on, and a bad value '
        'keeps the rest of the config', () {
      expect(AppConfig.connectTraceOn(null), isFalse);
      expect(AppConfig.connectTraceOn({'enabled': true}), isTrue);
      expect(AppConfig.connectTraceOn({'enabled': false}), isFalse);
      expect(AppConfig.connectTraceOn({'enabled': 'true'}), isFalse);
      expect(AppConfig.connectTraceOn({}), isFalse);
      expect(AppConfig.connectTraceOn(true), isFalse);
      expect(AppConfig.connectTraceOn([true]), isFalse);

      AppConfig config(Object? block) => AppConfig.fromJson({
        'privacy_policy_url': 'https://example.com/privacy',
        'terms_of_service_url': 'https://example.com/terms',
        'eula_url': 'https://example.com/eula',
        'support_email': 'support@example.com',
        'force_update': {
          for (final os in ['ios', 'android'])
            os: {
              'latest_version': '1.0.0',
              'minimum_version': '1.0.0',
              'update_url': 'https://example.com/update',
            },
        },
        'connect_trace': ?block,
      });
      expect(config(null).connectTrace, isFalse);
      expect(config({'enabled': true}).connectTrace, isTrue);
      expect(config('on').connectTrace, isFalse);
      expect(config('on').supportEmail, 'support@example.com');
      expect(config({'enabled': true}).toJson()['connect_trace'], {
        'enabled': true,
      });
      expect(config(null).toJson().containsKey('connect_trace'), isFalse);
    });

    test('turning sharing off drops a trace that is waiting', () async {
      fail = () => ApiException(statusCode: 0, message: 'No internet');
      final trace = ConnectTrace(attemptId: 'c' * 32, startedAt: tapAt)
        ..end(TraceOutcome.allClosed);
      await traces().send(trace);
      await settle();
      expect(await queue.pending(), hasLength(1));

      await VpnEventReporter.setSharing(false);

      expect(await queue.pending(), isEmpty);
    });

    test('sharing off: nothing is stored', () async {
      SharedPreferences.setMockInitialValues({
        VpnEventReporter.sharePrefKey: false,
      });
      final f = flow(_FakeVpn({open2.pathKey}), checklist: settings());

      await f.connect(paths, preferred: row2.first);
      await settle();

      expect(await queue.pending(), isEmpty);
      expect(tried, isEmpty);
    });
  });

  group('how a tap ends', () {
    test('a stop in the middle of a one-at-a-time checklist: what ran, and '
        'stopped for the rest', () async {
      final held = Completer<void>();
      final release = Completer<void>();
      final third = doorOf(row1, 'xhttp-reality-b');
      final vpn = _FakeVpn({open2.pathKey});
      final f = flow(
        vpn,
        // door_parallel 1: the search of 1.7.0, whose check in flight runs
        // to its end after a stop.
        checklist: settings(doorChecks: DoorCheckSettings.oneAtATime),
        hold: (door) async {
          if (door != third) return;
          held.complete();
          await release.future;
        },
      );

      final tap = f.connect(paths, preferred: row1.first);
      await held.future;
      f.cancel();
      release.complete();
      await tap;
      await settle();

      expect(f.stage, ConnectStage.cancelled);
      expect(vpn.dialled, isEmpty);
      final sent = items();
      expect(sent.map((i) => i['outcome']).toSet(), {'stopped'});
      expect(sent.map((i) => i['chosen']).toSet(), {null});
      final steps = shape(stepsOf(sent));
      expect(steps.take(3), [
        step('1:xhttp-reality', 'a', 'checklist', 'fail', 'tcp'),
        step('1:grpc-reality', 'a', 'checklist', 'fail', 'tcp'),
        // The check in flight ran to its end.
        step('1:xhttp-reality-b', 'b', 'checklist', 'fail', 'other'),
      ]);
      expect(steps.skip(3), [
        for (final d in [...row1.skip(3), ...row2])
          step(
            '${d.serverId}:${d.door}',
            ConnectTrace.kindOf(d),
            'checklist',
            'skipped',
            'stopped',
          ),
      ]);
    });

    test('a stop in the middle of the checklist with several checks at '
        'once: what ran, and stopped for the check in flight', () async {
      final held = Completer<void>();
      final release = Completer<void>();
      final third = doorOf(row1, 'xhttp-reality-b');
      final vpn = _FakeVpn({open2.pathKey});
      final f = flow(
        vpn,
        checklist: settings(),
        hold: (door) async {
          if (door != third) return;
          held.complete();
          await release.future;
        },
      );

      final tap = f.connect(paths, preferred: row1.first);
      await held.future;
      f.cancel();
      // The search ends on the stop, before the check in flight answers.
      await tap.timeout(const Duration(seconds: 1));
      release.complete();
      await settle();

      expect(f.stage, ConnectStage.cancelled);
      expect(vpn.dialled, isEmpty);
      final sent = items();
      expect(sent.map((i) => i['outcome']).toSet(), {'stopped'});
      final steps = shape(stepsOf(sent));
      expect(steps.take(2), [
        step('1:xhttp-reality', 'a', 'checklist', 'fail', 'tcp'),
        step('1:grpc-reality', 'a', 'checklist', 'fail', 'tcp'),
      ]);
      // Its answer came after the stop and changes nothing.
      expect(steps.skip(2), [
        for (final d in [...row1.skip(2), ...row2])
          step(
            '${d.serverId}:${d.door}',
            ConnectTrace.kindOf(d),
            'checklist',
            'skipped',
            'stopped',
          ),
      ]);
      expect(probes, isEmpty);
    });

    test('a stop during the last pass: the rows it did not reach say '
        'stopped, and nothing is dialled', () async {
      await sweptEarlier();
      final lastPass = Completer<void>();
      final release = Completer<void>();
      final vpn = _FakeVpn({open2.pathKey});
      final first = doorOf(row2, 'xhttp-reality');
      final f = flow(
        vpn,
        // No sweep window: the last pass starts at the second server's
        // first door.
        checklist: ChecklistSettings(
          lastPass: const LastPassSettings(
            doors: 16,
            parallel: 1,
            timeout: Duration(seconds: 1),
          ),
        ),
        hold: (door) async {
          if (door != first) return;
          lastPass.complete();
          await release.future;
        },
      );

      final tap = f.connect(paths, preferred: row1.first);
      await lastPass.future;
      f.cancel();
      release.complete();
      await tap;
      await settle();

      expect(f.stage, ConnectStage.cancelled);
      expect(vpn.dialled, isEmpty);
      final steps = shape(stepsOf(items()));
      expect(items().map((i) => i['outcome']).toSet(), {'stopped'});
      expect(steps.where((s) => s.$3 == 'sweep_hint'), isEmpty);
      expect(steps.where((s) => s.$3 == 'last_pass'), [
        step('2:xhttp-reality', 'a', 'last_pass', 'fail', 'tcp'),
        // One door at each address no row had dialled, then the others.
        step('2:xhttp-reality-b', 'b', 'last_pass', 'skipped', 'stopped'),
        step('2:ws-tls', 'cdn', 'last_pass', 'skipped', 'stopped'),
        step('2:grpc-reality', 'a', 'last_pass', 'skipped', 'stopped'),
        step('2:grpc-reality-b', 'b', 'last_pass', 'skipped', 'stopped'),
        step('2:httpupgrade-tls', 'cdn', 'last_pass', 'skipped', 'stopped'),
        step('2:xhttp-reality-v6', 'v6', 'last_pass', 'skipped', 'no_ipv6'),
        step('2:grpc-reality-v6', 'v6', 'last_pass', 'skipped', 'no_ipv6'),
      ]);
    });

    test('the fast path: one part with the one dial', () async {
      await memory().remember('wifi', open2.pathKey);
      final f = flow(_FakeVpn({open2.pathKey}), checklist: settings());

      await f.connect(paths, preferred: open2);
      await settle();

      expect(f.stage, ConnectStage.done);
      final sent = items();
      expect(sent, hasLength(1));
      expect(sent.single['part'], 0);
      expect(sent.single['outcome'], 'connected');
      expect(sent.single['chosen'], '2:xhttp-reality-b');
      expect(shape(stepsOf(sent)), [
        step('2:xhttp-reality-b', 'b', 'dial', 'ok'),
      ]);
      expect(posts, hasLength(1));
    });

    test('a stop while the tunnel is coming up: the dial says stopped, and '
        'the tap ends on no door', () async {
      await memory().remember('wifi', open2.pathKey);
      final vpn = _FakeVpn({open2.pathKey})..hang = true;
      final f = flow(vpn, checklist: settings());

      final tap = f.connect(paths, preferred: open2);
      await vpn.firstDial.future;
      await pumpEventQueue();
      expect(f.stage, ConnectStage.fastPath);
      f.cancel();
      await tap;
      await settle();

      expect(f.stage, ConnectStage.cancelled);
      expect(vpn.dialled, [open2.pathKey]);
      final sent = items();
      expect(sent, hasLength(1));
      expect(sent.single['outcome'], 'stopped');
      expect(sent.single['chosen'], isNull);
      final steps = stepsOf(sent);
      expect(shape(steps), [
        step('2:xhttp-reality-b', 'b', 'dial', 'fail', 'stopped'),
      ]);
      expect(steps.single['ms'], isA<int>());
    });

    test('a tunnel that never comes up: each dial says the wait ran out, '
        'and the checklist runs between them', () async {
      await memory().remember('wifi', open2.pathKey);
      final vpn = _FakeVpn({open2.pathKey})..hang = true;
      final f = flow(
        vpn,
        attemptTimeout: const Duration(milliseconds: 50),
        budget: const Duration(seconds: 5),
      );

      await f.connect(paths, preferred: open2);
      await settle();

      expect(f.stage, ConnectStage.failed);
      expect(vpn.dialled, [open2.pathKey, open2grpc.pathKey]);
      final sent = items();
      expect(sent.map((i) => i['outcome']).toSet(), {'failed'});
      expect(sent.map((i) => i['chosen']).toSet(), {'2:grpc-reality-b'});
      expect(shape(stepsOf(sent)), [
        step('2:xhttp-reality-b', 'b', 'dial', 'fail', 'timeout'),
        step('2:xhttp-reality', 'a', 'checklist', 'fail', 'tcp'),
        step('2:grpc-reality', 'a', 'checklist', 'fail', 'tcp'),
        step('2:grpc-reality-b', 'b', 'checklist', 'ok'),
        step('2:grpc-reality-b', 'b', 'dial', 'fail', 'timeout'),
      ]);
    });

    test('a tap that ends on an error says failed, not stopped', () async {
      final f = flow(
        _FakeVpn({open2.pathKey}),
        checklist: settings(),
        // A throw from the control fetch now counts as no internet
        // (PathFinder.controlFetch), so the error comes from the network
        // key the tap reads before its checklist.
        network: () async => throw StateError('no answer from the platform'),
      );

      await expectLater(
        f.connect(paths, preferred: row1.first),
        throwsStateError,
      );
      await settle();

      final sent = items();
      expect(sent, hasLength(1));
      expect(sent.single['outcome'], 'failed');
      expect(sent.single['chosen'], isNull);
      expect(sent.single['steps'], isEmpty);
    });

    test('the allowance after a failed fast path: the dial says so, and no '
        'checklist runs', () async {
      await memory().remember('wifi', open2.pathKey);
      final vpn = _FakeVpn({});
      final f = flow(vpn, checklist: settings());

      await f.connect(
        paths,
        preferred: open2,
        allowanceSpent: () async => true,
      );
      await settle();

      expect(f.stage, ConnectStage.idle);
      final sent = items();
      expect(sent, hasLength(1));
      expect(sent.single['outcome'], 'allowance');
      expect(shape(stepsOf(sent)), [
        step('2:xhttp-reality-b', 'b', 'dial', 'fail', 'allowance'),
      ]);
    });

    test('the allowance after a checklist that found nothing: the rows it '
        'did not reach say allowance', () async {
      await sweptEarlier();
      final f = flow(_FakeVpn({open2.pathKey}), checklist: settings());

      await f.connect(
        paths,
        preferred: row1.first,
        allowanceSpent: () async => true,
      );
      await settle();

      expect(f.stage, ConnectStage.idle);
      final sent = items();
      expect(sent.map((i) => i['outcome']).toSet(), {'allowance'});
      final steps = shape(stepsOf(sent));
      expect(steps, hasLength(16));
      expect(steps.take(8).map((s) => s.$4).toSet(), {'fail'});
      expect(steps.skip(8).map((s) => (s.$4, s.$5)).toSet(), {
        ('skipped', 'allowance'),
      });
    });

    test('a refused VPN permission ends on permission, on the door it '
        'dialled', () async {
      final vpn = _FakeVpn({})..refusePermission = true;
      final f = flow(vpn, budget: const Duration(seconds: 5));

      await f.connect(paths, preferred: row2.first);
      await settle();

      expect(f.stage, ConnectStage.failed);
      final sent = items();
      expect(sent.single['outcome'], 'permission');
      expect(sent.single['chosen'], '2:xhttp-reality-b');
      expect(shape(stepsOf(sent)), [
        step('2:xhttp-reality', 'a', 'checklist', 'fail', 'tcp'),
        step('2:grpc-reality', 'a', 'checklist', 'fail', 'tcp'),
        step('2:xhttp-reality-b', 'b', 'checklist', 'ok'),
        step('2:xhttp-reality-b', 'b', 'dial', 'fail', 'other'),
      ]);
    });

    test('the checklist names no door after the open one, a door skipped '
        'for the day among them', () async {
      final m = memory();
      for (var i = 0; i < 3; i++) {
        await m.markFailed('wifi', doorOf(row2, 'ws-tls').pathKey);
      }
      final f = flow(
        _FakeVpn({open2.pathKey}),
        budget: const Duration(seconds: 5),
      );

      await f.connect(paths, preferred: row2.first);
      await settle();

      expect(f.stage, ConnectStage.done);
      expect(f.checks[6].state, PathCheckState.skipped);
      expect(shape(stepsOf(items())), [
        step('2:xhttp-reality', 'a', 'checklist', 'fail', 'tcp'),
        step('2:grpc-reality', 'a', 'checklist', 'fail', 'tcp'),
        step('2:xhttp-reality-b', 'b', 'checklist', 'ok'),
        step('2:xhttp-reality-b', 'b', 'dial', 'ok'),
      ]);
    });

    test('no internet: one part, no door named', () async {
      final f = flow(
        _FakeVpn({open2.pathKey}),
        checklist: settings(),
        internet: false,
      );

      await f.connect(paths, preferred: row1.first);
      await settle();

      expect(f.stage, ConnectStage.noInternet);
      final sent = items();
      expect(sent, hasLength(1));
      expect(sent.single['outcome'], 'no_internet');
      expect(sent.single['steps'], isEmpty);
    });

    test(
      'a cut way abroad: one part, its own outcome, no door named',
      () async {
        final f = flow(
          _FakeVpn({open2.pathKey}),
          checklist: settings(),
          internet: false,
          home: true,
        );

        // The first server only: none of its doors is open on this line.
        await f.connect(row1, preferred: row1.first);
        await settle();

        expect(f.stage, ConnectStage.cutOff);
        final sent = items();
        expect(sent, hasLength(1));
        expect(sent.single['outcome'], 'cut_off');
        // Every door fails with the way abroad cut, which says nothing about
        // any one of them.
        expect(sent.single['steps'], isEmpty);
      },
    );

    test(
      'a cut way abroad gives the doors the whole search: the open one '
      'that the tap with no internet never reached carries the tunnel',
      () async {
        final f = flow(
          _FakeVpn({open2.pathKey}),
          checklist: settings(),
          internet: false,
          home: true,
        );

        await f.connect(paths, preferred: row1.first);
        await settle();

        expect(f.stage, ConnectStage.done);
        expect(f.chosen, open2);
        expect(items().single['outcome'], 'connected');
      },
    );

    test('the shared-link fallback: its checks are checklist steps, and the '
        'tunnel through one is the chosen door', () async {
      final shared = Server(
        id: '7',
        name: 'Shared',
        country: 'Germany',
        city: '',
        connectionUri:
            'vless://s@198.51.100.200:443?type=tcp&security=reality&$sni#S',
        flagEmoji: '',
      );
      // After the open one, so it is never checked.
      final later = Server(
        id: '8',
        name: 'Shared 2',
        country: 'Germany',
        city: '',
        connectionUri:
            'vless://s@198.51.100.205:443?type=tcp&security=reality&$sni#S2',
        flagEmoji: '',
      );
      final vpn = _FakeVpn({shared.pathKey});
      final f = flow(vpn, budget: const Duration(seconds: 5));

      await f.connect(
        row1,
        preferred: row1.first,
        shared: () async => [estonia, shared, later],
      );
      await settle();

      expect(f.stage, ConnectStage.done);
      expect(f.chosen, shared);
      expect(f.checks.last.path, later);
      expect(f.checks.last.state, PathCheckState.pending);
      final sent = items();
      final lidEstonia = ConnectTrace.doorKey(estonia);
      final lidShared = ConnectTrace.doorKey(shared);
      expect(sent.map((i) => i['chosen']).toSet(), {lidShared});
      // Nothing for the link after the open one.
      expect(shape(stepsOf(sent)).skip(8), [
        step(lidEstonia, 'community', 'checklist', 'fail', 'timeout'),
        step(lidShared, 'shared', 'checklist', 'ok'),
        step(lidShared, 'shared', 'dial', 'ok'),
      ]);
    });
  });

  test('a part sent again after a failed upload is the same part, so the '
      'backend can store it once', () async {
    final f = flow(_FakeVpn({open2.pathKey}), checklist: settings());
    fail = () => ApiException(statusCode: 0, message: 'No internet');

    await f.connect(paths, preferred: row2.first);
    await settle();

    expect(posts, isEmpty);
    expect(tried, isNotEmpty);
    final first = tried.first;
    expect(await queue.pending(), isNotEmpty);

    // An hour later, from a line that carries it.
    clock = clock.add(const Duration(hours: 1));
    fail = null;
    tried.clear();
    await queue.flush();

    expect(posts, isNotEmpty);
    // The same items, attempt id and part included. Only sent_at moved.
    expect(posts.first.body['items'], first['items']);
    expect(posts.first.body['sent_at'], isNot(first['sent_at']));
    expect(posts.first.body['sent_at'], '2026-10-05T08:57:00.000Z');
    final keys = {
      for (final item in items()) '${item['attempt_id']}/${item['part']}',
    };
    expect(keys, hasLength(items().length));
    expect(await queue.pending(), isEmpty);

    // Nothing left to send twice.
    posts.clear();
    await queue.flush();
    expect(posts, isEmpty);
  });

  test('a waiting trace goes with the other reports when the reporter '
      'flushes', () async {
    final sent = <String>[];
    final reporter = VpnEventReporter(
      send: (_, _, _) async {},
      post: (path, _) async => sent.add(path),
      deviceId: () async => 'DEV-1',
      register: () async {},
      clock: () => clock,
    );
    final trace = ConnectTrace(attemptId: 'b' * 32, startedAt: tapAt)
      ..add(open2, TraceStage.dial, TraceResult.ok, ms: 900)
      ..end(TraceOutcome.connected, chosen: open2);
    await ReportQueue.connectTraces().addLater(trace.items);

    await reporter.flush();

    expect(sent, ['/api/v1/devices/DEV-1/connect-traces']);
  });

  test('a network type the platform never answers does not hold the '
      'queues: the trace goes without it', () async {
    final t = ConnectTraces(
      queue: queue,
      enabled: () => true,
      networkType: () => Completer<String?>().future,
      linkFacts: () async => const {'transport': 'wifi'},
      clock: () => clock,
    );
    final trace = t.start('d' * 32)!..end(TraceOutcome.allClosed);

    // Every queue shares one lock, and the trace is built inside it.
    await t.send(trace).timeout(DeliveryLog.networkTimeout * 5);
    await settle();

    final sent = items();
    expect(sent, hasLength(1));
    expect(sent.single['network_type'], isNull);
    expect(sent.single['transport'], 'wifi');
    expect(await queue.pending(), isEmpty);
  });

  group('door keys', () {
    test('a door of our own is its row and its name, never an address', () {
      expect(ConnectTrace.doorKey(row1.first), '1:xhttp-reality');
      expect(ConnectTrace.kindOf(row1.first), 'a');
      expect(ConnectTrace.doorKey(doorOf(row2, 'grpc-reality-b')), isNotEmpty);
      expect(ConnectTrace.kindOf(doorOf(row2, 'grpc-reality-b')), 'b');
      expect(ConnectTrace.kindOf(doorOf(row2, 'grpc-reality-v6')), 'v6');
      expect(ConnectTrace.kindOf(doorOf(row2, 'ws-tls')), 'cdn');
      // A door from a backend that sent no row id.
      final noRow = Server.fromDedicatedPath(
        uri: row1.first.connectionUri,
        door: 'xhttp-reality',
        doorLabel: 'xhttp-reality',
      );
      expect(ConnectTrace.doorKey(noRow), 'xhttp-reality');
    });

    test('a shared or community link goes by its lid', () {
      final key = ConnectTrace.doorKey(estonia);
      expect(key, matches(RegExp(r'^lid:[0-9a-f]{12}$')));
      expect(ConnectTrace.kindOf(estonia), 'community');
      final shared = Server(
        id: '7',
        name: 'Shared',
        country: '',
        city: '',
        connectionUri: 'vless://s@198.51.100.205:443?type=tcp&security=reality',
        flagEmoji: '',
      );
      expect(ConnectTrace.kindOf(shared), 'shared');
      expect(ConnectTrace.doorKey(shared), startsWith('lid:'));
      for (final s in [...paths, estonia, shared]) {
        final k = ConnectTrace.doorKey(s);
        for (final a in addresses) {
          expect(k, isNot(contains(a)));
        }
      }
    });
  });

  test('a failed check becomes a kind of failure, never the core\'s words', () {
    TraceReason of(String? error, [String? phase]) => ConnectTrace.reasonOf(
      PathCheck(row1.first, state: PathCheckState.blocked)
        ..error = error
        ..phase = phase,
    );
    expect(of('tcp timeout', 'tcp'), TraceReason.tcp);
    expect(of('tcp unreachable', 'tcp'), TraceReason.tcp);
    expect(of('tcp refused', 'tcp'), TraceReason.refused);
    expect(of('tls: handshake failure', 'tls'), TraceReason.tls);
    expect(of('tcp ok 40ms; no answer in 3000 ms'), TraceReason.timeout);
    expect(of('TimeoutException after 0:00:04.000000'), TraceReason.timeout);
    expect(of('tcp ok 80ms; EOF'), TraceReason.other);
    expect(of(null), TraceReason.other);
  });
}
