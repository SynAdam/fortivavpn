import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/server.dart';

/// Where one door's check stands.
enum PathCheckState { pending, running, open, blocked, skipped }

/// When a door check began, and how far it got on the sockets the core
/// opened for it (backend issue #365, item 1). The core fields come from
/// `Fortivacore.checkDoorTimed` and are null when the check ran without it
/// (the backend has not turned timed checks on, the platform lacks it, or
/// the core gave no reading). Times are milliseconds. None of it is an
/// address.
class CheckTimeline {
  const CheckTimeline({
    required this.began,
    this.bootMs,
    this.coldMs,
    this.dnsMs,
    this.dialMs,
    this.firstByteMs,
    this.tlsMs,
    this.replyMs,
    this.bytesOut,
    this.bytesIn,
    this.dials,
    this.dialFails,
  });

  /// When the phone asked for the check.
  final DateTime began;

  /// Starting the check's core, inside the check's wait.
  final int? bootMs;

  /// The first of the check's two requests alone, when it got its reply.
  final int? coldMs;

  /// How long the system resolver took for the door's name, for a door the
  /// link names by host. A door dialled at an address has none.
  final int? dnsMs;

  /// The core's first TCP connect to the door that succeeded.
  final int? dialMs;

  /// From the first request to the first byte back on the door's socket:
  /// the server's first handshake flight.
  final int? firstByteMs;

  /// From the first request to when the first TLS or REALITY handshake on
  /// the door's sockets was done. A door with no TLS has none.
  final int? tlsMs;

  /// From the first request to the first byte of the probe's reply,
  /// through the tunnel.
  final int? replyMs;

  /// Bytes the core sent to and read from the door, failed checks included.
  final int? bytesOut;
  final int? bytesIn;

  /// TCP connects the core made to the door, and how many failed.
  final int? dials;
  final int? dialFails;

  /// The same timeline with the core's fields from the native map of a
  /// timed check. A map without them leaves only [began].
  CheckTimeline withCore(Map<dynamic, dynamic> m) {
    int? n(String key) {
      final v = m[key];
      return v is num && v >= 0 ? v.toInt() : null;
    }

    return CheckTimeline(
      began: began,
      bootMs: n('bootMs'),
      coldMs: n('coldMs'),
      dnsMs: n('dnsMs'),
      dialMs: n('dialMs'),
      firstByteMs: n('firstByteMs'),
      tlsMs: n('tlsMs'),
      replyMs: n('replyMs'),
      bytesOut: n('bytesOut'),
      bytesIn: n('bytesIn'),
      dials: n('dials'),
      dialFails: n('dialFails'),
    );
  }
}

/// What one door check found, with the parts the backend keeps next to
/// the result.
class DoorOutcome {
  const DoorOutcome({
    required this.ms,
    this.error,
    this.tcpMs,
    this.phase,
    this.timeline,
  });

  /// How many milliseconds data took to flow through the door, or -1 when
  /// it did not.
  final int ms;

  /// Why it did not, when the check could say.
  final String? error;

  /// How long a plain TCP connection to the door's address took, opened
  /// beside the check. Null when it did not connect, or was not measured.
  final int? tcpMs;

  /// How far the check got: "ok" (data flowed), "tcp" (the address took no
  /// TCP connection) or "tls" (the handshake was not answered, or failed).
  /// A timed check also says "proxy" (the handshake was answered and no
  /// reply came) and "late" (a reply came, after the check's wait ran out).
  /// Null when the phone cannot tell, which without a timed check includes
  /// most "tcp ok; EOF" checks.
  final String? phase;

  /// When the check began and, for a timed check, how far it got.
  final CheckTimeline? timeline;

  bool get open => ms >= 0;
}

/// Tests one door and says what it found. Never throws for a closed door.
typedef DoorReader = Future<DoorOutcome> Function(Server path);

/// One row of the checklist: a door, and what the check found.
class PathCheck {
  PathCheck(this.path, {this.state = PathCheckState.pending, this.ms});

  final Server path;
  PathCheckState state;
  int? ms;
  String? error;

  /// When this row's check started, on DateTime.now's clock. Null while no
  /// check has reached it. The connect trace counts its step's start from
  /// it (TraceStep.at).
  DateTime? startedAt;

  /// See [DoorOutcome.tcpMs], [DoorOutcome.phase] and
  /// [DoorOutcome.timeline].
  int? tcpMs;
  String? phase;
  CheckTimeline? timeline;

  /// Whether this row has a result the backend should hear about. Skipped
  /// rows were never dialled and say nothing.
  bool get reportable =>
      state == PathCheckState.open || state == PathCheckState.blocked;

