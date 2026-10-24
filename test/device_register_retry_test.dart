import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/core/state/device_state.dart';
import 'package:fortiva_vpn/data/models/device.dart';

// A phone whose network cut part of our calls lost its register call and
// the two the provisioning retry made, and the backend never heard of it
// for an hour. Some of its calls were getting through, so trying again was
// all it needed.

final _device = Device(
  id: 760,
  deviceId: 'DEV-1',
  platform: 'android',
  appVersion: '1.6.11',
  isPremium: false,
  createdAt: DateTime.utc(2026, 10, 6, 6, 3),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const gap = Duration(milliseconds: 20);

  Future<void> waitFor(bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('a register that fails is tried again until it works', () async {
    var calls = 0;
    var told = 0;
    final state = DeviceState(
      register: () async {
        calls++;
        if (calls < 3) {
          throw ApiException(statusCode: 0, message: 'No internet connection');
        }
        return _device;
      },
      retryGaps: const [gap],
    )..onRegistered = () => told++;

    await state.registerDevice();
    expect(state.isRegistered, isFalse);

    await waitFor(() => state.isRegistered);
    expect(calls, 3);
    expect(state.isRegistered, isTrue);
    expect(state.device?.id, 760);
    expect(told, 1);

    // Registered, so nothing more is scheduled.
    await Future<void>.delayed(gap * 3);
    expect(calls, 3);
    state.dispose();
  });

  test('a register that works first time tells the app once', () async {
    var told = 0;
    final state = DeviceState(
      register: () async => _device,
      retryGaps: const [gap],
    )..onRegistered = () => told++;
    await state.registerDevice();
    await Future<void>.delayed(gap * 3);
    expect(told, 1);
    state.dispose();
  });

  test('the gaps grow and the last one repeats', () async {
    final at = <DateTime>[];
    final state = DeviceState(
      register: () async {
        at.add(DateTime.now());
        throw Exception('cut');
      },
      retryGaps: const [gap, Duration(milliseconds: 60)],
    );
    await state.registerDevice();
    await waitFor(() => at.length >= 4);
    state.dispose();
    expect(at.length, greaterThanOrEqualTo(4));
    final gaps = [
      for (var i = 1; i < 4; i++) at[i].difference(at[i - 1]).inMilliseconds,
    ];
    // Only lower bounds, with room for timer rounding: a slow runner fires
    // late, never this early.
    expect(gaps[0], greaterThanOrEqualTo(15));
    expect(gaps[1], greaterThanOrEqualTo(50));
    expect(gaps[2], greaterThanOrEqualTo(50));
  });

  test(
    'a register still in flight when the state is disposed ends quietly',
    () async {
      final release = Completer<void>();
      var calls = 0;
      final state = DeviceState(
        register: () async {
          calls++;
          await release.future;
          throw Exception('cut');
        },
        retryGaps: const [gap],
      );
      final inFlight = state.registerDevice();
      state.dispose();
      release.complete();
      // Would throw "used after being disposed" from notifyListeners.
      await inFlight;
      await Future<void>.delayed(gap * 3);
      expect(calls, 1);
    },
  );

  test('a reset stops the retries', () async {
    var calls = 0;
    final state = DeviceState(
      register: () async {
        calls++;
        throw Exception('cut');
      },
      retryGaps: const [gap],
    );
    await state.registerDevice();
    state.reset();
    await Future<void>.delayed(gap * 4);
    expect(calls, 1);
    state.dispose();
  });
}
