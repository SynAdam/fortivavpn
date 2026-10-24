import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/device_state.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/core/state/message_state.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/connection_info.dart';
import 'package:fortiva_vpn/data/models/device.dart';
import 'package:fortiva_vpn/data/models/in_app_message.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/data/models/version_info.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/home_screen.dart';
import 'package:fortiva_vpn/screens/inbox_screen.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/message_bell.dart';
import 'package:fortiva_vpn/widgets/message_dialog.dart';
import 'package:fortiva_vpn/widgets/power_button.dart';
import 'package:fortiva_vpn/widgets/update_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/app_theme.dart';

/// The properties worth pinning: a message can never get in the way of
/// connecting, it pops up only once the tunnel has settled and nothing else
/// has the screen, it gives way to the update dialog, and its text reads in
/// its own direction whatever language the app is in.

const _shared = Server(
  id: 'official-1',
  name: 'DE Falkenstein',
  country: 'Germany',
  city: 'Falkenstein',
  connectionUri: 'vless://u@198.51.100.201:443?security=reality#DE',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
);

const _persianBody = 'نسخه‌ی تازه‌ی Fortiva آمده است. از کانال بگیرید.';

/// A message as the backend sends it, sent a minute ago.
Map<String, dynamic> wire(
  int id, {
  String language = 'en',
  String? title,
  String? body,
  String? button,
  String? link,
}) {
  final sent = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
  return {
    'id': id,
    'language': language,
    'title': title ?? 'News $id',
    'body': body ?? 'Body of message $id.',
    'button': button,
    'link': link,
    'sent_at': sent.toIso8601String(),
    'ends_at': sent.add(const Duration(days: 7)).toIso8601String(),
  };
}

InAppMessage message(
  int id, {
  String language = 'en',
  String? title,
  String? body,
  String? button,
  String? link,
}) => InAppMessage.tryParse(
  wire(
    id,
    language: language,
    title: title,
    body: body,
    button: button,
    link: link,
  ),
)!;

/// A MessageState whose checks answer [messages] and whose receipts are
/// kept on the phone for the test to read. Created by the provider, so the
/// tree disposes it.
MessageState messagesWith(
  List<Map<String, dynamic>> messages, {
  String language = 'en',
}) => MessageState(
  fetch: (_, _) async => MessagesPage.fromJson({
    'server_time': DateTime.now().toUtc().toIso8601String(),
    'messages': messages,
  }),
  post: (_, _) async {},
  deviceId: () async => 'DEV-1',
  register: () async {},
  language: () => language,
  flushDelay: const Duration(days: 1),
);

/// The receipts waiting on the phone, as `id:kind`.
Future<List<String>> queued() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(MessageState.receiptsKey);
  if (raw == null) return [];
  final matches = RegExp(r'"message_id":(\d+),"kind":"(\w+)"').allMatches(raw);
  return [for (final m in matches) '${m.group(1)}:${m.group(2)}'];
}

class _FakeDedicated extends DedicatedState {
  @override
  QuotaStatus? get quota => null;

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

class _FakeServers extends ServerState {
  @override
  Server? get selectedServer => _shared;

  @override
  Future<void> loadServers({bool forceRefresh = false}) async {}

  @override
  int? getPingResult(String serverId) => 42;

  @override
  Future<void> pingServer(Server server) async {}
}

/// Records what the screen asks of the tunnel instead of dialling, and
/// lets a test move it between states.
class _FakeVpn extends VpnService {
  VpnStatus _fake;
  bool verifying = false;
  int connects = 0;
  int disconnects = 0;

  _FakeVpn({VpnStatus status = VpnStatus.disconnected}) : _fake = status;

  void become(VpnStatus status, {bool verifying = false}) {
    _fake = status;
    this.verifying = verifying;
    notifyListeners();
  }

  @override
  VpnStatus get status => _fake;

  @override
  bool get isConnected => _fake == VpnStatus.connected;

  @override
  bool get isConnecting => _fake == VpnStatus.connecting;

  @override
  bool get isVerifying => verifying;

  @override
  ConnectionInfo? get currentConnection => null;

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {
    connects++;
  }

