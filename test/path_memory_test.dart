import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The memory is what makes the checklist rare: the door that worked
/// last time on this network is dialled with no checks at all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  PathMemory memory() => PathMemory(now: () => now);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime.utc(2026, 9, 6, 12);
  });

  test('remembers the door that worked, per network', () async {
    final m = memory();
    await m.remember('mobile:Irancell', 'hel.example|xhttp-reality');
    await m.remember('wifi', 'hel.example|tcp-reality');
    expect(await m.recall('mobile:Irancell'), 'hel.example|xhttp-reality');
    expect(await m.recall('wifi'), 'hel.example|tcp-reality');
    expect(await m.recall('mobile:MCI'), isNull);
  });

  test('a memory older than a day is not trusted without a check', () async {
    final m = memory();
    await m.remember('wifi', 'hel.example|tcp-reality');
    now = now.add(const Duration(hours: 23));
    expect(await m.recall('wifi'), isNotNull);
    now = now.add(const Duration(hours: 2));
    expect(await m.recall('wifi'), isNull);
  });

  test('a failure forgets the remembered door', () async {
    final m = memory();
    await m.remember('wifi', 'hel.example|tcp-reality');
    await m.markFailed('wifi', 'hel.example|tcp-reality');
    expect(await m.recall('wifi'), isNull);
  });

  // A remembered door the user stopped while the app was still dialling
  // it (ConnectFlow.stop). About a third of those dials were of doors that
  // worked, so the stop is not a failure.
  group('a door forgotten after a stop', () {
    const key = 'hel.example|tcp-reality';

    test('is no longer the door to try first', () async {
      final m = memory();
      await m.remember('mobile:Irancell', key);
      await m.forget('mobile:Irancell', key);
      expect(await m.recall('mobile:Irancell'), isNull);
    });

    test('counts no failure and stays a door that carried traffic', () async {
      final m = memory();
      await m.remember('mobile:Irancell', key);
      await m.forget('mobile:Irancell', key);
      expect(await m.failedToday('mobile:Irancell'), isEmpty);
      for (var i = 0; i < 3; i++) {
        await m.markFailed('mobile:Irancell', key);
      }
      // Still the one door known to work here, so it is never skipped.
      expect(
        await m.skippable('mobile:Irancell', holding: const [key]),
        isEmpty,
      );
    });

    test('leaves another remembered door alone', () async {
      final m = memory();
      await m.remember('mobile:Irancell', key);
      await m.forget('mobile:Irancell', 'fsn.example|ws-tls');
      expect(await m.recall('mobile:Irancell'), key);
    });

    test('is not lent back by another Wi-Fi network', () async {
      final m = memory();
      await m.remember('wifi:home', key);
      // A network with no door of its own borrows the newest one.
      expect(await m.recall('wifi:cafe'), key);
      await m.forget('wifi:cafe', key);
      expect(await m.recall('wifi:cafe'), isNull);
      // The network it came from keeps it.
      expect(await m.recall('wifi:home'), key);
      // Remembered there again later, it is lent again.
      now = now.add(const Duration(minutes: 1));
      await m.remember('wifi:home', key);
      expect(await m.recall('wifi:cafe'), key);
    });

    test('is the door to try first again once it carries traffic', () async {
      final m = memory();
      await m.remember('wifi:cafe', key);
      await m.forget('wifi:cafe', key);
      await m.remember('wifi:cafe', key);
      expect(await m.recall('wifi:cafe'), key);
    });
  });

  test('a failure of another door leaves the remembered one alone', () async {
    final m = memory();
    await m.remember('wifi', 'hel.example|tcp-reality');
    await m.markFailed('wifi', 'fsn.example|ws-tls');
    expect(await m.recall('wifi'), 'hel.example|tcp-reality');
  });

  test('three failures in a day skip the door until tomorrow', () async {
    final m = memory();
    const key = 'hel.example|tcp-reality';
    await m.markFailed('wifi', key);
    await m.markFailed('wifi', key);
    expect(await m.skippable('wifi'), isEmpty);
    await m.markFailed('wifi', key);
    expect(await m.skippable('wifi'), {key});
    // Another network keeps its own count.
    expect(await m.skippable('mobile:Irancell'), isEmpty);
    now = now.add(const Duration(days: 1));
    expect(await m.skippable('wifi'), isEmpty);
  });

  test('a door that works again is no longer skipped', () async {
    final m = memory();
    const key = 'hel.example|tcp-reality';
    for (var i = 0; i < 3; i++) {
      await m.markFailed('wifi', key);
    }
    await m.remember('wifi', key);
    expect(await m.skippable('wifi'), isEmpty);
    expect(await m.recall('wifi'), key);
  });

  test('the shared link that worked is kept apart from the own door', () async {
    final m = memory();
    await m.remember('wifi', 'hel.example|tcp-reality');
    await m.rememberShared('wifi', 'ee.example:443|');
    expect(await m.recall('wifi'), 'hel.example|tcp-reality');
    expect(await m.recallShared('wifi'), 'ee.example:443|');
    expect(await m.recallShared('mobile:Irancell'), isNull);
    now = now.add(const Duration(hours: 25));
    expect(await m.recallShared('wifi'), isNull);
  });

  test('a failure forgets the remembered shared link', () async {
    final m = memory();
    await m.rememberShared('wifi', 'ee.example:443|');
    await m.markFailed('wifi', 'fr.example:443|');
    expect(await m.recallShared('wifi'), 'ee.example:443|');
    await m.markFailed('wifi', 'ee.example:443|');
    expect(await m.recallShared('wifi'), isNull);
  });

  test('a closed shared link goes back, and is never skipped', () async {
    final m = memory();
    await m.rememberShared('wifi', 'ee.example:443|');
    await m.markClosed('wifi', ['fr.example:443|', 'ee.example:443|']);
    expect(await m.failedToday('wifi'), {'fr.example:443|', 'ee.example:443|'});
    expect(await m.recallShared('wifi'), isNull);
    for (var i = 0; i < 5; i++) {
      await m.markClosed('wifi', ['fr.example:443|']);
    }
    expect(await m.skippable('wifi'), isEmpty);
    expect(await m.failedToday('mobile:Irancell'), isEmpty);
  });

  test('closed links and failures count for today only', () async {
    final m = memory();
    await m.markClosed('wifi', ['fr.example:443|']);
    await m.markFailed('wifi', 'es.example:443|');
    expect(await m.failedToday('wifi'), {'fr.example:443|', 'es.example:443|'});

    now = now.add(const Duration(days: 1));
    expect(await m.failedToday('wifi'), isEmpty);
    await m.markClosed('wifi', ['ee.example:443|']);
    expect(await m.failedToday('wifi'), {'ee.example:443|'});
  });

  // A carrier once closed every link for a while, and the links that worked
  // the rest of the day waited behind the others. A closed period sends them
  // back to their place once it ends.
  test('with a closed period, a closed link goes back to its place after '
      'it', () async {
    final m = memory();
    const period = Duration(minutes: 30);
    await m.markClosed('wifi', ['fr.example:443|']);
    now = now.add(const Duration(minutes: 20));
    await m.markClosed('wifi', ['ee.example:443|']);
    await m.markFailed('wifi', 'es.example:443|');
    expect(await m.failedToday('wifi', within: period), {
      'fr.example:443|',
      'ee.example:443|',
      'es.example:443|',
    });

    now = now.add(const Duration(minutes: 15));
    expect(await m.failedToday('wifi', within: period), {
      'ee.example:443|',
      'es.example:443|',
    });
    // Without one, the day's list as before.
    expect(await m.failedToday('wifi'), {
      'fr.example:443|',
      'ee.example:443|',
      'es.example:443|',
    });

    // Found closed again: its time is the new check's.
    await m.markClosed('wifi', ['fr.example:443|']);
    now = now.add(const Duration(minutes: 31));
    expect(await m.failedToday('wifi', within: period), isEmpty);
  });

  test('a closed list an older build wrote counts for the day', () async {
    SharedPreferences.setMockInitialValues({
      PathMemory.storageKey: jsonEncode({
        'wifi': {
          'closed': {
            'day': '2026-09-06',
            'keys': ['fr.example:443|'],
          },
        },
      }),
    });
    final m = memory();
    now = now.add(const Duration(hours: 5));
    expect(await m.failedToday('wifi', within: const Duration(minutes: 30)), {
      'fr.example:443|',
    });
    await m.markClosed('wifi', ['ee.example:443|']);
    now = now.add(const Duration(hours: 1));
    expect(await m.failedToday('wifi', within: const Duration(minutes: 30)), {
      'fr.example:443|',
    });
  });

  group('a skip set by the backend', () {
    const key = '198.51.100.200:8443|grpc-reality-b';
    const rule = SkipSettings(failures: 3, skipFor: Duration(minutes: 30));

    test(
      'ends a set time after the latest failure, not at UTC midnight',
      () async {
        // 08:40 Tehran on 2026-10-09, the third failure of a bad hour.
        now = DateTime.utc(2026, 10, 9, 5, 10);
        final m = memory();
        for (var i = 0; i < 3; i++) {
          await m.markFailed('wifi', key);
        }
        expect(await m.skippable('wifi', rule: rule), {key});

        now = now.add(const Duration(minutes: 29));
        expect(await m.skippable('wifi', rule: rule), {key});

        // 09:10 Tehran: tried again. With no rule it would wait for 03:30.
        now = now.add(const Duration(minutes: 1));
        expect(await m.skippable('wifi', rule: rule), isEmpty);
        expect(await m.skippable('wifi'), {key});
      },
    );

    test('a failure after the skip ends hides the door again', () async {
      final m = memory();
      for (var i = 0; i < 3; i++) {
        await m.markFailed('wifi', key);
      }
      now = now.add(const Duration(minutes: 31));
      expect(await m.skippable('wifi', rule: rule), isEmpty);
      await m.markFailed('wifi', key);
      expect(await m.skippable('wifi', rule: rule), {key});
    });

    test('counts its own number of failures', () async {
      final m = memory();
      await m.markFailed('wifi', key);
      const strict = SkipSettings(failures: 1, skipFor: Duration(minutes: 5));
      expect(await m.skippable('wifi', rule: strict), {key});
      expect(await m.skippable('wifi', rule: rule), isEmpty);
    });

    test(
      'a failure an older build wrote, with no time, lasts the day',
      () async {
        const today = '2026-09-06';
        SharedPreferences.setMockInitialValues({
          PathMemory.storageKey:
              '{"wifi":{"fails":{"$key":{"day":"$today","n":3}}}}',
        });
        final m = memory();
        now = now.add(const Duration(hours: 5));
        expect(await m.skippable('wifi', rule: rule), {key});
      },
    );
  });

  group('the only door that ever carried traffic', () {
    // One phone's home wifi: the -b doors at 198.51.100.200 carried its
    // tunnel, and the first address of each server was dead.
    const works = '198.51.100.200:8443|xhttp-reality-b';
    const dead = '198.51.100.204:8443|xhttp-reality';
    const other = '198.51.100.203:8443|xhttp-reality-b';
    final holding = [works, dead, other];

    test('is never skipped, whatever its failures', () async {
      final m = memory();
      await m.remember('wifi', works);
      for (var i = 0; i < 4; i++) {
        await m.markFailed('wifi', works);
        await m.markFailed('wifi', dead);
      }
      expect(await m.skippable('wifi', holding: holding), {dead});
      // The day rule alone would hide it too.
      expect(await m.skippable('wifi'), {works, dead});
    });

    test('is skipped like any door once another door has worked', () async {
      final m = memory();
      await m.remember('wifi', works);
      await m.remember('wifi', other);
      for (var i = 0; i < 3; i++) {
        await m.markFailed('wifi', works);
      }
      expect(await m.skippable('wifi', holding: holding), {works});
    });

    test('a door that never carried traffic is still skipped', () async {
      final m = memory();
      await m.remember('wifi', works);
      for (var i = 0; i < 3; i++) {
        await m.markFailed('wifi', dead);
      }
      expect(await m.skippable('wifi', holding: holding), {dead});
    });

    test('counts only doors the phone still holds', () async {
      final m = memory();
      // 198.51.100.208 worked here, then the backend replaced that address.
      await m.remember('wifi', '198.51.100.208:8443|xhttp-reality');
      await m.remember('wifi', works);
      for (var i = 0; i < 3; i++) {
        await m.markFailed('wifi', works);
      }
      expect(await m.skippable('wifi', holding: holding), isEmpty);
    });

    test('doors the phone no longer holds leave the record', () async {
      final m = memory();
      await m.remember('wifi', '198.51.100.208:8443|xhttp-reality');
      await m.remember('wifi', works, holding: holding);
      await m.remember('wifi', other, holding: [works, other]);
      // Both still held, so neither is the only one.
      for (var i = 0; i < 3; i++) {
        await m.markFailed('wifi', works);
      }
      expect(await m.skippable('wifi', holding: holding), {works});
      // Read with the old address held again: its record is gone.
      expect(
        await m.skippable(
          'wifi',
          holding: ['198.51.100.208:8443|xhttp-reality', works],
        ),
        isEmpty,
      );
    });

    test('is per network', () async {
      final m = memory();
      await m.remember('mobile:Irancell', works);
      for (var i = 0; i < 3; i++) {
        await m.markFailed('wifi', works);
      }
      expect(await m.skippable('wifi', holding: holding), {works});
    });
  });

  group('what the sweep found open', () {
    const a = '198.51.100.200:8443|xhttp-reality-b';
    const b = '198.51.100.200:2053|grpc-reality-b';

    test('is kept per network for as long as asked', () async {
      final m = memory();
      await m.markSwept('wifi', [a, b]);
      now = now.add(const Duration(minutes: 24));
      expect(await m.sweptOpen('wifi', const Duration(hours: 3)), {a, b});
      expect(
        await m.sweptOpen('mobile:Irancell', const Duration(hours: 3)),
        isEmpty,
      );
      now = now.add(const Duration(hours: 3));
      expect(await m.sweptOpen('wifi', const Duration(hours: 3)), isEmpty);
    });

    test('is replaced by the next sweep', () async {
      final m = memory();
      await m.markSwept('wifi', [a, b]);
      await m.markSwept('wifi', [b]);
      expect(await m.sweptOpen('wifi', const Duration(hours: 1)), {b});
      await m.markSwept('wifi', const []);
      expect(await m.sweptOpen('wifi', const Duration(hours: 1)), isEmpty);
    });

    test('leaves the rest of the memory alone', () async {
      final m = memory();
      await m.remember('wifi', a);
      await m.markSwept('wifi', [b]);
      expect(await m.recall('wifi'), a);
    });
  });

  test('garbage in storage reads as no memory', () async {
    SharedPreferences.setMockInitialValues({
      PathMemory.storageKey: '{not json',
    });
    final m = memory();
    expect(await m.recall('wifi'), isNull);
    expect(await m.skippable('wifi'), isEmpty);
    await m.remember('wifi', 'k');
    expect(await m.recall('wifi'), 'k');
  });
}
