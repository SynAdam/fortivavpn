import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_client.dart';
import '../../api/config_service.dart';
import '../../api/device_service.dart';
import '../../api/server_clock.dart';
import '../../data/models/door_outbound.dart';
import '../../data/models/psiphon_settings.dart';
import '../../data/models/server.dart';
import '../../data/models/variant_test.dart';
import '../../services/ping_service.dart';
import '../../utils/tls_fragment.dart';
import '../../utils/vless_link.dart';

/// This device's own servers, and the quota they are metered against.
///
/// These are not the community or official lists. Those are shared links,
/// handed out to whoever asks for them; this is a set provisioned for this
/// install alone, one client per reachable server, and it is what the app
/// connects through. The shared lists are the fallback for the case where
/// provisioning has not finished. They are not a fallback for a spent
/// allowance: the shared links are unmetered, so the home screen withholds
/// them while [isBlocked] is set.
///
/// Nothing here needs an account. Provisioning is keyed on the device id,
/// so a fresh install has its own servers before it has a user.
class DedicatedState extends ChangeNotifier {
  DedicatedState({
    Future<SharedPreferences> Function()? prefs,
    DateTime Function()? now,
    @visibleForTesting
    Future<DedicatedConfigs> Function({bool? viaTunnel})? fetch,
  }) : _prefs = prefs ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now,
       _fetch = fetch;

  final DeviceService _deviceService = DeviceService();
  final PingService _pingService = PingService();
  final Future<SharedPreferences> Function() _prefs;
  final DateTime Function() _now;
  final Future<DedicatedConfigs> Function({bool? viaTunnel})? _fetch;

  /// The backend's last answer, and when it came, kept for a launch that
  /// cannot reach the backend.
  ///
  /// Until 2026-10-11 this device's servers lived in memory only, so every
  /// launch had to fetch them, and a launch on a network that cuts our
  /// calls had none: the Connect button had only shared links behind it,
  /// or nothing. The servers themselves were fine; it was the call to us
  /// that failed. In the week before, 24 of 487 new phones in Iran never
  /// got their servers at all.
  static const prefSaved = 'fortiva_dedicated_saved';

  /// How old a kept answer may be and still be used. Older, the servers in
  /// it have probably moved, and the shared links do better.
  static const savedMaxAge = Duration(days: 30);

  /// Survives relaunches so the app comes back on the server the user left
  /// it on, rather than silently moving them to whichever one the backend
  /// happens to list first.
  static const _prefSelectedId = 'fortiva_dedicated_server_id';

  /// Whether the server under [_prefSelectedId] is one the user picked.
  /// See [selectedByUser].
  static const _prefSelectedByUser = 'fortiva_dedicated_server_by_user';

  List<String> _configs = [];
  List<Server> _servers = [];
  List<Server> _paths = [];
  Server? _selectedServer;
  bool _byUser = false;
  QuotaStatus? _quota;
  bool _isLoading = false;
  String? _errorMessage;
  TestPointConfig? _testPoint;
  DoorPairCheck? _doorPair;
  List<VariantTest> _variantTests = const [];
  VariantTestParams? _variantTestParams;
  bool? _psiphon;

  final Map<String, int> _pingResults = {};
  final Set<String> _pinging = {};
  bool _isPingingAll = false;

  List<String> get configs => List.unmodifiable(_configs);

  /// This device's servers, in the order the backend returned them.
  List<Server> get servers => List.unmodifiable(_servers);

  /// Every door of every server, in the order the backend says to try
  /// them for the network the last refresh came from. This is what the
  /// connect button walks; [servers] is what the servers screen shows.
  /// Falls back to one path per server, with no door, on a backend that
  /// predates doors.
  List<Server> get paths => List.unmodifiable(_paths);

  /// The one the app connects through, or null before provisioning lands.
  Server? get selectedServer => _selectedServer;

  /// Whether [selectedServer] is one the user picked: on the servers
  /// screen, or from the error bar's offer of it. False for the backend's
  /// first server, and for one the connect flow moved the selection to
  /// because a tap landed there.
  ///
  /// Only a picked server has its doors tried first (dialServer). The
  /// others keep the backend's door order, which puts the doors that work
  /// on the phone's carrier first. Up to 1.7.0 every server the flow moved
  /// to was kept like a pick, and every later tap checked all of its doors
  /// before any other server's, even when that server's IPv4 addresses
  /// rarely passed on the phone's carrier and another server's mostly did.
  /// Some of those taps failed.
  bool get selectedByUser => _byUser && _selectedServer != null;

