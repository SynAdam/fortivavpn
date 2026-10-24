import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/stall_recovery.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/stall_watch.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tunnel that is up and carries nothing (#289): the drop it is filed as,
/// the rows it must not get afterwards, and the search that replaces it.
Server door(String host, String door) => Server(
  id: 'dedicated-$host:443',
  name: host,
  country: '',
  city: host,
  connectionUri: 'vless://u@$host:443?type=tcp#$host',
  flagEmoji: '🌍',
  isDedicated: true,
  door: door,
  doorLabel: door,
  serverId: 7,
);

final hel = door('hel', 'xhttp-reality');
final fsn = door('fsn', 'grpc-reality');

const finding = StallFinding(
  trigger: StallWatch.triggerCounters,
  probes: 3,
  quietFor: Duration(minutes: 3),
  up: 5200,
  down: 0,
);

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
  }) async => const {'tcp': 'ok'};

  @override
  Future<Map<String, dynamic>> platformReport() async => const {};
}

/// A tunnel whose dead state the test sets, and whose replacement or
/// teardown it records.
class _Vpn extends VpnService {
  _Vpn() : super(events: VpnEventReporter(send: (_, _, _) async {}));

  bool dead = true;
  bool connected = true;
  int drops = 0;
  int checks = 0;
  Server? active = hel;

  /// What an app reopened over the tunnel kept of the door it is on, when
  /// it has no doors of its own ([active] null).
  String? keptKey;

  @override
  bool get isConnected => connected;

  @override
  bool get isVerifying => false;

  @override
  bool get stalled => dead && connected;

  @override
  Server? get activeDoor => active;

  @override
  String? get activeDoorKey => active?.pathKey ?? keptKey;

  @override
  Future<void> dropStalled() async {
    drops++;
    connected = false;
    notifyListeners();
  }

