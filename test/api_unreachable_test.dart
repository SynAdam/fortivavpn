import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/api_routes.dart';
import 'package:fortiva_vpn/api/server_clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the API client does when a call cannot get through, besides
/// trying the next route: it says so as soon as the phone's own network
/// fails, so the fallback file can be read, and it remembers, for each
/// network, which relay carried a call and which failed.
const _pin = 'abababababababababababababababababababababababababababababababab';
const _blocked = ApiRelay(url: 'https://203.0.113.5:443', pin: _pin);
const _working = ApiRelay(url: 'https://203.0.113.6:443', pin: _pin);
const _fromFile = ApiRelay(url: 'https://203.0.113.7:443', pin: _pin);

http.Client _answers(Object Function(http.Request) answer) =>
    MockClient((request) async {
      final a = answer(request);
      if (a is http.Response) return a;
      throw a;
    });

http.Response _ok() => http.Response(jsonEncode({'ok': true}), 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int directFailed;
  late List<ApiRelay> worked;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiRelays.resetForTest();
    directFailed = 0;
    worked = [];
    ApiClient.onDirectFailed = () => directFailed++;
  });
  tearDown(() => ApiClient.onDirectFailed = null);

  ApiClient client({
    required Object Function(http.Request) direct,
    Object Function(ApiRelay, http.Request)? relay,
  }) => ApiClient.forTest(
    direct: _answers(direct),
    relay: (r) => _answers((q) => relay == null ? _ok() : relay(r, q)),
    relays: () async => const [_blocked, _working],
    relayWorked: (r) async => worked.add(r),
  );

  test('a call the phone own network drops says so, whatever the other '
      'routes do', () async {
    final c = client(
      direct: (_) => const SocketException('reset'),
      relay: (r, _) => r == _working ? _ok() : TimeoutException('no answer'),
    );

    await c.get('/api/v1/app/config');

    expect(directFailed, 1);
  });

  test('an answer of any status on the phone own network is the backend '
      'reached', () async {
    final c = client(direct: (_) => http.Response('{}', 500));

    await expectLater(
      c.get('/api/v1/app/config'),
      throwsA(isA<ApiException>()),
    );

    expect(directFailed, 0);
  });

  test('a call kept on the phone own network says so too', () async {
    final c = client(direct: (_) => const SocketException('reset'));

    await expectLater(
      c.get('/api/v1/info/me', fallback: false),
      throwsA(isA<ApiException>()),
    );

    expect(directFailed, 1);
  });

  test('the relay that carried a call is remembered, and a direct answer '
      'remembers none', () async {
    final relayed = client(
      direct: (_) => const SocketException('reset'),
      relay: (r, _) => r == _blocked ? TimeoutException('no answer') : _ok(),
    );
    await relayed.get('/api/v1/app/config');
    expect(worked, [_working]);

    worked.clear();
    await client(direct: (_) => _ok()).get('/api/v1/app/config');
    expect(worked, isEmpty);
  });

  test('a relay that fails on the phone own network is noted, and one that '
      'fails through the tunnel is not', () async {
    final failed = <ApiRelay>[];
    final c = ApiClient.forTest(
      direct: _answers((_) => const SocketException('reset')),
      tunnel: (_) => _answers((_) => TimeoutException('no answer')),
      tunnelRelay: (_, _) => _answers((_) => TimeoutException('no answer')),
      relay: (r) => _answers(
        (_) => r == _blocked ? TimeoutException('no answer') : _ok(),
      ),
      relays: () async => const [_blocked, _working],
      tunnelPort: () async => 10808,
      relayWorked: (r) async => worked.add(r),
      relayFailed: (r) async => failed.add(r),
    );

    await c.get('/api/v1/app/config');

    expect(failed, [_blocked]);
    expect(worked, [_working]);
  });

  // Putting the relays in order reads the network the phone is on, which
  // on mobile data is a platform call. A call that does not need a relay
  // must not wait for it.
  test('a call the phone own network carries reads neither the relays nor '
      'the tunnel port', () async {
    var reads = 0;
    final c = ApiClient.forTest(
      direct: _answers((_) => _ok()),
      relays: () async {
        reads++;
        return const [_blocked, _working];
      },
      tunnelPort: () async {
        reads++;
        return 10808;
      },
    );

    await c.get('/api/v1/app/config');

    expect(reads, 0);
  });

  test('what a call learns about the relays on the phone own network is '
      'kept, and the network is read only once a relay is needed', () async {
    await ApiRelays.adopt(const [_blocked, _working, _fromFile]);
    var reads = 0;
    ApiRelays.networkKey = () async {
      reads++;
      return 'mobile:MCI';
    };
    var directUp = true;
    final asked = <String>[];
    final c = ApiClient.forTest(
      direct: _answers((_) {
        asked.add('direct');
        return directUp ? _ok() : const SocketException('reset');
      }),
      relay: (r) => _answers((_) {
        asked.add(r.url);
        return r == _blocked ? TimeoutException('no answer') : _ok();
      }),
      relays: ApiRelays.current,
      relayWorked: ApiRelays.noteWorked,
      relayFailed: ApiRelays.noteFailed,
    );

    await c.get('/api/v1/app/config');
    expect(reads, 0);

    directUp = false;
    await c.get('/api/v1/app/config');
    await pumpEventQueue();

    expect(asked, ['direct', 'direct', _blocked.url, _working.url]);
    // The relay that carried the call first, the one that failed last.
    expect(await ApiRelays.current(), const [_working, _fromFile, _blocked]);
    expect(reads, 1);
  });

  group('the order relays are tried in', () {
    Future<void> saved(List<ApiRelay> relays) async {
      await ApiRelays.adopt(relays);
      ApiRelays.resetForTest();
    }

    test('a fallback file built after the backend\'s list was saved decides '
        'the relays, its order included', () async {
      await saved(const [_blocked, _working]);
      ApiRelays.addFound(const [
        _fromFile,
        _working,
      ], issuedAt: DateTime.now().toUtc().add(const Duration(minutes: 5)));

      expect(await ApiRelays.current(), const [_fromFile, _working]);
    });

    test('a file built before the backend\'s list was saved changes nothing, '
        'and an empty list from the backend still turns relays off', () async {
      final before = DateTime.now().toUtc().subtract(const Duration(days: 3));
      await saved(const []);
      ApiRelays.addFound(const [_fromFile, _working], issuedAt: before);

      expect(await ApiRelays.current(), isEmpty);
    });

    test('a list saved with no time, by a build up to 1.7.0, gives way to any '
        'file', () async {
      SharedPreferences.setMockInitialValues({
        ApiRelays.savedRelaysKey: jsonEncode([_blocked.toJson()]),
      });
      ApiRelays.resetForTest();
      ApiRelays.addFound(const [_working], issuedAt: DateTime.utc(2026, 1, 1));

      expect(await ApiRelays.current(), const [_working]);
    });

    test('the relay that last carried a call goes first, in this run and '
        'the next', () async {
      await saved(const [_blocked, _working]);
      await ApiRelays.noteWorked(_working);
      expect(await ApiRelays.current(), const [_working, _blocked]);

      // The next run starts with nothing in memory.
      ApiRelays.resetForTest();
      expect(await ApiRelays.current(), const [_working, _blocked]);
    });
  });

  group('the relays on each network', () {
    const a = ApiRelay(url: 'https://203.0.113.11:443', pin: _pin);
    const b = ApiRelay(url: 'https://203.0.113.12:443', pin: _pin);
    const c = ApiRelay(url: 'https://[2001:db8::13]:443', pin: _pin);
    String savedList() => jsonEncode([
      for (final r in const [a, b, c]) r.toJson(),
    ]);

    late String network;
    late DateTime clock;
    late int reads;

    /// A new run: nothing read yet, and the network key main.dart sets.
    void newRun() {
      ApiRelays.resetForTest();
      ApiRelays.networkKey = () async {
        reads++;
        return network;
      };
      ApiRelays.clock = () => clock;
    }

    /// The phone is on [key] from now on. An answer of the network key is
    /// used for [ApiRelays.networkFresh], so the clock moves past that.
    void moveTo(String key) {
      network = key;
      clock = clock.add(ApiRelays.networkFresh);
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({
        ApiRelays.savedRelaysKey: savedList(),
      });
      network = 'wifi';
      clock = DateTime.utc(2026, 10, 13, 9);
      reads = 0;
      newRun();
    });
    tearDown(ApiRelays.resetForTest);

    test(
      'after an account deletion no network from before it comes back',
      () async {
        network = 'wifi:0123456789abcdef';
        await ApiRelays.noteFailed(a);
        // The deletion removes the stored memory and forgets what this run
        // holds; the new salt gives the same Wi-Fi a new key.
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(ApiRelays.memoryKey);
        ApiRelays.forgetNetworks();
        moveTo('wifi:fedcba9876543210');
        await ApiRelays.noteWorked(b);

        final stored = prefs.getString(ApiRelays.memoryKey)!;
        expect(stored, contains('fedcba9876543210'));
        expect(stored, isNot(contains('0123456789abcdef')));
      },
    );

    test('while a deletion has the memory closed, nothing is kept and the '
        'relays still work', () async {
      network = 'wifi:0123456789abcdef';
      await ApiRelays.noteWorked(c);
      ApiRelays.closeNetworks();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ApiRelays.memoryKey);
      await ApiRelays.noteFailed(a);
      await ApiRelays.noteWorked(b);
      expect(prefs.getString(ApiRelays.memoryKey), isNull);
      // The backend's order, the relay that last carried a call first.
      expect(await ApiRelays.current(), const [b, a, c]);
      ApiRelays.reopenNetworks();
      moveTo('wifi:fedcba9876543210');
      await ApiRelays.noteWorked(b);
      final stored = prefs.getString(ApiRelays.memoryKey)!;
      expect(stored, isNot(contains('0123456789abcdef')));
    });

    test(
      'a note that worked, begun before a deletion, saves nothing',
      () async {
        network = 'wifi:0123456789abcdef';
        final answer = Completer<String>();
        ApiRelays.networkKey = () => answer.future;
        final note = ApiRelays.noteWorked(b);
        ApiRelays.forgetNetworks();
        answer.complete(network);
        await note;
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(ApiRelays.memoryKey), isNull);
      },
    );

    test('a note begun before a deletion saves nothing', () async {
      network = 'wifi:0123456789abcdef';
      final answer = Completer<String>();
      ApiRelays.networkKey = () => answer.future;
      final note = ApiRelays.noteFailed(a);
      ApiRelays.forgetNetworks();
      answer.complete(network);
      await note;
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ApiRelays.memoryKey), isNull);
    });

    test('the relay that last carried a call on this network goes first, not '
        'the one that last carried a call on another', () async {
      await ApiRelays.noteWorked(c);
      moveTo('mobile:MCI');
      await ApiRelays.noteWorked(b);
      moveTo('wifi');

      expect(await ApiRelays.current(), const [c, a, b]);
    });

    test('a relay that failed here lately goes after the others, the one that '
        'failed longest ago first', () async {
      await ApiRelays.noteFailed(b);
      clock = clock.add(const Duration(minutes: 1));
      await ApiRelays.noteFailed(a);

      expect(await ApiRelays.current(), const [c, b, a]);
    });

    test('the relay that last carried a call here does not go first for '
        'thirty minutes after it failed here', () async {
      await ApiRelays.noteWorked(b);
      // The relay that last carried a call anywhere is another one.
      moveTo('mobile:MCI');
      await ApiRelays.noteWorked(c);
      moveTo('wifi');
      await ApiRelays.noteFailed(b);
      expect(await ApiRelays.current(), const [a, c, b]);

      clock = clock.add(ApiRelays.failedFor);
      expect(await ApiRelays.current(), const [b, a, c]);
    });

    test('a relay that carries a call here is no longer held back by its '
        'failure here', () async {
      await ApiRelays.noteFailed(a);
      await ApiRelays.noteWorked(a);

      expect(await ApiRelays.current(), const [a, b, c]);
    });

    test('a failure thirty minutes old no longer holds a relay back', () async {
      await ApiRelays.noteFailed(a);

      clock = clock.add(const Duration(minutes: 29));
      expect(await ApiRelays.current(), const [b, c, a]);

      clock = clock.add(const Duration(minutes: 1));
      expect(await ApiRelays.current(), const [a, b, c]);
    });

    test(
      'two networks are remembered apart, in this run and the next',
      () async {
        await ApiRelays.noteWorked(b);
        moveTo('mobile:MCI');
        await ApiRelays.noteFailed(a);
        await ApiRelays.noteWorked(c);

        expect(await ApiRelays.current(), const [c, b, a]);
        moveTo('wifi');
        expect(await ApiRelays.current(), const [b, a, c]);

        // The next run starts with nothing in memory.
        newRun();
        expect(await ApiRelays.current(), const [b, a, c]);
        moveTo('mobile:MCI');
        expect(await ApiRelays.current(), const [c, b, a]);
      },
    );

    // A phone updated from 1.8.0 knows one relay for every network.
    test('where no relay carried a call yet, the one that last carried a call '
        'on any network goes first, unless it failed here lately', () async {
      SharedPreferences.setMockInitialValues({
        ApiRelays.savedRelaysKey: savedList(),
        ApiRelays.workedKey: c.url,
      });
      newRun();
      expect(await ApiRelays.current(), const [c, a, b]);

      await ApiRelays.noteFailed(a);
      expect(await ApiRelays.current(), const [c, b, a]);

      clock = clock.add(const Duration(minutes: 1));
      await ApiRelays.noteFailed(c);
      expect(await ApiRelays.current(), const [b, a, c]);
    });

    test(
      'with no network to go by, nothing is noted for one and the relay that '
      'last carried a call goes first, as before',
      () async {
        await ApiRelays.noteWorked(b);
        for (final read in <Future<String> Function()?>[
          null,
          () async => 'none',
          () async => 'unknown',
          () async => throw Exception('no platform'),
        ]) {
          newRun();
          ApiRelays.networkKey = read;
          await ApiRelays.noteFailed(b);
          expect(await ApiRelays.current(), const [b, a, c]);
        }

        final prefs = await SharedPreferences.getInstance();
        final kept = jsonDecode(prefs.getString(ApiRelays.memoryKey)!) as Map;
        expect(kept.keys, ['wifi']);
      },
    );

    test('calls close together read the network once', () async {
      await Future.wait([ApiRelays.current(), ApiRelays.current()]);
      await ApiRelays.noteFailed(a);
      expect(reads, 1);

      clock = clock.add(ApiRelays.networkFresh);
      await ApiRelays.current();
      expect(reads, 2);
    });

    test('a network read that does not answer holds a call up for a second at '
        'most, and its answer is kept when it comes', () {
      fakeAsync((async) {
        // Set up inside the fake zone, so the stored values are read there.
        SharedPreferences.setMockInitialValues({
          ApiRelays.savedRelaysKey: savedList(),
          ApiRelays.memoryKey: jsonEncode({
            'wifi': {'worked': c.url},
          }),
        });
        newRun();
        final answer = Completer<String>();
        ApiRelays.networkKey = () {
          reads++;
          return answer.future;
        };

        List<ApiRelay>? order;
        ApiRelays.current().then((v) => order = v);
        async.elapse(ApiRelays.networkWait - const Duration(milliseconds: 1));
        expect(order, isNull);
        async.elapse(const Duration(milliseconds: 1));
        expect(order, const [a, b, c]);

        answer.complete('wifi');
        async.flushMicrotasks();
        ApiRelays.current().then((v) => order = v);
        async.flushMicrotasks();
        expect(order, const [c, a, b]);
        expect(reads, 1);
      });
    });

    test('at most twenty networks are kept, and the one written to longest ago '
        'goes first', () async {
      for (var i = 0; i < ApiRelays.maxNetworks; i++) {
        moveTo('mobile:carrier$i');
        await ApiRelays.noteFailed(a);
      }
      // Written to again, so now the newest.
      moveTo('mobile:carrier0');
      await ApiRelays.noteFailed(b);
      moveTo('mobile:carrier${ApiRelays.maxNetworks}');
      await ApiRelays.noteFailed(a);

      final prefs = await SharedPreferences.getInstance();
      final kept =
          (jsonDecode(prefs.getString(ApiRelays.memoryKey)!) as Map).keys;
      expect(kept, hasLength(ApiRelays.maxNetworks));
      expect(kept, contains('mobile:carrier0'));
      expect(kept, isNot(contains('mobile:carrier1')));
    });
  });

  test('a relay that carried a call through the tunnel is not remembered '
      'for the phone own network', () async {
    final c = ApiClient.forTest(
      direct: _answers((_) => const SocketException('reset')),
      tunnel: (_) => _answers((_) => TimeoutException('no answer')),
      tunnelRelay: (_, _) => _answers((_) => _ok()),
      relay: (_) => _answers((_) => TimeoutException('no answer')),
      relays: () async => const [_blocked, _working],
      tunnelPort: () async => 10808,
      relayWorked: (r) async => worked.add(r),
    );

    await c.get('/api/v1/app/config');

    expect(worked, isEmpty);
  });

  test('once the tunnel\'s exit failed and a relay inside it carried the '
      'call, the next calls go to that relay first, and after ten minutes '
      'the tunnel gets its turn again', () async {
    var clock = DateTime.utc(2026, 10, 12, 1);
    final asked = <String>[];
    final c = ApiClient.forTest(
      direct: _answers((_) {
        asked.add('direct');
        return const SocketException('reset');
      }),
      tunnel: (_) => _answers((_) {
        asked.add('tunnel');
        return TimeoutException('no answer');
      }),
      tunnelRelay: (_, _) => _answers((_) {
        asked.add('tunnel relay');
        return _ok();
      }),
      relays: () async => const [_working],
      tunnelPort: () async => 10808,
      now: () => clock,
    );

    await c.get('/api/v1/app/config');
    expect(asked, ['direct', 'tunnel', 'tunnel relay']);

    asked.clear();
    await c.get('/api/v1/app/config');
    expect(asked, ['tunnel relay']);

    asked.clear();
    clock = clock.add(const Duration(minutes: 11));
    await c.get('/api/v1/app/config');
    // The phone's own network also gets its turn again by then.
    expect(asked.take(2), ['direct', 'tunnel']);
  });

  group('the build\'s copy and the backend\'s clock', () {
    test('a list saved with no time stays ahead of the copy built into the '
        'app, but not of a file read from a host', () async {
      SharedPreferences.setMockInitialValues({
        ApiRelays.savedRelaysKey: jsonEncode(<Object>[]),
      });
      ApiRelays.resetForTest();
      ApiRelays.addFound(
        const [_working],
        issuedAt: DateTime.utc(2026, 10, 11),
        inBuild: true,
      );
      expect(await ApiRelays.current(), isEmpty);

      ApiRelays.addFound(const [
        _working,
      ], issuedAt: DateTime.utc(2026, 10, 11));
      expect(await ApiRelays.current(), const [_working]);
    });

    test('the backend\'s list is stamped with the backend\'s time, so a phone '
        'clock that is ahead does not hide a newer file', () async {
      // The phone is three hours ahead of the backend.
      ServerClock.heard(
        HttpDate.format(
          DateTime.now().toUtc().subtract(const Duration(hours: 3)),
        ),
        DateTime.now(),
      );
      addTearDown(ServerClock.resetForTest);
      await ApiRelays.adopt(const [_blocked]);
      ApiRelays.addFound(const [
        _working,
      ], issuedAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)));

      expect(await ApiRelays.current(), const [_working]);
    });
  });

  test('the backend\'s clock does not move when the phone clock is changed '
      'after it was heard', () {
    addTearDown(ServerClock.resetForTest);
    final server = DateTime.utc(2026, 10, 12, 1);
    ServerClock.heard(HttpDate.format(server), server);

    final later = ServerClock.now(server.add(const Duration(days: 1)));

    expect(later.difference(server).inMinutes, lessThan(1));
  });

  test('a deadline is judged on the later of the backend\'s clock and the '
      'phone\'s, so a night asleep does not hold it back', () {
    addTearDown(ServerClock.resetForTest);
    final heard = DateTime.utc(2026, 10, 12, 1);
    ServerClock.heard(HttpDate.format(heard), heard);

    // Eight hours later by the phone's clock; the stopwatch barely moved,
    // as it does not run while the phone sleeps.
    final morning = heard.add(const Duration(hours: 8));
    expect(ServerClock.now(morning).difference(heard).inMinutes, lessThan(1));
    expect(ServerClock.notBefore(morning), morning);
  });
}
