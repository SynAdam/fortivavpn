import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_routes.dart';
import 'package:fortiva_vpn/api/bootstrap.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config_state_test.dart' show configWith;
import 'bootstrap_file_test.dart' show payload, seal, sealKey, seed;

/// A fresh fallback file from the backend while it answers (#267, item E).
/// The hosts are read only when the backend cannot be reached, so before
/// this a phone that always reached it held nothing newer than the copy
/// built into its release when a cut came.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<int> publicKey;
  late DateTime clock;
  late int asks;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ApiRelays.resetForTest();
    clock = DateTime.utc(2026, 10, 16, 12);
    asks = 0;
    final pair = await Ed25519().newKeyPairFromSeed(seed);
    publicKey = (await pair.extractPublicKey()).bytes;
  });

  int at(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

  Bootstrap bootstrap({String? built}) => Bootstrap(
    tunnel: () async => null,
    builtIn: const [],
    publicKey: publicKey,
    sealKey: sealKey,
    now: () => clock,
    seed: () async => built,
  );

  Future<String?> Function() backend(String? text) => () async {
    asks++;
    return text;
  };

  test('a phone holding only an old file takes the backend\'s', () async {
    final old = await seal(
      payload(issuedAt: at(clock.subtract(const Duration(days: 20)))),
    );
    final b = bootstrap(built: old);
    final fresh = await seal(
      payload(
        issuedAt: at(clock.subtract(const Duration(minutes: 5))),
        links: const ['vless://new@198.51.100.9:443#n'],
      ),
    );

    expect(await b.refreshFromBackend(backend(fresh)), isTrue);
    expect(b.file?.links, ['vless://new@198.51.100.9:443#n']);
    // Kept for the next launch, and fresh enough to hand to a friend.
    final saved = (await SharedPreferences.getInstance()).getString(
      Bootstrap.savedKey,
    );
    expect(saved, fresh);
    expect(b.shareable, isNotNull);
  });

  test('a phone with no file at all takes one too', () async {
    final b = bootstrap();
    final fresh = await seal(payload(issuedAt: at(clock)));
    expect(await b.refreshFromBackend(backend(fresh)), isTrue);
    expect(b.file, isNotNull);
  });

  test('a file built lately is not asked for again', () async {
    final recent = await seal(
      payload(issuedAt: at(clock.subtract(const Duration(hours: 2)))),
    );
    final b = bootstrap(built: recent);
    expect(await b.refreshFromBackend(backend('x')), isFalse);
    expect(asks, 0);
  });

  test('the backend is asked at most once in a while', () async {
    final b = bootstrap();
    expect(await b.refreshFromBackend(backend(null)), isFalse);
    expect(await b.refreshFromBackend(backend(null)), isFalse);
    expect(asks, 1);
    clock = clock.add(Bootstrap.refreshAfter);
    await b.refreshFromBackend(backend(null));
    expect(asks, 2);
  });

  test('an older file than the one held is not kept', () async {
    final held = await seal(
      payload(issuedAt: at(clock.subtract(const Duration(hours: 13)))),
    );
    final b = bootstrap(built: held);
    final older = await seal(
      payload(issuedAt: at(clock.subtract(const Duration(days: 3)))),
    );
    expect(await b.refreshFromBackend(backend(older)), isFalse);
    expect(b.file?.text, held);
  });

  test('anything not signed by us is refused', () async {
    final b = bootstrap();
    final forged = await seal(
      payload(issuedAt: at(clock)),
      signWith: List<int>.generate(32, (i) => 200 - i),
    );
    expect(await b.refreshFromBackend(backend(forged)), isFalse);
    expect(await b.refreshFromBackend(backend('not a file')), isFalse);
    expect(b.file, isNull);
  });

  test('a backend that fails costs nothing but the try', () async {
    final b = bootstrap();
    expect(
      await b.refreshFromBackend(() async => throw StateError('404')),
      isFalse,
    );
    expect(b.file, isNull);
  });

  test('a phone whose clock runs ahead of the file asks', () async {
    // The file says it was built in the future: the clock is behind, and
    // its age says nothing, so the backend is asked.
    final ahead = await seal(
      payload(issuedAt: at(clock.add(const Duration(hours: 2)))),
    );
    final b = bootstrap(built: ahead);
    await b.refreshFromBackend(backend(null));
    expect(asks, 1);
  });

  test('a config that loads asks the backend for the file', () async {
    final b = bootstrap();
    final fresh = await seal(payload(issuedAt: at(clock)));
    final state = AppConfigState(
      fetch: () async => configWith(''),
      fallbackFile: backend(fresh),
      bootstrap: b,
      retryGaps: const [],
    );
    await state.load();
    await pumpEventQueue();

    expect(asks, 1);
    expect(b.file?.text, fresh);
  });

  test('a config that does not load asks nothing', () async {
    final b = bootstrap();
    final state = AppConfigState(
      fetch: () async => throw StateError('unreachable'),
      fallbackFile: backend('x'),
      bootstrap: b,
      retryGaps: const [],
    );
    await state.load();
    await pumpEventQueue();

    expect(asks, 0);
  });
}