  /// Whether the check failed after the door's address took a TCP
  /// connection, with no answer in time: "tcp ok 133ms; no answer in 3000
  /// ms". On a slow line a check of an open door can say that when other
  /// checks share the line with it (ConnectFlow._checkAlone).
  bool get noAnswerAfterTcp =>
      state == PathCheckState.blocked &&
      tcpMs != null &&
      (error ?? '').contains('no answer');

  /// Back to pending with no result, as a row no check has reached.
  void forget() {
    state = PathCheckState.pending;
    ms = null;
    error = null;
    startedAt = null;
    tcpMs = null;
    phase = null;
    timeline = null;
  }
}

/// What the control fetch found about the phone's network
/// ([PathFinder.controlFetch]).
enum NetReach {
  /// A site abroad answered.
  open,

  /// No site abroad answered, and one inside the country did: the phone's
  /// network is up and only its way abroad is cut, as in Iran in June 2025
  /// and January 2026. The tap searches as hard as with [open], and keeps
  /// trying (ConnectStage.cutOff).
  cut,

  /// Nothing answered: the phone has no internet, as far as it can tell.
  offline,
}

/// What a diagnosis found.
class PathFinding {
  PathFinding({
    required this.checks,
    required this.internet,
    this.cut = false,
    this.open,
    this.cancelled = false,
    Future<bool>? control,
  }) : control = control ?? Future.value(true);

  final List<PathCheck> checks;

  /// False when the control fetch beside the search failed and no door it
  /// checked was open: the phone may have no internet. The tap then checks
  /// the shared links, and ends at "no internet" when none is open. True
  /// when the fetch passed, or when a door was open, which no phone without
  /// internet could have found.
  final bool internet;

  /// With [internet] false: a site inside the country answered the
  /// control fetch ([NetReach.cut]). The phone is not offline, its way
  /// abroad is cut. The tap searches as it would with [internet] true, and
  /// ends at ConnectStage.cutOff rather than at no internet. The rows still
  /// go nowhere and nothing is written down, as with [internet] false:
  /// with the way abroad cut every door fails, and that says nothing about
  /// any one of them.
  final bool cut;

  /// The first door that carried data, or null when none did.
  final Server? open;
  final bool cancelled;

  /// Whether the control fetch beside the search reached a known-open
  /// site. True at once for a search that ran none. It can still be
  /// running when a search returns with a door open. A caller that
  /// reports rows with no door open waits for it, and reports nothing when
  /// it is false. Rows with a door open need not wait: no phone without
  /// internet finds one (ConnectFlow._reportOnline).
  final Future<bool> control;
}

/// Tests one door: data flowed through it, in this many milliseconds, or
/// -1 when it did not. Backed by the core's real-delay test, which starts
/// the core in proxy-only mode with the link and fetches a tiny page
/// through it. No VPN permission, no tunnel, the user's current connection
/// untouched.
typedef DoorProbe = Future<int> Function(Server path);

/// Does the phone reach a known-open site at all.
typedef InternetCheck = Future<bool> Function();

/// [read], or [probe] read as a [DoorOutcome] that carries only its time.
/// A probe that throws still throws, as it always has.
DoorReader doorReader({DoorProbe? probe, DoorReader? read}) {
  if (read != null) return read;
  final p = probe ?? (Server _) async => -1;
  return (path) async => DoorOutcome(ms: await p(path));
}

