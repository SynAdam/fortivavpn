import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/dial_server.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/connection_info.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/data/repositories/server_repository.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/server_list_screen.dart';
import 'package:fortiva_vpn/services/door_sweep.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/path_memory.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The public list survives a fetch that fails.
///
/// A phone on home wifi got the public list (156 links). The app started
/// again 25 seconds later and that fetch never arrived. The list lived
/// only in memory and a failed fetch came back as an empty list, so the
/// Public tab said "No community servers yet", and when every door of the
/// phone's own server was closed the connect checklist had no shared link
/// to try. The user saw every route blocked.

// Each link carries a flag, because a row is titled by its country; a
// link without one is titled by its number instead, never by its label.
const _linkA = 'vless://uuid@a.example:443?type=tcp#\u{1F1E9}\u{1F1EA} Alpha';
const _linkB = 'vless://uuid@b.example:443?type=tcp#\u{1F1EB}\u{1F1F7} Bravo';
const _linkC = 'vless://uuid@c.example:443?type=tcp#\u{1F1EF}\u{1F1F5} Charlie';

final _cut = ApiException(statusCode: 0, message: 'timeout');

/// The backend as the phone sees it: answers, fails, or holds a fetch
/// until the test lets it go.
class _Source implements ServerConfigSource {
  _Source({this.links = const [], this.error, this.official = const []});

  List<String> links;
  Object? error;
  Completer<List<String>>? hold;
  int communityCalls = 0;

  /// Our own shared links. Their fetch always works: on 2026-10-07 the
  /// phone's call for them reached us and the call for the public list
  /// did not.
  List<Server> official;

  @override
  Future<List<Server>> getOfficialConfigs() async => official;

  @override
  Future<List<String>> getCommunityConfigs() async {
    communityCalls++;
    final held = hold;
    if (held != null) return held.future;
    if (error != null) throw error!;
    return links;
  }
}

/// A repository whose official list throws, which the real one never
/// does, to prove that nothing before the public list can skip it.
class _OfficialThrows extends ServerRepository {
  _OfficialThrows(super.source) : super.withConfigSource();

  @override
  Future<({List<Server> free, List<Server> premium})> getOfficialServers({
    bool forceRefresh = false,
  }) async => throw StateError('official list broke');
}

ServerState _state(_Source source) =>
    ServerState(repository: ServerRepository.withConfigSource(source));

/// A repository that answers each load of the public list from [answers],
/// in order, and has nothing saved.
class _Scripted extends ServerRepository {
  _Scripted(this.answers) : super.withConfigSource(_Source());

  final List<CommunityList> answers;

  @override
  Future<CommunityList> getCommunityServers({
    bool forceRefresh = false,
  }) async => answers.removeAt(0);

  @override
  Future<CommunityList?> savedCommunityServers() async => null;
}

/// One run of the app that fetched [links] and saved them.
Future<void> _earlierRun(List<String> links) async {
  final state = _state(_Source(links: links));
  await state.loadServers();
  await pumpEventQueue();
  expect(state.communityServers, hasLength(links.length));
}

List<String> _uris(ServerState s) => [
  for (final server in s.communityServers) server.connectionUri,
];

// ── The connect checklist ────────────────────────────────────────────────

Server _door(String id, String uri, String door, int serverId) => Server(
  id: id,
  name: id,
  country: 'Germany',
  city: 'Nuremberg',
  connectionUri: uri,
  flagEmoji: '',
  isDedicated: true,
  door: door,
  serverId: serverId,
);

/// The incident's doors, all closed on that wifi. The Cloudflare door is
/// dialled at a Cloudflare address and names the server only in its TLS
/// handshake, which is what the carrier filtered.
final _reality = _door(
  'r11',
  'vless://u@edge-11.example:443?type=xhttp&security=reality#r11',
  'xhttp-reality',
  11,
);
final _ws = _door(
  'w11',
  'vless://u@198.51.100.215:443?type=ws&security=tls&sni=cdn-11.example#w11',
  'ws-tls',
  11,
);

