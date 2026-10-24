import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/services/door_refresh.dart';

void main() {
  test('fetches the servers again every interval while a tunnel is up', () {
    fakeAsync((time) {
      var calls = 0;
      final refresh = DoorRefresh(refresh: () async => calls++);

      refresh.connected();
      time.elapse(const Duration(minutes: 44));
      expect(calls, 0);
      time.elapse(const Duration(minutes: 1));
      expect(calls, 1);
      time.elapse(const Duration(minutes: 90));
      expect(calls, 3);
      refresh.dispose();
    });
  });

  test(
    'stops when the tunnel goes down, and a second connect starts one timer',
    () {
      fakeAsync((time) {
        var calls = 0;
        final refresh = DoorRefresh(refresh: () async => calls++);

        refresh.connected();
        refresh.connected();
        time.elapse(const Duration(minutes: 45));
        expect(calls, 1);
        refresh.disconnected();
        expect(refresh.active, isFalse);
        time.elapse(const Duration(hours: 3));
        expect(calls, 1);
      });
    },
  );

  test('a fetch that has not answered is not stacked under the next tick', () {
    fakeAsync((time) {
      var calls = 0;
      final answer = Completer<void>();
      final refresh = DoorRefresh(
        refresh: () {
          calls++;
          return answer.future;
        },
        interval: const Duration(minutes: 1),
      );

      refresh.connected();
      time.elapse(const Duration(minutes: 5));
      expect(calls, 1);
      answer.complete();
      time.elapse(const Duration(minutes: 1));
      expect(calls, 2);
      refresh.dispose();
    });
  });

  test('a failed fetch is logged and the timer goes on', () {
    fakeAsync((time) {
      var calls = 0;
      final refresh = DoorRefresh(
        refresh: () async {
          calls++;
          throw StateError('no route to the API');
        },
      );

      refresh.connected();
      time.elapse(const Duration(minutes: 90));
      expect(calls, 2);
      expect(refresh.active, isTrue);
      refresh.dispose();
    });
  });
}
