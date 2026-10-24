import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/ping_service.dart';
import 'package:fortiva_vpn/utils/tls_fragment.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every native door test carries the app's split as `splitter`, for every
/// link and not only the TLS ones. On Android each test builds its own core,
/// but the cores share one dialer, and a TLS test looks its "fragment"
/// splitter up in the core created last. Until 2026-10-12 a Reality test's
/// core had none, so a TLS test beside it failed with "io: read/write on
/// closed pipe". Android adds the splitter to every test's core from this
/// argument (TestLink.config).
const _reality =
    'vless://b831381d-6324-4d53-ad4f-8cda48b30811@1.2.3.4:443'
    '?type=tcp&security=reality&pbk=abc&sni=www.example.com&fp=chrome#r';
const _tls =
    'vless://b831381d-6324-4d53-ad4f-8cda48b30811@198.51.100.215:443'
    '?type=ws&security=tls&sni=cdn.example.site&fp=chrome#t';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    TlsFragment.spec = TlsFragment.builtIn;
    TlsFragment.doorSpec = null;
    SharedPreferences.setMockInitialValues({});
    calls = [];
    messenger.setMockMethodCallHandler(tunnel, (call) async {
      calls.add(call);
      return call.method == 'realPing' ? 180 : {'ms': 180};
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(tunnel, null);
    TlsFragment.spec = TlsFragment.builtIn;
    TlsFragment.doorSpec = null;
  });

  Map<Object?, Object?> args(MethodCall call) =>
      call.arguments as Map<Object?, Object?>;

  test('a Reality door check carries the app split', () async {
    await PingService().readDoor(Server.fromConnectionUri(_reality));
    final sent = args(calls.single);
    expect(calls.single.method, 'realPingDetail');
    expect(sent['splitter'], TlsFragment.builtIn);
    expect(sent['link'] as String, isNot(contains('fragment=')));
  });

  test('a TLS door check carries it too', () async {
    await PingService().checkDoor(Server.fromConnectionUri(_tls));
    expect(args(calls.single)['splitter'], TlsFragment.builtIn);
  });

  test('the server list and the candidate prober send it', () async {
    await PingService().pingServer(Server.fromConnectionUri(_reality));
    await PingService().pingServer(
      Server.fromConnectionUri(_tls),
      coreTimeout: const Duration(seconds: 8),
    );
    expect(calls.map((c) => c.method), ['realPing', 'realPing']);
    for (final c in calls) {
      expect(args(c)['splitter'], TlsFragment.builtIn);
    }
  });

  test('the split the backend sent is the one sent', () async {
    TlsFragment.spec = 'tlshello,5-9,3-4';
    await PingService().readDoor(Server.fromConnectionUri(_reality));
    expect(args(calls.single)['splitter'], 'tlshello,5-9,3-4');
  });

  test('with the split off, the spec sent is empty', () async {
    // Android reads an empty spec as no splitter, as before.
    TlsFragment.spec = '';
    await PingService().readDoor(Server.fromConnectionUri(_reality));
    expect(args(calls.single)['splitter'], '');
  });

  test('a test point variant keeps its own split in the link', () async {
    final variant = TlsFragment.withSpec(_tls, 'tlshello,100-200,10-20');
    await PingService().readDoor(Server.fromConnectionUri(variant));
    final sent = args(calls.single);
    expect(sent['link'] as String, contains('fragment=tlshello,100-200,10-20'));
    expect(sent['splitter'], TlsFragment.builtIn);
  });

  group('on a phone whose TLS doors carry a split of their own', () {
    // The backend's door experiments write the test arm's split into the
    // phone's -tls door links (door_experiments.apply). A TLS door test
    // retries through the splitter of the newest core, so every core must
    // hold the split that door's tunnel dials with. On 2026-10-12 a door
    // whose own split was reset read open beside a Reality test carrying
    // the app's split, and closed beside one carrying its own.
    const arm = 'tlshello,200-400,1-2';

    Future<DedicatedState> phone(String? fragment) async {
      final tls = fragment == null
          ? _tls
          : _tls.replaceFirst('#', '&fragment=$fragment#');
      final state = DedicatedState();
      await state.adoptForTest(
        [_reality],
        [
          DedicatedPath(
            serverId: 7,
            inboundId: 1,
            door: 'tcp-reality',
            label: 'Reality',
            uri: _reality,
          ),
          DedicatedPath(
            serverId: 7,
            inboundId: 2,
            door: 'ws-tls',
            label: 'TLS over WebSocket',
            uri: tls,
          ),
        ],
      );
      return state;
    }

    Server door(DedicatedState state, String name) =>
        state.paths.firstWhere((p) => p.door == name);

    test('a Reality door check sends the arm split', () async {
      final state = await phone(arm);
      await PingService().readDoor(door(state, 'tcp-reality'));
      final sent = args(calls.single);
      expect(sent['splitter'], arm);
      expect(sent['link'] as String, isNot(contains('fragment=')));
    });

    test('the TLS door check sends it too, and keeps it in its link', () async {
      final state = await phone(arm);
      await PingService().checkDoor(door(state, 'ws-tls'));
      final sent = args(calls.single);
      expect(sent['splitter'], arm);
      expect(sent['link'] as String, contains('fragment=$arm'));
    });

    test('a shared link check beside them sends it as well', () async {
      await phone(arm);
      await PingService().pingServer(Server.fromConnectionUri(_reality));
      expect(args(calls.single)['splitter'], arm);
    });

    test('with the app split off, a Reality check still gets one', () async {
      TlsFragment.spec = '';
      final state = await phone(arm);
      await PingService().readDoor(door(state, 'tcp-reality'));
      expect(args(calls.single)['splitter'], arm);
    });

    test(
      'a control phone, or an off, ech or ff arm, sends the app split',
      () async {
        for (final fragment in [null, 'off']) {
          calls.clear();
          final state = await phone(fragment);
          expect(TlsFragment.doorSpec, isNull, reason: '$fragment');
          await PingService().readDoor(door(state, 'tcp-reality'));
          expect(args(calls.single)['splitter'], TlsFragment.builtIn);
        }
      },
    );

    test('a split the core would refuse is not sent', () async {
      for (final fragment in ['tlshello,0-20,1-2', 'tlshello,20-0,1-2', 'x']) {
        calls.clear();
        final state = await phone(fragment);
        expect(TlsFragment.doorSpec, isNull, reason: fragment);
        await PingService().readDoor(door(state, 'tcp-reality'));
        expect(args(calls.single)['splitter'], TlsFragment.builtIn);
      }
    });

    test('a fragment on a door that is not -tls is not read', () async {
      final state = DedicatedState();
      await state.adoptForTest(
        [_reality],
        [
          DedicatedPath(
            serverId: 7,
            inboundId: 1,
            door: 'tcp-reality',
            label: 'Reality',
            uri: _reality.replaceFirst('#', '&fragment=$arm#'),
          ),
        ],
      );
      expect(TlsFragment.doorSpec, isNull);
    });

    test('the next answer without a split, or a reset, drops it', () async {
      final state = await phone(arm);
      expect(TlsFragment.doorSpec, arm);
      await state.adoptForTest([_reality], const []);
      expect(TlsFragment.doorSpec, isNull);

      final again = await phone(arm);
      expect(TlsFragment.doorSpec, arm);
      again.reset();
      expect(TlsFragment.doorSpec, isNull);
      await PingService().readDoor(Server.fromConnectionUri(_reality));
      expect(args(calls.single)['splitter'], TlsFragment.builtIn);
    });
  });

  test('every native door test in lib goes through PingService', () {
    // A test sent from anywhere else would build a core with no splitter.
    // windows_tunnel.dart only forwards the call to the Windows service.
    final senders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final text = f.readAsStringSync();
      if (text.contains("'realPing") || text.contains('"realPing')) {
        senders.add(f.path.replaceAll(r'\', '/'));
      }
    }
    expect(senders..sort(), [
      'lib/services/ping_service.dart',
      'lib/services/windows_tunnel.dart',
    ]);
  });
}
