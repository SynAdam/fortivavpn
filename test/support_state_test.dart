import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/support_service.dart';
import 'package:fortiva_vpn/core/state/support_state.dart';
import 'package:fortiva_vpn/data/models/support_chat.dart';
import 'package:fortiva_vpn/services/failure_verdict.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _t0 = DateTime.utc(2026, 10, 7, 12);

/// A quota as the backend sends it.
Map<String, dynamic> quotaJson({
  int limit = 10,
  int remaining = 7,
  int conversationLeft = 4,
  DateTime? resetsAt,
  DateTime? conversationResetsAt,
  DateTime? pausedUntil,
  DateTime? serverTime,
}) => {
  'limit': limit,
  'remaining': remaining,
  'conversation_limit': 6,
  'conversation_left': conversationLeft,
  'resets_at': (resetsAt ?? _t0.add(const Duration(hours: 8)))
      .toIso8601String(),
  'conversation_resets_at': conversationResetsAt?.toIso8601String(),
  'paused_until': pausedUntil?.toIso8601String(),
  'server_time': (serverTime ?? _t0).toIso8601String(),
};

/// A message as the backend sends it.
Map<String, dynamic> wire(
  int id, {
  String role = 'assistant',
  String status = 'sent',
  String? code,
  String? clientId,
  String text = 'Text',
  DateTime? at,
}) => {
  'id': id,
  'client_id': clientId,
  'role': role,
  'status': status,
  'code': code,
  'redacted': false,
  'text': text,
  'rating': null,
  'created_at': (at ?? _t0.add(Duration(seconds: id))).toIso8601String(),
};

/// The backend, as far as the chat sees it. Each answer can be swapped by
/// a test; every call is recorded.
class FakeSupport implements SupportService {
  FutureOr<SupportStatus> Function() onStatus = () => SupportStatus.fromJson({
    'enabled': true,
    'mode': 'ai',
    'quota': quotaJson(),
    'thread': {'id': 1, 'ticket': 'none'},
    'pending': false,
  });

  FutureOr<SupportPage> Function(int after) onFetch = (_) =>
      SupportPage.fromJson({
        'server_time': _t0.toIso8601String(),
        'mode': 'ai',
        'quota': quotaJson(),
        'pending': false,
        'messages': [],
      });

  late FutureOr<SupportReply> Function(Map<String, dynamic> body) onSend =
      (body) => SupportReply.fromJson({
        'message': wire(
          100 + sent.length,
          role: 'user',
          status: body['to'] == 'staff' ? 'to_staff' : 'queued',
          clientId: body['client_id'] as String,
          text: body['text'] as String,
        ),
        'quota': quotaJson(remaining: 6),
        'thread': {'id': 1, 'ticket': 'none'},
        'mode': 'ai',
      });

  FutureOr<void> Function(int id, String value) onRate = (_, _) {};

  FutureOr<SupportReply> Function() onNew = () => SupportReply.fromJson({
    'quota': quotaJson(conversationLeft: 6),
    'thread': {'id': 2, 'ticket': 'none'},
  });

  int statusCalls = 0;
  final fetchedAfter = <int>[];
  final sent = <Map<String, dynamic>>[];
  final rated = <String>[];
  int newCalls = 0;

  @override
  Future<SupportStatus> status(String deviceId) async {
    statusCalls++;
    return onStatus();
  }

  @override
  Future<SupportPage> fetch(String deviceId, int after, String lang) async {
    fetchedAfter.add(after);
    return onFetch(after);
  }

  @override
  Future<SupportReply> send(String deviceId, Map<String, dynamic> body) async {
    final reply = await onSend(body);
    sent.add(body);
    return reply;
  }

  @override
  Future<void> rate(String deviceId, int messageId, String value) async {
    await onRate(messageId, value);
    rated.add('$messageId:$value');
  }

  @override
  Future<SupportReply> startNew(String deviceId) async {
    newCalls++;
    return onNew();
  }
}

ApiException refusal(
  int status,
  String code, {
  Map<String, dynamic>? quota,
  Duration retryIn = const Duration(minutes: 5),
}) => ApiException(
  statusCode: status,
  message: code,
  body: {
    'detail': {
      'code': code,
      'retry_at': _t0.add(retryIn).toIso8601String(),
      'quota': ?quota,
    },
  },
);

/// A page of the conversation as the backend sends it.
SupportPage page(List<Map<String, dynamic>> messages, {bool pending = false}) =>
    SupportPage.fromJson({
      'server_time': _t0.toIso8601String(),
      'mode': 'ai',
      'pending': pending,
      'messages': messages,
    });