  @override
  Future<void> disconnect() async {
    disconnects++;
    become(VpnStatus.disconnected);
  }
}

/// A device the backend knows as row [id].
class _FakeDevice extends DeviceState {
  _FakeDevice(this.id);

  final int id;

  @override
  Device? get device => Device(
    id: id,
    deviceId: 'DEV-1',
    platform: 'android',
    appVersion: '1.6.11',
    isPremium: false,
    createdAt: DateTime.utc(2026),
  );
}

/// A MessageState that fails on every read, standing in for a bug in it.
class _BrokenMessages extends MessageState {
  _BrokenMessages()
    : super(
        fetch: (_, _) async => throw StateError('broken'),
        post: (_, _) async {},
        deviceId: () async => 'DEV-1',
        register: () async {},
      );

  @override
  int get unreadCount => throw StateError('broken');

  @override
  InAppMessage? get pendingPopup => throw StateError('broken');

  @override
  List<InAppMessage> get messages => throw StateError('broken');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
  const statusChannel = EventChannel('com.vpn.fortivavpn/tunnel/status');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UpdateDialog.resetForTest();
    MessageDialog.resetForTest();
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

  /// A plain screen to open dialogs and pages from.
  Future<BuildContext> pumpHost(
    WidgetTester tester, {
    MessageState? messages,
    DeviceState? device,
    Locale locale = const Locale('en'),
    Widget? child,
  }) async {
    late BuildContext host;
    final app = MaterialApp(
      locale: locale,
      theme: appThemeFor(locale),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: Builder(
        builder: (context) {
          host = context;
          return Scaffold(body: child ?? const SizedBox.shrink());
        },
      ),
    );
    await tester.pumpWidget(
      messages == null && device == null
          ? app
          : MultiProvider(
              key: UniqueKey(),
              providers: [
                if (messages != null)
                  ChangeNotifierProvider<MessageState>(
                    lazy: false,
                    create: (_) => messages,
                  ),
                if (device != null)
                  ChangeNotifierProvider<DeviceState>.value(value: device),
              ],
              child: app,
            ),
    );
    await tester.pump();
    return host;
  }

  /// The home screen, as the app builds it, with [messages] above it.
  Future<_FakeVpn> pumpHome(
    WidgetTester tester, {
    MessageState? messages,
    VpnStatus status = VpnStatus.disconnected,
  }) async {
    final vpn = _FakeVpn(status: status);
    // On screen, as when the user opens the app. The test binding starts
    // with no lifecycle state at all, and a popup waits for resumed.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(value: _FakeDedicated()),
          ChangeNotifierProvider<ServerState>.value(value: _FakeServers()),
          ChangeNotifierProvider<VpnService>.value(value: vpn),
          ChangeNotifierProvider<ConnectFlow>(
            create: (_) => ConnectFlow(vpn: vpn),
          ),
          ChangeNotifierProvider<LocaleState>(create: (_) => LocaleState()),
          if (messages != null)
            ChangeNotifierProvider<MessageState>(
              lazy: false,
              create: (_) => messages,
            ),
        ],
        child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: const Locale('en'),
          theme: appThemeFor(const Locale('en')),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    return vpn;
  }

  /// The power button animates while connected, so the home screen never
  /// settles; a dialog's transition is over well within this.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// Bring the tunnel down at the end of a test, which stops the timers
  /// the service runs while connected.
  Future<void> down(WidgetTester tester, _FakeVpn vpn) async {
    vpn.become(VpnStatus.disconnected);
    await tester.pump(const Duration(seconds: 1));
  }

