import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/community_checks.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A stop while the shared fallback writes down the link whose tunnel just
/// failed ends the tap there.
///
/// In a test on 2026-10-12 the fallback came back as "failed" for a tap
/// the user had stopped during that write. The stopped tap went back to
/// its own doors and checked 4 to 6 of them, and its stage stayed at
/// "diagnosing" after it returned, so the button showed "Finding a path"
/// and the user's next tap was spent as a stop. A door skipped for the day
/// was put on the card and its server made the selection.
Server door(String host) => Server(
  id: 'dedicated-$host:443',
  name: host,
  country: '',
  city: host,
  connectionUri: 'vless://u@$host:443?type=tcp#$host',
  flagEmoji: '',
  isDedicated: true,
  door: 'tcp-reality',
  doorLabel: 'tcp-reality',
);

/// Every tunnel fails.
class _FakeVpn extends VpnService {
  _FakeVpn() : super(events: VpnEventReporter(send: (_, _, _) async {}));

  final dialled = <String>[];
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
    _fakeStatus = VpnStatus.error;
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

/// Holds the write of one link's failure until the test lets it go.
class _GatedMemory extends PathMemory {
  _GatedMemory(this.held);

  final String held;
  final reached = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> markFailed(String network, String pathKey) async {
    if (pathKey == held && !reached.isCompleted) {
      reached.complete();
      await release.future;
    }
    return super.markFailed(network, pathKey);
  }
}

class _Kept extends CommunityChecks {
  _Kept() : super(platform: 'android');

  @override
  Future<void> report(List<CommunityCheck> checks, {String? carrier}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const network = 'mobile:Irancell';

  final link = Server.fromConnectionUri(
    'vless://u@h0.example:443?type=tcp&security=reality'
    '&sni=www.samsung.com&pbk=key#Link0',
  );

  late List<String> probed;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    probed = [];
  });

  ConnectFlow flow(
    _FakeVpn vpn,
    PathMemory memory,
    ChecklistSettings checklist, {
    required Set<String> open,
  }) => ConnectFlow(
    vpn: vpn,
    memory: memory,
    finder: PathFinder(
      probe: (p) async {
        probed.add(p.pathKey);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return open.contains(p.pathKey) ? 30 : -1;
      },
      internet: () async => true,
      budget: const Duration(seconds: 2),
      probeTimeout: const Duration(seconds: 1),
    ),
    reporter: VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, _, _) async {},
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.7.1',
      platform: 'android',
      networkType: () async => 'mobile',
    ),
    networkKey: () async => network,
    carrier: () async => 'Irancell',
    communityChecks: _Kept(),
    checklist: () => checklist,
    attemptTimeout: const Duration(seconds: 1),
  );

  test('after FallbackSettings.after: no own door is checked after the stop, '
      'and the stage stays stopped', () async {
    final own = [for (var i = 0; i < 8; i++) door('d$i')];
    final memory = _GatedMemory(link.pathKey);
    final vpn = _FakeVpn();
    final f = flow(
      vpn,
      memory,
      const ChecklistSettings(
        fallback: FallbackSettings(
          links: 1,
          parallel: 1,
          after: Duration(milliseconds: 50),
        ),
        doors: DoorCheckSettings(parallel: 2, stagger: Duration.zero),
      ),
      open: {link.pathKey},
    );

    final tap = f.connect(own, shared: () async => [link]);
    await memory.reached.future;
    final before = probed.length;
    f.cancel();
    memory.release.complete();
    await tap;
    await pumpEventQueue();

    expect(vpn.dialled, [link.pathKey]);
    expect(probed.length, before);
    expect(f.stage, ConnectStage.cancelled);
    expect(f.isBusy, isFalse);
  });

  test('a door skipped for the day is not dialled after the stop, and the '
      'selection stays', () async {
    final a = door('a');
    final b = door('b');
    final memory = _GatedMemory(link.pathKey);
    // b failed three times today on this network, so the checklist skips
    // it and only the last pass checks it.
    for (var i = 0; i < 3; i++) {
      await memory.markFailed(network, b.pathKey);
    }
    final vpn = _FakeVpn();
    final switched = <Server>[];
    final f = flow(
      vpn,
      memory,
      const ChecklistSettings(
        lastPass: LastPassSettings(
          doors: 4,
          parallel: 2,
          timeout: Duration(seconds: 1),
        ),
        fallback: FallbackSettings(links: 1, parallel: 1),
        doors: DoorCheckSettings(parallel: 2, stagger: Duration.zero),
      ),
      open: {b.pathKey, link.pathKey},
    );

    final tap = f.connect(
      [a, b],
      preferred: a,
      shared: () async => [link],
      onSwitchedServer: switched.add,
    );
    await memory.reached.future;
    f.cancel();
    memory.release.complete();
    await tap;
    await pumpEventQueue();

    expect(probed, [a.pathKey, b.pathKey, link.pathKey]);
    expect(vpn.dialled, [link.pathKey]);
    expect(switched, isEmpty);
    expect(f.stage, ConnectStage.cancelled);
    expect(f.isBusy, isFalse);
  });
}
