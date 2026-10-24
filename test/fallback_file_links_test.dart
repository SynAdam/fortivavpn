import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/bootstrap.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/api/server_clock.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/data/repositories/server_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The fallback file's links stand in for the public list while the
/// backend's cannot be had.
///
/// A new install on a network that cuts our calls had no public list and
/// nothing saved, so the Connect button had nothing behind it. The links in
/// the file are ones phones in Iran got through lately.
const _fileA = 'vless://u@198.51.100.1:443?type=tcp#\u{1F1E9}\u{1F1EA} FileA';
const _fileB = 'vless://u@198.51.100.2:443?type=tcp#\u{1F1EB}\u{1F1F7} FileB';
const _backend = 'vless://u@203.0.113.3:443?type=tcp#\u{1F1EF}\u{1F1F5} Ours';

class _Source implements ServerConfigSource {
  _Source({this.links, this.cut = false, this.official = const []});

  List<String>? links;
  bool cut;
  List<Server> official;

  @override
  Future<List<Server>> getOfficialConfigs() async {
    if (cut) throw ApiException(statusCode: 0, message: 'timeout');
    return official;
  }

  @override
  Future<List<String>> getCommunityConfigs() async {
    if (cut) throw ApiException(statusCode: 0, message: 'timeout');
    return links ?? const [];
  }
}

/// A fallback file that the test hands over when it likes.
class _File extends Bootstrap {
  BootstrapFile? given;

  @override
  BootstrapFile? get file => given;

  void give(BootstrapFile file) {
    given = file;
    notifyListeners();
  }
}

BootstrapFile _file(
  DateTime at, [
  List<String> links = const [_fileA, _fileB],
]) => BootstrapFile(issuedAt: at, text: '', links: links);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 10, 11, 12);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ServerState state(_Source source, _File file) => ServerState(
    repository: ServerRepository.withConfigSource(source),
    bootstrap: file,
    now: () => now,
  );

  List<String> links(ServerState s) => [
    for (final server in s.communityServers) server.connectionUri,
  ];

  test('a phone cut off from the backend, with nothing saved, gets the '
      'file\'s links and has one to dial', () async {
    final file = _File();
    final s = state(_Source(cut: true), file);
    await s.loadServers();
    await pumpEventQueue();
    expect(s.communityServers, isEmpty);

    file.give(_file(now));

    expect(links(s), [_fileA, _fileB]);
    expect(s.selectedServer?.connectionUri, _fileA);
  });

  test('a file read before the load is taken up by it', () async {
    final file = _File()..given = _file(now);
    final s = state(_Source(cut: true), file);

    await s.loadServers();
    await pumpEventQueue();

    expect(links(s), [_fileA, _fileB]);
  });

  test('a list the backend sent in this run is not replaced', () async {
    final file = _File();
    final s = state(_Source(links: [_backend]), file);
    await s.loadServers();
    await pumpEventQueue();

    file.give(_file(now));

    expect(links(s), [_backend]);
  });

  test(
    'a saved list newer than the file stays, an older one gives way',
    () async {
      String saved(DateTime at) => jsonEncode({
        'at': at.toIso8601String(),
        'links': [_backend],
      });

      SharedPreferences.setMockInitialValues({
        ServerRepository.savedCommunityKey: saved(now),
      });
      final file = _File();
      final s = state(_Source(cut: true), file);
      await s.loadServers();
      await pumpEventQueue();
      file.give(_file(now.subtract(const Duration(hours: 1))));
      expect(links(s), [_backend]);

      SharedPreferences.setMockInitialValues({
        ServerRepository.savedCommunityKey: saved(
          now.subtract(const Duration(days: 2)),
        ),
      });
      final file2 = _File();
      final s2 = state(_Source(cut: true), file2);
      await s2.loadServers();
      await pumpEventQueue();
      file2.give(_file(now.subtract(const Duration(hours: 1))));
      expect(links(s2), [_fileA, _fileB]);
    },
  );

  test('a fetch that fails after the file came does not put an older saved '
      'list back over it', () async {
    SharedPreferences.setMockInitialValues({
      ServerRepository.savedCommunityKey: jsonEncode({
        'at': now.subtract(const Duration(days: 2)).toIso8601String(),
        'links': [_backend],
      }),
    });
    final file = _File()..given = _file(now);
    final s = state(_Source(cut: true), file);

    await s.loadServers();
    await pumpEventQueue();
    await s.retryCommunityServers();

    expect(links(s), [_fileA, _fileB]);
  });

  test('the backend\'s list replaces the file\'s once it arrives', () async {
    final source = _Source(cut: true);
    final file = _File()..given = _file(now);
    final s = state(source, file);
    await s.loadServers();
    await pumpEventQueue();
    expect(links(s), [_fileA, _fileB]);

    source
      ..cut = false
      ..links = [_backend];
    await s.retryCommunityServers();

    expect(links(s), [_backend]);
  });

  // Found by the review before 1.8.0.
  test('a list the backend sent earlier in this run stays after a later '
      'fetch fails', () async {
    final source = _Source(links: [_backend]);
    final file = _File();
    final s = state(source, file);
    await s.loadServers();
    await pumpEventQueue();

    source.cut = true;
    file.give(_file(now.add(const Duration(hours: 1))));
    await s.retryCommunityServers();

    expect(links(s), [_backend]);
  });

  test('a link the file stood in with gives way to our official servers '
      'when they load', () async {
    final ours = Server.fromApiJson({
      'id': 7,
      'uri': 'vless://u@203.0.113.9:443?type=ws&security=tls#Ours',
      'country_code': 'DE',
      'type': 'free',
    });
    final file = _File()..given = _file(now);
    final s = state(_Source(official: [ours], links: [_backend]), file);

    await s.loadServers();
    await pumpEventQueue();

    expect(s.selectedServer?.connectionUri, ours.connectionUri);
  });

  test('a list the backend sent hours ago gives way to a newer file once '
      'the API is cut', () async {
    var clock = now;
    final source = _Source(links: [_backend]);
    final file = _File();
    final s = ServerState(
      repository: ServerRepository.withConfigSource(source, clock: () => clock),
      bootstrap: file,
      now: () => clock,
    );
    await s.loadServers();
    await pumpEventQueue();

    clock = now.add(const Duration(hours: 8));
    source.cut = true;
    file.give(_file(now.add(const Duration(hours: 7, minutes: 30))));
    await s.retryCommunityServers();

    expect(links(s), [_fileA, _fileB]);
  });

  test(
    'a phone whose fetches work keeps the backend\'s list, however old',
    () async {
      var clock = now;
      final source = _Source(links: [_backend]);
      final file = _File();
      final s = ServerState(
        repository: ServerRepository.withConfigSource(
          source,
          clock: () => clock,
        ),
        bootstrap: file,
        now: () => clock,
      );
      await s.loadServers();
      await pumpEventQueue();

      clock = now.add(const Duration(hours: 3));
      file.give(_file(now.add(const Duration(hours: 2, minutes: 50))));

      expect(links(s), [_backend]);
    },
  );

  test(
    'a newer file replaces an older one whatever the clock offset',
    () async {
      addTearDown(ServerClock.resetForTest);
      // The phone's clock is two hours behind the backend's.
      ServerClock.heard(
        HttpDate.format(now.add(const Duration(hours: 2))),
        now,
      );
      final file = _File();
      final s = state(_Source(cut: true), file);
      await s.loadServers();
      await pumpEventQueue();

      file.give(_file(now, const [_fileA]));
      file.give(_file(now.add(const Duration(hours: 1)), const [_fileB]));

      expect(links(s), [_fileB]);
    },
  );
}