/// Finds a door that is open on this network, one check at a time or
/// several at once.
///
/// The order matters more than anything: the remembered door first, then
/// the backend's order, which is the scoreboard for this carrier. [find]
/// takes the first door in that order that is open once every door above
/// it is closed, so a good order means one check. With several checks at
/// once it lands on the same door a one-at-a-time search would, never
/// later, and leaves the rows as that search would ([_inOrder]). A search
/// that found nothing open can end with a last pass ([findRest]) that
/// checks the rows it did not reach several at a time.
///
/// Door checks can run side by side, and beside a dial. On Android each
/// check is its own coroutine on Dispatchers.IO with no lock, and builds
/// its own core in the app's process (Libv2ray.measureOutboundDelay). The
/// cores still share one thing: the core's dialer is process-wide, and
/// holds the outbounds of the core created last. A TLS door's check dials
/// through its "fragment" splitter, which the core looks up there, retries
/// included. Until 2026-10-12 a newer Reality check's core had no splitter,
/// so a TLS check beside it failed ("io: read/write on closed pipe") where
/// it would have passed alone. Every check's core now carries the app's
/// splitter (PingService's `splitter`, TestLink.config on Android). The
/// tunnel's core runs in another process (:RunSoLibV2RayDaemon), and the
/// app is left out of its own tunnel. The background sweep has checked 12
/// doors at once beside a live tunnel since 2026-09-09 (DoorSweep). The
/// real limit is Dispatchers.IO's 64 threads: a check the app gave up on
/// keeps its thread until the core returns.
///
/// The control fetch, which tells "every door closed" from "no internet",
/// runs beside the first checks rather than before them, and a door found
/// open is open whatever it says (see [find]).
///
/// Every check runs against a budget, and the whole search against a
/// larger one, because a user watching a list fill with "blocked" needs to
/// know when it will end.
class PathFinder extends ChangeNotifier {
  /// [read] tests a door and says how far the check got; [probe] only
  /// says how long it took. One of the two is needed.
  ///
  /// [home] reaches a site inside the country, and is asked only when
  /// [internet] reached none abroad ([NetReach]). Null asks nothing, and a
  /// fetch that reached no site abroad reads as [NetReach.offline].
  PathFinder({
    DoorProbe? probe,
    DoorReader? read,
    required InternetCheck internet,
    InternetCheck? home,
    this.probeTimeout = const Duration(seconds: 4),
    this.budget = const Duration(seconds: 20),
  }) : assert(probe != null || read != null),
       _read = doorReader(probe: probe, read: read),
       _internet = internet,
       _home = home;

  final DoorReader _read;
  final InternetCheck _internet;
  final InternetCheck? _home;

  /// Whether something besides the control fetch has shown, during the tap
  /// under way, that the phone has internet. ConnectFlow sets it: our API
  /// answered the phone on its own network since the tap began
  /// (ApiClient.answeredSince). Never, until it is set.
  ///
  /// Then a failed control fetch reads as passed ([controlFetch]), the
  /// search keeps its whole budget ([find]'s offline budget does not
  /// apply), and a search that found nothing open does not end at no
  /// internet. It is asked again at each of those points, because an
  /// answer can come after the fetch failed. Until 2.2.0 a fetch that
  /// failed was enough: in the 4 days to 2026-10-23, about 10 to 25 taps a
  /// day ended at no internet on phones our API was answering.
  /// [reachesAbroad] does not ask it: it is asked outside a tap.
  bool Function() answered = _never;

  static bool _never() => false;

  /// [answered], or false when it throws.
  bool _answeredNow() {
    try {
      return answered();
    } catch (e) {
      debugPrint('PathFinder: could not tell whether the API answered: $e');
      return false;
    }
  }

  /// How long one door gets.
  final Duration probeTimeout;

  /// How long the whole search gets. No new check starts past this.
  final Duration budget;

  /// How long a search goes on starting door checks once its control fetch
  /// has failed, when the caller does not say ([find]'s `offlineBudget`).
  /// The backend's CHECKLIST_FALLBACK_AFTER_MS default on 2026-10-11: the
  /// time the own doors get before the shared links.
  static const defaultOfflineBudget = Duration(seconds: 8);

  List<PathCheck> _checks = const [];
  bool _cancelled = false;

  /// Set by [cutShort], and cleared by [cancel] and by each new search.
  bool _keepOpen = false;
  bool _running = false;
  Completer<void>? _ended;

  /// Completed by [cancel], so a search waiting on its control fetch ends
  /// at once.
  Completer<void>? _stop;

  /// Searches [_inOrder] has run. A check that answers after its search
  /// returned sees a newer count and changes nothing.
  int _search = 0;

  /// Wakes the [_inOrder] search that is waiting, on a stop.
  void Function()? _wake;

  /// Control fetches [controlFetch] has started. Only the latest one sets
  /// [internet].
  int _fetches = 0;

  /// See [internet].
  bool? _internetSeen;

  /// See [cut].
  bool? _cutSeen;

  /// See [reach].
  Future<NetReach> _reach = Future.value(NetReach.open);

  /// The rows the checklist draws, updated as each check completes.
  List<PathCheck> get checks => List.unmodifiable(_checks);
  bool get isRunning => _running;

  /// Whether the phone has internet, as the checklist's first row shows it.
  /// Null while the latest control fetch runs and no check since it
  /// started has found a door or link open. True once that fetch passed or
  /// such a check found one open: no phone without internet finds one open
  /// ([PathFinding.internet]). False once that fetch failed and none was.
  ///
  /// Until 2026-10-12 the row read the connect stage instead. It showed a
  /// tick whenever the checklist was on screen, because the home screen
  /// hides the checklist at "no internet". In an emulator test that day, a
  /// tap whose fetch had not answered yet, or had failed, showed the tick
  /// above door rows that said "blocked" in red.
  bool? get internet => _internetSeen;