/// Lets every call started without awaiting it run to its end.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSupport backend;
  late DateTime now;
  late int registers;
  late bool sharing;
  late int ids;

  SupportState make({
    bool connected = false,
    String? problem,
    Future<bool> Function()? playBilling,
    bool Function()? searching,
    List<Map<String, Object>> Function()? recentTaps,
  }) => SupportState(
    service: backend,
    deviceId: () async => 'DEV-1',
    register: () async => registers++,
    sharing: () async => sharing,
    phone: () async => {
      'network': 'mobile',
      'carrier': 'MCI',
      'android': '14',
      'phone': {'vpn_permission': true},
    },
    playBilling: playBilling,
    connected: () => connected,
    problem: () => problem,
    searching: searching,
    recentTaps: recentTaps,
    language: () => 'fa',
    clock: () => now,
    foreground: () => true,
    newClientId: () => 'client-${ids++}',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = FakeSupport();
    now = _t0;
    registers = 0;
    sharing = true;
    ids = 1;
  });

  group('status', () {
    test('the chat is on only when the backend says so', () async {
      final s = make();
      expect(s.enabled, isFalse);
      await s.checkStatus(force: true);
      expect(s.enabled, isTrue);
      expect(s.mode, 'ai');
      expect(s.quota?.remaining, 7);
      s.dispose();
    });

    test('the last answer is kept for the next run', () async {
      final first = make();
      await first.checkStatus(force: true);
      first.dispose();

      backend.onStatus = () => throw const SocketException('down');
      final second = make();
      await Future<void>.delayed(Duration.zero);
      expect(second.enabled, isTrue);
      await second.checkStatus(force: true);
      expect(second.enabled, isTrue);
      second.dispose();
    });

    test('a 503 with code off turns the chat off and is saved', () async {
      final s = make();
      await s.checkStatus(force: true);
      backend.onStatus = () => throw refusal(503, 'off');
      await s.checkStatus(force: true);
      expect(s.enabled, isFalse);
      s.dispose();

      final again = make();
      await Future<void>.delayed(Duration.zero);
      expect(again.enabled, isFalse);
      again.dispose();
    });

    test('enabled false from the backend turns the chat off', () async {
      final s = make();
      await s.checkStatus(force: true);
      backend.onStatus = () => SupportStatus.fromJson({'enabled': false});
      await s.checkStatus(force: true);
      expect(s.enabled, isFalse);
      s.dispose();
    });

    test('an unknown phone is not registered by the status check', () async {
      backend.onStatus = () =>
          throw ApiException(statusCode: 404, message: 'Not found');
      final s = make();
      await s.checkStatus(force: true);
      expect(registers, 0);
      expect(s.enabled, isFalse);
      s.dispose();
    });

    test('a call during a check that fails runs one more after it', () async {
      final gate = Completer<SupportStatus>();
      backend.onStatus = () => gate.future;
      final s = make();
      final first = s.checkStatus(force: true);
      await Future<void>.delayed(Duration.zero);
      // What the app does when the register lands.
      unawaited(s.checkStatus());
      backend.onStatus = () =>
          SupportStatus.fromJson({'enabled': true, 'mode': 'ai'});
      gate.completeError(ApiException(statusCode: 404, message: 'Not found'));
      await first;
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(backend.statusCalls, 2);
      expect(s.enabled, isTrue);
      s.dispose();
    });

    test('a check within five minutes of a good one is skipped', () async {
      final s = make();
      await s.checkStatus();
      now = now.add(const Duration(minutes: 4));
      await s.checkStatus();
      expect(backend.statusCalls, 1);
      now = now.add(const Duration(minutes: 2));
      await s.checkStatus();
      expect(backend.statusCalls, 2);
      s.dispose();
    });
  });

  group('sending', () {
    test('a question is stored and the fetch schedule starts', () async {
      final s = make();
      await s.checkStatus(force: true);
      final result = await s.send('  وصل نمیشه  ');
      expect(result.outcome, SupportSendOutcome.sent);
      expect(backend.sent.single['text'], 'وصل نمیشه');
      expect(backend.sent.single['to'], 'assistant');
      expect(backend.sent.single['lang'], 'fa');
      expect(backend.sent.single['client_id'], 'client-1');
      expect(s.pending, isTrue);
      expect(s.pendingSince, _t0.add(const Duration(seconds: 100)));
      expect(s.quota?.remaining, 6);
      expect(s.messages.single.text, 'وصل نمیشه');
      expect(s.outbox, isEmpty);
      expect(s.nextPollDelay(), const Duration(seconds: 2));
      s.dispose();
    });

    test('nothing is posted while another question waits', () async {
      final s = make();
      await s.checkStatus(force: true);
      await s.send('first');
      final second = await s.send('second');
      expect(second.outcome, SupportSendOutcome.refused);
      expect(second.code, 'wait_reply');
      expect(backend.sent, hasLength(1));
      // Nothing about a waiting question sends it to our team instead.
      expect(s.writesToTeam, isFalse);
      s.dispose();
    });

    test('empty and over-long text never leaves the phone', () async {
      final s = make();
      await s.checkStatus(force: true);
      expect((await s.send('   ')).code, 'empty');
      expect((await s.send('a' * 501)).code, 'too_long');
      // 500 code points, though more UTF-16 units, is allowed.
      expect(
        (await s.send('\u{1F44D}' * 500)).outcome,
        SupportSendOutcome.sent,
      );
      expect(backend.sent, hasLength(1));
      s.dispose();
    });

    test('with automatic answers off every message goes to our team', () async {
      backend.onStatus = () => SupportStatus.fromJson({
        'enabled': true,
        'mode': 'staff',
        'quota': quotaJson(),
        'pending': false,
      });
      final s = make();
      await s.checkStatus(force: true);
      expect(s.teamOnly, isTrue);
      await s.send('help');
      expect(backend.sent.single['to'], 'staff');
      expect(s.pending, isFalse);
      expect(s.limit, isNull);
      s.dispose();
    });

    test('with sharing off a message says only whether it is connected, '
        'whether it is still searching, and whether this copy can buy '
        'through Google Play', () async {
      sharing = false;
      final s = make(
        connected: true,
        problem: 'network_trouble',
        playBilling: () async => true,
        searching: () => true,
        recentTaps: () => [
          {'ago_s': 30, 'took_s': 12, 'outcome': 'stopped'},
        ],
      );
      await s.checkStatus(force: true);
      await s.send('hi there');
      expect(backend.sent.single['context'], {
        'connected': true,
        'searching': true,
        'play_billing': true,
      });
      s.dispose();
    });

    test('with sharing on a message carries the phone facts', () async {
      final s = make(problem: 'phone_offline');
      await s.checkStatus(force: true);
      await s.send('nothing opens');
      expect(backend.sent.single['context'], {
        'connected': false,
        'searching': false,
        'play_billing': false,
        'problem': 'phone_offline',
        'network': 'mobile',
        'carrier': 'MCI',
        'android': '14',
        'phone': {'vpn_permission': true},
      });
      s.dispose();
    });

    // clients C4 of the plan of 2026-10-23: from 10-20 to 10-23 the
    // assistant was told "connecting" 0 times, while 6 of 9 phones that
    // complained were in a search, and its tap counts came from traces a
    // stuck phone sends late.
    test('with sharing on a message says the app is still searching and '
        'how its latest taps ended', () async {
      final taps = [
        {'ago_s': 20, 'took_s': 20},
        {'ago_s': 140, 'took_s': 30, 'outcome': 'all_closed'},
      ];
      final s = make(searching: () => true, recentTaps: () => taps);
      await s.checkStatus(force: true);
      await s.send('چرا وصل نمیشه');
      final context = backend.sent.single['context'] as Map;
      expect(context['searching'], isTrue);
      expect(context['recent_taps'], taps);
      expect(context['connected'], isFalse);
      s.dispose();
    });

    test('no recent taps, no key; a check that throws sends the message '
        'all the same', () async {
      final s = make(
        searching: () => throw StateError('no flow'),
        recentTaps: () => const [],
      );
      await s.checkStatus(force: true);
      final result = await s.send('سلام');
      expect(result.outcome, SupportSendOutcome.sent);
      final context = backend.sent.single['context'] as Map;
      expect(context['searching'], isFalse);
      expect(context.containsKey('recent_taps'), isFalse);
      s.dispose();
    });

    // The assistant must not point a user of the channel APK, where Google
    // Play cannot sell, to a Buy button it does not have.
    group('play_billing', () {
      for (final can in [true, false]) {
        test('is $can when this copy ${can ? 'can' : 'cannot'} buy through '
            'Google Play', () async {
          final s = make(playBilling: () async => can);
          await s.checkStatus(force: true);
          await s.send('how do I buy Premium?');
          final context = backend.sent.single['context'] as Map;
          expect(context['play_billing'], can);
          expect(context['phone'], {'vpn_permission': true});
          s.dispose();
        });
      }

      test(
        'is false when the check fails, and the message still goes',
        () async {
          final s = make(playBilling: () async => throw Exception('no Play'));
          await s.checkStatus(force: true);
          final result = await s.send('premium?');
          expect(result.outcome, SupportSendOutcome.sent);
          expect(backend.sent.single['context']['play_billing'], isFalse);
          s.dispose();
        },
      );

      test('is false when the check does not answer in time', () async {
        final never = Completer<bool>();
        final s = make(playBilling: () => never.future);
        await s.checkStatus(force: true);
        final result = await s.send('premium?');
        expect(result.outcome, SupportSendOutcome.sent);
        expect(backend.sent.single['context']['play_billing'], isFalse);
        s.dispose();
      });

      test('is false when nothing tells the chat', () async {
        final s = SupportState(
          service: backend,
          deviceId: () async => 'DEV-1',
          register: () async => registers++,
          sharing: () async => false,
          clock: () => now,
          foreground: () => true,
          newClientId: () => 'client-${ids++}',
        );
        await s.checkStatus(force: true);
        await s.send('premium?');
        expect(backend.sent.single['context'], {
          'connected': false,
          'searching': false,
          'play_billing': false,
        });
        s.dispose();
      });
    });

    test('a refusal comes back with its code and the limit', () async {
      final s = make();
      await s.checkStatus(force: true);
      final resets = _t0.add(const Duration(hours: 5, minutes: 20));
      backend.onSend = (_) => throw refusal(
        429,
        'quota_day',
        quota: quotaJson(remaining: 0, resetsAt: resets),
      );
      final result = await s.send('one more');
      expect(result.outcome, SupportSendOutcome.refused);
      expect(result.code, 'quota_day');
      expect(result.accepted, isFalse);
      expect(s.outbox, isEmpty);
      expect(s.messages, isEmpty);
      expect(s.limit?.code, 'quota_day');
      expect(s.limit?.until, resets);
      s.dispose();
    });

    test('a 503 off while sending turns the chat off', () async {
      final s = make();
      await s.checkStatus(force: true);
      backend.onSend = (_) => throw refusal(503, 'off');
      final result = await s.send('anyone?');
      expect(result.code, 'off');
      expect(s.enabled, isFalse);
      s.dispose();
    });

    test('a message that reaches no route waits with its client id', () async {
      final s = make();
      await s.checkStatus(force: true);
      backend.onSend = (_) =>
          throw ApiException(statusCode: 0, message: 'No internet connection');
      final result = await s.send('are you there');
      expect(result.outcome, SupportSendOutcome.waiting);
      expect(result.accepted, isTrue);
      expect(s.outbox.single.failed, isTrue);
      s.dispose();

      // A later run still has it, and sends it under the same id.
      final FakeSupport working = FakeSupport();
      backend = working;
      final again = make();
      await again.checkStatus(force: true);
      await again.flushOutbox();
      expect(working.sent.single['client_id'], 'client-1');
      expect(working.sent.single['text'], 'are you there');
      expect(again.outbox, isEmpty);
      again.dispose();
    });

    test('a timeout keeps the message too', () async {
      final s = make();
      await s.checkStatus(force: true);
      backend.onSend = (_) => throw TimeoutException('slow');
      expect((await s.send('slow')).outcome, SupportSendOutcome.waiting);
      backend.onSend = (_) => throw ApiException(statusCode: 502, message: '');
      await s.flushOutbox();
      expect(s.outbox, hasLength(1));
      s.dispose();
    });

    test('a later try that is refused stays in the conversation', () async {
      final s = make();
      await s.checkStatus(force: true);
      backend.onSend = (_) => throw const SocketException('down');
      await s.send('first try');
      backend.onSend = (_) => throw refusal(422, 'redacted_empty');
      await s.flushOutbox();
      expect(s.outbox, isEmpty);
      final kept = s.messages.single;
      expect(kept.local, isTrue);
      expect(kept.status, 'refused');
      expect(kept.code, 'redacted_empty');
      expect(kept.text, 'first try');
      s.dispose();
    });

    test(
      'a waiting message that meets a question being answered goes later',
      () async {
        final s = make();
        await s.checkStatus(force: true);
        final normal = backend.onSend;
        backend.onSend = (_) => throw const SocketException('down');
        await s.send('first try');
        // Another question of this phone reached us some other way.
        backend.onSend = (_) => throw refusal(409, 'wait_reply');
        backend.onFetch = (_) =>
            page([wire(50, role: 'user', status: 'answering')], pending: true);
        await s.flushOutbox();
        await settle();
        expect(s.outbox.single.text, 'first try');
        expect(s.outbox.single.failed, isTrue);
        expect(s.messages.where((m) => m.status == 'refused'), isEmpty);
        expect(s.pending, isTrue);
        expect(backend.sent, isEmpty);

        // Once that one has its answer, it goes.
        backend.onSend = normal;
        backend.onFetch = (_) => page([
          wire(50, role: 'user', status: 'handled'),
          wire(51, text: 'Answer'),
        ]);
        await s.poll();
        await settle();
        expect(backend.sent.single['text'], 'first try');
        expect(backend.sent.single['client_id'], 'client-1');
        expect(s.outbox, isEmpty);
        s.dispose();
      },
    );

    test('a message stored though its answer was lost shows once', () async {
      final s = make();
      await s.checkStatus(force: true);
      backend.onSend = (_) => throw TimeoutException('answer lost');
      await s.send('did it go');
      expect(s.outbox, hasLength(1));
      backend.onFetch = (_) => page([
        wire(
          100,
          role: 'user',
          status: 'queued',
          clientId: 'client-1',
          text: 'did it go',
        ),
      ], pending: true);
      await s.poll();
      expect(s.outbox, isEmpty);
      expect(s.messages.single.clientId, 'client-1');
      expect(s.pending, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(SupportState.outboxKey), isFalse);
      s.dispose();
    });

    test(
      'a message that could not go for a day says it was not sent',
      () async {
        final s = make();
        await s.checkStatus(force: true);
        backend.onSend = (_) => throw const SocketException('down');
        await s.send('lost in the night');
        now = now.add(const Duration(hours: 25));
        backend.onSend = (body) => throw StateError('must not be sent');
        await s.flushOutbox();
        expect(s.outbox, isEmpty);
        final kept = s.messages.single;
        expect(kept.local, isTrue);
        expect(kept.status, 'failed');
        expect(kept.code, SupportState.notSent);
        expect(kept.text, 'lost in the night');
        s.dispose();

        // It is still there on the next run.
        final again = make();
        await Future<void>.delayed(Duration.zero);
        expect(again.messages.single.code, SupportState.notSent);
        expect(again.outbox, isEmpty);
        again.dispose();
      },
    );

    test(
      'a question saved long ago does not hold back one typed offline',
      () async {
        final first = make();
        await first.checkStatus(force: true);
        await first.send('q');
        expect(first.pending, isTrue);
        first.dispose();

        backend.onStatus = () => throw const SocketException('down');
        backend.onFetch = (_) => throw const SocketException('down');
        backend.onSend = (_) => throw const SocketException('down');
        final again = make();
        await Future<void>.delayed(Duration.zero);
        // Within half an hour of it, it may still be waiting.
        now = _t0.add(const Duration(minutes: 20));
        expect(again.pending, isTrue);
        now = _t0.add(const Duration(minutes: 35));
        expect(again.pending, isFalse);
        final result = await again.send('another');
        expect(result.outcome, SupportSendOutcome.waiting);
        expect(again.outbox.single.text, 'another');
        again.dispose();
      },
    );

    test('a 404 registers the phone and sends once more', () async {
      final s = make();
      await s.checkStatus(force: true);
      var first = true;
      final normal = backend.onSend;
      backend.onSend = (body) {
        if (first) {
          first = false;
          throw ApiException(statusCode: 404, message: 'Not found');
        }
        return normal(body);
      };
      final result = await s.send('new phone');
      expect(result.outcome, SupportSendOutcome.sent);
      expect(registers, 1);
      s.dispose();
    });
  });

  group('fetching', () {
    test('the schedule after a question, then every 30 s on screen', () async {
      final s = make();
      await s.checkStatus(force: true);
      await s.send('q');
      final sentAt = now;
      Duration? at(int seconds) {
        now = sentAt.add(Duration(seconds: seconds));
        return s.nextPollDelay();
      }

      expect(at(0), const Duration(seconds: 2));
      expect(at(2), const Duration(seconds: 2));
      expect(at(4), const Duration(seconds: 3));
      expect(at(7), const Duration(seconds: 5));
      expect(at(12), const Duration(seconds: 5));
      expect(at(17), const Duration(seconds: 10));
      expect(at(27), const Duration(seconds: 10));
      expect(at(170), const Duration(seconds: 7));
      expect(at(177), const Duration(seconds: 3));
      expect(at(180), isNull);
      s.attach();
      expect(at(181), const Duration(seconds: 30));
      s.detach();
      s.dispose();
    });

    test(
      'nothing is fetched on a timer with the chat closed and nothing waiting',
      () async {
        final s = make();
        await s.checkStatus(force: true);
        expect(s.nextPollDelay(), isNull);
        s.dispose();
      },
    );

    test('fetches run at 2, 4, 7, 12 and 17 seconds after a question', () {
      fakeAsync((async) {
        final start = _t0;
        now = start;
        final s = SupportState(
          service: backend,
          deviceId: () async => 'DEV-1',
          register: () async {},
          sharing: () async => false,
          language: () => 'fa',
          clock: () => start.add(async.elapsed),
          foreground: () => true,
          newClientId: () => 'client-1',
        );
        backend.onFetch = (_) => SupportPage.fromJson({
          'server_time': start.add(async.elapsed).toIso8601String(),
          'mode': 'ai',
          'pending': true,
          'messages': [],
        });
        s.checkStatus(force: true);
        async.flushMicrotasks();
        s.send('q');
        async.flushMicrotasks();
        final seenAt = <int>[];
        var last = backend.fetchedAfter.length;
        for (var second = 1; second <= 30; second++) {
          async.elapse(const Duration(seconds: 1));
          if (backend.fetchedAfter.length > last) {
            seenAt.add(second);
            last = backend.fetchedAfter.length;
          }
        }
        expect(seenAt, [2, 4, 7, 12, 17, 27]);
        s.dispose();
      });
    });

    test('a waiting question is asked about until it is answered', () async {
      backend.onFetch = (_) => SupportPage.fromJson({
        'mode': 'ai',
        'pending': false,
        'messages': [for (var id = 1; id <= 3; id++) wire(id)],
      });
      final s = make();
      await s.checkStatus(force: true);
      await s.poll();
      expect(backend.fetchedAfter, [0]);

      await s.send('q'); // stored as 100
      backend.onFetch = (_) => SupportPage.fromJson({
        'mode': 'ai',
        'pending': true,
        'messages': [wire(100, role: 'user', status: 'answering')],
      });
      await s.poll();
      expect(backend.fetchedAfter.last, 3);
      // Asked from just before the question, not after it, so its status
      // comes back with every fetch.
      await s.poll();
      expect(backend.fetchedAfter.last, 99);

      backend.onFetch = (_) => SupportPage.fromJson({
        'mode': 'ai',
        'pending': false,
        'messages': [
          wire(100, role: 'user', status: 'handled'),
          wire(101, text: 'Answer'),
        ],
      });
      await s.poll();
      expect(s.pending, isFalse);
      expect(s.messages.last.text, 'Answer');
      await s.poll();
      expect(backend.fetchedAfter.last, 101);
      s.dispose();
    });

    test(
      'a fetch that left before a question was stored keeps it waiting',
      () async {
        final s = make();
        await s.checkStatus(force: true);
        final gate = Completer<SupportPage>();
        backend.onFetch = (_) => gate.future;
        final stale = s.poll();
        await Future<void>.delayed(Duration.zero);
        await s.send('q');
        expect(s.pending, isTrue);
        gate.complete(page(const []));
        await stale;
        expect(s.pending, isTrue);
        expect(s.nextPollDelay(), const Duration(seconds: 2));

        // A status check that left before it does not clear it either.
        final status = Completer<SupportStatus>();
        backend.onStatus = () => status.future;
        backend.onFetch = (_) =>
            page([wire(100, role: 'user', status: 'queued')], pending: true);
        final check = s.checkStatus(force: true);
        await Future<void>.delayed(Duration.zero);
        status.complete(
          SupportStatus.fromJson({
            'enabled': true,
            'mode': 'ai',
            'quota': quotaJson(),
            'pending': false,
          }),
        );
        await check;
        expect(s.pending, isTrue);
        expect(s.nextPollDelay(), const Duration(seconds: 2));
        s.dispose();
      },
    );

    test('a question the backend gave up on shows its code', () async {
      final s = make();
      await s.checkStatus(force: true);
      await s.send('q');
      backend.onFetch = (_) => SupportPage.fromJson({
        'mode': 'ai',
        'pending': false,
        'messages': [wire(100, role: 'user', status: 'failed', code: 'busy')],
      });
      await s.poll();
      expect(s.messages.single.status, 'failed');
      expect(s.messages.single.code, 'busy');
      expect(s.pending, isFalse);
      s.dispose();
    });

    test('pages are followed while full', () async {
      backend.onFetch = (after) => SupportPage.fromJson({
        'mode': 'ai',
        'pending': false,
        'messages': [
          for (var id = after + 1; id <= after + 50 && id <= 120; id++)
            wire(id),
        ],
      });
      final s = make();
      await s.checkStatus(force: true);
      await s.poll();
      expect(backend.fetchedAfter, [0, 50, 100]);
      expect(s.messages, hasLength(120));
      s.dispose();
    });

    test('a failed fetch keeps the conversation', () async {
      backend.onFetch = (_) => SupportPage.fromJson({
        'mode': 'ai',
        'messages': [wire(1)],
      });
      final s = make();
      await s.checkStatus(force: true);
      await s.poll();
      for (final failure in <Object>[
        TimeoutException('slow'),
        const SocketException('down'),
        const FormatException('captive portal'),
        ApiException(statusCode: 503, message: 'db'),
        StateError('bug'),
      ]) {
        backend.onFetch = (_) => throw failure;
        await s.poll();
        expect(s.messages, hasLength(1), reason: '$failure');
        expect(s.enabled, isTrue, reason: '$failure');
      }
      s.dispose();
    });

    test('replies count as unseen until the chat is opened', () async {
      backend.onFetch = (_) => SupportPage.fromJson({
        'mode': 'ai',
        'messages': [
          wire(1, role: 'user'),
          wire(2),
          wire(3, role: 'staff'),
          wire(4, role: 'system', code: 'ticket_opened'),
        ],
      });
      final s = make();
      await s.checkStatus(force: true);
      await s.poll();
      expect(s.unseenReplies, 2);
      s.attach();
      expect(s.unseenReplies, 0);
      s.detach();
      s.dispose();
    });
  });

  group('fetching while the chat is on screen', () {
    /// A chat on the fake clock of [async], which starts at [_t0].
    SupportState onFakeClock(FakeAsync async) => SupportState(
      service: backend,
      deviceId: () async => 'DEV-1',
      register: () async {},
      sharing: () async => false,
      language: () => 'fa',
      clock: () => _t0.add(async.elapsed),
      foreground: () => true,
      newClientId: () => 'client-1',
    );

    /// A page with nothing new while the question is still being answered.
    SupportPage stillWaiting(FakeAsync async) => SupportPage.fromJson({
      'server_time': _t0.add(async.elapsed).toIso8601String(),
      'mode': 'ai',
      'pending': true,
      'messages': [],
    });

    /// A page where the question (stored as 100) has [status], and with
    /// the answer when it was handled.
    SupportPage settled(FakeAsync async, String status, {String? code}) =>
        SupportPage.fromJson({
          'server_time': _t0.add(async.elapsed).toIso8601String(),
          'mode': 'ai',
          'pending': false,
          'messages': [
            wire(100, role: 'user', status: status, code: code),
            if (status == 'handled') wire(101, text: 'Answer'),
          ],
        });

    /// Moves the fake clock on one second at a time up to [second], and
    /// returns the seconds in which a fetch ran.
    List<int> fetchesUntil(FakeAsync async, int second) {
      final seen = <int>[];
      var count = backend.fetchedAfter.length;
      while (async.elapsed < Duration(seconds: second)) {
        async.elapse(const Duration(seconds: 1));
        if (backend.fetchedAfter.length > count) {
          seen.add(async.elapsed.inSeconds);
          count = backend.fetchedAfter.length;
        }
      }
      return seen;
    }

    /// The chat turned on and opened, with a question sent at second 0.
    SupportState askedOnScreen(FakeAsync async) {
      final s = onFakeClock(async);
      backend.onFetch = (_) => stillWaiting(async);
      s.checkStatus(force: true);
      async.flushMicrotasks();
      s.attach();
      async.flushMicrotasks();
      s.send('q');
      async.flushMicrotasks();
      expect(s.pending, isTrue);
      return s;
    }

    test('every 2 s for a minute, every 4 s to 3 minutes, then 30 s', () {
      fakeAsync((async) {
        final s = askedOnScreen(async);
        expect(fetchesUntil(async, 240), [
          for (var t = 2; t <= 60; t += 2) t,
          for (var t = 64; t <= 180; t += 4) t,
          210,
          240,
        ]);
        s.detach();
        s.dispose();
      });
    });

    test('closing the chat goes back to the schedule after a question', () {
      fakeAsync((async) {
        final s = askedOnScreen(async);
        expect(fetchesUntil(async, 10), [2, 4, 6, 8, 10]);
        s.detach();
        expect(fetchesUntil(async, 40), [12, 17, 27, 37]);
        s.dispose();
      });
    });

    test('fast fetching stops once the answer is in', () {
      fakeAsync((async) {
        final s = askedOnScreen(async);
        final seen = fetchesUntil(async, 7);
        backend.onFetch = (_) => settled(async, 'handled');
        seen.addAll(fetchesUntil(async, 70));
        expect(seen, [2, 4, 6, 8, 38, 68]);
        expect(s.pending, isFalse);
        expect(s.messages.last.text, 'Answer');
        expect(s.nextPollDelay(), SupportState.openPollEvery);
        s.detach();
        expect(s.nextPollDelay(), isNull);
        s.dispose();
      });
    });

    test('fast fetching stops once the question has failed', () {
      fakeAsync((async) {
        final s = askedOnScreen(async);
        final seen = fetchesUntil(async, 7);
        backend.onFetch = (_) => settled(async, 'failed', code: 'busy');
        seen.addAll(fetchesUntil(async, 70));
        expect(seen, [2, 4, 6, 8, 38, 68]);
        expect(s.pending, isFalse);
        expect(s.messages.single.status, 'failed');
        s.detach();
        s.dispose();
      });
    });

    test(
      'a failed fetch falls back to the slower schedule until one works',
      () {
        fakeAsync((async) {
          final s = askedOnScreen(async);
          final seen = fetchesUntil(async, 5);
          backend.onFetch = (_) => throw const SocketException('down');
          seen.addAll(fetchesUntil(async, 30));
          backend.onFetch = (_) =>
              throw ApiException(statusCode: 503, message: 'db');
          seen.addAll(fetchesUntil(async, 50));
          backend.onFetch = (_) => stillWaiting(async);
          seen.addAll(fetchesUntil(async, 75));
          expect(seen, [
            2, 4, // fast while the route works
            6, 7, 12, 17, 27, 37, 47, // failing: 7, 12, 17, then every 10 s
            57, // got through
            59, 61, 65, 69, 73, // fast again: 2 s, then 4 s after a minute
          ]);
          expect(s.pending, isTrue);
          s.detach();
          s.dispose();
        });
      },
    );

    test(
      'a question this run did not send counts from when it was asked',
      () async {
        final asked = _t0.subtract(const Duration(seconds: 10));
        backend.onFetch = (_) => SupportPage.fromJson({
          'server_time': now.toIso8601String(),
          'mode': 'ai',
          'pending': true,
          'messages': [wire(100, role: 'user', status: 'queued', at: asked)],
        });
        final s = make();
        await s.checkStatus(force: true);
        s.attach();
        await settle();
        expect(s.pending, isTrue);
        expect(s.nextPollDelay(), SupportState.onScreenPollEvery);
        now = _t0.add(const Duration(seconds: 60));
        expect(s.nextPollDelay(), SupportState.onScreenPollSlowerEvery);
        now = _t0.add(const Duration(seconds: 175));
        expect(s.nextPollDelay(), SupportState.openPollEvery);
        // With the chat closed, as before: nothing on a timer.
        s.detach();
        expect(s.nextPollDelay(), isNull);
        s.dispose();
      },
    );
  });

  group('limits', () {
    test('the day limit holds until the reset, then lifts', () async {
      final resets = _t0.add(const Duration(hours: 2));
      backend.onStatus = () => SupportStatus.fromJson({
        'enabled': true,
        'mode': 'ai',
        'quota': quotaJson(remaining: 0, resetsAt: resets),
      });
      final s = make();
      await s.checkStatus(force: true);
      expect(s.limit?.code, 'quota_day');
      now = now.add(const Duration(hours: 3));
      expect(s.limit, isNull);
      s.dispose();
    });

    test('a pause is a limit; a count per conversation is not', () async {
      backend.onStatus = () => SupportStatus.fromJson({
        'enabled': true,
        'mode': 'paused',
        'quota': quotaJson(pausedUntil: _t0.add(const Duration(minutes: 30))),
      });
      final s = make();
      await s.checkStatus(force: true);
      expect(s.limit?.code, 'paused');
      backend.onStatus = () => SupportStatus.fromJson({
        'enabled': true,
        'mode': 'ai',
        'quota': quotaJson(conversationLeft: 0),
      });
      await s.checkStatus(force: true);
      // An older backend still sends one. Only the day's count limits.
      expect(s.limit, isNull);
      expect(s.quota?.toJson().keys, isNot(contains('conversation_left')));
      s.dispose();
    });

    test(
      "an older backend's conversation limit holds like the day's",
      () async {
        final s = make();
        await s.checkStatus(force: true);
        backend.onSend = (_) => throw refusal(
          429,
          'quota_conversation',
          quota: quotaJson(remaining: 3, conversationLeft: 0),
          retryIn: const Duration(minutes: 30),
        );
        final result = await s.send('one more');
        expect(result.outcome, SupportSendOutcome.refused);
        expect(result.code, 'quota_day');
        expect(s.notice?.code, 'quota_day');
        expect(s.limit?.code, 'quota_day');
        expect(s.limit?.until, _t0.add(const Duration(minutes: 30)));
        expect(s.writesToTeam, isFalse);
        now = now.add(const Duration(minutes: 31));
        expect(s.limit, isNull);
        s.dispose();
      },
    );

    test('a short wait for the assistant holds until it runs out', () async {
      final s = make();
      await s.checkStatus(force: true);
      backend.onSend = (_) => throw refusal(429, 'slow_down');
      expect((await s.send('q')).code, 'slow_down');
      expect(s.limit?.code, 'slow_down');
      expect(s.teamLimit, isNull);
      // Another message does not lift it.
      backend.onSend = (body) => throw refusal(422, 'gibberish');
      await s.send('asdf');
      expect(s.limit?.code, 'slow_down');
      now = now.add(const Duration(minutes: 6));
      expect(s.limit, isNull);
      s.dispose();
    });

    test(
      'with the day used up, only a conversation our team has goes on',
      () async {
        final open = {'id': 1, 'ticket': 'open'};
        backend.onFetch = (_) => SupportPage.fromJson({
          'mode': 'ai',
          'quota': quotaJson(remaining: 0),
          'thread': open,
          'messages': [],
        });
        backend.onStatus = () => SupportStatus.fromJson({
          'enabled': true,
          'mode': 'ai',
          'quota': quotaJson(remaining: 0),
          'thread': {'id': 1, 'ticket': 'none'},
        });
        final s = make();
        await s.checkStatus(force: true);
        // No ticket: the day's limit holds, and nothing goes to our team.
        expect(s.limit?.code, 'quota_day');
        expect(s.writesToTeam, isFalse);

        backend.onStatus = () => SupportStatus.fromJson({
          'enabled': true,
          'mode': 'ai',
          'quota': quotaJson(remaining: 0),
          'thread': open,
        });
        await s.checkStatus(force: true);
        expect(s.writesToTeam, isTrue);
        var capped = false;
        backend.onSend = (body) => capped
            ? throw refusal(429, 'slow_down', retryIn: const Duration(hours: 8))
            : SupportReply.fromJson({
                'message': wire(
                  100,
                  role: 'user',
                  status: 'to_staff',
                  clientId: body['client_id'] as String,
                  text: body['text'] as String,
                ),
                'quota': quotaJson(remaining: 0),
                'thread': open,
                'mode': 'ai',
              });
        expect(
          (await s.send('thanks, it works')).outcome,
          SupportSendOutcome.sent,
        );
        expect(backend.sent.single['to'], 'staff');
        expect(s.pending, isFalse);

        // The cap on messages to our team holds them, not the assistant.
        capped = true;
        expect((await s.send('one more')).code, 'slow_down');
        expect(s.teamLimit?.code, 'slow_down');
        expect(s.limit?.code, 'quota_day');
        s.dispose();
      },
    );

    test('a new conversation gives no questions back', () async {
      backend.onStatus = () => SupportStatus.fromJson({
        'enabled': true,
        'mode': 'ai',
        'quota': quotaJson(remaining: 0),
      });
      backend.onFetch = (_) => SupportPage.fromJson({
        'mode': 'ai',
        'quota': quotaJson(remaining: 0),
        'messages': [wire(1)],
      });
      backend.onNew = () => SupportReply.fromJson({
        'quota': quotaJson(remaining: 0),
        'thread': {'id': 2, 'ticket': 'none'},
      });
      final s = make();
      await s.checkStatus(force: true);
      await s.poll();
      expect(s.fetches, 1);
      expect(await s.startNewConversation(), isTrue);
      expect(s.limit?.code, 'quota_day');
      expect(s.thread?.id, 2);
      expect(s.messages.last.role, SupportMessage.divider);
      s.dispose();
    });
  });

  group('ratings', () {
    test('a rating shows at once and is put back when not sent', () async {
      backend.onFetch = (_) => SupportPage.fromJson({
        'mode': 'ai',
        'messages': [wire(5), wire(6, role: 'user')],
      });
      final s = make();
      await s.checkStatus(force: true);
      await s.poll();
      expect(await s.rate(5, up: false), isTrue);
      expect(s.messages.first.rating, 'down');
      expect(backend.rated, ['5:down']);

      backend.onRate = (_, _) => throw const SocketException('down');
      expect(await s.rate(5, up: true), isFalse);
      expect(s.messages.first.rating, 'down');

      // Only answers can be rated.
      expect(await s.rate(6, up: true), isFalse);
      s.dispose();
    });
  });

  group('deletion', () {
    test('reset forgets the chat and drops answers in flight', () async {
      final s = make();
      await s.checkStatus(force: true);
      backend.onSend = (_) => throw const SocketException('down');
      await s.send('waiting');
      await s.poll();
      final gate = Completer<SupportPage>();
      backend.onFetch = (_) => gate.future;
      final inFlight = s.poll();
      await Future<void>.delayed(Duration.zero);

      await s.reset();
      gate.complete(
        SupportPage.fromJson({
          'mode': 'ai',
          'messages': [wire(9)],
        }),
      );
      await inFlight;

      expect(s.enabled, isFalse);
      expect(s.messages, isEmpty);
      expect(s.outbox, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      for (final key in const [
        SupportState.statusKey,
        SupportState.messagesKey,
        SupportState.outboxKey,
        SupportState.seenKey,
      ]) {
        expect(prefs.containsKey(key), isFalse, reason: key);
      }
      s.dispose();
    });
  });

  group('phone facts', () {
    test('only the listed facts leave the phone', () {
      final facts = SupportState.factsFrom(
        {
          'network': 'wifi',
          'carrier': 'Irancell',
          'sim_carrier': 'MTN',
          'sdk_int': 34,
          'vpn_permission': true,
          'battery_optimized': true,
          'background_restricted': false,
          'private_dns': 'dns.example',
          'core_log': 'thousands of lines',
          'resolver': '1.1.1.1',
          'device': 'Samsung SM-A515F',
        },
        {'other_vpn': false, 'sim_country': 'ir'},
      );
      expect(facts, {
        'network': 'wifi',
        'carrier': 'Irancell',
        'android': '14',
        'phone': {
          'vpn_permission': true,
          'other_vpn': false,
          'battery_optimized': true,
          'background_restricted': false,
          'private_dns_on': true,
        },
      });
      expect(jsonEncode(facts), isNot(contains('dns.example')));
    });

    test('networks map onto wifi, mobile, other or nothing', () {
      String? network(String? n) =>
          SupportState.factsFrom({'network': n}, null)['network'] as String?;
      expect(network('wifi'), 'wifi');
      expect(network('mobile'), 'mobile');
      expect(network('ethernet'), 'other');
      expect(network('none'), isNull);
      expect(network(null), isNull);
    });

    test('the Android version is always one the backend keeps', () {
      // The backend keeps one or two digits with an optional .N part.
      final kept = RegExp(r'^\d{1,2}(\.\d{1,2})?$');
      for (var sdk = 0; sdk <= 60; sdk++) {
        final release = SupportState.androidRelease(sdk);
        if (release == null) continue;
        expect(kept.hasMatch(release), isTrue, reason: '$sdk: $release');
      }
      expect(SupportState.androidRelease(32), '12');
      expect(SupportState.androidRelease(36), '16');
      // Android 17 phones are out: an end to end run on one sent no version.
      expect(SupportState.androidRelease(37), '17');
      expect(SupportState.factsFrom({'sdk_int': 37}, null)['android'], '17');
      expect(SupportState.androidRelease(38), isNull);
      final facts = SupportState.factsFrom({'sdk_int': 38}, null);
      expect(facts.containsKey('android'), isFalse);
    });

    test('a failure leaves the phone as a kind of problem', () {
      const kinds = {
        'phone_offline',
        'phone_permission',
        'network_trouble',
        'service_trouble',
        'allowance_used',
        'unclear',
      };
      for (final verdict in [...FailureVerdict.values, null]) {
        expect(
          kinds,
          contains(SupportState.problemCategory(verdict)),
          reason: '$verdict',
        );
      }
      expect(
        SupportState.problemCategory(FailureVerdict.noInternet),
        'phone_offline',
      );
      expect(
        SupportState.problemCategory(FailureVerdict.needsPermission),
        'phone_permission',
      );
      expect(
        SupportState.problemCategory(FailureVerdict.blockedTls),
        'network_trouble',
      );
      expect(SupportState.problemCategory(null), 'unclear');
    });

    test('client ids are version 4 UUIDs', () {
      final id = SupportState.uuid4();
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(id),
        isTrue,
        reason: id,
      );
      expect(SupportState.uuid4(), isNot(id));
    });
  });
}
