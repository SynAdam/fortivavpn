import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/api_routes.dart';
import 'package:fortiva_vpn/api/message_service.dart';
import 'package:fortiva_vpn/data/models/in_app_message.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A message as the backend sends it, with [extra] on top.
Map<String, dynamic> wire([Map<String, dynamic> extra = const {}]) => {
  'id': 12,
  'language': 'fa',
  'title': 'سلام',
  'body': 'نسخه‌ی تازه آمده است.',
  'button': 'کانال',
  'link': 'https://t.me/fortiva_vpn',
  'sent_at': '2026-10-06T07:12:00Z',
  'ends_at': '2026-10-13T07:12:00Z',
  ...extra,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InAppMessage', () {
    test('reads what the backend sends', () {
      final m = InAppMessage.tryParse(wire())!;
      expect(m.id, 12);
      expect(m.language, 'fa');
      expect(m.isRtl, isTrue);
      expect(m.title, 'سلام');
      expect(m.button, 'کانال');
      expect(m.link, Uri.parse('https://t.me/fortiva_vpn'));
      expect(m.sentAt, DateTime.utc(2026, 10, 6, 7, 12));
      expect(m.endsAt.isUtc, isTrue);
    });

    test('survives its own round trip through the saved list', () {
      final m = InAppMessage.tryParse(wire())!;
      final back = InAppMessage.tryParse(jsonDecode(jsonEncode(m.toJson())))!;
      expect(back.id, m.id);
      expect(back.title, m.title);
      expect(back.body, m.body);
      expect(back.link, m.link);
      expect(back.sentAt, m.sentAt);
      expect(back.endsAt, m.endsAt);
    });

    test('an empty title is a message with no title', () {
      expect(InAppMessage.tryParse(wire({'title': ''}))!.title, '');
      expect(InAppMessage.tryParse(wire({'title': null}))!.title, '');
    });

    test('a bad entry is null, never an exception', () {
      for (final bad in <Object?>[
        null,
        'text',
        42,
        [wire()],
        wire({'id': '12'}),
        wire({'id': null}),
        wire({'body': ''}),
        wire({'body': 7}),
        wire({'language': null}),
        wire({'sent_at': 'yesterday'}),
        wire({'ends_at': null}),
      ]) {
        expect(InAppMessage.tryParse(bad), isNull, reason: '$bad');
      }
    });

    test('a link that is not https drops the button, not the message', () {
      for (final link in [
        'http://t.me/fortiva_vpn',
        'tg://resolve?domain=fortiva_vpn',
        'intent://x#Intent;end',
        'javascript:alert(1)',
        'https://',
        'not a link',
        null,
      ]) {
        final m = InAppMessage.tryParse(wire({'link': link}));
        expect(m, isNotNull, reason: '$link');
        expect(m!.button, isNull, reason: '$link');
        expect(m.link, isNull, reason: '$link');
      }
    });

    test('a link without a label is no button either', () {
      final m = InAppMessage.tryParse(wire({'button': null}))!;
      expect(m.button, isNull);
      expect(m.link, isNull);
    });
  });

  group('MessagesPage', () {
    test('skips the entries it cannot read and keeps the rest', () {
      final page = MessagesPage.fromJson({
        'server_time': '2026-10-06T07:12:30Z',
        'messages': [
          wire(),
          {'id': 'broken'},
          null,
          wire({'id': 13, 'language': 'en', 'body': 'Hello'}),
        ],
      });
      expect(page.messages.map((m) => m.id), [12, 13]);
      expect(page.serverTime, DateTime.utc(2026, 10, 6, 7, 12, 30));
    });

    test('an answer that is not a messages list is an error', () {
      // A captive portal's page or an unexpected shape must not read as
      // "there are no messages" and wipe the saved list.
      for (final bad in <Object?>[
        null,
        '<html>',
        [],
        {'messages': null},
        {'messages': 'none'},
      ]) {
        expect(
          () => MessagesPage.fromJson(bad),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });

    test('an answer without server_time still lists the messages', () {
      final page = MessagesPage.fromJson({
        'messages': [wire()],
      });
      expect(page.messages, hasLength(1));
      expect(page.serverTime, isNull);
    });
  });

  group('MessageService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ApiRelays.resetForTest();
    });

    test('the language reaches the backend on every route', () async {
      // The direct route is cut, the tunnel route is cut, and the relay
      // answers: the query string must arrive on each of them.
      final asked = <String, Uri>{};
      http.Client route(String name, {bool answers = false}) =>
          MockClient((request) async {
            asked[name] = request.url;
            if (!answers) throw http.ClientException('cut');
            // Persian text, as the backend sends it: UTF-8 JSON with no
            // charset named.
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'server_time': '2026-10-06T07:12:30Z',
                  'messages': [wire()],
                }),
              ),
              200,
              headers: {'content-type': 'application/json'},
            );
          });
      final client = ApiClient.forTest(
        direct: route('direct'),
        tunnel: (_) => route('tunnel'),
        relay: (_) => route('relay', answers: true),
        tunnelPort: () async => 10808,
        relays: () async => const [
          ApiRelay(url: 'https://203.0.113.5:443', pin: 'aa'),
        ],
      );

      final page = await MessageService(client: client).fetch('DEV-1', 'fa');

      expect(page.messages.single.id, 12);
      expect(page.messages.single.title, 'سلام');
      for (final name in ['direct', 'tunnel', 'relay']) {
        expect(asked[name]!.path, '/api/v1/devices/DEV-1/messages');
        expect(asked[name]!.queryParameters, {'lang': 'fa'}, reason: name);
      }
      expect(asked['relay']!.host, '203.0.113.5');
    });

    test('a 404 reaches the caller as one, so it can register', () async {
      final client = ApiClient.forTest(
        direct: MockClient((_) async => http.Response('{"detail":"x"}', 404)),
      );
      await expectLater(
        MessageService(client: client).fetch('DEV-1', 'en'),
        throwsA(isA<ApiException>().having((e) => e.isNotFound, '404', true)),
      );
    });

    test('receipts go to the receipts path with the body as given', () async {
      late http.Request sent;
      final client = ApiClient.forTest(
        direct: MockClient((request) async {
          sent = request;
          return http.Response('{"accepted": 1}', 200);
        }),
      );
      final body = {
        'receipts': [
          {
            'message_id': 12,
            'kind': 'shown',
            'at': '2026-10-06T07:13:00.000Z',
            'language': 'fa',
          },
        ],
        'sent_at': '2026-10-06T07:13:05.000Z',
      };
      await MessageService(client: client).sendReceipts('DEV-1', body);
      expect(sent.method, 'POST');
      expect(sent.url.path, '/api/v1/devices/DEV-1/messages/receipts');
      expect(jsonDecode(sent.body), body);
    });
  });
}
