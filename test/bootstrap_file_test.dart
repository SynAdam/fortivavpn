import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/api_routes.dart';
import 'package:fortiva_vpn/api/bootstrap.dart';
import 'package:fortiva_vpn/api/built_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The fallback file: read from public hosts when the backend cannot be
/// reached at all (lib/api/bootstrap.dart, and the backend's side of the
/// same format).

/// The backend's test keys and the line its test seals with them
/// (tests/test_bootstrap_file.py, VECTOR). Opening it here is what proves
/// the two sides agree on the format.
final seed = List<int>.generate(32, (i) => i);
final sealKey = List<int>.generate(32, (i) => 32 + i);
final backendPublicKey = base64.decode(
  'A6EHv/POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg=',
);
const backendVector =
    'AUBBQkNERUZHSElKS7qOGM4RfAc7Qs6bUgijl9SliNl81AUFmGNY-UiyOJ34vUCu'
    'KVkSYRSOVfFqlc27qZ7jNppms1YVjMn77iOHVba5_JQAxiuRMcr8SKbFoC9RkBaH'
    'YhCH6w_mceZ6GraBku_QQYAMQeFSRk7lsuZz8yoxIMJuJIBHysTL5CaaVGPCGCiL'
    'k4jwUMNXJN2J1MnxJQkrJe7UdYJ3NT3PtjZQFzoV_kf9tYvMW4UE4QYpKjzZ8fT-'
    'RQ.BE693QEOGSd40PnFbXzcNoueJkjUX_Vsv0QQVjIlB3tID-t02D7-eS1EuPM-9'
    '88sghNCyRNjkokLWLvr9g-QAA';

/// A file sealed the way the backend seals one, with the test keys.
Future<String> seal(
  Map<String, Object?> payload, {
  List<int>? signWith,
  List<int>? sealWith,
}) async {
  final aad = utf8.encode(BootstrapFile.context);
  final box = await AesGcm.with256bits().encrypt(
    ZLibCodec().encode(utf8.encode(jsonEncode(payload))),
    secretKey: SecretKey(sealWith ?? sealKey),
    nonce: List<int>.generate(12, (i) => 64 + i),
    aad: aad,
  );
  final body = [1, ...box.nonce, ...box.cipherText, ...box.mac.bytes];
  final pair = await Ed25519().newKeyPairFromSeed(signWith ?? seed);
  final signature = await Ed25519().sign([...aad, ...body], keyPair: pair);
  String b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');
  return '${b64(body)}.${b64(signature.bytes)}';
}

Map<String, Object?> payload({
  required int issuedAt,
  List<String> links = const ['vless://a@198.51.100.7:443#a'],
  List<Map<String, String>> relays = const [],
  List<String> mirrors = const [],
}) => {
  'v': 1,
  'issued_at': issuedAt,
  'relays': relays,
  'links': links,
  'mirrors': mirrors,
};

const pin = 'abababababababababababababababababababababababababababababababab';

/// Why the tests of the keys and the file compiled in skip, in the public
/// copy of the repo, which has neither (lib/api/built_in.dart).
final Object noBuiltIn = BuiltIn.isPublicCopy
    ? 'the public copy has no built-in fallback file or keys'
    : false;

