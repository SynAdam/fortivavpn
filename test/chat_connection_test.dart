import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/support_service.dart';
import 'package:fortiva_vpn/core/state/chat_connection.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/support_state.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/data/models/support_chat.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/door_sweep.dart';
import 'package:fortiva_vpn/services/ipv6_reach.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/stall_watch.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What a chat message says about the connection (chatConnected,
/// chatSearching), as main.dart hands it to SupportState.
///
/// Found in review on 2026-10-24: during the search StallRecovery runs
/// after a dead tunnel, the tunnel is still up, and a message said
/// connected and searching at once. The backend reads connected first, so
/// the assistant was told the phone was connected while the app was
/// looking for another way.

final _t0 = DateTime.utc(2026, 10, 24, 12);

Server door(String host, String door, {int? serverId}) => Server(
  id: 'dedicated-$host:443',
  name: host,
  country: '',
  city: host,
  connectionUri: 'vless://u@$host:443?type=tcp#$host',
  flagEmoji: '',
  isDedicated: true,
  door: door,
  doorLabel: door,
  serverId: serverId,
);

/// A tunnel that is up and past its traffic check. A dial fails.
class _UpVpn extends VpnService {
  _UpVpn()
    : super(
        events: VpnEventReporter(send: (_, _, _) async {}),
        diagnostics: ConnectDiagnostics(),
      );

  VpnStatus _status = VpnStatus.connected;
  final dialled = <String>[];

  @override
  VpnStatus get status => _status;
  @override
  bool get isConnected => _status == VpnStatus.connected;
  @override
  bool get isConnecting => _status == VpnStatus.connecting;
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
    _status = VpnStatus.connecting;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    _status = VpnStatus.error;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _status = VpnStatus.disconnected;
    notifyListeners();
  }
}

Map<String, dynamic> _quota() => {
  'limit': 10,
  'remaining': 7,
  'conversation_limit': 6,
  'conversation_left': 4,
  'resets_at': _t0.add(const Duration(hours: 8)).toIso8601String(),
  'conversation_resets_at': null,
  'paused_until': null,
  'server_time': _t0.toIso8601String(),
};

/// The chat's backend: it keeps every message sent.
class _Backend implements SupportService {
  final sent = <Map<String, dynamic>>[];

  @override
  Future<SupportStatus> status(String deviceId) async =>
      SupportStatus.fromJson({
        'enabled': true,
        'mode': 'ai',
        'quota': _quota(),
        'thread': {'id': 1, 'ticket': 'none'},
        'pending': false,
      });

  @override
  Future<SupportPage> fetch(String deviceId, int after, String lang) async =>
      SupportPage.fromJson({
        'server_time': _t0.toIso8601String(),
        'mode': 'ai',
        'quota': _quota(),
        'pending': false,
        'messages': [],
      });

  @override
  Future<SupportReply> send(String deviceId, Map<String, dynamic> body) async {
    sent.add(body);
    return SupportReply.fromJson({
      'message': {
        'id': 100 + sent.length,
        'client_id': body['client_id'],
        'role': 'user',
        'status': 'queued',
        'code': null,
        'redacted': false,
        'text': body['text'],
        'rating': null,
        'created_at': _t0.toIso8601String(),
      },
      'quota': _quota(),
      'thread': {'id': 1, 'ticket': 'none'},
      'mode': 'ai',
    });
  }

  @override
  Future<void> rate(String deviceId, int messageId, String value) async {}

