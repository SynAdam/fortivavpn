import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/bootstrap.dart';
import 'package:fortiva_vpn/api/notices_file.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The notices file: the broadcast messages, read from the public hosts
/// when the backend cannot be reached (lib/api/notices_file.dart, and the
/// backend's side of the same format).

/// The backend's test keys (tests/test_bootstrap_file.py there).
final seed = List<int>.generate(32, (i) => i);
final sealKey = List<int>.generate(32, (i) => 32 + i);

/// A notices file the backend sealed with its test keys and a fixed nonce
/// (its seal, with NOTICES_CONTEXT). Opening it
/// here is what proves the two sides agree on the format.
const backendVector =
    'AUBBQkNERUZHSElKS7qO4A-RGEY7XrQPTXdz1GILmhO4WOftDSAlvpQiQIoJywKc'
    'JBcC3GhrGpPWeSwFUAFu6wPp49MQokATOgTAEd9wIZtGDPsid0kABcs7avAdisVw'
    '-La7ehg9ptbNAgadyTKOy4kMqynqlN4FWDGfcRk7UJ8mw8FlLSsqFGTVqDRsK2c2'
    '1Nle0kuaH5RNjq37tKioSCK7U4BwpvWplA5f0DFVZyR6ReECvAVW2hPbIUyxst_j'
    '2kZmswfWNmQ1mXCdR9xUIz-yitumZm06zfBeBc-X03tpiQ34J-45-MtQh0ezVbTw'
    'hTqJ_K9v1STKCw9Fsc-8oXYqc341zT9Spa-YBO8vdJK0YBYb7eGuxA.UsV6oUy-R'
    'WemZRGmXgdDUNJA23m0Loitrg9sXjfKVWVho7NE-VRd6QcjUp4Nk1PW8NJKnZdfR'
    'aT3CsmTPNwHDg';

/// [payload] sealed the way the backend seals a file, under [context].
Future<String> seal(
  Map<String, Object?> payload, {
  String context = NoticesFile.context,
  List<int>? signWith,
}) async {
  final aad = utf8.encode(context);
  final box = await AesGcm.with256bits().encrypt(
    ZLibCodec().encode(utf8.encode(jsonEncode(payload))),
    secretKey: SecretKey(sealKey),
    nonce: List<int>.generate(12, (i) => 64 + i),
    aad: aad,
  );
  final body = [1, ...box.nonce, ...box.cipherText, ...box.mac.bytes];
  final pair = await Ed25519().newKeyPairFromSeed(signWith ?? seed);
  final signature = await Ed25519().sign([...aad, ...body], keyPair: pair);
  String b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');
  return '${b64(body)}.${b64(signature.bytes)}';
}

Map<String, Object?> notice({
  int id = 7,
  String sentAt = '2026-10-12T08:00:00Z',
  String endsAt = '2026-10-19T08:00:00Z',
  String? link = 'https://t.me/fortiva_vpn',
  List<String> countries = const [],
  String? minVersion,
  String? maxVersion,
  Map<String, Map<String, Object?>>? texts,
}) => {
  'id': id,
  'sent_at': sentAt,
  'ends_at': endsAt,
  'link': link,
  'countries': countries,
  'min_version': minVersion,
  'max_version': maxVersion,
  'texts':
      texts ??
      {
        'en': {
          'title': 'Hello',
          'body': 'News for everyone',
          'button': 'Open',
          'fallback': false,
        },
        'fa': {
          'title': 'سلام',
          'body': 'خبر برای همه',
          'button': 'باز کن',
          'fallback': false,
        },
      },
};

Map<String, Object?> file(int issuedAt, List<Map<String, Object?>> notices) => {
  'v': 1,
  'issued_at': issuedAt,
  'notices': notices,
};

