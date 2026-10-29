import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/ipv6_reach.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Another VPN app on the phone, such as Psiphon or NPV Tunnel.
///
/// Android runs one VPN at a time. On a phone where the user has approved
/// Fortiva once, the platform call that takes the slot (VpnService.prepare)
/// takes it at once and tears down the other app's VPN. Up to 2.2.0 the app
/// made that call with no tap: when another app took the slot, in every
/// report, on every dial of a search, on every retry and when Android
/// restarted the service. Users on Samsung reported on 2026-10-21 that
/// Psiphon and NPV Tunnel could not stay on even with Fortiva off, until
/// they uninstalled Fortiva; it reproduced on Android 14 and 16.
///
/// Now the first dial of a tap is the only one that may take the slot. Any
/// other dial gets a tunnel only while the slot is still this app's, and
/// one that finds another app holding it ends the tap as a stop ends it.
Server own(String host, String door, int row) => Server.fromDedicatedPath(
  uri:
      'vless://u@$host:8443?type=tcp&security=reality'
      '&sni=www.samsung.com&pbk=key#Row$row',
  door: door,
  doorLabel: door,
  serverId: row,
);

final hel1 = own('192.0.2.10', 'tcp-reality', 13);
final hel2 = own('192.0.2.10', 'xhttp-reality', 13);
final fsn1 = own('192.0.2.20', 'tcp-reality', 14);
final paths = [hel1, hel2, fsn1];

final picked = Server.fromConnectionUri(
  'vless://u@h1.example:443?type=tcp&security=reality'
  '&sni=www.samsung.com&pbk=key#Link1',
);

final picked2 = Server.fromConnectionUri(
  'vless://u@h2.example:443?type=tcp&security=reality'
  '&sni=www.samsung.com&pbk=key#Link2',
);

const open = DoorOutcome(ms: 120, tcpMs: 40, phase: 'ok');
const closed = DoorOutcome(
  ms: -1,
  error: 'tcp timeout; no answer in 3000 ms',
  phase: 'tcp',
);

/// The phone's VPN slot as the platform keeps it, and a tunnel that comes
/// up through the doors in [works].
class _Vpn extends VpnService {
  _Vpn(this.works) : super(events: VpnEventReporter(send: (_, _, _) async {}));

  final Set<String> works;
  final dialled = <String>[];

  /// For each dial, whether the flow let it take the slot.
  final tookSlot = <bool>[];

  /// Whether Android has this app as the VPN it may start: true after
  /// this app's own last tunnel, false after a reboot or once another VPN
  /// app has taken the slot.
  bool ours = true;

  /// Another app's VPN is up and holds the slot.
  bool get other => _other;
  set other(bool up) {
    _other = up;
    if (up) ours = false;
  }

  bool _other = false;

  /// A VPN for a few apps only: it holds the slot and does not carry this
  /// app, so [otherVpnUp] does not see it.
  bool get forFewApps => _forFewApps;
  set forFewApps(bool up) {
    _forFewApps = up;
    if (up) ours = false;
  }

  bool _forFewApps = false;

  /// VPNs in a work profile: their own slot, not this one.
  int inWorkProfile = 0;

  /// Times the flow put the screen back after giving way.
  int gaveWay = 0;

  /// How many door checks had run when the tap took the slot before its
  /// search (takeSlotForTap), once for each time it did.
  final takenAtTap = <int>[];

  /// Reads the checks run so far, for [takenAtTap].
  int Function() checksSoFar = () => 0;

  bool _allowed = false;
  bool _lost = false;
  VpnStatus _fakeStatus = VpnStatus.disconnected;

  @override
  void allowTakingSlot() => _allowed = true;

  @override
  Future<bool> otherVpnUp() async => other;

  @override
  Future<int?> otherVpnCount() async =>
      (other ? 1 : 0) + (forFewApps ? 1 : 0) + inWorkProfile;

  @override
  void clearAfterGivingWay() => gaveWay++;

  /// How long the platform takes to take the slot (MainActivity waits for
  /// the other app's network to go, up to 2 s).
  Duration takeTakes = Duration.zero;

  @override
  Future<bool> takeSlotForTap() async {
    if (!other) return false;
    await Future<void>.delayed(takeTakes);
    takenAtTap.add(checksSoFar());
    other = false;
    ours = true;
    return true;
  }

