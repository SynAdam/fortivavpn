import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/design_system.dart';
import 'package:fortiva_vpn/core/form_factor.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/core/update_check.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/connection_info.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/data/models/version_info.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/services/ipv6_reach.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/update_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/app_theme.dart';

/// The properties worth pinning: a required update cannot be escaped but
/// always leaves a way to get online, or says why there is none, and a way
/// to take down a tunnel that holds the phone's traffic, an optional one
/// comes back on the next open rather than a day later, only one dialog is
/// ever on screen,
/// and on Android a user who cannot update from Google Play is still shown
/// a way to update.

const playUrl =
    'https://play.google.com/store/apps/details?id=com.vpn.fortivavpn';

PlatformVersion version({
  String latest = '1.9.0',
  String minimum = '1.0.0',
  bool required = false,
}) => PlatformVersion(
  latestVersion: latest,
  minimumVersion: minimum,
  updateRequired: required,
  updateUrl: playUrl,
  releaseNotes: null,
);

/// A required update: the minimum is the latest release, and both are
/// newer than the running 1.4.1.
PlatformVersion forcedVersion() => version(latest: '9.9.9', minimum: '9.9.9');

/// What the backend sends, with [extra] on top.
PlatformVersion fromBackend(Map<String, dynamic> extra) =>
    PlatformVersion.fromJson({
      'latest_version': '9.9.9',
      'minimum_version': '1.0.0',
      'update_required': false,
      'update_url': playUrl,
      ...extra,
    });

ForceUpdate rulesWith(PlatformVersion android) =>
    ForceUpdate(ios: android, android: android);

const _shared = Server(
  id: 'official-1',
  name: 'DE Falkenstein',
  country: 'Germany',
  city: 'Falkenstein',
  connectionUri: 'vless://u@198.51.100.201:443?security=reality#DE',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
);

/// A device whose own servers have not loaded, so the connect button
/// dials the shared server, the simplest path through the real code.
class _FakeDedicated extends DedicatedState {
  int refreshes = 0;

  /// Whether the daily allowance is spent.
  bool blocked = false;

  /// What the next refresh finds the allowance to be, when a test wants it
  /// to change.
  bool? blockedAfterRefresh;

  void spend() {
    blocked = true;
    notifyListeners();
  }

  @override
  bool get isBlocked => blocked;

  @override
  QuotaStatus? get quota => blocked
      ? QuotaStatus(
          unlimited: false,
          limitBytes: 1 << 30,
          usedBytes: 1 << 30,
          remainingBytes: 0,
          blocked: true,
          resetsAt: DateTime.now().add(const Duration(hours: 3, minutes: 5)),
        )
      : null;

  @override
  Server? get selectedServer => null;

  @override
  bool get hasServers => false;

  /// What the last refresh failed with, when a test wants it to fail.
  String? failWith;

  @override
  String? get errorMessage => failWith;

  @override
  Future<void> refresh({bool? viaTunnel}) async {
    refreshes++;
    final after = blockedAfterRefresh;
    if (after != null) blocked = after;
    notifyListeners();
  }
}

/// The shared servers, which have loaded unless a test says otherwise.
class _FakeServers extends ServerState {
  _FakeServers({required this.loaded});

  bool loaded;
  int loads = 0;

  /// Holds a load open until the test completes it.
  Completer<void>? loading;

  @override
  Server? get selectedServer => loaded ? _shared : null;

  @override
  Future<void> loadServers({bool forceRefresh = false}) async {
    loads++;
    await loading?.future;
    loaded = true;
    notifyListeners();
  }
}

/// Records what the dialog asks of the tunnel instead of dialling, and
/// lets a test move it between states.
class _FakeVpn extends VpnService {
  VpnStatus _fake;
  final connects = <Server>[];
  int disconnects = 0;

  _FakeVpn({VpnStatus status = VpnStatus.disconnected}) : _fake = status;

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
  }) async {
    connects.add(server);
    become(VpnStatus.connecting);
  }

  /// When set, a disconnect waits for it before the tunnel is down, so a
  /// test can look at the dialog while the tunnel is still coming down.
  Completer<void>? holdDisconnect;

  @override
  Future<void> disconnect() async {
    disconnects++;
    await holdDisconnect?.future;
    become(VpnStatus.disconnected);
  }

  /// What every traffic check answers, after [answers] runs out.
  bool carries = true;

  /// Answers for the next checks, in order.
  final answers = <bool>[];
  int trafficChecks = 0;

  @override
  Future<bool> checkTraffic() async {
    trafficChecks++;
    return answers.isEmpty ? carries : answers.removeAt(0);
  }

  /// What every read of the tunnel's counters answers.
  int? down = 0;
  int byteReads = 0;

  @override
  Future<int?> tunnelBytesDown() async {
    byteReads++;
    return down;
  }
}

