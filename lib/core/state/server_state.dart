import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/bootstrap.dart';
import '../../api/server_clock.dart';
import '../../data/models/server.dart';
import '../../data/repositories/server_repository.dart';
import '../../services/community_checks.dart';
import '../../services/ping_service.dart';

/// State manager for server data and ping results
/// Manages three categories: Community, Free (official), Premium (official)
class ServerState extends ChangeNotifier {
  /// [fallbackWait] is how long [communityForFallback] waits for a fetch.
  /// Tests shorten it; the app uses [fallbackFetchWait]. [refreshWait] is
  /// the same for a list that is only old, and the app uses
  /// [fallbackRefreshWait]. [now] is the clock that tells a list's age.
  ///
  /// [communityChecks] is where the results of testing community links go.
  /// Null sends them nowhere. main.dart passes the app's reporter.
  ServerState({
    ServerRepository? repository,
    Duration fallbackWait = fallbackFetchWait,
    Duration refreshWait = fallbackRefreshWait,
    DateTime Function()? now,
    CommunityChecks? communityChecks,
    Bootstrap? bootstrap,
  }) : _repository = repository ?? ServerRepository(),
       _fallbackWait = fallbackWait,
       _refreshWait = refreshWait,
       _now = now ?? DateTime.now,
       _communityChecks = communityChecks,
       _bootstrap = bootstrap {
    bootstrap?.addListener(_takeFallbackFile);
  }

  final ServerRepository _repository;

  /// Whether [_communityFetchedAt] is the backend's clock (a fallback
  /// file's build time) rather than this phone's (a fetch or the saved
  /// copy).
  bool _communityTimeIsBackend = false;

  /// When the backend last sent a public list with links in this run.
  DateTime? _backendListAt;

  /// How long a list the backend sent stays ahead of the fallback file. It
  /// is ordered for this phone's carrier, and the file mixes carriers; past
  /// this, a newer file's links are the better bet for a phone that has been
  /// cut off since.
  static const backendListAheadFor = Duration(hours: 1);

  /// Whether [selectedServer] is a link from the fallback file that the
  /// app chose by itself, before ours or the backend's list were there.
  bool _selectedFromFile = false;

  /// The fallback file read from public hosts when the backend cannot be
  /// reached. Its links stand in for the public list while the backend's
  /// cannot be had (see [_takeFallbackFile]). Null takes nothing from it.
  /// main.dart passes Bootstrap.instance.
  final Bootstrap? _bootstrap;
  final PingService _pingService = PingService();
  final Duration _fallbackWait;
  final Duration _refreshWait;
  final DateTime Function() _now;
  final CommunityChecks? _communityChecks;

  /// How long a tap waits for the public list when it has no public link
  /// at all. Two of the API client's ten second tries: the phone's own
  /// network and the first other route. The wait starts with the tap and
  /// runs while the device's own doors are checked. When every one of
  /// them is closed, a list that arrives in this time is the only way
  /// left to connect.
  static const fallbackFetchWait = Duration(seconds: 20);

  /// How old the public list in memory may be before a tap fetches it
  /// again. The backend orders the list for the phone's carrier, links a
  /// phone on it got through most recently first, and works that order out
  /// again every five minutes. A list fetched when the app started can be
  /// hours old by the time every door of the device's own is closed.
  static const fallbackFreshFor = Duration(minutes: 5);

  /// How long a tap waits for that fetch, counted from the tap, when it
  /// already has a list to fall back on. The device's own doors are
  /// checked in that time, so the wait usually costs nothing. When the
  /// fetch does not arrive in time, the old list is used.
  static const fallbackRefreshWait = Duration(seconds: 6);

  /// The shared server the user picked by hand, stored by its link.
  ///
  /// Not by id: community ids are positional (`telegram-<index>` in
  /// [Server.fromConnectionUri]), so a refresh that reorders the list
  /// would restore a different server under the same id.
  static const prefChosenUri = 'fortiva_shared_server_uri';

  /// Whether the shared server stored under [prefChosenUri] was chosen by
  /// the connect fallback rather than by the user.
  static const prefChosenByFallback = 'fortiva_shared_server_by_fallback';

