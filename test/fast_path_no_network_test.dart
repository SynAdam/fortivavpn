import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/data/models/psiphon_settings.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/ipv6_reach.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The fast path on no network at all (FastPathSettings.skipOffline).
///
/// With the backend's fast_path_skip_offline on, a tap on the network key
/// `none` does not dial the remembered door first. The checklist runs, and
/// checks that door like any other, so it is still dialled when it answers.
/// Without the key, nothing changes. Every address here is made up.
Server own(String host, String door, int row) => Server.fromDedicatedPath(
  uri:
      'vless://u@$host:8443?type=tcp&security=reality'
      '&sni=www.example.com&pbk=key#Row$row',
  door: door,
  doorLabel: door,
  serverId: row,
);

final hel1 = own('203.0.113.226', 'tcp-reality', 13);
final hel2 = own('203.0.113.226', 'xhttp-reality', 13);
final fsn1 = own('203.0.113.227', 'tcp-reality', 14);
final paths = [hel1, hel2, fsn1];

const open = DoorOutcome(ms: 120, tcpMs: 40, phase: 'ok');
const closed = DoorOutcome(
  ms: -1,
  error: 'tcp timeout; no answer in 3000 ms',
  phase: 'tcp',
);

const fresh = QuotaStatus(
  unlimited: false,
  limitBytes: 100,
  usedBytes: 10,
  remainingBytes: 90,
  blocked: false,
);

/// A tunnel that comes up through the doors in [works]. Every check and
/// dial goes into [log] in the order they happen.
class _FakeVpn extends VpnService {
  _FakeVpn(this.works, this.log)
    : super(
        events: VpnEventReporter(send: (_, _, _) async {}, queues: const []),
      );

  final Set<String> works;
  final List<String> log;
  VpnStatus _fake = VpnStatus.disconnected;

  @override
  VpnStatus get status => _fake;

  @override
  bool get isConnected => _fake == VpnStatus.connected;

  @override
  bool get isConnecting => _fake == VpnStatus.connecting;

  @override
  bool get isVerifying => false;

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {
    log.add('dial ${server.pathKey}');
    _fake = VpnStatus.connecting;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 2));
    _fake = works.contains(server.pathKey)
        ? VpnStatus.connected
        : VpnStatus.error;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _fake = VpnStatus.disconnected;
    notifyListeners();
  }

  @override
  void clearError() {
    if (_fake == VpnStatus.error) _fake = VpnStatus.disconnected;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> log;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    log = [];
  });

  ConnectFlow flow(
    _FakeVpn vpn, {
    required String network,
    ChecklistSettings? checklist,
  }) {
    final f = ConnectFlow(
      vpn: vpn,
      memory: PathMemory(),
      finder: PathFinder(
        read: (p) async {
          log.add('check ${p.pathKey}');
          return p.pathKey == hel2.pathKey ? open : closed;
        },
        internet: () async => true,
        home: () async => true,
        budget: const Duration(milliseconds: 300),
      ),
      reporter: VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, _, _) async {},
        deviceId: () async => 'DEV-1',
        appVersion: () async => '2.3.0',
        platform: 'android',
        networkType: () async => null,
        queues: const [],
      ),
      ipv6: Ipv6Reach(route: () async => null),
      networkKey: () async => network,
      carrier: () async => null,
      checklist: () => checklist,
      random: () => 0.5,
      networkSettle: const Duration(milliseconds: 10),
      attemptTimeout: const Duration(seconds: 2),
      psiphon: () => null,
      psiphonDevice: () =>
          const PsiphonDevice(allowed: true, quota: fresh, quotaFresh: true),
      android: () => true,
      tv: () => false,
    );
    addTearDown(f.cancel);
    return f;
  }

  const skipOn = ChecklistSettings(
    fastPath: FastPathSettings(
      besideAfter: Duration(seconds: 5),
      forgetAfter: Duration(seconds: 5),
      skipOffline: true,
    ),
  );

  test('with the switch on and no network, the remembered door is checked '
      'before it is dialled, and still connects', () async {
    await PathMemory().remember('none', hel2.pathKey);
    final vpn = _FakeVpn({hel2.pathKey}, log);
    final f = flow(vpn, network: 'none', checklist: skipOn);

    await f.connect(paths);

    expect(log.first, startsWith('check '));
    expect(log, contains('check ${hel2.pathKey}'));
    expect(
      log.indexOf('check ${hel2.pathKey}'),
      lessThan(log.indexOf('dial ${hel2.pathKey}')),
    );
    expect(f.stage, ConnectStage.done);
  });

  test('without the switch, no network still dials the remembered door '
      'first', () async {
    await PathMemory().remember('none', hel2.pathKey);
    final vpn = _FakeVpn({hel2.pathKey}, log);
    final f = flow(vpn, network: 'none');

    await f.connect(paths);

    expect(log.first, 'dial ${hel2.pathKey}');
    expect(f.stage, ConnectStage.done);
  });

  test(
    'with the switch on, a phone on a network keeps the fast path',
    () async {
      await PathMemory().remember('mobile', hel2.pathKey);
      final vpn = _FakeVpn({hel2.pathKey}, log);
      final f = flow(vpn, network: 'mobile', checklist: skipOn);

      await f.connect(paths);

      expect(log.first, 'dial ${hel2.pathKey}');
      expect(f.stage, ConnectStage.done);
    },
  );
}
