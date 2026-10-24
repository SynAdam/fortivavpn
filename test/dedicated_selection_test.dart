import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the server this device is set to use is one the user picked, or
/// one the connect flow moved the selection to because a tap landed there.
///
/// Up to 1.7.0 both were saved the same way, and every later tap checked
/// all of the saved server's doors before any other server's, even when
/// that server's IPv4 addresses rarely passed on the phone's carrier and
/// another server's mostly did. Some of those taps failed.
const row1 =
    'vless://u@203.0.113.1:443?type=xhttp&security=reality'
    '&sni=www.samsung.com&pbk=key#Fortiva%20DE%20Nuremberg';
const row2 =
    'vless://u@203.0.113.2:443?type=tcp&security=reality'
    '&sni=www.samsung.com&pbk=key#Fortiva%20FI%20Helsinki';
// The second server's door at its second address.
const row2b =
    'vless://u@198.51.100.2:443?type=tcp&security=reality'
    '&sni=www.samsung.com&pbk=key#Fortiva%20FI%20Helsinki';
// A server the backend no longer lists.
const gone =
    'vless://u@203.0.113.99:443?type=tcp&security=reality'
    '&sni=www.samsung.com&pbk=key#Fortiva%20NL%20Amsterdam';

const configs = [row1, row2];

DedicatedPath _path(String uri, String door, int serverId) => DedicatedPath(
  serverId: serverId,
  inboundId: 1,
  door: door,
  label: door,
  uri: uri,
);

final paths = [
  _path(row1, 'xhttp-reality', 1),
  _path(row2, 'tcp-reality', 2),
  _path(row2b, 'tcp-reality-b', 2),
];

/// A launch: a new state that adopts the backend's answer.
Future<DedicatedState> launch() async {
  final state = DedicatedState();
  await state.adoptForTest(configs, paths);
  return state;
}

/// The backend's answer, for a device with Premium when [unlimited]: the
/// backend reports an unlimited allowance only for such a device.
DedicatedConfigs answer({required bool unlimited}) => DedicatedConfigs(
  configs: configs,
  paths: paths,
  quota: QuotaStatus(
    unlimited: unlimited,
    limitBytes: unlimited ? 0 : 100,
    usedBytes: 10,
    remainingBytes: unlimited ? 0 : 90,
    blocked: false,
  ),
);

/// A launch whose refresh gets [answer] from the backend.
Future<DedicatedState> launchWith({required bool unlimited}) async {
  final state = DedicatedState(
    fetch: ({bool? viaTunnel}) async => answer(unlimited: unlimited),
  );
  await state.refresh();
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final row1Id = Server.fromDedicatedUri(row1).id;
  final row2Id = Server.fromDedicatedUri(row2).id;
  final goneId = Server.fromDedicatedUri(gone).id;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a server picked on the servers screen is a pick, after a relaunch '
      'too', () async {
    final state = await launch();
    final entry = state.servers.firstWhere((s) => s.id == row2Id);

    state.select(entry);
    expect(state.selectedByUser, isTrue);
    await state.selectionWritten;

    final next = await launch();
    expect(next.selectedServer?.id, row2Id);
    expect(next.selectedByUser, isTrue);
  });

  test(
    'a server the flow moved to is not a pick, after a relaunch too',
    () async {
      final state = await launch();
      final door = state.paths.firstWhere((p) => p.connectionUri == row2b);

      state.select(door, byUser: false);
      // The card names the server, not the door the tap landed on.
      expect(state.selectedServer?.serverId, 2);
      expect(state.selectedServer?.id, row2Id);
      expect(state.selectedByUser, isFalse);
      await state.selectionWritten;

      final next = await launch();
      expect(next.selectedServer?.serverId, 2);
      expect(next.selectedByUser, isFalse);
    },
  );

  test('a selection saved by 1.7.0, with no flag, is not a pick', () async {
    SharedPreferences.setMockInitialValues({
      'fortiva_dedicated_server_id': row2Id,
    });

    final state = await launch();

    expect(state.selectedServer?.id, row2Id);
    expect(state.selectedByUser, isFalse);
  });

  test('a pick the backend no longer lists is not a pick any more', () async {
    SharedPreferences.setMockInitialValues({
      'fortiva_dedicated_server_id': goneId,
      'fortiva_dedicated_server_by_user': true,
    });

    final state = await launch();

    expect(state.selectedServer?.id, state.servers.first.id);
    expect(state.selectedServer?.id, row1Id);
    expect(state.selectedByUser, isFalse);
  });

  test('a refresh keeps a pick made in this run, and its flag', () async {
    final state = await launch();
    state.select(state.servers.firstWhere((s) => s.id == row2Id));

    await state.adoptForTest(configs, paths);

    expect(state.selectedServer?.id, row2Id);
    expect(state.selectedByUser, isTrue);
  });

  test('reset leaves no pick', () async {
    final state = await launch();
    state.select(state.servers.firstWhere((s) => s.id == row2Id));
    expect(state.selectedByUser, isTrue);

    state.reset();

    expect(state.selectedServer, isNull);
    expect(state.selectedByUser, isFalse);
  });

  // A paying user is never moved off a Premium server they chose. The
  // phone cannot tell which of its servers are Premium ones, so a device
  // with Premium keeps every selection 1.7.0 saved as a pick.
  group('on a device with Premium', () {
    test('a selection saved by 1.7.0, with no flag, is a pick', () async {
      SharedPreferences.setMockInitialValues({
        'fortiva_dedicated_server_id': row2Id,
      });

      final state = await launchWith(unlimited: true);

      expect(state.selectedServer?.id, row2Id);
      expect(state.selectedByUser, isTrue);
    });

    test('the same selection on a device without Premium is not', () async {
      SharedPreferences.setMockInitialValues({
        'fortiva_dedicated_server_id': row2Id,
      });

      final state = await launchWith(unlimited: false);

      expect(state.selectedServer?.id, row2Id);
      expect(state.selectedByUser, isFalse);
    });

    test('a selection saved as a move of the flow stays one', () async {
      SharedPreferences.setMockInitialValues({
        'fortiva_dedicated_server_id': row2Id,
        'fortiva_dedicated_server_by_user': false,
      });

      final state = await launchWith(unlimited: true);

      expect(state.selectedServer?.id, row2Id);
      expect(state.selectedByUser, isFalse);
    });
  });
}
