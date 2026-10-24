import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/data/repositories/server_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A source the test drives directly: it counts calls, and can be told to
/// fail the way the real one does.
class FakeConfigSource implements ServerConfigSource {
  FakeConfigSource({
    this.official = const [],
    this.community = const [],
    this.officialError,
    this.communityError,
  });

  List<Server> official;
  List<String> community;
  Object? officialError;
  Object? communityError;

  int officialCalls = 0;
  int communityCalls = 0;

  @override
  Future<List<Server>> getOfficialConfigs() async {
    officialCalls++;
    if (officialError != null) throw officialError!;
    return official;
  }

  @override
  Future<List<String>> getCommunityConfigs() async {
    communityCalls++;
    if (communityError != null) throw communityError!;
    return community;
  }
}

Server server(String id, {bool premium = false}) => Server(
  id: id,
  name: id,
  country: 'Unknown',
  city: '',
  connectionUri: 'vless://uuid@$id:443',
  flagEmoji: '\u{1F30D}',
  isPremium: premium,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('official servers', () {
    test('splits the response into free and premium', () async {
      final source = FakeConfigSource(
        official: [server('a'), server('b', premium: true), server('c')],
      );
      final repo = ServerRepository.withConfigSource(source);

      final result = await repo.getOfficialServers();

      expect(result.free.map((s) => s.id), ['a', 'c']);
      expect(result.premium.map((s) => s.id), ['b']);
    });

    test('a second read inside the window is served from cache', () async {
      final source = FakeConfigSource(official: [server('a')]);
      final repo = ServerRepository.withConfigSource(source);

      await repo.getOfficialServers();
      await repo.getOfficialServers();

      expect(source.officialCalls, 1);
    });

    test('forceRefresh goes back to the source', () async {
      final source = FakeConfigSource(official: [server('a')]);
      final repo = ServerRepository.withConfigSource(source);

      await repo.getOfficialServers();
      await repo.getOfficialServers(forceRefresh: true);

      expect(source.officialCalls, 2);
    });

    test('forceRefresh picks up servers added since the last read', () async {
      final source = FakeConfigSource(official: [server('a')]);
      final repo = ServerRepository.withConfigSource(source);

      await repo.getOfficialServers();
      source.official = [server('a'), server('b')];

      final stale = await repo.getOfficialServers();
      expect(stale.free.length, 1, reason: 'cache still holds');

      final fresh = await repo.getOfficialServers(forceRefresh: true);
      expect(fresh.free.length, 2);
    });

    test('clearCache forces the next read to hit the source', () async {
      final source = FakeConfigSource(official: [server('a')]);
      final repo = ServerRepository.withConfigSource(source);

      await repo.getOfficialServers();
      repo.clearCache();
      await repo.getOfficialServers();

      expect(source.officialCalls, 2);
    });

    test('an ApiException degrades to empty lists, not a throw', () async {
      // The UI has no error path for this: it renders whatever it gets.
      // Returning empty is what keeps a backend outage from being a crash.
      final source = FakeConfigSource(
        officialError: ApiException(statusCode: 500, message: 'boom'),
      );
      final repo = ServerRepository.withConfigSource(source);

      final result = await repo.getOfficialServers();

      expect(result.free, isEmpty);
      expect(result.premium, isEmpty);
    });

    test('an unexpected error degrades the same way', () async {
      final source = FakeConfigSource(officialError: FormatException('bad'));
      final repo = ServerRepository.withConfigSource(source);

      final result = await repo.getOfficialServers();

      expect(result.free, isEmpty);
      expect(result.premium, isEmpty);
    });

    test('a failed fetch is not cached as an empty result', () async {
      final source = FakeConfigSource(
        officialError: ApiException(statusCode: 503, message: 'down'),
      );
      final repo = ServerRepository.withConfigSource(source);

      await repo.getOfficialServers();
      source.officialError = null;
      source.official = [server('a')];

      // Without forceRefresh. A cached failure would strand the user on
      // an empty list until the app is restarted.
      final result = await repo.getOfficialServers();
      expect(result.free.map((s) => s.id), ['a']);
    });

    test('the returned lists are unmodifiable', () async {
      final source = FakeConfigSource(official: [server('a')]);
      final repo = ServerRepository.withConfigSource(source);

      final result = await repo.getOfficialServers();

      expect(() => result.free.add(server('b')), throwsUnsupportedError);
    });
  });

  group('community servers', () {
    test('parses each URI into a Server', () async {
      final source = FakeConfigSource(
        community: [
          'vless://uuid@one.example:443#One',
          'vless://uuid@two.example:443#Two',
        ],
      );
      final repo = ServerRepository.withConfigSource(source);

      final servers = (await repo.getCommunityServers()).servers;

      expect(servers.map((s) => s.remark), ['One', 'Two']);
    });

    test('a malformed URI is skipped, the rest survive', () async {
      final source = FakeConfigSource(
        community: ['vless://uuid@one.example:443#One', '', 'garbage'],
      );
      final repo = ServerRepository.withConfigSource(source);

      final servers = (await repo.getCommunityServers()).servers;

      // The two that are not links of a kind the app can dial are left
      // out. What matters is that one bad entry in a Telegram scrape never
      // empties the list.
      expect(servers, hasLength(1));
      expect(servers.first.remark, 'One');
    });

    test('caches within the window and refreshes on demand', () async {
      final source = FakeConfigSource(community: ['vless://uuid@a:443#A']);
      final repo = ServerRepository.withConfigSource(source);

      await repo.getCommunityServers();
      await repo.getCommunityServers();
      expect(source.communityCalls, 1);

      await repo.getCommunityServers(forceRefresh: true);
      expect(source.communityCalls, 2);
    });

    test('a failure with no list kept is reported as a failure', () async {
      final source = FakeConfigSource(
        communityError: ApiException(statusCode: 0, message: 'no network'),
      );
      final repo = ServerRepository.withConfigSource(source);

      final result = await repo.getCommunityServers();

      expect(result.servers, isEmpty);
      expect(result.failed, isTrue);
    });

    test('official and community caches are independent', () async {
      final source = FakeConfigSource(
        official: [server('a')],
        community: ['vless://uuid@b:443#B'],
      );
      final repo = ServerRepository.withConfigSource(source);

      await repo.getOfficialServers();
      await repo.getCommunityServers();
      await repo.getOfficialServers(forceRefresh: true);

      expect(source.officialCalls, 2);
      expect(source.communityCalls, 1);
    });
  });

  // A phone on home wifi got the public list, the app started again 25
  // seconds later, and the next fetch never arrived. The list lived only
  // in memory, so the screen said "no servers yet" and the connect
  // checklist had no shared link to try.
  group('the saved public list', () {
    const linkA = 'vless://uuid@a.example:443#A';
    const linkB = 'vless://uuid@b.example:443#B';
    const linkC = 'vless://uuid@c.example:443#C';
    final cut = ApiException(statusCode: 0, message: 'timeout');

    test('a failed fetch keeps the list from earlier in this run', () async {
      final source = FakeConfigSource(community: [linkA, linkB]);
      final repo = ServerRepository.withConfigSource(source);
      await repo.getCommunityServers();
      // Only the list in memory can answer now.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ServerRepository.savedCommunityKey);

      source.communityError = cut;
      final result = await repo.getCommunityServers(forceRefresh: true);

      expect(result.servers.map((s) => s.remark), ['A', 'B']);
      expect(result.failed, isTrue);
      expect(source.communityCalls, 2);
    });

    test('a cold start reads the list the last run saved', () async {
      final before = ServerRepository.withConfigSource(
        FakeConfigSource(community: [linkA, linkB]),
      );
      await before.getCommunityServers();

      // The next run: nothing in memory, and its fetch fails.
      final source = FakeConfigSource(communityError: cut);
      final after = ServerRepository.withConfigSource(source);

      final saved = await after.savedCommunityServers();
      expect(saved?.servers.map((s) => s.remark), ['A', 'B']);
      expect(source.communityCalls, 0, reason: 'read without a fetch');

      final result = await after.getCommunityServers();
      expect(result.servers.map((s) => s.remark), ['A', 'B']);
      expect(result.servers.map((s) => s.connectionUri), [linkA, linkB]);
      expect(result.failed, isTrue);
    });

    test('a fresh answer replaces the saved list', () async {
      await ServerRepository.withConfigSource(
        FakeConfigSource(community: [linkA, linkB]),
      ).getCommunityServers();
      final fresh = await ServerRepository.withConfigSource(
        FakeConfigSource(community: [linkC]),
      ).getCommunityServers();
      expect(fresh.failed, isFalse);

      final later = await ServerRepository.withConfigSource(
        FakeConfigSource(communityError: cut),
      ).getCommunityServers();

      expect(later.servers.map((s) => s.remark), ['C']);
    });

    test('an answer with no links is not a failure, a fetch with no '
        'answer is', () async {
      final empty = await ServerRepository.withConfigSource(
        FakeConfigSource(community: const []),
      ).getCommunityServers();
      expect(empty.servers, isEmpty);
      expect(empty.failed, isFalse);

      final cutOff = await ServerRepository.withConfigSource(
        FakeConfigSource(communityError: cut),
      ).getCommunityServers();
      expect(cutOff.servers, isEmpty);
      expect(cutOff.failed, isTrue);
    });

    // The backend answers with no links when it cannot read its own list.
    // That must not cost the next run that cannot reach us its list.
    test('an answer with no links does not replace the saved list', () async {
      await ServerRepository.withConfigSource(
        FakeConfigSource(community: [linkA, linkB]),
      ).getCommunityServers();

      final empty = await ServerRepository.withConfigSource(
        FakeConfigSource(community: const []),
      ).getCommunityServers();
      expect(empty.servers, isEmpty);
      expect(empty.failed, isFalse);

      final later = await ServerRepository.withConfigSource(
        FakeConfigSource(communityError: cut),
      ).getCommunityServers();
      expect(later.servers.map((s) => s.remark), ['A', 'B']);
      expect(later.failed, isTrue);
    });

    test(
      'a list older than the limit is dropped, a younger one kept',
      () async {
        final fetched = DateTime.utc(2026, 10, 7, 4, 4, 46);
        await ServerRepository.withConfigSource(
          FakeConfigSource(community: [linkA]),
          clock: () => fetched,
        ).getCommunityServers();

        Future<CommunityList> failAfter(Duration age) =>
            ServerRepository.withConfigSource(
              FakeConfigSource(communityError: cut),
              clock: () => fetched.add(age),
            ).getCommunityServers();

        final young = await failAfter(
          ServerRepository.savedCommunityMaxAge - const Duration(hours: 1),
        );
        expect(young.servers.map((s) => s.remark), ['A']);
        expect(young.fetchedAt, fetched);

        final old = await failAfter(
          ServerRepository.savedCommunityMaxAge + const Duration(hours: 1),
        );
        expect(old.servers, isEmpty);
        expect(old.failed, isTrue);
      },
    );

    test('a saved copy that cannot be read counts as none', () async {
      SharedPreferences.setMockInitialValues({
        ServerRepository.savedCommunityKey: 'not json',
      });
      final repo = ServerRepository.withConfigSource(
        FakeConfigSource(communityError: cut),
      );

      expect(await repo.savedCommunityServers(), isNull);
      final result = await repo.getCommunityServers();
      expect(result.servers, isEmpty);
      expect(result.failed, isTrue);
    });
  });

  group('lookup', () {
    test(
      'getServerById finds a free, a premium and a community server',
      () async {
        final source = FakeConfigSource(
          official: [server('free-1'), server('prem-1', premium: true)],
          community: ['vless://uuid@c:443#C'],
        );
        final repo = ServerRepository.withConfigSource(source);

        expect((await repo.getServerById('free-1'))?.id, 'free-1');
        expect((await repo.getServerById('prem-1'))?.id, 'prem-1');
        expect((await repo.getServerById('telegram-0'))?.id, 'telegram-0');
      },
    );

    test('getServerById returns null for an unknown id', () async {
      final repo = ServerRepository.withConfigSource(
        FakeConfigSource(official: [server('a')]),
      );
      expect(await repo.getServerById('nope'), isNull);
    });

    test('getOptimalServer prefers the lowest measured latency', () async {
      final source = FakeConfigSource(
        official: [server('slow'), server('fast'), server('unmeasured')],
      );
      final repo = ServerRepository.withConfigSource(source);
      await repo.getOfficialServers();

      repo.updateServerLatency('slow', 300);
      repo.updateServerLatency('fast', 40);

      expect((await repo.getOptimalServer()).id, 'fast');
    });

    test('getOptimalServer falls back to the first free server', () async {
      final repo = ServerRepository.withConfigSource(
        FakeConfigSource(official: [server('a'), server('b')]),
      );
      expect((await repo.getOptimalServer()).id, 'a');
    });

    test('getOptimalServer falls back to community, then premium', () async {
      final community = ServerRepository.withConfigSource(
        FakeConfigSource(
          official: [server('p', premium: true)],
          community: ['vless://uuid@c:443#C'],
        ),
      );
      expect((await community.getOptimalServer()).id, 'telegram-0');

      final premiumOnly = ServerRepository.withConfigSource(
        FakeConfigSource(official: [server('p', premium: true)]),
      );
      expect((await premiumOnly.getOptimalServer()).id, 'p');
    });

    test('getOptimalServer throws when there is nothing at all', () async {
      final repo = ServerRepository.withConfigSource(FakeConfigSource());
      expect(repo.getOptimalServer(), throwsA(isA<Exception>()));
    });
  });

  group('latency updates', () {
    test('writes through to the cached free list', () async {
      final repo = ServerRepository.withConfigSource(
        FakeConfigSource(official: [server('a')]),
      );
      await repo.getOfficialServers();

      repo.updateServerLatency('a', 42);

      final result = await repo.getOfficialServers();
      expect(result.free.single.latencyMs, 42);
    });

    test('an unknown id is a no-op rather than an error', () async {
      final repo = ServerRepository.withConfigSource(
        FakeConfigSource(official: [server('a')]),
      );
      await repo.getOfficialServers();

      expect(() => repo.updateServerLatency('nope', 42), returnsNormally);
    });

    test('updating before anything is cached is a no-op', () {
      final repo = ServerRepository.withConfigSource(FakeConfigSource());
      expect(() => repo.updateServerLatency('a', 42), returnsNormally);
    });
  });
}
