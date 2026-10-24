import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/connection_info.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/my_servers_screen.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/variant_tests.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Variant tests change nothing on screen. An answer that carries them
/// shows the same servers as the same answer without them, while the
/// tests run in the background, and no variant ever appears as something
/// to pick.

const _door =
    'vless://b831381d-6324-4d53-ad4f-8cda48b30811@203.0.113.7:8443'
    '?type=xhttp&security=reality&sni=www.samsung.com&pbk=key#Nuremberg';

const _variant =
    'vless://b831381d-6324-4d53-ad4f-8cda48b30811@203.0.113.7:8443'
    '?type=xhttp&security=reality&sni=www.samsung.com&pbk=key&fp=chrome'
    '&mode=packet-up#VariantUnderTest';

final _now = DateTime.utc(2026, 10, 18, 9);

Map<String, dynamic> _answer({bool withTests = false}) => {
  'configs': [_door],
  'paths': [
    {
      'server_id': 13,
      'inbound_id': 2,
      'door': 'xhttp-reality',
      'label': 'Reality over XHTTP',
      'uri': _door,
      'preferred': true,
    },
  ],
  'quota': {
    'unlimited': false,
    'limit_bytes': 100,
    'used_bytes': 10,
    'remaining_bytes': 90,
    'blocked': false,
  },
  'google': {'linked': false},
  if (withTests) ...{
    'variant_tests': [
      {
        'assignment_id': 41,
        'variant_key': 'xhttp-reality#v=a3f1c2d0e5b4',
        'server_id': 13,
        'door': 'xhttp-reality',
        'uri': _variant,
        'deadline': _now.add(const Duration(hours: 2)).toIso8601String(),
        'config': {
          'outbounds': [
            {
              'tag': 'proxy',
              'protocol': 'vless',
              'settings': {
                'vnext': [
                  {'address': '203.0.113.7', 'port': 8443},
                ],
              },
            },
          ],
        },
      },
    ],
    'variant_test_params': {
      'test_url': 'https://cp.cloudflare.com/generate_204',
      'timeout_ms': 4000,
      'max_per_run': 8,
      'min_gap_minutes': 0,
      'only_when_tunnel_down': true,
    },
  },
};

class _FakeServers extends ServerState {
  @override
  List<Server> get communityServers => const [];

  @override
  bool get isLoading => false;

  @override
  Future<void> loadServers({bool forceRefresh = false}) async {}

  @override
  Future<void> refreshServers() async {}
}

class _FakeVpn extends VpnService {
  @override
  VpnStatus get status => VpnStatus.disconnected;

  @override
  bool get isConnected => false;

  @override
  bool get isConnecting => false;

  @override
  bool get isVerifying => false;

  @override
  ConnectionInfo? get currentConnection => null;
}

void main() {
  const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
  const statusChannel = EventChannel('com.vpn.fortivavpn/tunnel/status');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(tunnel, (call) async {
      return call.method == 'getStatus' ? 'disconnected' : null;
    });
    messenger.setMockStreamHandler(
      statusChannel,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(tunnel, null);
    messenger.setMockStreamHandler(statusChannel, null);
  });

  /// Your servers on [body], with a variant tester attached as the app
  /// attaches it. Returns every text on screen, the links checked and the
  /// reports sent.
  Future<({List<String> texts, List<String> checked, int reports})> show(
    WidgetTester tester,
    Map<String, dynamic> body,
  ) async {
    final dedicated = DedicatedState(
      now: () => _now,
      fetch: ({bool? viaTunnel}) async => DedicatedConfigs.fromJson(body),
    );
    final vpn = _FakeVpn();
    final checked = <String>[];
    var reports = 0;
    final variants = VariantTester(
      dedicated,
      idle: () => !vpn.isConnecting,
      tunnelUp: () => vpn.isConnected,
      throughTunnel: () => false,
      check: (dial) async {
        checked.add(dial.test.uri);
        return const DoorOutcome(ms: 230, phase: 'ok');
      },
      internet: () async => true,
      send: (_, _, _) async => reports++,
      clock: () => _now,
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.12.0',
      networkType: () async => 'mobile',
      carrier: () async => 'IR-MCI',
      checksRunning: () => 0,
      checksStarted: () => checked.length,
    );
    addTearDown(variants.dispose);

    // A fresh screen for each answer, which asks for its servers again.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(value: dedicated),
          ChangeNotifierProvider<ServerState>(create: (_) => _FakeServers()),
          ChangeNotifierProvider<VpnService>.value(value: vpn),
          ChangeNotifierProvider<ConnectFlow>(
            create: (_) => ConnectFlow(vpn: vpn),
          ),
          ChangeNotifierProvider<LocaleState>(create: (_) => LocaleState()),
        ],
        child: const MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: Locale('en'),
          home: MyServersScreen(),
        ),
      ),
    );
    // The screen asks for the servers after its first frame.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final texts = [
      for (final w in tester.widgetList<Text>(find.byType(Text)))
        w.data ?? w.textSpan?.toPlainText() ?? '',
    ];
    return (texts: texts, checked: checked, reports: reports);
  }

  testWidgets('the servers screen is the same with variant tests, and they '
      'run behind it', (tester) async {
    final plain = await show(tester, _answer());
    final tested = await show(tester, _answer(withTests: true));

    expect(plain.texts, contains('Nuremberg'));
    expect(tested.texts, plain.texts);
    for (final text in tested.texts) {
      expect(text, isNot(contains('VariantUnderTest')));
      expect(text, isNot(contains('#v=')));
    }

    expect(plain.checked, isEmpty);
    expect(plain.reports, 0);
    expect(tested.checked, [_variant]);
    expect(tested.reports, 1);

    // Lets the screens' own timers run out before the tree goes.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
