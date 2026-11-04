import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/api/device_facts.dart';
import 'package:fortiva_vpn/api/device_identity.dart';
import 'package:fortiva_vpn/api/device_service.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/data/models/device.dart';
import 'package:fortiva_vpn/services/device_place.dart';
import 'package:fortiva_vpn/services/install_referrer.dart';
import 'package:fortiva_vpn/services/test_lab.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app already read the Play install referrer for the invite code and
/// threw the rest away. It now keeps the campaign parameters too, and
/// register sends them once.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InstallReferrer.parseSource', () {
    test("reads Play's organic referrer", () {
      expect(
        InstallReferrer.parseSource(
          'utm_source=google-play&utm_medium=organic',
        ),
        {'utm_source': 'google-play', 'utm_medium': 'organic'},
      );
    });

    test('reads the source our Telegram links send alone', () {
      expect(InstallReferrer.parseSource('utm_source=telegram_fa_release'), {
        'utm_source': 'telegram_fa_release',
      });
    });

    test('reads all three, next to the invite code and others', () {
      expect(
        InstallReferrer.parseSource(
          'ref=AB3D7K&utm_source=telegram&utm_medium=channel'
          '&utm_campaign=release_2_1&utm_term=x&gclid=abc',
        ),
        {
          'utm_source': 'telegram',
          'utm_medium': 'channel',
          'utm_campaign': 'release_2_1',
        },
      );
    });

    test('decodes percent encoding and plus signs', () {
      expect(
        InstallReferrer.parseSource(
          'utm_source=t.me%2Ffortiva_vpn&utm_campaign=spring+sale',
        ),
        {'utm_source': 't.me/fortiva_vpn', 'utm_campaign': 'spring sale'},
      );
    });

    test('keeps (not set) as it is', () {
      expect(
        InstallReferrer.parseSource(
          'utm_source=(not%20set)&utm_medium=(not set)',
        ),
        {'utm_source': '(not set)', 'utm_medium': '(not set)'},
      );
    });

    test('removes control characters and the spaces around the value', () {
      expect(
        InstallReferrer.parseSource(
          'utm_source=%01%20tele%0Agram%7F%20&utm_medium=%09organic%0D',
        ),
        {'utm_source': 'telegram', 'utm_medium': 'organic'},
      );
    });

    test('cuts a long value to 64', () {
      final source = InstallReferrer.parseSource('utm_source=${'a' * 300}');
      expect(source!['utm_source'], 'a' * InstallReferrer.maxSourceLength);
      expect(InstallReferrer.maxSourceLength, 64);
    });

    test('never cuts a character in half', () {
      // U+1F600 is two UTF-16 code units. With 63 letters before it, a cut
      // at 64 would keep only its first half.
      final value = '${'a' * 63}\u{1F600}b';
      expect(InstallReferrer.cleanSourceValue(value), 'a' * 63);
      final fits = '${'a' * 62}\u{1F600}b';
      expect(InstallReferrer.cleanSourceValue(fits), '${'a' * 62}\u{1F600}');
      // And through the parser, where it arrives percent encoded.
      final encoded = '${'a' * 63}${Uri.encodeQueryComponent('\u{1F600}')}';
      expect(InstallReferrer.parseSource('utm_source=$encoded'), {
        'utm_source': 'a' * 63,
      });
    });

    test('a value that is empty once cleaned is left out', () {
      expect(
        InstallReferrer.parseSource(
          'utm_source=&utm_medium=%20%20&utm_campaign=%01%02',
        ),
        isNull,
      );
      expect(InstallReferrer.parseSource('utm_source=&utm_medium=organic'), {
        'utm_medium': 'organic',
      });
    });

    test('returns null for nothing at all, or no source in it', () {
      expect(InstallReferrer.parseSource(null), isNull);
      expect(InstallReferrer.parseSource(''), isNull);
      expect(InstallReferrer.parseSource('ref=AB3D7K'), isNull);
      expect(InstallReferrer.parseSource('utm_source'), isNull);
      expect(InstallReferrer.parseSource('=telegram'), isNull);
    });

    test('a pair that is not valid encoding loses only itself', () {
      expect(InstallReferrer.parseSource('%%%not a query%%%'), isNull);
      expect(
        InstallReferrer.parseSource('utm_source=100%&utm_medium=organic'),
        {'utm_medium': 'organic'},
      );
    });

    test('the first usable value counts when a parameter comes twice', () {
      expect(
        InstallReferrer.parseSource(
          'utm_source=&utm_source=telegram&utm_source=other',
        ),
        {'utm_source': 'telegram'},
      );
    });
  });

  group('one read of Play for the code and the source', () {
    late int reads;
    late String? answer;

    setUp(() {
      reads = 0;
      answer = 'ref=AB3D7K&utm_source=telegram_fa_release';
      InstallReferrer.newRunForTest();
      InstallReferrer.androidOverride = true;
      InstallReferrer.readOverride = () async {
        reads++;
        return answer;
      };
      // Google Play installed this copy, unless a test says otherwise.
      InstallReferrer.fromPlayOverride = () async => true;
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      InstallReferrer.newRunForTest();
      InstallReferrer.androidOverride = null;
      InstallReferrer.readOverride = null;
      InstallReferrer.fromPlayOverride = null;
    });

    test('a copy Play did not install keeps no source, and still gives its '
        'code', () async {
      // The APK from the website or the channel, on a phone with the Play
      // Store: Play answers with its organic default.
      var asked = 0;
      InstallReferrer.fromPlayOverride = () async {
        asked++;
        return false;
      };
      answer = 'ref=AB3D7K&utm_source=google-play&utm_medium=organic';

      expect(await InstallReferrer.pendingSource(), isNull);
      expect(await InstallReferrer.pendingCode(), 'AB3D7K');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('fortiva_install_source'), isNull);
      expect(prefs.getBool('fortiva_install_source_read'), isTrue);

      // Not asked again on a later launch.
      InstallReferrer.newRunForTest();
      expect(await InstallReferrer.pendingSource(), isNull);
      expect((reads, asked), (1, 1));
    });

    test('a copy Play did not install does not wait for Play', () async {
      // Play is slow to answer or never does. The installer alone says there
      // is no source, so register has nothing to wait for.
      InstallReferrer.fromPlayOverride = null;
      PackageInfo.setMockInitialValues(
        appName: 'Fortiva',
        packageName: 'com.vpn.fortivavpn',
        version: '2.1.3',
        buildNumber: '80',
        buildSignature: '',
        installerStore: 'com.android.packageinstaller',
      );
      InstallReferrer.readOverride = () {
        reads++;
        return Completer<String?>().future;
      };

      expect(
        await InstallReferrer.pendingSource().timeout(
          const Duration(seconds: 10),
        ),
        isNull,
      );
      expect(reads, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('fortiva_install_source_read'), isTrue);
    });

    test('without an install time from Play, its organic default is not a '
        'source', () async {
      // The real check: Play gives an install time of 0 for a copy it did
      // not install, and the answer here carries none. The installer reads
      // as the Play Store, so only the install time can refuse it.
      InstallReferrer.fromPlayOverride = null;
      PackageInfo.setMockInitialValues(
        appName: 'Fortiva',
        packageName: 'com.vpn.fortivavpn',
        version: '2.1.3',
        buildNumber: '80',
        buildSignature: '',
        installerStore: 'com.android.vending',
      );
      answer = 'utm_source=google-play&utm_medium=organic';
      expect(await InstallReferrer.pendingSource(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('fortiva_install_source_read'), isTrue);
    });

    test('a fresh install gets both from one read', () async {
      expect(await InstallReferrer.pendingCode(), 'AB3D7K');
      expect(await InstallReferrer.pendingSource(), {
        'utm_source': 'telegram_fa_release',
      });
      expect(reads, 1);
    });

    test('callers at the same time share the one read', () async {
      final slow = Completer<String?>();
      InstallReferrer.readOverride = () {
        reads++;
        return slow.future;
      };
      final code = InstallReferrer.pendingCode();
      final source = InstallReferrer.pendingSource();
      final again = InstallReferrer.pendingSource();
      slow.complete('ref=AB3D7K&utm_source=google-play&utm_medium=organic');

      expect(await code, 'AB3D7K');
      expect(await source, {
        'utm_source': 'google-play',
        'utm_medium': 'organic',
      });
      expect(await again, await source);
      expect(reads, 1);
    });

    test('a phone updated from a build that only read the code reads the '
        'source once, and is not offered the code again', () async {
      // What an older build leaves: the code was read and its claim had an
      // answer, so nothing is pending.
      SharedPreferences.setMockInitialValues({
        'fortiva_install_referrer_read': true,
      });

      expect(await InstallReferrer.pendingCode(), isNull);
      expect(reads, 0);

      expect(await InstallReferrer.pendingSource(), {
        'utm_source': 'telegram_fa_release',
      });
      expect(reads, 1);
      expect(await InstallReferrer.pendingCode(), isNull);

      // A later launch does not ask Play again for either.
      InstallReferrer.newRunForTest();
      await InstallReferrer.sourceSent();
      expect(await InstallReferrer.pendingSource(), isNull);
      expect(await InstallReferrer.pendingCode(), isNull);
      expect(reads, 1);
    });

    test('the source is kept until it was sent, across launches', () async {
      expect(await InstallReferrer.pendingSource(), isNotNull);
      expect(await InstallReferrer.pendingCode(), 'AB3D7K');
      InstallReferrer.newRunForTest();
      answer = null;

      // Not sent yet: the kept source comes back without asking Play.
      expect(await InstallReferrer.pendingSource(), {
        'utm_source': 'telegram_fa_release',
      });
      expect(reads, 1);

      await InstallReferrer.sourceSent();
      expect(await InstallReferrer.pendingSource(), isNull);
      expect(reads, 1);
      // Sending the source leaves the code waiting for its claim.
      expect(await InstallReferrer.pendingCode(), 'AB3D7K');
      expect(reads, 1);
    });

    test('a referrer without a source is read once and gives null', () async {
      answer = 'utm_term=x';
      expect(await InstallReferrer.pendingSource(), isNull);
      InstallReferrer.newRunForTest();
      expect(await InstallReferrer.pendingSource(), isNull);
      expect(reads, 1);
    });

    test('Play failing is silent and is not asked again', () async {
      InstallReferrer.readOverride = () async {
        reads++;
        throw StateError('no Play Services');
      };
      expect(await InstallReferrer.pendingSource(), isNull);
      expect(await InstallReferrer.pendingCode(), isNull);
      InstallReferrer.newRunForTest();
      expect(await InstallReferrer.pendingSource(), isNull);
      expect(reads, 1);
    });

    test('off Android nothing is read or kept', () async {
      InstallReferrer.androidOverride = false;
      expect(await InstallReferrer.pendingSource(), isNull);
      expect(await InstallReferrer.pendingCode(), isNull);
      expect(reads, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });

    test('a kept source that is not ours counts as none', () async {
      SharedPreferences.setMockInitialValues({
        'fortiva_install_source_read': true,
        'fortiva_install_source': '{not json',
      });
      expect(await InstallReferrer.pendingSource(), isNull);
      SharedPreferences.setMockInitialValues({
        'fortiva_install_source_read': true,
        'fortiva_install_source': '{"utm_source": 3, "other": "x"}',
      });
      expect(await InstallReferrer.pendingSource(), isNull);
      expect(reads, 0);
    });

    test('reset clears both flags and both kept values', () async {
      SharedPreferences.setMockInitialValues({
        'fortiva_install_referrer_read': true,
        'fortiva_install_referrer_pending': 'AB3D7K',
        'fortiva_install_source_read': true,
        'fortiva_install_source': '{"utm_source":"telegram"}',
      });
      await InstallReferrer.reset();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);

      // So the next launch reads Play again for both.
      InstallReferrer.newRunForTest();
      expect(await InstallReferrer.pendingCode(), 'AB3D7K');
      expect(await InstallReferrer.pendingSource(), {
        'utm_source': 'telegram_fa_release',
      });
      expect(reads, 1);
    });
  });

  group('register', () {
    const channel = MethodChannel('test/install_source');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const organic = {'utm_source': 'google-play', 'utm_medium': 'organic'};

    late List<Map<String, dynamic>> bodies;
    late int sent;

    /// A backend that answers register with [answer] and [status], or cuts
    /// the call when [cut].
    DeviceService service({
      required Future<Map<String, String>?> Function() source,
      Future<void> Function()? sourceSent,
      int status = 200,
      String? answer,
      bool cut = false,
    }) {
      final client = ApiClient.forTest(
        direct: MockClient((request) async {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          if (cut) throw http.ClientException('cut');
          return http.Response(
            answer ??
                jsonEncode({
                  'id': 1,
                  'device_id': 'known-to-the-backend',
                  'platform': 'android',
                  'app_version': '2.1.3',
                  'created_at': '2026-10-23T00:00:00Z',
                }),
            status,
            headers: {'content-type': 'application/json'},
          );
        }),
        tunnelSocks: () async => null,
      );
      return DeviceService.forTest(
        client: client,
        place: DevicePlace(channel: channel),
        testLab: TestLab(channel: channel, android: false),
        facts: DeviceFacts(isAndroid: false),
        installSource: source,
        sourceSent: sourceSent ?? () async => sent++,
      );
    }

    setUp(() {
      bodies = [];
      sent = 0;
      // A stored id, so registering derives nothing from the platform.
      SharedPreferences.setMockInitialValues({
        DeviceIdentity.legacyPrefsKey: 'known-to-the-backend',
      });
      messenger.setMockMethodCallHandler(channel, (_) async => null);
    });
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test(
      'sends the kept source while sharing is on, then marks it sent',
      () async {
        await service(source: () async => organic).registerDevice();
        expect(bodies.single['utm_source'], 'google-play');
        expect(bodies.single['utm_medium'], 'organic');
        expect(bodies.single.containsKey('utm_campaign'), isFalse);
        expect(bodies.single['device_id'], 'known-to-the-backend');
        expect(sent, 1);
      },
    );

    test('sends all three as top-level keys when Play had them', () async {
      await service(
        source: () async => {
          'utm_source': 'telegram',
          'utm_medium': 'channel',
          'utm_campaign': 'release',
        },
      ).registerDevice();
      expect(bodies.single, containsPair('utm_source', 'telegram'));
      expect(bodies.single, containsPair('utm_medium', 'channel'));
      expect(bodies.single, containsPair('utm_campaign', 'release'));
    });

    test('sends no source while sharing is off, and keeps it', () async {
      SharedPreferences.setMockInitialValues({
        DeviceIdentity.legacyPrefsKey: 'known-to-the-backend',
        VpnEventReporter.sharePrefKey: false,
      });
      await service(source: () async => organic).registerDevice();
      expect(bodies.single.keys.where((k) => k.startsWith('utm_')), isEmpty);
      expect(bodies.single['device_id'], 'known-to-the-backend');
      expect(sent, 0);
    });

    test('without a source nothing is sent or marked', () async {
      await service(source: () async => null).registerDevice();
      await service(source: () async => const {}).registerDevice();
      for (final body in bodies) {
        expect(body.keys.where((k) => k.startsWith('utm_')), isEmpty);
      }
      expect(sent, 0);
    });

    test('a source can only add its own three keys', () async {
      await service(
        source: () async => {
          'utm_source': 'telegram',
          'device_id': 'someone-else',
          'utm_term': 'x',
        },
      ).registerDevice();
      expect(bodies.single['device_id'], 'known-to-the-backend');
      expect(bodies.single['utm_source'], 'telegram');
      expect(bodies.single.containsKey('utm_term'), isFalse);
    });

    test(
      'kept when register fails, on the network or at the backend',
      () async {
        await expectLater(
          service(source: () async => organic, cut: true).registerDevice(),
          throwsA(isA<ApiException>()),
        );
        await expectLater(
          service(
            source: () async => organic,
            status: 503,
            answer: '{"detail": "down"}',
          ).registerDevice(),
          throwsA(isA<ApiException>()),
        );
        expect(bodies, hasLength(2));
        expect(bodies.every((b) => b['utm_source'] == 'google-play'), isTrue);
        expect(sent, 0);
      },
    );

    test('kept when the answer is not a device', () async {
      await expectLater(
        service(source: () async => organic, answer: '[]').registerDevice(),
        throwsA(anything),
      );
      expect(bodies.single['utm_source'], 'google-play');
      expect(sent, 0);
    });

    test('a source that fails to clear does not fail the register', () async {
      final device = await service(
        source: () async => organic,
        sourceSent: () async => throw StateError('no preferences'),
      ).registerDevice();
      expect(device.deviceId, 'known-to-the-backend');
    });

    test('a register told not to wait neither asks for the source nor marks '
        'it sent', () async {
      var asked = 0;
      final devices = service(
        source: () {
          asked++;
          return Completer<Map<String, String>?>().future;
        },
      );
      await devices.registerDevice(waitForSource: false);
      expect(asked, 0);
      expect(bodies.single['device_id'], 'known-to-the-backend');
      expect(bodies.single.keys.where((k) => k.startsWith('utm_')), isEmpty);
      expect(sent, 0);
    });

    group('the register a connect can wait on', () {
      /// The servers the retry gets once the phone is registered.
      final servers = DedicatedConfigs(
        configs: const [],
        paths: const [],
        quota: QuotaStatus(
          unlimited: false,
          limitBytes: 100,
          usedBytes: 10,
          remainingBytes: 90,
          blocked: false,
        ),
      );

      test('recovers from an unknown device without waiting for the source, '
          'and the next register still carries it', () async {
        var asked = 0;
        Future<Map<String, String>?> stalled =
            Completer<Map<String, String>?>().future;
        final devices = service(
          source: () {
            asked++;
            return stalled;
          },
        );
        var provisions = 0;
        final state = DedicatedState(
          deviceService: devices,
          provision: (_, {bool? viaTunnel}) async {
            provisions++;
            if (provisions == 1) {
              throw ApiException(statusCode: 404, message: 'unknown device');
            }
            return servers;
          },
        );
        addTearDown(state.dispose);

        await state.refresh();

        expect(provisions, 2);
        expect(state.lastRefreshErred, isFalse);
        expect(asked, 0);
        expect(bodies.single.keys.where((k) => k.startsWith('utm_')), isEmpty);
        expect(sent, 0);

        stalled = Future.value(organic);
        await devices.registerDevice();
        expect(bodies.last['utm_source'], 'google-play');
        expect(sent, 1);
      });
    });

    test('a slow source read does not hold register past the wait', () async {
      expect(DeviceService.sourceWait, const Duration(seconds: 2));
      // Found before the fake clock runs, because finding the id asks the
      // platform's secure storage, which only answers on the real clock.
      await DeviceIdentity.instance.resolve();
      PackageInfo.setMockInitialValues(
        appName: 'Fortiva',
        packageName: 'com.vpn.fortivavpn',
        version: '2.1.3',
        buildNumber: '80',
        buildSignature: '',
      );

      fakeAsync((async) {
        // Everything register waits on is made inside the fake zone, so the
        // fake clock drives it.
        SharedPreferences.setMockInitialValues({
          DeviceIdentity.legacyPrefsKey: 'known-to-the-backend',
        });
        final stalled = Completer<Map<String, String>?>();
        final devices = service(source: () => stalled.future);

        Device? device;
        devices.registerDevice().then((d) => device = d);
        async.elapse(
          DeviceService.sourceWait - const Duration(milliseconds: 1),
        );
        expect(device, isNull);
        expect(bodies, isEmpty);
        async.elapse(const Duration(milliseconds: 1));
        expect(device, isNotNull);
        expect(bodies.single.keys.where((k) => k.startsWith('utm_')), isEmpty);
        expect(sent, 0);

        // The read finishes later, and the next register sends what it
        // found (InstallReferrer keeps it).
        stalled.complete(organic);
        devices.registerDevice();
        async.flushMicrotasks();
        expect(bodies.last['utm_source'], 'google-play');
        expect(sent, 1);
      });
    });

    test(
      'with InstallReferrer, Play is read once and the source sent once',
      () async {
        var reads = 0;
        InstallReferrer.newRunForTest();
        InstallReferrer.androidOverride = true;
        InstallReferrer.readOverride = () async {
          reads++;
          return 'utm_source=google-play&utm_medium=organic';
        };
        InstallReferrer.fromPlayOverride = () async => true;
        addTearDown(() {
          InstallReferrer.newRunForTest();
          InstallReferrer.androidOverride = null;
          InstallReferrer.readOverride = null;
          InstallReferrer.fromPlayOverride = null;
        });
        final devices = service(
          source: InstallReferrer.pendingSource,
          sourceSent: InstallReferrer.sourceSent,
        );

        await devices.registerDevice();
        await devices.registerDevice();

        expect(bodies.first['utm_source'], 'google-play');
        expect(bodies.first['utm_medium'], 'organic');
        expect(bodies.last.keys.where((k) => k.startsWith('utm_')), isEmpty);
        expect(reads, 1);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('fortiva_install_source'), isNull);
        expect(prefs.getBool('fortiva_install_source_read'), isTrue);
      },
    );
  });
}
