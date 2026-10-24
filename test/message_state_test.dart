import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/core/state/message_state.dart';
import 'package:fortiva_vpn/data/models/in_app_message.dart';
import 'package:fortiva_vpn/services/notice_pull.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _t0 = DateTime.utc(2026, 10, 6, 7);

/// A message as the backend sends it.
Map<String, dynamic> wire(
  int id, {
  String language = 'en',
  Duration sentAgo = Duration.zero,
  Duration lasts = const Duration(days: 7),
  DateTime? at,
}) {
  final sent = (at ?? _t0).subtract(sentAgo);
  return {
    'id': id,
    'language': language,
    'title': 'Title $id',
    'body': 'Body $id',
    'button': null,
    'link': null,
    'sent_at': sent.toIso8601String(),
    'ends_at': sent.add(lasts).toIso8601String(),
  };
}

/// Answers a check with [messages], on a server clock of [serverTime].
MessagesPage page(
  List<Map<String, dynamic>> messages, {
  DateTime? serverTime,
}) => MessagesPage.fromJson({
  'server_time': (serverTime ?? _t0).toIso8601String(),
  'messages': messages,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late String language;
  late bool chosen;
  late String deviceId;
  late int registers;
  late List<String> fetchedIn;
  late List<Map<String, dynamic>> posted;
  late FutureOr<MessagesPage> Function() answer;
  late FutureOr<void> Function(Map<String, dynamic> body) receive;

  MessageState make({Duration flushDelay = const Duration(seconds: 10)}) =>
      MessageState(
        fetch: (id, lang) async {
          expect(id, deviceId);
          fetchedIn.add(lang);
          return answer();
        },
        post: (id, body) async {
          expect(id, deviceId);
          await receive(body);
          posted.add(body);
        },
        deviceId: () async => deviceId,
        register: () async {
          registers++;
          deviceId = 'DEV-registered';
        },
        language: () => language,
        languageChosen: () => chosen,
        clock: () => now,
        flushDelay: flushDelay,
      );

  /// The receipts in every batch posted so far, as `id:kind`.
  List<String> receipts() => [
    for (final body in posted)
      for (final r in body['receipts'] as List)
        '${(r as Map)['message_id']}:${r['kind']}',
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = _t0;
    language = 'en';
    chosen = true;
    deviceId = 'DEV-1';
    registers = 0;
    fetchedIn = [];
    posted = [];
    answer = () => page([wire(1)]);
    receive = (_) {};
  });

  group('checking', () {
    test('lists what the server sent, as it sent it', () async {
      answer = () => page([
        wire(2, sentAgo: const Duration(hours: 1)),
        wire(1, sentAgo: const Duration(hours: 2)),
      ]);
      final s = make();
      await s.refresh();
      expect(s.messages.map((m) => m.id), [2, 1]);
      expect(s.unreadCount, 2);
      expect(s.lastAttemptFailed, isFalse);
      s.dispose();
    });

    test('skips a check within five minutes of a good one', () async {
      final s = make();
      await s.refresh();
      now = now.add(const Duration(minutes: 4));
      await s.refresh();
      expect(fetchedIn, hasLength(1));
      await s.refresh(force: true);
      expect(fetchedIn, hasLength(2));
      now = now.add(const Duration(minutes: 6));
      await s.refresh();
      expect(fetchedIn, hasLength(3));
      s.dispose();
    });

    test('a forced call during a check runs one more after it', () async {
      final gate = Completer<MessagesPage>();
      answer = () => gate.future;
      final s = make();
      final first = s.refresh();
      await Future<void>.delayed(Duration.zero);
      // Three calls while the first is in flight: one is unforced and
      // ignored, the two forced ones fold into a single extra check.
      unawaited(s.refresh());
      unawaited(s.refresh(force: true));
      unawaited(s.refresh(force: true));
      answer = () => page([wire(1), wire(2)]);
      gate.complete(page([wire(1)]));
      await first;
      expect(fetchedIn, hasLength(2));
      expect(s.messages.map((m) => m.id), [1, 2]);
      s.dispose();
    });

    test('an unforced call during a check runs nothing more', () async {
      final gate = Completer<MessagesPage>();
      answer = () => gate.future;
      final s = make();
      final first = s.refresh();
      await Future<void>.delayed(Duration.zero);
      unawaited(s.refresh());
      gate.complete(page([wire(1)]));
      await first;
      expect(fetchedIn, hasLength(1));
      s.dispose();
    });

    test('every kind of failure is caught and keeps the saved list', () async {
      final s = make();
      await s.refresh();
      expect(s.messages, hasLength(1));
      for (final failure in <Object>[
        TimeoutException('slow'),
        const HandshakeException('cut'),
        const SocketException('down'),
        const FormatException('captive portal'),
        ApiException(statusCode: 503, message: 'down'),
        ApiException(statusCode: 0, message: 'No internet connection'),
        StateError('bug'),
        ArgumentError('bug'),
      ]) {
        answer = () => throw failure;
        await s.refresh(force: true);
        expect(s.lastAttemptFailed, isTrue, reason: '$failure');
        expect(s.messages.map((m) => m.id), [1], reason: '$failure');
      }
      // A check runs again after all of them: the in-flight flag cleared.
      answer = () => page([wire(1), wire(2)]);
      await s.refresh(force: true);
      expect(s.messages, hasLength(2));
      expect(s.lastAttemptFailed, isFalse);
      s.dispose();
    });

    test('a 503 keeps the list saved by an earlier run', () async {
      final first = make();
      await first.refresh();
      first.dispose();

      answer = () => throw ApiException(statusCode: 503, message: 'db');
      final second = make();
      await second.refresh();
      expect(second.lastAttemptFailed, isTrue);
      expect(second.messages.map((m) => m.id), [1]);
      second.dispose();
    });

    test('a 404 registers the device and asks once more', () async {
      var calls = 0;
      answer = () {
        calls++;
        if (deviceId == 'DEV-1') {
          throw ApiException(statusCode: 404, message: 'Not found');
        }
        return page([wire(1)]);
      };
      final s = make();
      await s.refresh();
      expect(registers, 1);
      expect(calls, 2);
      expect(s.messages, hasLength(1));
      s.dispose();
    });

    test('a 404 after registering is a failure, not a loop', () async {
      answer = () => throw ApiException(statusCode: 404, message: 'Not found');
      final s = make();
      await s.refresh();
      expect(registers, 1);
      expect(fetchedIn, hasLength(2));
      expect(s.lastAttemptFailed, isTrue);
      s.dispose();
    });

    test('nothing is fetched before the user has chosen a language', () async {
      chosen = false;
      final s = make();
      await s.refresh(force: true);
      expect(fetchedIn, isEmpty);
      chosen = true;
      await s.refresh();
      expect(fetchedIn, ['en']);
      s.dispose();
    });

    test('a change of app language fetches again at once', () async {
      final s = make();
      await s.refresh();
      language = 'fa';
      now = now.add(const Duration(minutes: 1));
      await s.refresh();
      expect(fetchedIn, ['en', 'fa']);
      s.dispose();
    });

    test('expiry reads the server clock, not the phone clock', () async {
      // The phone is a day behind. The message ends in two hours on the
      // server's clock, so on the phone's own clock it would stay for a
      // day and two hours.
      now = _t0.subtract(const Duration(days: 1));
      answer = () => page([wire(1, lasts: const Duration(hours: 2))]);
      final s = make();
      await s.refresh();
      expect(s.messages, hasLength(1));
      now = now.add(const Duration(hours: 3));
      expect(s.messages, isEmpty);
      expect(s.unreadCount, 0);
      s.dispose();

      // The gap is saved with the list, so the next run agrees.
      final again = make();
      await Future<void>.delayed(Duration.zero);
      expect(again.messages, isEmpty);
      now = now.subtract(const Duration(hours: 2));
      expect(again.messages, hasLength(1));
      again.dispose();
    });
  });

  group('receipts', () {
    test(
      'received is queued once per message, however often it is listed',
      () async {
        final s = make(flushDelay: Duration.zero);
        await s.refresh();
        await s.refresh(force: true);
        await s.flush();
        expect(receipts(), ['1:received']);
        final r = (posted.single['receipts'] as List).single as Map;
        expect(r['language'], 'en');
        expect(r['at'], endsWith('Z'));
        expect(posted.single['sent_at'], endsWith('Z'));
        s.dispose();
      },
    );

    test('kinds wait for a quiet spell and then go together', () async {
      // The app waits ten seconds; the same rule on a shorter delay here.
      final s = make(flushDelay: const Duration(milliseconds: 300));
      final m = InAppMessage.tryParse(wire(1))!;
      await s.report(m, ReceiptKind.received);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await s.report(m, ReceiptKind.shown);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await s.report(m, ReceiptKind.dismissed);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(posted, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(posted, hasLength(1));
      expect(receipts(), ['1:received', '1:shown', '1:dismissed']);
      s.dispose();
    });

    test('each kind is sent at most once per message', () async {
      final s = make(flushDelay: Duration.zero);
      final m = InAppMessage.tryParse(wire(1))!;
      for (var i = 0; i < 3; i++) {
        await s.report(m, ReceiptKind.shown);
        await s.report(m, ReceiptKind.clicked);
      }
      await s.flush();
      expect(receipts(), ['1:shown', '1:clicked']);
      s.dispose();
    });

    test('the queue survives into the next run', () async {
      receive = (_) => throw ApiException(statusCode: 0, message: 'offline');
      final first = make(flushDelay: Duration.zero);
      final m = InAppMessage.tryParse(wire(1))!;
      await first.report(m, ReceiptKind.shown);
      await first.flush();
      expect(await first.pendingReceipts(), 1);
      first.dispose();

      receive = (_) {};
      final second = make(flushDelay: Duration.zero);
      await second.flush();
      expect(receipts(), ['1:shown']);
      expect(await second.pendingReceipts(), 0);
      // Already queued once, so not again.
      await second.report(m, ReceiptKind.shown);
      expect(await second.pendingReceipts(), 0);
      second.dispose();
    });

    test('sends in batches of 50, oldest first', () async {
      final s = make(flushDelay: const Duration(hours: 1));
      for (var id = 1; id <= 120; id++) {
        await s.report(InAppMessage.tryParse(wire(id))!, ReceiptKind.received);
      }
      await s.flush();
      expect(posted.map((b) => (b['receipts'] as List).length), [50, 50, 20]);
      expect(receipts().first, '1:received');
      expect(receipts().last, '120:received');
      s.dispose();
    });

    test('keeps at most 200, dropping the oldest', () async {
      receive = (_) => throw ApiException(statusCode: 0, message: 'offline');
      final s = make(flushDelay: const Duration(hours: 1));
      for (var id = 1; id <= 205; id++) {
        await s.report(InAppMessage.tryParse(wire(id))!, ReceiptKind.received);
      }
      expect(await s.pendingReceipts(), 200);
      receive = (_) {};
      await s.flush();
      expect(receipts().first, '6:received');
      s.dispose();
    });

    test('stops at the first failure and keeps the rest', () async {
      final s = make(flushDelay: const Duration(hours: 1));
      for (var id = 1; id <= 60; id++) {
        await s.report(InAppMessage.tryParse(wire(id))!, ReceiptKind.received);
      }
      var sends = 0;
      receive = (_) {
        if (++sends == 2) {
          throw ApiException(statusCode: 502, message: 'bad gateway');
        }
      };
      await s.flush();
      expect(posted, hasLength(1));
      expect(await s.pendingReceipts(), 10);
      s.dispose();
    });

    test('a batch refused with 413 or 422 is dropped', () async {
      final s = make(flushDelay: const Duration(hours: 1));
      for (var id = 1; id <= 60; id++) {
        await s.report(InAppMessage.tryParse(wire(id))!, ReceiptKind.received);
      }
      var sends = 0;
      receive = (_) {
        sends++;
        if (sends == 1) throw ApiException(statusCode: 413, message: 'big');
        if (sends == 2) throw ApiException(statusCode: 422, message: 'bad');
      };
      await s.flush();
      expect(sends, 2);
      expect(await s.pendingReceipts(), 0);
      s.dispose();
    });

    test('a 404 registers the device and sends again', () async {
      final s = make(flushDelay: const Duration(hours: 1));
      await s.report(InAppMessage.tryParse(wire(1))!, ReceiptKind.shown);
      receive = (_) {
        if (deviceId == 'DEV-1') {
          throw ApiException(statusCode: 404, message: 'Not found');
        }
      };
      await s.flush();
      expect(registers, 1);
      expect(receipts(), ['1:shown']);
      s.dispose();
    });

    test('with diagnostics sharing off nothing is queued or sent', () async {
      final s = make(flushDelay: Duration.zero);
      final m = InAppMessage.tryParse(wire(1))!;
      await s.report(m, ReceiptKind.shown);
      expect(await s.pendingReceipts(), 1);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pref_share_diagnostics', false);
      await s.report(m, ReceiptKind.clicked);
      await s.flush();
      expect(posted, isEmpty);
      // What was queued before the switch went off is cleared, not kept
      // for later.
      expect(await s.pendingReceipts(), 0);
      await s.refresh();
      expect(await s.pendingReceipts(), 0);
      s.dispose();
    });
  });

  group('popup', () {
    test('comes only from a check made by this run', () async {
      final first = make();
      await first.refresh();
      expect(first.pendingPopup?.id, 1);
      first.dispose();

      // The next run has the saved list, but nothing pops up from it.
      answer = () => throw ApiException(statusCode: 503, message: 'down');
      final second = make();
      await second.refresh();
      expect(second.messages, hasLength(1));
      expect(second.pendingPopup, isNull);
      second.dispose();
    });

    test('offers the newest message', () async {
      answer = () => page([
        wire(1, sentAgo: const Duration(hours: 3)),
        wire(3, sentAgo: const Duration(hours: 1)),
        wire(2, sentAgo: const Duration(hours: 2)),
      ]);
      final s = make();
      await s.refresh();
      expect(s.pendingPopup?.id, 3);
      s.dispose();
    });

    test('pops up once per run, and never again later', () async {
      answer = () => page([
        wire(1, sentAgo: const Duration(hours: 2)),
        wire(2, sentAgo: const Duration(hours: 1)),
      ]);
      final s = make();
      await s.refresh();
      await s.markPopped(2);
      expect(s.pendingPopup, isNull);
      // A popped message is not unread: the user has seen it.
      expect(s.unreadCount, 1);
      s.dispose();

      // Message 1 is older than the one that popped up, so it never pops
      // up, even in a later run.
      final next = make();
      await next.refresh();
      expect(next.pendingPopup, isNull);
      expect(next.unreadCount, 1);
      next.dispose();
    });

    test('a newer message pops up in a later run', () async {
      final s = make();
      await s.refresh();
      await s.markPopped(1);
      s.dispose();

      now = now.add(const Duration(hours: 1));
      answer = () => page([wire(2, at: now), wire(1)], serverTime: now);
      final next = make();
      await next.refresh();
      expect(next.pendingPopup?.id, 2);
      next.dispose();
    });

    test('a message read in the inbox does not pop up', () async {
      final s = make();
      await s.refresh();
      await s.markAllRead();
      expect(s.unreadCount, 0);
      expect(s.pendingPopup, isNull);
      s.dispose();

      final next = make();
      await next.refresh();
      expect(next.pendingPopup, isNull);
      next.dispose();
    });

    test('only a message in the app language pops up', () async {
      language = 'fa';
      answer = () => page([wire(1, language: 'en')]);
      final s = make();
      await s.refresh();
      expect(s.messages, hasLength(1));
      expect(s.unreadCount, 1);
      expect(s.pendingPopup, isNull);
      s.dispose();
    });

    test('an ended message does not pop up', () async {
      answer = () => page([wire(1, lasts: const Duration(minutes: 1))]);
      final s = make();
      await s.refresh();
      now = now.add(const Duration(minutes: 2));
      expect(s.pendingPopup, isNull);
      s.dispose();
    });

    test('closed by the app, it goes back to the inbox unread', () async {
      final s = make();
      await s.refresh();
      await s.markPopped(1);
      expect(s.unreadCount, 0);
      await s.returnToInbox(1);
      expect(s.unreadCount, 1);
      // And it does not pop up again.
      expect(s.pendingPopup, isNull);
      s.dispose();
    });
  });

  group('saved state', () {
    test('a corrupt or wrongly typed value reads as empty', () async {
      SharedPreferences.setMockInitialValues({
        MessageState.cacheKey: '{not json',
        MessageState.poppedKey: 42,
        MessageState.readKey: '["a list"]',
        MessageState.reportedKey: true,
        MessageState.receiptsKey: '{"a": "map"}',
        MessageState.lastPoppedKey: 'never',
      });
      final s = make(flushDelay: Duration.zero);
      await s.refresh();
      expect(s.messages, hasLength(1));
      expect(s.pendingPopup?.id, 1);
      await s.flush();
      expect(receipts(), ['1:received']);
      s.dispose();
    });

    test('read and popped are pruned only when the message ends', () async {
      answer = () => page([wire(1, lasts: const Duration(days: 1))]);
      final s = make();
      await s.refresh();
      await s.markAllRead();
      s.dispose();

      // The next list leaves message 1 out. It is still read.
      answer = () => page([]);
      final second = make();
      await second.refresh();
      second.dispose();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MessageState.readKey), contains('"1"'));

      // Once it has ended it is forgotten.
      now = now.add(const Duration(days: 2));
      final third = make();
      await third.refresh();
      await third.markPopped(99);
      await third.markAllRead();
      third.dispose();
      answer = () => page([wire(2, at: now)], serverTime: now);
      final fourth = make();
      await fourth.refresh();
      await fourth.markAllRead();
      fourth.dispose();
      expect(prefs.getString(MessageState.readKey), isNot(contains('"1"')));
      expect(prefs.getString(MessageState.readKey), contains('"2"'));
    });

    test('reset forgets the list, the badge and the queue', () async {
      final s = make(flushDelay: const Duration(hours: 1));
      await s.refresh();
      expect(s.unreadCount, 1);
      expect(await s.pendingReceipts(), 1);
      await s.reset();
      expect(s.messages, isEmpty);
      expect(s.unreadCount, 0);
      expect(s.pendingPopup, isNull);
      expect(await s.pendingReceipts(), 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MessageState.cacheKey), isNull);
      s.dispose();
    });

    test('a check in flight during reset drops what it gets', () async {
      final gate = Completer<MessagesPage>();
      answer = () => gate.future;
      final s = make(flushDelay: const Duration(hours: 1));
      final checking = s.refresh();
      await Future<void>.delayed(Duration.zero);
      await s.reset();
      gate.complete(page([wire(1)]));
      await checking;
      expect(s.messages, isEmpty);
      expect(await s.pendingReceipts(), 0);
      // And a check after it runs.
      answer = () => page([wire(2)]);
      await s.refresh();
      expect(s.messages.map((m) => m.id), [2]);
      s.dispose();
    });

    test('a 404 answered after reset does not register again', () async {
      final gate = Completer<MessagesPage>();
      answer = () => gate.future;
      final s = make(flushDelay: const Duration(hours: 1));
      final checking = s.refresh();
      await Future<void>.delayed(Duration.zero);
      await s.reset();
      gate.completeError(ApiException(statusCode: 404, message: 'Not found'));
      await checking;
      expect(registers, 0);
      expect(s.lastAttemptFailed, isFalse);
      s.dispose();
    });

    test('receipts still being queued during reset are dropped', () async {
      answer = () => page([wire(1), wire(2), wire(3)]);
      final first = Completer<void>();
      final release = Completer<void>();
      var asked = 0;
      final s = MessageState(
        fetch: (_, _) async => answer(),
        post: (_, body) async => posted.add(body),
        deviceId: () async => deviceId,
        register: () async {},
        sharing: () async {
          if (asked++ == 0) {
            first.complete();
            await release.future;
          }
          return true;
        },
        language: () => language,
        clock: () => now,
        flushDelay: const Duration(hours: 1),
      );
      final checking = s.refresh();
      await first.future;
      await s.reset();
      release.complete();
      await checking;
      expect(await s.pendingReceipts(), 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MessageState.reportedKey), isNull);

      // A report started before reset and finished after it is dropped too.
      final slow = Completer<void>();
      final t = MessageState(
        fetch: (_, _) async => answer(),
        post: (_, body) async => posted.add(body),
        deviceId: () async => deviceId,
        register: () async {},
        sharing: () async {
          await slow.future;
          return true;
        },
        language: () => language,
        clock: () => now,
        flushDelay: const Duration(hours: 1),
      );
      final reporting = t.report(
        InAppMessage.tryParse(wire(1))!,
        ReceiptKind.shown,
      );
      await Future<void>.delayed(Duration.zero);
      await t.reset();
      slow.complete();
      await reporting;
      expect(await t.pendingReceipts(), 0);
      s.dispose();
      t.dispose();
    });

    test(
      'a send in flight during reset does not touch the new queue',
      () async {
        final s = make(flushDelay: const Duration(hours: 1));
        await s.report(InAppMessage.tryParse(wire(1))!, ReceiptKind.shown);
        final gate = Completer<void>();
        receive = (_) => gate.future;
        final sending = s.flush();
        await Future<void>.delayed(Duration.zero);
        await s.reset();
        await s.report(InAppMessage.tryParse(wire(1))!, ReceiptKind.shown);
        gate.complete();
        await sending;
        expect(await s.pendingReceipts(), 1);
        s.dispose();
      },
    );
  });

  test('app language: chosen, else the phone, else English', () {
    expect(MessageState.appLanguage(const Locale('fa')), 'fa');
    expect(MessageState.appLanguage(null, const Locale('pt', 'BR')), 'pt');
    expect(MessageState.appLanguage(null, const Locale('sv')), 'en');
    expect(
      MessageState.appLanguage(const Locale('sv'), const Locale('de')),
      'de',
    );
  });

  test('the saved list is plain JSON', () async {
    final s = make();
    await s.refresh();
    s.dispose();
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString(MessageState.cacheKey)!) as Map;
    expect(saved['offset_ms'], 0);
    expect((saved['messages'] as List).single['id'], 1);
  });

  group('what the background check found', () {
    /// What NoticePull keeps after a check that was current at [at].
    void found(DateTime at, List<Map<String, dynamic>> messages) {
      SharedPreferences.setMockInitialValues({
        NoticePull.foundKey: jsonEncode({
          'at': at.toIso8601String(),
          'messages': messages,
        }),
      });
    }

    test('a message it found is listed when the app cannot reach us, and '
        'can be opened by its id', () async {
      found(_t0, [wire(7, sentAgo: const Duration(minutes: 5))]);
      answer = () => throw const SocketException('cut');
      final s = make();
      await s.adoptBackground();
      await s.refresh();
      expect(s.messages.map((m) => m.id), [7]);
      expect(s.byId(7)?.title, 'Title 7');
      expect(s.unreadCount, 1);
    });

    test('it is merged in, newest first, beside what the app already '
        'has', () async {
      answer = () => page([wire(1, sentAgo: const Duration(hours: 3))]);
      final s = make();
      await s.refresh();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        NoticePull.foundKey,
        jsonEncode({
          'at': _t0.add(const Duration(hours: 1)).toIso8601String(),
          'messages': [wire(1), wire(8, sentAgo: const Duration(hours: 1))],
        }),
      );
      await s.adoptBackground();
      expect(s.messages.map((m) => m.id), [8, 1]);
    });

    test('what it found before the app\'s own last check is not taken up: a '
        'message withdrawn since does not come back', () async {
      answer = () => page([], serverTime: _t0.add(const Duration(hours: 1)));
      final s = make();
      await s.refresh();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        NoticePull.foundKey,
        jsonEncode({
          'at': _t0.toIso8601String(),
          'messages': [wire(9)],
        }),
      );
      await s.adoptBackground();
      expect(s.messages, isEmpty);
    });

    test('a message that got a notification does not pop up as well', () async {
      SharedPreferences.setMockInitialValues({
        NoticePull.notifiedKey: jsonEncode({
          '3': _t0.add(const Duration(days: 7)).toIso8601String(),
        }),
      });
      answer = () => page([wire(3)]);
      final s = make();
      await s.adoptBackground();
      await s.refresh();
      expect(s.messages.map((m) => m.id), [3]);
      expect(s.pendingPopup, isNull);
    });

    test('an account deletion forgets it too', () async {
      found(_t0, [wire(7)]);
      final s = make();
      await s.adoptBackground();
      await s.reset();
      final prefs = await SharedPreferences.getInstance();
      for (final key in NoticePull.keys) {
        expect(prefs.containsKey(key), isFalse, reason: key);
      }
    });
  });
}
