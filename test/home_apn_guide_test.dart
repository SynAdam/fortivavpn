import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/apn_guide.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/connection_info.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/home_screen.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The APN guide card on the home screen. IPv6 often gets through where
/// our IPv4 door addresses are blocked, and many Samsung phones on mobile
/// data have no IPv6. The card shows those phones how to turn it on. These
/// tests pin that the screen shows it, opens the steps, puts it away for
/// "Not now", and keeps it away while a connect is under way. Who sees it
/// is pinned in apn_guide_test.dart.
const _shared = Server(
  id: 'official-1',
  name: 'DE Falkenstein',
  country: 'Germany',
  city: 'Falkenstein',
  connectionUri: 'vless://u@198.51.100.201:443?security=reality#DE',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
);

final _settings = ApnGuideSettings.fromJson({
  'enabled': true,
  'brands': ['samsung'],
  'carriers': ['Hamrah Aval', 'Irancell'],
});

const _title = 'A steadier connection on this SIM';

class _Dedicated extends DedicatedState {
  @override
  bool get isBlocked => false;

  @override
  Server? get selectedServer => null;

  @override
  bool get hasServers => false;

  @override
  Future<void> refresh({bool? viaTunnel}) async {}

  @override
  int? pingFor(String serverId) => null;

  @override
  Future<void> pingServer(Server server) async {}
}

class _Servers extends ServerState {
  @override
  Server? get selectedServer => _shared;

  @override
  Future<void> loadServers({bool forceRefresh = false}) async {}

  @override
  int? getPingResult(String serverId) => 42;

  @override
  Future<void> pingServer(Server server) async {}
}

/// A tunnel whose state a test sets. It never dials.
class _Vpn extends VpnService {
  VpnStatus _fake = VpnStatus.disconnected;

  void become(VpnStatus status) {
    _fake = status;
    notifyListeners();
  }

  @override
  VpnStatus get status => _fake;

  @override
  bool get isConnected => _fake == VpnStatus.connected;

  @override
  bool get isConnecting => _fake == VpnStatus.connecting;

  @override
  bool get isVerifying => false;

  @override
  ConnectionInfo? get currentConnection => null;

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {}

  @override
  Future<void> disconnect() async => become(VpnStatus.disconnected);
}

/// A connect flow whose busy state a test sets.
class _Flow extends ConnectFlow {
  _Flow({required super.vpn});

  bool _busy = false;

  void busy(bool value) {
    _busy = value;
    notifyListeners();
  }

  @override
  bool get isBusy => _busy;
}

/// The backend's APN guide settings, as a test sets them.
class _Config extends AppConfigState {
  _Config(this._guide)
    : super(fetch: () async => throw StateError('no fetch in tests'));

  ApnGuideSettings? _guide;

  void become(ApnGuideSettings? settings) {
    _guide = settings;
    notifyListeners();
  }

  @override
  ApnGuideSettings? get apnGuide => _guide;
}

