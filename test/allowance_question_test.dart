import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/dial_server.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The connect flow's question about the allowance (askAllowance), asked
/// through this device's config request.
///
/// Found 2026-10-23 in review: the refresh keeps its error for the screen
/// and never throws, so a request that got no answer read as "not spent",
/// and the flow took that no for the whole try instead of asking again at
/// its next check.
const _uri =
    'vless://u@198.51.100.204:8443?type=xhttp&security=reality'
    '&sni=www.samsung.com&pbk=key#Row13';

Map<String, dynamic> _answer({required bool blocked}) => {
  'configs': blocked ? const <String>[] : const [_uri],
  'paths': [
    if (!blocked)
      {
        'server_id': 13,
        'inbound_id': 2,
        'door': 'xhttp-reality',
        'label': 'xhttp-reality',
        'uri': _uri,
        'preferred': true,
      },
  ],
  'quota': {
    'unlimited': false,
    'limit_bytes': 100,
    'used_bytes': blocked ? 100 : 10,
    'remaining_bytes': blocked ? 0 : 90,
    'blocked': blocked,
  },
};

class _Vpn extends VpnService {
  _Vpn() : super(events: VpnEventReporter(send: (_, _, _) async {}));

  @override
  bool get isConnected => false;

  @override
  bool get isConnecting => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<bool> ask(Future<DedicatedConfigs> Function() fetch) => askAllowance(
    _Vpn(),
    DedicatedState(fetch: ({bool? viaTunnel}) => fetch()),
  );

  test('an answer says whether the allowance is spent', () async {
    expect(
      await ask(() async => DedicatedConfigs.fromJson(_answer(blocked: false))),
      isFalse,
    );
    expect(
      await ask(() async => DedicatedConfigs.fromJson(_answer(blocked: true))),
      isTrue,
    );
  });

  test('no answer is an error, so the flow asks again', () async {
    await expectLater(
      ask(
        () async => throw ApiException(
          statusCode: 0,
          message: 'No internet connection',
        ),
      ),
      throwsA(isA<AllowanceUnanswered>()),
    );
  });

  test('an answer with an error status is an error too', () async {
    await expectLater(
      ask(
        () async => throw ApiException(statusCode: 502, message: 'Bad gateway'),
      ),
      throwsA(isA<AllowanceUnanswered>()),
    );
  });

  test('an answer after a request that got none reads as an answer '
      'again', () async {
    var calls = 0;
    final dedicated = DedicatedState(
      fetch: ({bool? viaTunnel}) async {
        calls++;
        if (calls == 1) {
          throw ApiException(statusCode: 0, message: 'No internet connection');
        }
        return DedicatedConfigs.fromJson(_answer(blocked: false));
      },
    );
    final vpn = _Vpn();

    await expectLater(
      askAllowance(vpn, dedicated),
      throwsA(isA<AllowanceUnanswered>()),
    );
    expect(await askAllowance(vpn, dedicated), isFalse);
  });

  test('a spent allowance in memory still reads as spent when the request '
      'gets no answer', () async {
    var answered = false;
    final dedicated = DedicatedState(
      fetch: ({bool? viaTunnel}) async {
        if (answered) {
          throw ApiException(statusCode: 0, message: 'No internet connection');
        }
        answered = true;
        return DedicatedConfigs.fromJson(_answer(blocked: true));
      },
    );
    await dedicated.refresh();

    expect(await askAllowance(_Vpn(), dedicated), isTrue);
  });
}