  /// Whether a site inside the country answered the latest control fetch,
  /// once no site abroad did ([NetReach.cut]). Null while that is not
  /// known, and when a site abroad answered. The checklist's first row
  /// says so when [internet] is false.
  bool? get cut => _cutSeen;

  /// What the latest control fetch found, once its checks have answered:
  /// the one abroad, and the one inside the country after it when the first
  /// failed. [NetReach.open] before any fetch.
  Future<NetReach> get reach => _reach;

  /// Completes when the search in progress has ended, or at once when none
  /// is. A cancelled one-at-a-time search ends only once its check in
  /// flight returns. A search with several checks at once ends at once,
  /// and the answers of its checks still in flight change nothing.
  Future<void> get idle => _ended?.future ?? Future<void>.value();

  /// Stop after the check in flight, or at once when several run. The user
  /// tapped again.
  void cancel() => _halt(keepOpen: false);

  /// Stop as [cancel] does, but keep a door already found open: the search
  /// returns it as found, where after [cancel] it returns none. A check
  /// that runs to its end after this, as a check in flight does in a search
  /// of one check at a time, counts too. With several checks at once, the
  /// first row found open is kept, and the rows above it that still run
  /// go back to pending. For a tap that has looked long enough
  /// (ConnectFlow._cutSearch): no further door is checked, and a door
  /// found open is still dialled.
  void cutShort() => _halt(keepOpen: true);

  void _halt({required bool keepOpen}) {
    _cancelled = true;
    _keepOpen = keepOpen;
    final stop = _stop;
    if (stop != null && !stop.isCompleted) stop.complete();
    _wake?.call();
  }

  /// Whether a search that ends with [open] ends as stopped: after
  /// [cancel], or after [cutShort] with no door found open.
  bool _stoppedWith(PathCheck? open) =>
      _cancelled && !(_keepOpen && open != null);

  /// The control fetch on its own: does the phone reach a known-open site.
  /// Never throws. A fetch that throws did not reach one.
  ///
  /// [internet] follows the latest fetch started, from the moment it starts.
  /// One that answers after a newer one started changes nothing there: on a
  /// tap that starts on a shared link the fallback chose, ConnectFlow's
  /// _ownFirst starts one and the diagnosis after it starts another.
  ///
  /// The answer is about the sites abroad only. When they fail, the check
  /// of a site inside the country follows, and [reach] and [cut] say what
  /// it found. The answer does not wait for it.
  ///
  /// A fetch whose sites failed passes all the same when our API has
  /// answered the phone on its own network during the tap ([answered]):
  /// our API is abroad, so the phone reaches abroad.
  Future<bool> controlFetch() {
    final fetch = ++_fetches;
    _setInternet(null);
    _setCut(null);
    final abroad = _ask(_internet).then((ok) => ok || _answeredNow());
    _reach = abroad.then((ok) async {
      if (ok) return NetReach.open;
      final home = _home;
      final inside = home != null && await _ask(home);
      if (fetch == _fetches) _setCut(inside);
      return inside ? NetReach.cut : NetReach.offline;
    });
    return abroad.then((ok) {
      if (fetch == _fetches) _setInternet(ok || _internetSeen == true);
      return ok;
    });
  }

  /// Whether the phone reaches a known-open site abroad now: the control
  /// fetch's own check, without anything [controlFetch] sets ([internet],
  /// [cut], [reach]) and without telling the listeners, so the checklist's
  /// first row does not change. Never throws.
  ///
  /// For a question that only needs the answer: whether the way is back
  /// while a tap waits to try again (ConnectFlow's recheck), and whether a
  /// tunnel that stopped carrying data died with the phone's own network
  /// (StallRecovery).
  Future<bool> reachesAbroad() => _ask(_internet);

  /// [check]'s answer. One that throws reached nothing.
  static Future<bool> _ask(InternetCheck check) async {
    try {
      return await check();
    } catch (e) {
      debugPrint('PathFinder: the control fetch threw: $e');
      return false;
    }
  }

  void _setInternet(bool? value) {
    if (_internetSeen == value) return;
    _internetSeen = value;
    notifyListeners();
  }

  void _setCut(bool? value) {
    if (_cutSeen == value) return;
    _cutSeen = value;
    notifyListeners();
  }

