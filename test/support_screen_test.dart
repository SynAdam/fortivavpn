import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/api/support_service.dart';
import 'package:fortiva_vpn/core/design_system.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/core/state/support_state.dart';
import 'package:fortiva_vpn/data/models/connection_info.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/data/models/support_chat.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/home_screen.dart';
import 'package:fortiva_vpn/screens/support_screen.dart';
import 'package:fortiva_vpn/services/failure_verdict.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/chatbot_glyph.dart';
import 'package:fortiva_vpn/widgets/focus_ring.dart';
import 'package:fortiva_vpn/widgets/power_button.dart';
import 'package:fortiva_vpn/widgets/support_button.dart';
import 'package:fortiva_vpn/widgets/support_thinking.dart';
import 'package:fortiva_vpn/widgets/tappable.dart';
import 'package:fortiva_vpn/widgets/typed_text.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/app_theme.dart';

/// The properties worth pinning: the chatbot button never gets in the way
/// of the connect button or the lines around it, the input stops at 500
/// code points with a counter from 400, a reached limit says until when and
/// offers no way around it, a waiting question shows the assistant
/// thinking, a reply that arrives while the chat is open is typed out
/// (never one from before, and never with less motion asked for), every
/// code the backend can send reads as a line in all 18 languages, and text
/// is laid out in its own direction in either app direction.

final _t0 = DateTime.utc(2026, 10, 7, 12);

Map<String, dynamic> quotaJson({
  int remaining = 7,
  int conversationLeft = 4,
  Duration resetsIn = const Duration(hours: 8),
}) => {
  'limit': 10,
  'remaining': remaining,
  'conversation_limit': 6,
  'conversation_left': conversationLeft,
  'resets_at': _t0.add(resetsIn).toIso8601String(),
  'conversation_resets_at': null,
  'paused_until': null,
  'server_time': _t0.toIso8601String(),
};

Map<String, dynamic> wire(
  int id, {
  String role = 'assistant',
  String status = 'sent',
  String? code,
  String text = 'Text',
  DateTime? at,
}) => {
  'id': id,
  'role': role,
  'status': status,
  'code': code,
  'redacted': false,
  'text': text,
  'rating': null,
  'created_at': (at ?? _t0.add(Duration(seconds: id))).toIso8601String(),
};

class _Backend implements SupportService {
  _Backend({
    this.enabled = true,
    this.mode = 'ai',
    Map<String, dynamic>? quota,
    this.pending = false,
    this.messages = const [],
    this.ticket = 'none',
    this.clock,
  }) : quota = quota ?? quotaJson();

  /// The server's clock in every answer. Fixed at the test's start when
  /// not given.
  final DateTime Function()? clock;
  String get serverTime => (clock?.call() ?? _t0).toIso8601String();

  bool enabled;
  String mode;
  Map<String, dynamic> quota;
  bool pending;
  List<Map<String, dynamic>> messages;

  /// Whether our team has the conversation: `none`, `open` or `closed`.
  String ticket;
  Map<String, dynamic> get thread => {'id': 1, 'ticket': ticket};
  final sent = <Map<String, dynamic>>[];
  final rated = <String>[];
  int newCalls = 0;
  Object? sendError;

  /// While set, a send waits for it, so a test can see the message on its
  /// way.
  Completer<void>? hold;

  /// Thrown for messages to our team only, in place of [sendError].
  Object? staffError;

  @override
  Future<SupportStatus> status(String deviceId) async => SupportStatus.fromJson(
    enabled
        ? {
            'enabled': true,
            'mode': mode,
            'quota': quota,
            'thread': thread,
            'pending': pending,
            'server_time': serverTime,
          }
        : {'enabled': false},
  );

  /// How many times the conversation was fetched.
  int fetchCalls = 0;

  @override
  Future<SupportPage> fetch(String deviceId, int after, String lang) async {
    fetchCalls++;
    return SupportPage.fromJson({
      'mode': mode,
      'quota': quota,
      'thread': thread,
      'pending': pending,
      'server_time': serverTime,
      'messages': [
        for (final m in messages)
          if ((m['id'] as int) > after) m,
      ],
    });
  }

  @override
  Future<SupportReply> send(String deviceId, Map<String, dynamic> body) async {
    await hold?.future;
    final error = body['to'] == 'staff' ? staffError ?? sendError : sendError;
    if (error != null) throw error;
    sent.add(body);
    return SupportReply.fromJson({
      'message': wire(
        200 + sent.length,
        role: 'user',
        status: body['to'] == 'staff' ? 'to_staff' : 'queued',
        text: body['text'] as String,
      ),
      'quota': quota,
      'thread': thread,
      'mode': mode,
      'server_time': serverTime,
    });
  }

  @override
  Future<void> rate(String deviceId, int messageId, String value) async {
    rated.add('$messageId:$value');
  }

  @override
  Future<SupportReply> startNew(String deviceId) async {
    newCalls++;
    quota = quotaJson(conversationLeft: 6);
    return SupportReply.fromJson({'quota': quota});
  }
}

SupportState _chatWith(_Backend backend, {DateTime Function()? clock}) =>
    SupportState(
      service: backend,
      deviceId: () async => 'DEV-1',
      register: () async {},
      sharing: () async => false,
      language: () => 'en',
      clock: clock ?? () => _t0,
      foreground: () => true,
    );

/// A 429 as the backend sends it, asking to wait [wait].
ApiException _tooSoon(String code, Duration wait) => ApiException(
  statusCode: 429,
  message: code,
  body: {
    'detail': {'code': code, 'retry_at': _t0.add(wait).toIso8601String()},
  },
);

/// A SupportState that fails on every read, standing in for a bug in it.
class _BrokenSupport extends SupportState {
  _BrokenSupport() : super(service: _Backend(), deviceId: () async => 'DEV-1');

  @override
  bool get enabled => throw StateError('broken');
}

/// A tunnel that has already failed, or, with [connected], one that is up
/// with the last failure still on screen.
class _FailedVpn extends VpnService {
  _FailedVpn({this.connected = false});

  final bool connected;
  int disconnects = 0;

  @override
  VpnStatus get status => connected ? VpnStatus.connected : VpnStatus.error;

  @override
  bool get isConnected => connected;

  @override
  bool get isConnecting => false;

  @override
  bool get isVerifying => false;

  @override
  ConnectionInfo? get currentConnection => null;

  @override
  String? get errorMessage => 'Server not working, try another';

  @override
  Map<String, dynamic>? get lastDiagnosis => const {'control': 'fail'};

  @override
  FailureVerdict? get failureVerdict => FailureVerdict.noInternet;

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {}

  @override
  Future<void> disconnect() async => disconnects++;

  @override
  void clearError() {}
}

/// A tunnel that is down, with nothing wrong.
class _CalmVpn extends _FailedVpn {
  @override
  VpnStatus get status => VpnStatus.disconnected;

  @override
  String? get errorMessage => null;

  @override
  Map<String, dynamic>? get lastDiagnosis => null;

  @override
  FailureVerdict? get failureVerdict => null;
}

class _Dedicated extends DedicatedState {
  _Dedicated({this.allowance});

  /// Shows the used-today line under the server card when set.
  final QuotaStatus? allowance;

  @override
  QuotaStatus? get quota => allowance;

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
  Future<void> loadServers({bool forceRefresh = false}) async {}

  @override
  int? getPingResult(String serverId) => null;

  @override
  Future<void> pingServer(Server server) async {}
}

