import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/api_routes.dart';
import 'package:fortiva_vpn/api/built_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A certificate and key made for these tests only. They protect nothing:
// the tests below start a local server with them to check that a relay is
// accepted by its pin and refused without it.
const _testCert = '''-----BEGIN CERTIFICATE-----
MIIBgTCCASegAwIBAgIUf6+WmjkBaMd6+v9C/Lr2RBb0Bd8wCgYIKoZIzj0EAwIw
FTETMBEGA1UEAwwKcmVsYXktdGVzdDAgFw0yNjEwMDYwNjE3NTNaGA8yMTI2MDkx
MjA2MTc1M1owFTETMBEGA1UEAwwKcmVsYXktdGVzdDBZMBMGByqGSM49AgEGCCqG
SM49AwEHA0IABK1V9yVZykFrqNlhScF6yo12k721JZKMvyjwI09FdjxRkf0KyJcW
4da4yxarY8t7JVVKryc6Ap7GZKKwyMELYLejUzBRMB0GA1UdDgQWBBR3dPeXlKhf
joDwXrovUsbhg+dwWzAfBgNVHSMEGDAWgBR3dPeXlKhfjoDwXrovUsbhg+dwWzAP
BgNVHRMBAf8EBTADAQH/MAoGCCqGSM49BAMCA0gAMEUCIQD0rIwiC65jbn7h+RNz
r7QW/jj69XmUD11Ne3SQBFgeEAIgEJiPiDmrgSK9bxcjFo44WW0k0tCgBiQ52Mtc
qxoIsEI=
-----END CERTIFICATE-----''';
const _testKey = '''-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgd5KAD9pummfTaflA
DY1iPAcMdcpMTNdthnVgQ1g7tPahRANCAAStVfclWcpBa6jZYUnBesqNdpO9tSWS
jL8o8CNPRXY8UZH9CsiXFuHWuMsWq2PLeyVVSq8nOgKexmSisMjBC2C3
-----END PRIVATE KEY-----''';
const _testPin =
    '09d8bb703447f693427d8a0f4b115cfc6805a3df57421ed0438e699c03be7227';

const _relay = ApiRelay(url: 'https://203.0.113.5:443', pin: _testPin);

/// A client that records what it was asked and answers with [answer], or
/// throws what [answer] returns when that is an exception.
class _Route {
  _Route(this.name, this.answer);

  final String name;
  final Object Function(http.Request request) answer;
  final requests = <http.Request>[];

  http.Client get client => MockClient((request) async {
    requests.add(request);
    final a = answer(request);
    if (a is http.Response) return a;
    throw a;
  });
}

/// The tunnel client, trusting the test certificate the way the real one
/// trusts a public one.
http.Client _tunnel(int port) => tunnelClient(
  port,
  timeout: const Duration(seconds: 5),
  onBadCertificate: (cert) =>
      ApiRelay(url: 'https://x', pin: _testPin).matches(cert),
);