  List<Server> _communityServers = [];
  List<Server> _freeServers = [];
  List<Server> _premiumServers = [];
  Server? _selectedServer;
  bool _isChosen = false;
  bool _chosenByFallback = false;
  bool _isLoading = false;
  String? _errorMessage;

  bool _loadingCommunity = false;
  bool _communityLoadFailed = false;

  /// The load of the public list in flight, so a second caller waits for
  /// it instead of starting another.
  Future<void>? _communityLoad;

  /// The one read per run of the public list saved by an earlier run.
  Future<void>? _savedCommunityRead;

  /// Whether the public list in memory is the one an earlier run saved,
  /// and no fetch in this run has finished yet.
  ///
  /// A pick is not restored from that list. The backend may have dropped
  /// the link since, and a restored pick is dialled before the device's
  /// own doors on every tap. Once the fetch finishes, the list it leaves
  /// decides: the fresh one, or the saved one again when it failed.
  bool _communityFromSaved = false;

  /// When the backend sent the public list in memory. Null when it is not
  /// known.
  DateTime? _communityFetchedAt;

  // ── Ping State ──────────────────────────────────────────────────────────
  /// Latency results: serverId → ms (-1 = timeout)
  final Map<String, int> _pingResults = {};

  /// Server IDs currently being pinged
  final Set<String> _pingingServerIds = {};

  /// Server IDs queued and waiting to be pinged
  final Set<String> _queuedServerIds = {};

  /// Whether a bulk "Ping All" is in progress for specific tabs
  final Set<int> _pingingTabs = {};

  /// Progress tracking for bulk ping
  int _pingProgress = 0;
  int _pingTotal = 0;

  // ── Getters ─────────────────────────────────────────────────────────────
  List<Server> get communityServers => List.unmodifiable(_communityServers);
  List<Server> get freeServers => List.unmodifiable(_freeServers);
  List<Server> get premiumServers => List.unmodifiable(_premiumServers);

  /// Every shared server Fortiva runs itself, whatever tier it is tagged.
  ///
  /// Presented as one list because nothing in the app distinguishes them:
  /// `isPremium` draws a badge and gates nothing, and there is no way to
  /// buy anything. A separate "Premium" tab was therefore always empty,
  /// which reads as a paid tier that cannot be reached.
  List<Server> get officialServers =>
      List.unmodifiable([..._freeServers, ..._premiumServers]);

  Server? get selectedServer => _selectedServer;

  /// Whether [selectedServer] is a server the user picked off the shared
  /// list, rather than one this object fell back to on its own.
  ///
  /// The home screen reads this to decide which of the two selections
  /// wins. Without it a shared pick is invisible: this device's own
  /// servers are selected as soon as provisioning lands, so they would
  /// always take precedence and the picker would appear to do nothing.
  bool get isChosen => _isChosen && _selectedServer != null;

  /// Whether the shared server in use was chosen by the connect fallback,
  /// not picked by the user. The next tap then checks this device's own
  /// doors beside it first (ConnectFlow.connect, ownFirst).
  bool get chosenByFallback => isChosen && _chosenByFallback;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Whether a load of the public list is in flight.
  bool get isLoadingCommunity => _loadingCommunity;

  /// Whether the last load of the public list got no answer.
  ///
  /// [communityServers] then still holds the last list that did arrive,
  /// when there is one. With an empty list this is what tells "could not
  /// load" apart from an answer with no links in it.
  bool get communityLoadFailed => _communityLoadFailed;
  bool get hasServers =>
      _communityServers.isNotEmpty ||
      _freeServers.isNotEmpty ||
      _premiumServers.isNotEmpty;
  bool get isPingingAll => _pingingTabs.isNotEmpty;

  /// The server with the lowest positive latency across all categories
  Server? get fastestServer {
    Server? best;
    int bestLatency = 999999;
    for (final s in [
      ..._communityServers,
      ..._freeServers,
      ..._premiumServers,
    ]) {
      final lat = _pingResults[s.id];
      if (lat != null && lat > 0 && lat < bestLatency) {
        bestLatency = lat;
        best = s;
      }
    }
    return best;
  }

