import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/utils/link_id.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every event says where the link it dialled came from: `src` in its
/// strategy, and `lid` for a community link. Without them the backend
/// could not tell a community link the user picked from one the fallback
/// dialled, nor which link it was.

const _own = Server(
  id: 'dedicated-hel.example:443',
  name: 'Helsinki',
  country: 'Finland',
  city: 'Helsinki',
  connectionUri: 'vless://u@hel.example:443?type=tcp&security=reality#hel',
  flagEmoji: '',
  isDedicated: true,
  door: 'tcp-reality',
);

const _official = Server(
  id: '12',
  name: 'Fortiva DE',
  country: 'Germany',
  city: 'Nuremberg',
  connectionUri: 'vless://s@de.example:443?type=ws&security=tls#de',
  flagEmoji: '',
);

final _vmessLink =
    'vmess://${base64.encode(utf8.encode(jsonEncode({'add': 'vm.example', 'port': '2053', 'id': 'secret', 'net': 'ws', 'tls': 'tls'})))}';

final _community = Server.fromConnectionUri(_vmessLink, index: 3);

final _communityVless = Server.fromConnectionUri(
  'vless://c@nl.example:443?type=tcp&security=reality&sni=a.example#NL',
  index: 5,
);

class _Recorded {
  _Recorded(this.type, this.host, this.strategy);
  final VpnEventType type;
  final String? host;
  final Map<String, dynamic>? strategy;
}

class _CapturingReporter extends VpnEventReporter {
  _CapturingReporter() : super(send: (_, _, _) async {});

  final events = <_Recorded>[];

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
    events.add(_Recorded(type, serverHost, strategy));
  }
}

class _QuietDiagnostics extends ConnectDiagnostics {
  @override
  Future<Map<String, dynamic>> collect({
    String? host,
    int port = 443,
    String? sni,
  }) async => const {};

  @override
  Future<Map<String, dynamic>> platformReport() async => const {};
}

/// A tunnel that only records what it was asked to dial, and fails.
class _DialRecorder extends VpnService {
  _DialRecorder() : super(events: VpnEventReporter(send: (_, _, _) async {}));

  final dials = <(Server, LinkSource?)>[];
  VpnStatus _fake = VpnStatus.disconnected;

  @override
  VpnStatus get status => _fake;

  @override
  bool get isConnected => _fake == VpnStatus.connected;

  @override
  bool get isConnecting => _fake == VpnStatus.connecting;

  @override
  bool get isVerifying => false;