  /// Check [candidates] in order until one is open, with the control fetch
  /// running beside the checks rather than before them.
  ///
  /// Until 1.7.1 the fetch ran first, and a failed one ended the tap at "no
  /// internet" with no door checked. In the 24 hours to 01:00 Tehran on
  /// 2026-10-12 that was 30 first taps a day: 19 of their 30 traces reached
  /// the backend within 2 minutes, and Android called the network validated
  /// in 25 of 34 of their diagnoses. The fetch fails on phones that have
  /// internet. A door found open is open, whatever the fetch says. Once the
  /// fetch has failed, no new check starts past [offlineBudget] (null:
  /// [defaultOfflineBudget]) from the start of the search, unless a site
  /// inside the country answered ([NetReach.cut]): then the search has its
  /// whole budget, as when the fetch passed.
  /// [PathFinding.internet] is false only when the fetch failed and no door
  /// checked was open, and [PathFinding.cut] then says whether a site
  /// inside the country answered.
  ///
  /// [skip] are doors this phone gave up on for today; they are shown as
  /// skipped rather than silently dropped, so the user sees why a door
  /// they remember is not being tried.
  ///
  /// [append] keeps the rows of the previous search on screen and adds
  /// these below them, so a second search reads as the same checklist
  /// carrying on. [online] skips the control fetch when the caller has
  /// just made it. [budget] stands in for the finder's own [budget] in
  /// this search.
  ///
  /// [parallel] above 1 checks that many doors at once, the first ones
  /// [stagger] apart, and still takes the door a one-at-a-time search would
  /// ([_inOrder]). 1 is the one-at-a-time search of 1.7.0.
  Future<PathFinding> find(
    List<Server> candidates, {
    Set<String> skip = const {},
    bool append = false,
    bool online = false,
    Duration? budget,
    Duration? offlineBudget,
    int parallel = 1,
    Duration stagger = Duration.zero,
  }) async {
    final limit = budget ?? this.budget;
    final offlineFor = offlineBudget ?? defaultOfflineBudget;
    _cancelled = false;
    _keepOpen = false;
    _running = true;
    final ended = _ended = Completer<void>();
    final stop = _stop = Completer<void>();
    final fresh = [
      for (final c in candidates)
        PathCheck(
          c,
          state: skip.contains(c.pathKey)
              ? PathCheckState.skipped
              : PathCheckState.pending,
        ),
    ];
    _checks = append ? [..._checks, ...fresh] : fresh;
    notifyListeners();

    // The fetch's answer, null while it runs. Read before each check starts.
    bool? reached = online ? true : null;
    final control = online
        ? Future<bool>.value(true)
        : controlFetch().then((ok) => reached = ok);
    // What the fetch found once both its checks answered, and whether the
    // phone reaches anything at all, null until then.
    final reach = online ? Future.value(NetReach.open) : this.reach;
    bool? reachesAny;
    unawaited(reach.then((r) => reachesAny = r != NetReach.offline));
    // A search cut short ([cutShort]) says what its fetch found, so a tap
    // whose fetch failed reads as one with no internet, as it would have
    // without the cut. A stop does not wait for it.
    PathFinding stopped() => PathFinding(
      checks: _checks,
      internet: !_keepOpen || reached != false,
      cancelled: true,
      control: control,
    );

    try {
      final started = DateTime.now();
      // No new check past the budget, nor past offlineFor once the fetch
      // has failed and no site inside the country answered either: the
      // doors had their part of the search, and none of them was open. A
      // site inside the country that answered, or whose check still runs,
      // leaves the search its whole budget: with the way abroad cut, our
      // doors are the only way out, and one of them may still be open. So
      // does an answer from our API that came after the fetch failed
      // ([answered]).
      bool mayStart() {
        final spent = DateTime.now().difference(started);
        final offline =
            reached == false && reachesAny == false && !_answeredNow();
        return spent <= limit && !(offline && spent > offlineFor);
      }

      if (parallel > 1) {
        final open = await _inOrder(
          [
            for (final c in fresh)
              if (c.state == PathCheckState.pending) c,
          ],
          parallel: parallel,
          stagger: stagger,
          started: started,
          mayStart: mayStart,
        );
        if (_stoppedWith(open)) return stopped();
        if (open != null) {
          // Open is open, and the dial does not wait for the fetch.
          return PathFinding(
            checks: _checks,
            internet: true,
            open: open.path,
            control: control,
          );
        }
      } else {
        for (final check in fresh) {
          if (_cancelled) return stopped();
          if (check.state == PathCheckState.skipped) continue;
          if (!mayStart()) break;

          check.state = PathCheckState.running;
          notifyListeners();

          int ms;
          final checkStarted = check.startedAt = DateTime.now();
          try {
            final reading = await _read(check.path).timeout(probeTimeout);
            ms = reading.ms;
            if (!reading.open) check.error = reading.error;
            check
              ..tcpMs = reading.tcpMs
              ..phase = reading.phase
              ..timeline = reading.timeline;
          } catch (e) {
            ms = -1;
            check.error = e.toString();
          }
          if (ms < 0) {
            // How long a failure took is half of why: a door that is cut
            // fails at once, one that is dropped waits out the timeout.
            check.ms = DateTime.now().difference(checkStarted).inMilliseconds;
          }

          if (ms >= 0) {
            check
              ..state = PathCheckState.open
              ..ms = ms;
            _internetSeen = true;
            notifyListeners();
            // Open is open: the phone reached our server, and the dial does
            // not wait for the fetch.
            return PathFinding(
              checks: _checks,
              internet: true,
              open: check.path,
              control: control,
            );
          }
          check.state = PathCheckState.blocked;
          notifyListeners();
        }
      }
      // Nothing open. The fetch tells "every door closed" from "no
      // internet". A stop does not wait for it: no check of this search
      // can change a row any more, and the next tap waits on [idle].
      final fetched = await Future.any<bool>([
        control,
        stop.future.then((_) => false),
      ]);
      if (_cancelled) return stopped();
      // An answer from our API since the fetch failed says the phone has
      // internet too ([answered]).
      final ok = fetched || _answeredNow();
      if (ok && !fetched) _setInternet(true);
      // With the fetch failed, its check of a site inside the country tells
      // a cut way abroad from no internet.
      final cut =
          !ok &&
          await Future.any<NetReach>([
                reach,
                stop.future.then((_) => NetReach.offline),
              ]) ==
              NetReach.cut;
      if (_cancelled) return stopped();
      return PathFinding(
        checks: _checks,
        internet: ok,
        cut: cut,
        control: control,
      );
    } finally {
      _running = false;
      ended.complete();
      notifyListeners();
    }
  }

