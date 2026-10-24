import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/api_routes.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/psiphon_settings.dart';
import 'package:fortiva_vpn/services/psiphon_entries.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config_state_test.dart' as base show configWith;

/// The backup network's server list (clients #299): the sha the config
/// names, the download through the API client, the copy kept on the phone
/// for the tunnel, and the path the tunnel is given.
///
/// Every value here is made up, the list's lines included.
const network = {
  'PropagationChannelId': '0123456789ABCDEF',
  'SponsorId': 'FEDCBA9876543210',
  'RemoteServerListURLs': ['https://lists.example.test/list'],
};

final listA = Uint8List.fromList(
  utf8.encode('3132372e302e302e31\n6578616d706c65\n'),
);
final listB = Uint8List.fromList(utf8.encode('6f74686572206c697374\n'));

String shaOf(List<int> bytes) => sha256.convert(bytes).toString();

PsiphonSettings settings({String? sha, bool tv = false}) => PsiphonSettings(
  network: network,
  enabled: true,
  tv: tv,
  serverEntriesSha: sha,
);

AppConfig configWith(Object? psiphon) =>
    AppConfig.fromJson({...base.configWith('').toJson(), 'psiphon': ?psiphon});

Future<AppConfig> unreachable() async => throw Exception('no route');

/// Records what AppConfigState asks of the list, and does nothing else.
class _Entries extends PsiphonEntries {
  _Entries({this.hold}) : super(android: () => true);

  final Completer<void>? hold;
  final asked = <PsiphonSettings?>[];

