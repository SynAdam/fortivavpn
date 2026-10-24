import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/connection_data.dart';
import 'package:fortiva_vpn/data/models/psiphon_settings.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the tunnel dials the backup network (clients #299): the platform's
/// `connectPsiphon` with the settings the backend sent, a start that gets
/// the network's own time to come up, and events that name the session
/// "psiphon" and never an address of the network's. Every value of the
/// network's settings here is made up.
const network = {
  'PropagationChannelId': '0123456789ABCDEF',
  'SponsorId': '0123456789ABCDEF',
  'RemoteServerListURLs': ['https://lists.example.test/list'],
};

PsiphonSettings backup({String egress = '', int establishSeconds = 90}) =>
    PsiphonSettings(
      network: network,
      enabled: true,
      egressRegion: egress,
      establishTimeout: Duration(seconds: establishSeconds),
    );

class _Row {
  _Row(this.type, this.host, this.door, this.strategy, this.diag);
  final VpnEventType type;
  final String? host;
  final String? door;
  final Map<String, dynamic>? strategy;
  final Map<String, dynamic>? diag;
}

class _Reporter extends VpnEventReporter {
  _Reporter() : super(send: (_, _, _) async {}, queues: const []);

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
    rows.add(_Row(type, serverHost, door, strategy, diag));
  }
}

/// Records the host every diagnosis was asked to check.
class _Diagnostics extends ConnectDiagnostics {
  final hosts = <String?>[];

  @override
  Future<Map<String, dynamic>> collect({
    String? host,
    int port = 443,
    String? sni,
  }) async {
    hosts.add(host);
    return const {'control': 'ok'};
  }