const _allCodes = [
  'too_long',
  'empty',
  'wait_reply',
  'slow_down',
  'quota_day',
  'quota_conversation',
  'paused',
  'busy',
  'off',
  'greeting',
  'gibberish',
  'redacted',
  'redacted_empty',
  'injection',
  'abuse',
  'off_topic',
  'ai_unavailable',
  'to_staff',
  'ticket_opened',
  // Only the phone sets this one.
  SupportState.notSent,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  /// The chat screen with [backend] behind it, the status already checked.
  Future<SupportState> pumpChat(
    WidgetTester tester,
    _Backend backend, {
    Locale locale = const Locale('en'),
    Future<void> Function(Uri url)? open,
    DateTime Function()? clock,
  }) async {
    final state = _chatWith(backend, clock: clock);
    await state.checkStatus(force: true);
    await tester.pumpWidget(
      ChangeNotifierProvider<SupportState>(
        // A new tree each time, so a test that pumps twice gets its new
        // state and the old one is disposed.
        key: UniqueKey(),
        create: (_) => state,
        child: MaterialApp(
          locale: locale,
          theme: appThemeFor(locale),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: SupportScreen(open: open),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return state;
  }

  Finder sendButton() => find.widgetWithIcon(IconButton, Icons.send_rounded);

  Finder newChatButton() =>
      find.widgetWithIcon(IconButton, Icons.maps_ugc_outlined);

  bool newChatEnabled(WidgetTester tester) =>
      tester.widget<IconButton>(newChatButton()).onPressed != null;

  /// The color the New conversation icon asks for itself; null leaves it
  /// to the button, which is the color of a working button.
  Color? newChatIconColor(WidgetTester tester) => tester
      .widget<Icon>(
        find.descendant(
          of: newChatButton(),
          matching: find.byIcon(Icons.maps_ugc_outlined),
        ),
      )
      .color;

  bool sendEnabled(WidgetTester tester) =>
      tester.widget<IconButton>(sendButton()).onPressed != null;

  String? hint(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).decoration?.hintText;

  bool inputEnabled(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).enabled ?? true;

  final limitCard = find.byKey(const ValueKey('support-limit'));

  /// Nothing on the limit card can be tapped, and no way to our team or to
  /// a new conversation is offered anywhere but the header's own button.
  void expectNoWayAround(WidgetTester tester) {
    for (final kind in [ButtonStyleButton, InkWell, GestureDetector]) {
      expect(
        find.descendant(of: limitCard, matching: find.byType(kind)),
        findsNothing,
        reason: '$kind on the limit card',
      );
    }
    expect(find.textContaining('our team'), findsNothing);
    expect(find.text('New conversation'), findsNothing);
  }

  /// The text of a reply being typed out, all of it, shown or not.
  InlineSpan typedSpan(WidgetTester tester) => tester
      .widget<RichText>(
        find.descendant(
          of: find.byType(TypedText),
          matching: find.byType(RichText),
        ),
      )
      .text;

  /// What a reply being typed out shows now: the words drawn in a colour
  /// that can be seen.
  String typedSoFar(WidgetTester tester) {
    final out = StringBuffer();
    typedSpan(tester).visitChildren((span) {
      if (span is TextSpan) {
        final alpha = span.style?.color?.a;
        if (alpha == null || alpha > 0) out.write(span.text ?? '');
      }
      return true;
    });
    return out.toString();
  }

  /// The corners of the bubble around [text].
  BorderRadiusDirectional bubbleCorners(WidgetTester tester, Finder text) {
    final box = tester
        .widgetList<Container>(
          find.ancestor(of: text, matching: find.byType(Container)),
        )
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.borderRadius is BorderRadiusDirectional);
    return box.borderRadius! as BorderRadiusDirectional;
  }

  /// The bubble around [text], where it is on screen.
  Rect bubbleRect(WidgetTester tester, Finder text) => tester.getRect(
    find
        .ancestor(of: text, matching: find.byType(Container))
        .evaluate()
        .map((e) => find.byWidget(e.widget))
        .firstWhere((f) {
          final d = tester.widget<Container>(f).decoration;
          return d is BoxDecoration &&
              d.borderRadius is BorderRadiusDirectional;
        }),
  );

  TextDirection directionOf(WidgetTester tester, String text) => tester
      .widget<Directionality>(
        find
            .ancestor(
              of: find.text(text),
              matching: find.byType(Directionality),
            )
            .first,
      )
      .textDirection;

  group('RuneLimitFormatter', () {
    const formatter = RuneLimitFormatter(5);
    TextEditingValue edit(
      String before,
      String after, {
      TextRange? composing,
    }) => formatter.formatEditUpdate(
      TextEditingValue(text: before),
      TextEditingValue(
        text: after,
        selection: TextSelection.collapsed(offset: after.length),
        composing: composing ?? TextRange.empty,
      ),
    );

    test('counts code points, not UTF-16 units or graphemes', () {
      // Five thumbs are ten UTF-16 units and five code points.
      const thumbs = '\u{1F44D}\u{1F44D}\u{1F44D}\u{1F44D}\u{1F44D}';
      expect(edit('', thumbs).text, thumbs);
      expect(RuneLimitFormatter.count(thumbs), 5);
      // One family emoji is one grapheme and seven code points.
      const family = '\u{1F468}‍\u{1F469}‍\u{1F467}‍\u{1F466}';
      expect(RuneLimitFormatter.count(family), 7);
      expect(RuneLimitFormatter.count(edit('', family).text), 5);
    });

    test('a paste is cut at the limit, never inside a code point', () {
      final cut = edit('ab', 'ab\u{1F44D}\u{1F44D}\u{1F44D}\u{1F44D}');
      expect(cut.text, 'ab\u{1F44D}\u{1F44D}\u{1F44D}');
      expect(cut.selection.baseOffset, cut.text.length);
    });

    test('a full field takes nothing more', () {
      expect(edit('abcde', 'abcdef').text, 'abcde');
    });

    test('a paste into the middle keeps the end of what was typed', () {
      const ten = RuneLimitFormatter(10);
      final pasted = ten.formatEditUpdate(
        const TextEditingValue(
          text: 'abcdefgh',
          selection: TextSelection.collapsed(offset: 2),
        ),
        const TextEditingValue(
          text: 'abXYZWcdefgh',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      expect(pasted.text, 'abXYcdefgh');
      expect(pasted.selection, const TextSelection.collapsed(offset: 4));

      // Over a selection in a full field, the paste takes the room the
      // selection left.
      final over = ten.formatEditUpdate(
        const TextEditingValue(
          text: 'abcdefghij',
          selection: TextSelection(baseOffset: 2, extentOffset: 4),
        ),
        const TextEditingValue(
          text: 'abWXYZefghij',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      expect(over.text, 'abWXefghij');
      expect(over.selection, const TextSelection.collapsed(offset: 4));
    });

    test('text being composed and deletions always go through', () {
      expect(
        edit(
          'abcd',
          'abcdefg',
          composing: const TextRange(start: 4, end: 7),
        ).text,
        'abcdefg',
      );
      expect(edit('abcdefg', 'abcdef').text, 'abcdef');
    });
  });

  group('codes', () {
    test('every code reads as a line in all 18 languages', () async {
      final english = await S.delegate.load(const Locale('en'));
      expect(S.supportedLocales, hasLength(18));
      for (final locale in S.supportedLocales) {
        final l10n = await S.delegate.load(locale);
        for (final code in _allCodes) {
          final line = SupportScreen.codeText(l10n, code);
          expect(line, isNotNull, reason: '$locale $code');
          expect(line, isNotEmpty, reason: '$locale $code');
          if (locale.languageCode != 'en') {
            expect(
              line,
              isNot(SupportScreen.codeText(english, code)),
              reason: '$locale $code is still in English',
            );
          }
          expect(line, isNot(matches('[\\u2013\\u2014]')), reason: code);
        }
        expect(SupportScreen.codeText(l10n, 'something_new'), isNull);
      }
    });

    test('the wait reads in hours and minutes, never zero', () async {
      final l10n = await S.delegate.load(const Locale('en'));
      String? wait(Duration d) => SupportScreen.waitText(l10n, _t0.add(d), _t0);
      expect(
        wait(const Duration(hours: 5, minutes: 20)),
        'You can ask again in 5 h 20 min.',
      );
      // A whole number of hours has no "0 min" after it.
      expect(wait(const Duration(hours: 3)), 'You can ask again in 3 h.');
      expect(
        wait(const Duration(hours: 2, minutes: 59, seconds: 30)),
        'You can ask again in 3 h.',
      );
      expect(wait(const Duration(minutes: 60)), 'You can ask again in 1 h.');
      expect(
        wait(const Duration(hours: 1, minutes: 1)),
        'You can ask again in 1 h 1 min.',
      );
      final persian = await S.delegate.load(const Locale('fa'));
      for (final locale in S.supportedLocales) {
        final l10n = await S.delegate.load(locale);
        final whole = SupportScreen.waitText(
          l10n,
          _t0.add(const Duration(hours: 3)),
          _t0,
        )!;
        expect(whole, contains('3'), reason: '$locale');
        expect(whole, isNot(contains('0')), reason: '$locale');
      }
      expect(
        SupportScreen.waitText(persian, _t0.add(const Duration(hours: 3)), _t0),
        isNot(contains('دقیقه')),
      );
      expect(wait(const Duration(minutes: 7)), 'You can ask again in 7 min.');
      expect(wait(const Duration(seconds: 20)), 'You can ask again in 1 min.');
      expect(wait(const Duration(seconds: -5)), 'You can ask again in 1 min.');
      expect(SupportScreen.waitText(l10n, null, _t0), isNull);
    });

    test('text is laid out in its own script', () {
      expect(SupportScreen.layoutLanguage('سلام وصل نمیشه', 'en'), 'fa');
      expect(SupportScreen.layoutLanguage('Hello', 'fa'), 'en');
      expect(SupportScreen.layoutLanguage('salam, vasl nemishe', 'fa'), 'en');
      expect(SupportScreen.layoutLanguage('سلام', 'ar'), 'ar');
      expect(SupportScreen.layoutLanguage('Hello', 'de'), 'de');
      expect(SupportScreen.layoutLanguage('123 ?', 'fa'), 'fa');
    });
  });

  group('chat screen', () {
    testWidgets('says answers are automatic and how many questions are left', (
      tester,
    ) async {
      await pumpChat(tester, _Backend());
      expect(
        find.text('Answers are written automatically and can be wrong.'),
        findsOneWidget,
      );
      expect(find.text('7 of 10 questions left today'), findsOneWidget);
      // The header names the chat and says an assistant answers.
      expect(find.text('Support'), findsOneWidget);
      expect(find.text('AI assistant'), findsOneWidget);
      expect(find.text('Hi! How can I help you with Fortiva?'), findsOneWidget);
    });

    testWidgets('with automatic answers off, messages go to our team', (
      tester,
    ) async {
      final backend = _Backend(mode: 'staff');
      await pumpChat(tester, backend);
      expect(
        find.text(
          'Automatic answers are off for now. Your messages go to our team.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('questions left today'), findsNothing);
      expect(find.text('Write to our team'), findsOneWidget);
      expect(find.text('Fortiva team'), findsOneWidget);
      // No suggested questions: there is no assistant to ask.
      expect(find.byKey(const ValueKey('support-suggestion-0')), findsNothing);
      await tester.enterText(find.byType(TextField), 'Hello team');
      await tester.pump();
      await tester.tap(sendButton());
      await tester.pump();
      await tester.pump();
      expect(backend.sent.single['to'], 'staff');
      // A message to our team has its own line, and no thinking.
      expect(
        find.text('Sent to our team. Their reply will show up here.'),
        findsOneWidget,
      );
      expect(find.byType(ThinkingBubble), findsNothing);
    });

    testWidgets('a question already waiting keeps Send off', (tester) async {
      await pumpChat(
        tester,
        _Backend(
          pending: true,
          messages: [wire(1, role: 'user', status: 'queued', text: 'Earlier')],
        ),
      );
      expect(find.byType(ThinkingBubble), findsOneWidget);
      expect(find.text('Reading your question'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Hello?');
      await tester.pump();
      expect(sendEnabled(tester), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('New conversation is off while a question waits', (
      tester,
    ) async {
      final backend = _Backend();
      final state = await pumpChat(tester, backend);
      expect(find.byTooltip('New conversation'), findsOneWidget);
      expect(newChatEnabled(tester), isTrue);

      await tester.enterText(find.byType(TextField), 'It does not connect');
      await tester.pump();
      await tester.tap(sendButton());
      await tester.pump();
      await tester.pump();
      expect(state.pending, isTrue);
      // A second tap cannot start over and leave the question behind.
      expect(newChatEnabled(tester), isFalse);
      await tester.tap(newChatButton(), warnIfMissed: false);
      await tester.pump();
      expect(backend.newCalls, 0);

      // The answer is in: it is on again.
      backend.messages = [
        wire(201, role: 'user', status: 'handled', text: 'It does not connect'),
        wire(202, text: 'Try mobile data.'),
      ];
      await state.poll();
      await tester.pump();
      expect(state.pending, isFalse);
      expect(newChatEnabled(tester), isTrue);
      await tester.tap(newChatButton());
      await tester.pump();
      await tester.pump();
      expect(backend.newCalls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a message on its way is shown whole, with New conversation '
        'off', (tester) async {
      final backend = _Backend()..hold = Completer<void>();
      await pumpChat(tester, backend);
      await tester.enterText(find.byType(TextField), 'Are you there?');
      await tester.pump();
      await tester.tap(sendButton());
      await tester.pump();
      await tester.pump();
      // Not stored yet: the question is between the tap and the backend.
      expect(backend.sent, isEmpty);
      expect(find.text('Sending'), findsOneWidget);
      expect(newChatEnabled(tester), isFalse);
      // At full strength, with a clock beside the line under it rather
      // than faded out.
      expect(
        find.ancestor(
          of: find.text('Are you there?'),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);

      backend.hold!.complete();
      await tester.pump();
      await tester.pump();
      expect(backend.sent.single['text'], 'Are you there?');
      expect(find.text('Sending'), findsNothing);
      // Now it waits for its answer, and the button stays off.
      expect(newChatEnabled(tester), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('New conversation stays on under a remote\'s focus, and a '
        'press then does nothing', (tester) async {
      final backend = _Backend();
      await pumpChat(tester, backend);
      await tester.enterText(find.byType(TextField), 'It does not connect');
      await tester.pump();
      final focus = tester.widget<IconButton>(newChatButton()).focusNode!;
      focus.requestFocus();
      await tester.pump();
      expect(newChatIconColor(tester), isNot(AppDesign.textDisabled));
      await tester.tap(sendButton());
      await tester.pump();
      await tester.pump();
      expect(backend.sent, hasLength(1));
      // A control that turns off loses the focus, and the remote is left
      // pointing at nothing.
      expect(focus.hasFocus, isTrue);
      expect(newChatEnabled(tester), isTrue);
      // It looks off, so the remote's user can see why a press does
      // nothing.
      expect(newChatIconColor(tester), AppDesign.textDisabled);
      tester.widget<IconButton>(newChatButton()).onPressed!();
      await tester.pump();
      expect(backend.newCalls, 0);

      // Once the remote moves on, it is off like on a phone.
      focus.unfocus();
      await tester.pump();
      expect(newChatEnabled(tester), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Send stays on under a remote\'s focus after a send, and a '
        'press then does nothing', (tester) async {
      final backend = _Backend();
      await pumpChat(tester, backend);
      await tester.enterText(find.byType(TextField), 'It does not connect');
      await tester.pump();
      final focus = tester.widget<IconButton>(sendButton()).focusNode!;
      focus.requestFocus();
      await tester.pump();
      // The remote's centre button.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();
      expect(backend.sent, hasLength(1));
      expect(focus.hasFocus, isTrue);
      expect(sendEnabled(tester), isTrue);
      // A round button, so a TV draws a round ring around it.
      expect(
        find.ancestor(of: sendButton(), matching: find.byType(FocusRingCircle)),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();
      expect(backend.sent, hasLength(1));

      focus.unfocus();
      await tester.pump();
      expect(sendEnabled(tester), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the counter starts at 400 and the input stops at 500', (
      tester,
    ) async {
      await pumpChat(tester, _Backend());
      final counter = find.byKey(const ValueKey('support-counter'));

      await tester.enterText(find.byType(TextField), 'a' * 399);
      await tester.pump();
      expect(counter, findsNothing);
      expect(sendEnabled(tester), isTrue);

      await tester.enterText(find.byType(TextField), 'a' * 400);
      await tester.pump();
      expect(find.text('400/500'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'b' * 650);
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text.runes.length, 500);
      expect(find.text('500/500'), findsOneWidget);
      expect(sendEnabled(tester), isTrue);
    });

    testWidgets('with the keyboard open the top bar stays and the box sits '
        'above the keyboard', (tester) async {
      // A 1080 by 2424 phone with a 900 pixel keyboard open.
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      addTearDown(tester.view.reset);
      await pumpChat(tester, _Backend(), locale: const Locale('fa'));
      await tester.enterText(find.byType(TextField), 'سلام، از صبح وصل نمیشه');
      await tester.pump();

      expect(tester.getTopLeft(find.byType(AppBar)).dy, 0);
      expect(find.text('پشتیبانی'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byType(TextField)).dy,
        lessThan(2424 - 900),
      );
      expect(tester.getBottomLeft(sendButton()).dy, lessThan(2424 - 900));
    });

    testWidgets('the counter uses the app language digits', (tester) async {
      await pumpChat(tester, _Backend(), locale: const Locale('fa'));
      await tester.enterText(find.byType(TextField), 'س' * 432);
      await tester.pump();
      expect(find.text('۴۳۲/۵۰۰'), findsOneWidget);
    });

    testWidgets(
      'sending clears the box and the question waits for its answer',
      (tester) async {
        final backend = _Backend();
        final state = await pumpChat(tester, backend);
        expect(sendEnabled(tester), isFalse);
        await tester.enterText(find.byType(TextField), 'It does not connect');
        await tester.pump();
        await tester.tap(sendButton());
        await tester.pump();
        await tester.pump();
        expect(backend.sent.single['text'], 'It does not connect');
        expect(backend.sent.single['to'], 'assistant');
        expect(state.pending, isTrue);
        expect(find.byType(ThinkingBubble), findsOneWidget);

        // A second question waits for the first.
        await tester.enterText(find.byType(TextField), 'And another');
        await tester.pump();
        expect(sendEnabled(tester), isFalse);
        // Leave the screen so the polls stop.
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('a refused message goes back into the box', (tester) async {
      final backend = _Backend()
        ..sendError = ApiException(
          statusCode: 422,
          message: 'too_long',
          body: {
            'detail': {'code': 'redacted_empty'},
          },
        );
      await pumpChat(tester, backend);
      await tester.enterText(find.byType(TextField), '0912 345 6789');
      await tester.pump();
      await tester.tap(sendButton());
      await tester.pump();
      await tester.pump();
      expect(find.text('0912 345 6789'), findsOneWidget);
      expect(
        find.textContaining('Your message only had personal details'),
        findsOneWidget,
      );
    });

    testWidgets('a used-up day says until when, and nothing gets around it', (
      tester,
    ) async {
      final backend = _Backend(
        quota: quotaJson(
          remaining: 0,
          resetsIn: const Duration(hours: 5, minutes: 20),
        ),
      );
      await pumpChat(tester, backend);
      expect(limitCard, findsOneWidget);
      expect(
        find.text("You have used all of today's questions."),
        findsOneWidget,
      );
      // On the card, and as the hint in the box, which is off until then.
      expect(find.text('You can ask again in 5 h 20 min.'), findsNWidgets(2));
      expect(hint(tester), 'You can ask again in 5 h 20 min.');
      expect(inputEnabled(tester), isFalse);
      expect(sendEnabled(tester), isFalse);
      expect(find.textContaining('questions left today'), findsNothing);
      expectNoWayAround(tester);
      // No suggested questions over a card that says none can be asked.
      expect(find.byKey(const ValueKey('support-suggestion-0')), findsNothing);
      expect(find.text('Hi! How can I help you with Fortiva?'), findsOneWidget);
      expect(backend.sent, isEmpty);
    });

    testWidgets("an older backend's conversation limit reads as the day's", (
      tester,
    ) async {
      final backend = _Backend(
        quota: quotaJson(conversationLeft: 0),
        messages: [wire(1, text: 'An answer')],
      );
      await pumpChat(tester, backend);
      // Its count per conversation is never shown and never limits.
      expect(limitCard, findsNothing);
      expect(find.text('7 of 10 questions left today'), findsOneWidget);

      backend.sendError = ApiException(
        statusCode: 429,
        message: 'quota_conversation',
        body: {
          'detail': {
            'code': 'quota_conversation',
            'retry_at': _t0.add(const Duration(minutes: 30)).toIso8601String(),
          },
        },
      );
      await tester.enterText(find.byType(TextField), 'One more');
      await tester.pump();
      await tester.tap(sendButton());
      await tester.pump();
      await tester.pump();
      expect(limitCard, findsOneWidget);
      expect(
        find.text("You have used all of today's questions."),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: limitCard,
          matching: find.text('You can ask again in 30 min.'),
        ),
        findsOneWidget,
      );
      expect(inputEnabled(tester), isFalse);
      expectNoWayAround(tester);
      // The text the user wrote is kept.
      expect(find.text('One more'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a pause says until when, with nothing to tap', (tester) async {
      final backend = _Backend(mode: 'paused')
        ..quota = {
          ...quotaJson(),
          'paused_until': _t0
              .add(const Duration(hours: 1, minutes: 5))
              .toIso8601String(),
        };
      await pumpChat(tester, backend);
      expect(
        find.text('Automatic answers are paused for now.'),
        findsOneWidget,
      );
      expect(find.text('You can ask again in 1 h 5 min.'), findsNWidgets(2));
      expect(inputEnabled(tester), isFalse);
      expectNoWayAround(tester);
    });

    testWidgets('a busy assistant says to try again soon, with nothing to tap', (
      tester,
    ) async {
      final backend = _Backend()
        ..sendError = _tooSoon('busy', const Duration(seconds: 60));
      await pumpChat(tester, backend);
      await tester.enterText(find.byType(TextField), 'Hello?');
      await tester.pump();
      await tester.tap(sendButton());
      await tester.pump();
      await tester.pump();
      expect(
        find.text(
          'Our assistant is busy right now. Please try again in a few minutes.',
        ),
        findsOneWidget,
      );
      // No minute counted down for a busy assistant.
      expect(find.textContaining('You can ask again'), findsNothing);
      expect(hint(tester), 'Try again in a few minutes.');
      expect(inputEnabled(tester), isFalse);
      expectNoWayAround(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a short wait turns the box off until it ends', (tester) async {
      var now = _t0;
      final backend = _Backend(clock: () => now)
        ..sendError = _tooSoon('slow_down', const Duration(seconds: 60));
      await pumpChat(tester, backend, clock: () => now);
      await tester.enterText(find.byType(TextField), 'Why is it slow?');
      await tester.pump();
      await tester.tap(sendButton());
      await tester.pump();
      await tester.pump();
      expect(limitCard, findsOneWidget);
      expect(
        find.text(
          'You are sending messages too quickly. Please wait a little.',
        ),
        findsOneWidget,
      );
      expect(hint(tester), 'You can ask again in 1 min.');
      expect(
        find.descendant(
          of: limitCard,
          matching: find.text('You can ask again in 1 min.'),
        ),
        findsOneWidget,
      );
      // The text is back, kept in the box while it is off.
      expect(find.text('Why is it slow?'), findsOneWidget);
      expect(inputEnabled(tester), isFalse);
      expect(sendEnabled(tester), isFalse);
      expectNoWayAround(tester);

      // The box comes back on by itself when the wait is over.
      now = _t0.add(const Duration(seconds: 61));
      backend.sendError = null;
      await tester.pump(const Duration(seconds: 61));
      expect(limitCard, findsNothing);
      expect(find.textContaining('too quickly'), findsNothing);
      expect(inputEnabled(tester), isTrue);
      expect(sendEnabled(tester), isTrue);
      await tester.tap(sendButton());
      await tester.pump();
      await tester.pump();
      expect(backend.sent.single['to'], 'assistant');
      expect(backend.sent.single['text'], 'Why is it slow?');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('when the day turns over, the count comes from the backend', (
      tester,
    ) async {
      var now = _t0;
      final backend = _Backend(
        clock: () => now,
        quota: quotaJson(remaining: 0, resetsIn: const Duration(seconds: 45)),
      );
      final state = await pumpChat(tester, backend, clock: () => now);
      expect(limitCard, findsOneWidget);
      expect(inputEnabled(tester), isFalse);

      now = _t0.add(const Duration(seconds: 44));
      await tester.pump(const Duration(seconds: 44));
      expect(limitCard, findsOneWidget);
      final before = backend.fetchCalls;

      // The backend still has the old count when the phone asks.
      now = _t0.add(const Duration(seconds: 46));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(limitCard, findsNothing);
      expect(inputEnabled(tester), isTrue);
      // Asked at the reset, not at the next routine fetch 14 s later.
      expect(backend.fetchCalls, before + 1);
      // A count of none left is never shown over a box that is on.
      expect(find.textContaining('questions left today'), findsNothing);

      backend.quota = quotaJson(
        remaining: 10,
        resetsIn: const Duration(hours: 24),
      );
      await state.poll();
      await tester.pump();
      expect(find.text('10 of 10 questions left today'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a limit card and a refusal are read out as they appear', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final backend = _Backend()
        ..sendError = _tooSoon('busy', const Duration(seconds: 60));
      final state = await pumpChat(tester, backend);
      await tester.enterText(find.byType(TextField), 'Hello?');
      await tester.pump();
      await tester.tap(sendButton());
      await tester.pump();
      for (var i = 0; i < 5 && limitCard.evaluate().isEmpty; i++) {
        await tester.pump();
      }
      expect(limitCard, findsOneWidget);
      // The frame the card first shows in is the one a screen reader hears.
      expect(
        tester.getSemantics(limitCard).flagsCollection.isLiveRegion,
        isTrue,
      );
      // Once only, so the minutes counting down are not read out again.
      await state.poll();
      await tester.pump();
      expect(limitCard, findsOneWidget);
      expect(
        tester.getSemantics(limitCard).flagsCollection.isLiveRegion,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());

      // A refusal under the box, the same.
      final refused = _Backend()
        ..sendError = ApiException(
          statusCode: 422,
          message: 'redacted_empty',
          body: {
            'detail': {'code': 'redacted_empty'},
          },
        );
      await pumpChat(tester, refused);
      await tester.enterText(find.byType(TextField), '0912 345 6789');
      await tester.pump();
      await tester.tap(sendButton());
      final line = find.textContaining(
        'Your message only had personal details',
      );
      for (var i = 0; i < 5 && line.evaluate().isEmpty; i++) {
        await tester.pump();
      }
      expect(tester.getSemantics(line).flagsCollection.isLiveRegion, isTrue);
      semantics.dispose();
    });

    testWidgets('with our team on the conversation, it shows them', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final backend = _Backend(
        quota: quotaJson(remaining: 0),
        ticket: 'open',
        messages: [
          wire(1, role: 'user', text: 'q1'),
          wire(2, text: 'An answer from the assistant'),
          wire(3, role: 'user', status: 'to_staff', code: 'ticket_opened'),
          wire(4, role: 'system', code: 'ticket_opened', text: ''),
          wire(5, role: 'staff', text: 'Which carrier are you on?'),
        ],
      );
      await pumpChat(tester, backend);
      final header = find.byType(AppBar);
      // The header names our team and shows their face, not the bot's.
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('support-subtitle')))
            .data,
        'Fortiva team',
      );
      expect(
        find.descendant(
          of: header,
          matching: find.byIcon(Icons.support_agent_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.byType(ChatbotAvatar)),
        findsNothing,
      );
      // A reply from our team has their face beside it, and starts where
      // the assistant's replies start.
      final staff = find.text('Which carrier are you on?');
      final bot = find.text('An answer from the assistant');
      expect(bubbleRect(tester, staff).left, bubbleRect(tester, bot).left);
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byIcon(Icons.support_agent_rounded),
        ),
        findsNWidgets(2),
        reason: 'the face beside the reply and the label in it',
      );
    });

    testWidgets('the small corner of a bubble points at who is speaking', (
      tester,
    ) async {
      await pumpChat(
        tester,
        _Backend(
          pending: true,
          messages: [
            wire(1, role: 'user', text: 'Hello'),
            wire(2, text: 'Hi there'),
            wire(3, role: 'user', status: 'queued', text: 'And?'),
          ],
        ),
      );
      const tail = Radius.circular(4);
      const round = Radius.circular(14);
      // Up at the face for the assistant, and while it thinks.
      final thinking = tester.widget<Container>(
        find.byKey(const ValueKey('support-thinking')),
      );
      for (final corners in [
        bubbleCorners(tester, find.text('Hi there')),
        (thinking.decoration! as BoxDecoration).borderRadius!
            as BorderRadiusDirectional,
      ]) {
        expect(corners.topStart, tail);
        expect(corners.bottomStart, round);
        expect(corners.topEnd, round);
      }
      // On the user's own side for theirs.
      final mine = bubbleCorners(tester, find.text('Hello'));
      expect(mine.topEnd, tail);
      expect(mine.bottomEnd, round);
      expect(mine.topStart, round);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the thumbs are big enough to tap', (tester) async {
      await pumpChat(tester, _Backend(messages: [wire(5, text: 'Try it.')]));
      for (final label in ['Helpful', 'Not helpful']) {
        final size = tester.getSize(find.byTooltip(label));
        expect(size.width, greaterThanOrEqualTo(48), reason: label);
        expect(size.height, greaterThanOrEqualTo(48), reason: label);
      }
    });

    testWidgets('with the day used up, our team can still be answered', (
      tester,
    ) async {
      final backend = _Backend(
        quota: quotaJson(remaining: 0),
        ticket: 'open',
        messages: [
          wire(1, role: 'user', status: 'to_staff', code: 'ticket_opened'),
          wire(2, role: 'system', code: 'ticket_opened', text: ''),
          wire(3, role: 'staff', text: 'Which carrier are you on?'),
        ],
      );
      await pumpChat(tester, backend);
      // No limit card: the user is talking to our team now.
      expect(limitCard, findsNothing);
      expect(find.byKey(const ValueKey('support-with-team')), findsOneWidget);
      expect(
        find.text('This conversation is now with our team.'),
        findsOneWidget,
      );
      expect(inputEnabled(tester), isTrue);
      expect(hint(tester), 'Write to our team');
      await tester.enterText(find.byType(TextField), 'Irancell');
      await tester.pump();
      await tester.tap(sendButton());
      await tester.pump();
      await tester.pump();
      expect(backend.sent.single['to'], 'staff');
      expect(find.byType(ThinkingBubble), findsNothing);

      // The cap on messages to our team is a limit like any other.
      backend.staffError = _tooSoon('slow_down', const Duration(hours: 8));
      await tester.enterText(find.byType(TextField), 'Still there?');
      await tester.pump();
      await tester.tap(sendButton());
      await tester.pump();
      await tester.pump();
      expect(limitCard, findsOneWidget);
      expect(inputEnabled(tester), isFalse);
      expect(hint(tester), 'You can ask again in 8 h.');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('what became of a question is said once', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // As the backend stores them: the code on the question, and our
      // notice or the assistant's own refusal after it.
      await pumpChat(
        tester,
        _Backend(
          messages: [
            wire(
              1,
              role: 'user',
              status: 'failed',
              code: 'ai_unavailable',
              text: 'q1',
            ),
            wire(2, role: 'system', code: 'ai_unavailable', text: ''),
            wire(
              3,
              role: 'user',
              status: 'to_staff',
              code: 'ticket_opened',
              text: 'q2',
            ),
            wire(4, role: 'system', code: 'ticket_opened', text: ''),
            wire(5, role: 'user', status: 'failed', code: 'busy', text: 'q3'),
            wire(6, role: 'system', code: 'busy', text: ''),
            wire(
              7,
              role: 'user',
              status: 'refused',
              code: 'off_topic',
              text: 'q4',
            ),
            wire(
              8,
              role: 'assistant',
              code: 'off_topic',
              text: 'I am here for Fortiva questions.',
            ),
            // Refused when it was sent; nothing follows it.
            wire(
              9,
              role: 'user',
              status: 'refused',
              code: 'gibberish',
              text: 'q5',
            ),
          ],
        ),
      );
      expect(
        find.text(
          'The assistant could not answer this time. '
          'Please try again in a little while.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'We passed your question to our team. Their reply will show up here.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Our assistant is busy right now. Please try again in a few minutes.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('I can only help with questions about using Fortiva.'),
        findsNothing,
      );
      expect(find.text('I am here for Fortiva questions.'), findsOneWidget);
      expect(
        find.text(
          'Sorry, I did not understand that. Please write your question again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('codes become lines, a greeting gets a friendly answer', (
      tester,
    ) async {
      await pumpChat(
        tester,
        _Backend(
          messages: [
            wire(
              1,
              role: 'user',
              status: 'handled',
              code: 'greeting',
              text: 'سلام',
            ),
            wire(
              2,
              role: 'user',
              status: 'refused',
              code: 'injection',
              text: 'x',
            ),
            wire(3, role: 'system', code: 'ticket_opened', text: ''),
            wire(4, role: 'staff', text: 'Hi, this is the team.'),
          ],
        ),
      );
      expect(find.text('Hi! How can I help you with Fortiva?'), findsOneWidget);
      expect(
        find.text('I can only help with questions about using Fortiva.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'We passed your question to our team. Their reply will show up here.',
        ),
        findsOneWidget,
      );
      expect(find.text('Fortiva team'), findsOneWidget);
    });

    testWidgets('an answer can be rated down, and the user is thanked', (
      tester,
    ) async {
      final backend = _Backend(messages: [wire(5, text: 'Try mobile data.')]);
      await pumpChat(tester, backend);
      await tester.tap(find.byTooltip('Not helpful'));
      await tester.pump();
      await tester.pump();
      expect(backend.rated, ['5:down']);
      expect(
        find.text('Thanks. Our team will look at this answer.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.thumb_down_rounded), findsOneWidget);
      // The filled glyph says which one was chosen. Rose means a failure
      // everywhere else, so the chosen thumb is only brighter.
      expect(
        tester.widget<Icon>(find.byIcon(Icons.thumb_down_rounded)).color,
        AppDesign.textPrimary,
      );
    });

    testWidgets('with the chat off, Telegram is offered', (tester) async {
      final opened = <Uri>[];
      await pumpChat(
        tester,
        _Backend(enabled: false),
        open: (url) async => opened.add(url),
      );
      expect(find.text('Chat is not available right now.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Message us on Telegram'));
      await tester.pump();
      expect(opened, [Uri.parse('https://t.me/fortiva_vpn')]);
    });

    testWidgets('a message that found no route says so', (tester) async {
      final backend = _Backend()
        ..sendError = ApiException(
          statusCode: 0,
          message: 'No internet connection',
        );
      final state = await pumpChat(tester, backend);
      await tester.enterText(find.byType(TextField), 'Are you there?');
      await tester.pump();
      await tester.tap(sendButton());
      await tester.pump();
      await tester.pump();
      expect(find.text('Are you there?'), findsOneWidget);
      expect(find.text('Not sent. Tap to try again.'), findsOneWidget);
      // A failure the user has to act on, so in the error color.
      expect(
        tester
            .widget<Text>(find.text('Not sent. Tap to try again.'))
            .style
            ?.color,
        AppDesign.error,
      );
      // A small line, in a tap area a finger can hit.
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('Not sent. Tap to try again.'),
                    matching: find.byType(Tappable),
                  )
                  .first,
            )
            .height,
        greaterThanOrEqualTo(48),
      );
      await tester.pump(const Duration(milliseconds: 250));

      backend.sendError = null;
      await tester.tap(find.text('Not sent. Tap to try again.'));
      await tester.pump();
      await tester.pump();
      expect(backend.sent.single['text'], 'Are you there?');
      expect(state.outbox, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('thinking', () {
    testWidgets('the line under the dots moves on with the time asked', (
      tester,
    ) async {
      var now = _t0;
      await pumpChat(
        tester,
        _Backend(
          clock: () => now,
          pending: true,
          messages: [
            wire(1, role: 'user', status: 'answering', text: 'Hi', at: _t0),
          ],
        ),
        clock: () => now,
      );
      expect(find.byType(ThinkingBubble), findsOneWidget);
      expect(find.text('Reading your question'), findsOneWidget);
      // The small grey line it replaces is gone.
      expect(find.byType(CircularProgressIndicator), findsNothing);

      Future<void> wait(int seconds) async {
        now = now.add(Duration(seconds: seconds));
        await tester.pump(Duration(seconds: seconds));
        await tester.pump(const Duration(milliseconds: 300));
      }

      await wait(4);
      expect(find.text('Looking for the answer'), findsOneWidget);
      await wait(7);
      expect(find.text('Writing the answer'), findsOneWidget);
      await wait(35);
      expect(find.text('Still on it, thanks for waiting'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the bubble eases to the width of its next line', (
      tester,
    ) async {
      var now = _t0;
      final backend = _Backend(
        clock: () => now,
        pending: true,
        messages: [
          wire(1, role: 'user', status: 'answering', text: 'Hi', at: _t0),
        ],
      );
      await pumpChat(tester, backend, clock: () => now);
      final bubble = find.byKey(const ValueKey('support-thinking'));
      now = _t0.add(const Duration(seconds: 44));
      await tester.pump(const Duration(seconds: 44));
      await tester.pump(const Duration(milliseconds: 600));
      final short = tester.getSize(bubble).width;

      // The last line is much longer than the one before it. Frame by
      // frame, the bubble passes through the widths in between.
      now = _t0.add(const Duration(seconds: 45));
      final widths = <double>[];
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        widths.add(tester.getSize(bubble).width);
      }
      final long = widths.last;
      expect(find.text('Still on it, thanks for waiting'), findsOneWidget);
      expect(long, greaterThan(short));
      expect(widths.where((w) => w > short && w < long), isNotEmpty);
      await tester.pumpWidget(const SizedBox.shrink());

      // With less motion asked for, it takes the new width at once.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      now = _t0;
      await pumpChat(tester, backend, clock: () => now);
      expect(
        find.descendant(of: bubble, matching: find.byType(AnimatedSize)),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('every line reads in all 18 languages', () async {
      final english = await S.delegate.load(const Locale('en'));
      for (final locale in S.supportedLocales) {
        final l10n = await S.delegate.load(locale);
        for (final seconds in [0, 3, 10, 45]) {
          final line = ThinkingBubble.line(l10n, Duration(seconds: seconds));
          expect(line, isNotEmpty);
          if (locale.languageCode != 'en') {
            expect(
              line,
              isNot(ThinkingBubble.line(english, Duration(seconds: seconds))),
              reason: '$locale ${seconds}s is still in English',
            );
          }
        }
      }
    });
  });

  group('typed replies', () {
    const long =
        'Open Settings on your phone, find Private DNS, turn it off, then '
        'come back to Fortiva and tap the button to connect again please.';

    /// The chat with one old answer, then a question and [reply] arriving
    /// while it is open.
    Future<SupportState> arrive(
      WidgetTester tester, {
      String reply = long,
      Locale locale = const Locale('en'),
    }) async {
      final backend = _Backend(messages: [wire(1, text: 'An old answer')]);
      final state = await pumpChat(tester, backend, locale: locale);
      backend.messages = [
        ...backend.messages,
        wire(2, role: 'user', text: 'Some sites do not open'),
        wire(3, text: reply),
      ];
      await state.poll();
      await tester.pump();
      return state;
    }

    testWidgets('an answer from before shows at once, with its thumbs', (
      tester,
    ) async {
      await pumpChat(tester, _Backend(messages: [wire(1, text: 'Old')]));
      expect(find.byType(TypedText), findsNothing);
      expect(find.text('Old'), findsOneWidget);
      expect(find.byTooltip('Helpful'), findsOneWidget);
    });

    testWidgets('a new answer grows word by word, then gets its thumbs', (
      tester,
    ) async {
      await arrive(tester);
      expect(find.byType(TypedText), findsOneWidget);
      final first = typedSoFar(tester);
      await tester.pump(const Duration(milliseconds: 500));
      final later = typedSoFar(tester);
      expect(later.length, greaterThan(first.length));
      expect(later.length, lessThan(long.length));
      expect(long.startsWith(later), isTrue);
      // Only the old answer can be rated while this one is typed.
      expect(find.byTooltip('Helpful'), findsOneWidget);
      // A screen reader has the whole answer from the start.
      expect(find.bySemanticsLabel(long), findsOneWidget);

      // 21 words take 945 ms.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(find.byType(TypedText), findsNothing);
      expect(find.text(long), findsOneWidget);
      expect(find.byTooltip('Helpful'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a typed answer has its final size from the first frame', (
      tester,
    ) async {
      await arrive(tester);
      final typed = find.byType(TypedText);
      // Above the new reply, in a list that starts at the bottom: it moves
      // if the reply grows. The question has a slide of its own.
      final question = find.text('An old answer');
      // The first word is there at once, and the rest of the text is laid
      // out, only not seen yet. No caret that could push a word along.
      expect(typedSoFar(tester), isNotEmpty);
      expect(typedSpan(tester).toPlainText(), long);
      var widgets = 0;
      typedSpan(tester).visitChildren((span) {
        if (span is WidgetSpan) widgets++;
        return true;
      });
      expect(widgets, 0);
      // It takes the thinking bubble's place as it is: no fade or slide.
      for (final fade in tester.widgetList<FadeTransition>(
        find.ancestor(of: typed, matching: find.byType(FadeTransition)),
      )) {
        expect(fade.opacity.value, 1);
      }
      final first = tester.getSize(typed);
      final questionAt = tester.getRect(question);

      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getSize(typed), first);
      expect(tester.getRect(question), questionAt);

      // Whole, and with the thumbs in the room kept for them: nothing in
      // the chat moves.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byType(TypedText), findsNothing);
      expect(tester.getSize(find.text(long)), first);
      expect(tester.getRect(question), questionAt);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a short answer is typed out in the same bubble width', (
      tester,
    ) async {
      const short = 'Glad it works! Ask me any time.';
      await arrive(tester, reply: short);
      final typed = find.byType(TypedText);
      final first = tester.getSize(typed);
      final seen = <String>{typedSoFar(tester)};
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 90));
        if (typed.evaluate().isEmpty) break;
        expect(tester.getSize(typed), first);
        seen.add(typedSoFar(tester));
      }
      // It did grow, word by word, inside a bubble that did not.
      expect(seen.length, greaterThan(2));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(tester.getSize(find.text(short)), first);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a tap shows the whole answer at once', (tester) async {
      await arrive(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(typedSoFar(tester).length, lessThan(long.length));
      await tester.tap(find.byKey(const ValueKey('support-typing')));
      await tester.pump();
      expect(find.byType(TypedText), findsNothing);
      expect(find.text(long), findsOneWidget);
      expect(find.byTooltip('Helpful'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('with less motion asked for, nothing is typed out', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await arrive(tester);
      expect(find.byType(TypedText), findsNothing);
      expect(find.text(long), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a reply shown whole is not typed out again later', (
      tester,
    ) async {
      // Flutter on Android counts any accessibility service that reads the
      // screen as a screen reader, and stops when the service stops. The
      // reply is shown whole meanwhile, and stays whole after.
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await arrive(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(typedSoFar(tester).length, lessThan(long.length));

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      await tester.pump();
      expect(find.byType(TypedText), findsNothing);
      expect(find.text(long), findsOneWidget);

      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pump();
      expect(find.byType(TypedText), findsNothing);
      expect(find.text(long), findsOneWidget);
      expect(find.byTooltip('Helpful'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('with a screen reader on, a new reply is read out once', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await arrive(tester);
      expect(find.byType(TypedText), findsNothing);
      expect(
        tester.getSemantics(find.text(long)).flagsCollection.isLiveRegion,
        isTrue,
      );
      // History is not read out.
      expect(
        tester
            .getSemantics(find.text('An old answer'))
            .flagsCollection
            .isLiveRegion,
        isFalse,
      );
      // Once: a later build leaves it a plain reply, so scrolling back to
      // it does not read it again.
      await tester.enterText(find.byType(TextField), 'Thanks');
      await tester.pump();
      expect(
        tester.getSemantics(find.text(long)).flagsCollection.isLiveRegion,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    });

    testWidgets('Persian is typed out in whole words', (tester) async {
      const persian =
          'می‌تونی از «تنظیمات» گزینه‌ی Private DNS رو خاموش کنی و '
          'دوباره وصل بشی، اگه باز هم نشد بهم بگو.';
      await arrive(tester, reply: persian, locale: const Locale('fa'));
      final words = TypedText.words(persian);
      final steps = <String>{
        for (var i = 0; i <= words.length; i++) words.take(i).join(),
      };
      for (var i = 0; i < 8; i++) {
        expect(steps, contains(typedSoFar(tester)));
        await tester.pump(const Duration(milliseconds: 90));
      }
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text(persian), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('words keep the non-joiner and mixed scripts whole', () {
      const text = '  می‌خواهم  وصل\nبشم با VPN، باشه؟';
      final words = TypedText.words(text);
      expect(words.join(), text);
      expect(words.first, '  می‌خواهم  ');
      expect(words, contains('VPN، '));
      // No word starts or ends inside another: each is a run of non-space
      // characters and the spaces after it.
      for (final w in words.skip(1)) {
        expect(w, matches(RegExp(r'^\S+\s*$')));
      }
      expect(TypedText.words('   '), isEmpty);
      expect(
        TypedText.durationFor(3),
        TypedText.shortest,
        reason: 'a short reply still takes the shortest time',
      );
      expect(TypedText.durationFor(500), TypedText.longest);
      expect(TypedText.durationFor(30), const Duration(milliseconds: 1350));
    });
  });

  group('empty chat', () {
    testWidgets('a suggested question is asked, and the rest go away', (
      tester,
    ) async {
      final backend = _Backend();
      await pumpChat(tester, backend);
      for (final text in [
        "I can't connect",
        'How much data do I have today?',
        'My connection is slow',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      // Google sign-in is closed (backend #383), so it is not offered.
      expect(find.byKey(const ValueKey('support-suggestion-3')), findsNothing);
      await tester.tap(find.text('How much data do I have today?'));
      await tester.pump();
      await tester.pump();
      expect(backend.sent.single['text'], 'How much data do I have today?');
      expect(backend.sent.single['to'], 'assistant');
      expect(find.byKey(const ValueKey('support-suggestion-0')), findsNothing);
      expect(find.byType(ThinkingBubble), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a suggested question leaves what the user typed in the box', (
      tester,
    ) async {
      final backend = _Backend();
      await pumpChat(tester, backend);
      await tester.enterText(
        find.byType(TextField),
        'my long draft about wifi',
      );
      await tester.pump();
      await tester.tap(find.text("I can't connect"));
      await tester.pump();
      await tester.pump();
      expect(backend.sent.single['text'], "I can't connect");
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'my long draft about wifi',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a suggested question is a button big enough to tap', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpChat(tester, _Backend());
      for (var i = 0; i < 3; i++) {
        final chip = find.byKey(ValueKey('support-suggestion-$i'));
        expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
        final node = tester.getSemantics(chip);
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.flagsCollection.isEnabled.toBoolOrNull(), isTrue);
      }
      semantics.dispose();
    });

    testWidgets('no suggested questions while a limit holds', (tester) async {
      // A pause on an empty chat: the hello stays, the questions that
      // cannot be asked do not.
      await pumpChat(
        tester,
        _Backend(mode: 'paused')
          ..quota = {
            ...quotaJson(),
            'paused_until': _t0
                .add(const Duration(minutes: 40))
                .toIso8601String(),
          },
      );
      expect(limitCard, findsOneWidget);
      expect(find.text('Hi! How can I help you with Fortiva?'), findsOneWidget);
      expect(find.byKey(const ValueKey('support-suggestion-0')), findsNothing);
    });

    testWidgets('the hello is set in even lines, never one word alone', (
      tester,
    ) async {
      // The test font draws every letter one square of the font size, so
      // at this width the whole width would leave "Fortiva?" alone on the
      // second line.
      tester.view.physicalSize = const Size(660, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpChat(tester, _Backend());
      const hello = 'Hi! How can I help you with Fortiva?';
      final paragraph = tester.renderObject<RenderParagraph>(find.text(hello));
      final lines = <double, double>{};
      for (final box in paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: hello.length),
      )) {
        final top = box.top.roundToDouble();
        lines[top] = (lines[top] ?? 0) + box.right - box.left;
      }
      expect(lines, hasLength(2));
      final widths = lines.values.toList()..sort();
      expect(widths.first / widths.last, greaterThan(0.75), reason: '$lines');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final locale in [const Locale('en'), const Locale('fa')]) {
      testWidgets('[${locale.languageCode}] a one-line box is as tall as the '
          'send button', (tester) async {
        // Persian lines are taller than English ones. A fixed padding made
        // the box 52 high in Persian, no longer a pill.
        await pumpChat(tester, _Backend(), locale: locale);
        expect(tester.getSize(find.byType(TextField)).height, closeTo(48, 0.5));
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });

  group('direction', () {
    testWidgets(
      'in a Persian app the user writes on the left, replies on the right',
      (tester) async {
        await pumpChat(
          tester,
          _Backend(
            messages: [
              wire(1, role: 'user', text: 'وصل نمیشه'),
              wire(2, text: 'دیتای موبایل رو امتحان کن.'),
            ],
          ),
          locale: const Locale('fa'),
        );
        final width = tester.getSize(find.byType(Scaffold)).width;
        expect(
          tester.getCenter(find.text('وصل نمیشه')).dx,
          lessThan(width / 2),
        );
        expect(
          tester.getCenter(find.text('دیتای موبایل رو امتحان کن.')).dx,
          greaterThan(width / 2),
        );
        expect(directionOf(tester, 'وصل نمیشه'), TextDirection.rtl);
        expect(find.text('۷ از ۱۰ سؤال امروز باقی مونده'), findsOneWidget);
      },
    );

    testWidgets('English in a Persian app reads left to right', (tester) async {
      await pumpChat(
        tester,
        _Backend(messages: [wire(1, text: 'Turn off Private DNS.')]),
        locale: const Locale('fa'),
      );
      expect(directionOf(tester, 'Turn off Private DNS.'), TextDirection.ltr);
    });

    testWidgets('Persian in an English app reads right to left', (
      tester,
    ) async {
      await pumpChat(
        tester,
        _Backend(
          messages: [wire(1, role: 'user', text: 'سلام، وصل نمیشه')],
        ),
      );
      final width = tester.getSize(find.byType(Scaffold)).width;
      expect(directionOf(tester, 'سلام، وصل نمیشه'), TextDirection.rtl);
      expect(
        tester.getCenter(find.text('سلام، وصل نمیشه')).dx,
        greaterThan(width / 2),
      );
    });

    testWidgets('Arabic and Urdu lay the chat out right to left', (
      tester,
    ) async {
      for (final language in ['ar', 'ur']) {
        await pumpChat(
          tester,
          _Backend(
            messages: [wire(1, role: 'user', text: 'مرحبا')],
          ),
          locale: Locale(language),
        );
        final width = tester.getSize(find.byType(Scaffold)).width;
        expect(
          tester.getCenter(find.text('مرحبا')).dx,
          lessThan(width / 2),
          reason: language,
        );
      }
    });
  });

  group('chatbot button', () {
    // Where the button can go depends on how wide the lines around it are.
    // The test engine's own font draws every letter a square, which makes
    // a status line half again as wide as on a phone, so the real fonts
    // the app ships are loaded here.
    setUpAll(() async {
      Future<ByteData> bytes(String path) async =>
          ByteData.sublistView(await File(path).readAsBytes());
      final inter = FontLoader('Inter');
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        inter.addFont(bytes('assets/fonts/Inter/Inter-$weight.ttf'));
      }
      await inter.load();
      final vazirmatn = FontLoader('Vazirmatn');
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        vazirmatn.addFont(
          bytes('assets/fonts/Vazirmatn/Vazirmatn-$weight.ttf'),
        );
      }
      await vazirmatn.load();
    });

    Future<void> pumpButton(WidgetTester tester, SupportState? state) async {
      final app = MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: const Locale('en'),
        theme: appThemeFor(const Locale('en')),
        home: const Scaffold(body: Center(child: ChatbotButton())),
      );
      await tester.pumpWidget(
        state == null
            ? app
            : ChangeNotifierProvider<SupportState>(
                create: (_) => state,
                child: app,
              ),
      );
      await tester.pump();
    }

    final button = find.byKey(const ValueKey('chatbot-button'));
    final dot = find.byKey(const ValueKey('chatbot-unread'));

    testWidgets('draws nothing until the chat is on', (tester) async {
      await pumpButton(tester, null);
      expect(button, findsNothing);

      await pumpButton(tester, _chatWith(_Backend()));
      expect(button, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens the chat once it is on, and grows in once', (
      tester,
    ) async {
      final state = _chatWith(_Backend());
      await state.checkStatus(force: true);
      await pumpButton(tester, state);
      expect(find.byTooltip('Chat with support'), findsOneWidget);
      expect(find.bySemanticsLabel('Chat with support'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      // Still once it has grown in: nothing runs while it sits there.
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.getSize(button), const Size.square(ChatbotButton.size));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(SupportScreen), findsOneWidget);
    });

    testWidgets('a dot says a reply has not been seen', (tester) async {
      final backend = _Backend(messages: [wire(4, text: 'Try mobile data.')]);
      final state = _chatWith(backend);
      await state.checkStatus(force: true);
      await pumpButton(tester, state);
      expect(dot, findsNothing);
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Chat with support')).value,
        isEmpty,
      );
      await state.poll();
      await tester.pump();
      expect(state.unseenReplies, 1);
      expect(dot, findsOneWidget);
      // A screen reader says it in words.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Chat with support')).value,
        'New reply',
      );
      semantics.dispose();
    });

    Future<_FailedVpn> pumpHome(
      WidgetTester tester, {
      SupportState? support,
      bool connected = false,
      bool calm = false,
      Locale locale = const Locale('en'),
      QuotaStatus? allowance,
    }) async {
      final vpn = calm ? _CalmVpn() : _FailedVpn(connected: connected);
      await tester.pumpWidget(
        MultiProvider(
          // A new tree each time, so the providers of the last one are
          // disposed and this one's are used.
          key: UniqueKey(),
          providers: [
            ChangeNotifierProvider<DedicatedState>.value(
              value: _Dedicated(allowance: allowance),
            ),
            ChangeNotifierProvider<ServerState>.value(value: _Servers()),
            ChangeNotifierProvider<VpnService>.value(value: vpn),
            ChangeNotifierProvider<ConnectFlow>(
              create: (_) => ConnectFlow(vpn: vpn),
            ),
            ChangeNotifierProvider<LocaleState>(create: (_) => LocaleState()),
            if (support != null)
              ChangeNotifierProvider<SupportState>(create: (_) => support),
          ],
          child: MaterialApp(
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            locale: locale,
            theme: appThemeFor(locale),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      return vpn;
    }

    Future<SupportState> chatOn() async {
      final support = _chatWith(_Backend());
      await support.checkStatus(force: true);
      return support;
    }

    testWidgets(
      'sits at the end: on the right in English, the left in Persian',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpHome(tester, support: await chatOn(), calm: true);
        expect(tester.getCenter(button).dx, greaterThan(412 / 2 + 110));
        // No longer in the top bar.
        expect(
          tester.getCenter(button).dy,
          greaterThan(tester.getCenter(find.byType(PowerButton)).dy),
        );

        await pumpHome(
          tester,
          support: await chatOn(),
          calm: true,
          locale: const Locale('fa'),
        );
        expect(tester.getCenter(button).dx, lessThan(412 / 2 - 110));
      },
    );

    const allowance = QuotaStatus(
      unlimited: false,
      limitBytes: 5368709120,
      usedBytes: 327155712,
      remainingBytes: 5041553408,
      blocked: false,
    );

    for (final size in const [Size(360, 640), Size(393, 851), Size(412, 915)]) {
      for (final scale in const [1.0, 1.3]) {
        for (final failed in const [false, true]) {
          final name =
              '${size.width.toInt()}x${size.height.toInt()} at $scale'
              '${failed ? ' with the error bar' : ''}';
          testWidgets('covers nothing on $name', (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
            tester.view.viewPadding = const FakeViewPadding(
              top: 24,
              bottom: 16,
            );
            tester.view.systemGestureInsets = const FakeViewPadding(
              left: 24,
              right: 24,
              bottom: 32,
            );
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.reset);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await pumpHome(
              tester,
              support: await chatOn(),
              calm: !failed,
              allowance: allowance,
            );
            expect(tester.takeException(), isNull);
            final l10n = await S.delegate.load(const Locale('en'));
            final fab = tester.getRect(button);
            final view = tester.getRect(
              find
                  .ancestor(
                    of: find.byType(PowerButton),
                    matching: find.byType(SingleChildScrollView),
                  )
                  .first,
            );
            final shown = fab.intersect(view);
            final onScreen = shown.width > 0 && shown.height > 0;
            if (!failed) {
              // On a calm screen it is always there to see, whole.
              expect(shown, fab, reason: name);
            }
            final others = <String, Finder>{
              'power button': find.byType(PowerButton),
              // The server card says the same while it is set up; the
              // status line comes first.
              'status': find
                  .text(
                    failed ? l10n.errorConnectionFailed : l10n.homePreparing,
                  )
                  .first,
              'server card': find
                  .ancestor(
                    of: find.text(l10n.yourServer),
                    matching: find.byType(InkWell),
                  )
                  .first,
              'used today': find.textContaining('used today'),
              if (failed)
                'error bar': find
                    .ancestor(
                      of: find.text('Ask support'),
                      matching: find.byType(Container),
                    )
                    .first,
            };
            for (final entry in others.entries) {
              expect(entry.value, findsOneWidget, reason: entry.key);
              final rect = tester.getRect(entry.value);
              if (!onScreen) continue;
              expect(
                shown.overlaps(rect),
                isFalse,
                reason: '$name: the button covers the ${entry.key}',
              );
            }
            // Wherever it is on screen, it is above the bottom block.
            if (onScreen) {
              expect(shown.bottom, lessThanOrEqualTo(view.bottom));
            }
          });
        }
      }
    }

    testWidgets('lines up with the server card under it', (tester) async {
      for (final size in const [Size(360, 640), Size(412, 915)]) {
        for (final locale in const [Locale('en'), Locale('fa')]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await pumpHome(
            tester,
            support: await chatOn(),
            calm: true,
            locale: locale,
            allowance: allowance,
          );
          final l10n = await S.delegate.load(locale);
          final fab = tester.getRect(button);
          final card = tester.getRect(
            find
                .ancestor(
                  of: find.text(l10n.yourServer),
                  matching: find.byType(InkWell),
                )
                .first,
          );
          final name = '$size $locale';
          if (locale.languageCode == 'en') {
            expect(fab.right, moreOrLessEquals(card.right), reason: name);
          } else {
            expect(fab.left, moreOrLessEquals(card.left), reason: name);
          }
        }
      }
    });

    testWidgets('moves up when the bottom block grows', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpHome(tester, support: await chatOn(), calm: true);
      final calm = tester.getRect(button);
      await pumpHome(tester, support: await chatOn());
      final failed = tester.getRect(button);
      final bar = tester.getRect(
        find
            .ancestor(
              of: find.text('Ask support'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(failed.bottom, lessThan(calm.bottom));
      expect(failed.bottom, lessThanOrEqualTo(bar.top));
    });

    testWidgets('a failure offers the chat once it is on', (tester) async {
      await pumpHome(tester, support: await chatOn());
      expect(find.text('Ask support'), findsOneWidget);
      // A small line of text, with a full size tap target.
      final target = tester.getSize(
        find
            .ancestor(
              of: find.text('Ask support'),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      expect(target.height, greaterThanOrEqualTo(kMinInteractiveDimension));
      expect(target.width, greaterThanOrEqualTo(kMinInteractiveDimension));
      expect(find.byTooltip('Chat with support'), findsOneWidget);
      await tester.tap(find.text('Ask support'));
      await tester.pumpAndSettle();
      expect(find.byType(SupportScreen), findsOneWidget);
    });

    testWidgets('with the chat off the home screen is as before', (
      tester,
    ) async {
      await pumpHome(tester, support: _chatWith(_Backend(enabled: false)));
      expect(find.text('Ask support'), findsNothing);
      expect(find.byTooltip('Chat with support'), findsNothing);
      final centred = tester.getCenter(find.byType(PowerButton));

      await pumpHome(tester);
      expect(find.text('Ask support'), findsNothing);
      expect(find.byTooltip('Chat with support'), findsNothing);
      expect(tester.getCenter(find.byType(PowerButton)), centred);
    });

    testWidgets('a broken SupportState leaves the connect button working', (
      tester,
    ) async {
      final vpn = await pumpHome(
        tester,
        support: _BrokenSupport(),
        connected: true,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(PowerButton), findsOneWidget);
      expect(find.text('Ask support'), findsNothing);
      expect(find.byTooltip('Chat with support'), findsNothing);
      await tester.tap(find.byType(PowerButton));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(vpn.disconnects, 1);
    });
  });
}
