import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/server.dart';
import '../../api/config_service.dart';
import '../../utils/shared_link.dart';

/// The public list as one load left it.
@immutable
class CommunityList {
  const CommunityList(this.servers, {this.fetchedAt, this.failed = false});

  /// The links, parsed, in the order the backend sent them.
  final List<Server> servers;

  /// When the backend sent [servers]. Null when no list ever arrived.
  final DateTime? fetchedAt;

  /// Whether the fetch this load made got no answer.
  ///
  /// [servers] is then the last list that did arrive, from earlier in
  /// this run or saved on the phone, and is empty only when there is
  /// none. An answer with no links in it is not a failure.
  final bool failed;
}

/// Repository for managing server data
/// Fetches the official and community lists from the backend. Nothing is
/// built in: a failed fetch leaves the official list empty, and the
/// community list falls back to the last one saved on the phone.
class ServerRepository {
  // Singleton pattern
  static final ServerRepository _instance = ServerRepository._internal();
  factory ServerRepository() => _instance;
  ServerRepository._internal()
    : _configService = ConfigService(),
      _prefs = SharedPreferences.getInstance,
      _clock = DateTime.now;

  /// Build a repository over a supplied source, for tests.
  ///
  /// The caching and the degrade-to-empty behaviour below are what the UI
  /// relies on, and neither can be exercised through the singleton
  /// because it reaches straight for the network.
  @visibleForTesting
  ServerRepository.withConfigSource(
    this._configService, {
    Future<SharedPreferences> Function()? prefs,
    DateTime Function()? clock,
  }) : _prefs = prefs ?? SharedPreferences.getInstance,
       _clock = clock ?? DateTime.now;

  final ServerConfigSource _configService;
  final Future<SharedPreferences> Function() _prefs;
  final DateTime Function() _clock;

  /// Where the last public list that arrived with links in it is kept on
  /// the phone: its links and when they arrived.
  static const savedCommunityKey = 'community_list_saved';

  /// How old a saved public list may be and still be shown and tried.
  ///
  /// Every fetch that brings links replaces the saved list, so its age
  /// only grows while no fetch works: on a network that drops our calls, or
  /// in a shutdown. That is when the phone needs it most. A phone on home
  /// wifi once got the list, the app started again 25 seconds later, the
  /// next fetch never arrived, and with only an empty list in memory the
  /// connect checklist had no shared link to try.
  ///
  /// Most links stop working within hours, but the few that last are
  /// then the only way out, and a dead one costs one check that the
  /// checklist already limits. A limit of hours would drop the list in
  /// exactly the case it is kept for. A phone that has reached us at any
  /// time in the last month keeps a list; an older one is dropped, so
  /// the screen says the list could not be loaded rather than show
  /// links that are almost all dead.
  static const savedCommunityMaxAge = Duration(days: 30);

  // Cache for official servers (split into free/premium)
  List<Server>? _cachedFreeServers;
  List<Server>? _cachedPremiumServers;
  DateTime? _lastFetch;

  // Separate cache for community servers
  List<Server>? _cachedCommunityServers;
  DateTime? _lastCommunityFetch;

  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Check if official cache is still valid
  bool get _isCacheValid {
    if (_cachedFreeServers == null ||
        _cachedPremiumServers == null ||
        _lastFetch == null) {
      return false;
    }
    return _clock().difference(_lastFetch!) < _cacheExpiry;
  }

  /// Check if community cache is still valid
  bool get _isCommunityCacheValid {
    if (_cachedCommunityServers == null || _lastCommunityFetch == null) {
      return false;
    }
    return _clock().difference(_lastCommunityFetch!) < _cacheExpiry;
  }

  /// Get official servers, split into free and premium
  /// Returns a record of (freeServers, premiumServers)
  Future<({List<Server> free, List<Server> premium})> getOfficialServers({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _isCacheValid) {
      return (
        free: List<Server>.unmodifiable(_cachedFreeServers!),
        premium: List<Server>.unmodifiable(_cachedPremiumServers!),
      );
    }

    try {
      final allServers = await _configService.getOfficialConfigs();

      final List<Server> freeList = allServers
          .where((s) => !s.isPremium)
          .toList();
      final List<Server> premiumList = allServers
          .where((s) => s.isPremium)
          .toList();
      _cachedFreeServers = freeList;
      _cachedPremiumServers = premiumList;
      _lastFetch = _clock();

      return (
        free: List<Server>.unmodifiable(_cachedFreeServers!),
        premium: List<Server>.unmodifiable(_cachedPremiumServers!),
      );
    } catch (_) {
      // Graceful degradation: an empty split lets the UI fall back to
      // community servers instead of erroring out.
      return (free: const <Server>[], premium: const <Server>[]);
    }
  }

  /// Get the public list: links from public channels and other sources.
  ///
  /// Never throws, and never turns a failure into an empty list. A fetch
  /// that gets no answer returns the last list that did arrive, from
  /// earlier in this run or saved on the phone, marked
  /// [CommunityList.failed]. Every answer with links in it is saved, so
  /// the next run of the app has a list even when its own fetch fails.
  Future<CommunityList> getCommunityServers({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCommunityCacheValid) {
      return CommunityList(
        List.unmodifiable(_cachedCommunityServers!),
        fetchedAt: _lastCommunityFetch,
      );
    }

    final List<String> connectionUris;
    try {
      connectionUris = await _configService.getCommunityConfigs();
    } catch (e) {
      debugPrint('ServerRepository: could not load the public list ($e)');
      return _keptCommunityServers();
    }

    final servers = parseLinks(connectionUris);
    final at = _clock();
    _cachedCommunityServers = servers;
    _lastCommunityFetch = at;
    // An answer with no links does not replace a saved list that has some.
    // The backend sends none when it cannot read its own list, and the
    // next run that cannot reach us would then have nothing to try.
    if (servers.isNotEmpty) await _saveCommunityServers(servers, at);
    return CommunityList(List.unmodifiable(servers), fetchedAt: at);
  }