  @override
  Future<Map<String, dynamic>> platformReport() async => const {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.vpn.fortivavpn/tunnel');
  late List<MethodCall> calls;
  late Object? Function(MethodCall call) answer;
  late Map<String, dynamic> stats;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return answer(call);
        });
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    stats = {'bytes_up': 10, 'bytes_down': 20};
    answer = (call) => switch (call.method) {
      'getStatus' => 'disconnected',
      'tunnelStats' => stats,
      _ => null,
    };
    install();
    PsiphonSettings.current = null;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    PsiphonSettings.current = null;
    ConnectionData.current = ConnectionData.off;
  });

  VpnService service({
    PsiphonSettings? settings,
    _Reporter? reporter,
    _Diagnostics? diagnostics,
    Future<String?> Function(PsiphonSettings settings)? entries,
  }) {
    final s = VpnService(
      events: reporter ?? _Reporter(),
      diagnostics: diagnostics ?? _Diagnostics(),
      psiphon: () => settings,
      psiphonEntries: entries ?? (_) async => null,
    );
    addTearDown(s.dispose);
    return s;
  }

  MethodCall? callOf(String method) =>
      calls.where((c) => c.method == method).lastOrNull;

  group('the dial', () {
    test('goes to connectPsiphon with the network, the time it has to come '
        'up and the session readings', () async {
      ConnectionData.current = const ConnectionData(
        sessionSample: Duration(seconds: 30),
        stallAfter: Duration(seconds: 90),
        busyBytes: 4096,
      );
      final vpn = service(settings: backup(egress: 'CA'));

      await vpn.connect(Server.psiphon, attemptId: 'a' * 32);

      expect(callOf('connect'), isNull);
      final args = Map<String, dynamic>.from(
        callOf('connectPsiphon')!.arguments as Map,
      );
      expect(args.keys.toSet(), {
        'config',
        'establish_timeout_ms',
        'session_sample_ms',
        'session_stall_ms',
        'session_busy_bytes',
      });
      expect(jsonDecode(args['config'] as String), {
        ...network,
        'EgressRegion': 'CA',
      });
      expect(args['establish_timeout_ms'], 90000);
      expect(args['session_sample_ms'], 30000);
      expect(args['session_stall_ms'], 90000);
      expect(args['session_busy_bytes'], 4096);
      expect(vpn.status, VpnStatus.connecting);
      expect(vpn.onPsiphon, isTrue);
    });

    test('no exit region when the backend sets none, and the readings off '
        'when it turns them off', () async {
      final vpn = service(settings: backup());

      await vpn.connect(Server.psiphon);

      final args = callOf('connectPsiphon')!.arguments as Map;
      final config = jsonDecode(args['config'] as String) as Map;
      expect(config.containsKey('EgressRegion'), isFalse);
      expect(config, network);
      expect(args['session_sample_ms'], 0);
      expect(args['session_stall_ms'], 0);
      expect(args['session_busy_bytes'], 0);
    });

    test('hands the tunnel the server list kept on the phone, when it is '
        'the one the settings name', () async {
      const sha =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      const path =
          '/data/user/0/com.vpn.fortivavpn/files/psiphon/'
          'server_entries';
      final asked = <PsiphonSettings>[];
      final settings = PsiphonSettings(
        network: network,
        enabled: true,
        serverEntriesSha: sha,
      );
      final vpn = service(
        settings: settings,
        entries: (s) async {
          asked.add(s);
          return path;
        },
      );

      await vpn.connect(Server.psiphon);

      final args = callOf('connectPsiphon')!.arguments as Map;
      expect(args['server_entries_file'], path);
      expect(asked, [same(settings)]);
      // Only the path: the list itself never goes over the channel.
      expect(args.keys.toSet(), {
        'config',
        'establish_timeout_ms',
        'server_entries_file',
        'session_sample_ms',
        'session_stall_ms',
        'session_busy_bytes',
      });
    });

    test('without a kept list for the settings, no server list goes to '
        'the tunnel', () async {
      final vpn = service(settings: backup(), entries: (_) async => null);

      await vpn.connect(Server.psiphon);

      final args = callOf('connectPsiphon')!.arguments as Map;
      expect(args.containsKey('server_entries_file'), isFalse);
    });

    test('a link never asks for the server list', () async {
      var asked = 0;
      final vpn = service(
        settings: backup(),
        entries: (_) async {
          asked++;
          return '/files/psiphon/server_entries';
        },
      );

      await vpn.connect(
        const Server(
          id: 'official-1',
          name: 'DE',
          country: '',
          city: '',
          connectionUri: 'vless://u@de.example:443?type=tcp#de',
          flagEmoji: '',
        ),
      );

      expect(asked, 0);
      expect(
        (callOf('connect')!.arguments as Map).containsKey(
          'server_entries_file',
        ),
        isFalse,
      );
    });

    test('a stop while the list is looked for dials nothing', () async {
      final looking = Completer<String?>();
      final vpn = service(settings: backup(), entries: (_) => looking.future);

      final dial = vpn.connect(Server.psiphon);
      await pumpEventQueue();
      await vpn.disconnect();
      looking.complete('/files/psiphon/server_entries');
      await dial;

      expect(callOf('connectPsiphon'), isNull);
    });

    test('reads the settings in force when none are passed in', () async {
      PsiphonSettings.current = backup(egress: 'DE');
      final vpn = VpnService(events: _Reporter(), diagnostics: _Diagnostics());
      addTearDown(vpn.dispose);

      await vpn.connect(Server.psiphon);

      final args = callOf('connectPsiphon')!.arguments as Map;
      expect(jsonDecode(args['config'] as String)['EgressRegion'], 'DE');
    });

    test('a link is dialled as before, and clears nothing of the backup '
        'network\'s on its own', () async {
      final vpn = service(settings: backup());
      const own = Server(
        id: 'dedicated-hel.example:443',
        name: 'Helsinki',
        country: 'Finland',
        city: 'Helsinki',
        connectionUri: 'vless://u@hel.example:443?type=tcp#hel',
        flagEmoji: '',
        isDedicated: true,
        door: 'tcp-reality',
      );

      await vpn.connect(own);

      expect(callOf('connectPsiphon'), isNull);
      expect(callOf('connect'), isNotNull);
      expect(vpn.onPsiphon, isFalse);
    });

    test('with the network turned off meanwhile, the attempt fails and '
        'nothing is dialled', () async {
      final vpn = service(settings: null);

      await vpn.connect(Server.psiphon);

      expect(callOf('connectPsiphon'), isNull);
      expect(callOf('connect'), isNull);
      expect(vpn.status, VpnStatus.error);
    });

    test('a refused permission is reported as on any dial', () async {
      answer = (call) => call.method == 'connectPsiphon'
          ? throw PlatformException(code: 'PERMISSION_DENIED')
          : null;
      final vpn = service(settings: backup());

      await vpn.connect(Server.psiphon);

      expect(vpn.status, VpnStatus.error);
      expect(vpn.failedOnPermission, isTrue);
    });
  });

  group('the start\'s own time', () {
    test('is the network\'s time to come up plus the usual building', () {
      fakeAsync((async) {
        install();
        final vpn = VpnService(
          events: VpnEventReporter(send: (_, _, _) async {}, queues: const []),
          diagnostics: _Diagnostics(),
          psiphon: () => backup(establishSeconds: 60),
        );
        unawaited(vpn.connect(Server.psiphon).catchError((_) {}));
        async.flushMicrotasks();

        // A link's start would have been failed at 20 seconds.
        async.elapse(const Duration(seconds: 70));
        async.flushMicrotasks();
        expect(vpn.status, VpnStatus.connecting);

        async.elapse(const Duration(seconds: 6));
        async.flushMicrotasks();
        expect(vpn.status, VpnStatus.error);
        vpn.dispose();
      });
    });

    test('a link after it gets the usual time again', () {
      fakeAsync((async) {
        install();
        final vpn = VpnService(
          events: VpnEventReporter(send: (_, _, _) async {}, queues: const []),
          diagnostics: _Diagnostics(),
          psiphon: () => backup(establishSeconds: 60),
        );
        unawaited(vpn.connect(Server.psiphon).catchError((_) {}));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        const link = Server(
          id: 'official-1',
          name: 'DE',
          country: '',
          city: '',
          connectionUri: 'vless://u@de.example:443?type=tcp#de',
          flagEmoji: '',
        );
        unawaited(vpn.connect(link).catchError((_) {}));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 22));
        async.flushMicrotasks();
        expect(vpn.status, VpnStatus.error);
        vpn.dispose();
      });
    });
  });

  group('what its events say', () {
    test('the server is "psiphon", no door, and the strategy names the '
        'source', () async {
      answer = (call) => call.method == 'connectPsiphon'
          ? throw PlatformException(code: 'START_FAILED')
          : null;
      final reporter = _Reporter();
      final diagnostics = _Diagnostics();
      final vpn = service(
        settings: backup(),
        reporter: reporter,
        diagnostics: diagnostics,
      );

      await expectLater(
        vpn.connect(Server.psiphon),
        throwsA(isA<PlatformException>()),
      );
      await pumpEventQueue();

      final row = reporter.rows.singleWhere(
        (r) => r.type == VpnEventType.connectFailed,
      );
      expect(row.host, 'psiphon');
      expect(row.door, isNull);
      expect(row.strategy, {'src': 'psiphon', 'egress': ''});
      // No server of ours to check: only the control fetch and the
      // platform report run.
      expect(diagnostics.hosts, [null]);
    });

    test('the exit region, once the tunnel says it, and nothing else the '
        'network says', () async {
      final reporter = _Reporter();
      final vpn = service(settings: backup(), reporter: reporter);
      await vpn.connect(Server.psiphon);

      stats = {
        'bytes_up': 1,
        'bytes_down': 2,
        'psiphon_region': 'DE',
        'client_region': 'IR',
        'client_address': '198.51.100.7',
      };
      await vpn.tunnelBytesDown();
      expect(vpn.psiphonRegion, 'DE');

      await vpn.reportDrop('psiphon', null, null, 'killed');
      final row = reporter.rows.last;
      expect(row.type, VpnEventType.dropped);
      expect(row.host, 'psiphon');
      expect(row.door, isNull);
      expect(row.strategy, {'src': 'psiphon', 'egress': 'DE'});
      expect('${row.diag}', isNot(contains('IR')));
      expect('${row.diag}', isNot(contains('198.51.100.7')));
    });

    test('a region that is not two capital letters is not taken', () async {
      final vpn = service(settings: backup());
      await vpn.connect(Server.psiphon);

      for (final region in ['de', 'DEU', '', 7]) {
        stats = {'bytes_up': 1, 'bytes_down': 2, 'psiphon_region': region};
        await vpn.tunnelBytesDown();
        expect(vpn.psiphonRegion, isNull);
      }
    });

    test('a link\'s session takes no region', () async {
      final vpn = service(settings: backup());
      await vpn.connect(
        const Server(
          id: 'official-1',
          name: 'DE',
          country: '',
          city: '',
          connectionUri: 'vless://u@de.example:443?type=tcp#de',
          flagEmoji: '',
        ),
      );
      stats = {'bytes_up': 1, 'bytes_down': 2, 'psiphon_region': 'DE'};
      await vpn.tunnelBytesDown();
      expect(vpn.psiphonRegion, isNull);
    });

    test('a heartbeat names no door and no door move, whatever the reading '
        'says', () async {
      final reporter = _Reporter();
      final vpn = service(settings: backup(), reporter: reporter);
      await vpn.connect(Server.psiphon, attemptId: 'd' * 32);
      vpn.applyNativeStatus('connected');
      // The traffic check would run next, through no tunnel: end it.
      vpn.debugVerifying = false;
      stats = {
        'bytes_up': 100,
        'bytes_down': 200,
        'carrier': 'Irancell',
        'door_index': 1,
        'door_status': jsonEncode({
          'state': 'ok',
          'switch_count': 1,
          'switches': [
            {'from': 0, 'to': 1, 'reason': 'failover', 'at': 5},
          ],
          'doors': [
            {'index': 0},
          ],
        }),
        'psiphon_region': 'CA',
      };

      await vpn.sendHeartbeat();

      expect(
        reporter.rows.where((r) => r.type == VpnEventType.doorSwitched),
        isEmpty,
      );
      final beat = reporter.rows.singleWhere(
        (r) => r.type == VpnEventType.heartbeat,
      );
      expect(beat.host, 'psiphon');
      expect(beat.door, isNull);
      expect(beat.strategy, {'src': 'psiphon', 'egress': 'CA'});
      expect(beat.diag?['carrier'], 'Irancell');
      expect(beat.diag?.containsKey('door_states'), isFalse);
      expect(vpn.activeDoor, Server.psiphon);
    });

    test('a heartbeat says when the network has a newer client', () async {
      final reporter = _Reporter();
      final vpn = service(settings: backup(), reporter: reporter);
      await vpn.connect(Server.psiphon, attemptId: 'e' * 32);
      vpn.applyNativeStatus('connected');
      vpn.debugVerifying = false;

      stats = {'bytes_up': 1, 'bytes_down': 2};
      await vpn.sendHeartbeat();
      stats = {'bytes_up': 3, 'bytes_down': 4, 'psiphon_upgrade': '412'};
      await vpn.sendHeartbeat();

      final beats = reporter.rows
          .where((r) => r.type == VpnEventType.heartbeat)
          .toList();
      expect(beats, hasLength(2));
      expect(beats[0].diag?.containsKey('psiphon_upgrade'), isFalse);
      expect(beats[1].diag?['psiphon_upgrade'], '412');
    });

    test('a value that is not a version is not sent', () async {
      final reporter = _Reporter();
      final vpn = service(settings: backup(), reporter: reporter);
      await vpn.connect(Server.psiphon, attemptId: 'f' * 32);
      vpn.applyNativeStatus('connected');
      vpn.debugVerifying = false;

      for (final bad in <Object?>['', '1.2', 'v9', '198.51.100.7', 412]) {
        stats = {'bytes_up': 1, 'bytes_down': 2, 'psiphon_upgrade': bad};
        await vpn.sendHeartbeat();
      }

      final beats = reporter.rows.where(
        (r) => r.type == VpnEventType.heartbeat,
      );
      expect(beats, hasLength(5));
      for (final beat in beats) {
        expect(beat.diag?.containsKey('psiphon_upgrade'), isFalse);
      }
    });

    test('a link\'s heartbeat never carries it', () async {
      final reporter = _Reporter();
      final vpn = service(settings: backup(), reporter: reporter);
      await vpn.connect(
        const Server(
          id: 'official-1',
          name: 'DE',
          country: '',
          city: '',
          connectionUri: 'vless://u@de.example:443?type=tcp#de',
          flagEmoji: '',
        ),
        attemptId: 'a' * 32,
      );
      vpn.applyNativeStatus('connected');
      vpn.debugVerifying = false;
      stats = {'bytes_up': 1, 'bytes_down': 2, 'psiphon_upgrade': '412'};

      await vpn.sendHeartbeat();

      final beat = reporter.rows.singleWhere(
        (r) => r.type == VpnEventType.heartbeat,
      );
      expect(beat.diag?.containsKey('psiphon_upgrade'), isFalse);
    });

    test('a diagnosis never checks a host called "psiphon"', () async {
      final diagnostics = _Diagnostics();
      final vpn = service(settings: backup(), diagnostics: diagnostics);

      await vpn.diagnose('psiphon', 'psiphon://');

      expect(diagnostics.hosts, [null]);
    });
  });

  group('an app reopened over it', () {
    test('still knows the tunnel goes through the backup network, and where '
        'it leaves', () async {
      // What a session through the backup network left on the phone when
      // the app was closed over it (see the test below).
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('vpn_connected_server_id', Server.psiphonId);
      await prefs.setString('vpn_connected_server_name', Server.psiphonName);
      await prefs.setString(
        'vpn_connected_start_time',
        DateTime.now().toIso8601String(),
      );
      await prefs.setString(
        'vpn_connected_attempt',
        jsonEncode({
          'attempt_id': 'b' * 32,
          'door_index': 0,
          'strategy': {'src': 'psiphon', 'egress': 'NL'},
          'server_host': 'psiphon',
        }),
      );

      final reopened = service(settings: backup());
      reopened.applyNativeStatus('connected');
      await pumpEventQueue();

      expect(reopened.isConnected, isTrue);
      expect(reopened.onPsiphon, isTrue);
      expect(reopened.psiphonRegion, 'NL');
      expect(reopened.currentConnection?.serverName, Server.psiphonName);
    });

    test('what the tunnel writes down when it comes up says so', () async {
      final vpn = service(settings: backup());
      await vpn.connect(Server.psiphon, attemptId: 'c' * 32);
      vpn.applyNativeStatus('connected');
      await pumpEventQueue();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('vpn_connected_server_id'), Server.psiphonId);
      expect(prefs.getString('vpn_connected_server_name'), Server.psiphonName);
      final attempt =
          jsonDecode(prefs.getString('vpn_connected_attempt')!) as Map;
      expect(attempt['server_host'], 'psiphon');
      expect(attempt['strategy'], {'src': 'psiphon', 'egress': ''});
      expect(attempt.containsKey('door'), isFalse);
      expect(attempt.containsKey('link'), isFalse);
      // The traffic check would run next, through no tunnel: end it.
      vpn.debugVerifying = false;
    });
  });
}
