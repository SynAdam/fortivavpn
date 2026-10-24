import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/form_factor.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/connection_info.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/home_screen.dart';
import 'package:fortiva_vpn/services/failure_verdict.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/focus_ring.dart';
import 'package:fortiva_vpn/widgets/outside_link.dart';
import 'package:fortiva_vpn/widgets/power_button.dart';
import 'package:fortiva_vpn/widgets/readable_width.dart';
import 'package:fortiva_vpn/widgets/remote_refresh_button.dart';
import 'package:fortiva_vpn/widgets/tappable.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app on a TV: everything reachable and pressable with a remote,
/// a layout that fits a TV's 540 pixels of height, and links the TV cannot
/// open shown as a QR code for a phone.

const _tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
const _statusChannel = EventChannel('com.vpn.fortivavpn/tunnel/status');
const _launcher = MethodChannel('plugins.flutter.io/url_launcher');

/// A TV's screen: 1920 by 1080 pixels, 960 by 540 in logical pixels.
void _tvScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// A phone held upright. The test's own 800 by 600 screen is wide.
void _phoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Let the TV's first-focus run. It waits a turn of the event loop, which
/// a pump with no duration does not give.
Future<void> _settleFocus(WidgetTester tester) async {
  await tester.pump(Duration.zero);
  await tester.pump(Duration.zero);
}

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: S.localizationsDelegates,
  supportedLocales: S.supportedLocales,
  locale: const Locale('en'),
  navigatorKey: appNavigatorKey,
  builder: (context, child) => FocusRing(child: child!),
  home: home,
);

const _first = Server(
  id: 'dedicated-0',
  name: 'Fortiva DE',
  country: 'Germany',
  city: 'Falkenstein',
  connectionUri: 'vless://u@198.51.100.201:443?security=reality#DE',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
  isDedicated: true,
);

const _second = Server(
  id: 'dedicated-1',
  name: 'Fortiva FI',
  country: 'Finland',
  city: 'Helsinki',
  connectionUri: 'vless://u@198.51.100.202:443?security=reality#FI',
  flagEmoji: '\u{1F1EB}\u{1F1EE}',
  isDedicated: true,
);

class _FakeDedicated extends DedicatedState {
  @override
  QuotaStatus? get quota => QuotaStatus(
    unlimited: false,
    limitBytes: 100 << 20,
    usedBytes: 10 << 20,
    remainingBytes: 90 << 20,
    blocked: false,
    resetsAt: DateTime.now().add(const Duration(hours: 3)),
  );

  @override
  bool get isBlocked => false;

  @override
  Server? get selectedServer => _first;

  @override
  bool get hasServers => true;

  @override
  List<Server> get servers => const [_first, _second];

  @override
  List<Server> get paths => const [_first, _second];

  @override
  Future<void> refresh({bool? viaTunnel}) async {}

  @override
  int? pingFor(String serverId) => null;

  @override
  Future<void> pingServer(Server server) async {}
}

class _Servers extends ServerState {
  @override
  Future<void> loadServers({bool forceRefresh = false}) async {}

  @override
  int? getPingResult(String serverId) => 42;

  @override
  Future<void> pingServer(Server server) async {}
}

/// A tunnel that has just failed, so the home screen carries its tallest
/// content: the error bar with its advice and diagnosis under the card.
class _FailedVpn extends VpnService {
  static const _diag = {
    'control': 'ok',
    'dns': 'ok',
    'tcp': 'timeout',
    'tls': 'skipped',
  };
  static const _reason = 'Server not working, try another';

  @override
  VpnStatus get status => VpnStatus.error;

  @override
  bool get isConnected => false;

  @override
  bool get isConnecting => false;

  @override
  bool get isVerifying => false;

  @override
  ConnectionInfo? get currentConnection => null;

  @override
  String? get errorMessage => _reason;

  @override
  Map<String, dynamic>? get lastDiagnosis => _diag;

  @override
  FailureVerdict? get failureVerdict => verdictFor(diag: _diag, error: _reason);

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void clearError() {}
}

/// What the platform answers for a QR code: a fixed 21 by 21 pattern.
Map<String, Object> _qrReply() => {
  'size': 21,
  'modules': Uint8List.fromList(
    List.generate(21 * 21, (i) => i.isEven ? 1 : 0),
  ),
};

