import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/path_finder.dart';

/// The search: one door at a time, in order, stopping at the first that
/// carries data.
Server door(String host, String door) => Server(
  id: 'dedicated-$host:443',
  name: host,
  country: '',
  city: host,
  connectionUri: 'vless://u@$host:443?type=tcp#$host',
  flagEmoji: '🌍',
  isDedicated: true,
  door: door,
  doorLabel: door,
);

void main() {
  final hel1 = door('hel', 'tcp-reality');
  final hel2 = door('hel', 'xhttp-reality');
  final fsn1 = door('fsn', 'tcp-reality');

  test('stops at the first open door and reports what it checked', () async {
    final probed = <String>[];
    final finder = PathFinder(
      probe: (p) async {
        probed.add(p.pathKey);
        return p == hel2 ? 210 : -1;
      },
      internet: () async => true,
    );

    final finding = await finder.find([hel1, hel2, fsn1]);

    expect(finding.internet, isTrue);
    expect(finding.open, hel2);
    expect(probed, [hel1.pathKey, hel2.pathKey]);
    expect(finding.checks.map((c) => c.state), [
      PathCheckState.blocked,
      PathCheckState.open,
      PathCheckState.pending,
    ]);
    expect(finding.checks[1].ms, 210);
    expect(finding.checks.where((c) => c.reportable), hasLength(2));
  });

  // Until 1.7.1 the control fetch ran first, and a failed one ended the
  // search with no door checked. In the 24 hours to 01:00 Tehran on
  // 2026-10-12 that was 30 first taps a day, and 19 of their 30 traces
  // reached the backend within 2 minutes. It now runs beside the checks.
  group('the control fetch beside the checks', () {
    test('a failed control fetch and every door closed is no internet, and '
        'the rows are kept', () async {
      var probes = 0;
      final finder = PathFinder(
        probe: (p) async {
          probes++;
          return -1;
        },
        internet: () async => false,
      );
      final finding = await finder.find([hel1, hel2]);
      expect(finding.internet, isFalse);
      expect(finding.open, isNull);
      expect(probes, 2);
      expect(
        finding.checks.every((c) => c.state == PathCheckState.blocked),
        isTrue,
      );
      expect(await finding.control, isFalse);
    });

    test('the control fetch runs beside the first check', () async {
      final fetch = Completer<bool>();
      final pendingAtProbe = <bool>[];
      final finder = PathFinder(
        probe: (p) async {
          pendingAtProbe.add(!fetch.isCompleted);
          return p == hel1 ? 90 : -1;
        },
        internet: () => fetch.future,
      );

      final finding = await finder.find([hel1, hel2]);

      expect(fetch.isCompleted, isFalse);
      expect(pendingAtProbe, [true]);
      expect(finding.open, hel1);
      expect(finding.internet, isTrue);
      fetch.complete(false);
      expect(await finding.control, isFalse);
    });

    test('a door open beside a failed control fetch is open', () async {
      final probed = <String>[];
      final finder = PathFinder(
        probe: (p) async {
          probed.add(p.pathKey);
          return p == hel2 ? 150 : -1;
        },
        internet: () async => false,
      );

      final finding = await finder.find([hel1, hel2, fsn1]);

      expect(finding.open, hel2);
      expect(finding.internet, isTrue);
      expect(probed, [hel1.pathKey, hel2.pathKey]);
      expect(await finding.control, isFalse);
    });

    PathFinder slow(bool online, void Function() counted) => PathFinder(
      probe: (p) async {
        counted();
        await Future.delayed(const Duration(milliseconds: 30));
        return -1;
      },
      internet: () async => online,
    );

    test('after a failed control fetch no check starts past the offline '
        'budget', () async {
      var probes = 0;
      final finder = slow(false, () => probes++);

      final finding = await finder.find([
        hel1,
        hel2,
        fsn1,
      ], offlineBudget: const Duration(milliseconds: 40));

      expect(probes, lessThan(3));
      expect(finding.checks.last.state, PathCheckState.pending);
      expect(finding.internet, isFalse);
    });

    test('with the control fetch passing the offline budget changes '
        'nothing', () async {
      var probes = 0;
      final finder = slow(true, () => probes++);

      final finding = await finder.find([
        hel1,
        hel2,
        fsn1,
      ], offlineBudget: const Duration(milliseconds: 40));

      expect(probes, 3);
      expect(finding.internet, isTrue);
      expect(finding.open, isNull);
    });

    test('with no door open the search waits for the control fetch', () async {
      final fetch = Completer<bool>();
      final finder = PathFinder(
        probe: (p) async => -1,
        internet: () => fetch.future,
      );

      PathFinding? finding;
      final search = finder.find([hel1, hel2]).then((f) => finding = f);
      await pumpEventQueue();

      expect(finding, isNull);
      expect(finder.isRunning, isTrue);
      expect(
        finder.checks.every((c) => c.state == PathCheckState.blocked),
        isTrue,
      );

      fetch.complete(true);
      await search;
      expect(finding!.internet, isTrue);
      expect(finding!.open, isNull);
      expect(finder.isRunning, isFalse);
    });

    test('a stop while the search waits on the control fetch ends it at '
        'once', () async {
      final finder = PathFinder(
        probe: (p) async => -1,
        internet: () => Completer<bool>().future,
      );

      final search = finder.find([hel1, hel2]);
      await pumpEventQueue();
      expect(finder.isRunning, isTrue);
      finder.cancel();

      final finding = await search.timeout(const Duration(seconds: 1));
      expect(finding.cancelled, isTrue);
      expect(finder.isRunning, isFalse);
      await finder.idle.timeout(const Duration(seconds: 1));
    });

    test('a control fetch that throws counts as failed', () async {
      final finder = PathFinder(
        probe: (p) async => -1,
        internet: () async => throw StateError('no answer from the platform'),
      );

      final finding = await finder.find([hel1]);

      expect(finding.internet, isFalse);
      expect(await finding.control, isFalse);
      expect(await finder.controlFetch(), isFalse);
    });

    // The checklist's internet row reads [PathFinder.internet]. Until
    // 2026-10-12 it showed a tick while the fetch ran and after it failed.
    group('what the internet row shows', () {
      test('unknown while the fetch runs with every door closed, then what '
          'it found', () async {
        for (final passed in [false, true]) {
          final fetch = Completer<bool>();
          final finder = PathFinder(
            probe: (p) async => -1,
            internet: () => fetch.future,
          );
          var heard = 0;
          finder.addListener(() => heard++);

          final search = finder.find([hel1, hel2]);
          await pumpEventQueue();
          expect(finder.checks.map((c) => c.state), [
            PathCheckState.blocked,
            PathCheckState.blocked,
          ]);
          expect(finder.internet, isNull);

          final before = heard;
          fetch.complete(passed);
          await search;
          expect(finder.internet, passed);
          expect(heard, greaterThan(before));
        }
      });

      test('a door found open counts while the fetch runs, and a failed '
          'fetch after it leaves it', () async {
        final fetch = Completer<bool>();
        final finder = PathFinder(
          probe: (p) async => 120,
          internet: () => fetch.future,
        );

        final finding = await finder.find([hel1]);
        expect(finding.open, hel1);
        expect(finder.internet, isTrue);

        fetch.complete(false);
        await pumpEventQueue();
        expect(finder.internet, isTrue);
      });

      test('a link found open after a failed fetch counts', () async {
        final finder = PathFinder(
          probe: (p) async => p == fsn1 ? 90 : -1,
          internet: () async => false,
        );

        final finding = await finder.find([hel1, hel2]);
        expect(finding.internet, isFalse);
        expect(finder.internet, isFalse);

        // The shared fallback after it, on the same checklist.
        await finder.race([fsn1], parallel: 2);
        expect(finder.internet, isTrue);
      });

      test('a fetch that answers after a newer one started changes '
          'nothing', () async {
        final first = Completer<bool>();
        final second = Completer<bool>();
        final fetches = [first, second];
        final finder = PathFinder(
          probe: (p) async => -1,
          internet: () => fetches.removeAt(0).future,
        );

        final a = finder.controlFetch();
        final b = finder.controlFetch();
        first.complete(false);
        expect(await a, isFalse);
        expect(finder.internet, isNull);

        second.complete(true);
        expect(await b, isTrue);
        expect(finder.internet, isTrue);

        // A new fetch starts unknown again.
        fetches.add(Completer<bool>());
        unawaited(finder.controlFetch());
        expect(finder.internet, isNull);
      });
    });
  });

  // #269: a site inside the country tells a cut way abroad from no
  // internet, and is asked only once the sites abroad failed.
  group('a site inside the country', () {
    test('is asked only after the sites abroad failed', () async {
      var asks = 0;
      PathFinder finder({required bool abroad, bool? home}) => PathFinder(
        probe: (_) async => -1,
        internet: () async => abroad,
        home: home == null
            ? null
            : () async {
                asks++;
                return home;
              },
      );

      var f = finder(abroad: true, home: true);
      expect(await f.controlFetch(), isTrue);
      expect(await f.reach, NetReach.open);
      expect(f.cut, isNull);
      expect(asks, 0);

      f = finder(abroad: false, home: true);
      expect(await f.controlFetch(), isFalse);
      expect(await f.reach, NetReach.cut);
      expect(f.internet, isFalse);
      expect(f.cut, isTrue);
      expect(asks, 1);

      f = finder(abroad: false, home: false);
      await f.controlFetch();
      expect(await f.reach, NetReach.offline);
      expect(f.cut, isFalse);

      // No check inside the country: a failed fetch is no internet.
      f = finder(abroad: false);
      await f.controlFetch();
      expect(await f.reach, NetReach.offline);
    });

    test('one that throws reached nothing', () async {
      final f = PathFinder(
        probe: (_) async => -1,
        internet: () async => false,
        home: () async => throw StateError('no answer from the platform'),
      );
      await f.controlFetch();
      expect(await f.reach, NetReach.offline);
    });

    test('that answered keeps the search going past the offline budget, and '
        'the finding says cut', () async {
      final doors = [for (var i = 0; i < 6; i++) door('h$i', 'tcp')];
      Future<PathFinding> search({required bool home}) {
        final f = PathFinder(
          probe: (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 15));
            return -1;
          },
          internet: () async => false,
          home: () async => home,
          budget: const Duration(seconds: 2),
        );
        return f.find(doors, offlineBudget: const Duration(milliseconds: 20));
      }

      final offline = await search(home: false);
      expect(
        offline.checks.where((c) => c.state == PathCheckState.blocked).length,
        lessThan(doors.length),
      );
      expect(offline.cut, isFalse);

      final cut = await search(home: true);
      expect(
        cut.checks.every((c) => c.state == PathCheckState.blocked),
        isTrue,
      );
      expect(cut.internet, isFalse);
      expect(cut.cut, isTrue);
    });
  });

  test('every door blocked is nothing open, and every row says so', () async {
    final finder = PathFinder(
      probe: (p) async => -1,
      internet: () async => true,
    );
    final finding = await finder.find([hel1, hel2, fsn1]);
    expect(finding.open, isNull);
    expect(
      finding.checks.every((c) => c.state == PathCheckState.blocked),
      isTrue,
    );
  });

  test('skipped doors are shown but never dialled', () async {
    final probed = <String>[];
    final finder = PathFinder(
      probe: (p) async {
        probed.add(p.pathKey);
        return -1;
      },
      internet: () async => true,
    );
    final finding = await finder.find([hel1, hel2], skip: {hel1.pathKey});
    expect(finding.checks.first.state, PathCheckState.skipped);
    expect(probed, [hel2.pathKey]);
  });

  test('a check that hangs is blocked after its timeout', () async {
    final finder = PathFinder(
      probe: (p) => p == hel1 ? Completer<int>().future : Future.value(90),
      internet: () async => true,
      probeTimeout: const Duration(milliseconds: 50),
    );
    final finding = await finder.find([hel1, hel2]);
    expect(finding.checks.first.state, PathCheckState.blocked);
    expect(finding.open, hel2);
  });

  test('a check that throws is blocked, not a crash', () async {
    final finder = PathFinder(
      probe: (p) async => throw StateError('closed pipe'),
      internet: () async => true,
    );
    final finding = await finder.find([hel1]);
    expect(finding.checks.single.state, PathCheckState.blocked);
    expect(finding.checks.single.error, contains('closed pipe'));
  });

  test('no new check starts past the budget', () async {
    var probes = 0;
    final finder = PathFinder(
      probe: (p) async {
        probes++;
        await Future.delayed(const Duration(milliseconds: 30));
        return -1;
      },
      internet: () async => true,
      budget: const Duration(milliseconds: 40),
    );
    final finding = await finder.find([hel1, hel2, fsn1]);
    expect(probes, lessThan(3));
    expect(finding.open, isNull);
    expect(finding.checks.last.state, PathCheckState.pending);
  });

  test('cancel stops after the check in flight', () async {
    late PathFinder finder;
    var probes = 0;
    finder = PathFinder(
      probe: (p) async {
        probes++;
        finder.cancel();
        return -1;
      },
      internet: () async => true,
    );
    final finding = await finder.find([hel1, hel2, fsn1]);
    expect(probes, 1);
    expect(finding.cancelled, isTrue);
    expect(finding.open, isNull);
  });

  group('cut short', () {
    // A tap that has looked long enough stops checking doors and still
    // dials one found open (ConnectFlow._cutSearch). A stop drops it.
    final nbg = door('nbg', 'tcp-reality');

    /// A finder whose checks take [takes] and find [open] open.
    PathFinder timed(
      Map<Server, Duration> takes,
      Set<Server> open, {
      bool internet = true,
    }) => PathFinder(
      probe: (p) async {
        await Future<void>.delayed(takes[p] ?? Duration.zero);
        return open.contains(p) ? 120 : -1;
      },
      internet: () async => internet,
      probeTimeout: const Duration(seconds: 5),
    );

    test('a race keeps the door it found open while other checks ran, '
        'where a stop drops it', () async {
      for (final keep in [true, false]) {
        final finder = timed(
          {
            hel1: const Duration(milliseconds: 10),
            hel2: const Duration(milliseconds: 200),
            fsn1: const Duration(milliseconds: 200),
          },
          {hel1},
        );
        final race = finder.race([hel1, hel2, fsn1, nbg], parallel: 2);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        keep ? finder.cutShort() : finder.cancel();
        final finding = await race;

        expect(finding.open, keep ? hel1 : isNull, reason: 'keep: $keep');
        expect(finding.cancelled, !keep, reason: 'keep: $keep');
        // No check started after the stop or the cut.
        expect(finder.checks.last.state, PathCheckState.pending);
      }
    });

    test('a check that answers open after the cut counts too', () async {
      final finder = timed({hel1: const Duration(milliseconds: 100)}, {hel1});
      final rest = finder.race([hel1, hel2], parallel: 1);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      finder.cutShort();
      final finding = await rest;

      expect(finding.open, hel1);
      expect(finding.cancelled, isFalse);
    });

    test('several checks at once keep the first row found open, and the '
        'rows above it that still run go back to pending', () async {
      for (final keep in [true, false]) {
        final finder = timed(
          {
            hel1: const Duration(milliseconds: 400),
            hel2: const Duration(milliseconds: 10),
            fsn1: const Duration(milliseconds: 400),
          },
          {hel2},
        );
        final from = DateTime.now();
        final search = finder.find([hel1, hel2, fsn1, nbg], parallel: 3);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        keep ? finder.cutShort() : finder.cancel();
        final finding = await search;

        // Without waiting for the checks in flight.
        expect(
          DateTime.now().difference(from),
          lessThan(const Duration(milliseconds: 300)),
        );
        expect(finding.open, keep ? hel2 : isNull, reason: 'keep: $keep');
        expect(finding.cancelled, !keep, reason: 'keep: $keep');
        expect(finder.checks.map((c) => c.state), [
          PathCheckState.pending,
          keep ? PathCheckState.open : PathCheckState.pending,
          PathCheckState.pending,
          PathCheckState.pending,
        ]);
      }
    });

    test('a search cut short with no door open says what its control fetch '
        'found, where a stop says nothing about it', () async {
      for (final keep in [true, false]) {
        final finder = timed(
          {
            hel1: const Duration(milliseconds: 100),
            hel2: const Duration(milliseconds: 100),
          },
          const {},
          internet: false,
        );
        final search = finder.find([hel1, hel2]);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        keep ? finder.cutShort() : finder.cancel();
        final finding = await search;

        expect(finding.open, isNull);
        expect(finding.cancelled, isTrue);
        expect(finding.internet, !keep, reason: 'keep: $keep');
      }
    });

    test(
      'lasts until the next search, which runs as any search does',
      () async {
        final finder = timed(const {}, {nbg});
        finder.cutShort();
        final finding = await finder.find([hel1, hel2, fsn1, nbg]);

        expect(finding.open, nbg);
        expect(finding.cancelled, isFalse);
        expect(finder.checks.map((c) => c.state), [
          PathCheckState.blocked,
          PathCheckState.blocked,
          PathCheckState.blocked,
          PathCheckState.open,
        ]);
      },
    );
  });

  test('a second search can carry on below the first', () async {
    var internetChecks = 0;
    final probed = <String>[];
    final finder = PathFinder(
      probe: (p) async {
        probed.add(p.pathKey);
        return p == fsn1 ? 120 : -1;
      },
      internet: () async {
        internetChecks++;
        return true;
      },
    );

    await finder.find([hel1, hel2]);
    final finding = await finder.find([fsn1], append: true, online: true);

    expect(internetChecks, 1);
    expect(probed, [hel1.pathKey, hel2.pathKey, fsn1.pathKey]);
    expect(finding.open, fsn1);
    expect(finder.checks.map((c) => c.state), [
      PathCheckState.blocked,
      PathCheckState.blocked,
      PathCheckState.open,
    ]);
  });

  group('the last pass', () {
    final hel3 = door('hel3', 'grpc-reality');
    final fsn2 = door('fsn2', 'xhttp-reality');
    final nbg1 = door('nbg', 'tcp-reality');

    test('checks the rows the search left, in place', () async {
      final probed = <String>[];
      final finder = PathFinder(
        probe: (p) async {
          probed.add(p.pathKey);
          if (p == fsn1) await Future.delayed(const Duration(milliseconds: 30));
          return p == nbg1 ? 140 : -1;
        },
        internet: () async => true,
        budget: const Duration(milliseconds: 10),
      );
      // hel1 skipped for the day; the budget ends after fsn1.
      final first = await finder.find(
        [hel1, hel2, fsn1, nbg1],
        skip: {hel1.pathKey},
      );
      expect(first.open, isNull);
      expect(first.checks.map((c) => c.state), [
        PathCheckState.skipped,
        PathCheckState.blocked,
        PathCheckState.blocked,
        PathCheckState.pending,
      ]);

      final rows = [first.checks[3], first.checks[0]];
      final rest = await finder.findRest(
        rows,
        parallel: 2,
        timeout: const Duration(seconds: 1),
      );

      expect(rest.open, nbg1);
      // Each row kept its place in the checklist.
      expect(finder.checks.map((c) => c.path), [hel1, hel2, fsn1, nbg1]);
      expect(finder.checks.map((c) => c.state), [
        PathCheckState.blocked,
        PathCheckState.blocked,
        PathCheckState.blocked,
        PathCheckState.open,
      ]);
      expect(finder.checks[3].ms, 140);
      expect(finder.checks.every((c) => c.reportable), isTrue);
      // The rows with a result were not checked again.
      expect(probed.where((k) => k == hel2.pathKey), hasLength(1));
      expect(probed.where((k) => k == fsn1.pathKey), hasLength(1));
    });

    test('runs at most [parallel] checks at once', () async {
      var inFlight = 0;
      var most = 0;
      final finder = PathFinder(
        probe: (p) async {
          inFlight++;
          if (inFlight > most) most = inFlight;
          await Future.delayed(const Duration(milliseconds: 10));
          inFlight--;
          return -1;
        },
        internet: () async => true,
      );
      final doors = [hel1, hel2, hel3, fsn1, fsn2, nbg1];
      await finder.find(doors, skip: {for (final d in doors) d.pathKey});

      final rest = await finder.findRest(
        finder.checks,
        parallel: 3,
        timeout: const Duration(seconds: 1),
      );

      expect(most, 3);
      expect(rest.open, isNull);
      expect(
        finder.checks.every((c) => c.state == PathCheckState.blocked),
        isTrue,
      );
    });

    test('starts no check once a door is open, and waits for the ones in '
        'flight', () async {
      final probed = <String>[];
      final slow = Completer<int>();
      final finder = PathFinder(
        probe: (p) {
          probed.add(p.pathKey);
          if (p == hel1) return slow.future;
          return Future.value(p == hel2 ? 60 : -1);
        },
        internet: () async => true,
      );
      final doors = [hel1, hel2, fsn1, nbg1];
      await finder.find(doors, skip: {for (final d in doors) d.pathKey});

      final running = finder.findRest(
        finder.checks,
        parallel: 2,
        timeout: const Duration(seconds: 1),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(finder.isRunning, isTrue);
      expect(finder.checks.first.state, PathCheckState.running);
      slow.complete(-1);
      final rest = await running;

      expect(probed, [hel1.pathKey, hel2.pathKey]);
      expect(rest.open, hel2);
      expect(finder.checks.first.state, PathCheckState.blocked);
      expect(finder.checks[2].state, PathCheckState.skipped);
      expect(finder.isRunning, isFalse);
    });

    test(
      'the open door is the first of the rows, not the first to answer',
      () async {
        final finder = PathFinder(
          probe: (p) async {
            if (p == hel1) {
              await Future.delayed(const Duration(milliseconds: 20));
            }
            return 50;
          },
          internet: () async => true,
        );
        await finder.find([hel1, hel2], skip: {hel1.pathKey, hel2.pathKey});
        final rest = await finder.findRest(
          finder.checks,
          parallel: 2,
          timeout: const Duration(seconds: 1),
        );
        expect(rest.open, hel1);
      },
    );

    test('a check past its timeout is blocked', () async {
      final finder = PathFinder(
        probe: (p) => p == hel1 ? Completer<int>().future : Future.value(-1),
        internet: () async => true,
        probeTimeout: const Duration(milliseconds: 10),
      );
      await finder.find([hel1, hel2], skip: {hel1.pathKey, hel2.pathKey});
      final started = DateTime.now();
      final rest = await finder.findRest(
        finder.checks,
        parallel: 2,
        timeout: const Duration(milliseconds: 60),
      );
      expect(rest.open, isNull);
      expect(finder.checks.first.state, PathCheckState.blocked);
      expect(finder.checks.first.error, contains('TimeoutException'));
      // The backend's longer time, not the checklist's own.
      expect(
        DateTime.now().difference(started),
        greaterThanOrEqualTo(const Duration(milliseconds: 60)),
      );
    });

    test('a timeout shorter than the checklist\'s own wait counts as that '
        'wait', () async {
      // The native check runs its own time whatever the app waits. A
      // shorter wait would call this door closed while its check runs.
      var inFlight = 0;
      var most = 0;
      final finder = PathFinder(
        probe: (p) async {
          inFlight++;
          if (inFlight > most) most = inFlight;
          await Future.delayed(const Duration(milliseconds: 40));
          inFlight--;
          return p == hel2 ? 90 : -1;
        },
        internet: () async => true,
        probeTimeout: const Duration(milliseconds: 500),
      );
      final doors = [hel1, hel2, fsn1];
      await finder.find(doors, skip: {for (final d in doors) d.pathKey});
      final rest = await finder.findRest(
        finder.checks,
        parallel: 1,
        timeout: const Duration(milliseconds: 5),
      );
      expect(rest.open, hel2);
      expect(finder.checks.first.state, PathCheckState.blocked);
      expect(finder.checks.first.error, isNull);
      expect(most, 1);
    });

    test('keeps what each check found, as the checklist does', () async {
      final finder = PathFinder(
        read: (p) async => p == hel1
            ? const DoorOutcome(ms: -1, error: 'tcp timeout', phase: 'tcp')
            : const DoorOutcome(ms: 150, tcpMs: 40, phase: 'ok'),
        internet: () async => true,
      );
      await finder.find([hel1, hel2], skip: {hel1.pathKey, hel2.pathKey});
      final rest = await finder.findRest(
        finder.checks,
        parallel: 1,
        timeout: const Duration(seconds: 1),
      );

      expect(rest.open, hel2);
      final closed = finder.checks.first;
      expect(closed.state, PathCheckState.blocked);
      expect(closed.error, 'tcp timeout');
      expect(closed.phase, 'tcp');
      expect(closed.tcpMs, isNull);
      final open = finder.checks[1];
      expect(open.ms, 150);
      expect(open.tcpMs, 40);
      expect(open.phase, 'ok');
      expect(open.error, isNull);
    });

    test('a row that is not on the checklist is left alone', () async {
      var probes = 0;
      final finder = PathFinder(
        probe: (p) async {
          probes++;
          return 70;
        },
        internet: () async => true,
      );
      await finder.find([hel1], skip: {hel1.pathKey});
      final stranger = PathCheck(fsn1);
      final rest = await finder.findRest(
        [stranger],
        parallel: 1,
        timeout: const Duration(seconds: 1),
      );
      expect(probes, 0);
      expect(rest.open, isNull);
      expect(stranger.state, PathCheckState.pending);
    });

    test('cancel starts no further check', () async {
      late PathFinder finder;
      var probes = 0;
      finder = PathFinder(
        probe: (p) async {
          probes++;
          finder.cancel();
          return -1;
        },
        internet: () async => true,
      );
      final doors = [hel1, hel2, fsn1];
      await finder.find(doors, skip: {for (final d in doors) d.pathKey});
      final rest = await finder.findRest(
        finder.checks,
        parallel: 1,
        timeout: const Duration(seconds: 1),
      );
      expect(probes, 1);
      expect(rest.cancelled, isTrue);
      expect(rest.open, isNull);
    });
  });

  group('a race below the rows on screen', () {
    final ams = door('ams', 'tcp-reality');
    final waw = door('waw', 'tcp-reality');
    final vie = door('vie', 'tcp-reality');

    test('adds its rows below the last search and checks them several at '
        'once', () async {
      var running = 0;
      var most = 0;
      final finder = PathFinder(
        probe: (p) async {
          running++;
          if (running > most) most = running;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          running--;
          return p == vie ? 80 : -1;
        },
        internet: () async => true,
      );
      await finder.find([hel1]);

      final finding = await finder.race([ams, waw, vie], parallel: 3);

      expect(most, 3);
      expect(finding.internet, isTrue);
      expect(finding.open, vie);
      expect(finder.checks.map((c) => c.path), [hel1, ams, waw, vie]);
      expect(finder.checks.map((c) => c.state), [
        PathCheckState.blocked,
        PathCheckState.blocked,
        PathCheckState.blocked,
        PathCheckState.open,
      ]);
      expect(finder.isRunning, isFalse);
    });

    test('the open one is the first in the given order, not the first to '
        'answer', () async {
      final finder = PathFinder(
        probe: (p) async {
          if (p == ams) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return 300;
          }
          return p == waw ? 40 : -1;
        },
        internet: () async => true,
      );

      final finding = await finder.race([ams, waw], parallel: 2);

      expect(finding.open, ams);
      expect(finder.checks.map((c) => c.state), [
        PathCheckState.open,
        PathCheckState.open,
      ]);
    });

    test('at most [parallel] at once, and none starts once one is '
        'open', () async {
      final probed = <String>[];
      final finder = PathFinder(
        probe: (p) async {
          probed.add(p.pathKey);
          return p == ams ? 50 : -1;
        },
        internet: () async => true,
      );

      final finding = await finder.race([
        ams,
        waw,
        vie,
        hel1,
        fsn1,
      ], parallel: 2);

      expect(finding.open, ams);
      expect(probed, [ams.pathKey, waw.pathKey]);
      expect(finder.checks.skip(2).map((c) => c.state).toSet(), {
        PathCheckState.pending,
      });
    });

    test('a check that hangs is blocked after the finder\'s timeout', () async {
      final finder = PathFinder(
        probe: (p) => Completer<int>().future,
        internet: () async => true,
        probeTimeout: const Duration(milliseconds: 20),
      );

      final finding = await finder.race([ams, waw], parallel: 2);

      expect(finding.open, isNull);
      expect(finder.checks.map((c) => c.state).toSet(), {
        PathCheckState.blocked,
      });
    });
  });

  // On Tehran day 2026-10-23 a race of shared links that found one open
  // still waited about 3.1 seconds for the checks below it. With
  // returnAtFirst it returns once the open row is known.
  group('a race that returns at the first open row', () {
    final ams = door('ams', 'tcp-reality');
    final waw = door('waw', 'tcp-reality');
    final vie = door('vie', 'tcp-reality');

    test('does not wait for the checks below the open row', () async {
      final slow = Completer<int>();
      final finder = PathFinder(
        probe: (p) async => p == ams ? 60 : slow.future,
        internet: () async => true,
        probeTimeout: const Duration(seconds: 30),
      );

      final finding = await finder
          .race([ams, waw], parallel: 2, returnAtFirst: true)
          .timeout(const Duration(seconds: 2));

      expect(finding.open, ams);
      expect(finder.isRunning, isFalse);
      // The check still in flight is back to pending, as one at a time
      // would leave it, and its late answer changes nothing.
      expect(finder.checks.map((c) => c.state), [
        PathCheckState.open,
        PathCheckState.pending,
      ]);
      slow.complete(90);
      await pumpEventQueue();
      expect(finder.checks[1].state, PathCheckState.pending);
      expect(finder.checks[1].ms, isNull);
    });

    test('still waits for a row above the open one', () async {
      final above = Completer<int>();
      final finder = PathFinder(
        probe: (p) async => p == ams ? above.future : (p == waw ? 40 : -1),
        internet: () async => true,
        probeTimeout: const Duration(seconds: 30),
      );

      var done = false;
      final race = finder
          .race([ams, waw, vie], parallel: 3, returnAtFirst: true)
          .whenComplete(() => done = true);
      await pumpEventQueue();
      expect(done, isFalse);

      above.complete(-1);
      final finding = await race;
      expect(finding.open, waw);
      expect(finder.checks.map((c) => c.state), [
        PathCheckState.blocked,
        PathCheckState.open,
        PathCheckState.blocked,
      ]);
    });

    test('the row above wins when it is open too', () async {
      final above = Completer<int>();
      final finder = PathFinder(
        probe: (p) async => p == ams ? above.future : 40,
        internet: () async => true,
        probeTimeout: const Duration(seconds: 30),
      );

      final race = finder.race([ams, waw], parallel: 2, returnAtFirst: true);
      await pumpEventQueue();
      above.complete(300);
      expect((await race).open, ams);
    });

    test('with nothing open, every row has its result', () async {
      final finder = PathFinder(
        probe: (p) async => -1,
        internet: () async => true,
      );

      final finding = await finder.race(
        [ams, waw, vie],
        parallel: 2,
        returnAtFirst: true,
      );

      expect(finding.open, isNull);
      expect(finder.checks.map((c) => c.state).toSet(), {
        PathCheckState.blocked,
      });
    });

    test('a stop ends it at once, with the checks still in flight', () async {
      final finder = PathFinder(
        probe: (p) => Completer<int>().future,
        internet: () async => true,
        probeTimeout: const Duration(seconds: 30),
      );

      final race = finder.race([ams, waw], parallel: 2, returnAtFirst: true);
      await pumpEventQueue();
      finder.cancel();
      final finding = await race.timeout(const Duration(seconds: 2));

      expect(finding.cancelled, isTrue);
      expect(finding.open, isNull);
      expect(finder.checks.map((c) => c.state).toSet(), {
        PathCheckState.pending,
      });
    });

    test('a cut keeps a row found open below one still running', () async {
      final finder = PathFinder(
        probe: (p) async => p == ams ? Completer<int>().future : 40,
        internet: () async => true,
        probeTimeout: const Duration(seconds: 30),
      );

      final race = finder.race([ams, waw], parallel: 2, returnAtFirst: true);
      await pumpEventQueue();
      finder.cutShort();
      final finding = await race.timeout(const Duration(seconds: 2));

      expect(finding.cancelled, isFalse);
      expect(finding.open, waw);
      expect(finder.checks.first.state, PathCheckState.pending);
    });

    test('without it, the checks in flight run to their end', () async {
      final slow = Completer<int>();
      final finder = PathFinder(
        probe: (p) async => p == ams ? 60 : slow.future,
        internet: () async => true,
        probeTimeout: const Duration(seconds: 30),
      );

      var done = false;
      final race = finder
          .race([ams, waw], parallel: 2)
          .whenComplete(() => done = true);
      await pumpEventQueue();
      expect(done, isFalse);
      slow.complete(-1);
      expect((await race).open, ams);
      expect(finder.checks[1].state, PathCheckState.blocked);
    });
  });

  group('budgets', () {
    final ams = door('ams', 'tcp-reality');
    final waw = door('waw', 'tcp-reality');
    final vie = door('vie', 'tcp-reality');

    PathFinder slow(List<String> probed) => PathFinder(
      probe: (p) async {
        probed.add(p.pathKey);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return -1;
      },
      internet: () async => true,
    );

    test('a search can be given its own, shorter budget', () async {
      final probed = <String>[];
      final finder = slow(probed);

      await finder.find([
        ams,
        waw,
        vie,
      ], budget: const Duration(milliseconds: 10));

      expect(probed, [ams.pathKey]);
      expect(finder.checks.map((c) => c.state), [
        PathCheckState.blocked,
        PathCheckState.pending,
        PathCheckState.pending,
      ]);
    });

    test('the rows a search did not reach can be picked up within a '
        'budget', () async {
      final probed = <String>[];
      final finder = slow(probed);
      await finder.find([
        ams,
        waw,
        vie,
      ], budget: const Duration(milliseconds: 10));

      await finder.findRest(
        finder.checks,
        parallel: 1,
        timeout: const Duration(seconds: 1),
        budget: const Duration(milliseconds: 10),
      );

      expect(probed, [ams.pathKey, waw.pathKey]);
      expect(finder.checks.last.state, PathCheckState.pending);
    });

    test('a race without append replaces the rows on screen', () async {
      final finder = slow([]);
      await finder.find([ams]);

      await finder.race([waw, vie], parallel: 2, append: false);

      expect(finder.checks.map((c) => c.path), [waw, vie]);
    });
  });

  // One at a time a closed door costs about 3 seconds, and in the 24 hours
  // to 01:00 Tehran on 2026-10-12 a checklist reached 7 or 8 of a phone's
  // 19 to 22 doors. With several checks at once the search still lands on
  // the door a one-at-a-time search would, and leaves the rows as it would.
  // The tests above run with parallel 1 and pin that search.
  group('several at a time', () {
    final more = [for (var i = 0; i < 8; i++) door('d$i', 'tcp-reality')];

    test('runs at most [parallel] at once and reaches every door within the '
        'budget', () async {
      final probed = <String>[];
      var inFlight = 0;
      var most = 0;
      final finder = PathFinder(
        probe: (p) async {
          probed.add(p.pathKey);
          inFlight++;
          if (inFlight > most) most = inFlight;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          inFlight--;
          return -1;
        },
        internet: () async => true,
        budget: const Duration(seconds: 1),
      );

      final finding = await finder.find(more, parallel: 4);

      expect(most, 4);
      expect(finding.open, isNull);
      expect(finding.internet, isTrue);
      expect(probed, [for (final d in more) d.pathKey]);
      expect(
        finding.checks.every((c) => c.state == PathCheckState.blocked),
        isTrue,
      );
      expect(finder.isRunning, isFalse);
    });

    test('takes the first door in the order that is open once every door '
        'above it is closed, not the first to answer', () async {
      var hel1Answered = false;
      final finder = PathFinder(
        probe: (p) async {
          if (p == hel1) {
            await Future<void>.delayed(const Duration(milliseconds: 40));
            hel1Answered = true;
            return -1;
          }
          await Future<void>.delayed(const Duration(milliseconds: 1));
          return p == hel2 ? 90 : 80;
        },
        internet: () async => true,
      );

      final finding = await finder.find([hel1, hel2, fsn1], parallel: 3);

      expect(hel1Answered, isTrue);
      expect(finding.open, hel2);
      expect(finding.checks.map((c) => c.state), [
        PathCheckState.blocked,
        PathCheckState.open,
        PathCheckState.pending,
      ]);
      expect(finding.checks[1].ms, 90);
      // fsn1 was found open too, but one at a time it was never reached.
      expect(finding.checks[2].ms, isNull);
      expect(finding.checks.where((c) => c.reportable), hasLength(2));
    });

    test('a door above the open one that opens later still wins', () async {
      final finder = PathFinder(
        probe: (p) async {
          await Future<void>.delayed(
            Duration(milliseconds: p == hel1 ? 30 : 1),
          );
          return p == hel1 ? 150 : 60;
        },
        internet: () async => true,
      );

      final finding = await finder.find([hel1, hel2], parallel: 2);

      expect(finding.open, hel1);
      expect(finding.checks.map((c) => c.state), [
        PathCheckState.open,
        PathCheckState.pending,
      ]);
      expect(finding.checks.first.ms, 150);
    });

    test('returns as soon as the open door is known, with checks below it in '
        'flight, and their answers change nothing', () async {
      final gate = Completer<int>();
      final finder = PathFinder(
        probe: (p) => p == hel1 ? Future.value(120) : gate.future,
        internet: () async => true,
      );

      final finding = await finder
          .find([hel1, hel2], parallel: 2)
          .timeout(const Duration(seconds: 1));

      expect(finding.open, hel1);
      expect(finder.isRunning, isFalse);
      expect(finder.checks[1].state, PathCheckState.pending);

      var heard = 0;
      finder.addListener(() => heard++);
      gate.complete(70);
      await pumpEventQueue();

      expect(heard, 0);
      expect(finder.checks[1].state, PathCheckState.pending);
      expect(finder.checks[1].ms, isNull);
      expect(finder.checks.first.state, PathCheckState.open);
    });

    test('the first checks start [stagger] apart, and one that ends lets the '
        'next start at once', () async {
      final probed = <String>[];
      final gates = <String, Completer<int>>{};
      final finder = PathFinder(
        probe: (p) {
          probed.add(p.pathKey);
          return (gates[p.pathKey] = Completer<int>()).future;
        },
        internet: () async => true,
        probeTimeout: const Duration(seconds: 5),
      );

      final before = DateTime.now();
      final search = finder.find(
        more,
        parallel: 3,
        stagger: const Duration(milliseconds: 100),
      );
      Duration started(int i) => finder.checks[i].startedAt!.difference(before);

      // The test waits for the checks to start, and then reads when each
      // one did, on the clock the search reads too. A stall can only make
      // a check start late, never early, and the test does not time
      // anything against its own timers.
      final end = DateTime.now().add(const Duration(seconds: 5));
      while (probed.length < 3) {
        if (DateTime.now().isAfter(end)) fail('only ${probed.length} started');
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      expect(
        started(1),
        greaterThanOrEqualTo(const Duration(milliseconds: 100)),
      );
      expect(
        started(2),
        greaterThanOrEqualTo(const Duration(milliseconds: 200)),
      );
      // Not much later either: a ramp ten times too slow fails here.
      expect(started(2), lessThan(const Duration(seconds: 2)));
      // No fourth check while three run, however long they take.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(probed, hasLength(3));

      gates[more[0].pathKey]!.complete(-1);
      await pumpEventQueue();
      expect(probed, hasLength(4));

      finder.cancel();
      final finding = await search;
      expect(finding.cancelled, isTrue);
    });

    test('a stop ends the search at once, and the checks in flight change no '
        'row', () async {
      final gates = <String, Completer<int>>{};
      final finder = PathFinder(
        probe: (p) => (gates[p.pathKey] = Completer<int>()).future,
        internet: () async => true,
      );

      final search = finder.find([hel1, hel2, fsn1], parallel: 2);
      await pumpEventQueue();
      expect(gates.keys, [hel1.pathKey, hel2.pathKey]);
      expect(finder.checks[0].state, PathCheckState.running);

      finder.cancel();
      final finding = await search.timeout(const Duration(seconds: 1));

      expect(finding.cancelled, isTrue);
      expect(finding.open, isNull);
      expect(finder.isRunning, isFalse);
      await finder.idle.timeout(const Duration(seconds: 1));
      expect(
        finder.checks.every((c) => c.state == PathCheckState.pending),
        isTrue,
      );

      gates[hel1.pathKey]!.complete(-1);
      gates[hel2.pathKey]!.complete(90);
      await pumpEventQueue();
      expect(
        finder.checks.every((c) => c.state == PathCheckState.pending),
        isTrue,
      );
      expect(gates, hasLength(2));
    });

    test('no check starts past the budget, and the ones in flight run to '
        'their end', () async {
      // The first two checks end at once. The two that start after them are
      // still running when the budget runs out, and end 100 ms apart.
      final finder = PathFinder(
        probe: (p) async {
          if (p == more[0] || p == more[1]) return -1;
          await Future<void>.delayed(
            Duration(milliseconds: p == more[2] ? 400 : 500),
          );
          return -1;
        },
        internet: () async => true,
      );

      final finding = await finder.find(
        more.take(6).toList(),
        budget: const Duration(milliseconds: 300),
        parallel: 2,
      );

      expect(finding.open, isNull);
      expect(finding.checks.map((c) => c.state), [
        for (var i = 0; i < 4; i++) PathCheckState.blocked,
        PathCheckState.pending,
        PathCheckState.pending,
      ]);
    });

    test(
      'findInOrder carries on below the rows a shorter search left',
      () async {
        final probed = <String>[];
        final finder = PathFinder(
          probe: (p) async {
            probed.add(p.pathKey);
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return p == more[4] || p == more[5] ? 70 : -1;
          },
          internet: () async => true,
        );
        final doors = more.take(6).toList();
        final first = await finder.find(
          doors,
          budget: const Duration(milliseconds: 5),
          parallel: 2,
        );
        expect(first.open, isNull);
        final left = [
          for (final c in first.checks)
            if (c.state == PathCheckState.pending) c,
        ];
        expect(left.map((c) => c.path), doors.skip(2));

        final rest = await finder.findInOrder(left, parallel: 2);

        expect(rest.open, more[4]);
        expect(rest.cancelled, isFalse);
        expect(finder.checks.map((c) => c.path), doors);
        expect(finder.checks.map((c) => c.state), [
          PathCheckState.blocked,
          PathCheckState.blocked,
          PathCheckState.blocked,
          PathCheckState.blocked,
          PathCheckState.open,
          PathCheckState.pending,
        ]);
        // No row was checked twice.
        expect(probed, [for (final d in doors) d.pathKey]);
        expect(finder.isRunning, isFalse);
      },
    );

    test('with a failed control fetch no check starts past the offline '
        'budget', () async {
      var probes = 0;
      // The first two checks take a moment, so the control fetch has failed
      // before the next two start. Those two run past the offline budget.
      // The budget is long, so a stalled machine cannot use it up before
      // they start.
      final finder = PathFinder(
        probe: (p) async {
          probes++;
          final first = p == more[0] || p == more[1];
          await Future<void>.delayed(Duration(milliseconds: first ? 40 : 1300));
          return -1;
        },
        internet: () async => false,
      );

      final finding = await finder.find(
        more.take(6).toList(),
        offlineBudget: const Duration(milliseconds: 1200),
        parallel: 2,
      );

      expect(probes, 4);
      expect(finding.internet, isFalse);
      expect(finding.checks.skip(4).map((c) => c.state), [
        PathCheckState.pending,
        PathCheckState.pending,
      ]);
    });

    test(
      'an empty list returns after the control fetch, with its answer',
      () async {
        final fetch = Completer<bool>();
        final finder = PathFinder(
          probe: (p) async => 90,
          internet: () => fetch.future,
        );

        PathFinding? finding;
        final search = finder
            .find(const [], parallel: 4)
            .then((f) => finding = f);
        await pumpEventQueue();
        expect(finding, isNull);

        fetch.complete(false);
        await search;
        expect(finding!.internet, isFalse);
        expect(finding!.open, isNull);
        expect(finding!.cancelled, isFalse);
      },
    );

    test('skipped doors are shown but never dialled', () async {
      final probed = <String>[];
      final finder = PathFinder(
        probe: (p) async {
          probed.add(p.pathKey);
          return p == fsn1 ? 80 : -1;
        },
        internet: () async => true,
      );

      final finding = await finder.find(
        [hel1, hel2, fsn1],
        skip: {hel1.pathKey},
        parallel: 3,
      );

      expect(probed, [hel2.pathKey, fsn1.pathKey]);
      expect(finding.open, fsn1);
      expect(finding.checks.map((c) => c.state), [
        PathCheckState.skipped,
        PathCheckState.blocked,
        PathCheckState.open,
      ]);
    });
  });

  test('listeners hear every row change', () async {
    final finder = PathFinder(
      probe: (p) async => p == hel2 ? 50 : -1,
      internet: () async => true,
    );
    var notifications = 0;
    finder.addListener(() => notifications++);
    await finder.find([hel1, hel2]);
    // start, running, blocked, running, open, finished
    expect(notifications, greaterThanOrEqualTo(5));
    expect(finder.isRunning, isFalse);
  });
}