  /// A spent allowance that has refilled by its reset time while the
  /// backend could not be asked reads as refilled: nothing used, nothing
  /// blocked (see [_refilled]).
  QuotaStatus? get quota {
    final quota = _quota;
    if (quota == null || !_refilled) return quota;
    return QuotaStatus(
      unlimited: quota.unlimited,
      limitBytes: quota.limitBytes,
      usedBytes: 0,
      remainingBytes: quota.limitBytes,
      blocked: false,
      bonusBytes: quota.bonusBytes,
    );
  }

  /// Set when the backend says this phone is a test point.
  TestPointConfig? get testPoint => _testPoint;

  /// Set while this phone's carrier has a paired door test. Only from a
  /// fresh answer: a kept one may name a test that has ended.
  DoorPairCheck? get doorPair => _doorPair;

  /// Variants of this device's doors to check in the background, from the
  /// last fresh answer (VariantTester). Never from a kept answer, whose
  /// tests are past their deadline or already tried. Empty while the
  /// backend's variant tests are off.
  List<VariantTest> get variantTests => _variantTests;

  /// How [variantTests] are run, from the same answer. Null when it said
  /// nothing usable, which runs none.
  VariantTestParams? get variantTestParams => _variantTestParams;

  /// Bumped by [forgetAccount] and [reset]. Anything read from this state
  /// before the number changed belongs to an account whose deletion has
  /// started since.
  int get generation => _generation;

  /// Whether the backend lets this device use the backup network, from the
  /// last /configs/dedicated answer that said, in this run or kept from an
  /// earlier one. Null when no answer has said yet. See PsiphonSettings.
  bool? get psiphon => _psiphon;

  /// What the connect flow reads before it dials the backup network.
  PsiphonDevice get psiphonDevice => PsiphonDevice(
    allowed: _psiphon,
    blocked: isBlocked,
    quota: quota,
    quotaFresh: _quotaFresh,
  );

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Whether the last refresh got no answer from the backend. A tunnel
  /// that comes up after one is a new way to ask.
  bool get lastRefreshFailed => _lastRefreshFailed;
  bool _lastRefreshFailed = false;

  /// Whether the last refresh ended without an answer to read the
  /// allowance from: no answer, as [lastRefreshFailed], or one with an
  /// error status. The connect flow asks again after one (askAllowance).
  bool get lastRefreshErred => _lastRefreshErred;
  bool _lastRefreshErred = false;

  /// Whether the servers in memory are the ones an earlier run kept, and
  /// no refresh in this run has replaced them yet.
  bool get fromSaved => _fromSaved;
  bool _fromSaved = false;

  Future<void>? _restoring;

  /// Whether the allowance in memory is the backend's answer to the last
  /// refresh. False for a kept one and after any refresh that did not get
  /// an answer with configs, whatever its status: a 502 at the reset time
  /// must not hold a spent allowance in force.
  bool _quotaFresh = false;

  /// Set by [forgetAccount] until [reset] or [keepAccount]: no answer is
  /// taken up or kept on the phone while an account deletion runs.
  bool _forgetting = false;

  /// Bumped by [reset]. An answer that arrives for an earlier generation
  /// belongs to an account that was deleted meanwhile, and is dropped.
  int _generation = 0;

  bool get hasConfigs => _configs.isNotEmpty;

  /// Whether the device has servers of its own to connect through.
  bool get hasServers => _servers.isNotEmpty;

  /// True when the server withheld configs because the window is spent.
  ///
  /// The server returns an empty list in that case rather than links plus
  /// a flag, so that a client which ignored the flag could not keep using
  /// credentials it is no longer entitled to.
  ///
  bool get isBlocked => quota?.blocked ?? false;

  /// Whether the spent allowance in memory has refilled by its reset time,
  /// when the backend could not be asked since.
  ///
  /// Only for an answer kept from an earlier run, or after a refresh that
  /// failed: a phone whose network cuts our calls would otherwise hold back
  /// every link until restarted. A fresh answer from the backend decides by
  /// itself, whatever this phone's clock says, so setting the clock ahead
  /// does not end a block. Compared on the backend's clock when an answer
  /// in this run has given it (ServerClock).
  bool get _refilled {
    final quota = _quota;
    if (quota == null || !quota.blocked) return false;
    if (_quotaFresh) return false;
    final resets = quota.resetsAt;
    return resets != null && !resets.isAfter(ServerClock.notBefore(_now()));
  }