  Finder messageDialog() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text('Body of message 1.'),
  );

  group('bell', () {
    testWidgets('shows how many messages are unread', (tester) async {
      final messages = messagesWith([wire(1), wire(2)]);
      await messages.refresh();
      await pumpHost(tester, messages: messages, child: const MessageBell());
      expect(find.byTooltip('Messages'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      await messages.markAllRead();
      await tester.pump();
      expect(find.text('2'), findsNothing);
      expect(find.byTooltip('Messages'), findsOneWidget);
    });

    testWidgets('draws nothing without a MessageState above it', (
      tester,
    ) async {
      await pumpHost(tester, child: const MessageBell());
      expect(find.byType(IconButton), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens the inbox', (tester) async {
      final messages = messagesWith([wire(1)]);
      await messages.refresh();
      await pumpHost(tester, messages: messages, child: const MessageBell());
      await tester.tap(find.byTooltip('Messages'));
      await tester.pumpAndSettle();
      expect(find.byType(InboxScreen), findsOneWidget);
      expect(find.text('Body of message 1.'), findsOneWidget);
    });
  });

  group('home screen', () {
    testWidgets('a broken MessageState leaves the connect button working', (
      tester,
    ) async {
      final vpn = await pumpHome(
        tester,
        messages: _BrokenMessages(),
        status: VpnStatus.connected,
      );
      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
      expect(find.byType(PowerButton), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(find.byType(PowerButton));
      await tester.pump(const Duration(seconds: 3));
      expect(vpn.disconnects, 1);
    });

    testWidgets('pops up only after five settled seconds connected', (
      tester,
    ) async {
      final messages = messagesWith([wire(1)]);
      await messages.refresh();
      final vpn = await pumpHome(tester, messages: messages);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);

      // Disconnected, connecting and verifying never pop up.
      await tester.pump(const Duration(seconds: 10));
      expect(messageDialog(), findsNothing);
      vpn.become(VpnStatus.connecting);
      await tester.pump(const Duration(seconds: 10));
      expect(messageDialog(), findsNothing);
      vpn.become(VpnStatus.connected, verifying: true);
      await tester.pump(const Duration(seconds: 10));
      expect(messageDialog(), findsNothing);

      // Checked: not yet within five seconds.
      vpn.become(VpnStatus.connected);
      await tester.pump(const Duration(seconds: 4));
      expect(messageDialog(), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(messageDialog(), findsOneWidget);
      expect(find.text('News 1'), findsOneWidget);
      expect(await queued(), contains('1:shown'));

      // Once only.
      await tester.tap(find.text('Close'));
      await settle(tester);
      expect(await queued(), contains('1:dismissed'));
      vpn.become(VpnStatus.disconnected);
      vpn.become(VpnStatus.connected);
      await tester.pump(const Duration(seconds: 10));
      expect(messageDialog(), findsNothing);
      await down(tester, vpn);
    });

    testWidgets('a drop within the five seconds starts the wait again', (
      tester,
    ) async {
      final messages = messagesWith([wire(1)]);
      await messages.refresh();
      final vpn = await pumpHome(tester, messages: messages);
      vpn.become(VpnStatus.connected);
      await tester.pump(const Duration(seconds: 4));
      vpn.become(VpnStatus.disconnected);
      vpn.become(VpnStatus.connected);
      await tester.pump(const Duration(seconds: 4));
      expect(messageDialog(), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(messageDialog(), findsOneWidget);
      await down(tester, vpn);
    });

    testWidgets('never pops up while the app is in the background', (
      tester,
    ) async {
      final messages = messagesWith([wire(1)]);
      await messages.refresh();
      final vpn = await pumpHome(tester, messages: messages);
      vpn.become(VpnStatus.connected);
      await tester.pump(const Duration(seconds: 2));
      // The user leaves as soon as the button turns green. One step at a
      // time, as the engine reports it.
      for (final state in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump(const Duration(seconds: 10));
      expect(messageDialog(), findsNothing);
      expect(await queued(), isNot(contains('1:shown')));
      expect(messages.unreadCount, 1);

      // Back on screen, the five seconds start again.
      for (final state in const [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump(const Duration(seconds: 4));
      expect(messageDialog(), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(messageDialog(), findsOneWidget);
      expect(await queued(), contains('1:shown'));
      await down(tester, vpn);
    });

    testWidgets('waits while the update dialog is up', (tester) async {
      final messages = messagesWith([wire(1)]);
      await messages.refresh();
      final vpn = await pumpHome(
        tester,
        messages: messages,
        status: VpnStatus.connected,
      );
      final home = tester.element(find.byType(HomeScreen));
      unawaited(
        UpdateDialog.maybeShow(
          home,
          ForceUpdate(ios: _update(), android: _update()),
          currentVersion: '1.4.1',
          android: true,
          open: (_) async {},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(UpdateDialog.isShowing, isTrue);
      await tester.pump(const Duration(seconds: 12));
      expect(messageDialog(), findsNothing);
      expect(messages.unreadCount, 1);
      await down(tester, vpn);
    });

    testWidgets('the update dialog takes the place of an open message', (
      tester,
    ) async {
      final messages = messagesWith([wire(1)]);
      await messages.refresh();
      final vpn = await pumpHome(
        tester,
        messages: messages,
        status: VpnStatus.connected,
      );
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(messageDialog(), findsOneWidget);
      expect(MessageDialog.isShowing, isTrue);
      expect(messages.unreadCount, 0);

      final home = tester.element(find.byType(HomeScreen));
      unawaited(
        UpdateDialog.maybeShow(
          home,
          ForceUpdate(ios: _update(), android: _update()),
          currentVersion: '1.4.1',
          android: true,
          open: (_) async {},
        ),
      );
      await settle(tester);
      expect(messageDialog(), findsNothing);
      expect(MessageDialog.isShowing, isFalse);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(UpdateDialog.isShowing, isTrue);
      // Not closed by the user: no dismissed, and back in the inbox unread.
      expect(await queued(), isNot(contains('1:dismissed')));
      expect(messages.unreadCount, 1);
      await down(tester, vpn);
    });

    testWidgets('a message in another language does not pop up', (
      tester,
    ) async {
      final messages = messagesWith([wire(1, language: 'fa')]);
      await messages.refresh();
      final vpn = await pumpHome(
        tester,
        messages: messages,
        status: VpnStatus.connected,
      );
      await tester.pump(const Duration(seconds: 10));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('1'), findsOneWidget);
      await down(tester, vpn);
    });
  });

  group('inbox', () {
    testWidgets('a Persian message reads right to left in an English app', (
      tester,
    ) async {
      final messages = messagesWith([
        wire(
          1,
          language: 'fa',
          title: 'نسخه‌ی تازه',
          body: _persianBody,
          button: 'کانال',
          link: 'https://t.me/fortiva_vpn',
        ),
        wire(2, body: 'An English one.'),
      ]);
      await messages.refresh();
      final opened = <Uri>[];
      await pumpHost(
        tester,
        messages: messages,
        device: _FakeDevice(4242),
        child: InboxScreen(open: (url) async => opened.add(url)),
      );
      await tester.pump();

      expect(find.text('Messages'), findsOneWidget);
      TextDirection direction(String text) =>
          Directionality.of(tester.element(find.text(text)));
      expect(direction(_persianBody), TextDirection.rtl);
      expect(direction('نسخه‌ی تازه'), TextDirection.rtl);
      expect(direction('کانال'), TextDirection.rtl);
      expect(direction('An English one.'), TextDirection.ltr);
      final persian = tester.widget<Text>(find.text(_persianBody));
      expect(persian.style?.fontFamily, 'Vazirmatn');
      // Letter spacing breaks the joins of Persian letters, so a message in
      // a joined script has none, even in an English app.
      expect(persian.style?.letterSpacing, 0);
      expect(tester.widget<Text>(find.text('کانال')).style?.letterSpacing, 0);

      // The phone's number on our side, for a test send.
      expect(find.text('ID 4242'), findsOneWidget);

      // Opening it counts everything listed as seen.
      expect(messages.unreadCount, 0);
      expect(await queued(), containsAll(['1:shown', '2:shown']));

      await tester.tap(find.text('کانال'));
      await tester.pump();
      expect(opened, [Uri.parse('https://t.me/fortiva_vpn')]);
      expect(await queued(), contains('1:clicked'));
    });

    testWidgets('says so when there is nothing', (tester) async {
      final messages = messagesWith([]);
      await pumpHost(tester, messages: messages, child: const InboxScreen());
      await tester.pump();
      expect(find.text('No messages right now.'), findsOneWidget);
      expect(find.textContaining('ID '), findsNothing);
      // A quiet bell over the line, not a line alone.
      expect(
        find.descendant(
          of: find
              .ancestor(
                of: find.text('No messages right now.'),
                matching: find.byType(Column),
              )
              .first,
          matching: find.byIcon(Icons.notifications_off_outlined),
        ),
        findsOneWidget,
      );
    });
  });

  group('dialog', () {
    Future<(BuildContext, MessageState)> open(
      WidgetTester tester,
      InAppMessage m, {
      List<Uri>? opened,
      Locale locale = const Locale('en'),
    }) async {
      final messages = messagesWith([]);
      final host = await pumpHost(tester, messages: messages, locale: locale);
      unawaited(
        MessageDialog.show(
          host,
          m,
          state: messages,
          open: (url) async => opened?.add(url),
        ),
      );
      await tester.pumpAndSettle();
      return (host, messages);
    }

    testWidgets('Close reports dismissed', (tester) async {
      await open(tester, message(1));
      expect(MessageDialog.isShowing, isTrue);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(MessageDialog.isShowing, isFalse);
      expect(await queued(), ['1:shown', '1:dismissed']);
    });

    testWidgets('a tap outside reports dismissed', (tester) async {
      await open(tester, message(1));
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(await queued(), ['1:shown', '1:dismissed']);
    });

    testWidgets('the button reports clicked, opens the link and closes', (
      tester,
    ) async {
      final opened = <Uri>[];
      await open(
        tester,
        message(1, button: 'Get it', link: 'https://fortivavpn.com/x'),
        opened: opened,
      );
      await tester.tap(find.text('Get it'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(opened, [Uri.parse('https://fortivavpn.com/x')]);
      expect(await queued(), ['1:shown', '1:clicked']);
    });

    testWidgets('Close follows the app language, the text its own', (
      tester,
    ) async {
      await open(
        tester,
        message(1, body: 'In English.'),
        locale: const Locale('fa'),
      );
      expect(find.text('بستن'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('بستن'))),
        TextDirection.rtl,
      );
      expect(
        Directionality.of(tester.element(find.text('In English.'))),
        TextDirection.ltr,
      );
    });

    testWidgets('fits a small phone in every language, at any text size', (
      tester,
    ) async {
      // 320 by 568 points, the smallest phone screen in common use, with the
      // longest message the backend accepts: a 120 character title, 1500
      // characters of text and a 40 character button. The test font draws
      // every glyph a full em wide, wider than any real font.
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      String fill(String word, int length) =>
          (word * (length ~/ word.length + 1)).substring(0, length).trim();

      for (final scale in [1.0, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        for (final locale in S.supportedLocales) {
          // A message in the other direction from the app's.
          final appRtl = const {'fa', 'ar', 'ur'}.contains(locale.languageCode);
          final language = appRtl ? 'en' : 'fa';
          final word = appRtl ? 'Message ' : 'پیام ';
          final m = InAppMessage(
            id: 1,
            language: language,
            title: fill(word, 120),
            body: fill(word, 1500),
            button: fill(word, 40),
            link: Uri.parse('https://t.me/fortiva_vpn'),
            sentAt: DateTime.now().toUtc(),
            endsAt: DateTime.now().toUtc().add(const Duration(days: 1)),
          );
          final reason = '$locale, text x$scale, message in $language';
          MessageDialog.resetForTest();
          await open(tester, m, locale: locale);
          expect(tester.takeException(), isNull, reason: reason);

          final buttons = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byWidgetPredicate(
              (w) => w is FilledButton || w is TextButton,
            ),
          );
          expect(buttons, findsNWidgets(2), reason: reason);
          for (var i = 0; i < 2; i++) {
            final rect = tester.getRect(buttons.at(i));
            expect(rect.left, greaterThanOrEqualTo(0), reason: reason);
            expect(rect.right, lessThanOrEqualTo(320), reason: reason);
            expect(rect.top, greaterThanOrEqualTo(0), reason: reason);
            expect(rect.bottom, lessThanOrEqualTo(568), reason: reason);
          }

          // The text scrolls rather than pushing the buttons off.
          final scroll = tester.state<ScrollableState>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Scrollable),
            ),
          );
          expect(
            scroll.position.maxScrollExtent,
            greaterThan(0),
            reason: reason,
          );

          await tester.tap(find.byType(TextButton));
          await tester.pumpAndSettle();
        }
      }
    });
  });
}

PlatformVersion _update() => PlatformVersion(
  latestVersion: '9.9.9',
  minimumVersion: '1.0.0',
  updateRequired: false,
  updateUrl: 'https://play.google.com/store/apps/details?id=com.vpn.fortivavpn',
  releaseNotes: null,
);