void main() {
  const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
  const statusChannel = EventChannel('com.vpn.fortivavpn/tunnel/status');

  // What the fake phone says. A test changes them before or after the
  // screen reads them.
  late bool? route;
  late int reads;
  late int opens;
  _Flow? flow;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    route = false;
    reads = 0;
    opens = 0;
    flow = null;
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

  /// A Samsung on Hamrah Aval mobile data. Platform channels answer
  /// nothing in a widget test, so every read is a fake.
  ApnGuide samsungOnMci() => ApnGuide(
    android: true,
    manufacturer: () async {
      reads++;
      return 'samsung';
    },
    network: () async {
      reads++;
      return (network: 'mobile', carrier: 'IR-MCI');
    },
    ipv6Route: () async {
      reads++;
      return route;
    },
    openSettings: () async {
      opens++;
      return true;
    },
  );

  Future<void> pumpHome(
    WidgetTester tester, {
    required ApnGuide guide,
    AppConfigState? config,
    _Vpn? vpn,
    String locale = 'en',
  }) async {
    // A phone held upright, 360 by 780, where the card sits under the
    // button with the server card.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final tunnelVpn = vpn ?? _Vpn();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(value: _Dedicated()),
          ChangeNotifierProvider<ServerState>.value(value: _Servers()),
          ChangeNotifierProvider<VpnService>.value(value: tunnelVpn),
          ChangeNotifierProvider<ConnectFlow>(
            create: (_) => flow = _Flow(vpn: tunnelVpn),
          ),
          ChangeNotifierProvider<LocaleState>(create: (_) => LocaleState()),
          ChangeNotifierProvider<AppConfigState>.value(
            value: config ?? _Config(_settings),
          ),
          ChangeNotifierProvider<ApnGuide>.value(value: guide),
        ],
        child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: Locale(locale),
          home: const HomeScreen(),
        ),
      ),
    );
    // The first frame, then the read of the phone that follows it.
    await tester.pump();
    await tester.pump();
  }

  /// Let the sheet open or close. The power button animates, so the
  /// screen never settles.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Take the screen away, which stops its timers, and let the tunnel
  /// service's first status poll run.
  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('shows the card, and "Not now" puts it away', (tester) async {
    await pumpHome(tester, guide: samsungOnMci());
    expect(find.text(_title), findsOneWidget);
    expect(
      find.text(
        'Your phone is not using IPv6 on this SIM. Turning it on helps '
        'Fortiva stay connected.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Not now'));
    await tester.pump();
    expect(find.text(_title), findsNothing);
    final saved = await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(ApnGuide.apnGuideDismissedKey);
    });
    expect(saved, isNotNull);

    // Back in front: the phone is read again, and the card stays away.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(find.text(_title), findsNothing);
    await done(tester);
  });

  testWidgets('"Show me how" opens the steps for the SIM\'s access point, '
      'and the button opens the APN screen', (tester) async {
    await pumpHome(tester, guide: samsungOnMci());

    await tester.tap(find.text('Show me how'));
    await settle(tester);
    expect(find.text('Turn on IPv6 for this SIM'), findsOneWidget);
    for (final step in [
      'Tap "Open APN settings" (or go to Settings > Connections > Mobile '
          'networks > Access Point Names).',
      'Tap the access point in use (mcinet).',
      'Tap "APN protocol" and choose "IPv4/IPv6".',
      'Save (on Samsung: the three-dot menu, then Save).',
      'Turn mobile data off and on again.',
      'If mobile data stops working, set APN protocol back to IPv4.',
    ]) {
      expect(find.text(step), findsOneWidget, reason: step);
    }

    await tester.tap(find.text('Open APN settings'));
    await tester.pump();
    expect(opens, 1);
    // Still open, for when the user comes back to read the next step.
    expect(find.text('Turn on IPv6 for this SIM'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await done(tester);
  });

  testWidgets('reads in Persian, with the steps\' numbers in Persian digits '
      'and IPv4/IPv6 as it is', (tester) async {
    await pumpHome(tester, guide: samsungOnMci(), locale: 'fa');
    expect(find.text('اتصال پایدارتر با این سیم‌کارت'), findsOneWidget);

    await tester.tap(find.text('روشش را نشانم بده'));
    await settle(tester);
    expect(find.text('روی نقطه دسترسی فعال (mcinet) بزنید.'), findsOneWidget);
    expect(
      find.text('روی «پروتکل APN» بزنید و «IPv4/IPv6» را انتخاب کنید.'),
      findsOneWidget,
    );
    expect(find.text('۱'), findsOneWidget);
    expect(find.text('۵'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await done(tester);
  });

  testWidgets('stays away while a connect is under way', (tester) async {
    final vpn = _Vpn();
    await pumpHome(tester, guide: samsungOnMci(), vpn: vpn);
    expect(find.text(_title), findsOneWidget);

    flow!.busy(true);
    await tester.pump();
    expect(find.text(_title), findsNothing);
    flow!.busy(false);
    await tester.pump();
    expect(find.text(_title), findsOneWidget);

    vpn.become(VpnStatus.connecting);
    await tester.pump();
    expect(find.text(_title), findsNothing);
    vpn.become(VpnStatus.connected);
    await tester.pump();
    expect(find.text(_title), findsOneWidget);

    // Down again, which also stops the timers the tunnel service runs
    // while connected.
    vpn.become(VpnStatus.disconnected);
    await tester.pump();
    expect(find.text(_title), findsOneWidget);
    await done(tester);
  });

  testWidgets('goes once the phone comes back with an IPv6 route', (
    tester,
  ) async {
    await pumpHome(tester, guide: samsungOnMci());
    expect(find.text(_title), findsOneWidget);

    // Back from the APN screen with the protocol changed.
    route = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(find.text(_title), findsNothing);
    await done(tester);
  });

  testWidgets('nothing shows, and nothing is read, until the config turns '
      'the guide on', (tester) async {
    final config = _Config(null);
    await pumpHome(tester, guide: samsungOnMci(), config: config);
    expect(find.text(_title), findsNothing);
    expect(reads, 0);

    config.become(_settings);
    await tester.pump();
    await tester.pump();
    expect(find.text(_title), findsOneWidget);
    expect(reads, greaterThan(0));

    config.become(null);
    await tester.pump();
    expect(find.text(_title), findsNothing);
    await done(tester);
  });
}
