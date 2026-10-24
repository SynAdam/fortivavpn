import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/account_service.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/device_service.dart';
import 'package:fortiva_vpn/data/models/connection_data.dart';
import 'package:fortiva_vpn/services/network_history.dart';
import 'package:fortiva_vpn/services/network_keys.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// Wi-Fi networks told apart without the location permission, and what the
/// phone remembers of each network (backend issue #365, items 3, 4 and 9).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const on = {'network_keys': true, 'network_key_days': 7};

  late List<Map<dynamic, dynamic>> asked;
  Map<String, Object?>? answer;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ConnectionData.current = ConnectionData.off;
    NetworkKeys.resetForTest();
    asked = [];
    answer = {'local': '0123456789abcdef', 'shared': 'fedcba9876543210'};
    messenger.setMockMethodCallHandler(tunnel, (call) async {
      if (call.method != 'networkKey') return null;
      asked.add(call.arguments as Map<dynamic, dynamic>);
      return answer;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(tunnel, null);
    ConnectionData.current = ConnectionData.off;
    NetworkKeys.forget();
  });

  group('the network key', () {
    test('is not read while the backend has network keys off', () async {
      expect(await NetworkKeys.read(), isNull);
      expect(await NetworkKeys.wifiMemoryKey(), 'wifi');
      expect(asked, isEmpty);
    });

    test(
      'is read with this install\'s salt and the backend\'s period',
      () async {
        ConnectionData.current = ConnectionData.fromJson(on);
        final keys = await NetworkKeys.read();
        expect(keys!.local, '0123456789abcdef');
        expect(keys.shared, 'fedcba9876543210');
        expect(await NetworkKeys.wifiMemoryKey(), 'wifi:0123456789abcdef');
        final salt = asked.first['salt'] as String;
        expect(salt, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(asked.first['periodSeconds'], 7 * 86400);
        // The same salt every time, from storage once memory is cleared.
        NetworkKeys.forget();
        await NetworkKeys.read();
        expect(asked.last['salt'], salt);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(NetworkKeys.saltKey), salt);
      },
    );

    test(
      'every reading asks afresh, so a new network is seen at once',
      () async {
        ConnectionData.current = ConnectionData.fromJson(on);
        expect(await NetworkKeys.wifiMemoryKey(), 'wifi:0123456789abcdef');
        answer = {'local': 'aaaaaaaaaaaaaaaa', 'shared': 'bbbbbbbbbbbbbbbb'};
        expect(await NetworkKeys.wifiMemoryKey(), 'wifi:aaaaaaaaaaaaaaaa');
        expect(asked.length, 2);
        // The key of the network left behind is not sent for the new one.
        expect(await NetworkKeys.sharedFor('wifi:0123456789abcdef'), isNull);
      },
    );

    test(
      'off Wi-Fi, or anything the app cannot read, is plain "wifi"',
      () async {
        ConnectionData.current = ConnectionData.fromJson(on);
        answer = null;
        expect(await NetworkKeys.wifiMemoryKey(), 'wifi');
        NetworkKeys.forget();
        answer = {'local': 'not hex', 'shared': null};
        expect(await NetworkKeys.read(), isNull);
      },
    );

    test(
      'the key sent is only ever the one of the network it was read on',
      () async {
        ConnectionData.current = ConnectionData.fromJson(on);
        expect(
          (await NetworkKeys.sharedFor('wifi:0123456789abcdef'))!.shared,
          'fedcba9876543210',
        );
        expect(await NetworkKeys.sharedFor('wifi:aaaaaaaaaaaaaaaa'), isNull);
        expect(await NetworkKeys.sharedFor('mobile:IR-MCI'), isNull);
        expect(await NetworkKeys.sharedFor(null), isNull);
      },
    );

    test(
      'no key is read or made while a deletion has the keys closed',
      () async {
        ConnectionData.current = ConnectionData.fromJson(on);
        NetworkKeys.close();
        expect(await NetworkKeys.read(), isNull);
        expect(asked, isEmpty);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(NetworkKeys.saltKey), isNull);
        NetworkKeys.reopen();
        expect(await NetworkKeys.read(), isNotNull);
      },
    );

    test(
      'a reading under way when the salt is forgotten gives nothing',
      () async {
        ConnectionData.current = ConnectionData.fromJson(on);
        final held = Completer<void>();
        messenger.setMockMethodCallHandler(tunnel, (call) async {
          if (call.method != 'networkKey') return null;
          await held.future;
          return answer;
        });
        final reading = NetworkKeys.read();
        // Let the read reach the platform, then delete the account.
        await Future<void>.delayed(Duration.zero);
        NetworkKeys.forget();
        held.complete();
        expect(await reading, isNull);
        expect(await NetworkKeys.read(), isNotNull);
      },
    );

    test('no period from the backend sends no key', () async {
      ConnectionData.current = ConnectionData.fromJson({'network_keys': true});
      answer = {'local': '0123456789abcdef', 'shared': null};
      expect(await NetworkKeys.sharedFor('wifi:0123456789abcdef'), isNull);
      expect(asked.single['periodSeconds'], 0);
    });
  });

  group('what the phone remembers of a network', () {
    test('a network met for the first time has no age and no days', () async {
      var now = DateTime.utc(2026, 10, 16, 8);
      final h = NetworkHistory(now: () => now);
      final first = await h.factsThenNote('wifi:aa', [
        (door: 'h|xhttp-reality', ok: false),
        (door: 'h|tcp-reality', ok: true),
      ]);
      expect(first.map((f) => f.toRow()).toList(), [
        {'net_days': 0},
        {'net_days': 0},
      ]);

      now = now.add(const Duration(days: 2, hours: 1));
      final later = await h.factsThenNote('wifi:aa', [
        (door: 'h|xhttp-reality', ok: true),
        (door: 'h|ws-tls', ok: false),
      ]);
      expect(later[0].ageDays, 2);
      expect(later[0].daysSeen, 1);
      expect(later[0].doorFailSeconds, (2 * 24 + 1) * 3600);
      expect(later[0].doorOkSeconds, isNull);
      expect(later[0].networkOkSeconds, (2 * 24 + 1) * 3600);
      expect(later[1].doorOkSeconds, isNull);
      expect(later[1].doorFailSeconds, isNull);

      // Another network is another history.
      final other = await h.factsThenNote('mobile:IR-MCI', [
        (door: 'h|xhttp-reality', ok: true),
      ]);
      expect(other.single.daysSeen, 0);
    });

    test('keeps the networks met most lately', () async {
      var now = DateTime.utc(2026, 10, 1);
      final h = NetworkHistory(now: () => now);
      for (var i = 0; i < NetworkHistory.maxNetworks + 5; i++) {
        now = now.add(const Duration(minutes: 1));
        await h.factsThenNote('wifi:$i', [(door: 'd', ok: true)]);
      }
      final again = await h.factsThenNote('wifi:0', [(door: 'd', ok: true)]);
      expect(again.single.daysSeen, 0); // dropped, so met as new
      final kept = await h.factsThenNote('wifi:34', [(door: 'd', ok: true)]);
      expect(kept.single.daysSeen, 1);
    });
  });

  group('the door memory per Wi-Fi network', () {
    test(
      'a Wi-Fi network with no memory of its own gets the newest Wi-Fi door, '
      'as when every Wi-Fi shared one',
      () async {
        var now = DateTime.utc(2026, 10, 16, 8);
        final m = PathMemory(now: () => now);
        await m.remember('wifi', '13:xhttp-reality');
        now = now.add(const Duration(hours: 1));
        await m.remember('wifi:home', '14:tcp-reality');
        expect(await m.recall('wifi:cafe'), '14:tcp-reality');
        expect(await m.recall('wifi:home'), '14:tcp-reality');
        now = now.add(const Duration(minutes: 5));
        await m.remember('wifi:cafe', '17:grpc-reality');
        expect(await m.recall('wifi:cafe'), '17:grpc-reality');
        expect(await m.recall('wifi:home'), '14:tcp-reality');
        // Mobile networks never borrow a Wi-Fi door.
        expect(await m.recall('mobile:IR-MCI'), isNull);
      },
    );

    test('a borrowed door that failed here is not lent again', () async {
      var now = DateTime.utc(2026, 10, 16, 8);
      final m = PathMemory(now: () => now);
      await m.remember('wifi:home', '14:tcp-reality');
      now = now.add(const Duration(minutes: 1));
      await m.remember('wifi:work', '13:xhttp-reality');
      now = now.add(const Duration(minutes: 1));
      expect(await m.recall('wifi:cafe'), '13:xhttp-reality');
      await m.markFailed('wifi:cafe', '13:xhttp-reality');
      // The next newest Wi-Fi door instead.
      expect(await m.recall('wifi:cafe'), '14:tcp-reality');
      await m.markFailed('wifi:cafe', '14:tcp-reality');
      expect(await m.recall('wifi:cafe'), isNull);
      // Once it carried traffic again where it came from, it is lent again.
      now = now.add(const Duration(minutes: 1));
      await m.remember('wifi:work', '13:xhttp-reality');
      expect(await m.recall('wifi:cafe'), '13:xhttp-reality');
    });

    test('plain "wifi" borrows from the Wi-Fi networks with a key', () async {
      final m = PathMemory(now: () => DateTime.utc(2026, 10, 16, 8));
      await m.remember('wifi:home', '14:tcp-reality');
      expect(await m.recall('wifi'), '14:tcp-reality');
      expect(await m.recall('other'), isNull);
    });

    test('a stale memory is no memory, borrowed or not', () async {
      var now = DateTime.utc(2026, 10, 16, 8);
      final m = PathMemory(now: () => now);
      await m.remember('wifi:home', '14:tcp-reality');
      now = now.add(PathMemory.fresh + const Duration(minutes: 1));
      expect(await m.recall('wifi:cafe'), isNull);
    });

    test('keeps the networks used most lately', () async {
      var now = DateTime.utc(2026, 10, 1);
      final m = PathMemory(now: () => now);
      for (var i = 0; i < PathMemory.maxNetworks + 3; i++) {
        now = now.add(const Duration(minutes: 1));
        await m.remember('wifi:$i', 'door-$i');
      }
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(PathMemory.storageKey)!;
      expect(raw.contains('"wifi:0"'), isFalse);
      expect(raw.contains('"wifi:${PathMemory.maxNetworks + 2}"'), isTrue);
    });
  });

  group('the rows the backend gets', () {
    late List<Map<String, dynamic>> rows;

    VpnEventReporter reporter({String transport = 'wifi'}) => VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, p, _) async => rows.addAll(p),
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.11.0',
      platform: 'android',
      networkType: () async => transport,
      linkFacts: () async => const {},
      queues: const [],
    );

    setUp(() => rows = []);

    test('say what the phone saw of the network before, and its key', () async {
      ConnectionData.current = ConnectionData.fromJson(on);
      const results = [
        ProbeResult(
          door: 'xhttp-reality',
          ok: true,
          serverHost: '198.51.100.207',
        ),
      ];
      await reporter().recordProbes(results, network: 'wifi:0123456789abcdef');
      await reporter().recordProbes(results, network: 'wifi:0123456789abcdef');
      expect(rows[0]['net_days'], 0);
      expect(rows[0]['net_key'], 'fedcba9876543210');
      expect(rows[0].containsKey('door_ok_s'), isFalse);
      expect(rows[1]['net_days'], 1);
      expect(rows[1]['net_age_d'], 0);
      expect(rows[1]['door_ok_s'], inInclusiveRange(0, 5));
      expect(rows[1]['net_ok_s'], inInclusiveRange(0, 5));
    });

    test('keep the history of each door of a shared address apart', () async {
      ConnectionData.current = ConnectionData.fromJson(on);
      // Cloudflare doors of two servers: one address, one door name.
      await reporter().recordProbes(const [
        ProbeResult(
          door: 'ws-tls',
          ok: true,
          serverHost: '104.16.0.1',
          doorKey: '13:ws-tls',
        ),
      ], network: 'wifi:0123456789abcdef');
      await reporter().recordProbes(const [
        ProbeResult(
          door: 'ws-tls',
          ok: false,
          serverHost: '104.16.0.1',
          doorKey: '14:ws-tls',
        ),
      ], network: 'wifi:0123456789abcdef');
      expect(rows[1].containsKey('door_ok_s'), isFalse);
      expect(rows[1]['net_ok_s'], inInclusiveRange(0, 5));
    });

    test(
      'a key that lumps networks together gets no history and no facts',
      () async {
        ConnectionData.current = ConnectionData.fromJson(on);
        for (final network in ['wifi', 'mobile', 'other']) {
          await reporter().recordProbes(const [
            ProbeResult(door: 'tcp-reality', ok: true),
          ], network: network);
        }
        for (final r in rows) {
          expect(r.keys.where((k) => k.startsWith('net_')), isEmpty);
        }
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(NetworkHistory.storageKey), isNull);
      },
    );

    test('a Wi-Fi network\'s history starts again with each new key', () async {
      ConnectionData.current = ConnectionData.fromJson(on);
      const results = [
        ProbeResult(
          door: 'xhttp-reality',
          ok: true,
          doorKey: '13:xhttp-reality',
        ),
      ];
      await reporter().recordProbes(results, network: 'wifi:0123456789abcdef');
      await reporter().recordProbes(results, network: 'wifi:0123456789abcdef');
      expect(rows[1]['net_days'], 1);
      expect(rows[1]['door_ok_s'], inInclusiveRange(0, 5));
      // The period ends: the same network, a new key for the backend. Its
      // rows say nothing of what came before, as for a network never met.
      answer = {'local': '0123456789abcdef', 'shared': '00112233aabbccdd'};
      await reporter().recordProbes(results, network: 'wifi:0123456789abcdef');
      expect(rows[2]['net_key'], '00112233aabbccdd');
      expect(rows[2]['net_days'], 0);
      for (final k in ['net_age_d', 'door_ok_s', 'door_fail_s', 'net_ok_s']) {
        expect(rows[2].containsKey(k), isFalse, reason: k);
      }
      // The door memory is the phone's own and stays under the local key.
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(NetworkHistory.storageKey)!;
      expect(stored.contains('0123456789abcdef'), isFalse);
    });

    test('a Wi-Fi network with no key for the backend has no facts', () async {
      ConnectionData.current = ConnectionData.fromJson({'network_keys': true});
      answer = {'local': '0123456789abcdef', 'shared': null};
      await reporter().recordProbes(const [
        ProbeResult(door: 'tcp-reality', ok: true),
      ], network: 'wifi:0123456789abcdef');
      expect(rows.single.keys.where((k) => k.startsWith('net_')), isEmpty);
      expect(rows.single.containsKey('door_ok_s'), isFalse);
    });

    test(
      'one tap never carries two keys, even when the period ends in it',
      () async {
        ConnectionData.current = ConnectionData.fromJson(on);
        const results = [ProbeResult(door: 'tcp-reality', ok: false)];
        await reporter().recordProbes(
          results,
          attemptId: 'tap-1',
          network: 'wifi:0123456789abcdef',
        );
        // The period ends between the tap's two batches.
        answer = {'local': '0123456789abcdef', 'shared': '00112233aabbccdd'};
        await reporter().recordProbes(
          results,
          attemptId: 'tap-1',
          network: 'wifi:0123456789abcdef',
        );
        expect(rows[0]['net_key'], 'fedcba9876543210');
        expect(rows[1].keys.where((k) => k.startsWith('net_')), isEmpty);
        // The next tap sends the new key.
        await reporter().recordProbes(
          results,
          attemptId: 'tap-2',
          network: 'wifi:0123456789abcdef',
        );
        expect(rows[2]['net_key'], '00112233aabbccdd');
      },
    );

    test('a carrier\'s facts only on a row that says mobile', () async {
      ConnectionData.current = ConnectionData.fromJson(on);
      // The tap began on mobile data and the phone is on Wi-Fi now.
      await reporter(transport: 'wifi').recordProbes(const [
        ProbeResult(door: 'tcp-reality', ok: true),
      ], network: 'mobile:IR-MCI');
      expect(rows.single.keys.where((k) => k.startsWith('net_')), isEmpty);
    });

    test(
      'work under way during an account deletion puts nothing back',
      () async {
        ConnectionData.current = ConnectionData.fromJson(on);
        const results = [ProbeResult(door: 'tcp-reality', ok: true)];
        await reporter().recordProbes(
          results,
          network: 'wifi:0123456789abcdef',
        );
        await reporter(
          transport: 'mobile',
        ).recordProbes(results, network: 'mobile:IR-MCI');
        final prefs = await SharedPreferences.getInstance();
        final oldSalt = prefs.getString(NetworkKeys.saltKey);
        expect(oldSalt, isNotNull);
        // The platform makes the old keys only with the old salt.
        messenger.setMockMethodCallHandler(tunnel, (call) async {
          if (call.method != 'networkKey') return null;
          await Future<void>.delayed(const Duration(milliseconds: 1));
          final salt = (call.arguments as Map)['salt'];
          return salt == oldSalt
              ? {'local': '0123456789abcdef', 'shared': 'fedcba9876543210'}
              : {'local': 'aaaaaaaaaaaaaaaa', 'shared': 'bbbbbbbbbbbbbbbb'};
        });
        rows.clear();
        // A store that takes a millisecond per write, as the phone's does, so
        // work runs between the deletion's removals.
        SharedPreferencesStorePlatform.instance = _SlowStore.withData({
          for (final k in prefs.getKeys()) 'flutter.$k': prefs.get(k)!,
        });
        Future<void> batch(int i) => i.isEven
            ? reporter().recordProbes(results, network: 'wifi:0123456789abcdef')
            : reporter(
                transport: 'mobile',
              ).recordProbes(results, network: 'mobile:IR-MCI');
        // Two batches already running when the deletion begins, and more
        // while it runs.
        final work = [batch(0), batch(1)];
        var done = false;
        final deletion = AccountService.clearLocal().then((_) => done = true);
        for (var i = 2; !done && i < 400; i++) {
          work.add(batch(i));
          await Future<void>.delayed(Duration.zero);
        }
        await deletion;
        await Future.wait(work);

        expect(rows.where((r) => r['net_key'] == 'fedcba9876543210'), isEmpty);
        expect(prefs.getString(NetworkKeys.saltKey), isNot(oldSalt));
        final history = prefs.getString(NetworkHistory.storageKey) ?? '';
        expect(history, isNot(contains('fedcba9876543210')));
        expect(history, isNot(contains('mobile:IR-MCI')));
      },
    );

    test('a batch that read its key before a deletion sends it without its '
        'network', () async {
      ConnectionData.current = ConnectionData.fromJson(on);
      final link = Completer<void>();
      final reading = VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, p, _) async => rows.addAll(p),
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.11.0',
        platform: 'android',
        networkType: () async => 'wifi',
        linkFacts: () async {
          await link.future;
          return const {};
        },
        queues: const [],
      );
      final batch = reading.recordProbes(const [
        ProbeResult(door: 'tcp-reality', ok: true),
      ], network: 'wifi:0123456789abcdef');
      // The batch has read the key and waits on the line's facts when the
      // user deletes the account.
      while (asked.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await AccountService.clearLocal();
      link.complete();
      await batch;
      expect(rows.single.keys.where((k) => k.startsWith('net_')), isEmpty);
      expect(rows.single.containsKey('door_ok_s'), isFalse);
      expect(rows.single['door'], 'tcp-reality');
    });

    test('a send under way when the account is deleted retries without the '
        'network', () async {
      ConnectionData.current = ConnectionData.fromJson(on);
      var calls = 0;
      final r = VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, p, _) async {
          if (calls++ == 0) {
            // The user deletes the account while this upload is out; the
            // backend no longer knows the device.
            await AccountService.clearLocal();
            throw ApiException(statusCode: 404, message: 'not found');
          }
          rows.addAll(p);
        },
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.11.0',
        platform: 'android',
        networkType: () async => 'wifi',
        register: () async {},
        linkFacts: () async => const {},
        queues: const [],
      );
      await r.recordProbes(const [
        ProbeResult(door: 'tcp-reality', ok: true),
      ], network: 'wifi:0123456789abcdef');
      expect(calls, 2);
      expect(rows.single.keys.where((k) => k.startsWith('net_')), isEmpty);
      expect(rows.single['door'], 'tcp-reality');
    });

    test(
      'after a deletion nothing is kept under a Wi-Fi key read before it',
      () async {
        ConnectionData.current = ConnectionData.fromJson(on);
        final old = await NetworkKeys.wifiMemoryKey();
        expect(old, 'wifi:0123456789abcdef');
        await AccountService.clearLocal();
        answer = {'local': 'aaaaaaaaaaaaaaaa', 'shared': 'bbbbbbbbbbbbbbbb'};
        final m = PathMemory();
        await m.remember(old, '13:xhttp-reality');
        await m.markFailed(old, '13:ws-tls');
        final now = await NetworkKeys.wifiMemoryKey();
        await m.remember(now, '14:tcp-reality');
        await m.remember('mobile:IR-MCI', '17:grpc-reality');
        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getString(PathMemory.storageKey)!;
        expect(stored, isNot(contains('0123456789abcdef')));
        expect(stored, contains('aaaaaaaaaaaaaaaa'));
        expect(stored, contains('mobile:IR-MCI'));
      },
    );

    test('the network side is closed before the backend call, and opens '
        'again however the deletion ends', () async {
      ConnectionData.current = ConnectionData.fromJson(on);
      final account = AccountService.instance;
      addTearDown(() => account.backendDelete = null);
      var closedDuringCall = false;
      account.backendDelete = () async {
        closedDuringCall = NetworkKeys.closed;
        throw ApiException(statusCode: 503, message: 'busy');
      };
      await expectLater(account.deleteAccount(), throwsA(isA<ApiException>()));
      expect(closedDuringCall, isTrue);
      expect(NetworkKeys.closed, isFalse);
      expect(DeviceService.deleting, isFalse);
      expect(await NetworkKeys.read(), isNotNull);

      // A batch whose upload comes back 404 after the row is gone, and is
      // sent again once the device is registered, before the local
      // removal has even begun.
      final uploads = <List<Map<String, dynamic>>>[];
      final retry = Completer<void>();
      final r = VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, p, _) async {
          uploads.add(p);
          if (uploads.length == 1) {
            await retry.future;
            throw ApiException(statusCode: 404, message: 'not found');
          }
        },
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.11.0',
        platform: 'android',
        networkType: () async => 'wifi',
        register: () async {},
        linkFacts: () async => const {},
        queues: const [],
      );
      final batch = r.recordProbes(const [
        ProbeResult(door: 'tcp-reality', ok: true),
      ], network: 'wifi:0123456789abcdef');
      while (uploads.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      final google = Completer<void>();
      account.backendDelete = () async {
        retry.complete();
        await batch; // the retry goes out while the deletion is under way
        google.complete();
      };
      await account.deleteAccount();
      await google.future;
      expect(uploads.first.single['net_key'], 'fedcba9876543210');
      expect(
        uploads.last.single.keys.where((k) => k.startsWith('net_')),
        isEmpty,
      );
      expect(NetworkKeys.closed, isFalse);
    });

    test(
      'after a deletion no door memory writer keeps an old Wi-Fi key',
      () async {
        ConnectionData.current = ConnectionData.fromJson(on);
        final old = await NetworkKeys.wifiMemoryKey();
        await AccountService.clearLocal();
        final m = PathMemory();
        await m.remember(old, '13:xhttp-reality');
        await m.rememberShared(old, 'shared:1');
        await m.markFailed(old, '13:ws-tls');
        await m.markClosed(old, ['shared:2']);
        await m.markSwept(old, ['13:grpc-reality']);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(PathMemory.storageKey), isNull);
        // While a deletion runs nothing is kept, not even under a carrier.
        NetworkKeys.close();
        expect(NetworkKeys.mayKeep('mobile:IR-MCI'), isFalse);
        await m.remember('mobile:IR-MCI', '13:xhttp-reality');
        NetworkKeys.reopen();
        expect(prefs.getString(PathMemory.storageKey), isNull);
        expect(NetworkKeys.mayKeep('mobile:IR-MCI'), isTrue);
        expect(NetworkKeys.mayKeep(old), isFalse);
        expect(NetworkKeys.mayKeep('wifi'), isTrue);
      },
    );

    test(
      'no device is registered while the account is being deleted',
      () async {
        final account = AccountService.instance;
        addTearDown(() => account.backendDelete = null);
        // An upload that comes back 404 once the row is gone asks to register
        // again; the registration is refused, so the upload waits.
        var sends = 0;
        final r = VpnEventReporter(
          send: (_, _, _) async {},
          sendProbes: (_, _, _) async {
            sends++;
            throw ApiException(statusCode: 404, message: 'not found');
          },
          deviceId: () async => 'DEV-1',
          appVersion: () async => '1.11.0',
          platform: 'android',
          networkType: () async => 'wifi',
          register: () => DeviceService().registerDevice(),
          linkFacts: () async => const {},
          queues: const [],
        );
        Object? refused;
        account.backendDelete = () async {
          await r.recordProbes(const [ProbeResult(door: 'ws-tls', ok: true)]);
          try {
            await DeviceService().registerDevice();
          } catch (e) {
            refused = e;
          }
        };
        await account.deleteAccount();
        expect(sends, 1); // no second try for a device made again
        expect(
          refused,
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 0),
        );
        expect(DeviceService.deleting, isFalse);
      },
    );

    test('a tap that spans a deletion sends no key after it', () async {
      ConnectionData.current = ConnectionData.fromJson(on);
      const results = [ProbeResult(door: 'tcp-reality', ok: false)];
      await reporter().recordProbes(
        results,
        attemptId: 'tap-9',
        network: 'wifi:0123456789abcdef',
      );
      VpnEventReporter.forgetAttemptKeys();
      await reporter().recordProbes(
        results,
        attemptId: 'tap-9',
        network: 'wifi:0123456789abcdef',
      );
      expect(rows[0]['net_key'], 'fedcba9876543210');
      expect(rows[1].containsKey('net_key'), isFalse);
    });

    test('a mobile network has history but no key', () async {
      ConnectionData.current = ConnectionData.fromJson(on);
      await reporter(transport: 'mobile').recordProbes(const [
        ProbeResult(door: 'tcp-reality', ok: false),
      ], network: 'mobile:IR-MCI');
      expect(rows.single['net_days'], 0);
      expect(rows.single.containsKey('net_key'), isFalse);
    });

    test(
      'nothing of it while network keys are off, or with no network',
      () async {
        await reporter().recordProbes(const [
          ProbeResult(door: 'tcp-reality', ok: false),
        ], network: 'wifi:0123456789abcdef');
        ConnectionData.current = ConnectionData.fromJson(on);
        await reporter().recordProbes(const [
          ProbeResult(door: 'tcp-reality', ok: false),
        ]);
        for (final r in rows) {
          expect(r.keys.where((k) => k.startsWith('net_')), isEmpty);
          expect(r.containsKey('door_ok_s'), isFalse);
        }
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(NetworkHistory.storageKey), isNull);
      },
    );
  });
}

/// The in-memory store with a millisecond's wait on every write.
class _SlowStore extends InMemorySharedPreferencesStore {
  _SlowStore.withData(super.data) : super.withData();

  @override
  Future<bool> remove(String key) async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return super.remove(key);
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return super.setValue(valueType, key, value);
  }
}