  @override
  bool get lostSlot => _lost;

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
    final take = _allowed;
    _allowed = false;
    _lost = false;
    dialled.add(server.pathKey);
    tookSlot.add(take);
    _fakeStatus = VpnStatus.connecting;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 2));
    if (take) {
      // prepare(): the slot is this app's, and the other app's VPN goes.
      other = false;
      forFewApps = false;
      ours = true;
    } else if (!ours) {
      // The platform's establish() gives no interface: the slot is not ours.
      _lost = true;
      _fakeStatus = VpnStatus.disconnected;
      notifyListeners();
      return;
    }
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

class _Row {
  _Row(this.type, this.error, this.diag);
  final VpnEventType type;
  final String? error;
  final Map<String, dynamic>? diag;
}

class _Reporter extends VpnEventReporter {
  _Reporter() : super(send: (_, _, _) async {});

  final rows = <_Row>[];

  @override
  Future<void> record(
    VpnEventType type, {
    String? serverHost,
    String? door,
    String? attemptId,
    Map<String, dynamic>? strategy,
    Duration? duration,
    String? error,
    Map<String, dynamic>? diag,
    int? bytesUp,
    int? bytesDown,
    DateTime? at,
  }) async {
    rows.add(_Row(type, error, diag));
  }
}

class _NoDiagnostics extends ConnectDiagnostics {
  @override
  Future<Map<String, dynamic>> collect({
    String? host,
    int port = 443,
    String? sni,
  }) async => const {};

  @override
  Future<Map<String, dynamic>> platformReport() async => const {};
}

