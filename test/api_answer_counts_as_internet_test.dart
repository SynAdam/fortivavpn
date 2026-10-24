import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/api_routes.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/failure_verdict.dart';
import 'package:fortiva_vpn/services/ipv6_reach.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An answer from our own API counts as internet (clients C5 of the plan
/// of 2026-10-23).
///
/// A tap ended at no internet when the control fetch (plain HTTP to Google
/// and Cloudflare) failed and nothing was open. On 10-23 about 10 to 25
/// taps a day ended that way on phones whose own calls to us were being
/// answered on the phone's own network. Our API is abroad, so such a phone
/// reaches abroad: its tap now gets the whole search, and ends at "every
/// path closed" when nothing is open. The two control sites are also raced
/// now, each with 4 seconds, and the backend can name its own
/// (`checklist.control_urls`).
Server own(String host, String door, int row) => Server.fromDedicatedPath(
  uri:
      'vless://u@$host:8443?type=tcp&security=reality'
      '&sni=www.samsung.com&pbk=key#Row$row',
  door: door,
  doorLabel: door,
  serverId: row,
);

final hel1 = own('203.0.113.226', 'tcp-reality', 13);
final hel2 = own('203.0.113.226', 'xhttp-reality', 13);
final fsn1 = own('203.0.113.227', 'tcp-reality', 14);
final paths = [hel1, hel2, fsn1];

const _closed = DoorOutcome(
  ms: -1,
  error: 'tcp timeout; no answer in 3000 ms',
  phase: 'tcp',
);

/// A tunnel that fails through every door.
class _FakeVpn extends VpnService {
  _FakeVpn() : super(events: VpnEventReporter(send: (_, _, _) async {}));

  final dialled = <String>[];
  VpnStatus _fakeStatus = VpnStatus.disconnected;