  @override
  Future<void> checkStall() async => checks++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
  const statusChannel = EventChannel('com.vpn.fortivavpn/tunnel/status');
  late List<String> calls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(tunnel, (call) async {
      calls.add(call.method);
      return call.method == 'getStatus' ? 'disconnected' : null;
    });
    messenger.setMockStreamHandler(
      statusChannel,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(tunnel, null);
    messenger.setMockStreamHandler(statusChannel, null);
  });

  group('the service', () {
    late _Reporter reporter;
    late VpnService service;
    late int told;

    setUp(() {
      reporter = _Reporter();
      service = VpnService(events: reporter, diagnostics: _NoDiagnostics());
      service.debugDoors = [hel, fsn];
      told = 0;
      service.onStall = () => told++;
      service.applyNativeStatus('connected');
    });

    tearDown(() => service.dispose());

    Iterable<_Row> ends() => reporter.rows.where(
      (r) =>
          r.type == VpnEventType.dropped || r.type == VpnEventType.disconnected,
    );

    test('files one drop with the reason and what the watch saw', () async {
      service.debugStall(finding);
      service.debugStall(finding);
      await Future<void>.delayed(Duration.zero);

      final row = ends().single;
      expect(row.type, VpnEventType.dropped);
      expect(row.error, dropReasonStalled);
      expect(row.diag, containsPair('drop_reason', 'stalled'));
      expect(row.diag, containsPair('stall_trigger', 'counters'));
      expect(row.diag, containsPair('stall_quiet_s', 180));
      // The checks run on the phone's own network, around the tunnel.
      expect(row.diag, containsPair('tcp', 'ok'));
      expect(service.stalled, isTrue);
      expect(told, 1);
    });

    test('the tunnel then going down files nothing more', () async {
      service.debugStall(finding);
      service.applyNativeStatus('disconnected');
      await Future<void>.delayed(Duration.zero);

      expect(ends(), hasLength(1));
      expect(service.stalled, isFalse);
    });

    test('a user stop after it files nothing more', () async {
      service.debugStall(finding);
      await service.disconnect();
      service.applyNativeStatus('disconnected');
      await Future<void>.delayed(Duration.zero);

      expect(ends(), hasLength(1));
      expect(calls, contains('disconnect'));
    });

    test('taking it down through dropStalled files nothing more', () async {
      service.debugStall(finding);
      await service.dropStalled();
      service.applyNativeStatus('disconnected');
      await Future<void>.delayed(Duration.zero);

      expect(ends(), hasLength(1));
    });

    test('dropStalled leaves a live tunnel alone', () async {
      await service.dropStalled();
      expect(calls, isNot(contains('disconnect')));
    });

    test('another door replacing it files no disconnect', () async {
      service.debugStall(finding);
      service.connect(fsn).ignore();
      // At once, so a recovery waiting on it does not take down the new one.
      expect(service.stalled, isFalse);
      await pumpEventQueue();

      expect(ends(), hasLength(1));
      expect(ends().single.type, VpnEventType.dropped);
    });

    test('a tunnel replaced without a stall is closed as before', () async {
      service.connect(fsn).ignore();
      await Future<void>.delayed(Duration.zero);

      expect(ends().single.type, VpnEventType.disconnected);
    });
  });

  group('the recovery', () {
    late _Vpn vpn;
    late ConnectFlow flow;
    late PathMemory memory;
    late int redials;
    late void Function() onRedial;
    // Whether the phone reaches a site abroad when the recovery asks.
    late bool online;

    setUp(() async {
      vpn = _Vpn();
      memory = PathMemory();
      await memory.remember('wifi:home', hel.pathKey);
      online = true;
      flow = ConnectFlow(
        vpn: vpn,
        memory: memory,
        finder: PathFinder(
          probe: (_) async => -1,
          internet: () async => online,
        ),
        networkKey: () async => 'wifi:home',
      );
      redials = 0;
      onRedial = () {};
    });

    StallRecovery recovery() => StallRecovery(
      vpn: vpn,
      flow: flow,
      watchApp: false,
      redial: () async {
        redials++;
        onRedial();
      },
    );

    test('forgets the dead door and searches again', () async {
      onRedial = () => vpn.dead = false;
      await recovery().recover();

      expect(redials, 1);
      expect(await memory.recall('wifi:home'), isNull);
      expect(await memory.failedToday('wifi:home'), contains(hel.pathKey));
      // Another door replaced the tunnel.
      expect(vpn.drops, 0);
    });

    test('keeps the door of a phone whose own internet is gone, and still '
        'searches', () async {
      // 248 of 493 dead tunnels in the 72 hours to 2026-10-20 21:00 UTC:
      // the door is not at fault, and is the one to dial first once the
      // internet is back.
      online = false;
      await recovery().recover();

      expect(redials, 1);
      expect(await memory.recall('wifi:home'), hel.pathKey);
      expect(await memory.failedToday('wifi:home'), isEmpty);
      expect(vpn.drops, 1);
    });

    test('forgets the door an app reopened over the tunnel kept', () async {
      // A reopened app has no list of doors, only the key the attempt kept
      // (VpnService.activeDoorKey). Until 2.2.0 it forgot nothing, and the
      // search dialled the dead door first again.
      vpn.active = null;
      vpn.keptKey = hel.pathKey;
      onRedial = () => vpn.dead = false;
      await recovery().recover();

      expect(redials, 1);
      expect(await memory.recall('wifi:home'), isNull);
      expect(await memory.failedToday('wifi:home'), contains(hel.pathKey));
    });

    test('takes the dead tunnel down when nothing replaced it', () async {
      await recovery().recover();

      expect(redials, 1);
      expect(vpn.drops, 1);
    });

    test('is what the service tells about a dead tunnel', () async {
      onRedial = () => vpn.dead = false;
      recovery();
      vpn.onStall!();
      await pumpEventQueue();

      expect(redials, 1);
    });

    test('does nothing for a tunnel that is not dead', () async {
      vpn.dead = false;
      await recovery().recover();

      expect(redials, 0);
      expect(await memory.recall('wifi:home'), hel.pathKey);
    });

    test('runs one search at a time', () async {
      final r = recovery();
      onRedial = () => vpn.dead = false;
      await Future.wait([r.recover(), r.recover()]);

      expect(redials, 1);
    });

    test('lets go of the service when disposed', () {
      final r = recovery();
      expect(vpn.onStall, isNotNull);
      r.dispose();
      expect(vpn.onStall, isNull);
    });
  });

  group('the switch', () {
    test('is on unless the config says false', () {
      expect(FeatureFlags.fromJson(const {}).stallWatch, isTrue);
      expect(
        FeatureFlags.fromJson(const {'stall_watch': true}).stallWatch,
        isTrue,
      );
      expect(
        FeatureFlags.fromJson(const {'stall_watch': false}).stallWatch,
        isFalse,
      );
      // A value of the wrong type does not throw the config away.
      expect(
        FeatureFlags.fromJson(const {'stall_watch': 'off'}).stallWatch,
        isTrue,
      );
      expect(
        FeatureFlags.fromJson(const {'stall_watch': false}).toJson(),
        containsPair('stall_watch', false),
      );
    });

    test('off keeps the watch from starting', () async {
      StallWatch.enabled = false;
      StallWatch.androidOverride = true;
      addTearDown(() {
        StallWatch.enabled = true;
        StallWatch.androidOverride = null;
      });
      final service = VpnService(
        events: _Reporter(),
        diagnostics: _NoDiagnostics(),
      );
      addTearDown(service.dispose);
      service.applyNativeStatus('connected');
      await pumpEventQueue();

      expect(service.stallWatch.active, isFalse);
    });

    test('on, a verified tunnel on Android is watched', () async {
      StallWatch.androidOverride = true;
      addTearDown(() => StallWatch.androidOverride = null);
      final service = VpnService(
        events: _Reporter(),
        diagnostics: _NoDiagnostics(),
      );
      addTearDown(service.dispose);
      service.applyNativeStatus('connected');
      await pumpEventQueue();
      expect(service.stallWatch.active, isTrue);

      service.debugStall(finding);
      expect(service.stallWatch.active, isFalse);
    });
  });
}