/// Waits until [ok] holds, failing the test after [within].
Future<void> until(
  bool Function() ok, {
  Duration within = const Duration(seconds: 3),
}) async {
  final end = DateTime.now().add(within);
  while (!ok()) {
    if (DateTime.now().isAfter(end)) fail('still waiting after $within');
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the service', () {
    const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<Map<Object?, Object?>> connects;
    late bool otherUp;
    late _Reporter reporter;
    late VpnService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      connects = [];
      otherUp = false;
      messenger.setMockMethodCallHandler(tunnel, (call) async {
        switch (call.method) {
          case 'connect':
            connects.add(Map.of(call.arguments as Map<Object?, Object?>));
            return null;
          case 'otherVpn':
            return otherUp;
          case 'getStatus':
            return 'disconnected';
        }
        return null;
      });
      reporter = _Reporter();
      service = VpnService(
        events: reporter,
        diagnostics: _NoDiagnostics(),
        android: true,
      );
      VpnService.slotTakerWait = const Duration(milliseconds: 60);
    });

    tearDown(() {
      service.dispose();
      messenger.setMockMethodCallHandler(tunnel, null);
      VpnService.slotTakerWait = const Duration(seconds: 10);
    });

    test(
      'a dial takes the slot only when allowed, and only that dial',
      () async {
        await service.connect(hel1);
        service.allowTakingSlot();
        await service.connect(hel1);
        await service.connect(hel1);

        expect(
          [for (final c in connects) c['take_slot']],
          [false, true, false],
        );
      },
    );

    test('a start that finds another app holding the slot ends with nothing '
        'up, no error and no failure filed', () async {
      await service.connect(hel1);
      expect(service.status, VpnStatus.connecting);

      service.applyNativeStatus('failed:$startFailedSlotTaken');
      await Future<void>.delayed(Duration.zero);

      expect(service.lostSlot, isTrue);
      expect(service.status, VpnStatus.disconnected);
      expect(service.errorMessage, isNull);
      expect(
        reporter.rows.where((r) => r.type == VpnEventType.connectFailed),
        isEmpty,
      );

      // The next connect starts clean.
      await service.connect(hel1);
      expect(service.lostSlot, isFalse);
    });

    test('giving way puts the screen back to Tap to connect, also over an '
        'error', () async {
      await service.connect(hel1);
      service.applyNativeStatus('failed');
      expect(service.status, VpnStatus.error);

      service.clearAfterGivingWay();

      expect(service.status, VpnStatus.disconnected);
      expect(service.errorMessage, isNull);
    });

    test('a tunnel Android took is filed as replaced once another app\'s VPN '
        'comes up', () async {
      // The first look finds nothing up. A wide window keeps a stall of the
      // test process from ending the wait before the next look.
      VpnService.slotTakerWait = const Duration(seconds: 10);
      service.applyNativeStatus('connected');
      service.applyNativeStatus('disconnected:$dropReasonRevoked');
      // The other app's VPN comes up a moment after it took the slot.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      otherUp = true;
      await until(
        () => reporter.rows.any((r) => r.type == VpnEventType.dropped),
      );

      final drop = reporter.rows.singleWhere(
        (r) => r.type == VpnEventType.dropped,
      );
      expect(drop.error, dropReasonReplaced);
      expect(drop.diag, containsPair('drop_reason', dropReasonReplaced));
    });

    test(
      'with no other VPN it stays revoked: the user turned it off',
      () async {
        service.applyNativeStatus('connected');
        service.applyNativeStatus('disconnected:$dropReasonRevoked');
        await until(
          () => reporter.rows.any((r) => r.type == VpnEventType.dropped),
        );

        final drop = reporter.rows.singleWhere(
          (r) => r.type == VpnEventType.dropped,
        );
        expect(drop.error, dropReasonRevoked);
      },
    );
  });

  group('the connect flow', () {
    const network = 'mobile';
    late List<String> probed;
    late Set<String> openHere;
    late void Function()? onProbe;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      probed = [];
      openHere = {};
      onProbe = null;
    });

    RetrySettings waits(List<int> ms) =>
        RetrySettings(after: [for (final m in ms) Duration(milliseconds: m)]);

    ConnectFlow flow(
      _Vpn vpn, {
      ChecklistSettings? checklist,
      ChecklistSettings? Function()? settings,
    }) {
      vpn.checksSoFar = () => probed.length;
      final f = ConnectFlow(
        vpn: vpn,
        memory: PathMemory(),
        finder: PathFinder(
          read: (p) async {
            probed.add(p.pathKey);
            onProbe?.call();
            return openHere.contains(p.pathKey) ? open : closed;
          },
          internet: () async => true,
          budget: const Duration(milliseconds: 300),
        ),
        reporter: VpnEventReporter(
          send: (_, _, _) async {},
          sendProbes: (_, _, _) async {},
          deviceId: () async => 'DEV-1',
          appVersion: () async => '2.1.4',
          platform: 'android',
          networkType: () async => network,
        ),
        ipv6: Ipv6Reach(route: () async => null),
        networkKey: () async => network,
        carrier: () async => null,
        checklist: settings ?? () => checklist,
        random: () => 0.5,
        networkSettle: const Duration(milliseconds: 10),
        attemptTimeout: const Duration(seconds: 2),
      );
      addTearDown(f.cancel);
      return f;
    }

    test('the first dial of a tap may take the slot, the next doors of the '
        'same tap may not', () async {
      // The remembered door is dialled first, fails, and the search finds
      // another.
      await PathMemory().remember(network, hel1.pathKey);
      openHere = {hel2.pathKey};
      final vpn = _Vpn({hel2.pathKey});
      final f = flow(vpn);

      await f.connect(paths);
      await pumpEventQueue();

      expect(vpn.dialled, [hel1.pathKey, hel2.pathKey]);
      expect(vpn.tookSlot, [true, false]);
      expect(f.stage, ConnectStage.done);
    });

    test('a tap while another app\'s VPN is up takes the slot, as the user '
        'asked', () async {
      openHere = {hel1.pathKey};
      final vpn = _Vpn({hel1.pathKey})..other = true;
      final f = flow(vpn);

      await f.connect(paths);
      await pumpEventQueue();

      expect(vpn.tookSlot, [true]);
      expect(vpn.other, isFalse);
      expect(f.stage, ConnectStage.done);
      // Before the first door check, so the checks ran on the phone's own
      // network and not through the other app's VPN.
      expect(vpn.takenAtTap, [0]);
      expect(probed, isNotEmpty);
    });

    test('another app\'s VPN turned on during the tap\'s search: the tap '
        'gives way, with no next door and no retry', () async {
      openHere = {hel1.pathKey, hel2.pathKey};
      final vpn = _Vpn({hel2.pathKey});
      // The user gives up waiting and turns on Psiphon while the doors are
      // still checked.
      onProbe = () => vpn.other = true;
      final f = flow(vpn, checklist: ChecklistSettings(retry: waits([5])));

      await f.connect(paths);
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(vpn.dialled, [hel1.pathKey]);
      expect(vpn.tookSlot, [false]);
      expect(vpn.other, isTrue, reason: 'Psiphon stays on');
      expect(f.stage, ConnectStage.cancelled);
    });

    test('another app taking the slot between two doors of one tap ends the '
        'tap there', () async {
      await PathMemory().remember(network, hel1.pathKey);
      openHere = {hel2.pathKey};
      final vpn = _Vpn({hel2.pathKey});
      // The remembered door failed, and the user turns on Psiphon while the
      // search looks for another.
      onProbe = () => vpn.other = true;
      final f = flow(vpn, checklist: ChecklistSettings(retry: waits([5])));

      await f.connect(paths);
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(vpn.dialled, [hel1.pathKey, hel2.pathKey]);
      expect(vpn.tookSlot, [true, false]);
      expect(vpn.other, isTrue, reason: 'Psiphon stays on');
      expect(f.stage, ConnectStage.cancelled);
    });

    test('a wait to try again ends with no dial and no check once another '
        'app\'s VPN is up', () async {
      final vpn = _Vpn({});
      final f = flow(vpn, checklist: ChecklistSettings(retry: waits([20])));

      await f.connect(paths);
      expect(f.stage, ConnectStage.waiting);
      final checked = probed.length;
      vpn.other = true;
      await until(() => f.stage == ConnectStage.cancelled);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(vpn.dialled, isEmpty);
      expect(probed.length, checked);
      // Tap to connect: no error card left from the tap's own try.
      expect(vpn.gaveWay, greaterThan(0));
    });

    test('a tap that dialled nothing leaves its take to the first dial of a '
        'retry: after a reboot the retry still connects', () async {
      // Nothing has the slot: Android gives this app no tunnel until it
      // takes it. Until the fix of this test, such a retry never connected.
      final vpn = _Vpn({hel2.pathKey})..ours = false;
      final f = flow(vpn, checklist: ChecklistSettings(retry: waits([5])));

      await f.connect(paths);
      expect(f.stage, ConnectStage.waiting);
      expect(vpn.dialled, isEmpty);
      openHere = {hel2.pathKey};
      await until(() => f.stage == ConnectStage.done);

      expect(vpn.dialled, [hel2.pathKey]);
      expect(vpn.tookSlot, [true]);
    });

    test('a retry after a tap that dialled does not take the slot, and still '
        'connects while the slot is this app\'s', () async {
      openHere = {hel1.pathKey};
      final vpn = _Vpn({});
      final f = flow(vpn, checklist: ChecklistSettings(retry: waits([5])));

      await f.connect(paths);
      await until(() => f.stage == ConnectStage.waiting);
      expect(vpn.tookSlot, [true]);
      openHere = {hel2.pathKey};
      vpn.works.add(hel2.pathKey);
      await until(() => f.stage == ConnectStage.done);

      expect(vpn.dialled, [hel1.pathKey, hel2.pathKey]);
      expect(vpn.tookSlot, [true, false]);
    });

    test('a tap that gives way ends cancelled with no error left, also with '
        'no retry to try again', () async {
      await PathMemory().remember(network, hel1.pathKey);
      openHere = {hel2.pathKey, fsn1.pathKey};
      final vpn = _Vpn({hel2.pathKey, fsn1.pathKey});
      onProbe = () => vpn.other = true;
      final f = flow(vpn);

      await f.connect(paths);
      await pumpEventQueue();

      expect(vpn.tookSlot, [true, false]);
      expect(f.stage, ConnectStage.cancelled);
      expect(vpn.gaveWay, greaterThan(0));
    });

    test('a VPN for a few apps, turned on while a tap that dialled nothing '
        'waits, keeps the slot: the retry gives way', () async {
      // NPV Tunnel for Telegram alone, say. It does not carry this app, and
      // the retry runs minutes after the tap.
      final vpn = _Vpn({hel2.pathKey});
      final f = flow(vpn, checklist: ChecklistSettings(retry: waits([5])));

      await f.connect(paths);
      expect(f.stage, ConnectStage.waiting);
      vpn.forFewApps = true;
      openHere = {hel2.pathKey};
      await until(() => f.stage == ConnectStage.cancelled);

      expect(vpn.tookSlot, [false]);
      expect(vpn.forFewApps, isTrue, reason: 'it stays on');
      expect(vpn.gaveWay, greaterThan(0));
    });

    test('a VPN in a work profile, up at the tap, does not stop the take: '
        'after a reboot the retry still connects', () async {
      final vpn = _Vpn({hel2.pathKey})
        ..ours = false
        ..inWorkProfile = 1;
      final f = flow(vpn, checklist: ChecklistSettings(retry: waits([5])));

      await f.connect(paths);
      expect(f.stage, ConnectStage.waiting);
      openHere = {hel2.pathKey};
      await until(() => f.stage == ConnectStage.done);

      expect(vpn.tookSlot, [true]);
    });

    test('a VPN the user turns back on during the search, after the tap took '
        'the slot from it, stays on', () async {
      openHere = {hel1.pathKey};
      final vpn = _Vpn({hel1.pathKey})..other = true;
      // Psiphon back on as soon as the doors are checked, once.
      onProbe = () {
        if (vpn.takenAtTap.isNotEmpty && probed.length == 1) vpn.other = true;
      };
      final f = flow(vpn);

      await f.connect(paths);
      await pumpEventQueue();

      expect(vpn.takenAtTap, [0]);
      expect(vpn.tookSlot, [false]);
      expect(vpn.other, isTrue);
      expect(f.stage, ConnectStage.cancelled);
    });

    test('the search after a dead tunnel never takes the slot', () async {
      openHere = {hel1.pathKey};
      final vpn = _Vpn({hel1.pathKey});
      final f = flow(vpn);

      await f.connect(paths, afterStall: true);
      await pumpEventQueue();

      expect(vpn.tookSlot, [false]);
      expect(f.stage, ConnectStage.done);
    });

    test('a tap on a shared link takes the slot on its first dial', () async {
      // Since 2.2.0 the pick is checked before it is dialled.
      openHere = {picked.pathKey};
      final vpn = _Vpn({picked.pathKey});
      final f = flow(vpn);

      await f.connectShared(picked, shared: () async => const []);
      await pumpEventQueue();

      expect(vpn.dialled, [picked.pathKey]);
      expect(vpn.tookSlot, [true]);
    });

    test('a tap on a shared link while another app\'s VPN is up takes the '
        'slot before the pick\'s check', () async {
      openHere = {picked.pathKey};
      final vpn = _Vpn({picked.pathKey})..other = true;
      final f = flow(vpn);

      await f.connectShared(picked, shared: () async => const []);
      await pumpEventQueue();

      // Before the pick's check, so it ran on the phone's own network.
      expect(vpn.takenAtTap, [0]);
      expect(probed, [picked.pathKey]);
      expect(vpn.dialled, [picked.pathKey]);
      expect(vpn.other, isFalse);
      expect(f.stage, ConnectStage.done);
    });

    test('a tap on a picked shared link on a phone with its own servers takes '
        'the slot before the pick\'s check', () async {
      // dialServer's path for a link the user chose: connect with the pick.
      openHere = {picked.pathKey};
      final vpn = _Vpn({picked.pathKey})..other = true;
      final f = flow(vpn);

      await f.connect(paths, picked: picked);
      await pumpEventQueue();

      expect(vpn.takenAtTap, [0]);
      expect(probed.first, picked.pathKey);
      expect(vpn.dialled, [picked.pathKey]);
      expect(vpn.tookSlot, [true]);
      expect(f.stage, ConnectStage.done);
    });

    test('a pick replaced during the take of the slot leaves no retry of '
        'its own', () async {
      // The last tap ended with nothing open, and Psiphon is up now.
      ChecklistSettings? settings;
      final vpn = _Vpn({});
      final f = flow(vpn, settings: () => settings);
      await f.connect(paths);
      expect(f.stage, ConnectStage.nothingOpen);
      settings = ChecklistSettings(retry: waits([400]));
      vpn
        ..other = true
        ..takeTakes = const Duration(milliseconds: 60);

      // Each time the screen goes to the wait for the next try.
      var waitsShown = 0;
      var last = f.stage;
      f.addListener(() {
        if (f.stage == ConnectStage.waiting && last != ConnectStage.waiting) {
          waitsShown++;
        }
        last = f.stage;
      });

      // The user picks link 1, and link 2 while the slot is taken.
      unawaited(f.connect(paths, picked: picked));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      unawaited(f.connect(paths, picked: picked2));
      await until(
        () =>
            probed.contains(picked2.pathKey) && f.stage == ConnectStage.waiting,
      );

      // Link 1's tap was replaced before it checked anything, and it
      // schedules no try of its own. One put a wait on screen in the middle
      // of link 2's try and used up a try of the retries, so link 2's tap
      // ended with no wait of its own. With more tries left, link 1's wait
      // would fire first and try link 1 again.
      expect(waitsShown, 1);
      expect(probed, isNot(contains(picked.pathKey)));
      expect(vpn.dialled, isNot(contains(picked.pathKey)));
    });

    test('a tap on a shared link that hands over to the phone\'s own servers '
        'takes the slot once, before any check', () async {
      openHere = {picked.pathKey};
      final vpn = _Vpn({picked.pathKey})..other = true;
      final f = flow(vpn);

      await f.connectShared(
        picked,
        shared: () async => const [],
        own: () => paths,
        pickIsChoice: true,
      );
      await pumpEventQueue();

      expect(vpn.takenAtTap, [0]);
      expect(probed.first, picked.pathKey);
      expect(vpn.dialled, [picked.pathKey]);
      expect(f.stage, ConnectStage.done);
    });
  });

  test('on Android only a tap calls VpnService.prepare', () {
    // The calls that take the slot, as they stand. A new one takes the slot
    // from any other VPN app on the phone the moment it runs, so it belongs
    // here only if it runs for a tap. See VpnSlot.kt.
    const allowed = [
      // MainActivity.withVpnConsent, for a connect with take_slot.
      'MainActivity.kt: if (takeSlot) VpnService.prepare(this) else null',
      // MainActivity.onActivityResult, after the consent dialog of a tap.
      'MainActivity.kt: (try { VpnService.prepare(this) } catch (e: Exception) { null }) == null',
      // MainActivity.takeSlotForTap, before the search of a tap made while
      // another app's VPN is up.
      'MainActivity.kt: val asked = try { VpnService.prepare(this) } catch (e: Exception) { result.success(false); return }',
      // V2RayVpnService.onStartCommand, for a start with EXTRA_TAKE_SLOT.
      'V2RayVpnService.kt: if (takeSlot && prepare(this) != null) {',
    ];
    // Any argument: prepare(applicationContext) takes the slot too.
    final call = RegExp(r'VpnService\.prepare\(|(?<![.\w])prepare\(');
    final declares = RegExp(r'\bfun\s+prepare\(');
    final found = <String>[];
    final sources = Directory('android/app/src/main/java')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.kt') || f.path.endsWith('.java'));
    for (final file in sources) {
      for (final line in file.readAsLinesSync()) {
        final code = line.split('//').first.trim();
        if (code.startsWith('*') || code.startsWith('/*')) continue;
        if (declares.hasMatch(code)) continue;
        if (!call.hasMatch(code)) continue;
        found.add('${file.uri.pathSegments.last}: $code');
      }
    }
    expect(found, unorderedEquals(allowed));
  });

  test('on Android the tap reaches the service, and a taken slot reaches '
      'the app', () {
    // The lines that carry the tap from the app to onStartCommand, and the
    // slot_taken reason back. 9b83fd8 dropped the reason in MainActivity's
    // receiver, so a start that found the slot taken read as a failed door,
    // and the tap went on to the next ones. The receiver is in AppEngine
    // now, which keeps it for as long as the app's engine runs.
    const wiring = {
      'MainActivity.kt': [
        'private fun takeSlot(call: MethodCall): Boolean = call.argument<Boolean>("take_slot") == true',
        '"otherVpn" -> {',
        '"otherVpnCount" -> {',
        '"takeSlot" -> {',
      ],
      'AppEngine.kt': [
        'AppConfig.MSG_STATE_START_FAILURE -> eventSink?.success(withReason("failed", intent))',
      ],
      'V2RayServiceManager.kt': [
        'intent.putExtra(VpnSlot.EXTRA_TAKE_SLOT, takeSlot)',
        // The tile and the widget start only on a tap.
        'startContextService(context, takeSlot = true)',
      ],
      'V2RayVpnService.kt': [
        'val takeSlot = intent?.getBooleanExtra(VpnSlot.EXTRA_TAKE_SLOT, false) == true',
        'if (established == null) return Setup.SLOT_TAKEN',
        'MessageUtil.sendMsg2UI(this@V2RayVpnService, AppConfig.MSG_STATE_START_FAILURE, VpnSlot.SLOT_TAKEN)',
      ],
    };
    final sources = {
      for (final f
          in Directory('android/app/src/main/java')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.kt')))
        f.uri.pathSegments.last: f.readAsLinesSync().map((l) => l.trim()),
    };
    for (final MapEntry(key: file, value: lines) in wiring.entries) {
      for (final line in lines) {
        expect(
          sources[file]!.contains(line),
          isTrue,
          reason: '$file no longer has: $line',
        );
      }
    }
    expect(startFailedSlotTaken, 'slot_taken', reason: 'VpnSlot.SLOT_TAKEN');
  });
}