  /// The links whose tunnel comes up.
  final works = <String>{};

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {
    dials.add((server, source));
    _fake = VpnStatus.connecting;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    _fake = works.contains(server.pathKey)
        ? VpnStatus.connected
        : VpnStatus.error;
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

  group('where a link came from', () {
    test('read off the server when nothing else is said', () {
      expect(LinkSource.of(_own), LinkSource.own);
      expect(LinkSource.of(_official), LinkSource.officialShared);
      expect(LinkSource.of(_community), LinkSource.communityPick);
    });

    test('as the backend spells it', () {
      expect(LinkSource.values.map((s) => s.wire), [
        'own',
        'official_shared',
        'community_pick',
        'community_fallback',
        'psiphon',
      ]);
    });

    test('src and lid lead the strategy', () {
      final strategy = LinkSource.communityFallback.strategy(
        _communityVless,
        _communityVless.connectionUri,
      );
      expect(strategy.keys.take(2), ['src', 'lid']);
      expect(strategy['src'], 'community_fallback');
      expect(strategy['lid'], LinkId.of(_communityVless.connectionUri));
      expect(strategy['sni'], 'a.example');
    });

    test('only a community link has a lid', () {
      final own = LinkSource.own.strategy(_own, _own.connectionUri);
      final official = LinkSource.officialShared.strategy(
        _official,
        _official.connectionUri,
      );
      expect(own['src'], 'own');
      expect(own.containsKey('lid'), isFalse);
      expect(official['src'], 'official_shared');
      expect(official.containsKey('lid'), isFalse);
    });

    test('the lid is the listed link, not the one dialled', () {
      // The app adds a fragment parameter to some links before dialling.
      final strategy = LinkSource.communityPick.strategy(
        _communityVless,
        '${_communityVless.connectionUri}&fragment=tlshello,10-20,1-2',
      );
      expect(strategy['lid'], LinkId.of(_communityVless.connectionUri));
    });

    test('a link that sets everything stays within the 24 keys', () {
      final full = Server.fromConnectionUri(
        'vless://u@h.example:443?type=xhttp&security=reality&sni=s&fp=chrome'
        '&alpn=h2&flow=xtls-rprx-vision&headerType=none&mode=auto&path=%2Fp'
        '&serviceName=g&host=h&fragment=tlshello,1-2,1-2&extra=%7B%7D'
        '&ech=e&fm=f&cs=c&pbk=0123456789abcdef#x',
      );
      final strategy = LinkSource.communityPick.strategy(
        full,
        full.connectionUri,
      );
      expect(strategy.length, lessThanOrEqualTo(24));
      expect(strategy['src'], 'community_pick');
      expect(strategy['pbk_prefix'], '01234567');
    });
  });

  group('the events of an attempt', () {
    const channel = MethodChannel('com.vpn.fortivavpn/tunnel');
    late _CapturingReporter reporter;
    late VpnService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'connect') {
              throw PlatformException(code: 'IMPORT_FAILED');
            }
            return null;
          });
      reporter = _CapturingReporter();
      service = VpnService(events: reporter, diagnostics: _QuietDiagnostics());
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Future<_Recorded> failed(Server server, {LinkSource? source}) async {
      await expectLater(
        service.connect(server, source: source),
        throwsA(isA<PlatformException>()),
      );
      for (var i = 0; i < 20 && reporter.events.isEmpty; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      return reporter.events.singleWhere(
        (e) => e.type == VpnEventType.connectFailed,
      );
    }

    test('a community link the user picked', () async {
      final event = await failed(_community);
      expect(event.strategy?['src'], 'community_pick');
      expect(event.strategy?['lid'], LinkId.of(_vmessLink));
    });

    test('a community link the fallback dialled', () async {
      final event = await failed(
        _communityVless,
        source: LinkSource.communityFallback,
      );
      expect(event.strategy?['src'], 'community_fallback');
      expect(event.strategy?['lid'], LinkId.of(_communityVless.connectionUri));
    });

    test('a vmess link names the server it dialled', () async {
      // With no host, the backend counted these as attempts on our fleet.
      final event = await failed(_community);
      expect(event.host, 'vm.example');
      expect(event.strategy?['port'], 2053);
      expect(event.strategy?['transport'], 'ws');
    });

    test('our own door and our official link', () async {
      expect((await failed(_own)).strategy?['src'], 'own');
      reporter.events.clear();
      final official = await failed(_official);
      expect(official.strategy?['src'], 'official_shared');
      expect(official.strategy?.containsKey('lid'), isFalse);
    });
  });

  group('the connect flow', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    ConnectFlow flow(_DialRecorder vpn, Map<String, int> open) => ConnectFlow(
      vpn: vpn,
      memory: PathMemory(),
      finder: PathFinder(
        probe: (p) async => open[p.pathKey] ?? -1,
        internet: () async => true,
      ),
      reporter: VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, _, _) async {},
      ),
      networkKey: () async => 'mobile:Irancell',
      carrier: () async => 'Irancell',
      attemptTimeout: const Duration(seconds: 2),
    );

    test('dials a community link it fell back on as the fallback', () async {
      final vpn = _DialRecorder()..works.add(_communityVless.pathKey);
      final f = flow(vpn, {_communityVless.pathKey: 300});

      await f.connect([_own], shared: () async => [_communityVless]);

      expect(f.stage, ConnectStage.done);
      expect(vpn.dials.last.$1, _communityVless);
      expect(vpn.dials.last.$2, LinkSource.communityFallback);
    });

    test('an official link it fell back on stays official', () async {
      final vpn = _DialRecorder()..works.add(_official.pathKey);
      final f = flow(vpn, {_official.pathKey: 300});

      await f.connect([_own], shared: () async => [_official]);

      expect(vpn.dials.last.$1, _official);
      // Null: the service reads it off the link, official_shared.
      expect(vpn.dials.last.$2, isNull);
    });

    test('a community link the user picked is dialled as a pick', () async {
      final vpn = _DialRecorder()..works.add(_communityVless.pathKey);
      // Its check passes: a pick is checked before it is dialled.
      final f = flow(vpn, {_communityVless.pathKey: 300});

      await f.connect([_own], picked: _communityVless);

      expect(vpn.dials.single.$1, _communityVless);
      expect(vpn.dials.single.$2, isNull);
      expect(LinkSource.of(_communityVless), LinkSource.communityPick);
    });

    test('never checks or dials a link with allowInsecure', () async {
      final insecure = Server.fromConnectionUri(
        'vless://i@ins.example:443?security=tls&allowInsecure=1#I',
      );
      final vpn = _DialRecorder()..works.add(insecure.pathKey);
      final f = flow(vpn, {insecure.pathKey: 100});

      await f.connect([_own], shared: () async => [insecure]);

      expect(f.checks.map((c) => c.path), isNot(contains(insecure)));
      expect(vpn.dials.map((d) => d.$1), isNot(contains(insecure)));
    });
  });
}