  /// What [tapStarted] held at each dial.
  final tapsAtDial = <DateTime?>[];

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
    tapsAtDial.add(tapStarted);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.lastAnsweredAt = null;
    ChecklistSettings.current = null;
  });
  tearDown(() {
    ApiClient.lastAnsweredAt = null;
    ChecklistSettings.current = null;
  });

  group('our API answering', () {
    const pin =
        'abababababababababababababababababababababababababababababababab';
    const relay = ApiRelay(url: 'https://203.0.113.6:443', pin: pin);
    final at = DateTime.utc(2026, 10, 24, 8);

    http.Client answers(Object Function() answer) => MockClient((_) async {
      final a = answer();
      if (a is http.Response) return a;
      throw a;
    });

    test('on the direct route, with any status, is noted', () async {
      final c = ApiClient.forTest(
        direct: answers(() => http.Response('{}', 500)),
        now: () => at,
      );
      await expectLater(c.get('/api/v1/app/config'), throwsA(anything));
      expect(ApiClient.lastAnsweredAt, at);
      expect(ApiClient.answeredSince(at), isTrue);
      expect(
        ApiClient.answeredSince(at.add(const Duration(milliseconds: 1))),
        isFalse,
      );
    });

    test('through a relay on the phone own network is noted', () async {
      final c = ApiClient.forTest(
        direct: answers(() => const SocketException('reset')),
        relay: (_) => answers(() => http.Response(jsonEncode({}), 200)),
        relays: () async => const [relay],
        now: () => at,
      );
      await c.get('/api/v1/app/config');
      expect(ApiClient.lastAnsweredAt, at);
    });

    test('through the tunnel is not: that says the tunnel works, not the '
        'phone own network', () async {
      final c = ApiClient.forTest(
        direct: answers(() => const SocketException('reset')),
        tunnel: (_) => answers(() => http.Response('{}', 200)),
        relays: () async => const [relay],
        tunnelPort: () async => 10808,
        now: () => at,
      );
      await c.get('/api/v1/app/config');
      expect(ApiClient.lastAnsweredAt, isNull);

      final viaRelay = ApiClient.forTest(
        direct: answers(() => const SocketException('reset')),
        tunnel: (_) => answers(() => TimeoutException('no answer')),
        tunnelRelay: (_, _) => answers(() => http.Response('{}', 200)),
        relays: () async => const [relay],
        tunnelPort: () async => 10808,
        now: () => at,
      );
      await viaRelay.get('/api/v1/app/config');
      expect(ApiClient.lastAnsweredAt, isNull);
    });

    test('nowhere is not noted', () async {
      final c = ApiClient.forTest(
        direct: answers(() => const SocketException('reset')),
        relay: (_) => answers(() => TimeoutException('no answer')),
        relays: () async => const [relay],
        now: () => at,
      );
      await expectLater(c.get('/api/v1/app/config'), throwsA(anything));
      expect(ApiClient.lastAnsweredAt, isNull);
    });
  });

  group('the verdict of a failed dial', () {
    const offline = {'control': 'fail', 'control_home': 'fail'};
    const cut = {'control': 'fail', 'control_home': 'ok'};

    test('is no internet, or a cut way abroad, only while our API has not '
        'answered', () {
      expect(verdictFor(diag: offline), FailureVerdict.noInternet);
      expect(verdictFor(diag: cut), FailureVerdict.cutOff);
      expect(verdictFor(diag: offline, online: true), FailureVerdict.unknown);
      expect(verdictFor(diag: cut, online: true), FailureVerdict.unknown);
    });

    test('reads the probes as after a fetch that passed once our API '
        'answered', () {
      const unreachable = {
        ...offline,
        'dns': 'ok',
        'tcp': 'timeout',
        'tls': 'skipped',
      };
      const tls = {...offline, 'dns': 'ok', 'tcp': 'ok', 'tls': 'reset'};
      expect(
        verdictFor(diag: unreachable, online: true),
        FailureVerdict.serverUnreachable,
      );
      expect(verdictFor(diag: tls, online: true), FailureVerdict.blockedTls);
      // A refused VPN permission is still that.
      expect(
        verdictFor(diag: {...offline, 'vpn_permission': false}, online: true),
        FailureVerdict.needsPermission,
      );
    });

    group('in the service', () {
      const channel = MethodChannel('com.vpn.fortivavpn/tunnel');
      final server = Server.fromConnectionUri(
        'vless://u@edge.example:443?type=tcp&security=reality'
        '&sni=www.samsung.com&pbk=key#Edge',
      );

      setUp(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async => null);
      });
      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      VpnService service() => VpnService(
        events: VpnEventReporter(send: (_, _, _) async {}),
        diagnostics: _Offline(),
      );

      test('an answer after the tap began, and before this dial, is read '
          'with the failure', () async {
        final vpn = service();
        final tap = DateTime.now();
        ApiClient.lastAnsweredAt = tap.add(const Duration(milliseconds: 1));
        vpn.tapStarted = tap;
        await vpn.connect(server);
        // Taken by the dial, so a dial no tap started reads its own start.
        expect(vpn.tapStarted, isNull);

        await vpn.reportConnectFailure('edge.example', null, 'timeout');

        expect(vpn.failureVerdict, FailureVerdict.unknown);
      });

      test('an answer from before the tap began is not', () async {
        final vpn = service();
        final tap = DateTime.now();
        ApiClient.lastAnsweredAt = tap.subtract(const Duration(seconds: 1));
        vpn.tapStarted = tap;
        await vpn.connect(server);

        await vpn.reportConnectFailure('edge.example', null, 'timeout');

        expect(vpn.failureVerdict, FailureVerdict.noInternet);
      });

      test('a dial no tap started counts from its own start', () async {
        final vpn = service();
        ApiClient.lastAnsweredAt = DateTime.now().subtract(
          const Duration(seconds: 1),
        );
        await vpn.connect(server);

        await vpn.reportConnectFailure('edge.example', null, 'timeout');

        expect(vpn.failureVerdict, FailureVerdict.noInternet);
      });
    });
  });

  group('the search', () {
    test('a fetch that failed passes once our API has answered, and its '
        'reach is open', () async {
      var answered = false;
      final finder = PathFinder(
        read: (_) async => _closed,
        internet: () async => false,
        home: () async => false,
      )..answered = () => answered;

      expect(await finder.controlFetch(), isFalse);
      expect(finder.internet, isFalse);
      expect(await finder.reach, NetReach.offline);

      answered = true;
      expect(await finder.controlFetch(), isTrue);
      expect(finder.internet, isTrue);
      expect(await finder.reach, NetReach.open);
    });

    test('asked outside a tap, the way abroad is the fetch alone', () async {
      final finder = PathFinder(
        read: (_) async => _closed,
        internet: () async => false,
      )..answered = () => true;

      expect(await finder.reachesAbroad(), isFalse);
    });

    test('an answer after the fetch failed keeps the whole budget and ends '
        'with internet', () async {
      var answered = false;
      final checked = <String>[];
      final finder = PathFinder(
        read: (p) async {
          checked.add(p.pathKey);
          await Future.delayed(const Duration(milliseconds: 40));
          return _closed;
        },
        internet: () async {
          // The fetch fails at once, and our API answers a moment later.
          Timer(const Duration(milliseconds: 10), () => answered = true);
          return false;
        },
        budget: const Duration(seconds: 5),
      )..answered = () => answered;

      final found = await finder.find(
        paths,
        offlineBudget: const Duration(milliseconds: 30),
      );

      expect(checked, [for (final p in paths) p.pathKey]);
      expect(found.internet, isTrue);
      expect(found.cut, isFalse);
      expect(finder.internet, isTrue);
    });

    test('with no answer the offline budget still holds, as before', () async {
      final checked = <String>[];
      final finder = PathFinder(
        read: (p) async {
          checked.add(p.pathKey);
          await Future.delayed(const Duration(milliseconds: 40));
          return _closed;
        },
        internet: () async => false,
        budget: const Duration(seconds: 5),
      );

      final found = await finder.find(
        paths,
        offlineBudget: const Duration(milliseconds: 30),
      );

      expect(checked, [hel1.pathKey]);
      expect(found.internet, isFalse);
    });
  });

  group('a tap', () {
    late List<List<Map<String, dynamic>>> reported;

    setUp(() => reported = []);

    ConnectFlow flow(
      _FakeVpn vpn, {
      required bool Function(DateTime since) answeredSince,
      Duration check = Duration.zero,
      void Function()? fetched,
    }) => ConnectFlow(
      vpn: vpn,
      memory: PathMemory(),
      finder: PathFinder(
        read: (_) async {
          if (check > Duration.zero) await Future.delayed(check);
          return _closed;
        },
        internet: () async {
          fetched?.call();
          return false;
        },
        budget: const Duration(seconds: 1),
      ),
      reporter: VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, probes, _) async => reported.add(probes),
        deviceId: () async => 'DEV-1',
        appVersion: () async => '2.2.0',
        platform: 'android',
        networkType: () async => 'mobile',
      ),
      ipv6: Ipv6Reach(route: () async => null),
      networkKey: () async => 'mobile',
      carrier: () async => null,
      checklist: () => null,
      attemptTimeout: const Duration(seconds: 2),
      answeredSince: answeredSince,
    );

    test('whose fetch failed with no answer from our API ends at no '
        'internet, as before', () async {
      final f = flow(_FakeVpn(), answeredSince: (_) => false);

      await f.connect(paths);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.noInternet);
      expect(reported, isEmpty);
    });

    test('whose fetch failed while our API answered ends at every path '
        'closed, and its rows go out', () async {
      final asked = <DateTime>[];
      final before = DateTime.now();
      final f = flow(
        _FakeVpn(),
        answeredSince: (since) {
          asked.add(since);
          return true;
        },
      );

      await f.connect(paths);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.nothingOpen);
      expect([for (final b in reported) ...b], hasLength(paths.length));
      // Asked about this tap: since it began, not since an earlier one.
      expect(asked, isNotEmpty);
      expect(asked.every((t) => !t.isBefore(before)), isTrue);
    });

    test('whose fetch failed before our API answered still sends its rows, '
        'once the answer came', () async {
      var answered = false;
      final f = flow(
        _FakeVpn(),
        answeredSince: (_) => answered,
        check: const Duration(milliseconds: 30),
        // The fetch fails at once; our API answers a moment later, while
        // the doors are still being checked.
        fetched: () =>
            Timer(const Duration(milliseconds: 10), () => answered = true),
      );

      await f.connect(paths);
      await pumpEventQueue();

      expect(f.stage, ConnectStage.nothingOpen);
      expect([for (final b in reported) ...b], hasLength(paths.length));
    });

    test('hands its start to each dial, for the failure verdict', () async {
      final vpn = _FakeVpn();
      final f = flow(vpn, answeredSince: (_) => true);

      // The fast path: a remembered door is dialled first.
      await PathMemory().remember('mobile', hel1.pathKey);
      await f.connect(paths);
      await pumpEventQueue();

      expect(vpn.dialled, isNotEmpty);
      expect(vpn.tapsAtDial, everyElement(isNotNull));
      expect(vpn.tapsAtDial.toSet(), hasLength(1));
    });
  });

  group('control_urls from the backend', () {
    List<String>? read(Object? raw) =>
        ChecklistSettings.fromJson({'control_urls': raw})?.control;

    test('takes 1 to 4 http or https sites', () {
      expect(read(['http://a.example/generate_204']), [
        'http://a.example/generate_204',
      ]);
      final four = [for (var i = 0; i < 4; i++) 'https://a$i.example/'];
      expect(read(four), four);
      final settings = ChecklistSettings.fromJson({'control_urls': four})!;
      expect(settings.toJson()['control_urls'], four);
      expect(ChecklistSettings.fromJson(settings.toJson())!.control, four);
    });

    test('drops a list it cannot use whole, and never takes an empty one: '
        'with no site every tap would read as no internet', () {
      expect(read(const <String>[]), isNull);
      expect(read(null), isNull);
      expect(read('http://a.example/'), isNull);
      expect(read(['ftp://a.example/']), isNull);
      expect(read(['http://a.example/', 7]), isNull);
      expect(read(['not a site']), isNull);
      expect(read([for (var i = 0; i < 5; i++) 'http://a$i.example/']), isNull);
      // Nothing else in the block: no settings at all.
      expect(ChecklistSettings.fromJson({'control_urls': []}), isNull);
    });
  });
}

/// A diagnosis that found no site abroad and none inside the country.
class _Offline extends ConnectDiagnostics {
  @override
  Future<Map<String, dynamic>> collect({
    String? host,
    int port = 443,
    String? sni,
  }) async => {'control': 'fail', 'control_home': 'fail'};

  @override
  Future<Map<String, dynamic>> platformReport() async => const {};
}