http.Response _ok([Object body = const {'ok': true}]) =>
    http.Response(jsonEncode(body), 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiRelays.resetForTest();
  });

  group('ApiClient routes', () {
    late _Route direct;
    late _Route tunnel;
    late _Route relay;
    late _Route tunnelRelay;
    late int? tunnelPort;
    late DateTime now;

    ApiClient client({List<ApiRelay> relays = const [_relay]}) =>
        ApiClient.forTest(
          direct: direct.client,
          tunnel: (_) => tunnel.client,
          relay: (_) => relay.client,
          tunnelRelay: (_, _) => tunnelRelay.client,
          relays: () async => relays,
          tunnelPort: () async => tunnelPort,
          now: () => now,
        );

    setUp(() {
      direct = _Route('direct', (_) => _ok());
      tunnel = _Route('tunnel', (_) => _ok());
      relay = _Route('relay', (_) => _ok());
      tunnelRelay = _Route('tunnel relay', (_) => _ok());
      tunnelPort = null;
      now = DateTime.utc(2026, 10, 6, 6);
    });

    test('goes out on the phone own network when that works', () async {
      tunnelPort = 10808;
      await client().post('/api/v1/devices/register', body: {'a': 1});
      expect(direct.requests, hasLength(1));
      expect(tunnel.requests, isEmpty);
      expect(relay.requests, isEmpty);
      expect(
        direct.requests.single.url.toString(),
        'https://api.fortivavpn.com/api/v1/devices/register',
      );
    });

    test('a call the network drops goes through the tunnel', () async {
      direct = _Route('direct', (_) => const SocketException('reset'));
      tunnelPort = 10808;
      final answer = await client().post(
        '/api/v1/devices/abc/events',
        body: {'events': [], 'via_tunnel': false},
      );
      expect(answer, {'ok': true});
      expect(tunnel.requests, hasLength(1));
      expect(relay.requests, isEmpty);
      // It reaches the backend from our own exit server, so it says so.
      expect(jsonDecode(tunnel.requests.single.body)['via_tunnel'], isTrue);
      expect(
        tunnel.requests.single.url.toString(),
        'https://api.fortivavpn.com/api/v1/devices/abc/events',
      );
    });

    test('with no tunnel up, a dropped call goes to the relay', () async {
      direct = _Route('direct', (_) => TimeoutException('no answer'));
      await client().post(
        '/api/v1/devices/abc/probes',
        body: {'probes': [], 'via_tunnel': false},
      );
      expect(tunnel.requests, isEmpty);
      expect(relay.requests, hasLength(1));
      expect(
        relay.requests.single.url.toString(),
        'https://203.0.113.5/api/v1/devices/abc/probes',
      );
      // The relay passes the phone's own address on, so the phone's own
      // answer about the route stands.
      expect(jsonDecode(relay.requests.single.body)['via_tunnel'], isFalse);
    });

    test('the relay is tried after the tunnel fails too', () async {
      direct = _Route('direct', (_) => const HandshakeException('cut'));
      tunnel = _Route('tunnel', (_) => const SocksException('refused'));
      tunnelRelay = _Route('tunnel relay', (_) => const SocksException('x'));
      tunnelPort = 10808;
      await client().get('/api/v1/app/config');
      expect(direct.requests, hasLength(1));
      expect(tunnel.requests, hasLength(1));
      expect(tunnelRelay.requests, hasLength(1));
      expect(relay.requests, hasLength(1));
    });

    // On 2026-10-11 a tunnel through a link from the fallback file loaded
    // GitHub and Google and timed out on every Cloudflare address, and the
    // relays were cut on the phone's own network.
    test('when the tunnel cannot reach the backend, a relay inside the '
        'tunnel carries the call, before the relays outside it', () async {
      direct = _Route('direct', (_) => TimeoutException('no answer'));
      tunnel = _Route('tunnel', (_) => TimeoutException('no answer'));
      tunnelPort = 10808;
      final answer = await client().post(
        '/api/v1/configs/dedicated',
        body: {'device_id': 'd', 'via_tunnel': false},
      );
      expect(answer, {'ok': true});
      expect(tunnelRelay.requests, hasLength(1));
      expect(relay.requests, isEmpty);
      expect(
        tunnelRelay.requests.single.url.toString(),
        'https://203.0.113.5/api/v1/configs/dedicated',
      );
      // It reaches the backend from the tunnel's exit, so it says so.
      expect(
        jsonDecode(tunnelRelay.requests.single.body)['via_tunnel'],
        isTrue,
      );
    });

    test('a relay inside the tunnel is tried only while a tunnel is up, and '
        'at most two of them', () async {
      direct = _Route('direct', (_) => TimeoutException('no answer'));
      relay = _Route('relay', (_) => TimeoutException('no answer'));
      const more = [
        _relay,
        ApiRelay(url: 'https://203.0.113.6:443', pin: _testPin),
        ApiRelay(url: 'https://203.0.113.7:443', pin: _testPin),
      ];
      await expectLater(
        client(relays: more).get('/api/v1/app/config'),
        throwsA(isA<TimeoutException>()),
      );
      expect(tunnelRelay.requests, isEmpty);

      tunnel = _Route('tunnel', (_) => TimeoutException('no answer'));
      tunnelRelay = _Route('tunnel relay', (_) => TimeoutException('x'));
      tunnelPort = 10808;
      await expectLater(
        client(relays: more).get('/api/v1/app/config'),
        throwsA(isA<TimeoutException>()),
      );
      expect(tunnelRelay.requests, hasLength(2));
    });

    test('an answer from the backend is final, whatever its status', () async {
      direct = _Route('direct', (_) => http.Response('{"detail":"x"}', 404));
      tunnelPort = 10808;
      await expectLater(
        client().post('/api/v1/configs/dedicated', body: {}),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
      expect(tunnel.requests, isEmpty);
      expect(relay.requests, isEmpty);
    });

    test(
      'when every route fails the caller hears what the network said',
      () async {
        direct = _Route('direct', (_) => const SocketException('down'));
        relay = _Route('relay', (_) => const SocketException('down too'));
        await expectLater(
          client().get('/api/v1/app/config'),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 0)),
        );
      },
    );

    test('after the network dropped a call, the other routes go first for a '
        'while', () async {
      var directDown = true;
      direct = _Route(
        'direct',
        (_) => directDown ? const SocketException('down') : _ok(),
      );
      final api = client();
      await api.get('/api/v1/app/config');
      expect(direct.requests, hasLength(1));
      expect(relay.requests, hasLength(1));

      // Nine minutes on: the relay first, and the direct route not at all.
      now = now.add(const Duration(minutes: 9));
      await api.get('/api/v1/app/config');
      expect(direct.requests, hasLength(1));
      expect(relay.requests, hasLength(2));

      // Past the ten minutes the direct route is first again.
      directDown = false;
      now = now.add(const Duration(minutes: 2));
      await api.get('/api/v1/app/config');
      expect(direct.requests, hasLength(2));
      expect(relay.requests, hasLength(2));
    });

    test(
      'a call that must stay on the phone network never falls back',
      () async {
        direct = _Route('direct', (_) => const SocketException('down'));
        tunnelPort = 10808;
        await expectLater(
          client().get('/api/v1/info/me', fallback: false),
          throwsA(isA<ApiException>()),
        );
        expect(tunnel.requests, isEmpty);
        expect(relay.requests, isEmpty);
      },
    );
  });

  group('app headers', () {
    late _Route direct;
    late _Route relay;

    setUp(() {
      ApiConfig.appVersion = '1.6.11';
      ApiConfig.appBuild = '56';
      ApiConfig.appPlatform = 'android';
      direct = _Route('direct', (_) => _ok());
      relay = _Route('relay', (_) => _ok());
    });

    tearDown(() {
      ApiConfig.appVersion = null;
      ApiConfig.appBuild = null;
      ApiConfig.appPlatform = null;
    });

    ApiClient client() => ApiClient.forTest(
      direct: direct.client,
      relay: (_) => relay.client,
      relays: () async => const [_relay],
    );

    void expectAppHeaders(http.Request request) {
      expect(request.headers['X-App-Version'], '1.6.11');
      expect(request.headers['X-App-Build'], '56');
      expect(request.headers['X-App-Platform'], 'android');
    }

    test('go with every call on the direct route', () async {
      final api = client();
      await api.get('/api/v1/app/config');
      await api.post('/api/v1/devices/register', body: {'a': 1});
      await api.delete('/api/v1/devices/abc');
      expect(direct.requests, hasLength(3));
      direct.requests.forEach(expectAppHeaders);
    });

    test('go with a call the relay carries', () async {
      direct = _Route('direct', (_) => const SocketException('reset'));
      await client().get('/api/v1/app/config');
      expect(relay.requests, hasLength(1));
      expectAppHeaders(relay.requests.single);
    });

    test('a value that is not known is left out, never sent empty', () async {
      ApiConfig.appVersion = null;
      ApiConfig.appBuild = null;
      ApiConfig.appPlatform = null;
      await client().get('/api/v1/app/config');
      final headers = direct.requests.single.headers;
      expect(headers.containsKey('X-App-Version'), isFalse);
      expect(headers.containsKey('X-App-Build'), isFalse);
      expect(headers.containsKey('X-App-Platform'), isFalse);
      expect(headers['Accept'], 'application/json');
    });
  });

  group('ApiRelay', () {
    test('reads a relay with an https address and a pin', () {
      final r = ApiRelay.fromJson({
        'url': 'https://203.0.113.5:443/',
        'pin': _testPin.toUpperCase(),
      });
      expect(r, const ApiRelay(url: 'https://203.0.113.5:443', pin: _testPin));
    });

    test('refuses a relay it could not use safely', () {
      expect(
        ApiRelay.fromJson({'url': 'http://203.0.113.5', 'pin': _testPin}),
        isNull,
      );
      expect(
        ApiRelay.fromJson({'url': 'https://203.0.113.5', 'pin': 'abc'}),
        isNull,
      );
      expect(ApiRelay.fromJson({'url': 'https://203.0.113.5'}), isNull);
      expect(ApiRelay.fromJson('https://203.0.113.5'), isNull);
    });

    test('the built-in relays are ones the app can use', skip: _noBuiltIn, () {
      expect(ApiRelays.builtIn, isNotEmpty);
      for (final r in ApiRelays.builtIn) {
        expect(ApiRelay.fromJson(r.toJson()), r);
        expect(Uri.parse(r.url).host, isNotEmpty);
      }
    });

    test('a config without the key leaves the known relays alone', () {
      expect(ApiRelays.parse(null), isNull);
      expect(ApiRelays.parse([]), isEmpty);
      expect(
        ApiRelays.parse([
          {'url': 'https://203.0.113.5', 'pin': _testPin},
          {'url': 'nonsense'},
        ]),
        hasLength(1),
      );
    });

    test('the backend list is kept between launches, empty included', () async {
      expect(await ApiRelays.current(), ApiRelays.builtIn);
      await ApiRelays.adopt(const [_relay]);
      ApiRelays.resetForTest();
      expect(await ApiRelays.current(), [_relay]);

      await ApiRelays.adopt(const []);
      ApiRelays.resetForTest();
      expect(await ApiRelays.current(), isEmpty);
    });
  });

  group('relay certificate pin', () {
    late HttpServer server;

    // The test binding answers every HttpClient request itself; these tests
    // need real sockets on this machine.
    setUpAll(() => HttpOverrides.global = null);

    setUp(() async {
      final context = SecurityContext()
        ..useCertificateChainBytes(utf8.encode(_testCert))
        ..usePrivateKeyBytes(utf8.encode(_testKey));
      server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        context,
      );
      server.listen((request) {
        request.response
          ..write('relayed ${request.uri.path}')
          ..close();
      });
    });

    tearDown(() => server.close(force: true));

    test('a relay with the pinned certificate is accepted', () async {
      final url = 'https://127.0.0.1:${server.port}';
      final c = relayClient(
        ApiRelay(url: url, pin: _testPin),
        timeout: const Duration(seconds: 5),
      );
      final r = await c.get(Uri.parse('$url/api/v1/app/config'));
      expect(r.body, 'relayed /api/v1/app/config');
      c.close();
    });

    test('a relay with any other certificate is refused', () async {
      final url = 'https://127.0.0.1:${server.port}';
      final c = relayClient(
        ApiRelay(url: url, pin: 'f' * 64),
        timeout: const Duration(seconds: 5),
      );
      await expectLater(
        c.get(Uri.parse('$url/api/v1/app/config')),
        throwsA(anyOf(isA<HandshakeException>(), isA<http.ClientException>())),
      );
      c.close();
    });

    // Hamrah Aval cuts an IPv4 hello whose name is an address, and Dart puts
    // the address there unless told otherwise.
    test('the hello to a relay address carries the neutral name', () async {
      final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final hello = Completer<List<int>>();
      listener.listen((socket) {
        final bytes = <int>[];
        socket.listen((data) {
          bytes.addAll(data);
          // A TLS record header is 5 bytes, its length in bytes 3 and 4.
          if (bytes.length >= 5 &&
              bytes.length >= 5 + (bytes[3] << 8 | bytes[4]) &&
              !hello.isCompleted) {
            hello.complete(bytes);
            socket.destroy();
          }
        });
      });

      final url = 'https://127.0.0.1:${listener.port}';
      final c = relayClient(
        ApiRelay(url: url, pin: _testPin),
        timeout: const Duration(seconds: 5),
      );
      unawaited(
        c
            .get(Uri.parse('$url/api/v1/app/config'))
            .then((_) {}, onError: (_) {}),
      );

      final record = await hello.future.timeout(const Duration(seconds: 5));
      expect(record.first, 0x16, reason: 'a TLS handshake record');
      expect(latin1.decode(record), contains(relayServerName));
      expect(latin1.decode(record), isNot(contains('127.0.0.1')));
      c.close();
      await listener.close();
    });

    // A desktop can have https_proxy set. The relay client dials the relay
    // itself, so a proxy would only get a CONNECT sent to the relay.
    test('a proxy from the environment is not used for a relay', () async {
      final url = 'https://127.0.0.1:${server.port}';
      final c = relayClient(
        ApiRelay(url: url, pin: _testPin),
        timeout: const Duration(seconds: 5),
      );
      final r = await HttpOverrides.runZoned(
        () => c.get(Uri.parse('$url/api/v1/app/config')),
        findProxyFromEnvironment: (_, _) => 'PROXY 127.0.0.1:9',
      );
      expect(r.body, 'relayed /api/v1/app/config');
      c.close();
    });
  });

  group('SOCKS5', () {
    late HttpServer target;
    late ServerSocket proxy;
    late List<List<int>> connectRequests;

    setUpAll(() => HttpOverrides.global = null);

    setUp(() async {
      connectRequests = [];
      final context = SecurityContext()
        ..useCertificateChainBytes(utf8.encode(_testCert))
        ..usePrivateKeyBytes(utf8.encode(_testKey));
      target = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        context,
      );
      target.listen((request) async {
        final body = await utf8.decodeStream(request);
        request.response
          ..write('${request.method} ${request.uri.path} $body')
          ..close();
      });
      // A small SOCKS5 proxy: no authentication, CONNECT only, and every
      // connection goes to [target] whatever it asked for, after the
      // request is recorded.
      proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      proxy.listen((client) async {
        final buffer = <int>[];
        var stage = 0;
        Socket? upstream;
        client.listen((data) async {
          if (upstream != null) {
            upstream!.add(data);
            return;
          }
          buffer.addAll(data);
          if (stage == 0 && buffer.length >= 3) {
            buffer.removeRange(0, 3);
            client.add([0x05, 0x00]);
            stage = 1;
          }
          if (stage == 1 && buffer.length >= 5) {
            final len = switch (buffer[3]) {
              0x01 => 4,
              0x04 => 16,
              _ => 1 + buffer[4],
            };
            final total = 4 + len + 2;
            if (buffer.length < total) return;
            connectRequests.add(buffer.sublist(0, total));
            buffer.removeRange(0, total);
            stage = 2;
            final up = await Socket.connect(
              InternetAddress.loopbackIPv4,
              target.port,
            );
            up.listen(client.add, onDone: client.destroy);
            client.add([0x05, 0x00, 0x00, 0x01, 127, 0, 0, 1, 0, 80]);
            upstream = up;
            if (buffer.isNotEmpty) up.add(buffer);
          }
        }, onDone: () => upstream?.destroy());
      });
    });

    tearDown(() async {
      await proxy.close();
      await target.close(force: true);
    });

    test('a plain http address is refused rather than sent', () async {
      final c = _tunnel(proxy.port);
      await expectLater(
        c.get(Uri.parse('http://127.0.0.1:${target.port}/')),
        throwsA(isA<SocksException>()),
      );
      expect(connectRequests, isEmpty);
      c.close();
    });

    test('a request goes through the proxy and comes back', () async {
      final c = _tunnel(proxy.port);
      final r = await c.post(
        Uri.parse('https://localhost:${target.port}/api/v1/x'),
        body: 'hello',
      );
      expect(r.body, 'POST /api/v1/x hello');
      // It asked the proxy for the host by name, so the name is resolved
      // on the far side of the tunnel.
      final request = connectRequests.single;
      expect(request.sublist(0, 4), [0x05, 0x01, 0x00, 0x03]);
      expect(utf8.decode(request.sublist(5, 5 + request[4])), 'localhost');
      c.close();
    });

    test('an address is sent as an address', () async {
      final c = _tunnel(proxy.port);
      await c.get(Uri.parse('https://127.0.0.1:${target.port}/'));
      final request = connectRequests.single;
      expect(request.sublist(0, 8), [0x05, 0x01, 0x00, 0x01, 127, 0, 0, 1]);
      expect((request[8] << 8) | request[9], target.port);
      c.close();
    });

    test('a proxy that refuses the connection fails the route', () async {
      final refusing = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      refusing.listen((client) {
        client.listen((data) {
          if (data.length == 3) {
            client.add([0x05, 0x00]);
          } else {
            client.add([0x05, 0x05, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
          }
        });
      });
      final c = _tunnel(refusing.port);
      await expectLater(
        c.get(Uri.parse('https://127.0.0.1:${target.port}/')),
        throwsA(isA<SocksException>()),
      );
      c.close();
      await refusing.close();
    });
  });
}

/// Why the tests of the values compiled in skip, in the public copy of the
/// repo, which has none (lib/api/built_in.dart).
final Object _noBuiltIn = BuiltIn.isPublicCopy
    ? 'the public copy has no built-in relays'
    : false;