final now = DateTime.utc(2026, 10, 12, 12);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<int> publicKey;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final pair = await Ed25519().newKeyPairFromSeed(seed);
    publicKey = (await pair.extractPublicKey()).bytes;
  });

  Future<NoticesFile?> open(String text) =>
      NoticesFile.open(text, publicKey: publicKey, sealKey: sealKey);

  group('opening a file', () {
    test('the line the backend sealed opens here to what went in', () async {
      final opened = await open(backendVector);
      expect(opened, isNotNull);
      expect(
        opened!.issuedAt,
        DateTime.fromMillisecondsSinceEpoch(1760270400000, isUtc: true),
      );
      final n = opened.notices.single;
      expect(n.id, 12);
      expect(n.countries, ['IR']);
      expect(n.minVersion, '1.9.0');
      expect(n.maxVersion, isNull);
      final m = opened
          .forPhone(language: 'fa', now: now, country: 'IR', version: '1.9.0')
          .single;
      expect(m.title, 'سلام');
      expect(m.button, 'باز کن');
      expect(m.link, Uri.parse('https://t.me/fortiva_vpn'));
    });

    test('a sealed file opens to its notices, newest first', () async {
      final opened = await open(
        await seal(file(1760270400, [notice(id: 9), notice(id: 7)])),
      );
      expect(opened, isNotNull);
      expect(
        opened!.issuedAt,
        DateTime.fromMillisecondsSinceEpoch(1760270400000, isUtc: true),
      );
      expect([for (final n in opened.notices) n.id], [9, 7]);
    });

    test('one changed character in the signature and nothing opens', () async {
      final text = await seal(file(1, [notice()]));
      final i = text.length - 5;
      final changed =
          text.substring(0, i) +
          (text[i] == 'A' ? 'B' : 'A') +
          text.substring(i + 1);
      expect(await open(changed), isNull);
    });

    test('a file signed with another key is refused', () async {
      final other = List<int>.generate(32, (i) => 200 - i);
      expect(
        await open(await seal(file(1, [notice()]), signWith: other)),
        isNull,
      );
    });

    test('the fallback file never opens as a notices file, nor the other '
        'way round', () async {
      final index = await seal({
        'v': 1,
        'issued_at': 1,
        'relays': [],
        'links': ['vless://a@198.51.100.7:443#a'],
        'mirrors': [],
      }, context: BootstrapFile.context);
      expect(await open(index), isNull);

      final notices = await seal(file(1, [notice()]));
      expect(
        await BootstrapFile.open(
          notices,
          publicKey: publicKey,
          sealKey: sealKey,
        ),
        isNull,
      );
    });

    test('an empty list is a file: it is how a withdrawal arrives', () async {
      final opened = await open(await seal(file(5, [])));
      expect(opened, isNotNull);
      expect(opened!.notices, isEmpty);
    });

    test('an entry this app cannot read costs that entry only', () async {
      final opened = await open(
        await seal(
          file(5, [
            {'id': 'x'},
            notice(id: 3),
          ]),
        ),
      );
      expect([for (final n in opened!.notices) n.id], [3]);
    });
  });

  group('which notices a phone gets', () {
    Future<NoticesFile> one(Map<String, Object?> n) async =>
        (await open(await seal(file(1, [n]))))!;

    test('in the app language, with the button and its link', () async {
      final f = await one(notice());
      final [m] = f.forPhone(language: 'fa', now: now);
      expect(m.id, 7);
      expect(m.language, 'fa');
      expect(m.title, 'سلام');
      expect(m.body, 'خبر برای همه');
      expect(m.button, 'باز کن');
      expect(m.link, Uri.parse('https://t.me/fortiva_vpn'));
    });

    test('a language the team showed in English says en, and so does a '
        'language the notice has no text for', () async {
      final f = await one(
        notice(
          texts: {
            'en': {'title': 'Hi', 'body': 'Body', 'fallback': false},
            'fa': {'title': 'Hi', 'body': 'Body', 'fallback': true},
          },
        ),
      );
      expect(f.forPhone(language: 'fa', now: now).single.language, 'en');
      expect(f.forPhone(language: 'de', now: now).single.language, 'en');
    });

    test('a button without a link is dropped, the message kept', () async {
      final f = await one(notice(link: null));
      final m = f.forPhone(language: 'en', now: now).single;
      expect(m.button, isNull);
      expect(m.link, isNull);
    });

    test('an ended notice is not shown', () async {
      final f = await one(notice(endsAt: '2026-10-12T11:59:59Z'));
      expect(f.forPhone(language: 'en', now: now), isEmpty);
    });

    test('countries: only phones placed in one of them, never a phone whose '
        'country is not known', () async {
      final f = await one(notice(countries: ['IR', 'TR']));
      expect(f.forPhone(language: 'en', now: now, country: 'IR'), hasLength(1));
      expect(f.forPhone(language: 'en', now: now, country: 'ir'), hasLength(1));
      expect(f.forPhone(language: 'en', now: now, country: 'DE'), isEmpty);
      expect(f.forPhone(language: 'en', now: now), isEmpty);
      final everyone = await one(notice());
      expect(everyone.forPhone(language: 'en', now: now), hasLength(1));
    });

    test('versions: inclusive bounds compared as numbers, an unknown version '
        'left out', () async {
      final f = await one(notice(minVersion: '1.8.0', maxVersion: '1.10.0'));
      List<int> ids(String? v) => [
        for (final m in f.forPhone(language: 'en', now: now, version: v)) m.id,
      ];
      expect(ids('1.8.0'), [7]);
      expect(ids('1.9'), [7]);
      expect(ids('1.10.0'), [7]);
      expect(ids('1.7.9'), isEmpty);
      expect(ids('1.10.1'), isEmpty);
      expect(ids(null), isEmpty);
    });

    test(
      'a bound that does not parse is no bound, as on the backend',
      () async {
        final f = await one(notice(minVersion: 'soon'));
        expect(
          f.forPhone(language: 'en', now: now, version: '1.0.0'),
          hasLength(1),
        );
        expect(f.forPhone(language: 'en', now: now), hasLength(1));
      },
    );
  });

  group('where the file is read', () {
    test('beside every fallback file path, GitHub API included', () {
      expect(
        NoticesReader.urlsFrom(Bootstrap.builtInMirrors),
        hasLength(Bootstrap.builtInMirrors.length),
      );
      expect(
        NoticesReader.urlsFrom([
          'https://raw.githubusercontent.com/o/r/main/data/index.txt',
          'https://api.github.com/repos/o/r/contents/data/index.txt',
          'https://example.org/other.txt',
        ]),
        [
          'https://raw.githubusercontent.com/o/r/main/data/notices.txt',
          'https://api.github.com/repos/o/r/contents/data/notices.txt',
        ],
      );
    });
  });

  group('reading the file from its hosts', () {
    late List<String> asked;
    late DateTime clock;

    NoticesReader reader(Map<String, Future<http.Response> Function()> hosts) {
      return NoticesReader(
        indexUrls: () => [
          for (final h in hosts.keys) 'https://$h/data/index.txt',
        ],
        client: () => MockClient((request) {
          asked.add(request.url.host);
          final answer = hosts[request.url.host];
          if (answer == null) throw const SocketException('no route');
          return answer();
        }),
        publicKey: publicKey,
        sealKey: sealKey,
        now: () => clock,
        grace: const Duration(milliseconds: 20),
      );
    }

    setUp(() {
      asked = [];
      clock = now;
    });

    test('the newest file that opens wins and is saved; GitHub API is not '
        'asked when another host gave one', () async {
      final older = await seal(file(1000, [notice(id: 1)]));
      final newer = await seal(file(2000, [notice(id: 2)]));
      final r = reader({
        'old.example': () async => http.Response(older, 200),
        'new.example': () async => http.Response(newer, 200),
        'block.example': () async => http.Response('<html>no</html>', 200),
        'api.github.com': () async => http.Response(newer, 200),
      });

      final got = await r.read();

      expect([for (final n in got!.notices) n.id], [2]);
      expect(asked, isNot(contains('api.github.com')));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(NoticesReader.savedKey), newer);
    });

    test('GitHub API is read when no other host gave a file', () async {
      final text = await seal(file(1000, [notice(id: 4)]));
      final r = reader({
        'gone.example': () async => http.Response('', 404),
        'api.github.com': () async => http.Response(text, 200),
      });
      final got = await r.read();
      expect([for (final n in got!.notices) n.id], [4]);
      expect(asked, containsAll(['gone.example', 'api.github.com']));
    });

    test(
      'a host that serves a file with a changed signature is ignored',
      () async {
        final text = await seal(file(1000, [notice(id: 4)]));
        final broken = '${text.substring(0, text.length - 2)}AA';
        final r = reader({
          'evil.example': () async => http.Response(broken, 200),
        });
        expect(await r.read(), isNull);
      },
    );

    test('no second read within 9 minutes of one that got a file, so a '
        'check every 10 minutes reads each new file; the saved one is '
        'answered instead', () async {
      final text = await seal(file(1000, [notice(id: 4)]));
      final r = reader({'a.example': () async => http.Response(text, 200)});
      await r.read();
      asked.clear();
      clock = now.add(const Duration(minutes: 8));
      final again = await r.read();
      expect(asked, isEmpty);
      expect([for (final n in again!.notices) n.id], [4]);
      clock = now.add(const Duration(minutes: 10));
      await r.read();
      expect(asked, ['a.example']);
    });

    test('after a read that found nothing, quiet for 5 minutes', () async {
      final r = reader({'gone.example': () async => http.Response('', 404)});
      expect(await r.read(), isNull);
      asked.clear();
      clock = now.add(const Duration(minutes: 4));
      await r.read();
      expect(asked, isEmpty);
      clock = now.add(const Duration(minutes: 6));
      await r.read();
      expect(asked, ['gone.example']);
    });

    test('GitHub API at most every 30 minutes, because phones behind one '
        'carrier address share its 60 reads an hour', () async {
      final r = reader({
        'gone.example': () async => http.Response('', 404),
        'api.github.com': () async => http.Response('', 403),
      });
      await r.read();
      expect(asked, containsAll(['gone.example', 'api.github.com']));
      asked.clear();
      clock = now.add(const Duration(minutes: 10));
      await r.read();
      expect(asked, ['gone.example']);
      asked.clear();
      clock = now.add(const Duration(minutes: 31));
      await r.read();
      expect(asked, containsAll(['gone.example', 'api.github.com']));
    });

    test(
      'an older file from a host never replaces a newer saved one',
      () async {
        final newer = await seal(file(2000, [notice(id: 2)]));
        final older = await seal(file(1000, [notice(id: 1)]));
        SharedPreferences.setMockInitialValues({NoticesReader.savedKey: newer});
        final r = reader({
          'old.example': () async => http.Response(older, 200),
        });
        final got = await r.read();
        expect([for (final n in got!.notices) n.id], [2]);
      },
    );
  });
}
