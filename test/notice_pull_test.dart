import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/notices_file.dart';
import 'package:fortiva_vpn/core/state/message_state.dart';
import 'package:fortiva_vpn/data/models/in_app_message.dart';
import 'package:fortiva_vpn/services/notice_pull.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The background check for messages (lib/services/notice_pull.dart): where
/// it gets them, which one gets a notification, and its receipts.

final now = DateTime.utc(2026, 10, 12, 12);

Map<String, Object?> message(
  int id, {
  String language = 'fa',
  DateTime? sentAt,
  DateTime? endsAt,
}) => {
  'id': id,
  'language': language,
  'title': 'عنوان $id',
  'body': 'متن $id',
  'button': null,
  'link': null,
  'sent_at': (sentAt ?? now.subtract(Duration(hours: 10 - id)))
      .toIso8601String(),
  'ends_at': (endsAt ?? now.add(const Duration(days: 3))).toIso8601String(),
};

MessagesPage page(List<Map<String, Object?>> messages) => MessagesPage.fromJson(
  {'server_time': now.toIso8601String(), 'messages': messages},
);

NoticesFile file(List<Notice> notices) => NoticesFile(
  issuedAt: now.subtract(const Duration(minutes: 5)),
  notices: notices,
  text: 'sealed',
);

Notice notice(int id, {List<String> countries = const []}) => Notice(
  id: id,
  sentAt: now.subtract(const Duration(hours: 1)),
  endsAt: now.add(const Duration(days: 2)),
  countries: countries,
  texts: {
    'fa': {'title': 'از فایل', 'body': 'متن فایل', 'fallback': false},
    'en': {'title': 'From the file', 'body': 'File body', 'fallback': false},
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<InAppMessage> shown;
  late List<Map<String, dynamic>> posted;
  late int fileReads;
  late bool allowNotifications;

  setUp(() {
    SharedPreferences.setMockInitialValues({'pref_locale': 'fa'});
    shown = [];
    posted = [];
    fileReads = 0;
    allowNotifications = true;
  });

  NoticePull pull({
    String? deviceId = 'DEV-1',
    Future<MessagesPage> Function()? backend,
    NoticesFile? notices,
    String? country = 'IR',
    Future<void> Function(Map<String, dynamic> body)? post,
  }) => NoticePull(
    deviceId: () async => deviceId,
    fetch: (id, lang) async {
      expect(id, deviceId);
      expect(lang, 'fa');
      if (backend == null) throw const SocketException('cut');
      return backend();
    },
    post: (id, body) async {
      if (post != null) return post(body);
      posted.add(body);
    },
    readFile: () async {
      fileReads++;
      return notices;
    },
    country: () async => country,
    version: () => '1.9.0',
    show: (m, language) async {
      if (!allowNotifications) return false;
      shown.add(m);
      return true;
    },
    clock: () => now,
  );

  Future<List<Map<String, dynamic>>> queued() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(NoticePull.receiptsKey);
    return raw == null
        ? []
        : (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  test('nothing at all before the user has chosen the app language', () async {
    SharedPreferences.setMockInitialValues({});
    final result = await pull(backend: () async => page([message(1)])).run();
    expect(result.source, NoticeSource.none);
    expect(shown, isEmpty);
  });

  test('the backend answers: the newest unseen message gets a notification, '
      'and the receipts go out at once', () async {
    final result = await pull(
      backend: () async => page([message(2), message(1)]),
    ).run();

    expect(result.source, NoticeSource.backend);
    expect(result.notified, 2);
    expect([for (final m in shown) m.id], [2]);
    expect(
      fileReads,
      0,
      reason:
          'the file is read only when the backend '
          'cannot be reached',
    );
    final sent = [
      for (final body in posted)
        for (final r in body['receipts'] as List)
          '${(r as Map)['message_id']}:${r['kind']}',
    ];
    expect(sent, ['2:received', '1:received', '2:shown']);
    expect(await queued(), isEmpty);
  });

  test('the same message never gets a second notification', () async {
    final p = pull(backend: () async => page([message(2)]));
    await p.run();
    final second = await p.run();
    expect(second.notified, isNull);
    expect(shown, hasLength(1));
  });

  test(
    'a message older than the last one notified waits in the inbox',
    () async {
      await pull(backend: () async => page([message(5)])).run();
      final later = await pull(
        backend: () async => page([message(5), message(3)]),
      ).run();
      expect(later.notified, isNull);
      expect([for (final m in shown) m.id], [5]);
    },
  );

  test('a message that popped up or was read in the app gets none', () async {
    String stamp(int id) =>
        jsonEncode({'$id': now.add(const Duration(days: 3)).toIso8601String()});
    SharedPreferences.setMockInitialValues({
      'pref_locale': 'fa',
      MessageState.poppedKey: stamp(4),
      MessageState.readKey: stamp(3),
    });
    final result = await pull(
      backend: () async => page([message(4), message(3)]),
    ).run();
    expect(result.notified, isNull);
    expect(shown, isEmpty);
  });

  test('nothing older than the last in-app popup gets one', () async {
    SharedPreferences.setMockInitialValues({
      'pref_locale': 'fa',
      MessageState.lastPoppedKey: now.toIso8601String(),
    });
    final result = await pull(backend: () async => page([message(4)])).run();
    expect(result.notified, isNull);
  });

  test('a message shown in English to a Persian app gets none, like the '
      'popup', () async {
    final result = await pull(
      backend: () async => page([message(4, language: 'en')]),
    ).run();
    expect(result.notified, isNull);
  });

  test('an ended message gets none', () async {
    final result = await pull(
      backend: () async =>
          page([message(4, endsAt: now.subtract(const Duration(minutes: 1)))]),
    ).run();
    expect(result.notified, isNull);
  });

  test('with notifications not allowed, nothing is recorded as shown and the '
      'next check tries again', () async {
    allowNotifications = false;
    final p = pull(backend: () async => page([message(2)]));
    expect((await p.run()).notified, isNull);
    allowNotifications = true;
    expect((await p.run()).notified, 2);
  });

  test('the backend cut off: the public file is read, the notice for this '
      'phone gets a notification, and its receipts wait', () async {
    final result = await pull(
      notices: file([
        notice(9),
        notice(8, countries: ['DE']),
      ]),
    ).run();

    expect(result.source, NoticeSource.file);
    expect(result.notified, 9);
    expect(shown.single.title, 'از فایل');
    expect(posted, isEmpty);
    expect(
      [for (final r in await queued()) '${r['message_id']}:${r['kind']}'],
      ['9:received', '9:shown'],
    );

    // The next check that reaches the backend sends them.
    await pull(backend: () async => page([])).run();
    expect(posted, hasLength(1));
    expect(await queued(), isEmpty);
  });

  test('after a backend failure, the next check reads the file at once and '
      'gives the backend less time', () async {
    await pull(notices: file([notice(9)])).run();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(NoticePull.backendFailedKey), isNotNull);

    var fileReadBeforeBackend = false;
    final second = NoticePull(
      deviceId: () async => 'DEV-1',
      fetch: (id, lang) async {
        fileReadBeforeBackend = fileReads > 1;
        throw const SocketException('still cut');
      },
      post: (id, body) async => posted.add(body),
      readFile: () async {
        fileReads++;
        return file([notice(9)]);
      },
      country: () async => 'IR',
      version: () => '1.9.0',
      show: (m, language) async => true,
      clock: () => now,
    );
    await second.run();
    expect(fileReadBeforeBackend, isTrue);

    // A later success clears it.
    await pull(backend: () async => page([])).run();
    expect(prefs.getString(NoticePull.backendFailedKey), isNull);
  });

  test('no device id yet: the backend is not asked and nothing registers; '
      'the file still works', () async {
    var asked = false;
    final result = await pull(
      deviceId: null,
      backend: () async {
        asked = true;
        return page([]);
      },
      notices: file([notice(9)]),
    ).run();
    expect(asked, isFalse);
    expect(result.notified, 9);
  });

  test(
    'nothing reachable: nothing changes, and the next check tries again',
    () async {
      final result = await pull().run();
      expect(result.source, NoticeSource.none);
      expect(fileReads, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(NoticePull.notifiedKey), isNull);
    },
  );

  test('what a check found is kept for the app, with the time it was '
      'current', () async {
    await pull(backend: () async => page([message(2)])).run();
    final prefs = await SharedPreferences.getInstance();
    final found = jsonDecode(prefs.getString(NoticePull.foundKey)!) as Map;
    expect(found['at'], now.toIso8601String());
    expect([for (final m in found['messages'] as List) (m as Map)['id']], [2]);
  });

  test('with diagnostics sharing off no receipt is queued', () async {
    SharedPreferences.setMockInitialValues({
      'pref_locale': 'fa',
      VpnEventReporter.sharePrefKey: false,
    });
    await pull(notices: file([notice(9)])).run();
    expect(await queued(), isEmpty);
    expect(
      shown,
      hasLength(1),
      reason:
          'the notification does not depend '
          'on sharing',
    );
  });

  test('a batch the backend can never take is dropped; any other failure '
      'keeps it', () async {
    await pull(notices: file([notice(9)])).run();
    await pull(
      backend: () async => page([]),
      post: (_) async => throw ApiException(statusCode: 503, message: 'busy'),
    ).run();
    expect(await queued(), hasLength(2));
    await pull(
      backend: () async => page([]),
      post: (_) async => throw ApiException(statusCode: 422, message: 'bad'),
    ).run();
    expect(await queued(), isEmpty);
  });
}