  @override
  Future<void> sync(PsiphonSettings? settings) {
    asked.add(settings);
    return hold?.future ?? Future<void>.value();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PsiphonSettings.current = null;
  });

  tearDown(() => PsiphonSettings.current = null);

  group('the sha in the config', () {
    test('is 64 lowercase hex characters', () {
      final sha = shaOf(listA);
      final read = PsiphonSettings.fromJson({
        'network': network,
        'server_entries_sha': sha,
      });
      expect(read!.serverEntriesSha, sha);
    });

    test('anything else is none, and the rest of the block still reads', () {
      final sha = shaOf(listA);
      for (final bad in <Object?>[
        null,
        '',
        sha.toUpperCase(),
        sha.substring(1),
        '${sha}0',
        'g${sha.substring(1)}',
        64,
        [sha],
      ]) {
        final read = PsiphonSettings.fromJson({
          'network': network,
          'tv': true,
          'server_entries_sha': bad,
        });
        expect(read, isNotNull, reason: '$bad');
        expect(read!.serverEntriesSha, isNull, reason: '$bad');
        expect(read.tv, isTrue);
      }
      expect(
        PsiphonSettings.fromJson({'network': network})!.serverEntriesSha,
        isNull,
      );
    });

    test('is kept for the next launch with the rest of the block', () async {
      final sha = shaOf(listA);
      final entries = _Entries();
      await AppConfigState(
        fetch: () async => configWith({
          'enabled': true,
          'network': network,
          'server_entries_sha': sha,
        }),
        psiphonEntries: entries,
      ).load();
      expect(PsiphonSettings.current!.serverEntriesSha, sha);

      PsiphonSettings.current = null;
      await AppConfigState(
        fetch: unreachable,
        retryGaps: const [],
        psiphonEntries: entries,
      ).load();
      expect(PsiphonSettings.current!.serverEntriesSha, sha);
      expect(
        PsiphonSettings.fromJson(
          jsonDecode(jsonEncode(PsiphonSettings.current!.toJson())),
        )!.serverEntriesSha,
        sha,
      );
    });
  });

  group('the download', () {
    const pin =
        'abababababababababababababababababababababababababababababababab';
    const relay = ApiRelay(url: 'https://203.0.113.6:443', pin: pin);

    http.Client answers(Object Function(http.Request) answer) =>
        MockClient((request) async {
          final a = answer(request);
          if (a is http.Response) return a;
          throw a;
        });

    test('hands back the body exactly as it came, text and all', () async {
      final paths = <String>[];
      final client = ApiClient.forTest(
        direct: answers((r) {
          paths.add(r.url.path);
          return http.Response.bytes(
            listA,
            200,
            headers: {'content-type': 'text/plain; charset=utf-8'},
          );
        }),
      );

      final body = await client.getBytes('/api/v1/app/psiphon/server-entries');

      expect(body, listA);
      expect(paths, ['/api/v1/app/psiphon/server-entries']);
    });

    test('goes through a relay when the phone own network drops it', () async {
      final client = ApiClient.forTest(
        direct: answers((_) => const SocketException('reset')),
        relay: (_) => answers((_) => http.Response.bytes(listB, 200)),
        relays: () async => const [relay],
      );

      expect(
        await client.getBytes('/api/v1/app/psiphon/server-entries'),
        listB,
      );
    });

    test('a 404 is an ApiException, as for any call', () async {
      final client = ApiClient.forTest(
        direct: answers((_) => http.Response('{"detail":"Not Found"}', 404)),
      );

      await expectLater(
        client.getBytes('/api/v1/app/psiphon/server-entries'),
        throwsA(isA<ApiException>().having((e) => e.isNotFound, '404', true)),
      );
    });

    test('has longer than a JSON call once its route has answered', () {
      expect(ApiClient.fileTimeout, greaterThan(ApiConfig.timeout));
      expect(ApiClient.fileMaxBytes, 16 * 1024 * 1024);
    });

    test('a body that does not arrive in its time is cut off and closed, '
        'no other route downloads it again, and no route is marked '
        'failed', () async {
      var closed = false;
      final body = StreamController<List<int>>(onCancel: () => closed = true);
      final paths = <String>[];
      final relayPaths = <String>[];
      final failedRelays = <ApiRelay>[];
      final client = ApiClient.forTest(
        direct: MockClient.streaming((request, _) async {
          paths.add(request.url.path);
          if (request.url.path == '/file') {
            return http.StreamedResponse(body.stream, 200);
          }
          return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
        }),
        relay: (_) => answers((r) {
          relayPaths.add(r.url.path);
          return http.Response.bytes(listB, 200);
        }),
        relays: () async => const [relay],
        relayFailed: (r) async => failedRelays.add(r),
      );
      // The start of the list arrives, and then nothing more.
      body.add(listA.sublist(0, 4));

      await expectLater(
        client.getBytes('/file', bodyTimeout: const Duration(milliseconds: 50)),
        throwsA(isA<DownloadCutOff>()),
      );

      expect(closed, isTrue);
      expect(relayPaths, isEmpty);
      expect(failedRelays, isEmpty);
      // The phone's own network still goes first for the next call, so it
      // was not marked failed either.
      await client.get('/next');
      expect(paths, ['/file', '/next']);
      expect(relayPaths, isEmpty);
    });

    test(
      'a body larger than the most it takes is cut off and closed',
      () async {
        var closed = false;
        final body = StreamController<List<int>>(onCancel: () => closed = true);
        final client = ApiClient.forTest(
          direct: MockClient.streaming(
            (_, _) async => http.StreamedResponse(body.stream, 200),
          ),
        );
        body
          ..add(List.filled(6, 0x61))
          ..add(List.filled(6, 0x62));

        await expectLater(
          client.getBytes('/file', maxBytes: 8),
          throwsA(isA<DownloadCutOff>()),
        );
        expect(closed, isTrue);
      },
    );

    test('a body whose length is more than the most it takes is closed '
        'before any of it is read', () async {
      var closed = false;
      // Nothing is ever sent: the length alone ends the call.
      final body = StreamController<List<int>>(onCancel: () => closed = true);
      final client = ApiClient.forTest(
        direct: MockClient.streaming(
          (_, _) async =>
              http.StreamedResponse(body.stream, 200, contentLength: 100),
        ),
      );

      await expectLater(
        client.getBytes('/file', maxBytes: 8),
        throwsA(isA<DownloadCutOff>()),
      );
      await pumpEventQueue();
      expect(closed, isTrue);
    });

    test('a route that does not answer in time is closed, and the next '
        'route is tried', () {
      fakeAsync((async) {
        http.BaseRequest? asked;
        final client = ApiClient.forTest(
          direct: MockClient.streaming((request, _) {
            asked = request;
            return Completer<http.StreamedResponse>().future;
          }),
          relay: (_) => answers((_) => http.Response.bytes(listB, 200)),
          relays: () async => const [relay],
        );
        Uint8List? got;
        client.getBytes('/file').then((b) => got = b);

        async.elapse(ApiConfig.timeout - const Duration(seconds: 1));
        expect(got, isNull);
        async.elapse(const Duration(seconds: 2));

        expect(got, listB);
        // The request that got no answer was told to stop.
        var aborted = false;
        (asked! as http.Abortable).abortTrigger!.then((_) => aborted = true);
        async.flushMicrotasks();
        expect(aborted, isTrue);
      });
    });
  });

  group('the copy on the phone', () {
    late Directory dir;
    late List<Uint8List> served;
    late int downloads;
    late Object? failWith;
    late bool android;
    late bool tv;
    late DateTime clock;

    File kept() => File('${dir.path}/psiphon/server_entries');
    File part() => File('${dir.path}/psiphon/server_entries.part');

    Future<String?> savedSha() async => (await SharedPreferences.getInstance())
        .getString(PsiphonEntries.shaKey);

    Future<String?> failedNote() async =>
        (await SharedPreferences.getInstance()).getString(
          PsiphonEntries.failedKey,
        );

    PsiphonEntries store() => PsiphonEntries(
      download: () async {
        downloads++;
        final e = failWith;
        if (e != null) throw e;
        return served.removeAt(0);
      },
      filesDir: () async => dir,
      android: () => android,
      tv: () => tv,
      now: () => clock,
    );

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('psiphon_entries_test');
      served = [];
      downloads = 0;
      failWith = null;
      android = true;
      tv = false;
      clock = DateTime(2026, 10, 16, 12);
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('is downloaded, checked and kept where the tunnel reads it, and '
        'then the sha is saved', () async {
      served = [listA];
      final entries = store();

      await entries.sync(settings(sha: shaOf(listA)));

      expect(downloads, 1);
      expect(await kept().readAsBytes(), listA);
      expect(await part().exists(), isFalse);
      expect(await savedSha(), shaOf(listA));
    });

    test('is not downloaded again while the sha stays the same', () async {
      served = [listA];
      final entries = store();
      await entries.sync(settings(sha: shaOf(listA)));

      await entries.sync(settings(sha: shaOf(listA)));
      await store().sync(settings(sha: shaOf(listA)));

      expect(downloads, 1);
    });

    test('is downloaded again when the file is gone', () async {
      served = [listA, listA];
      final entries = store();
      await entries.sync(settings(sha: shaOf(listA)));
      await kept().delete();

      await entries.sync(settings(sha: shaOf(listA)));

      expect(downloads, 2);
      expect(await kept().readAsBytes(), listA);
    });

    test('is replaced when the sha changes', () async {
      served = [listA, listB];
      final entries = store();
      await entries.sync(settings(sha: shaOf(listA)));

      await entries.sync(settings(sha: shaOf(listB)));

      expect(await kept().readAsBytes(), listB);
      expect(await savedSha(), shaOf(listB));
      expect(await part().exists(), isFalse);
    });

    test('a list that does not match its sha is thrown away, and the old '
        'file and sha stay', () async {
      served = [listA, listB];
      final entries = store();
      await entries.sync(settings(sha: shaOf(listA)));

      // The config names a new list, and something else arrives.
      final wanted = shaOf(utf8.encode('the list the backend meant\n'));
      await entries.sync(settings(sha: wanted));

      expect(await kept().readAsBytes(), listA);
      expect(await savedSha(), shaOf(listA));
      expect(await part().exists(), isFalse);
    });

    test('a first list that does not match keeps nothing', () async {
      served = [listB];

      await store().sync(settings(sha: shaOf(listA)));

      expect(await kept().exists(), isFalse);
      expect(await savedSha(), isNull);
    });

    test('a download that fails leaves the old file and sha, and the next '
        'settings load tries again', () async {
      served = [listA, listB];
      final entries = store();
      await entries.sync(settings(sha: shaOf(listA)));

      failWith = ApiException(statusCode: 0, message: 'No internet connection');
      await expectLater(entries.sync(settings(sha: shaOf(listB))), completes);
      expect(await kept().readAsBytes(), listA);
      expect(await savedSha(), shaOf(listA));

      failWith = null;
      await entries.sync(settings(sha: shaOf(listB)));
      expect(downloads, 3);
      expect(await kept().readAsBytes(), listB);
      expect(await savedSha(), shaOf(listB));
    });

    test('a 404 is a failed download like any other', () async {
      failWith = ApiException(statusCode: 404, message: 'Not found');

      await store().sync(settings(sha: shaOf(listA)));

      expect(await kept().exists(), isFalse);
      expect(await savedSha(), isNull);
    });

    group('after a failed try', () {
      test('one that failed once the backend answered waits an hour before '
          'the same list is tried again, on this launch or the next', () async {
        served = [listA];
        failWith = ApiException(statusCode: 404, message: 'Not found');
        final entries = store();
        await entries.sync(settings(sha: shaOf(listA)));
        expect(downloads, 1);
        expect(await failedNote(), startsWith('${shaOf(listA)} '));

        failWith = null;
        // The fetch that lands on the same launch.
        await entries.sync(settings(sha: shaOf(listA)));
        // A later launch, still within the hour.
        clock = clock.add(
          PsiphonEntries.retryAfter - const Duration(minutes: 1),
        );
        await store().sync(settings(sha: shaOf(listA)));
        expect(downloads, 1);
        expect(await kept().exists(), isFalse);

        clock = clock.add(const Duration(minutes: 1));
        await store().sync(settings(sha: shaOf(listA)));
        expect(downloads, 2);
        expect(await kept().readAsBytes(), listA);
        expect(await savedSha(), shaOf(listA));
        expect(await failedNote(), isNull);
      });

      test('a body cut off on its way waits too', () async {
        failWith = const DownloadCutOff('not whole after 180 s');
        final entries = store();
        await entries.sync(settings(sha: shaOf(listA)));
        failWith = null;
        served = [listA];

        await entries.sync(settings(sha: shaOf(listA)));

        expect(downloads, 1);
        expect(await failedNote(), startsWith('${shaOf(listA)} '));
      });

      test('a list that does not match its sha waits too', () async {
        served = [listB, listA];
        final entries = store();
        await entries.sync(settings(sha: shaOf(listA)));
        await entries.sync(settings(sha: shaOf(listA)));
        expect(downloads, 1);

        clock = clock.add(PsiphonEntries.retryAfter);
        await entries.sync(settings(sha: shaOf(listA)));

        expect(downloads, 2);
        expect(await kept().readAsBytes(), listA);
      });

      test('a list that could not be written waits too, and is downloaded '
          'again after', () async {
        served = [listA, listA];
        // A file where the folder should be, so the write fails.
        await File('${dir.path}/psiphon').writeAsString('not a folder');
        final entries = store();
        await entries.sync(settings(sha: shaOf(listA)));
        expect(downloads, 1);
        expect(await savedSha(), isNull);
        await entries.sync(settings(sha: shaOf(listA)));
        expect(downloads, 1);

        await File('${dir.path}/psiphon').delete();
        clock = clock.add(PsiphonEntries.retryAfter);
        await entries.sync(settings(sha: shaOf(listA)));

        expect(downloads, 2);
        expect(await kept().readAsBytes(), listA);
      });

      test('one that reached nothing is made again at the next settings '
          'load', () async {
        for (final nothing in <Object>[
          ApiException(statusCode: 0, message: 'No internet connection'),
          TimeoutException('no answer'),
          const SocketException('reset'),
        ]) {
          failWith = nothing;
          await store().sync(settings(sha: shaOf(listA)));
          expect(await failedNote(), isNull, reason: '$nothing');
        }
        failWith = null;
        served = [listA];

        await store().sync(settings(sha: shaOf(listA)));

        expect(downloads, 4);
        expect(await kept().readAsBytes(), listA);
      });

      test('a new sha is tried at once', () async {
        served = [listB];
        failWith = ApiException(statusCode: 500, message: 'Server error');
        final entries = store();
        await entries.sync(settings(sha: shaOf(listA)));
        failWith = null;

        await entries.sync(settings(sha: shaOf(listB)));

        expect(downloads, 2);
        expect(await kept().readAsBytes(), listB);
        expect(await failedNote(), isNull);
      });

      test('a clock set back does not hold the list back', () async {
        served = [listA];
        failWith = ApiException(statusCode: 404, message: 'Not found');
        final entries = store();
        await entries.sync(settings(sha: shaOf(listA)));
        failWith = null;
        clock = clock.subtract(const Duration(days: 1));

        await entries.sync(settings(sha: shaOf(listA)));

        expect(downloads, 2);
        expect(await kept().readAsBytes(), listA);
      });

      test('no sha clears the note', () async {
        failWith = ApiException(statusCode: 404, message: 'Not found');
        final entries = store();
        await entries.sync(settings(sha: shaOf(listA)));
        expect(await failedNote(), isNotNull);

        await entries.sync(settings());

        expect(await failedNote(), isNull);
      });
    });

    test('no sha deletes the file and the saved sha', () async {
      served = [listA];
      final entries = store();
      await entries.sync(settings(sha: shaOf(listA)));
      // A write cut off on an earlier run.
      await part().writeAsString('half');

      await entries.sync(settings());

      expect(downloads, 1);
      expect(await kept().exists(), isFalse);
      expect(await part().exists(), isFalse);
      expect(await savedSha(), isNull);
    });

    test('no backup network at all deletes them too', () async {
      served = [listA];
      final entries = store();
      await entries.sync(settings(sha: shaOf(listA)));

      await entries.sync(null);

      expect(await kept().exists(), isFalse);
      expect(await savedSha(), isNull);
    });

    test('a TV downloads it only when the network is for TVs', () async {
      tv = true;
      served = [listA];
      final entries = store();

      await entries.sync(settings(sha: shaOf(listA)));
      expect(downloads, 0);
      expect(await kept().exists(), isFalse);

      await entries.sync(settings(sha: shaOf(listA), tv: true));
      expect(downloads, 1);
      expect(await kept().readAsBytes(), listA);
    });

    test('nothing happens off Android', () async {
      android = false;
      served = [listA];
      await Directory('${dir.path}/psiphon').create();
      await kept().writeAsBytes(listA);

      await store().sync(settings(sha: shaOf(listB)));
      await store().sync(null);

      expect(downloads, 0);
      expect(await kept().readAsBytes(), listA);
    });

    test('settings that land while a download runs are worked through '
        'after it, with one download each', () async {
      final gate = Completer<void>();
      final entries = PsiphonEntries(
        download: () async {
          downloads++;
          if (downloads == 1) await gate.future;
          return served.removeAt(0);
        },
        filesDir: () async => dir,
        android: () => true,
        tv: () => false,
      );
      served = [listA];

      final first = entries.sync(settings(sha: shaOf(listA)));
      await pumpEventQueue();
      expect(downloads, 1);
      // The fetch lands while the download that the restore started runs.
      final second = entries.sync(settings(sha: shaOf(listA)));
      final third = entries.sync(settings(sha: shaOf(listA)));
      await pumpEventQueue();
      expect(downloads, 1);
      gate.complete();
      await Future.wait([first, second, third]);

      expect(downloads, 1);
      expect(await kept().readAsBytes(), listA);
      expect(await part().exists(), isFalse);
    });

    test('a sync that waited works with the newest settings', () async {
      final gate = Completer<void>();
      final entries = PsiphonEntries(
        download: () async {
          downloads++;
          if (downloads == 1) await gate.future;
          return served.removeAt(0);
        },
        filesDir: () async => dir,
        android: () => true,
        tv: () => false,
      );
      served = [listA, listB];

      final first = entries.sync(settings(sha: shaOf(listA)));
      await pumpEventQueue();
      expect(downloads, 1);
      final second = entries.sync(settings(sha: shaOf(listA)));
      final third = entries.sync(settings(sha: shaOf(listB)));
      gate.complete();
      await Future.wait([first, second, third]);

      // The first download, then one for the newest sha, not one per call.
      expect(downloads, 2);
      expect(served, isEmpty);
      expect(await kept().readAsBytes(), listB);
      expect(await savedSha(), shaOf(listB));
    });

    test('calls made at once are one download, of the newest', () async {
      served = [listB];
      final entries = store();

      await Future.wait([
        entries.sync(settings(sha: shaOf(listA))),
        entries.sync(settings(sha: shaOf(listB))),
      ]);

      expect(downloads, 1);
      expect(await kept().readAsBytes(), listB);
    });

    group('the path the tunnel is given', () {
      test('is the kept file when it is the list the settings name', () async {
        served = [listA];
        final entries = store();
        await entries.sync(settings(sha: shaOf(listA)));

        final path = await entries.fileFor(settings(sha: shaOf(listA)));

        expect(path, kept().absolute.path);
        expect(File(path!).isAbsolute, isTrue);
      });

      test('is none for another sha, no sha, a missing file or off '
          'Android', () async {
        served = [listA];
        final entries = store();
        await entries.sync(settings(sha: shaOf(listA)));

        expect(await entries.fileFor(settings(sha: shaOf(listB))), isNull);
        expect(await entries.fileFor(settings()), isNull);

        await kept().delete();
        expect(await entries.fileFor(settings(sha: shaOf(listA))), isNull);

        await kept().writeAsBytes(listA);
        android = false;
        expect(await entries.fileFor(settings(sha: shaOf(listA))), isNull);
      });

      test('is none while a new list is still on its way', () async {
        final gate = Completer<Uint8List>();
        final entries = PsiphonEntries(
          download: () => gate.future,
          filesDir: () async => dir,
          android: () => true,
          tv: () => false,
        );
        served = [];

        final running = entries.sync(settings(sha: shaOf(listA)));
        await pumpEventQueue();
        expect(await entries.fileFor(settings(sha: shaOf(listA))), isNull);

        gate.complete(listA);
        await running;
        expect(
          await entries.fileFor(settings(sha: shaOf(listA))),
          kept().absolute.path,
        );
      });

      test('is none when the platform cannot say where files go', () async {
        final entries = PsiphonEntries(
          download: () async => listA,
          filesDir: () async => throw const FileSystemException('no folder'),
          android: () => true,
          tv: () => false,
        );
        (await SharedPreferences.getInstance()).setString(
          PsiphonEntries.shaKey,
          shaOf(listA),
        );

        expect(await entries.fileFor(settings(sha: shaOf(listA))), isNull);
        await expectLater(entries.sync(settings(sha: shaOf(listA))), completes);
      });
    });
  });

  group('when the settings load', () {
    Map<String, dynamic> block(String? sha) => {
      'enabled': true,
      'network': network,
      'server_entries_sha': sha,
    };

    test('the list is told after the saved settings are back and after the '
        'fetch lands', () async {
      final sha = shaOf(listA);
      SharedPreferences.setMockInitialValues({
        AppConfigState.psiphonKey: jsonEncode(settings(sha: sha).toJson()),
      });
      final entries = _Entries();

      await AppConfigState(
        fetch: () async => configWith(block(shaOf(listB))),
        psiphonEntries: entries,
      ).load();

      expect(entries.asked.map((s) => s?.serverEntriesSha), [
        sha,
        shaOf(listB),
      ]);
    });

    test('a config with the block off tells it there is nothing', () async {
      final entries = _Entries();

      await AppConfigState(
        fetch: () async => configWith(null),
        psiphonEntries: entries,
      ).load();

      expect(entries.asked, [null, null]);
    });

    test('a fetch that fails tells it only the saved settings', () async {
      SharedPreferences.setMockInitialValues({
        AppConfigState.psiphonKey: jsonEncode(
          settings(sha: shaOf(listA)).toJson(),
        ),
      });
      final entries = _Entries();

      await AppConfigState(
        fetch: unreachable,
        retryGaps: const [],
        psiphonEntries: entries,
      ).load();

      expect(entries.asked.map((s) => s?.serverEntriesSha), [shaOf(listA)]);
    });

    test('the load does not wait for the download', () async {
      final hold = Completer<void>();
      final entries = _Entries(hold: hold);

      await AppConfigState(
        fetch: () async => configWith(block(shaOf(listA))),
        psiphonEntries: entries,
      ).load().timeout(const Duration(seconds: 5));

      expect(entries.asked, hasLength(2));
      expect(hold.isCompleted, isFalse);
      hold.complete();
    });
  });
}