  /// The public list saved by the last fetch that brought links, without
  /// asking the backend.
  ///
  /// Null when nothing is saved, the saved copy cannot be read, or it is
  /// older than [savedCommunityMaxAge].
  Future<CommunityList?> savedCommunityServers() async {
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(savedCommunityKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final at = DateTime.tryParse('${decoded['at']}');
      final links = decoded['links'];
      if (at == null || links is! List) return null;
      if (_clock().difference(at) > savedCommunityMaxAge) return null;
      return CommunityList(
        List.unmodifiable(parseLinks(links.whereType<String>().toList())),
        fetchedAt: at,
      );
    } catch (e) {
      debugPrint('ServerRepository: could not read the saved list ($e)');
      return null;
    }
  }

  /// What a failed fetch returns: the list from earlier in this run, or
  /// else the saved one, marked failed.
  Future<CommunityList> _keptCommunityServers() async {
    final inMemory = _cachedCommunityServers;
    if (inMemory != null && inMemory.isNotEmpty) {
      return CommunityList(
        List.unmodifiable(inMemory),
        fetchedAt: _lastCommunityFetch,
        failed: true,
      );
    }
    final saved = await savedCommunityServers();
    return CommunityList(
      saved?.servers ?? const [],
      fetchedAt: saved?.fetchedAt,
      failed: true,
    );
  }

  /// The links of the public list the app can use, as servers.
  ///
  /// A link the core cannot dial, or one whose allowInsecure makes the core
  /// refuse the whole config, is left out (see [SharedLink]). Shown, it
  /// would be tested as a timeout, and dialled, it would end in "The tunnel
  /// did not start" with nothing the user could do about it. The index
  /// stays the one the backend gave.
  static List<Server> parseLinks(List<String> connectionUris) {
    final servers = <Server>[];
    for (var i = 0; i < connectionUris.length; i++) {
      if (!SharedLink.usable(connectionUris[i])) continue;
      try {
        servers.add(Server.fromConnectionUri(connectionUris[i], index: i));
      } catch (_) {
        // Skip a single malformed URI rather than losing the whole batch.
      }
    }
    return servers;
  }

  /// Keep [servers] for the next run of the app. A list that cannot be
  /// saved still serves this run, so a failure is only logged.
  Future<void> _saveCommunityServers(List<Server> servers, DateTime at) async {
    try {
      final prefs = await _prefs();
      await prefs.setString(
        savedCommunityKey,
        jsonEncode({
          'at': at.toUtc().toIso8601String(),
          'links': [for (final s in servers) s.connectionUri],
        }),
      );
    } catch (e) {
      debugPrint('ServerRepository: could not save the public list ($e)');
    }
  }

  /// Force refresh all servers from API
  Future<void> refreshAll() async {
    await Future.wait([
      getOfficialServers(forceRefresh: true),
      getCommunityServers(forceRefresh: true),
    ]);
  }

  /// Get server by ID (searches across all categories)
  Future<Server?> getServerById(String id) async {
    final official = await getOfficialServers();

    // Check free servers
    try {
      return official.free.firstWhere((server) => server.id == id);
    } catch (_) {}

    // Check premium servers
    try {
      return official.premium.firstWhere((server) => server.id == id);
    } catch (_) {}

    // Check community servers
    final community = (await getCommunityServers()).servers;
    try {
      return community.firstWhere((server) => server.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get optimal server (currently just returns first available free server)
  Future<Server> getOptimalServer() async {
    final official = await getOfficialServers();

    // Prefer free official servers
    if (official.free.isNotEmpty) {
      final withLatency = official.free
          .where((s) => s.latencyMs != null)
          .toList();
      if (withLatency.isNotEmpty) {
        withLatency.sort((a, b) => a.latencyMs!.compareTo(b.latencyMs!));
        return withLatency.first;
      }
      return official.free.first;
    }

    // Fallback to community
    final community = (await getCommunityServers()).servers;
    if (community.isNotEmpty) return community.first;

    // Fallback to premium
    if (official.premium.isNotEmpty) return official.premium.first;

    throw Exception('No servers available');
  }

  /// Update server latency (for ping tests)
  void updateServerLatency(String serverId, int latencyMs) {
    _updateLatencyInList(_cachedFreeServers, serverId, latencyMs);
    _updateLatencyInList(_cachedPremiumServers, serverId, latencyMs);
    _updateLatencyInList(_cachedCommunityServers, serverId, latencyMs);
  }

  void _updateLatencyInList(
    List<Server>? list,
    String serverId,
    int latencyMs,
  ) {
    if (list == null) return;
    final index = list.indexWhere((s) => s.id == serverId);
    if (index != -1) {
      list[index] = list[index].copyWith(latencyMs: latencyMs);
    }
  }

  /// Clear the caches in memory to force a fresh fetch. The saved public
  /// list stays.
  void clearCache() {
    _cachedFreeServers = null;
    _cachedPremiumServers = null;
    _lastFetch = null;
    _cachedCommunityServers = null;
    _lastCommunityFetch = null;
  }
}
