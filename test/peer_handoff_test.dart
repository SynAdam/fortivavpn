import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/api_routes.dart';
import 'package:fortiva_vpn/api/bootstrap.dart';
import 'package:fortiva_vpn/api/built_in.dart';
import 'package:fortiva_vpn/api/peer_code.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/services/peer_pick.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bootstrap_file_test.dart'
    show fileOfRealSize, payload, pin, seal, sealKey, seed;

/// Passing the fallback file from a phone that has it to one that cannot
/// get it anywhere else (NimusAI/fortiva-vpn-clients#265).
///
/// The phone that has it shows it as QR codes, or sends or copies it; the
/// other photographs the codes, opens the file or pastes it. Nothing about
/// the other phone is trusted: what arrives is opened and checked like a
/// file read from a host, and kept only when it is newer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<int> publicKey;
  var clock = DateTime.utc(2026, 10, 12, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ApiRelays.resetForTest();
    clock = DateTime.utc(2026, 10, 12, 12);
    final pair = await Ed25519().newKeyPairFromSeed(seed);
    publicKey = (await pair.extractPublicKey()).bytes;
  });

  int at(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

  Bootstrap bootstrap({
    Map<String, Future<http.Response> Function()> hosts = const {},
    String? built,
    Future<http.Client?> Function()? tunnel,
  }) => Bootstrap(
    tunnel: tunnel ?? () async => null,
    client: () => MockClient((request) {
      final answer = hosts[request.url.host];
      if (answer == null) throw const SocketException('no route');
      return answer();
    }),
    builtIn: [for (final h in hosts.keys) 'https://$h/data/index.txt'],
    publicKey: publicKey,
    sealKey: sealKey,
    grace: const Duration(milliseconds: 50),
    now: () => clock,
    seed: () async => built,
  );

  group('the codes', () {
    late String line;

    setUpAll(() async {
      // The copy built into the app: a file of the real size. The public
      // copy of the repo has none, and makes one of about that size.
      line = BuiltIn.isPublicCopy
          ? await fileOfRealSize()
          : (await File(Bootstrap.seedAsset).readAsString()).trim();
    });

    test('a real file is cut into a few codes small enough to photograph, '
        'and put back together in any order', () {
      final codes = PeerCode.split(line);
      expect(codes.length, inInclusiveRange(2, 4));
      for (final c in codes) {
        expect(c.length, lessThan(PeerCode.maxPiece + 32));
      }

      final reader = PeerCodeReader();
      for (final c in codes.reversed) {
        expect(reader.line, isNull);
        expect(reader.add(c), PeerPiece.added);
      }
      expect(reader.line, line);
      expect(reader.have, codes.length);
      expect(reader.total, codes.length);
    });

    test('a code read twice counts once', () {
      final codes = PeerCode.split(line);
      final reader = PeerCodeReader();
      expect(reader.add(codes.first), PeerPiece.added);
      expect(reader.add(codes.first), PeerPiece.again);
      expect(reader.have, 1);
    });

    test('the codes read so far survive a restart of the app', () {
      final codes = PeerCode.split(line);
      final reader = PeerCodeReader()
        ..add(codes[0])
        ..add(codes[2]);
      final again = PeerCodeReader.fromJson(reader.toJson());
      expect(again.have, 2);
      expect(again.total, codes.length);
      for (final c in codes) {
        again.add(c);
      }
      expect(again.line, line);
      expect(again.toJson(), isNull, reason: 'a whole file is not kept');
      expect(PeerCodeReader.fromJson({'id': 'x', 'total': 99}).have, 0);
      expect(PeerCodeReader.fromJson('nonsense').have, 0);
    });

    test('a code of another file starts again, so two files are never '
        'joined into one', () {
      final mine = PeerCode.split(line);
      final theirs = PeerCode.split('${'A' * 3000}.${'B' * 86}');
      final reader = PeerCodeReader()..add(mine[0]);
      expect(reader.add(theirs[1]), PeerPiece.added);
      expect(reader.have, 1);
      expect(reader.total, theirs.length);
    });

    test('a code of something else is not ours', () {
      final reader = PeerCodeReader();
      for (final text in [
        'https://example.org',
        'vless://u@198.51.100.7:443#a',
        'FV1:0/3:abcd:xyz',
        'FV1:4/3:abcd:xyz',
        'FV1:1/99:abcd:xyz',
        '',
      ]) {
        expect(reader.add(text), PeerPiece.notOurs, reason: text);
      }
      expect(reader.have, 0);
    });

    test('a whole line is found in a message, an HTML wrapper or broken '
        'across lines', () {
      expect(PeerCode.lineIn(line), line);
      expect(PeerCode.lineIn('Here you go:\n$line\nThanks'), line);
      expect(PeerCode.lineIn('<html><p>$line</p></html>'), line);
      final broken = [
        for (var i = 0; i < line.length; i += 70)
          line.substring(i, (i + 70).clamp(0, line.length)),
      ].join('\n');
      expect(PeerCode.lineIn(broken), line);
      expect(PeerCode.lineIn('Use this: $line.'), line);
      expect(PeerCode.lineIn('nothing here'), isNull);
    });

    test('a line wrapped by a messenger is found with words around it, and '
        'a wide wrap whose last piece looks like a line is not taken for '
        'it', () {
      String wrap(int width) => [
        for (var i = 0; i < line.length; i += width)
          line.substring(i, (i + width).clamp(0, line.length)),
      ].join('\n');
      for (final width in [70, 76, 100, 500, 1000, 1500, 2000]) {
        expect(
          PeerCode.lineIn('Hi,\n${wrap(width)}\nBest,\nAli'),
          line,
          reason: 'wrapped at $width',
        );
        expect(
          PeerCode.lineIn('Here you go\n${wrap(width)}'),
          line,
          reason: 'greeting, wrapped at $width',
        );
        expect(PeerCode.linesIn(wrap(width)).first, line, reason: '$width');
      }
    });

    test('anything pasted is searched quickly, however long', () {
      final watch = Stopwatch()..start();
      for (final text in [
        'A' * Bootstrap.maxBytes,
        '${'A' * Bootstrap.maxBytes}.',
        'A.' * (Bootstrap.maxBytes ~/ 2),
        'A ' * (Bootstrap.maxBytes ~/ 2),
        '${'.' * Bootstrap.maxBytes}A',
        '${'. ' * (Bootstrap.maxBytes ~/ 2)}A',
        '${'A\n' * (Bootstrap.maxBytes ~/ 2)}.',
      ]) {
        expect(PeerCode.lineIn(text), isNull);
        expect(PeerCodeReader().add(text), PeerPiece.notOurs);
      }
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });
  });

  group('taking a file from another phone', () {
    test(
      'a newer file is kept, saved and used: its links and relays',
      () async {
        final b = bootstrap(
          built: await seal(payload(issuedAt: at(clock) - 3600)),
        );
        final servers = ServerState(bootstrap: b);
        final newer = await seal(
          payload(
            issuedAt: at(clock),
            links: ['vless://u@198.51.100.9:443?type=tcp#friend'],
            relays: [
              {'url': 'https://203.0.113.9:443', 'pin': pin},
            ],
          ),
        );

        expect(await b.takeFromPeer(newer), PeerTake.taken);

        expect(b.file!.issuedAt, clock);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(Bootstrap.savedKey), newer);
        expect(
          (await ApiRelays.current()).first,
          const ApiRelay(url: 'https://203.0.113.9:443', pin: pin),
        );
        expect(servers.communityServers.map((s) => s.connectionUri), [
          'vless://u@198.51.100.9:443?type=tcp#friend',
        ]);
        servers.dispose();
      },
    );

    test('the same file, or an older one, is not taken again', () async {
      final kept = await seal(payload(issuedAt: 5000));
      final b = bootstrap(built: kept);

      expect(await b.takeFromPeer(kept), PeerTake.notNewer);
      expect(
        await b.takeFromPeer(await seal(payload(issuedAt: 4000))),
        PeerTake.notNewer,
      );
      expect(b.file!.issuedAt.millisecondsSinceEpoch, 5000000);
    });

    test('a file another phone changed, signed with another key, cut short '
        'or far too big is refused', () async {
      final b = bootstrap();
      final good = await seal(payload(issuedAt: 5000));
      final changed =
          '${good.substring(0, 40)}${good[40] == 'A' ? 'B' : 'A'}'
          '${good.substring(41)}';
      final otherKey = await seal(
        payload(issuedAt: 5000),
        signWith: List<int>.generate(32, (i) => 200 - i),
      );

      for (final text in [
        changed,
        otherKey,
        good.substring(0, good.length - 10),
        'x' * (Bootstrap.maxBytes + 1),
        '',
      ]) {
        expect(await b.takeFromPeer(text), PeerTake.refused);
      }
      expect(b.file, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(Bootstrap.savedKey), isNull);
    });
  });

  group('what a phone hands out', () {
    test(
      'only a file it opened itself, built less than shareFor ago',
      () async {
        expect(bootstrap().shareable, isNull);

        final b = bootstrap(built: await seal(payload(issuedAt: at(clock))));
        await b.restore();
        expect(b.shareable, same(b.file));

        clock = clock.add(Bootstrap.shareFor - const Duration(minutes: 1));
        expect(b.shareable, same(b.file));
        clock = clock.add(const Duration(minutes: 2));
        expect(b.shareable, isNull);
      },
    );

    test('before handing out, a stale file is refreshed from the hosts; a '
        'fresh one is not', () async {
      var asked = 0;
      final newer = await seal(payload(issuedAt: at(clock)));
      final b = bootstrap(
        hosts: {
          'host.example': () async {
            asked++;
            return http.Response(newer, 200);
          },
        },
        built: await seal(
          payload(issuedAt: at(clock.subtract(const Duration(days: 3)))),
        ),
      );

      expect((await b.readForSharing())!.issuedAt, clock);
      expect(asked, 1);

      await b.readForSharing();
      expect(asked, 1, reason: 'the file is fresh now');
    });

    test('a connected phone reads through its tunnel, and those reads are '
        'not reported as reads on its own network', () async {
      final observed = <RouteAttempt>[];
      ApiClient.onRouteAttempt = observed.add;
      addTearDown(() => ApiClient.onRouteAttempt = null);
      var direct = 0;
      final newer = await seal(payload(issuedAt: at(clock)));
      final b = bootstrap(
        hosts: {
          'host.example': () async {
            direct++;
            return http.Response(newer, 200);
          },
        },
        built: await seal(
          payload(issuedAt: at(clock.subtract(const Duration(days: 3)))),
        ),
        tunnel: () async =>
            MockClient((request) async => http.Response(newer, 200)),
      );

      expect((await b.readForSharing())!.issuedAt, clock);
      expect(direct, 0);
      expect(observed, isEmpty);
    });

    test('without a tunnel, a read that found nothing is not repeated at '
        'once', () async {
      var asked = 0;
      final b = bootstrap(
        hosts: {
          'host.example': () async {
            asked++;
            throw const SocketException('cut');
          },
        },
      );

      await b.readForSharing();
      await b.readForSharing();
      expect(asked, 1);
      clock = clock.add(Bootstrap.quietAfterNothing);
      await b.readForSharing();
      expect(asked, 2);
    });

    // Long enough for a read whose hosts all fail at once to end.
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 100));

    test('a read through the tunnel that finds nothing says nothing about '
        'the phone\'s own network: no failure is recorded, and the next '
        'read there is not held back', () async {
      var direct = 0;
      final b = bootstrap(
        hosts: {
          'host.example': () async {
            direct++;
            throw const SocketException('cut');
          },
        },
        built: await seal(
          payload(issuedAt: at(clock.subtract(const Duration(days: 3)))),
        ),
        tunnel: () async => MockClient(
          (request) async => throw const SocketException('cut too'),
        ),
      );
      var told = 0;
      b.addListener(() => told++);
      await b.restore();
      told = 0;

      await b.readForSharing();
      expect(direct, 0);
      expect(b.nothingFound, isFalse);
      expect(told, 0);

      b.readSoon();
      await settle();
      expect(direct, 1, reason: 'no quiet time after the tunnel read');
    });

    test('a read on the phone\'s own network that finds nothing still '
        'records it, and holds the next one back', () async {
      var direct = 0;
      final b = bootstrap(
        hosts: {
          'host.example': () async {
            direct++;
            throw const SocketException('cut');
          },
        },
        built: await seal(
          payload(issuedAt: at(clock.subtract(const Duration(days: 3)))),
        ),
      );

      b.readSoon();
      await settle();
      expect(direct, 1);
      expect(b.nothingFound, isTrue);

      b.readSoon();
      await settle();
      expect(direct, 1, reason: 'quiet after a read that found nothing');
      clock = clock.add(Bootstrap.quietAfterNothing);
      b.readSoon();
      await settle();
      expect(direct, 2);
    });

    test('the client through the tunnel is closed, also when there is '
        'nowhere to read and when a read is already under way', () async {
      // Nowhere to read: no hosts, and no file naming any.
      final idle = _CountingClient(
        MockClient((request) async => http.Response('', 404)),
      );
      final none = bootstrap(tunnel: () async => idle);
      expect(none.mirrors, isEmpty);
      await none.readForSharing();
      expect(idle.closed, 1);
      expect(idle.sent, 0);

      // A read on the phone's own network under way: waited for.
      final hold = Completer<http.Response>();
      final waiting = _CountingClient(
        MockClient((request) async => http.Response('', 404)),
      );
      final busy = bootstrap(
        hosts: {'host.example': () => hold.future},
        tunnel: () async => waiting,
      );
      final reading = busy.read();
      await Future<void>.delayed(Duration.zero);
      final sharing = busy.readForSharing();
      await Future<void>.delayed(Duration.zero);
      hold.completeError(const SocketException('cut'));
      await Future.wait([reading, sharing]);
      expect(waiting.closed, 1);
      expect(waiting.sent, 0);

      // A read through it: closed once, when it ends.
      final newer = await seal(payload(issuedAt: at(clock)));
      final used = _CountingClient(
        MockClient((request) async => http.Response(newer, 200)),
      );
      final b = bootstrap(
        hosts: {'host.example': () async => http.Response(newer, 200)},
        tunnel: () async => used,
      );
      expect((await b.readForSharing())!.issuedAt, clock);
      expect(used.sent, 1);
      expect(used.closed, 1);
    });
  });

  group('whether every other place has failed', () {
    test('set when a read finds nothing, cleared by a read that finds a '
        'file or by a file from another phone', () async {
      var up = false;
      final file = await seal(payload(issuedAt: at(clock)));
      final b = bootstrap(
        hosts: {
          'host.example': () async {
            if (!up) throw const SocketException('cut');
            return http.Response(file, 200);
          },
        },
      );
      var told = 0;
      b.addListener(() => told++);

      expect(b.nothingFound, isFalse);
      await b.read();
      expect(b.nothingFound, isTrue);
      expect(told, 1);

      up = true;
      await b.read();
      expect(b.nothingFound, isFalse);

      up = false;
      clock = clock.add(const Duration(hours: 1));
      await b.read();
      expect(b.nothingFound, isTrue);
      final fromPeer = await seal(payload(issuedAt: at(clock)));
      expect(await b.takeFromPeer(fromPeer), PeerTake.taken);
      expect(b.nothingFound, isFalse);
    });

    test('a file from another phone that arrives during a read that finds '
        'nothing is not undone by it', () async {
      final hold = Completer<http.Response>();
      final b = bootstrap(hosts: {'host.example': () => hold.future});
      final reading = b.read();
      await Future<void>.delayed(Duration.zero);

      final fromPeer = await seal(payload(issuedAt: at(clock)));
      expect(await b.takeFromPeer(fromPeer), PeerTake.taken);
      hold.completeError(const SocketException('cut'));
      await reading;

      expect(b.nothingFound, isFalse);
    });
  });

  test(
    'the platform\'s answers are read, and anything else is unavailable',
    () {
      expect(PeerPick.parse({'status': 'ok', 'text': 'x'}), (
        status: PeerPickStatus.ok,
        text: 'x',
      ));
      expect(
        PeerPick.parse({'status': 'ok'}).status,
        PeerPickStatus.unavailable,
      );
      expect(
        PeerPick.parse({'status': 'cancelled'}).status,
        PeerPickStatus.cancelled,
      );
      expect(
        PeerPick.parse({'status': 'no_code'}).status,
        PeerPickStatus.noCode,
      );
      expect(
        PeerPick.parse({'status': 'unreadable'}).status,
        PeerPickStatus.unreadable,
      );
      expect(
        PeerPick.parse({'status': 'what'}).status,
        PeerPickStatus.unavailable,
      );
      expect(PeerPick.parse(null).status, PeerPickStatus.unavailable);
    },
  );
}

/// A client that counts the requests sent through it and how often it is
/// closed.
class _CountingClient extends http.BaseClient {
  _CountingClient(this._inner);

  final http.Client _inner;
  int sent = 0;
  int closed = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    sent++;
    return _inner.send(request);
  }

  @override
  void close() {
    closed++;
  }
}