/// Our shared link on the same server, under the same name as [_ws].
const _officialOnSameName = Server(
  id: 'official-11',
  name: 'Official',
  country: 'Germany',
  city: 'Nuremberg',
  connectionUri:
      'vless://o@198.51.100.215:443?type=ws&security=tls&sni=cdn-11.example'
      '&host=cdn-11.example#O11',
  flagEmoji: '',
);

final _ownServer = Server(
  id: 'dedicated-Nuremberg',
  name: 'Nuremberg',
  country: 'Germany',
  city: 'Nuremberg',
  connectionUri: _reality.connectionUri,
  flagEmoji: '',
  isDedicated: true,
  serverId: 11,
);

class _FakeDedicated extends DedicatedState {
  @override
  List<Server> get servers => [_ownServer];

  @override
  List<Server> get paths => [_reality, _ws];

  @override
  bool get hasServers => true;

  @override
  bool get isBlocked => false;

  @override
  bool get isLoading => false;

  @override
  QuotaStatus? get quota => null;

  @override
  Server? get selectedServer => _ownServer;

  @override
  void select(Server server, {bool byUser = true}) {}

  @override
  Future<void> refresh({bool? viaTunnel}) async {}

  @override
  int? pingFor(String serverId) => null;

  @override
  bool isPinging(String serverId) => false;

  @override
  Future<void> pingServer(Server server) async {}
}

/// A tunnel that comes up only through the links in [works].
class _FakeVpn extends VpnService {
  _FakeVpn(this.works);

  final Set<String> works;
  final connects = <Server>[];
  VpnStatus _fake = VpnStatus.disconnected;

  @override
  VpnStatus get status => _fake;

  @override
  bool get isConnected => _fake == VpnStatus.connected;

  @override
  bool get isConnecting => _fake == VpnStatus.connecting;

  @override
  bool get isVerifying => false;

  @override
  ConnectionInfo? get currentConnection => null;

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {
    connects.add(server);
    _fake = VpnStatus.connecting;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    _fake = works.contains(server.connectionUri)
        ? VpnStatus.connected
        : VpnStatus.error;
    notifyListeners();
  }

  @override
  void clearError() {
    if (_fake == VpnStatus.error) _fake = VpnStatus.disconnected;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _fake = VpnStatus.disconnected;
    notifyListeners();
  }
}

/// [onProbe] is told of every check before it runs, and each check of an
/// own door takes [probeTime].
ConnectFlow _flowFor(
  _FakeVpn vpn, {
  void Function(Server path)? onProbe,
  Duration probeTime = Duration.zero,
}) {
  final reporter = VpnEventReporter(
    send: (_, _, _) async {},
    sendProbes: (_, _, _) async {},
    deviceId: () async => 'DEV-1',
    appVersion: () async => '1.6.12',
    platform: 'android',
    networkType: () async => 'wifi',
  );
  return ConnectFlow(
    vpn: vpn,
    memory: PathMemory(),
    finder: PathFinder(
      // A link's check passes exactly when its tunnel would come up.
      probe: (p) async {
        onProbe?.call(p);
        if (p.isDedicated && probeTime > Duration.zero) {
          await Future<void>.delayed(probeTime);
        }
        return vpn.works.contains(p.connectionUri) ? 150 : -1;
      },
      internet: () async => true,
    ),
    reporter: reporter,
    sweep: DoorSweep(appBypassesTunnel: false, reporter: reporter),
    networkKey: () async => 'wifi:TCI',
    carrier: () async => null,
    attemptTimeout: const Duration(seconds: 2),
  );
}

// ── The Public tab ───────────────────────────────────────────────────────