  /// Whether a specific tab is currently being pinged
  bool isPingingTab(int tabIndex) => _pingingTabs.contains(tabIndex);

  /// Get ping result for a server (-1 = timeout, null = not yet pinged)
  int? getPingResult(String serverId) => _pingResults[serverId];

  /// Whether a specific server is currently being pinged
  bool isPinging(String serverId) => _pingingServerIds.contains(serverId);

  /// Whether a specific server is queued for pinging
  bool isQueued(String serverId) => _queuedServerIds.contains(serverId);

  /// Ping progress: how many servers completed so far
  int get pingProgress => _pingProgress;

  /// Ping total: how many servers being pinged in this batch
  int get pingTotal => _pingTotal;

  /// Load servers from repository (official first, community in background)
  ///
  /// The public list saved by an earlier run goes on screen first, and the
  /// public list is fetched whatever happens to the official one: a phone
  /// whose calls to us are being dropped needs it most.
  Future<void> loadServers({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await _showSavedCommunity();
    _takeFallbackFile();

    try {
      // Load official servers FIRST — show them immediately
      final official = await _repository.getOfficialServers(
        forceRefresh: forceRefresh,
      );
      _freeServers = official.free;
      _premiumServers = official.premium;

      // Auto-select first server if none selected. A link the fallback
      // file stood in with gives way to ours, as it would have had the
      // file not been read first.
      if (_selectedServer == null || (_selectedFromFile && !_isChosen)) {
        final ours = _freeServers.isNotEmpty
            ? _freeServers.first
            : _premiumServers.firstOrNull;
        if (ours != null) {
          _selectedServer = ours;
          _selectedFromFile = false;
        }
      }

      _isLoading = false;
      notifyListeners();

      await _restoreChoice();
    } catch (e) {
      _errorMessage = 'Failed to load servers: $e';
      _isLoading = false;
      notifyListeners();
    } finally {
      // In the background, so the screen does not wait for it.
      unawaited(_loadCommunityServers(forceRefresh: forceRefresh));
    }
  }

  /// Fetch the public list again, after a load that failed.
  Future<void> retryCommunityServers() =>
      _loadCommunityServers(forceRefresh: true);

  /// The public list for the connect checklist, once every door of this
  /// device's own has failed.
  ///
  /// The list in memory when it has links. Otherwise the saved one, and
  /// when that is empty too, one fetch, given at most [wait] (by default
  /// the one this object was built with) so that a dead network cannot
  /// hold the checklist up. A fetch still running after the wait carries
  /// on and fills the list for the next tap.
  ///
  /// A list older than [fallbackFreshFor], in memory or saved, is fetched
  /// again, and the fetch is given at most the refresh wait this object
  /// was built with. When it does not arrive in that time, fails, or
  /// brings no links, the old list is what the checklist gets. The backend
  /// sends none when it cannot read its own list.
  ///
  /// [refresh] fetches the list again however new it is, for a tap that
  /// tries again after finding nothing open.
  Future<List<Server>> communityForFallback({
    Duration? wait,
    bool refresh = false,
  }) async {
    if (communityServers.isEmpty) await _showSavedCommunity();
    final old = communityServers;
    if (old.isNotEmpty && _communityFresh && !refresh) return old;
    final limit = old.isEmpty ? (wait ?? _fallbackWait) : _refreshWait;
    try {
      await _loadCommunityServers(forceRefresh: true).timeout(limit);
    } on TimeoutException {
      debugPrint('ServerState: no public list after ${limit.inSeconds} s');
    }
    return communityServers.isEmpty ? old : communityServers;
  }

  /// Whether the public list in memory came from the backend less than
  /// [fallbackFreshFor] ago.
  bool get _communityFresh {
    final at = _communityFetchedAt;
    return at != null && _now().difference(at) < fallbackFreshFor;
  }

  /// Show the public list an earlier run saved, while the list in memory
  /// is empty. Read once per run: after that, the list in memory is at
  /// least as new.
  Future<void> _showSavedCommunity() =>
      _savedCommunityRead ??= _readSavedCommunity();

  Future<void> _readSavedCommunity() async {
    if (_communityServers.isNotEmpty) return;
    final saved = await _repository.savedCommunityServers();
    if (saved == null || saved.servers.isEmpty) return;
    // A fetch that landed during the read is newer.
    if (_communityServers.isNotEmpty) return;
    _communityServers = saved.servers;
    _communityFetchedAt = saved.fetchedAt;
    _communityTimeIsBackend = false;
    _communityFromSaved = true;
    notifyListeners();
  }

  /// Load community servers independently (non-blocking)
  Future<void> _loadCommunityServers({bool forceRefresh = false}) =>
      _communityLoad ??= _fetchCommunityServers(
        forceRefresh,
      ).whenComplete(() => _communityLoad = null);

  Future<void> _fetchCommunityServers(bool forceRefresh) async {
    _loadingCommunity = true;
    notifyListeners();
    try {
      final result = await _repository.getCommunityServers(
        forceRefresh: forceRefresh,
      );
      _communityFromSaved = false;
      _communityLoadFailed = result.failed;
      if (!result.failed && result.servers.isNotEmpty) {
        _backendListAt = _now();
      }
      // A failed load with nothing kept leaves whatever is on screen.
      if (!result.failed || result.servers.isNotEmpty) {
        final before = {
          for (final s in _communityServers) s.id: s.connectionUri,
        };
        _communityServers = result.servers;
        _communityFetchedAt = result.fetchedAt;
        _communityTimeIsBackend = false;
        // Community ids are positional, so a refreshed list can put another
        // link under an id that has a reading. Drop those readings, or the
        // list and the connect fallback credit one link with another's ping.
        for (final s in _communityServers) {
          if (before[s.id] != s.connectionUri) _pingResults.remove(s.id);
        }
      }

      // Auto-select community server only if still nothing selected. A
      // link from the fallback file that stood in gives way to the
      // backend's list once it arrives.
      final fromBackend = _backendListAt != null
          ? (officialServers.firstOrNull ?? _communityServers.firstOrNull)
          : null;
      if (fromBackend != null &&
          (_selectedServer == null || (_selectedFromFile && !_isChosen))) {
        _selectedServer = fromBackend;
        _selectedFromFile = false;
      } else if (_selectedServer == null && _communityServers.isNotEmpty) {
        _selectedServer = _communityServers.first;
      }

      _loadingCommunity = false;
      notifyListeners();
      await _restoreChoice();
    } catch (e) {
      _communityFromSaved = false;
      debugPrint('ServerState: could not load the public list ($e)');
    } finally {
      if (_loadingCommunity) {
        _loadingCommunity = false;
        notifyListeners();
      }
    }
    // A fetch that failed put the saved list back, which may be older than
    // a file read meanwhile.
    if (_communityLoadFailed) _takeFallbackFile();
  }

  /// Put the fallback file's links on the public list, when the backend's
  /// list cannot be had and the file is newer than what is shown.
  ///
  /// A phone whose calls to us are cut gets no public list, and on a new
  /// install nothing at all to dial. The file is read from public hosts
  /// when that happens (Bootstrap), and its links are the ones phones in
  /// Iran got through lately. A list the backend sent in this run is
  /// fresher than any file, and stays.
  void _takeFallbackFile() {
    final file = _bootstrap?.file;
    if (file == null || file.links.isEmpty) return;
    // A list the backend sent lately is ordered for this phone's carrier,
    // even after a later fetch failed. The file's mixes carriers.
    // Only once its fetch has failed since: a phone whose fetches work
    // keeps the backend's list however old the last one is.
    final sent = _backendListAt;
    if (sent != null &&
        (!_communityLoadFailed ||
            _now().difference(sent) < backendListAheadFor)) {
      return;
    }
    // The list's time is this phone's clock and the file's the backend's:
    // compared on the backend's.
    final at = _communityFetchedAt;
    final atOnBackend = at == null || _communityTimeIsBackend
        ? at
        : at.add(ServerClock.offset);
    if (_communityServers.isNotEmpty &&
        atOnBackend != null &&
        !file.issuedAt.isAfter(atOnBackend)) {
      return;
    }
    final servers = ServerRepository.parseLinks(file.links);
    if (servers.isEmpty) return;
    final before = {for (final s in _communityServers) s.id: s.connectionUri};
    _communityServers = servers;
    _communityFetchedAt = file.issuedAt;
    _communityTimeIsBackend = true;
    // Like a saved list: a pick is not restored from it, because a pick
    // restored is dialled first on every tap.
    _communityFromSaved = true;
    for (final s in servers) {
      if (before[s.id] != s.connectionUri) _pingResults.remove(s.id);
    }
    // Ours go first once they load, and the backend's list once it arrives
    // (see loadServers and _fetchCommunityServers).
    if (_selectedServer == null) {
      _selectedServer = servers.first;
      _selectedFromFile = true;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _bootstrap?.removeListener(_takeFallbackFile);
    super.dispose();
  }

  /// Refresh servers from API
  Future<void> refreshServers() async {
    await loadServers(forceRefresh: true);
  }

  /// Make [server] the one the app connects through.
  ///
  /// Recorded as the user's own choice, so the home screen uses it in
  /// place of this device's provisioned server. Someone opens the shared
  /// list because our servers are not working for them, and putting them
  /// back on ours is the one thing the picker must not do.
  ///
  /// [byFallback] when the connect fallback chose it: the user did not,
  /// and a tap may put them back on ours when ours works again.
  void selectServer(Server server, {bool byFallback = false}) {
    _selectedServer = server;
    _selectedFromFile = false;
    _isChosen = true;
    _chosenByFallback = byFallback;
    notifyListeners();
    _persistChoice(server.connectionUri, byFallback: byFallback);
  }

  /// Give up the shared server the user picked, and go back to letting
  /// this device's own server win.
  ///
  /// Called when the user picks one of their own servers instead. The
  /// selection itself is left alone, because it is still the fallback for
  /// a device whose provisioning has not landed.
  void clearChoice() {
    if (!_isChosen) return;
    _isChosen = false;
    _chosenByFallback = false;
    notifyListeners();
    _persistChoice(null);
  }

  /// Re-adopt the shared server the user last picked, if it is still on
  /// one of the lists.
  ///
  /// Matched on the link rather than the id, and skipped once a choice is
  /// live so that a background refresh cannot pull the user off a server
  /// they picked a moment ago. The saved public list counts only once
  /// this run's fetch has failed; see [_communityFromSaved].
  Future<void> _restoreChoice() async {
    if (_isChosen) return;
    final uri = await _storedChoiceUri();
    if (uri == null || _isChosen) return;

    for (final s in [
      if (!_communityFromSaved) ..._communityServers,
      ..._freeServers,
      ..._premiumServers,
    ]) {
      if (s.connectionUri != uri) continue;
      _selectedServer = s;
      _isChosen = true;
      _chosenByFallback = await _storedByFallback();
      notifyListeners();
      return;
    }
  }

  Future<bool> _storedByFallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(prefChosenByFallback) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _storedChoiceUri() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(prefChosenUri);
    } catch (_) {
      return null;
    }
  }

