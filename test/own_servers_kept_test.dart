import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// This device's own servers, kept on the phone for a launch that cannot
/// reach the backend.
///
/// Until 2026-10-11 they lived in memory only, so a launch on a network
/// that cut our calls had none, although the servers themselves worked.
const uri =
    'vless://u@198.51.100.204:8443?type=xhttp&security=reality'
    '&sni=www.samsung.com&pbk=key#Row13';

Map<String, dynamic> answer({
  bool blocked = false,
  String? resetsAt,
  List<String> configs = const [uri],
}) => {
  'configs': configs,
  'paths': [
    for (final c in configs)
      {
        'server_id': 13,
        'inbound_id': 2,
        'door': 'xhttp-reality',
        'label': 'xhttp-reality',
        'uri': c,
        'preferred': true,
      },
  ],
  'quota': {
    'unlimited': false,
    'limit_bytes': 100,
    'used_bytes': blocked ? 100 : 10,
    'remaining_bytes': blocked ? 0 : 90,
    'blocked': blocked,
    'resets_at': ?resetsAt,
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 10, 11, 12);

  String kept(Map<String, dynamic> body, {DateTime? at}) =>
      jsonEncode({'at': (at ?? now).toIso8601String(), 'body': body});

  DedicatedState state(
    Future<DedicatedConfigs> Function({bool? viaTunnel}) fetch,
  ) => DedicatedState(now: () => now, fetch: fetch);

  Future<DedicatedConfigs> cut({bool? viaTunnel}) async =>
      throw ApiException(statusCode: 0, message: 'No internet connection');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('an answer is kept, and a launch that cannot reach the backend still '
      'has the servers in it', () async {
    final first = state(
      ({bool? viaTunnel}) async => DedicatedConfigs.fromJson(answer()),
    );
    await first.refresh();
    await pumpEventQueue();
    expect(first.hasServers, isTrue);
    expect(first.lastRefreshFailed, isFalse);

    final next = state(cut);
    await next.refresh();

    expect(next.hasServers, isTrue);
    expect(next.paths.single.connectionUri, uri);
    expect(next.fromSaved, isTrue);
    expect(next.lastRefreshFailed, isTrue);
  });

  test('a restored selection keeps whether the user picked it', () async {
    final first = state(
      ({bool? viaTunnel}) async => DedicatedConfigs.fromJson(answer()),
    );
    await first.refresh();
    first.select(first.servers.single);
    await first.selectionWritten;
    await pumpEventQueue();

    // A launch that cannot reach the backend still knows it was a pick.
    final picked = state(cut);
    await picked.refresh();
    expect(picked.fromSaved, isTrue);
    expect(picked.selectedServer?.id, first.servers.single.id);
    expect(picked.selectedByUser, isTrue);

    // And that a move the connect flow made was not.
    picked.select(picked.paths.single, byUser: false);
    await picked.selectionWritten;
    final moved = state(cut);
    await moved.refresh();
    expect(moved.selectedServer?.id, first.servers.single.id);
    expect(moved.selectedByUser, isFalse);
  });

  test('a fresh answer replaces the kept one', () async {
    SharedPreferences.setMockInitialValues({
      DedicatedState.prefSaved: kept(answer()),
    });
    const other = 'vless://u@203.0.113.40:443?type=tcp&security=reality#New';
    final s = state(
      ({bool? viaTunnel}) async =>
          DedicatedConfigs.fromJson(answer(configs: [other])),
    );

    await s.refresh();

    expect(s.paths.single.connectionUri, other);
    expect(s.fromSaved, isFalse);
  });

  test('an answer older than a month is not used', () async {
    SharedPreferences.setMockInitialValues({
      DedicatedState.prefSaved: kept(
        answer(),
        at: now.subtract(const Duration(days: 31)),
      ),
    });
    final s = state(cut);

    await s.refresh();

    expect(s.hasServers, isFalse);
  });

  test('a spent allowance whose refill time has passed is not taken up, so '
      'it cannot hold the shared links back', () async {
    SharedPreferences.setMockInitialValues({
      DedicatedState.prefSaved: kept(
        answer(
          blocked: true,
          configs: const [],
          resetsAt: now.subtract(const Duration(hours: 1)).toIso8601String(),
        ),
      ),
    });
    final s = state(cut);

    await s.refresh();

    expect(s.isBlocked, isFalse);
  });

  test('a spent allowance that has not refilled yet still counts', () async {
    SharedPreferences.setMockInitialValues({
      DedicatedState.prefSaved: kept(
        answer(
          blocked: true,
          configs: const [],
          resetsAt: now.add(const Duration(hours: 1)).toIso8601String(),
        ),
      ),
    });
    final s = state(cut);

    await s.refresh();

    expect(s.isBlocked, isTrue);
  });

  test('an answer from the backend is not a failed refresh, whatever its '
      'status', () async {
    final s = state(
      ({bool? viaTunnel}) async =>
          throw ApiException(statusCode: 500, message: 'Server error'),
    );

    await s.refresh();

    expect(s.lastRefreshFailed, isFalse);
  });

  test('a spent allowance stops counting at its refill time, even when the '
      'backend cannot be asked', () async {
    var clock = now;
    SharedPreferences.setMockInitialValues({
      DedicatedState.prefSaved: kept(
        answer(
          blocked: true,
          configs: const [],
          resetsAt: now.add(const Duration(minutes: 30)).toIso8601String(),
        ),
      ),
    });
    final s = DedicatedState(now: () => clock, fetch: cut);
    await s.refresh();
    expect(s.isBlocked, isTrue);

    clock = now.add(const Duration(minutes: 31));
    expect(s.isBlocked, isFalse);
  });

  test('an answer that arrives after the account was deleted is neither '
      'used nor kept', () async {
    final answered = Completer<DedicatedConfigs>();
    final s = state(({bool? viaTunnel}) => answered.future);
    final refreshing = s.refresh();
    await pumpEventQueue();

    s.reset();
    answered.complete(DedicatedConfigs.fromJson(answer()));
    await refreshing;
    await pumpEventQueue();

    expect(s.hasServers, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(DedicatedState.prefSaved), isNull);
  });

  test('a fresh answer that says the allowance is spent holds, whatever the '
      'phone clock says', () async {
    // The phone's clock is a day ahead of the reset time.
    final ahead = now.add(const Duration(days: 1));
    final s = DedicatedState(
      now: () => ahead,
      fetch: ({bool? viaTunnel}) async => DedicatedConfigs.fromJson(
        answer(
          blocked: true,
          configs: const [],
          resetsAt: now.add(const Duration(hours: 2)).toIso8601String(),
        ),
      ),
    );

    await s.refresh();

    expect(s.isBlocked, isTrue);
    expect(s.quota!.blocked, isTrue);
  });

  test('a kept answer that has refilled reads as refilled everywhere: '
      'nothing used, nothing blocked', () async {
    var clock = now;
    SharedPreferences.setMockInitialValues({
      DedicatedState.prefSaved: kept(
        answer(
          blocked: true,
          configs: const [],
          resetsAt: now.add(const Duration(minutes: 30)).toIso8601String(),
        ),
      ),
    });
    final s = DedicatedState(now: () => clock, fetch: cut);
    await s.refresh();
    expect(s.quota!.blocked, isTrue);

    clock = now.add(const Duration(minutes: 31));
    expect(s.quota!.blocked, isFalse);
    expect(s.quota!.usedBytes, 0);
  });

  test(
    'an answer still on its way when a deletion starts is dropped',
    () async {
      final answered = Completer<DedicatedConfigs>();
      final s = state(({bool? viaTunnel}) => answered.future);
      final refreshing = s.refresh();
      await pumpEventQueue();

      s.forgetAccount();
      answered.complete(DedicatedConfigs.fromJson(answer()));
      await refreshing;
      await pumpEventQueue();

      expect(s.hasServers, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(DedicatedState.prefSaved), isNull);
    },
  );

  test('a refresh that gets an error answer after the reset time does not '
      'keep a spent allowance in force', () async {
    var clock = now;
    var fail = false;
    final s = DedicatedState(
      now: () => clock,
      fetch: ({bool? viaTunnel}) async {
        if (fail) throw ApiException(statusCode: 502, message: 'Bad gateway');
        return DedicatedConfigs.fromJson(
          answer(
            blocked: true,
            configs: const [],
            resetsAt: now.add(const Duration(hours: 2)).toIso8601String(),
          ),
        );
      },
    );
    await s.refresh();
    expect(s.isBlocked, isTrue);

    clock = now.add(const Duration(hours: 2, minutes: 1));
    fail = true;
    await s.refresh();

    expect(s.isBlocked, isFalse);
  });

  test('no answer is kept on the phone while an account deletion runs, and '
      'answers count again if it did not happen', () async {
    final s = state(
      ({bool? viaTunnel}) async => DedicatedConfigs.fromJson(answer()),
    );
    s.forgetAccount();
    await s.refresh();
    await pumpEventQueue();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(DedicatedState.prefSaved), isNull);
    expect(s.hasServers, isFalse);

    s.keepAccount();
    await pumpEventQueue();
    expect(s.hasServers, isTrue);
  });

  test('no request goes out while an account deletion runs', () async {
    var asked = 0;
    final s = state(({bool? viaTunnel}) async {
      asked++;
      return DedicatedConfigs.fromJson(answer());
    });
    s.forgetAccount();

    await s.refresh();

    expect(asked, 0);
    // A deletion that did not happen asks again by itself.
    s.keepAccount();
    await pumpEventQueue();
    expect(asked, 1);
  });
}