  /// Check the rows of the checklist on screen in [rows] that are still
  /// pending, as [find] does with several checks at once, and with no
  /// control fetch. For the own doors a shorter search left, once the
  /// shared links have been checked. Each row keeps its place, and the rows
  /// end as a one-at-a-time search would leave them.
  ///
  /// With [budget], no check starts once that long has passed since this
  /// call, and the rows not started stay pending.
  Future<PathFinding> findInOrder(
    List<PathCheck> rows, {
    required int parallel,
    Duration stagger = Duration.zero,
    Duration? budget,
  }) async {
    _cancelled = false;
    _keepOpen = false;
    _running = true;
    final ended = _ended = Completer<void>();
    final started = DateTime.now();
    try {
      final open = await _inOrder(
        [
          for (final r in rows)
            if (_checks.contains(r) && r.state == PathCheckState.pending) r,
        ],
        parallel: parallel,
        stagger: stagger,
        started: started,
        mayStart: () =>
            budget == null || DateTime.now().difference(started) <= budget,
      );
      return PathFinding(
        checks: _checks,
        internet: true,
        open: open?.path,
        cancelled: _stoppedWith(open),
      );
    } finally {
      _running = false;
      ended.complete();
      notifyListeners();
    }
  }

  /// Checks [queue] in order, up to [parallel] at once, the first ones
  /// [stagger] apart, and returns the first row that is open once every row
  /// above it is closed: the row a one-at-a-time search would reach, and
  /// never later. A check that ends lets the next one start at once, so
  /// every row starts no later than it would one at a time. No check starts
  /// once [mayStart] says no.
  ///
  /// Returns as soon as that row is known, or on a stop, without waiting
  /// for the checks in flight, whose answers are then ignored. The rows
  /// still running, and every row below the one returned or below a row
  /// still running, go back to pending. So the rows end as a one-at-a-time
  /// search leaves them, and the reports, the trace and the last pass read
  /// them unchanged. Null when nothing was open, or on a stop.
  Future<PathCheck?> _inOrder(
    List<PathCheck> queue, {
    required int parallel,
    required Duration stagger,
    required DateTime started,
    required bool Function() mayStart,
  }) async {
    final search = ++_search;
    var next = 0;
    var inFlight = 0;
    var wake = Completer<void>();
    void poke() {
      if (!wake.isCompleted) wake.complete();
    }

    _wake = poke;
    Timer? ramp;
    PathCheck? open;
    Duration since() => DateTime.now().difference(started);
    int allowed() {
      if (stagger <= Duration.zero) return parallel;
      final ramped = 1 + since().inMicroseconds ~/ stagger.inMicroseconds;
      return ramped < parallel ? ramped : parallel;
    }

    void start(PathCheck check) {
      inFlight += 1;
      check.state = PathCheckState.running;
      final checkStarted = check.startedAt = DateTime.now();
      unawaited(() async {
        DoorOutcome reading;
        try {
          reading = await _read(check.path).timeout(probeTimeout);
        } catch (e) {
          reading = DoorOutcome(ms: -1, error: e.toString());
        }
        inFlight -= 1;
        // The search returned without it: a stop, or a door above it was
        // found open. Its row is pending again, or belongs to a newer
        // search, and stays as it is.
        if (search != _search) return;
        check
          ..tcpMs = reading.tcpMs
          ..phase = reading.phase
          ..timeline = reading.timeline;
        if (reading.open) {
          check
            ..state = PathCheckState.open
            ..ms = reading.ms;
          _internetSeen = true;
        } else {
          // How long a failure took, as in the one-at-a-time search.
          check
            ..state = PathCheckState.blocked
            ..error = reading.error
            ..ms = DateTime.now().difference(checkStarted).inMilliseconds;
        }
        notifyListeners();
        poke();
      }());
    }

    PathCheck? settled() {
      for (final c in queue) {
        if (c.state == PathCheckState.open) return c;
        if (c.state != PathCheckState.blocked) return null;
      }
      return null;
    }

    try {
      while (true) {
        if (_cancelled) {
          // Cut short ([cutShort]): the first row found open is kept, and
          // the rows above it that still run are cut.
          if (_keepOpen) {
            open = queue
                .where((c) => c.state == PathCheckState.open)
                .firstOrNull;
          }
          return open;
        }
        open = settled();
        if (open != null) return open;
        var any = false;
        while (next < queue.length && inFlight < allowed() && mayStart()) {
          start(queue[next]);
          next += 1;
          any = true;
        }
        if (any) notifyListeners();
        if (inFlight == 0) return null;
        ramp?.cancel();
        ramp = null;
        if (next < queue.length && allowed() < parallel && mayStart()) {
          final step = stagger.inMicroseconds;
          ramp = Timer(
            Duration(microseconds: step - since().inMicroseconds % step),
            poke,
          );
        }
        await wake.future;
        wake = Completer<void>();
      }
    } finally {
      ramp?.cancel();
      _search += 1;
      _wake = null;
      // From the first row not found closed on, every row but the one
      // returned goes back to pending: one at a time, none of them would
      // have been checked yet.
      var below = false;
      for (final c in queue) {
        if (identical(c, open)) {
          below = true;
          continue;
        }
        if (below || c.state != PathCheckState.blocked) {
          below = true;
          c
            ..state = PathCheckState.pending
            ..ms = null
            ..error = null
            ..startedAt = null
            ..tcpMs = null
            ..phase = null
            ..timeline = null;
        }
      }
    }
  }