Future<void> _pumpPublicTab(
  WidgetTester tester,
  ServerState state, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ServerState>.value(value: state),
        ChangeNotifierProvider<VpnService>(create: (_) => VpnService()),
      ],
      child: MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: locale,
        home: const ServerListScreen(),
      ),
    ),
  );
}

/// The list reads whether the tunnel is up, which makes the lazy
/// VpnService, and VpnService checks its native side once, 2s after it is
/// made. Clear the tree and let that run, so no test ends with the timer
/// pending.
Future<void> _closePublicTab(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

/// What main.dart does after the first frame, then the fetches land.
Future<void> _launch(WidgetTester tester, ServerState state) async {
  unawaited(state.loadServers());
  await tester.pump();
  await tester.pump();
}

final _failedMessage = find.byKey(const Key('community-load-failed'));
final _retryButton = find.byKey(const Key('community-load-retry'));
final _noServersYet = find.text('No community servers yet');

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

  group('ServerState', () {
    test('shows the saved list while the fetch is still out', () async {
      await _earlierRun([_linkA, _linkB]);

      final source = _Source()..hold = Completer();
      final state = _state(source);
      unawaited(state.loadServers());
      await pumpEventQueue();

      expect(_uris(state), [_linkA, _linkB]);
      expect(state.isLoadingCommunity, isTrue);

      source.hold!.complete([_linkC]);
      await pumpEventQueue();

      expect(_uris(state), [_linkC]);
      expect(state.isLoadingCommunity, isFalse);
      expect(state.communityLoadFailed, isFalse);
    });

    test('flags a failed load, and not an answer with no links', () async {
      final source = _Source(error: _cut);
      final state = _state(source);

      await state.loadServers();
      await pumpEventQueue();
      expect(state.communityServers, isEmpty);
      expect(state.communityLoadFailed, isTrue);

      source
        ..error = null
        ..links = const [];
      await state.retryCommunityServers();
      expect(state.communityServers, isEmpty);
      expect(state.communityLoadFailed, isFalse);

      source.links = [_linkA];
      await state.retryCommunityServers();
      expect(_uris(state), [_linkA]);
      expect(state.communityLoadFailed, isFalse);
    });

    test('a failed load keeps the list it already has', () async {
      final source = _Source(links: [_linkA, _linkB]);
      final state = _state(source);
      await state.loadServers();
      await pumpEventQueue();

      source.error = _cut;
      await state.retryCommunityServers();

      expect(_uris(state), [_linkA, _linkB]);
      expect(state.communityLoadFailed, isTrue);
    });

    test(
      'a failure in the official list does not skip the public list',
      () async {
        final source = _Source(links: [_linkA]);
        final state = ServerState(repository: _OfficialThrows(source));

        await state.loadServers();
        await pumpEventQueue();

        expect(source.communityCalls, 1);
        expect(_uris(state), [_linkA]);
      },
    );

    test('the checklist waits a bounded time, and a late answer still '
        'fills the list', () async {
      final source = _Source()..hold = Completer();
      final state = _state(source);

      final watch = Stopwatch()..start();
      final links = await state.communityForFallback(
        wait: const Duration(milliseconds: 100),
      );
      watch.stop();

      expect(links, isEmpty);
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));

      source.hold!.complete([_linkA]);
      await pumpEventQueue();
      expect(_uris(state), [_linkA], reason: 'ready for the next tap');
    });

    test('a failed load does not empty a list already on screen', () async {
      final a = Server.fromConnectionUri(_linkA, index: 0);
      final b = Server.fromConnectionUri(_linkB, index: 1);
      final state = ServerState(
        repository: _Scripted([
          CommunityList([a, b]),
          const CommunityList([], failed: true),
        ]),
      );
      await state.loadServers();
      await pumpEventQueue();
      expect(_uris(state), [_linkA, _linkB]);

      await state.retryCommunityServers();

      expect(_uris(state), [_linkA, _linkB]);
      expect(state.communityLoadFailed, isTrue);
    });

    test('callers that need the list while it loads share one fetch', () async {
      final source = _Source()..hold = Completer();
      final state = _state(source);
      unawaited(state.loadServers());
      await pumpEventQueue();
      expect(source.communityCalls, 1);

      unawaited(state.retryCommunityServers());
      unawaited(
        state.communityForFallback(wait: const Duration(milliseconds: 50)),
      );
      await pumpEventQueue();
      expect(source.communityCalls, 1);

      source.hold!.complete([_linkA]);
      await pumpEventQueue();
      expect(_uris(state), [_linkA]);
    });

    // The saved list stands in for the fetch only until the fetch answers.
    // A link the backend has since dropped must not come back as the pick.
    test('a pick that a fresh list dropped is not brought back from the '
        'saved one', () async {
      final before = _state(_Source(links: [_linkA, _linkB]));
      await before.loadServers();
      await pumpEventQueue();
      before.selectServer(before.communityServers[1]);
      await before.choiceWritten;

      final after = _state(_Source(links: [_linkA, _linkC]));
      await after.loadServers();
      await pumpEventQueue();

      expect(_uris(after), [_linkA, _linkC]);
      expect(after.isChosen, isFalse);
      expect(after.selectedServer?.connectionUri, isNot(_linkB));
    });

    test('a pick on the saved list comes back when the fetch fails', () async {
      final before = _state(_Source(links: [_linkA, _linkB]));
      await before.loadServers();
      await pumpEventQueue();
      before.selectServer(before.communityServers[1]);
      await before.choiceWritten;

      final after = _state(_Source(error: _cut));
      await after.loadServers();
      await pumpEventQueue();

      expect(after.isChosen, isTrue);
      expect(after.selectedServer?.connectionUri, _linkB);
    });
  });

  group('a link the connect fallback chose', () {
    test('is remembered as the fallback\'s across runs, and a pick by hand '
        'is not', () async {
      final before = _state(_Source(links: [_linkA, _linkB]));
      await before.loadServers();
      await pumpEventQueue();
      before.selectServer(before.communityServers[1], byFallback: true);
      await before.choiceWritten;
      expect(before.chosenByFallback, isTrue);

      final after = _state(_Source(links: [_linkA, _linkB]));
      await after.loadServers();
      await pumpEventQueue();
      expect(after.selectedServer?.connectionUri, _linkB);
      expect(after.chosenByFallback, isTrue);

      after.selectServer(after.communityServers[0]);
      expect(after.chosenByFallback, isFalse);
      after.selectServer(after.communityServers[1], byFallback: true);
      after.clearChoice();
      expect(after.chosenByFallback, isFalse);
    });
  });

  // The backend orders the list for the phone's carrier, links a phone on
  // it got through most recently first. A list fetched when the app started
  // can be hours old when every door of the device's own is closed.
  group('an old list at the fallback', () {
    late DateTime clock;

    ServerState state(_Source source, {Duration? refreshWait}) => ServerState(
      repository: ServerRepository.withConfigSource(source, clock: () => clock),
      refreshWait: refreshWait ?? ServerState.fallbackRefreshWait,
      now: () => clock,
    );

    setUp(() => clock = DateTime.utc(2026, 10, 10, 9));

    test('is fetched again, and the new order is the one used', () async {
      final source = _Source(links: [_linkA, _linkB]);
      final s = state(source);
      await s.loadServers();
      await pumpEventQueue();

      clock = clock.add(const Duration(minutes: 6));
      source.links = [_linkC, _linkA];
      final links = await s.communityForFallback();

      expect(source.communityCalls, 2);
      expect([for (final l in links) l.connectionUri], [_linkC, _linkA]);
    });

    test('a list fetched minutes ago is used as it is', () async {
      final source = _Source(links: [_linkA, _linkB]);
      final s = state(source);
      await s.loadServers();
      await pumpEventQueue();

      clock = clock.add(const Duration(minutes: 4));
      final links = await s.communityForFallback();

      expect(source.communityCalls, 1);
      expect([for (final l in links) l.connectionUri], [_linkA, _linkB]);
    });

    test('is still used when the new one does not arrive in time, and the '
        'late one is there for the next tap', () async {
      final source = _Source(links: [_linkA, _linkB]);
      final s = state(source, refreshWait: const Duration(milliseconds: 50));
      await s.loadServers();
      await pumpEventQueue();

      clock = clock.add(const Duration(minutes: 6));
      source.hold = Completer();
      final watch = Stopwatch()..start();
      final links = await s.communityForFallback();
      watch.stop();

      expect([for (final l in links) l.connectionUri], [_linkA, _linkB]);
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));

      source.hold!.complete([_linkC]);
      await pumpEventQueue();
      expect(_uris(s), [_linkC]);
    });

    test('is still used when the new fetch fails', () async {
      final source = _Source(links: [_linkA, _linkB]);
      final s = state(source);
      await s.loadServers();
      await pumpEventQueue();

      clock = clock.add(const Duration(minutes: 6));
      source.error = _cut;
      final links = await s.communityForFallback();

      expect(source.communityCalls, 2);
      expect([for (final l in links) l.connectionUri], [_linkA, _linkB]);
    });

    test('is still used when the new one has no links', () async {
      final source = _Source(links: [_linkA, _linkB]);
      final s = state(source);
      await s.loadServers();
      await pumpEventQueue();

      clock = clock.add(const Duration(minutes: 6));
      source.links = const [];
      final links = await s.communityForFallback();

      expect(source.communityCalls, 2);
      expect([for (final l in links) l.connectionUri], [_linkA, _linkB]);
    });

    test('saved by an earlier run, is fetched again', () async {
      final earlier = state(_Source(links: [_linkA]));
      await earlier.loadServers();
      await pumpEventQueue();

      clock = clock.add(const Duration(minutes: 30));
      final source = _Source(links: [_linkB]);
      final s = state(source);
      final links = await s.communityForFallback();

      expect(source.communityCalls, 1);
      expect([for (final l in links) l.connectionUri], [_linkB]);
    });
  });

  group('the connect checklist', () {
    test(
      'reaches a saved public link when the list in memory is empty',
      () async {
        await _earlierRun([_linkA, _linkB]);

        // This run's fetch fails, and the list in memory is still empty.
        final state = _state(_Source(error: _cut));
        expect(state.communityServers, isEmpty);

        final vpn = _FakeVpn({_linkB});
        final flow = _flowFor(vpn);
        await dialServer(
          _ownServer,
          vpn: vpn,
          flow: flow,
          dedicated: _FakeDedicated(),
          servers: state,
        );

        expect(flow.stage, ConnectStage.done);
        expect(vpn.connects.last.connectionUri, _linkB);
        expect(state.selectedServer?.connectionUri, _linkB);
        await vpn.disconnect();
      },
    );

    test('with nothing saved, fetches the list once before saying every '
        'route is blocked', () async {
      final source = _Source(links: [_linkC]);
      final state = _state(source);

      final vpn = _FakeVpn({_linkC});
      final flow = _flowFor(vpn);
      await dialServer(
        _ownServer,
        vpn: vpn,
        flow: flow,
        dedicated: _FakeDedicated(),
        servers: state,
      );

      expect(source.communityCalls, 1);
      expect(flow.stage, ConnectStage.done);
      expect(vpn.connects.last.connectionUri, _linkC);
      await vpn.disconnect();
    });

    // On 2026-10-07 the fetch did not fail at once: it never came back.
    test('reaches a saved public link while the fetch hangs', () async {
      await _earlierRun([_linkA, _linkB]);
      final source = _Source()..hold = Completer();
      final state = _state(source);

      final vpn = _FakeVpn({_linkB});
      final flow = _flowFor(vpn);
      final watch = Stopwatch()..start();
      await dialServer(
        _ownServer,
        vpn: vpn,
        flow: flow,
        dedicated: _FakeDedicated(),
        servers: state,
      );
      watch.stop();

      expect(flow.stage, ConnectStage.done);
      expect(vpn.connects.last.connectionUri, _linkB);
      expect(watch.elapsed, lessThan(ServerState.fallbackFetchWait ~/ 4));
      await vpn.disconnect();
    });

    // The fetch the checklist may need starts with the tap, so it has the
    // whole of the own door checks to arrive in.
    test('starts looking for the public list when the tap starts', () async {
      final source = _Source()..hold = Completer();
      final state = _state(source);
      final callsAtCheck = <int>[];

      final vpn = _FakeVpn({_linkC});
      final flow = _flowFor(
        vpn,
        probeTime: const Duration(milliseconds: 20),
        onProbe: (p) {
          if (!p.isDedicated) return;
          callsAtCheck.add(source.communityCalls);
          // The list arrives while the own doors are being checked.
          if (p == _ws) source.hold!.complete([_linkC]);
        },
      );
      await dialServer(
        _ownServer,
        vpn: vpn,
        flow: flow,
        dedicated: _FakeDedicated(),
        servers: state,
      );

      // Asked for before the last own door was checked, not after.
      expect(callsAtCheck.last, 1);
      expect(source.communityCalls, 1);
      expect(flow.stage, ConnectStage.done);
      expect(vpn.connects.last.connectionUri, _linkC);
      await vpn.disconnect();
    });

    // The wait for a list that never comes counts from the tap, so our own
    // shared link is not held back behind it once the own doors fail.
    test('the wait for a list that never comes runs alongside the own '
        'door checks', () async {
      const ours = Server(
        id: 'official-1',
        name: 'Ours',
        country: '',
        city: '',
        connectionUri: 'vless://o@ours.example:443?type=tcp#Ours',
        flagEmoji: '',
      );
      final source = _Source(official: [ours])..hold = Completer();
      final state = ServerState(
        repository: ServerRepository.withConfigSource(source),
        fallbackWait: const Duration(seconds: 1),
      );
      await state.loadServers();
      expect(state.officialServers.single.connectionUri, ours.connectionUri);

      final vpn = _FakeVpn({ours.connectionUri});
      final flow = _flowFor(vpn, probeTime: const Duration(milliseconds: 600));
      final watch = Stopwatch()..start();
      await dialServer(
        _ownServer,
        vpn: vpn,
        flow: flow,
        dedicated: _FakeDedicated(),
        servers: state,
      );
      watch.stop();

      expect(flow.stage, ConnectStage.done);
      expect(vpn.connects.last.connectionUri, ours.connectionUri);
      // The two own doors take 1.2 s and the wait 1 s. One after the other
      // they would take 2.2 s.
      expect(watch.elapsed, lessThan(const Duration(milliseconds: 1700)));
      await vpn.disconnect();
    });

    // The incident, tap after tap: every own door closed, our shared link
    // on the same filtered name, and one public link deep in the saved
    // list that works. Each tap must get further down the list.
    test('taps in a row work down the saved list until one connects', () async {
      final links = [
        for (var i = 0; i < 20; i++) 'vless://u@p$i.example:443?type=tcp#P$i',
      ];
      await _earlierRun(links);

      final state = _state(
        _Source(error: _cut, official: [_officialOnSameName]),
      );
      await state.loadServers();
      await pumpEventQueue();
      expect(state.communityServers, hasLength(20));
      expect(state.communityLoadFailed, isTrue);

      final vpn = _FakeVpn({links[14]});
      final flow = _flowFor(vpn);
      final dedicated = _FakeDedicated();
      var taps = 0;
      while (taps < 3 && flow.stage != ConnectStage.done) {
        taps++;
        await dialServer(
          _ownServer,
          vpn: vpn,
          flow: flow,
          dedicated: dedicated,
          servers: state,
        );
      }

      expect(flow.stage, ConnectStage.done);
      expect(vpn.connects.last.connectionUri, links[14]);
      await vpn.disconnect();
    });
  });

  group('the Public tab', () {
    testWidgets('says the list could not be loaded only when the load '
        'failed', (tester) async {
      final failed = _state(_Source(error: _cut));
      await _pumpPublicTab(tester, failed);
      await _launch(tester, failed);

      expect(_failedMessage, findsOneWidget);
      expect(find.text('Could not load this list'), findsOneWidget);
      expect(_retryButton, findsOneWidget);
      expect(_noServersYet, findsNothing);

      final empty = _state(_Source(links: const []));
      await _pumpPublicTab(tester, empty);
      await _launch(tester, empty);

      expect(_noServersYet, findsOneWidget);
      expect(_failedMessage, findsNothing);
      expect(_retryButton, findsNothing);
      await _closePublicTab(tester);
    });

    // A phone with the keyboard open over the search field has about this
    // much room left for the list.
    testWidgets('the could-not-load message fits a short screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final source = _Source(error: _cut);
      final state = _state(source);
      await _pumpPublicTab(tester, state, locale: const Locale('fa'));
      await _launch(tester, state);

      expect(_failedMessage, findsOneWidget);
      expect(tester.takeException(), isNull);

      source
        ..error = null
        ..links = [_linkA];
      await tester.ensureVisible(_retryButton);
      await tester.pump();
      await tester.tap(_retryButton);
      await tester.pump();
      await tester.pump();
      expect(find.text('Germany'), findsOneWidget);
      await _closePublicTab(tester);
    });

    testWidgets('Try again loads the list', (tester) async {
      final source = _Source(error: _cut);
      final state = _state(source);
      await _pumpPublicTab(tester, state);
      await _launch(tester, state);
      expect(_retryButton, findsOneWidget);

      source.error = null;
      source.links = [_linkA, _linkB];
      await tester.tap(_retryButton);
      await tester.pump();
      await tester.pump();

      expect(find.text('Germany'), findsOneWidget);
      expect(find.text('France'), findsOneWidget);
      expect(_failedMessage, findsNothing);
      await _closePublicTab(tester);
    });

    testWidgets('shows progress, not "no servers yet", while the first '
        'load runs', (tester) async {
      final source = _Source()..hold = Completer();
      final state = _state(source);
      await _pumpPublicTab(tester, state);
      await _launch(tester, state);

      expect(_noServersYet, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      source.hold!.complete([_linkA]);
      await tester.pump();
      await tester.pump();
      expect(find.text('Germany'), findsOneWidget);
      await _closePublicTab(tester);
    });

    // The incident, in order.
    testWidgets('the first fetch works, the app restarts, the next fetch '
        'fails, and the Public tab still lists the links', (tester) async {
      // 07:34 Tehran: the list arrives.
      final first = _Source(links: [_linkA, _linkB, _linkC]);
      final before = _state(first);
      await _pumpPublicTab(tester, before);
      await _launch(tester, before);
      expect(find.text('Germany'), findsOneWidget);

      // 07:35: the app starts again. Nothing is in memory, and the fetch
      // never arrives.
      final second = _Source(error: _cut);
      final after = _state(second);
      await _pumpPublicTab(tester, after);
      await _launch(tester, after);

      expect(second.communityCalls, 1, reason: 'the fetch was tried');
      expect(after.communityLoadFailed, isTrue);
      expect(find.text('Germany'), findsOneWidget);
      expect(find.text('France'), findsOneWidget);
      expect(find.text('Japan'), findsOneWidget);
      expect(_noServersYet, findsNothing);
      expect(_failedMessage, findsNothing);
      await _closePublicTab(tester);
    });
  });
}