/// A file about the size of the one the backend publishes, sealed with the
/// test keys: links whose random parts zlib cannot shrink.
Future<String> fileOfRealSize() {
  final random = Random(7);
  String hex(int n) =>
      List.generate(n, (_) => random.nextInt(16).toRadixString(16)).join();
  return seal(
    payload(
      issuedAt: 1,
      links: [
        for (var i = 0; i < 48; i++)
          'vless://${hex(32)}@198.51.100.${i + 1}:443'
              '?security=reality&pbk=${hex(43)}#$i',
      ],
      relays: [
        {'url': 'https://203.0.113.5:443', 'pin': pin},
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<int> publicKey;
  late List<RouteAttempt> observed;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ApiRelays.resetForTest();
    observed = [];
    ApiClient.onRouteAttempt = observed.add;
    final pair = await Ed25519().newKeyPairFromSeed(seed);
    publicKey = (await pair.extractPublicKey()).bytes;
  });

  tearDown(() => ApiClient.onRouteAttempt = null);

  Future<BootstrapFile?> open(String text, {List<int>? key}) =>
      BootstrapFile.open(text, publicKey: key ?? publicKey, sealKey: sealKey);

  group('opening a file', () {
    test('the line the backend sealed opens here to what went in', () async {
      expect(publicKey, backendPublicKey);
      final file = await open(backendVector);
      expect(file, isNotNull);
      expect(
        file!.issuedAt,
        DateTime.fromMillisecondsSinceEpoch(1760140800000, isUtc: true),
      );
      expect(file.relays, [
        const ApiRelay(url: 'https://203.0.113.5:443', pin: pin),
      ]);
      expect(file.links, [
        'vless://00000000-0000-0000-0000-000000000000@198.51.100.7:443'
            '?type=tcp#a',
      ]);
      expect(file.mirrors, ['https://example.org/file.txt']);
    });

    test('one changed character and it is refused', () async {
      final text = await seal(payload(issuedAt: 1));
      final i = 30;
      final changed =
          text.substring(0, i) +
          (text[i] == 'A' ? 'B' : 'A') +
          text.substring(i + 1);
      expect(await open(changed), isNull);
    });

    test('a file signed with any other key is refused', () async {
      final other = List<int>.generate(32, (i) => 200 - i);
      expect(
        await open(await seal(payload(issuedAt: 1), signWith: other)),
        isNull,
      );
    });

    test('a block page, an empty answer or a torn line is refused', () async {
      for (final text in ['', '<html>blocked</html>', 'a.b.c', 'abc.']) {
        expect(await open(text), isNull, reason: text);
      }
    });

    test('the keys compiled into the app are real keys', skip: noBuiltIn, () {
      expect(Bootstrap.keysCompiledIn, isTrue);
    });

    test(
      'the copy built into the app opens with the keys compiled in, so a '
      'bad copy cannot reach a release',
      skip: noBuiltIn,
      () async {
        final b = Bootstrap(
          seed: () => File(Bootstrap.seedAsset).readAsString(),
          builtIn: const [],
        );
        await b.restore();
        expect(b.file, isNotNull, reason: 'run ./tool/fallback_seed.sh');
        expect(b.file!.relays, isNotEmpty);
        expect(b.file!.links, isNotEmpty);
      },
    );
  });

  group('reading the file from its hosts', () {
    Bootstrap bootstrap(
      Map<String, Future<http.Response> Function()> hosts, {
      Duration grace = const Duration(milliseconds: 50),
      DateTime Function()? now,
    }) => Bootstrap(
      client: () => MockClient((request) {
        final answer = hosts[request.url.host];
        if (answer == null) throw const SocketException('no route');
        return answer();
      }),
      builtIn: [for (final h in hosts.keys) 'https://$h/data/index.txt'],
      publicKey: publicKey,
      sealKey: sealKey,
      grace: grace,
      now: now,
      seed: () async => null,
    );

    test('every host is asked, the newest file that opens is kept, saved '
        'and its relays tried', () async {
      final older = await seal(payload(issuedAt: 1000));
      final newer = await seal(
        payload(
          issuedAt: 2000,
          links: ['vless://b@198.51.100.8:443#b'],
          relays: [
            {'url': 'https://203.0.113.9:443', 'pin': pin},
          ],
        ),
      );
      var told = 0;
      final b = bootstrap({
        'gone.example': () async => http.Response('', 404),
        'old.example': () async => http.Response(older, 200),
        'new.example': () async => http.Response(newer, 200),
        'block.example': () async => http.Response('<html>no</html>', 200),
      })..addListener(() => told++);

      final file = await b.read();

      expect(file!.links, ['vless://b@198.51.100.8:443#b']);
      expect(b.file, same(file));
      expect(told, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(Bootstrap.savedKey), newer);
      expect(
        (await ApiRelays.current()).first,
        const ApiRelay(url: 'https://203.0.113.9:443', pin: pin),
      );
    });

    test('each read is reported to the delivery log by host', () async {
      final good = await seal(payload(issuedAt: 1000));
      final b = bootstrap({
        'gone.example': () async => http.Response('', 404),
        'good.example': () async => http.Response(good, 200),
        'block.example': () async => http.Response('<html>no</html>', 200),
      });

      await b.read();

      final byRoute = {for (final a in observed) a.route: a};
      expect(byRoute.keys, {
        'mirror:gone.example',
        'mirror:good.example',
        'mirror:block.example',
      });
      expect(observed.every((a) => a.method == 'GET'), isTrue);
      expect(observed.every((a) => a.endpoint == Bootstrap.endpoint), isTrue);
      expect(byRoute['mirror:good.example']!.status, 200);
      expect(byRoute['mirror:gone.example']!.status, 404);
      // A page that is not our file is not a host that works.
      expect(byRoute['mirror:block.example']!.status, isNull);
      expect(byRoute['mirror:block.example']!.error, isA<FormatException>());
    });

    test('a host that never answers does not hold the read up once another '
        'has given a file, and is not reported as failing', () async {
      final good = await seal(payload(issuedAt: 1000));
      final b = bootstrap({
        'good.example': () async => http.Response(good, 200),
        'stuck.example': () => Future.delayed(
          const Duration(seconds: 5),
          () => http.Response('', 504),
        ),
      });

      final watch = Stopwatch()..start();
      final file = await b.read();

      expect(file, isNotNull);
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(observed.map((a) => a.route), ['mirror:good.example']);
    });

    test(
      'GitHub\'s API is asked for the file itself, other hosts plainly',
      () async {
        final good = await seal(payload(issuedAt: 1000));
        final asked = <String, String?>{};
        final b = Bootstrap(
          client: () => MockClient((request) async {
            asked[request.url.host] = request.headers['Accept'];
            return http.Response(good, 200);
          }),
          builtIn: const [
            'https://raw.example/data/index.txt',
            'https://api.github.com/repos/o/r/contents/data/index.txt',
          ],
          publicKey: publicKey,
          sealKey: sealKey,
          seed: () async => null,
        );

        await b.read();

        expect(asked['api.github.com'], 'application/vnd.github.raw+json');
        expect(asked['raw.example'], isNull);
      },
    );

    test('the copy built into the app is used when nothing newer was read, '
        'and is never saved as if it had been read', () async {
      final built = await seal(payload(issuedAt: 9000, links: ['vless://s#s']));
      Future<Bootstrap> restored() async {
        final b = Bootstrap(
          builtIn: const [],
          publicKey: publicKey,
          sealKey: sealKey,
          seed: () async => built,
        );
        await b.restore();
        return b;
      }

      expect((await restored()).file!.links, ['vless://s#s']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(Bootstrap.savedKey), isNull);

      // Read long before this build: the built-in copy is newer.
      SharedPreferences.setMockInitialValues({
        Bootstrap.savedKey: await seal(
          payload(issuedAt: 100, links: ['vless://old#old']),
        ),
      });
      expect((await restored()).file!.links, ['vless://s#s']);

      // Read after this build was made: the kept file is newer.
      SharedPreferences.setMockInitialValues({
        Bootstrap.savedKey: await seal(
          payload(issuedAt: 20000, links: ['vless://new#new']),
        ),
      });
      expect((await restored()).file!.links, ['vless://new#new']);
    });

    test(
      'a file older than the one already kept does not replace it',
      () async {
        final kept = await seal(
          payload(issuedAt: 5000, links: ['vless://k#k']),
        );
        SharedPreferences.setMockInitialValues({Bootstrap.savedKey: kept});
        final older = await seal(payload(issuedAt: 1000));
        final b = bootstrap({
          'old.example': () async => http.Response(older, 200),
        });

        final file = await b.read();

        expect(file!.links, ['vless://k#k']);
      },
    );

    test('the file and the extra hosts kept by an earlier run are taken up '
        'at launch', () async {
      final kept = await seal(
        payload(issuedAt: 5000, mirrors: ['https://more.example/x']),
      );
      SharedPreferences.setMockInitialValues({
        Bootstrap.savedKey: kept,
        Bootstrap.extraMirrorsKey: jsonEncode(['https://config.example/y']),
      });
      final b = bootstrap({'a.example': () async => http.Response('', 404)});

      await b.restore();

      expect(b.file!.issuedAt.millisecondsSinceEpoch, 5000000);
      expect(b.mirrors, [
        'https://a.example/data/index.txt',
        'https://config.example/y',
        'https://more.example/x',
      ]);
    });

    test('the hosts /app/config names are kept, https only', () async {
      final b = bootstrap({});
      await b.adoptMirrors(['https://x.example/f', 'http://plain.example/f']);
      expect(b.mirrors, ['https://x.example/f']);
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString(Bootstrap.extraMirrorsKey)!), [
        'https://x.example/f',
      ]);
    });

    test('a file built less than half an hour ago is not read again', () async {
      var asked = 0;
      final clock = DateTime.utc(2026, 10, 11, 12);
      final recent = await seal(
        payload(issuedAt: clock.millisecondsSinceEpoch ~/ 1000 - 600),
      );
      SharedPreferences.setMockInitialValues({Bootstrap.savedKey: recent});
      final b = bootstrap({
        'good.example': () async {
          asked++;
          return http.Response(recent, 200);
        },
      }, now: () => clock);
      await b.restore();

      b.readSoon();
      await pumpEventQueue(times: 50);

      expect(asked, 0);
    });

    test('many failed calls start one read, and after one that got a file, '
        'even an old one, none for half an hour', () async {
      var asked = 0;
      var clock = DateTime.utc(2026, 10, 11, 12);
      // Built 50 minutes before: a host can serve a file this old.
      final old = await seal(
        payload(issuedAt: clock.millisecondsSinceEpoch ~/ 1000 - 3000),
      );
      final b = bootstrap({
        'good.example': () async {
          asked++;
          return http.Response(old, 200);
        },
      }, now: () => clock);

      b.readSoon();
      b.readSoon();
      await pumpEventQueue(times: 50);
      expect(asked, 1);
      expect(b.file, isNotNull);

      clock = clock.add(const Duration(minutes: 10));
      b.readSoon();
      await pumpEventQueue(times: 50);
      expect(asked, 1);

      clock = clock.add(const Duration(minutes: 25));
      b.readSoon();
      await pumpEventQueue(times: 50);
      expect(asked, 2);
    });

    test(
      'after a read that found nothing, the next waits five minutes',
      () async {
        var asked = 0;
        var clock = DateTime.utc(2026, 10, 11, 12);
        final b = bootstrap({
          'down.example': () async {
            asked++;
            return http.Response('', 503);
          },
        }, now: () => clock);

        b.readSoon();
        await pumpEventQueue(times: 50);
        clock = clock.add(const Duration(minutes: 3));
        b.readSoon();
        await pumpEventQueue(times: 50);
        expect(asked, 1);

        clock = clock.add(const Duration(minutes: 3));
        b.readSoon();
        await pumpEventQueue(times: 50);
        expect(asked, 2);
      },
    );

    test('a phone whose clock is behind still reads: a file built "in the '
        'future" says nothing about its age', () async {
      var asked = 0;
      final clock = DateTime.utc(2026, 10, 11, 12);
      final ahead = await seal(
        payload(issuedAt: clock.millisecondsSinceEpoch ~/ 1000 + 7200),
      );
      SharedPreferences.setMockInitialValues({Bootstrap.savedKey: ahead});
      final b = bootstrap({
        'good.example': () async {
          asked++;
          return http.Response(ahead, 200);
        },
      }, now: () => clock);
      await b.restore();

      b.readSoon();
      await pumpEventQueue(times: 50);

      expect(asked, 1);
    });
  });
}