void main() {
  late List<String> launched;
  late List<String> encoded;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    launched = [];
    encoded = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_tunnel, (call) async {
      switch (call.method) {
        case 'getStatus':
          return 'disconnected';
        case 'qrModules':
          encoded.add((call.arguments as Map)['text'] as String);
          return _qrReply();
      }
      return null;
    });
    messenger.setMockStreamHandler(
      _statusChannel,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    messenger.setMockMethodCallHandler(_launcher, (call) async {
      if (call.method == 'launch') {
        launched.add((call.arguments as Map)['url'] as String);
        return true;
      }
      return call.method == 'canLaunch';
    });
  });

  tearDown(() {
    FormFactor.isTvForTest = false;
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_tunnel, null);
    messenger.setMockStreamHandler(_statusChannel, null);
    messenger.setMockMethodCallHandler(_launcher, null);
  });

  group('FormFactor.isWide', () {
    test('a TV and a tablet on its side are wide', () {
      expect(FormFactor.isWide(const Size(960, 540)), isTrue);
      expect(FormFactor.isWide(const Size(1280, 720)), isTrue);
      expect(FormFactor.isWide(const Size(1280, 800)), isTrue);
    });

    test('a phone, upright or not, is not', () {
      expect(FormFactor.isWide(const Size(390, 844)), isFalse);
      expect(FormFactor.isWide(const Size(700, 390)), isFalse);
      // The Windows window.
      expect(FormFactor.isWide(const Size(420, 720)), isFalse);
    });
  });

  group('Tappable', () {
    testWidgets('the remote can move to it and press it', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Center(
              child: Tappable(onTap: () => taps++, child: const Text('Ping')),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        Focus.of(tester.element(find.text('Ping'))).hasPrimaryFocus,
        isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(taps, 1);

      await tester.tap(find.text('Ping'));
      expect(taps, 2);
    });

    testWidgets('without a tap it stays out of the remote\'s way', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const Scaffold(
            body: Center(child: Tappable(onTap: null, child: Text('Nothing'))),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        Focus.of(tester.element(find.text('Nothing'))).hasPrimaryFocus,
        isFalse,
      );
    });
  });

  group('PowerButton', () {
    testWidgets('the remote\'s centre button presses it', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var taps = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Center(
              child: PowerButton(
                status: VpnStatus.disconnected,
                isVerifying: false,
                focusNode: focus,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 2);
    });

    testWidgets('keeps the focus while the tunnel comes down, and ignores '
        'presses then', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var taps = 0;
      Widget button(VpnStatus status) => _app(
        Scaffold(
          body: Center(
            child: PowerButton(
              status: status,
              isVerifying: false,
              focusNode: focus,
              onTap: () => taps++,
            ),
          ),
        ),
      );
      await tester.pumpWidget(button(VpnStatus.connected));
      focus.requestFocus();
      await tester.pump();

      await tester.pumpWidget(button(VpnStatus.disconnecting));
      await tester.pump();
      expect(focus.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 0);
    });
  });

  group('ReadableWidth', () {
    testWidgets('keeps a phone screen to a column on a TV', (tester) async {
      _tvScreen(tester);
      late Size seen;
      await tester.pumpWidget(
        _app(
          ReadableWidth(
            child: Builder(
              builder: (context) {
                seen = MediaQuery.sizeOf(context);
                return const Scaffold(body: SizedBox.expand(key: Key('page')));
              },
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(const Key('page'))).width, 720);
      expect(seen, const Size(720, 540));
    });

    testWidgets('leaves a phone alone', (tester) async {
      _phoneScreen(tester);
      await tester.pumpWidget(
        _app(
          const ReadableWidth(
            child: Scaffold(body: SizedBox.expand(key: Key('page'))),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(const Key('page'))).width, 390);
    });
  });

  group('openOutside', () {
    testWidgets('on a TV, shows a Telegram link as a code for a phone', (
      tester,
    ) async {
      FormFactor.isTvForTest = true;
      await tester.pumpWidget(_app(const Scaffold()));

      final shown = openOutside(Uri.parse('https://t.me/fortiva_vpn'));
      await tester.pumpAndSettle();

      expect(encoded, ['https://t.me/fortiva_vpn']);
      expect(launched, isEmpty);
      expect(find.text('Open on your phone'), findsOneWidget);
      expect(find.text('t.me/fortiva_vpn'), findsOneWidget);
      expect(find.byType(QrCode), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(await shown, isTrue);
      expect(find.byType(QrCode), findsNothing);
    });

    testWidgets('on a TV, still opens the Play Store, which is there', (
      tester,
    ) async {
      FormFactor.isTvForTest = true;
      await tester.pumpWidget(_app(const Scaffold()));

      const play = 'https://play.google.com/store/account/subscriptions';
      expect(await openOutside(Uri.parse(play)), isTrue);
      await tester.pumpAndSettle();

      expect(launched, [play]);
      expect(find.byType(QrCode), findsNothing);
    });

    testWidgets('on a phone, opens the link as before', (tester) async {
      await tester.pumpWidget(_app(const Scaffold()));

      expect(await openOutside(Uri.parse('https://t.me/fortiva_vpn')), isTrue);
      await tester.pumpAndSettle();

      expect(launched, ['https://t.me/fortiva_vpn']);
      expect(encoded, isEmpty);
    });

    test('the link under the code reads as it would be typed', () {
      expect(
        LinkQrDialog.readable(Uri.parse('https://fortivavpn.com/')),
        'fortivavpn.com',
      );
      expect(
        LinkQrDialog.readable(Uri.parse('https://fortivavpn.com/privacy')),
        'fortivavpn.com/privacy',
      );
    });
  });

  group('RemoteRefreshButton', () {
    testWidgets('draws nothing on a phone', (tester) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            appBar: AppBar(
              actions: [RemoteRefreshButton(onRefresh: () async {})],
            ),
          ),
        ),
      );
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('refreshes on a TV', (tester) async {
      FormFactor.isTvForTest = true;
      var refreshes = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            appBar: AppBar(
              actions: [
                RemoteRefreshButton(onRefresh: () async => refreshes++),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pump();
      expect(refreshes, 1);
      await _settleFocus(tester);
    });
  });

  group('FocusRing', () {
    testWidgets('on a TV, a screen that opens with nothing focused gives '
        'its first control the focus', (tester) async {
      FormFactor.isTvForTest = true;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Column(
              children: [
                TextButton(onPressed: () {}, child: const Text('First')),
                TextButton(onPressed: () {}, child: const Text('Second')),
              ],
            ),
          ),
        ),
      );
      await _settleFocus(tester);
      expect(
        Focus.of(tester.element(find.text('First'))).hasPrimaryFocus,
        isTrue,
      );
    });

    // The ring's own painter, over the whole app.
    final ring = find.byWidgetPredicate(
      (w) => w is CustomPaint && '${w.painter.runtimeType}' == '_RingPainter',
    );

    Future<void> focusField(WidgetTester tester) async {
      // A key press puts a phone in keyboard mode; an emulator typing from
      // the computer's keyboard does the same.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await tester.pumpWidget(
        _app(
          const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(40),
              child: TextField(autofocus: true),
            ),
          ),
        ),
      );
      await _settleFocus(tester);
      await tester.pump();
    }

    testWidgets('on a phone, draws no second border inside a focused text '
        'field, even in keyboard mode', (tester) async {
      await focusField(tester);
      expect(
        FocusManager.instance.highlightMode,
        FocusHighlightMode.traditional,
      );
      expect(tester.renderObject(ring), paintsNothing);
    });

    testWidgets('on a TV, rings the focused control', (tester) async {
      FormFactor.isTvForTest = true;
      await focusField(tester);
      // The soft glow first, then the ring itself. The glow is a plain
      // wide stroke at low alpha: a blurred one costs a blur pass on every
      // frame the ring moves.
      expect(
        tester.renderObject(ring),
        paints
          ..rrect(
            style: PaintingStyle.stroke,
            strokeWidth: 9,
            color: FocusRing.color.withValues(alpha: 0.12),
          )
          ..rrect(color: FocusRing.color),
      );
    });

    testWidgets('on a phone, leaves the focus where it was', (tester) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: TextButton(onPressed: () {}, child: const Text('First')),
          ),
        ),
      );
      await _settleFocus(tester);
      expect(
        Focus.of(tester.element(find.text('First'))).hasPrimaryFocus,
        isFalse,
      );
    });
  });

  group('Home on a TV', () {
    Future<void> pumpHome(WidgetTester tester) async {
      final vpn = _FailedVpn();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DedicatedState>.value(
              value: _FakeDedicated(),
            ),
            ChangeNotifierProvider<ServerState>.value(value: _Servers()),
            ChangeNotifierProvider<VpnService>.value(value: vpn),
            ChangeNotifierProvider<ConnectFlow>(
              create: (_) => ConnectFlow(vpn: vpn),
            ),
            ChangeNotifierProvider<LocaleState>(create: (_) => LocaleState()),
          ],
          child: _app(const HomeScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
    }

    testWidgets('puts the button beside the server card, and it all fits', (
      tester,
    ) async {
      FormFactor.isTvForTest = true;
      _tvScreen(tester);
      await pumpHome(tester);

      // A RenderFlex overflow is reported as an exception.
      expect(tester.takeException(), isNull);
      final button = tester.getRect(find.byType(PowerButton));
      final card = tester.getRect(find.text('Falkenstein, Germany'));
      expect(button.right, lessThanOrEqualTo(card.left));
      expect(card.bottom, lessThanOrEqualTo(540));
      expect(find.textContaining('cannot be reached'), findsOneWidget);
    });

    testWidgets('leaves the button room for its glow and its ring', (
      tester,
    ) async {
      FormFactor.isTvForTest = true;
      _tvScreen(tester);
      await pumpHome(tester);
      final button = tester.getRect(find.byType(PowerButton));
      final view = tester.getRect(
        find
            .ancestor(
              of: find.byType(PowerButton),
              matching: find.byType(SingleChildScrollView),
            )
            .first,
      );
      // The ring that grows out of the button when the tunnel comes up
      // reaches 0.35 of the radius past its edge, the glow 0.18. The view
      // cuts what it scrolls, so all of that is inside it.
      final reach = button.inflate(button.width / 2 * 0.35);
      expect(view.left, lessThanOrEqualTo(reach.left));
      expect(view.top, lessThanOrEqualTo(reach.top));
      expect(view.right, greaterThanOrEqualTo(reach.right));
    });

    testWidgets('on a short wide window the room above the button gives '
        'way, and the status line stays in view', (tester) async {
      // A tablet in split screen, one app above the other: the button's
      // column fits, but not with 40dp kept above it as well.
      tester.view.physicalSize = const Size(1280, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpHome(tester);
      expect(tester.takeException(), isNull);
      final l10n = await S.delegate.load(const Locale('en'));
      final view = tester.getRect(
        find
            .ancestor(
              of: find.byType(PowerButton),
              matching: find.byType(SingleChildScrollView),
            )
            .first,
      );
      final button = tester.getRect(find.byType(PowerButton));
      final status = tester.getRect(find.text(l10n.errorConnectionFailed));
      expect(button.top, greaterThan(view.top));
      expect(button.top - view.top, lessThan(40));
      expect(status.bottom, lessThanOrEqualTo(view.bottom));
    });

    testWidgets('starts the remote on the power button, and right moves it '
        'to the connection', (tester) async {
      FormFactor.isTvForTest = true;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      _tvScreen(tester);
      await pumpHome(tester);

      final power = Focus.of(
        tester.element(
          find.descendant(
            of: find.byType(PowerButton),
            matching: find.byType(GestureDetector),
          ),
        ),
      );
      expect(power.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(power.hasPrimaryFocus, isFalse);
      final focused = FocusManager.instance.primaryFocus!.rect;
      expect(
        focused.left,
        greaterThanOrEqualTo(tester.getRect(find.byType(PowerButton)).right),
      );
    });

    testWidgets('a phone keeps the one column', (tester) async {
      _phoneScreen(tester);
      await pumpHome(tester);
      expect(tester.takeException(), isNull);
      final button = tester.getRect(find.byType(PowerButton));
      final card = tester.getRect(find.text('Falkenstein, Germany'));
      expect(card.top, greaterThan(button.bottom));
    });
  });
}