  /// Check [row] of the checklist on screen again, alone, within
  /// [probeTimeout]. The new result replaces the old one. A row that is
  /// not on the checklist is left alone, and nothing is found open.
  Future<PathFinding> checkAgain(PathCheck row) {
    if (_checks.contains(row)) row.forget();
    return findRest([row], parallel: 1, timeout: probeTimeout);
  }

  /// Add [candidates] below the rows on screen and check them [parallel]
  /// at a time, until one is open. Without [append], they replace the rows
  /// on screen, as a new search.
  ///
  /// The checklist carrying on, like [find] with `append`, but several
  /// checks at once and no budget: the caller limits how many candidates
  /// there are. Each check gets [probeTimeout]. As in [findRest], the open
  /// one is the first of [candidates] found open, in the caller's order,
  /// and the checks in flight run to their end before this returns, unless
  /// [returnAtFirst] (see [findRest]).
  Future<PathFinding> race(
    List<Server> candidates, {
    required int parallel,
    bool append = true,
    bool returnAtFirst = false,
  }) {
    final rows = [for (final c in candidates) PathCheck(c)];
    _checks = append ? [..._checks, ...rows] : rows;
    notifyListeners();
    return findRest(
      rows,
      parallel: parallel,
      timeout: probeTimeout,
      returnAtFirst: returnAtFirst,
    );
  }