  @override
  Future<SupportReply> startNew(String deviceId) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final paths = [door('hel', 'a', serverId: 7), door('fsn', 'b', serverId: 8)];

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ConnectFlow flowFor(VpnService vpn) {
    final reporter = VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, _, _) async {},
      deviceId: () async => 'DEV-1',
      appVersion: () async => '2.2.0',
      platform: 'android',
      networkType: () async => 'mobile',
      queues: const [],
    );
    final flow = ConnectFlow(
      vpn: vpn,
      memory: PathMemory(),
      finder: PathFinder(
        // Slow checks, so the search is still running when the message goes.
        read: (p) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return const DoorOutcome(ms: -1, error: 'tcp timeout', phase: 'tcp');
        },
        internet: () async => true,
      ),
      reporter: reporter,
      sweep: DoorSweep(appBypassesTunnel: true, reporter: reporter),
      ipv6: Ipv6Reach(route: () async => null),
      networkKey: () async => 'mobile:Irancell',
      carrier: () async => 'Irancell',
      checklist: () => const ChecklistSettings(
        doors: DoorCheckSettings(parallel: 1, stagger: Duration.zero),
      ),
    );
    addTearDown(flow.cancel);
    return flow;
  }

  /// The chat as main.dart builds it, as far as a message's connection
  /// goes. Sharing is off, so the context holds only that.
  SupportState chatFor(VpnService vpn, ConnectFlow flow, _Backend backend) {
    var ids = 0;
    final chat = SupportState(
      service: backend,
      deviceId: () async => 'DEV-1',
      register: () async {},
      sharing: () async => false,
      phone: () async => const {},
      connected: () => chatConnected(vpn),
      searching: () => chatSearching(vpn, flow),
      language: () => 'fa',
      clock: () => _t0,
      foreground: () => true,
      newClientId: () => 'client-${ids++}',
    );
    addTearDown(chat.dispose);
    return chat;
  }

  test('a message sent during the search after a dead tunnel says not '
      'connected and searching', () async {
    final vpn = _UpVpn();
    final flow = flowFor(vpn);
    final backend = _Backend();
    final chat = chatFor(vpn, flow, backend);

    vpn.debugStall(
      const StallFinding(
        trigger: StallWatch.triggerCounters,
        probes: 3,
        quietFor: Duration(minutes: 1),
      ),
    );
    // StallRecovery.recover runs dialServer(afterStall: true).
    final search = flow.connect(paths, afterStall: true);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    // The dead tunnel is still up, and no door has been dialled yet.
    expect(vpn.isConnected, isTrue);
    expect(vpn.stalled, isTrue);
    expect(flow.afterStall, isTrue);
    expect(vpn.dialled, isEmpty);

    await chat.checkStatus(force: true);
    await chat.send('چرا قطع شد');
    expect(backend.sent.single['context'], {
      'connected': false,
      'searching': true,
      'play_billing': false,
    });

    flow.cancel();
    await search;
  });

  test('a message sent after a dead tunnel, before its search starts, says '
      'not connected and searching', () async {
    // Found 2026-10-24 in review of 1a49037: StallRecovery first asks
    // whether the phone reaches a site abroad, and a message sent then
    // said not connected and not searching, which the backend reads as off.
    final vpn = _UpVpn();
    final flow = flowFor(vpn);
    final backend = _Backend();
    final chat = chatFor(vpn, flow, backend);

    vpn.debugStall(
      const StallFinding(
        trigger: StallWatch.triggerCounters,
        probes: 3,
        quietFor: Duration(minutes: 1),
      ),
    );
    expect(vpn.stalled, isTrue);
    expect(flow.searching, isFalse);

    await chat.checkStatus(force: true);
    await chat.send('اینترنت ندارم');
    expect(backend.sent.single['context'], {
      'connected': false,
      'searching': true,
      'play_billing': false,
    });
  });

  test('a message sent over a tunnel that carries says connected and not '
      'searching', () async {
    final vpn = _UpVpn();
    final flow = flowFor(vpn);
    final backend = _Backend();
    final chat = chatFor(vpn, flow, backend);
    expect(vpn.stalled, isFalse);

    await chat.checkStatus(force: true);
    await chat.send('سلام');
    expect(backend.sent.single['context'], {
      'connected': true,
      'searching': false,
      'play_billing': false,
    });
  });
}
