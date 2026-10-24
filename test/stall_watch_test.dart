import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/stall_watch_settings.dart';
import 'package:fortiva_vpn/services/stall_watch.dart';

/// The watch that tells a tunnel carrying nothing from an idle one (#289).
void main() {
  late List<TunnelCounts?> readings;
  late List<bool> answers;
  late int probes;
  late List<StallFinding> found;
  late DateTime now;

  StallWatch watch(FakeAsync async) => StallWatch(
    read: () async => readings.isEmpty ? null : readings.removeAt(0),
    probe: () async {
      probes++;
      return answers.isEmpty ? false : answers.removeAt(0);
    },
    onStall: found.add,
    now: () => now.add(async.elapsed),
  );

  setUp(() {
    readings = [];
    answers = [];
    probes = 0;
    found = [];
    now = DateTime.utc(2026, 10, 16, 5);
  });

  test('an idle phone is never checked', () {
    fakeAsync((async) {
      final w = watch(async)..start();
      readings = [(up: 300, down: 0), (up: 0, down: 0)];
      async.elapse(const Duration(minutes: 2));
      expect(probes, 0);
      expect(found, isEmpty);
      w.stop();
    });
  });

  test('a tunnel bringing data down is not checked', () {
    fakeAsync((async) {
      final w = watch(async)..start();
      readings = [(up: 50000, down: 2048)];
      async.elapse(const Duration(minutes: 1));
      expect(probes, 0);
      w.stop();
    });
  });

  test('sent but nothing back is checked, and a passing check ends it', () {
    fakeAsync((async) {
      final w = watch(async)..start();
      readings = [(up: 4000, down: 0)];
      answers = [true];
      async.elapse(const Duration(minutes: 1));
      expect(probes, 1);
      expect(found, isEmpty);
      expect(w.fired, isFalse);
      w.stop();
    });
  });

  test('three failed checks in a row call the tunnel dead, once', () {
    fakeAsync((async) {
      final w = watch(async)..start();
      readings = [(up: 4000, down: 10), (up: 4000, down: 0)];
      answers = [false, false, false];
      async.elapse(const Duration(minutes: 1));
      expect(probes, 1);
      // Checks are spread out, so a core moving to a standby door has time.
      async.elapse(StallWatch.defaultCheckGap);
      expect(probes, 2);
      async.elapse(StallWatch.defaultCheckGap);
      expect(probes, 3);
      expect(found, hasLength(1));
      final f = found.single;
      expect(f.trigger, StallWatch.triggerCounters);
      expect(f.probes, 3);
      expect(f.facts, {
        'stall_trigger': 'counters',
        'stall_probes': 3,
        'stall_quiet_s': 80,
        'stall_up_bytes': 4000,
        'stall_down_bytes': 10,
      });
      // Nothing more for this tunnel, whatever the counters say.
      async.elapse(const Duration(minutes: 5));
      expect(probes, 3);
      expect(found, hasLength(1));
      w.stop();
    });
  });

  test('a check that passes in between starts the count over', () {
    fakeAsync((async) {
      final w = watch(async)..start();
      readings = [(up: 4000, down: 0), (up: 4000, down: 0)];
      answers = [false, true, false, false, false];
      async.elapse(const Duration(minutes: 1, seconds: 10));
      expect(probes, 2);
      expect(found, isEmpty);
      async.elapse(const Duration(minutes: 1, seconds: 30));
      expect(probes, 5);
      expect(found, hasLength(1));
      w.stop();
    });
  });

  test('a tunnel that goes down while it is checked is not reported', () {
    fakeAsync((async) {
      final w = watch(async)..start();
      readings = [(up: 4000, down: 0)];
      async.elapse(const Duration(minutes: 1));
      expect(probes, 1);
      w.stop();
      async.elapse(const Duration(minutes: 1));
      expect(probes, 1);
      expect(found, isEmpty);
    });
  });

  test('no reading, as on iOS, does nothing', () {
    fakeAsync((async) {
      final w = watch(async)..start();
      async.elapse(const Duration(minutes: 3));
      expect(probes, 0);
      w.stop();
    });
  });

  test('opening the app checks at once, at most every two minutes', () {
    fakeAsync((async) {
      final w = watch(async)..start();
      answers = [true];
      w.resumed();
      async.flushMicrotasks();
      expect(probes, 1);
      w.resumed();
      async.flushMicrotasks();
      expect(probes, 1);
      async.elapse(StallWatch.defaultResumeGap);
      answers = [false, false, false];
      w.resumed();
      async.elapse(const Duration(seconds: 25));
      expect(probes, 4);
      expect(found.single.trigger, StallWatch.triggerResume);
      w.stop();
    });
  });

  test('opening the app with data coming down checks nothing', () {
    fakeAsync((async) {
      final w = watch(async)..start();
      readings = [(up: 900, down: 70000)];
      w.resumed();
      async.flushMicrotasks();
      expect(probes, 0);
      w.stop();
    });
  });

  test('a new tunnel is watched afresh', () {
    fakeAsync((async) {
      final w = watch(async)..start();
      readings = [(up: 4000, down: 0)];
      async.elapse(const Duration(minutes: 1, seconds: 25));
      expect(found, hasLength(1));
      w.stop();
      w.start();
      expect(w.fired, isFalse);
      readings = [(up: 4000, down: 0)];
      async.elapse(const Duration(minutes: 1, seconds: 25));
      expect(found, hasLength(2));
      w.stop();
    });
  });

  test('a reading that throws is no reading', () {
    fakeAsync((async) {
      final w = StallWatch(
        read: () async => throw StateError('no core'),
        probe: () async {
          probes++;
          return false;
        },
        onStall: found.add,
      )..start();
      async.elapse(const Duration(minutes: 2));
      expect(probes, 0);
      w.stop();
    });
  });

  group('with the throttle trigger on', () {
    const throttling = StallWatchSettings(
      throttle: true,
      throttleRatio: 0.1,
      throttleReadings: 10,
      throttleMinNormal: 65536,
      throttleCooldown: Duration(minutes: 5),
    );
    late int changes;

    StallWatch throttleWatch(FakeAsync async) => StallWatch(
      read: () async => readings.isEmpty ? null : readings.removeAt(0),
      probe: () async {
        probes++;
        return answers.isEmpty ? false : answers.removeAt(0);
      },
      onStall: found.add,
      onChange: () => changes++,
      settings: () => throttling,
      now: () => now.add(async.elapsed),
    );

    setUp(() => changes = 0);

    // Five minutes of a session that brings 500 KB a minute back.
    List<TunnelCounts> normal() => List.filled(5, (up: 20000, down: 500000));

    test('a trickle far below the session\'s normal is checked', () {
      fakeAsync((async) {
        final w = throttleWatch(async)..start();
        readings = [...normal(), (up: 20000, down: 20000)];
        answers = [true];
        async.elapse(const Duration(minutes: 6));
        expect(probes, 1);
        expect(found, isEmpty);
        w.stop();
      });
    });

    test('a throttled tunnel whose checks all fail is called dead', () {
      fakeAsync((async) {
        final w = throttleWatch(async)..start();
        readings = [...normal(), (up: 20000, down: 20000)];
        async.elapse(const Duration(minutes: 6));
        async.elapse(const Duration(seconds: 25));
        expect(probes, 3);
        expect(found, hasLength(1));
        expect(found.single.trigger, StallWatch.triggerThrottle);
        w.stop();
      });
    });

    test('after a passing check the trigger rests', () {
      fakeAsync((async) {
        final w = throttleWatch(async)..start();
        readings = [
          ...normal(),
          (up: 20000, down: 20000),
          (up: 20000, down: 20000),
          (up: 20000, down: 20000),
        ];
        answers = [true, true];
        async.elapse(const Duration(minutes: 8));
        expect(probes, 1);
        w.stop();
      });
    });

    test('too few readings to know the normal are not judged', () {
      fakeAsync((async) {
        final w = throttleWatch(async)..start();
        readings = [
          (up: 20000, down: 500000),
          (up: 20000, down: 500000),
          (up: 20000, down: 20000),
        ];
        async.elapse(const Duration(minutes: 3));
        expect(probes, 0);
        w.stop();
      });
    });

    test('a session that never brought much back is not judged', () {
      fakeAsync((async) {
        final w = throttleWatch(async)..start();
        readings = [
          ...List.filled(5, (up: 20000, down: 30000)),
          (up: 20000, down: 2000),
        ];
        async.elapse(const Duration(minutes: 6));
        expect(probes, 0);
        w.stop();
      });
    });

    test('a failed try puts the tunnel in doubt until the check ends', () {
      fakeAsync((async) {
        final w = throttleWatch(async)..start();
        readings = [...normal(), (up: 20000, down: 20000)];
        answers = [false, true];
        async.elapse(const Duration(minutes: 6));
        expect(probes, 1);
        expect(w.doubting, isTrue);
        expect(changes, 1);
        async.elapse(StallWatch.defaultCheckGap);
        expect(probes, 2);
        expect(w.doubting, isFalse);
        expect(changes, 2);
        expect(found, isEmpty);
        w.stop();
      });
    });
  });

  test('a check that passes at its first try never shows doubt', () {
    fakeAsync((async) {
      var changes = 0;
      final seen = <bool>[];
      late final StallWatch w;
      w = StallWatch(
        read: () async => readings.isEmpty ? null : readings.removeAt(0),
        probe: () async {
          probes++;
          // What a screen would read while the first try runs.
          seen.add(w.doubting);
          return true;
        },
        onStall: found.add,
        onChange: () => changes++,
        now: () => now.add(async.elapsed),
      )..start();
      readings = [(up: 4000, down: 0)];
      async.elapse(const Duration(minutes: 1));
      expect(probes, 1);
      expect(seen, [false]);
      expect(changes, 0);
      expect(w.doubting, isFalse);
      w.stop();
    });
  });

  test('with the built-in settings a trickle is never checked', () {
    fakeAsync((async) {
      final w = watch(async)..start();
      readings = [
        ...List.filled(5, (up: 20000, down: 500000)),
        (up: 20000, down: 20000),
      ];
      async.elapse(const Duration(minutes: 6));
      expect(probes, 0);
      w.stop();
    });
  });

  test('the number of checks and their gap come from the settings', () {
    fakeAsync((async) {
      final w = StallWatch(
        read: () async => readings.isEmpty ? null : readings.removeAt(0),
        probe: () async {
          probes++;
          return false;
        },
        onStall: found.add,
        settings: () => const StallWatchSettings(
          checks: 2,
          checkGap: Duration(seconds: 3),
          interval: Duration(seconds: 30),
        ),
        now: () => now.add(async.elapsed),
      )..start();
      readings = [(up: 4000, down: 0)];
      async.elapse(const Duration(seconds: 30));
      expect(probes, 1);
      async.elapse(const Duration(seconds: 3));
      expect(probes, 2);
      expect(found, hasLength(1));
      expect(found.single.probes, 2);
      w.stop();
    });
  });

  group('a download check', () {
    test('passes only when every byte came', () {
      expect(
        StallWatch.downloadPassed({'bytes': 65536, 'ms': 900}, 65536),
        isTrue,
      );
      expect(
        StallWatch.downloadPassed({'bytes': 9000, 'ms': 5000}, 65536),
        isFalse,
      );
    });

    test('fails with nothing measured', () {
      expect(StallWatch.downloadPassed(null, 65536), isFalse);
    });

    test('says nothing when the page itself refused', () {
      expect(
        StallWatch.downloadPassed({
          'bytes': 0,
          'ms': 300,
          'status': 403,
        }, 65536),
        isNull,
      );
    });
  });

  test('the median of an even and an odd list', () {
    expect(StallWatch.median([3, 1, 2]), 2);
    expect(StallWatch.median([4, 1, 3, 2]), 2.5);
  });
}