  /// Latency in ms for one of this device's servers, -1 for a timeout,
  /// null when it has not been measured yet.
  int? pingFor(String serverId) => _pingResults[serverId];

  bool isPinging(String serverId) => _pinging.contains(serverId);

  bool get isPingingAll => _isPingingAll;

  /// Fetch (and on first call, provision) this device's servers.
  ///
  /// Safe on every launch — the endpoint is idempotent. [viaTunnel] says
  /// whether the request leaves through the tunnel; the backend orders
  /// the doors for the network it came from only when it did not.
  ///
  /// A call made while one is in flight waits for that one. The connect
  /// button asks for these servers before it falls back to a shared link,
  /// and returning at once would send it to that link a second before
  /// the answer arrived.
  Future<void> refresh({bool? viaTunnel}) => _refreshing ??= _refresh(
    viaTunnel,
  ).whenComplete(() => _refreshing = null);

  Future<void>? _refreshing;

  Future<void> _refresh(bool? viaTunnel) async {
    // While an account deletion runs, no request goes out: one for the old
    // device id would get a 404, register it again and provision servers
    // for it that this phone could never name or delete.
    if (_forgetting) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // The kept answer first, so the servers are there while the fetch runs
    // and stay there if it fails.
    await restoreSaved();
    final generation = _generation;
    try {
      final fetch = _fetch;
      final result = fetch != null
          ? await fetch(viaTunnel: viaTunnel)
          : await _fetchProvisioning(
              await _deviceService.getDeviceId(),
              viaTunnel: viaTunnel,
            );
      // The account was deleted while this was on its way.
      if (generation != _generation || _forgetting) return;
      _quota = result.quota;
      _testPoint = result.testPoint;
      _doorPair = result.doorPair;
      _variantTests = result.variantTests;
      _variantTestParams = result.variantTestParams;
      // An answer from a backend older than the field keeps what an
      // earlier answer said. So does an answer with the allowance spent:
      // the backend says no to every blocked device, and that no would
      // outlast the block on a phone that cannot ask again once the
      // allowance refills. The block keeps the network off meanwhile
      // (isBlocked).
      if (!result.quota.blocked) _psiphon = result.psiphon ?? _psiphon;
      await _adoptConfigs(result.configs, result.paths);
      if (generation != _generation) return;
      _adoptPaths(result.paths);
      _fromSaved = false;
      _lastRefreshFailed = false;
      _lastRefreshErred = false;
      _quotaFresh = true;
      _watchRefill();
      unawaited(_save(result, generation, psiphon: _psiphon));
    } on ApiException catch (e) {
      _quotaFresh = false;
      _errorMessage = e.message;
      // An answer of any status came from the backend: it was reached.
      _lastRefreshFailed = e.statusCode == 0;
      _lastRefreshErred = true;
    } catch (e) {
      _quotaFresh = false;
      _errorMessage = 'Could not load your servers. Check your connection.';
      _lastRefreshFailed = true;
      _lastRefreshErred = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Show the servers an earlier run kept, while none are in memory. Once
  /// per run; [refresh] runs it first.
  Future<void> restoreSaved() => _restoring ??= _restoreSaved();

  Future<void> _restoreSaved() async {
    if (_servers.isNotEmpty || _quota != null) return;
    final generation = _generation;
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(prefSaved);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final at = DateTime.tryParse('${decoded['at']}');
      final body = decoded['body'];
      if (at == null || body is! Map) return;
      if (_now().difference(at) > savedMaxAge) return;
      final saved = DedicatedConfigs.fromJson(body.cast<String, dynamic>());
      // Read before the checks below, which can set the rest of the answer
      // aside: whether this device may use the backup network does not
      // depend on its allowance. A kept answer carries what the last
      // answer without a spent allowance said (_save). A fresh answer that
      // came meanwhile wins.
      if (generation == _generation) _psiphon ??= saved.psiphon;
      // A spent allowance whose refill time has passed is no longer true,
      // and it would hold the shared links back from a phone that cannot
      // ask again.
      final resets = saved.quota.resetsAt;
      if (saved.quota.blocked && (resets == null || resets.isBefore(_now()))) {
        return;
      }
      // Something newer arrived during the read, or the account is gone.
      if (_servers.isNotEmpty || _quota != null) return;
      if (generation != _generation) return;
      _quota = saved.quota;
      await _adoptConfigs(saved.configs, saved.paths);
      if (generation != _generation) return;
      _adoptPaths(saved.paths);
      _fromSaved = true;
      _watchRefill();
      notifyListeners();
    } catch (e) {
      debugPrint('DedicatedState: could not read the kept servers ($e)');
    }
  }

  /// Keep [result] for a launch that cannot reach the backend, with
  /// [psiphon], the backup network's answer as this phone holds it, in
  /// place of the one the answer carried ([_refresh]).
  Future<void> _save(
    DedicatedConfigs result,
    int generation, {
    bool? psiphon,
  }) async {
    final raw = result.raw;
    if (raw == null) return;
    // Variant tests are not kept: each is checked once, from the answer
    // that handed it out. The doors' own outbounds are kept with the doors.
    // The google block is not kept either. The backend still sends it for
    // old builds, and this build reads nothing from it.
    final body = {...raw}
      ..remove('psiphon')
      ..remove('variant_tests')
      ..remove('variant_test_params')
      ..remove('google');
    if (psiphon != null) body['psiphon'] = psiphon;
    try {
      final prefs = await _prefs();
      // The account was deleted while this was on its way.
      if (generation != _generation || _forgetting) return;
      await prefs.setString(
        prefSaved,
        jsonEncode({'at': _now().toUtc().toIso8601String(), 'body': body}),
      );
    } catch (e) {
      debugPrint('DedicatedState: could not keep the servers ($e)');
    }
  }

  /// Ask for the device's configs, registering it first if the backend has
  /// never seen it.
  ///
  /// The provisioning endpoint 404s for an unregistered device, and
  /// registration is fired at launch without being awaited, so on a first
  /// run this call can and does arrive first. That used to cost only the
  /// quota line; now it costs the app the servers it connects through, so
  /// the 404 is recovered from rather than reported.
  Future<DedicatedConfigs> _fetchProvisioning(
    String deviceId, {
    bool? viaTunnel,
  }) async {
    final generation = _generation;
    try {
      return await ConfigService().getDedicatedConfigs(
        deviceId,
        viaTunnel: viaTunnel,
      );
    } on ApiException catch (e) {
      if (!e.isNotFound) rethrow;
      // The 404 may be the account deletion that started meanwhile: never
      // register a device that is being deleted, or servers would be
      // provisioned for an id nobody can name or delete again.
      if (_forgetting || generation != _generation) rethrow;
      await _deviceService.registerDevice();
      return ConfigService().getDedicatedConfigs(
        deviceId,
        viaTunnel: viaTunnel,
      );
    }
  }

  /// What a refresh does with the backend's answer, for tests that have
  /// no backend.
  @visibleForTesting
  Future<void> adoptForTest(
    List<String> configs,
    List<DedicatedPath> paths,
  ) async {
    await _adoptConfigs(configs, paths);
    _adoptPaths(paths);
  }

  void _adoptPaths(List<DedicatedPath> paths) {
    TlsFragment.doorSpec = _doorSplit(paths);
    DoorOutbounds.adopt({
      for (final p in paths)
        if (p.outbound != null && p.uri.isNotEmpty) p.uri: p.outbound!,
    });
    if (paths.isEmpty) {
      // A backend without doors: each server's one link is its one path.
      _paths = List.of(_servers);
      return;
    }
    _paths = [
      for (var i = 0; i < paths.length; i++)
        Server.fromDedicatedPath(
          uri: paths[i].uri,
          door: paths[i].door,
          doorLabel: paths[i].label,
          serverId: paths[i].serverId,
          penaltyMs: paths[i].penaltyMs,
          index: i,
        ),
    ];
  }

  /// The split the backend wrote into this phone's TLS door links, when
  /// the core can use it; null otherwise. See [TlsFragment.doorSpec].
  ///
  /// A door named `...-tls` is one the backend writes its splits into
  /// (is_tls_door in door_experiments.py), and it writes the same value
  /// into all of them. `off` and the ech and ff arms (which carry
  /// `fragment=off`) give null: those links dial through no splitter, so
  /// the tests keep the app's split.
  static String? _doorSplit(List<DedicatedPath> paths) {
    for (final p in paths) {
      if (!p.door.endsWith('-tls')) continue;
      final value = VlessLink.param(p.uri, 'fragment');
      if (value == null) continue;
      return TlsFragment.usable(value) ? value.trim() : null;
    }
    return null;
  }

  /// [paths] lend each server its backend id. A server's link is its first
  /// door's link, so the path with the same link is that server. With the
  /// id, the server the user chose is known to be the same server as any
  /// of its doors, whatever address each one is dialled at.
  Future<void> _adoptConfigs(
    List<String> configs, [
    List<DedicatedPath> paths = const [],
  ]) async {
    _configs = configs;
    final ids = {
      for (final p in paths)
        if (p.serverId > 0 && p.uri.isNotEmpty) p.uri: p.serverId,
    };
    _servers = [
      for (var i = 0; i < configs.length; i++)
        Server.fromDedicatedUri(
          configs[i],
          index: i,
        ).copyWith(serverId: ids[configs[i]]),
    ];

    // A server that has dropped off the fleet must not leave its latency
    // behind, or the list shows a reading for something that is gone.
    final live = _servers.map((s) => s.id).toSet();
    _pingResults.removeWhere((id, _) => !live.contains(id));

    if (_servers.isEmpty) {
      _selectedServer = null;
      _byUser = false;
      return;
    }

    final stored = _selectedServer == null ? await _storedSelection() : null;
    // A selection made while storage was read wins over what it held.
    final current = _selectedServer;
    if (current == null) _byUser = _storedIsPick(stored);
    final wanted = current?.id ?? stored?.id;
    final kept = _servers.where((s) => s.id == wanted).firstOrNull;
    // A picked server the backend no longer lists is not a pick any more.
    if (kept == null) _byUser = false;
    _selectedServer = kept ?? _servers.first;
  }

  /// The selection an earlier run saved. Its by-user flag is null when the
  /// run was 1.7.0 or older, which saved no flag.
  Future<({String? id, bool? byUser})?> _storedSelection() async {
    try {
      final prefs = await _prefs();
      return (
        id: prefs.getString(_prefSelectedId),
        byUser: prefs.getBool(_prefSelectedByUser),
      );
    } catch (_) {
      return null;
    }
  }

  /// Whether the selection an earlier run saved was the user's pick.
  ///
  /// A selection saved by 1.7.0 or older has no flag. Those builds saved
  /// every server the connect flow moved to under the same key as a pick,
  /// so it counts as not picked: its doors keep the backend's order, and
  /// the door remembered for the network still goes first.
  ///
  /// On a device with Premium it counts as a pick, because a paying user
  /// must never be moved off a Premium server they chose. The phone cannot
  /// tell which of its servers are Premium ones: /configs/dedicated sends
  /// no tier, [Server.isPremium] is read only off the Official list, which
  /// leaves Premium servers out, and the locked list names them only to a
  /// device without Premium. So every old selection of a device with
  /// Premium stays a pick. The backend reports the allowance as unlimited
  /// only for such a device.
  /// [_quota] is already the answer being adopted: [_refresh] and
  /// [_restoreSaved] set it before they call [_adoptConfigs].
  bool _storedIsPick(({String? id, bool? byUser})? stored) {
    if (stored == null || stored.id == null) return false;
    return stored.byUser ?? (_quota?.unlimited ?? false);
  }

  /// Move this device onto one of its other servers.
  ///
  /// [server] can be one of a server's doors rather than its entry in
  /// [servers]: the connect flow follows the core onto another server's
  /// door. The entry for that server is what gets selected. A door's id
  /// matched no entry, so the servers screen marked no server, or the
  /// first one after a refresh, while the traffic went through another.
  ///
  /// [byUser] is false when the connect flow moved the selection because a
  /// tap landed on, or the core moved to, a door of [server]. The user did
  /// not pick it, and the next tap keeps the backend's door order instead
  /// of trying its doors first (see [selectedByUser]). A server the user
  /// picked stays picked until a tap lands on another one.
  void select(Server server, {bool byUser = true}) {
    if (!server.isDedicated) return;
    final entry =
        _servers.where((s) => s.sameServerAs(server)).firstOrNull ?? server;
    _selectedServer = entry;
    _byUser = byUser;
    notifyListeners();
    _persistSelection(entry.id, byUser: byUser);
  }

  /// The chain of writes of the selection, so that two quick moves land in
  /// the order they were made. Exposed so a test can wait for the write it
  /// just triggered.
  @visibleForTesting
  Future<void> selectionWritten = Future<void>.value();

  /// Not awaited by the caller: failing to persist the choice costs the
  /// next launch its starting server, which is not worth blocking the move
  /// on.
  void _persistSelection(String id, {required bool byUser}) {
    selectionWritten = selectionWritten.then((_) async {
      try {
        final prefs = await _prefs();
        await prefs.setString(_prefSelectedId, id);
        await prefs.setBool(_prefSelectedByUser, byUser);
      } catch (_) {
        // The selection still holds for this run.
      }
    });
  }

  /// Measure one server's latency through the tunnel core.
  Future<void> pingServer(Server server) async {
    if (_pinging.contains(server.id)) return;
    _pinging.add(server.id);
    notifyListeners();
    try {
      _pingResults[server.id] = await _pingService.pingServer(server);
    } finally {
      _pinging.remove(server.id);
      notifyListeners();
    }
  }

  /// Measure every one of this device's servers, one at a time.
  ///
  /// One at a time. [PingService.pingAllServers] says why.
  Future<void> pingAll() async {
    if (_isPingingAll || _servers.isEmpty) return;
    _isPingingAll = true;
    notifyListeners();
    try {
      await _pingService.pingAllServers(
        _servers,
        onBeforePing: (id) {
          _pinging.add(id);
          notifyListeners();
        },
        onResult: (id, latencyMs) {
          _pinging.remove(id);
          _pingResults[id] = latencyMs;
          notifyListeners();
        },
      );
    } finally {
      _pinging.clear();
      _isPingingAll = false;
      notifyListeners();
    }
  }

  /// Take the allowance another answer carried, such as a redeemed key or
  /// a confirmed purchase, so the quota card shows it at once instead of
  /// after the next refresh. Callers refresh as well, because a device
  /// whose allowance was spent has no servers until the next fetch.
  void adoptQuota(QuotaStatus quota) {
    _quota = quota;
    _watchRefill();
    notifyListeners();
  }

  /// Wake the screens at the reset time of a spent allowance, so the button
  /// and the cards follow it without waiting for something else to change,
  /// and ask the backend again then.
  Timer? _refillTimer;

  void _watchRefill() {
    _refillTimer?.cancel();
    _refillTimer = null;
    final quota = _quota;
    final resets = quota?.resetsAt;
    if (quota == null || !quota.blocked || resets == null) return;
    final wait = resets.difference(ServerClock.notBefore(_now()));
    if (wait.isNegative) return;
    _refillTimer = Timer(wait + const Duration(seconds: 1), () {
      _refillTimer = null;
      notifyListeners();
      unawaited(refresh());
    });
  }

  /// Drop any answer still on its way, before an account deletion starts
  /// clearing what this phone keeps. [reset] does the rest afterwards.
  void forgetAccount() {
    _generation++;
    _forgetting = true;
    _refillTimer?.cancel();
    _refillTimer = null;
  }

  /// The deletion [forgetAccount] was for did not happen: answers count
  /// again.
  void keepAccount() {
    _forgetting = false;
    // forgetAccount stopped the refill timer, and refreshes asked for
    // during the deletion went nowhere. One refresh covers both, and a
    // reset time that passed meanwhile.
    _watchRefill();
    notifyListeners();
    unawaited(refresh());
  }

  @override
  void dispose() {
    _refillTimer?.cancel();
    super.dispose();
  }

  /// Drop the provisioned servers and quota after account deletion.
  ///
  /// The VLESS clients behind these links have been removed from the
  /// panels, so holding on to them would leave the app offering
  /// credentials that no longer authenticate anywhere.
  ///
  /// In-memory only. The persisted choice of server is cleared by
  /// [AccountService], which owns the list of keys a deletion touches so
  /// that a single test can assert none was forgotten.
  void reset() {
    _generation++;
    _forgetting = false;
    _quotaFresh = false;
    // A save that passed its checks just before this cannot outlive it.
    unawaited(
      _prefs()
          .then((prefs) => prefs.remove(prefSaved))
          .catchError((_) => false),
    );
    _refillTimer?.cancel();
    _refillTimer = null;
    _fromSaved = false;
    _lastRefreshFailed = false;
    _lastRefreshErred = false;
    _configs = [];
    _servers = [];
    _paths = [];
    TlsFragment.doorSpec = null;
    DoorOutbounds.adopt(const {});
    _selectedServer = null;
    _byUser = false;
    _quota = null;
    _doorPair = null;
    _variantTests = const [];
    _variantTestParams = null;
    _psiphon = null;
    _errorMessage = null;
    _isLoading = false;
    _pingResults.clear();
    _pinging.clear();
    _isPingingAll = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