/// The connect flow these screens dial through, with nothing that reaches
/// a platform channel: a widget test has none to answer. A phone with no
/// servers of its own races the shared links after a failed pick, and
/// that asks for the network type and checks links.
ConnectFlow _testFlow(VpnService vpn) => ConnectFlow(
  vpn: vpn,
  memory: PathMemory(),
  // A shared link's check passes, so a pick is dialled as the home screen
  // button dials it: checked first, then dialled. Our own doors are closed.
  finder: PathFinder(
    probe: (p) async => p.isDedicated ? -1 : 100,
    internet: () async => true,
  ),
  reporter: VpnEventReporter(
    send: (_, _, _) async {},
    sendProbes: (_, _, _) async {},
    deviceId: () async => 'DEV-1',
    appVersion: () async => '1.7.0',
    platform: 'android',
    networkType: () async => 'wifi',
  ),
  ipv6: Ipv6Reach(route: () async => false),
  networkKey: () async => 'wifi',
  carrier: () async => null,
  attemptTimeout: const Duration(seconds: 2),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The connect flow the last pump built.
  ConnectFlow? flow;

  /// Stop the dial a test started. The fake tunnel never settles by
  /// itself, and the flow's wait for it must not outlive the test.
  Future<void> stopConnect(WidgetTester tester) async {
    flow?.cancel();
    await tester.pump(const Duration(seconds: 30));
  }

  const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
  const statusChannel = EventChannel('com.vpn.fortivavpn/tunnel/status');

  /// Every link the dialog asked to open, in order.
  late List<Uri> opened;
  late _FakeVpn vpn;
  late _FakeDedicated dedicated;
  late _FakeServers servers;

  /// Runs the update check again on the app [pump] built last, the way a
  /// return to the foreground does.
  late Future<void> Function(ForceUpdate rules) checkAgain;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UpdateDialog.resetForTest();
    opened = [];
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

  Future<void> pump(
    WidgetTester tester,
    ForceUpdate rules, {
    bool android = true,
    bool? windows,
    // Whether Google signed this copy. Null asks PlaySignature.shared, as
    // the app does, and that says no on the test host, which is no phone.
    bool? googleSigned = true,
    Locale? locale,
    VpnStatus status = VpnStatus.disconnected,
    bool blocked = false,
    bool serversLoaded = true,
  }) async {
    vpn = _FakeVpn(status: status);
    dedicated = _FakeDedicated()..blocked = blocked;
    servers = _FakeServers(loaded: serversLoaded);
    late BuildContext appContext;
    Future<void> check(ForceUpdate rules) => UpdateDialog.maybeShow(
      appContext,
      rules,
      currentVersion: '1.4.1',
      android: android,
      windows: windows,
      googleSigned: googleSigned,
      open: (url) async => opened.add(url),
    );
    checkAgain = check;
    await tester.pumpWidget(
      MultiProvider(
        // A new tree on every pump, so a dialog left open by an earlier
        // pump in the same test does not carry over.
        key: UniqueKey(),
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(value: dedicated),
          ChangeNotifierProvider<ServerState>.value(value: servers),
          ChangeNotifierProvider<VpnService>.value(value: vpn),
          ChangeNotifierProvider<ConnectFlow>(
            create: (_) => flow = _testFlow(vpn),
          ),
        ],
        child: MaterialApp(
          locale: locale,
          theme: appThemeFor(locale),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: Builder(
            builder: (context) {
              appContext = context;
              return TextButton(
                onPressed: () => check(rules),
                child: const Text('go'),
              );
            },
          ),
        ),
      ),
    );
    // The service's start-up status poll runs on a timer.
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  group('where to update from', () {
    testWidgets('Android offers Google Play and the Telegram channel', (
      tester,
    ) async {
      await pump(tester, rulesWith(version(latest: '9.9.9')));

      expect(find.text('Google Play'), findsOneWidget);
      expect(find.text('Telegram channel'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Update'), findsNothing);
    });

    testWidgets('the copy Google signed lists Google Play first', (
      tester,
    ) async {
      await pump(tester, rulesWith(version(latest: '9.9.9')));

      final play = tester.getRect(find.text('Google Play'));
      final telegram = tester.getRect(find.text('Telegram channel'));
      expect(play.top, lessThan(telegram.top));
    });

    // Play cannot update the channel APK. A user who went there uninstalled
    // and came back as a new device, counted twice. Every copy runs the same
    // code, so the channel APK is told apart by its signature alone.
    testWidgets('the channel APK lists the channel first and opens '
        'channel_url', (tester) async {
      final platform = fromBackend({
        'channel_url': 'https://t.me/fortiva_vpn/123',
        'play_channel_url': 'https://t.me/fortiva_news',
      });
      await pump(tester, rulesWith(platform), googleSigned: false);

      final play = tester.getRect(find.text('Google Play'));
      final telegram = tester.getRect(find.text('Telegram channel'));
      expect(telegram.top, lessThan(play.top));

      await tester.tap(find.text('Telegram channel'));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse('https://t.me/fortiva_vpn/123')]);
    });

    testWidgets('the channel APK still offers Google Play', (tester) async {
      await pump(
        tester,
        rulesWith(version(latest: '9.9.9')),
        googleSigned: false,
      );

      await tester.tap(find.text('Google Play'));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse(playUrl)]);
    });

    // A check that fails reads as "not Google's". The channel APK is then
    // right whether its check works or not.
    testWidgets('a copy that cannot read its signature lists the channel '
        'first and opens channel_url', (tester) async {
      final platform = fromBackend({
        'channel_url': 'https://t.me/fortiva_vpn/123',
        'play_channel_url': 'https://t.me/fortiva_news',
      });
      await pump(tester, rulesWith(platform), googleSigned: null);

      final play = tester.getRect(find.text('Google Play'));
      final telegram = tester.getRect(find.text('Telegram channel'));
      expect(telegram.top, lessThan(play.top));

      await tester.tap(find.text('Telegram channel'));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse('https://t.me/fortiva_vpn/123')]);
    });

    testWidgets('iOS keeps the one App Store button', (tester) async {
      await pump(tester, rulesWith(version(latest: '9.9.9')), android: false);

      expect(find.text('Update'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Google Play'), findsNothing);
      expect(find.text('Telegram channel'), findsNothing);
    });

    testWidgets('Windows opens the download the backend sent', (tester) async {
      const download = 'https://fortivavpn.com/download/windows';
      final windows = PlatformVersion(
        latestVersion: '9.9.9',
        minimumVersion: '1.0.0',
        updateRequired: false,
        updateUrl: download,
        releaseNotes: null,
      );
      await pump(
        tester,
        ForceUpdate(
          ios: version(latest: '9.9.9'),
          android: version(latest: '9.9.9'),
          windows: windows,
        ),
        windows: true,
      );

      expect(find.text('Google Play'), findsNothing);
      expect(find.text('Telegram channel'), findsNothing);
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse(download)]);
    });

    testWidgets(
      'Windows is offered nothing by a backend that does not know it',
      (tester) async {
        await pump(tester, rulesWith(version(latest: '9.9.9')), windows: true);

        expect(find.text('Update'), findsNothing);
        expect(find.text('Google Play'), findsNothing);
        expect(find.text('Later'), findsNothing);
      },
    );

    testWidgets('Google Play opens update_url', (tester) async {
      await pump(tester, rulesWith(version(latest: '9.9.9')));

      await tester.tap(find.text('Google Play'));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse(playUrl)]);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('the channel button opens the channel_url the backend sent', (
      tester,
    ) async {
      final platform = fromBackend({
        'channel_url': 'https://t.me/fortiva_vpn/123',
      });
      await pump(tester, rulesWith(platform));

      await tester.tap(find.text('Telegram channel'));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse('https://t.me/fortiva_vpn/123')]);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('the copy Google signed opens play_channel_url when the '
        'backend sends one', (tester) async {
      final platform = fromBackend({
        'channel_url': 'https://t.me/fortiva_vpn',
        'play_channel_url': 'https://t.me/fortiva_news',
      });
      await pump(tester, rulesWith(platform));

      await tester.tap(find.text('Telegram channel'));
      await tester.pumpAndSettle();
      // The channel APK keeps channel_url, its update link (see the
      // channel APK tests above).
      expect(opened, [Uri.parse('https://t.me/fortiva_news')]);
    });

    testWidgets('with no channel_url the channel button opens @fortiva_vpn', (
      tester,
    ) async {
      // Every backend from before channel_url.
      await pump(tester, rulesWith(fromBackend({})));

      await tester.tap(find.text('Telegram channel'));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse('https://t.me/fortiva_vpn')]);
    });

    test('an empty or malformed channel_url falls back the same way', () {
      for (final bad in <Object?>['', '   ', null, 42]) {
        expect(
          fromBackend({'channel_url': bad}).channelUrl,
          PlatformVersion.defaultChannelUrl,
          reason: 'channel_url: $bad',
        );
      }
    });
  });

  group('a required update', () {
    testWidgets('has no way out', (tester) async {
      await pump(tester, rulesWith(forcedVersion()));

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Later'), findsNothing);

      // Tapping the barrier is how a user dismisses an ordinary dialog.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      // Nor does the back gesture close it.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('still offers the channel on Android', (tester) async {
      // Without it a user who cannot reach Play has no way to update, and
      // this dialog does not let them past it.
      await pump(tester, rulesWith(forcedVersion()));

      expect(find.text('Google Play'), findsOneWidget);
      expect(find.text('Telegram channel'), findsOneWidget);
    });

    testWidgets('stays up after the channel opens', (tester) async {
      await pump(tester, rulesWith(forcedVersion()));

      await tester.tap(find.text('Telegram channel'));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse('https://t.me/fortiva_vpn')]);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('is shown even when the offer was put off this open', (
      tester,
    ) async {
      UpdateDialog.opens.optionalAnswered();
      await pump(tester, rulesWith(forcedVersion()));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Later'), findsNothing);
    });

    testWidgets('is not forced when the minimum is newer than the latest', (
      tester,
    ) async {
      // A minimum raised before the release reached the store. Nobody
      // could satisfy it, so the user is offered the latest instead.
      await pump(tester, rulesWith(version(latest: '1.9.0', minimum: '9.9.9')));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(UpdateDialog.showingForced, isFalse);
    });
  });

  group('the way online on a required update', () {
    /// The filled buttons on the dialog whose fill is the brand's.
    List<String> brandButtons(WidgetTester tester) => [
      for (final button
          in find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byWidgetPredicate((w) => w is FilledButton),
              )
              .evaluate())
        if (tester
                .widget<Material>(
                  find
                      .descendant(
                        of: find.byWidget(button.widget),
                        matching: find.byType(Material),
                      )
                      .first,
                )
                .color ==
            AppDesign.brand)
          tester
              .widgetList<Text>(
                find.descendant(
                  of: find.byWidget(button.widget),
                  matching: find.byType(Text),
                ),
              )
              .single
              .data!,
    ];

    testWidgets('one brand button, the way that updates this copy, while '
        'the VPN is off and once it is on', (tester) async {
      await pump(tester, rulesWith(forcedVersion()));
      expect(brandButtons(tester), ['Google Play']);

      vpn.become(VpnStatus.connected);
      await tester.pumpAndSettle();
      expect(brandButtons(tester), ['Google Play']);
      vpn.become(VpnStatus.disconnected);
      await tester.pump();
    });

    testWidgets('the channel copy fills the channel button instead', (
      tester,
    ) async {
      await pump(tester, rulesWith(forcedVersion()), googleSigned: false);
      expect(brandButtons(tester), ['Telegram channel']);
    });

    testWidgets('Connect comes first while the VPN is off', (tester) async {
      await pump(tester, rulesWith(forcedVersion()));

      expect(find.text('Connect'), findsOneWidget);
      expect(
        find.textContaining('If Google Play or Telegram does not open'),
        findsOneWidget,
      );
      final connect = tester.getRect(find.text('Connect'));
      final play = tester.getRect(find.text('Google Play'));
      expect(connect.top, lessThan(play.top));
    });

    testWidgets('Connect dials what the home screen button would', (
      tester,
    ) async {
      await pump(tester, rulesWith(forcedVersion()));

      await tester.tap(find.text('Connect'));
      await tester.pump();

      // The home screen's path: the device's own servers were asked for
      // once more, then the shared server was dialled because none came.
      expect(dedicated.refreshes, greaterThanOrEqualTo(1));
      expect(vpn.connects, [_shared]);
      expect(find.byType(AlertDialog), findsOneWidget);
      await stopConnect(tester);
    });

    testWidgets('shows progress while connecting', (tester) async {
      await pump(tester, rulesWith(forcedVersion()));

      await tester.tap(find.text('Connect'));
      await tester.pump();

      expect(find.text('Connect'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Connecting'), findsOneWidget);
      await stopConnect(tester);
    });

    testWidgets('says the user can download once connected', (tester) async {
      await pump(tester, rulesWith(forcedVersion()));

      vpn.become(VpnStatus.connected);
      await tester.pumpAndSettle();

      expect(find.text('Connect'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text('You are connected. Download the update now.'),
        findsOneWidget,
      );
      // Reconnect stays, for a tunnel that is up but carries nothing.
      expect(find.text('Not working? Reconnect'), findsOneWidget);
      // The hint to connect first is gone with the need for it.
      expect(
        find.textContaining('If Google Play or Telegram does not open'),
        findsNothing,
      );
      expect(find.text('Google Play'), findsOneWidget);
      expect(find.text('Telegram channel'), findsOneWidget);

      // The service keeps a heartbeat timer while connected, and the test
      // must end with no timer pending.
      vpn.become(VpnStatus.disconnected);
      await tester.pump();
    });

    testWidgets('a tunnel already up is left up', (tester) async {
      await pump(
        tester,
        rulesWith(forcedVersion()),
        status: VpnStatus.connected,
      );

      expect(
        find.text('You are connected. Download the update now.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Telegram channel'));
      await tester.pumpAndSettle();
      expect(vpn.disconnects, 0);
      expect(vpn.connects, isEmpty);
    });

    testWidgets('a failed connect offers Connect again', (tester) async {
      await pump(tester, rulesWith(forcedVersion()));

      await tester.tap(find.text('Connect'));
      await tester.pump();
      vpn.become(VpnStatus.error);
      await tester.pumpAndSettle();

      expect(find.text('Connect'), findsOneWidget);
    });

    testWidgets('Reconnect takes the tunnel down and dials again', (
      tester,
    ) async {
      // A tunnel that says it is connected but carries nothing. The home
      // screen, where the user would reconnect, is behind the dialog.
      await pump(
        tester,
        rulesWith(forcedVersion()),
        status: VpnStatus.connected,
      );

      await tester.tap(find.text('Not working? Reconnect'));
      // Not settled: the dial leaves a spinner turning.
      await tester.pump();
      await tester.pump();

      expect(vpn.disconnects, 1);
      expect(vpn.connects, [_shared]);
      expect(find.byType(AlertDialog), findsOneWidget);
      await stopConnect(tester);
    });

    for (final tv in [false, true]) {
      testWidgets(
        tv
            ? 'on a TV, Reconnect stays enabled while it runs and ignores '
                  'a second press'
            : 'on a phone, Reconnect is disabled while it runs',
        (tester) async {
          FormFactor.isTvForTest = tv;
          addTearDown(() => FormFactor.isTvForTest = false);
          await pump(
            tester,
            rulesWith(forcedVersion()),
            status: VpnStatus.connected,
          );
          vpn.holdDisconnect = Completer<void>();
          final reconnect = find.ancestor(
            of: find.text('Not working? Reconnect'),
            matching: find.byWidgetPredicate((w) => w is TextButton),
          );

          await tester.tap(reconnect);
          await tester.pump();
          // The tunnel is still up, so the line and Reconnect are still
          // there while it comes down.
          expect(reconnect, findsOneWidget);
          final onPressed = tester.widget<TextButton>(reconnect).onPressed;
          expect(onPressed == null, !tv);
          if (tv) {
            await tester.tap(reconnect);
            await tester.pump();
          }
          expect(vpn.disconnects, 1);

          vpn.holdDisconnect!.complete();
          await tester.pump();
          await tester.pump();
          expect(vpn.connects, [_shared]);
          await stopConnect(tester);
        },
      );
    }

    testWidgets('Connect waits for servers that have not loaded, then dials', (
      tester,
    ) async {
      await pump(tester, rulesWith(forcedVersion()), serversLoaded: false);
      servers.loading = Completer<void>();

      await tester.tap(find.text('Connect'));
      await tester.pump();

      // Busy while the servers load, rather than a button that looks dead.
      expect(servers.loads, 1);
      expect(find.text('Connect'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(vpn.connects, isEmpty);

      servers.loading!.complete();
      await tester.pump();
      await tester.pump();
      expect(vpn.connects, [_shared]);
      await stopConnect(tester);
    });

    testWidgets('over the allowance the dialog says so and when it refills', (
      tester,
    ) async {
      await pump(tester, rulesWith(forcedVersion()), blocked: true);

      expect(find.text('Daily data used up'), findsOneWidget);
      expect(find.text('Resets in 3h'), findsOneWidget);
      // The hint would send the user to a Connect that cannot dial.
      expect(
        find.textContaining('If Google Play or Telegram does not open'),
        findsNothing,
      );

      // A tap asks whether the allowance has refilled, and dials nothing
      // while it has not.
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(dedicated.refreshes, greaterThanOrEqualTo(1));
      expect(vpn.connects, isEmpty);
      expect(find.text('Daily data used up'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
    });

    testWidgets('Connect over the allowance dials once it has refilled', (
      tester,
    ) async {
      await pump(tester, rulesWith(forcedVersion()), blocked: true);
      dedicated.blockedAfterRefresh = false;

      await tester.tap(find.text('Connect'));
      await tester.pump();
      await tester.pump();

      expect(vpn.connects, [_shared]);
      expect(find.text('Daily data used up'), findsNothing);
      await stopConnect(tester);
    });

    testWidgets('the offer has no Connect', (tester) async {
      await pump(tester, rulesWith(version(latest: '9.9.9')));
      expect(find.text('Connect'), findsNothing);
    });
  });

  group('Disconnect on a required update', () {
    // Issue #195: a tunnel that says it is connected and carries nothing
    // holds all of the phone's traffic, and the home screen's button is
    // behind this dialog.

    testWidgets('is offered while connected, below the update buttons', (
      tester,
    ) async {
      await pump(
        tester,
        rulesWith(forcedVersion()),
        status: VpnStatus.connected,
      );

      expect(find.text('Disconnect'), findsOneWidget);
      final disconnect = tester.getRect(find.text('Disconnect'));
      final telegram = tester.getRect(find.text('Telegram channel'));
      expect(disconnect.top, greaterThan(telegram.top));
    });

    testWidgets('is not offered while the tunnel is down', (tester) async {
      await pump(tester, rulesWith(forcedVersion()));
      expect(find.text('Disconnect'), findsNothing);
    });

    testWidgets('takes the tunnel down and leaves the dialog up', (
      tester,
    ) async {
      await pump(
        tester,
        rulesWith(forcedVersion()),
        status: VpnStatus.connected,
      );

      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();

      expect(vpn.disconnects, 1);
      expect(vpn.connects, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
      // Back to where the dialog started: Connect, with the hint.
      expect(find.text('Disconnect'), findsNothing);
      expect(find.text('Connect'), findsOneWidget);
      expect(
        find.textContaining('If Google Play or Telegram does not open'),
        findsOneWidget,
      );
      expect(find.text('Google Play'), findsOneWidget);
      expect(find.text('Telegram channel'), findsOneWidget);
    });

    testWidgets('is not offered while connecting', (tester) async {
      // The progress line holds that row, and the connect ends on its own
      // with Connect back.
      await pump(tester, rulesWith(forcedVersion()));

      await tester.tap(find.text('Connect'));
      await tester.pump();
      expect(vpn.connects, [_shared]);
      expect(find.text('Disconnect'), findsNothing);

      vpn.become(VpnStatus.error);
      await tester.pumpAndSettle();
      expect(find.text('Connect'), findsOneWidget);
    });

    testWidgets('over the allowance it is what the dialog points at', (
      tester,
    ) async {
      // The tunnel is still up, so the connected branch used to win and
      // tell the user to download over a tunnel that carries nothing.
      await pump(
        tester,
        rulesWith(forcedVersion()),
        status: VpnStatus.connected,
        blocked: true,
      );

      expect(find.text('Daily data used up'), findsOneWidget);
      expect(find.text('Resets in 3h'), findsOneWidget);
      expect(
        find.text(
          'Tap Disconnect to download the update over your normal internet.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('You are connected. Download the update now.'),
        findsNothing,
      );
      // Reconnect would dial nothing while the allowance is spent.
      expect(find.text('Not working? Reconnect'), findsNothing);

      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();
      expect(vpn.disconnects, 1);
      expect(find.text('Daily data used up'), findsOneWidget);
      expect(find.textContaining('Tap Disconnect'), findsNothing);
      expect(find.text('Connect'), findsOneWidget);
    });

    testWidgets('the offer has no Disconnect', (tester) async {
      // Later already closes the offer, and the home screen is behind it.
      await pump(
        tester,
        rulesWith(version(latest: '9.9.9')),
        status: VpnStatus.connected,
      );
      expect(find.text('Disconnect'), findsNothing);
    });
  });

  group('the live check on a required update', () {
    // Issue #195: the service checks traffic once, right after connecting,
    // so a tunnel that died later still read as connected.

    const notCarrying =
        'You are connected, but nothing is getting through. Try Reconnect, '
        'or tap Disconnect to use your normal internet.';
    const connectedLine = 'You are connected. Download the update now.';

    /// Connect in the dialog the way a user does, so the check starts from
    /// a tunnel the service has just passed.
    Future<void> connectFresh(WidgetTester tester) async {
      await pump(tester, rulesWith(forcedVersion()));
      vpn.become(VpnStatus.connecting);
      await tester.pump();
      vpn.become(VpnStatus.connected);
      await tester.pumpAndSettle();
    }

    /// One round of the check: the periodic tick, then the retry.
    Future<void> oneRound(WidgetTester tester) async {
      await tester.pump(UpdateDialog.liveCheckEvery);
      await tester.pump(UpdateDialog.liveRetryGap);
      await tester.pumpAndSettle();
    }

    /// Send the app to the background and back, one state at a time,
    /// the order the platform reports them in.
    void toBackground(WidgetTester tester) {
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    }

    void toFront(WidgetTester tester) {
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    }

    /// The service keeps a heartbeat timer while connected, and the test
    /// must end with no timer pending.
    Future<void> endConnected(WidgetTester tester) async {
      vpn.become(VpnStatus.disconnected);
      await tester.pump();
    }

    testWidgets('a fresh connect is not checked again at once', (tester) async {
      await connectFresh(tester);
      expect(vpn.trafficChecks, 0);
      await tester.pump(UpdateDialog.liveCheckEvery);
      expect(vpn.trafficChecks, 1);
      expect(find.text(connectedLine), findsOneWidget);
      await endConnected(tester);
    });

    testWidgets('a tunnel already up when the dialog opens is checked now', (
      tester,
    ) async {
      await pump(
        tester,
        rulesWith(forcedVersion()),
        status: VpnStatus.connected,
      );
      expect(vpn.trafficChecks, 1);
      expect(find.text(connectedLine), findsOneWidget);
    });

    testWidgets('a tunnel found connected without a dial is checked now', (
      tester,
    ) async {
      // Restored after a restart of the app: no check has passed it in
      // this run.
      await pump(tester, rulesWith(forcedVersion()));
      vpn.become(VpnStatus.connected);
      await tester.pump();
      expect(vpn.trafficChecks, 1);
      await endConnected(tester);
    });

    testWidgets('a tunnel that stops carrying is called out, not taken down', (
      tester,
    ) async {
      await connectFresh(tester);
      vpn.carries = false;
      await oneRound(tester);

      expect(vpn.trafficChecks, 2);
      expect(find.text(notCarrying), findsOneWidget);
      expect(find.text(connectedLine), findsNothing);
      expect(find.text('Not working? Reconnect'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
      // The user decides: a check can be wrong, and a working tunnel taken
      // down is worse than a dead one left up.
      expect(vpn.disconnects, 0);
      expect(find.byType(AlertDialog), findsOneWidget);
      await endConnected(tester);
    });

    testWidgets('a busy tunnel that is too slow to answer is not called dead', (
      tester,
    ) async {
      // The update download fills the tunnel, and both checks time out
      // while data keeps coming down.
      await connectFresh(tester);
      vpn.carries = false;
      vpn.down = 1 << 20;
      await oneRound(tester);

      expect(vpn.trafficChecks, 2);
      expect(vpn.byteReads, 2);
      expect(find.text(connectedLine), findsOneWidget);
      expect(find.text(notCarrying), findsNothing);
      expect(dedicated.refreshes, 0);
      await endConnected(tester);
    });

    testWidgets('a trickle of data does not count as working', (tester) async {
      await connectFresh(tester);
      vpn.carries = false;
      vpn.down = UpdateDialog.movingBytes - 1;
      await oneRound(tester);
      expect(find.text(notCarrying), findsOneWidget);
      await endConnected(tester);
    });

    testWidgets('no counters to read, as on iOS, leaves the checks to decide', (
      tester,
    ) async {
      await connectFresh(tester);
      vpn.carries = false;
      vpn.down = null;
      await oneRound(tester);
      expect(find.text(notCarrying), findsOneWidget);
      await endConnected(tester);
    });

    testWidgets('one failed check is not enough', (tester) async {
      await connectFresh(tester);
      vpn.answers.addAll([false, true]);
      await oneRound(tester);

      expect(vpn.trafficChecks, 2);
      expect(find.text(connectedLine), findsOneWidget);
      expect(find.text(notCarrying), findsNothing);
      expect(dedicated.refreshes, 0);
      await endConnected(tester);
    });

    testWidgets('a tunnel that carries again is connected again', (
      tester,
    ) async {
      await connectFresh(tester);
      vpn.carries = false;
      await oneRound(tester);
      expect(find.text(notCarrying), findsOneWidget);

      vpn.carries = true;
      await tester.pump(UpdateDialog.liveCheckEvery);
      await tester.pumpAndSettle();
      expect(find.text(connectedLine), findsOneWidget);
      expect(find.text(notCarrying), findsNothing);
      await endConnected(tester);
    });

    testWidgets('a dead tunnel reads the allowance again, once', (
      tester,
    ) async {
      await connectFresh(tester);
      final before = dedicated.refreshes;
      vpn.carries = false;
      await oneRound(tester);
      expect(dedicated.refreshes, before + 1);

      // Still dead at the next round: not asked again.
      await oneRound(tester);
      expect(dedicated.refreshes, before + 1);
      await endConnected(tester);
    });

    testWidgets('a failed allowance read is tried again at the next round', (
      tester,
    ) async {
      await connectFresh(tester);
      vpn.carries = false;
      dedicated.failWith = 'Could not load your servers.';
      await oneRound(tester);
      expect(dedicated.refreshes, 1);
      await oneRound(tester);
      expect(dedicated.refreshes, 2);

      // It works this time, and is not asked again while still dead.
      dedicated.failWith = null;
      await oneRound(tester);
      expect(dedicated.refreshes, 3);
      await oneRound(tester);
      expect(dedicated.refreshes, 3);
      await endConnected(tester);
    });

    testWidgets('a new tunnel after a dead one reads as connected', (
      tester,
    ) async {
      await connectFresh(tester);
      vpn.carries = false;
      await oneRound(tester);
      expect(find.text(notCarrying), findsOneWidget);

      vpn.carries = true;
      await tester.tap(find.text('Not working? Reconnect'));
      await tester.pump();
      vpn.become(VpnStatus.connected);
      await tester.pumpAndSettle();
      expect(find.text(connectedLine), findsOneWidget);
      expect(find.text(notCarrying), findsNothing);
      await endConnected(tester);
    });

    testWidgets('a spent allowance found that way takes the tunnel down', (
      tester,
    ) async {
      // The daily data ran out mid-session, and the servers stopped
      // carrying this device's traffic.
      await connectFresh(tester);
      vpn.carries = false;
      dedicated.blockedAfterRefresh = true;
      await oneRound(tester);

      expect(vpn.disconnects, 1);
      expect(find.text('Daily data used up'), findsOneWidget);
      expect(find.text('Resets in 3h'), findsOneWidget);
      expect(find.text(notCarrying), findsNothing);
      expect(find.text('Connect'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('nothing is checked while the app is in the background', (
      tester,
    ) async {
      await connectFresh(tester);
      toBackground(tester);
      await tester.pump(UpdateDialog.liveCheckEvery);
      await tester.pump(UpdateDialog.liveCheckEvery);
      expect(vpn.trafficChecks, 0);

      toFront(tester);
      await tester.pump();
      await endConnected(tester);
    });

    testWidgets('a return to the app checks at once', (tester) async {
      // The user went to Telegram, nothing loaded, and came back.
      await connectFresh(tester);
      toBackground(tester);
      await tester.pump();
      vpn.carries = false;

      toFront(tester);
      await tester.pump();
      expect(vpn.trafficChecks, 1);
      await tester.pump(UpdateDialog.liveRetryGap);
      await tester.pumpAndSettle();
      expect(find.text(notCarrying), findsOneWidget);
      await endConnected(tester);
    });

    testWidgets('a check that finishes after Reconnect is dropped', (
      tester,
    ) async {
      await connectFresh(tester);
      vpn.carries = false;
      await tester.pump(UpdateDialog.liveCheckEvery);
      // The first check failed and the retry is waiting. The user taps
      // Reconnect before it runs.
      await tester.tap(find.text('Not working? Reconnect'));
      await tester.pump();
      vpn.become(VpnStatus.connected);
      await tester.pump(UpdateDialog.liveRetryGap);
      await tester.pumpAndSettle();

      // The answer was about the old tunnel, so the new one reads as
      // connected, the old one got no second check, and the allowance was
      // read only by the Reconnect dial.
      expect(find.text(connectedLine), findsOneWidget);
      expect(find.text(notCarrying), findsNothing);
      expect(vpn.trafficChecks, 1);
      expect(dedicated.refreshes, 1);
      await endConnected(tester);
    });

    testWidgets('a return to the app with the tunnel down checks nothing', (
      tester,
    ) async {
      await pump(tester, rulesWith(forcedVersion()));
      toBackground(tester);
      await tester.pump();
      toFront(tester);
      await tester.pump();
      expect(vpn.trafficChecks, 0);
      expect(dedicated.refreshes, 0);
    });

    testWidgets('the offer never checks', (tester) async {
      await pump(
        tester,
        rulesWith(version(latest: '9.9.9')),
        status: VpnStatus.connected,
      );
      await tester.pump(UpdateDialog.liveCheckEvery);
      expect(vpn.trafficChecks, 0);
    });
  });

  group('one dialog at a time', () {
    testWidgets('a check while the required dialog is up adds nothing', (
      tester,
    ) async {
      // The user went to Telegram to download and came back.
      await pump(tester, rulesWith(forcedVersion()));
      await tester.tap(find.text('Telegram channel'));
      await tester.pumpAndSettle();

      await checkAgain(rulesWith(forcedVersion()));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('a check while the offer is up adds nothing', (tester) async {
      await pump(tester, rulesWith(version(latest: '9.9.9')));

      await checkAgain(rulesWith(version(latest: '9.9.9')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('the offer is replaced once the minimum passes this build', (
      tester,
    ) async {
      await pump(tester, rulesWith(version(latest: '9.9.9')));
      expect(find.text('Later'), findsOneWidget);

      await checkAgain(rulesWith(forcedVersion()));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Later'), findsNothing);
      expect(UpdateDialog.showingForced, isTrue);
    });

    testWidgets('the required dialog goes when the minimum is lowered', (
      tester,
    ) async {
      // The rollback path: the backend took the minimum back down.
      await pump(tester, rulesWith(forcedVersion()));

      await checkAgain(rulesWith(version(latest: '1.4.1')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a lowered minimum still leaves the offer of the latest', (
      tester,
    ) async {
      await pump(tester, rulesWith(forcedVersion()));

      await checkAgain(rulesWith(version(latest: '9.9.9')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
    });
  });

  group('Later', () {
    testWidgets('closes the offer for the rest of this open', (tester) async {
      await pump(tester, rulesWith(version(latest: '9.9.9')));

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      // A quick trip to another app and back.
      await checkAgain(rulesWith(version(latest: '9.9.9')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('the offer is back on the next open', (tester) async {
      await pump(tester, rulesWith(version(latest: '9.9.9')));
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      // Long enough in the background to count as a new open. The real
      // clock is used here, so the open is started by hand.
      UpdateDialog.opens = UpdateOpens();
      await checkAgain(rulesWith(version(latest: '9.9.9')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
    });

    testWidgets('a tap outside counts as an answer too', (tester) async {
      await pump(tester, rulesWith(version(latest: '9.9.9')));

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(UpdateDialog.opens.optionalHeld, isTrue);
    });

    testWidgets('an offer replaced by the required dialog is not an answer', (
      tester,
    ) async {
      await pump(tester, rulesWith(version(latest: '9.9.9')));
      await checkAgain(rulesWith(forcedVersion()));
      await tester.pumpAndSettle();
      expect(UpdateDialog.opens.optionalHeld, isFalse);
    });

    test('what the 24 hour Later of older builds saved is removed', () async {
      SharedPreferences.setMockInitialValues({
        UpdateDialog.dismissedPrefKey: '1.6.9',
        UpdateDialog.dismissedAtPrefKey: 1759700000000,
      });
      await UpdateDialog.forgetOldLater();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(UpdateDialog.dismissedPrefKey), isNull);
      expect(prefs.getInt(UpdateDialog.dismissedAtPrefKey), isNull);
    });
  });

  testWidgets('no rules means no dialog', (tester) async {
    // A phone the backend has never answered.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                UpdateDialog.maybeShow(context, null, currentVersion: '1.4.1'),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('fits a small phone in every language, at any text size', (
    tester,
  ) async {
    // 320 by 568 points, the smallest phone screen in common use. The test
    // font draws every glyph a full em wide, wider than any real font, and
    // 2.0 is the largest text size Android offers.
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final scale in [1.0, 2.0]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      for (final locale in S.supportedLocales) {
        for (final required in [false, true]) {
          final reason =
              '$locale, text x$scale, ${required ? 'required' : 'optional'}';
          UpdateDialog.resetForTest();
          await pump(
            tester,
            rulesWith(required ? forcedVersion() : version(latest: '9.9.9')),
            locale: locale,
          );
          expect(tester.takeException(), isNull, reason: reason);

          // Connect, Play and Telegram on a required update; Play,
          // Telegram and Later on an offer.
          final buttons = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byWidgetPredicate(
              (w) => w is FilledButton || w is TextButton,
            ),
          );
          void onScreen(Finder found, int count, String reason) {
            expect(found, findsNWidgets(count), reason: reason);
            for (var i = 0; i < count; i++) {
              final rect = tester.getRect(found.at(i));
              expect(rect.left, greaterThanOrEqualTo(0), reason: reason);
              expect(rect.right, lessThanOrEqualTo(320), reason: reason);
              expect(rect.bottom, lessThanOrEqualTo(568), reason: reason);
            }
          }

          void allOnScreen(int count, String reason) =>
              onScreen(buttons, count, reason);

          allOnScreen(3, reason);
          if (!required) continue;

          // Connecting: progress in place of Connect.
          vpn.become(VpnStatus.connecting);
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$reason, busy');
          allOnScreen(2, '$reason, busy');

          // Connected: the line takes the place of Connect, with Reconnect
          // under it. Both scroll with the text, so the two update buttons
          // and Disconnect stay on screen and Reconnect can always be
          // scrolled to.
          vpn.become(VpnStatus.connected);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$reason, on');
          final updates = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byWidgetPredicate((w) => w is FilledButton),
          );
          Finder textButtonWith(IconData icon) => find.ancestor(
            of: find.byIcon(icon),
            matching: find.byWidgetPredicate((w) => w is TextButton),
          );
          final disconnect = textButtonWith(Icons.power_settings_new_rounded);
          final reconnect = textButtonWith(Icons.refresh_rounded);
          onScreen(updates, 2, '$reason, on');
          onScreen(disconnect, 1, '$reason, on, disconnect');
          await tester.ensureVisible(reconnect);
          await tester.pumpAndSettle();
          onScreen(reconnect, 1, '$reason, on, reconnect');
          onScreen(updates, 2, '$reason, on, scrolled');
          onScreen(disconnect, 1, '$reason, on, scrolled');

          // Connected, but nothing getting through: the longer line must
          // not push a button off the screen either.
          vpn.carries = false;
          await tester.pump(UpdateDialog.liveCheckEvery);
          await tester.pump(UpdateDialog.liveRetryGap);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$reason, dead');
          expect(
            find.byIcon(Icons.error_outline_rounded),
            findsOneWidget,
            reason: '$reason, dead line shown',
          );
          onScreen(updates, 2, '$reason, dead');
          onScreen(disconnect, 1, '$reason, dead, disconnect');
          await tester.ensureVisible(reconnect);
          await tester.pumpAndSettle();
          onScreen(reconnect, 1, '$reason, dead, reconnect');
          vpn.carries = true;

          // Over the allowance with the tunnel still up: the quota line and
          // the pointer to Disconnect replace Reconnect, and push no button
          // off the screen.
          dedicated.spend();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$reason, spent on');
          allOnScreen(3, '$reason, spent on');
          onScreen(disconnect, 1, '$reason, spent on, disconnect');
          vpn.become(VpnStatus.disconnected);
          await tester.pumpAndSettle();

          // Over the allowance: the longer line about it must not push a
          // button off the screen.
          expect(tester.takeException(), isNull, reason: '$reason, spent');
          allOnScreen(3, '$reason, spent');
        }
      }
    }
  });
}