  /// Check [rows] of the checklist on screen, [parallel] at a time, each
  /// within [timeout], until one is open.
  ///
  /// For a search that found nothing open. Its budget can end before the
  /// rows at the bottom of the list, and it never dials a row it skipped,
  /// so the one door open on this network can be among the rows it left.
  /// [rows] are some of those rows, in the order to prefer them. Each one
  /// keeps its place in the checklist and changes from pending or skipped
  /// to its result. A row that already has a result, or that is not on
  /// the checklist, is left alone.
  ///
  /// No new check starts once a door is open, and the checks in flight run
  /// to their end before this returns, so that every row it returns has a
  /// result the caller can report. The open door is the first of [rows]
  /// that was found open, not the first to answer.
  ///
  /// With [budget], no check starts once that long has passed since this
  /// call, and the rows not started stay pending.
  ///
  /// A [timeout] shorter than [probeTimeout] is raised to it. The native
  /// check waits its own time whatever this waits, and [probeTimeout] is
  /// built around it. A shorter wait would report a door closed while its
  /// check still runs, and would start the next check beside it, so more
  /// than [parallel] checks would run at once.
  ///
  /// With [returnAtFirst] this returns as soon as the open row is known: a
  /// row is open and every row above it is closed. It does not wait for
  /// the checks still in flight, and a stop or a cut ends it at once. The
  /// rows still running then go back to pending, and their answers change
  /// nothing, as in [find] with several checks at once. On Tehran day
  /// 2026-10-23 the wait for those checks cost about 3.1 seconds in each
  /// race of shared links that found one open, and shared-link connects
  /// took a median of 26.8 seconds. The rows a caller reports are then
  /// only the ones with a result.
  Future<PathFinding> findRest(
    List<PathCheck> rows, {
    required int parallel,
    required Duration timeout,
    Duration? budget,
    bool returnAtFirst = false,
  }) async {
    final started = DateTime.now();
    bool spent() =>
        budget != null && DateTime.now().difference(started) > budget;
    _cancelled = false;
    _keepOpen = false;
    _running = true;
    final ended = _ended = Completer<void>();
    final wait = timeout < probeTimeout ? probeTimeout : timeout;
    final queue = [
      for (final r in rows)
        if (_checks.contains(r) &&
            (r.state == PathCheckState.pending ||
                r.state == PathCheckState.skipped))
          r,
    ];
    var next = 0;
    var found = false;
    // Set once this has returned with checks still in flight
    // ([returnAtFirst]). Their answers then change nothing.
    var returned = false;
    final known = Completer<void>();
    void settle() {
      if (!known.isCompleted) known.complete();
    }

    // Whether the open row is known: a row is open, and every row above it
    // is closed.
    bool openKnown() {
      for (final c in queue) {
        if (c.state == PathCheckState.open) return true;
        if (c.state != PathCheckState.blocked) return false;
      }
      return false;
    }

    Future<void> worker() async {
      while (!_cancelled && !found && !spent() && next < queue.length) {
        final check = queue[next++];
        check.state = PathCheckState.running;
        notifyListeners();
        int ms;
        String? error;
        DoorOutcome? reading;
        final checkStarted = check.startedAt = DateTime.now();
        try {
          reading = await _read(check.path).timeout(wait);
          ms = reading.ms;
          if (!reading.open) error = reading.error;
        } catch (e) {
          ms = -1;
          error = e.toString();
        }
        if (returned) return;
        check
          ..error = error
          ..tcpMs = reading?.tcpMs
          ..phase = reading?.phase
          ..timeline = reading?.timeline;
        if (ms >= 0) {
          found = true;
          check
            ..state = PathCheckState.open
            ..ms = ms;
          _internetSeen = true;
        } else {
          check
            ..state = PathCheckState.blocked
            ..ms = DateTime.now().difference(checkStarted).inMilliseconds;
        }
        notifyListeners();
        if (returnAtFirst && openKnown()) settle();
      }
    }

    try {
      final workers = parallel < queue.length ? parallel : queue.length;
      final all = Future.wait([for (var i = 0; i < workers; i++) worker()]);
      if (returnAtFirst) {
        // A stop or a cut does not wait for the checks in flight either.
        _wake = settle;
        await Future.any([all, known.future]);
        returned = true;
        for (final c in queue) {
          if (c.state == PathCheckState.running) c.forget();
        }
      } else {
        await all;
      }
      final open = queue
          .where((c) => c.state == PathCheckState.open)
          .firstOrNull;
      if (_stoppedWith(open)) {
        return PathFinding(checks: _checks, internet: true, cancelled: true);
      }
      return PathFinding(checks: _checks, internet: true, open: open?.path);
    } finally {
      if (returnAtFirst) _wake = null;
      _running = false;
      ended.complete();
      notifyListeners();
    }
  }
}