  /// The chain of writes to [prefChosenUri], so that two quick picks
  /// land in the order they were made rather than racing each other.
  /// Exposed so a test can wait for the write it just triggered.
  @visibleForTesting
  Future<void> choiceWritten = Future<void>.value();

  /// Not awaited by the caller: failing to write the choice costs the
  /// next launch its starting server, which is not worth blocking the
  /// move on.
  void _persistChoice(String? uri, {bool byFallback = false}) {
    choiceWritten = choiceWritten.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (uri == null) {
          await prefs.remove(prefChosenUri);
          await prefs.remove(prefChosenByFallback);
        } else {
          await prefs.setString(prefChosenUri, uri);
          await prefs.setBool(prefChosenByFallback, byFallback);
        }
      } catch (_) {
        // The choice still holds for this run; only the next launch
        // loses it.
      }
    });
  }

  /// Get optimal server
  Future<void> selectOptimalServer() async {
    try {
      _selectedServer = await _repository.getOptimalServer();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to find optimal server: $e';
      notifyListeners();
    }
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Ping Operations ─────────────────────────────────────────────────────

  /// Ping a single server and update state
  Future<void> pingServer(Server server) async {
    _pingingServerIds.add(server.id);
    notifyListeners();

    try {
      final started = DateTime.now();
      final latency = await _pingService.pingServer(server);
      _pingResults[server.id] = latency;
      _reportPings([(server, latency, DateTime.now().difference(started))]);

      // Also update the cached server object's latencyMs
      if (latency > 0) {
        _repository.updateServerLatency(server.id, latency);
      }
    } finally {
      _pingingServerIds.remove(server.id);
      notifyListeners();
    }
  }

  /// Ping a specific list of servers (the active tab's servers)
  Future<void> pingServers(
    List<Server> servers, {
    required int tabIndex,
  }) async {
    if (_pingingTabs.contains(tabIndex)) return; // This tab is already pinging

    _pingingTabs.add(tabIndex);
    _pingProgress = 0;
    _pingTotal = servers.length;
    final byId = {for (final s in servers) s.id: s};
    final started = <String, DateTime>{};
    final done = <(Server, int, Duration)>[];
    // Clear only the results for the servers being pinged
    // and mark them all as queued so the UI shows a waiting state
    for (final s in servers) {
      _pingResults.remove(s.id);
      _queuedServerIds.add(s.id);
    }
    notifyListeners();

    try {
      // Results are collected through onResult as each ping lands, so the
      // returned record adds nothing here.
      await _pingService.pingAllServers(
        servers,
        onBeforePing: (serverId) {
          started[serverId] = DateTime.now();
          _queuedServerIds.remove(serverId);
          _pingingServerIds.add(serverId);
          notifyListeners();
        },
        onResult: (serverId, latencyMs) {
          final server = byId[serverId];
          final from = started[serverId];
          if (server != null && from != null) {
            done.add((server, latencyMs, DateTime.now().difference(from)));
          }
          _pingResults[serverId] = latencyMs;
          _pingingServerIds.remove(serverId);
          _pingProgress++;
          if (latencyMs > 0) {
            _repository.updateServerLatency(serverId, latencyMs);
          }
          notifyListeners();
        },
      );

      // Ping cancelled — results so far are kept
    } finally {
      // Clean up any remaining state for THIS tab's servers
      for (final s in servers) {
        _pingingServerIds.remove(s.id);
        _queuedServerIds.remove(s.id);
      }
      _pingingTabs.remove(tabIndex);
      notifyListeners();
      // What a stopped run tested is reported too: each result is a test
      // that ran to its end.
      _reportPings(done);
    }
  }

  /// Send the tests of community links among [pings] to the backend: the
  /// link, its result, and how long the test took. A link the native test
  /// was never asked about ([PingService.canTest]) is not a test.
  void _reportPings(List<(Server, int, Duration)> pings) {
    final reporter = _communityChecks;
    if (reporter == null) return;
    final at = DateTime.now();
    final checks = [
      for (final (server, ms, took) in pings)
        if (server.isCommunity && PingService.canTest(server.connectionUri))
          CommunityCheck(
            link: server.connectionUri,
            kind: CommunityCheckKind.ping,
            // As the list reads it: no latency is a failed test.
            ok: ms > 0,
            at: at,
            ms: ms > 0 ? ms : took.inMilliseconds,
          ),
    ];
    unawaited(reporter.report(checks));
  }

  /// Cancel the current ping operation for a specific tab
  /// Immediately clears all visual state so the UI updates right away
  void cancelPing({required int tabIndex}) {
    _pingService.cancelAll();
    // Immediately clear pinging/queued state — don't wait for the in-flight ping
    _pingingServerIds.clear();
    _queuedServerIds.clear();
    _pingingTabs.remove(tabIndex);
    _pingProgress = 0;
    _pingTotal = 0;
    notifyListeners();
  }

  /// Clear all ping results
  void clearPingResults() {
    _pingResults.clear();
    _pingingServerIds.clear();
    _pingingTabs.clear();
    notifyListeners();
  }
}
