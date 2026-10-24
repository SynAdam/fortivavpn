import 'dart:async';
import 'dart:ui';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/services/device_place.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the app tells the backend about where the phone is. The backend
/// trusts these before the address a call arrives from, because the address
/// is another VPN's whenever one is on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/place');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) async => handler(call));
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('sends the readings the backend uses and nothing else', () async {
    answer((call) {
      expect(call.method, 'place');
      return {
        'network_country': 'ir',
        'sim_country': 'ir',
        'roaming': false,
        'time_zone': 'Asia/Tehran',
        'other_vpn': true,
        // Not something the backend asked for, so it stays on the phone.
        'device': 'Pixel 7',
      };
    });

    expect(await DevicePlace(channel: channel).read(), {
      'network_country': 'ir',
      'sim_country': 'ir',
      'roaming': false,
      'time_zone': 'Asia/Tehran',
      'other_vpn': true,
    });
  });

  test('leaves out what the platform could not read', () async {
    // iOS: no cell or SIM country, and no VPN answer while ours is up.
    answer(
      (_) => {
        'network_country': null,
        'sim_country': '',
        'time_zone': 'Asia/Baku',
      },
    );

    expect(await DevicePlace(channel: channel).read(), {
      'time_zone': 'Asia/Baku',
    });
  });

  test('sends nothing when the user turned diagnostics off', () async {
    SharedPreferences.setMockInitialValues({
      VpnEventReporter.sharePrefKey: false,
    });
    var asked = false;
    answer((_) {
      asked = true;
      return {'time_zone': 'Asia/Tehran'};
    });

    expect(await DevicePlace(channel: channel).read(), isNull);
    expect(asked, isFalse);
  });

  test('a platform without the call, or one that fails, gives null', () async {
    expect(await DevicePlace(channel: channel).read(), isNull);

    answer((_) => throw PlatformException(code: 'boom'));
    expect(await DevicePlace(channel: channel).read(), isNull);

    answer((_) => <String, Object?>{});
    expect(await DevicePlace(channel: channel).read(), isNull);
  });

  // The SIM country picks the language offered on the first launch. It is
  // read on the phone and never sent, so the diagnostics switch, which is
  // about what goes to the backend, does not apply to it.
  group('simCountry', () {
    test('reads the SIM country', () async {
      answer((call) {
        expect(call.method, 'place');
        return {'sim_country': 'ir', 'network_country': 'tr'};
      });

      expect(await DevicePlace(channel: channel).simCountry(), 'ir');
    });

    test('works with diagnostics off', () async {
      SharedPreferences.setMockInitialValues({
        VpnEventReporter.sharePrefKey: false,
      });
      var asked = false;
      answer((_) {
        asked = true;
        return {'sim_country': 'ir'};
      });

      expect(await DevicePlace(channel: channel).simCountry(), 'ir');
      expect(asked, isTrue);
    });

    test('trims the code', () async {
      answer((_) => {'sim_country': ' ir \n'});
      expect(await DevicePlace(channel: channel).simCountry(), 'ir');
    });

    test('is null when the SIM country is empty or missing', () async {
      final place = DevicePlace(channel: channel);

      answer((_) => {'sim_country': ''});
      expect(await place.simCountry(), isNull);

      answer((_) => {'sim_country': '   '});
      expect(await place.simCountry(), isNull);

      answer((_) => {'sim_country': null, 'time_zone': 'Asia/Tehran'});
      expect(await place.simCountry(), isNull);

      // Windows answers with the time zone alone.
      answer((_) => {'time_zone': 'Asia/Tehran'});
      expect(await place.simCountry(), isNull);

      answer((_) => null);
      expect(await place.simCountry(), isNull);
    });

    test('is null when the platform throws', () async {
      answer((_) => throw PlatformException(code: 'boom'));
      expect(await DevicePlace(channel: channel).simCountry(), isNull);
    });

    test('is null when nothing answers the call', () async {
      expect(await DevicePlace(channel: channel).simCountry(), isNull);
    });

    test('gives up after the timeout', () {
      // The first-run splash waits for this read, so a platform that never
      // answers must cost no more than DevicePlace.timeout.
      fakeAsync((async) {
        final stalled = Completer<Object?>();
        messenger.setMockMethodCallHandler(channel, (_) => stalled.future);

        var done = false;
        String? sim = 'unset';
        DevicePlace(channel: channel).simCountry().then((v) {
          sim = v;
          done = true;
        });

        async.elapse(DevicePlace.timeout - const Duration(milliseconds: 1));
        expect(done, isFalse);
        async.elapse(const Duration(milliseconds: 1));
        expect(done, isTrue);
        expect(sim, isNull);
      });
    });
  });

  group('LocaleState with the SIM country', () {
    // Counts the backend lookups. The real lookup waits up to 10 seconds
    // for /api/v1/info/me, so a lookup made when it is not needed holds
    // the first-run splash for that long.
    late int lookups;
    late String? backendAnswer;

    Future<String?> backendCountry() async {
      lookups++;
      return backendAnswer;
    }

    setUp(() {
      lookups = 0;
      backendAnswer = null;
    });

    LocaleState stateWithSim() => LocaleState(
      place: DevicePlace(channel: channel),
      backendCountry: backendCountry,
    );

    test('an Iranian SIM on an English phone set to the US offers Persian '
        'without asking the backend', () async {
      answer((_) => {'sim_country': 'ir'});

      expect(
        await stateWithSim().suggestedLanguage(
          deviceLocale: const Locale('en', 'US'),
        ),
        'fa',
      );
      expect(lookups, 0);
    });

    test(
      'asks the backend when neither the SIM nor the region answers',
      () async {
        answer((_) => {'sim_country': 'us'});
        backendAnswer = 'IR';

        expect(
          await stateWithSim().suggestedLanguage(
            deviceLocale: const Locale('en', 'US'),
          ),
          'fa',
        );
        expect(lookups, 1);
      },
    );

    test('a Persian phone with a Turkish SIM keeps Persian', () async {
      answer((_) => {'sim_country': 'tr'});

      expect(
        await stateWithSim().suggestedLanguage(
          deviceLocale: const Locale('fa', 'IR'),
        ),
        'fa',
      );
      expect(lookups, 0);
    });

    test('a SIM read that never answers still lets the region decide', () {
      // The phone region answers, so no backend lookup is made, and the
      // whole suggestion takes no longer than the SIM read's timeout.
      fakeAsync((async) {
        final stalled = Completer<Object?>();
        messenger.setMockMethodCallHandler(channel, (_) => stalled.future);

        String? suggested;
        stateWithSim()
            .suggestedLanguage(deviceLocale: const Locale('en', 'TR'))
            .then((v) => suggested = v);

        async.elapse(DevicePlace.timeout);
        expect(suggested, 'tr');
        expect(lookups, 0);
      });
    });
  });
}
