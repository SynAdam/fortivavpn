import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/services/report_schedule.dart';

// A phone's door checks once waited on it for hours: nothing tried them
// again between cold starts, and nothing tried when the phone changed
// network.
void main() {
  late int flushes;
  late StreamController<Object?> network;

  Future<void> flush() async => flushes++;

  setUp(() {
    flushes = 0;
    network = StreamController<Object?>.broadcast();
  });

  ReportSchedule schedule() =>
      ReportSchedule(flush: flush, networkChanges: network.stream);

  test('tries at once, then on a timer while in the foreground', () {
    fakeAsync((async) {
      final s = schedule()..start();
      async.flushMicrotasks();
      expect(flushes, 1);
      async.elapse(ReportSchedule.defaultInterval);
      expect(flushes, 2);
      async.elapse(ReportSchedule.defaultInterval * 2);
      expect(flushes, 4);
      s.dispose();
    });
  });

  test('stops the timer in the background, and tries again on resume', () {
    fakeAsync((async) {
      final s = schedule()..start();
      async.flushMicrotasks();
      s.background();
      async.elapse(ReportSchedule.defaultInterval * 3);
      expect(flushes, 1);
      s.foreground();
      async.flushMicrotasks();
      expect(flushes, 2);
      async.elapse(ReportSchedule.defaultInterval);
      expect(flushes, 3);
      s.dispose();
    });
  });

  test('a burst of network changes makes one try, after it settles', () {
    fakeAsync((async) {
      final s = schedule()..start();
      s.background();
      async.flushMicrotasks();
      expect(flushes, 1);
      network
        ..add('wifi')
        ..add('none')
        ..add('mobile');
      async.flushMicrotasks();
      expect(flushes, 1);
      async.elapse(ReportSchedule.defaultSettle);
      // Also in the background: the next network may carry what the last
      // one cut.
      expect(flushes, 2);
      s.dispose();
    });
  });

  test('a flush that throws does not stop the schedule', () {
    fakeAsync((async) {
      var calls = 0;
      final s = ReportSchedule(
        flush: () async {
          calls++;
          throw Exception('no route');
        },
        networkChanges: network.stream,
      )..start();
      async.elapse(ReportSchedule.defaultInterval);
      expect(calls, 2);
      s.dispose();
    });
  });

  test('nothing runs after dispose', () {
    fakeAsync((async) {
      final s = schedule()..start();
      async.flushMicrotasks();
      s.dispose();
      network.add('wifi');
      async.elapse(ReportSchedule.defaultInterval * 2);
      expect(flushes, 1);
    });
  });
}
