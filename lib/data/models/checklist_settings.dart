import '../../utils/state_platforms.dart';

/// How the connect checklist runs, from the app config's `checklist`
/// block. Every number in it comes from the backend.
///
/// Each part is null when the block is missing, or when it lacks a number
/// that part needs, and a null part keeps what the app did before the
/// block existed:
///
/// - [lastPass] null: a checklist that found no door open ends there.
/// - [skip] null: a door that failed on a network as many times as
///   PathMemory.maxFailsPerDay is skipped until the UTC day ends.
/// - [fallback] null: the shared links are checked one at a time, at most
///   ConnectFlow.sharedFallbackLimit of them, once every door of the
///   device's own has been checked.
/// - [retry] null: a tap that found nothing open ends there.
/// - [doors] null: the own doors are checked as DoorCheckSettings.standard
///   says, which is not what the app did before (see DoorCheckSettings).
/// - [homeControl] null: the sites in ConnectDiagnostics.homeUrls.
/// - [control] null: the sites in ConnectDiagnostics.controlUrls.
/// - [fastPath] null: the remembered door's dial runs as
///   FastPathSettings.standard says, which is not what the app did before
///   (see FastPathSettings).
///
/// A phone the backend has never answered has [builtIn] (see
/// AppConfigState).
///
/// Read without a cast, like the other optional blocks of the config: a
/// value of the wrong type turns its part off and never throws away the
/// rest of the config.
class ChecklistSettings {
  const ChecklistSettings({
    this.lastPass,
    this.skip,
    this.fallback,
    this.retry,
    this.doors,
    this.homeControl,
    this.control,
    this.fastPath,
  });

  /// The settings of a phone the backend has never answered: only
  /// [RetrySettings.standard], every other part as the app did before the
  /// block existed. Such a phone is a new install on a network that cut
  /// our calls from the start, which is the phone that most needs to keep
  /// trying by itself. Until 2026-10-13 it had no settings at all, and a
  /// tap that found nothing open ended there.
  static const builtIn = ChecklistSettings(retry: RetrySettings.standard);

  /// The settings the connect flow reads. AppConfigState sets them from
  /// the last config that landed, in this run of the app or an earlier
  /// one. Null on a phone the backend has never answered.
  static ChecklistSettings? current;

  /// See [LastPassSettings].
  final LastPassSettings? lastPass;

  /// See [SkipSettings].
  final SkipSettings? skip;

  /// See [FallbackSettings].
  final FallbackSettings? fallback;

  /// See [RetrySettings].
  final RetrySettings? retry;

  /// See [DoorCheckSettings].
  final DoorCheckSettings? doors;

  /// The sites inside the country the control fetch tries once the sites
  /// abroad did not answer (`home_control_urls`), as
  /// ConnectDiagnostics.homeCheck reads them. Null when the backend sent
  /// none, or a list the app cannot use or must not ask (one that names a
  /// state platform or hides its host, see StatePlatforms.mayAsk): the
  /// app's own list then. Empty when the backend sent an empty list: no
  /// such check, and a fetch that reached no site abroad reads as no
  /// internet, as before 1.9.0.
  final List<String>? homeControl;

  /// The most sites [homeControl] holds. They are tried at once.
  static const mostHomeControl = 6;

  /// The control sites abroad the control fetch races (`control_urls`), as
  /// ConnectDiagnostics.controlCheck reads them: http or https addresses.
  /// Null when the backend sent none, or a list the app cannot use or must
  /// not ask (see StatePlatforms.mayAsk): the app's own two then.
  /// Never empty, because with no site at all every tap would read as no
  /// internet.
  final List<String>? control;

  /// The most sites [control] holds. They are raced at once.
  static const mostControl = 4;

  /// See [FastPathSettings].
  final FastPathSettings? fastPath;

  /// The settings in [json], or null when it holds no part the app can
  /// use.
  static ChecklistSettings? fromJson(Object? json) {
    if (json is! Map) return null;
    final lastPass = LastPassSettings._fromJson(json);
    final skip = SkipSettings._fromJson(json);
    final fallback = FallbackSettings._fromJson(json);
    final retry = RetrySettings._fromJson(json);
    final doors = DoorCheckSettings._fromJson(json);
    final homeControl = _homeControl(json['home_control_urls']);
    final control = _control(json['control_urls']);
    final fastPath = FastPathSettings._fromJson(json);
    if (lastPass == null &&
        skip == null &&
        fallback == null &&
        retry == null &&
        doors == null &&
        homeControl == null &&
        control == null &&
        fastPath == null) {
      return null;
    }
    return ChecklistSettings(
      lastPass: lastPass,
      skip: skip,
      fallback: fallback,
      retry: retry,
      doors: doors,
      homeControl: homeControl,
      control: control,
      fastPath: fastPath,
    );
  }

  /// [raw] as [control]: a list of 1 to [mostControl] http or https
  /// addresses the app may ask (StatePlatforms.mayAsk), or null for
  /// anything else.
  static List<String>? _control(Object? raw) {
    if (raw is! List || raw.isEmpty || raw.length > mostControl) return null;
    final urls = <String>[];
    for (final u in raw) {
      if (u is! String) return null;
      final uri = Uri.tryParse(u);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty ||
          !StatePlatforms.mayAsk(u)) {
        return null;
      }
      urls.add(u);
    }
    return urls;
  }

  /// [raw] as [homeControl]: a list of at most [mostHomeControl] https
  /// addresses the app may ask (StatePlatforms.mayAsk), or null for
  /// anything else.
  static List<String>? _homeControl(Object? raw) {
    if (raw is! List || raw.length > mostHomeControl) return null;
    final urls = <String>[];
    for (final u in raw) {
      if (u is! String) return null;
      final uri = Uri.tryParse(u);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          !StatePlatforms.mayAsk(u)) {
        return null;
      }
      urls.add(u);
    }
    return urls;
  }

  Map<String, dynamic> toJson() => {
    ...?lastPass?._toJson(),
    ...?skip?._toJson(),
    ...?fallback?._toJson(),
    ...?retry?._toJson(),
    ...?doors?._toJson(),
    'home_control_urls': ?homeControl,
    'control_urls': ?control,
    ...?fastPath?._toJson(),
  };
}

/// The last pass of a checklist that found no door open.
///
/// The checklist checks its doors within a budget, so the doors
/// at the end of its list can go unchecked, and it never dials a door it
/// skipped for the day. Three checklists in a row on one phone ended at
/// "all doors closed" without trying the one address the background sweep
/// had found open half an hour before. The last pass checks the doors the
/// checklist did not reach, and the ones it skipped, several at a time.
class LastPassSettings {
  const LastPassSettings({
    required this.doors,
    required this.parallel,
    required this.timeout,
    this.sweptOpenFor,
  });

  /// The most doors one last pass checks (`last_pass_doors`).
  final int doors;

  /// How many of them are checked at once (`last_pass_parallel`).
  final int parallel;

  /// How long one check gets (`last_pass_timeout_ms`). A value shorter
  /// than the checklist's own wait for one check (PathFinder.probeTimeout)
  /// counts as that wait, because the native check runs its own time
  /// whatever the app waits (see PathFinder.findRest). The app's door
  /// check also gives up on its own after a few seconds, so a long value
  /// changes nothing past that.
  final Duration timeout;

  /// How long a door the background sweep found open goes first in the
  /// last pass (`swept_open_minutes`). Null when the backend did not say,
  /// and then the sweep does not change the order.
  final Duration? sweptOpenFor;

  static LastPassSettings? _fromJson(Map<dynamic, dynamic> json) {
    final doors = _positive(json['last_pass_doors']);
    final parallel = _positive(json['last_pass_parallel']);
    final ms = _positive(json['last_pass_timeout_ms']);
    if (doors == null || parallel == null || ms == null) return null;
    final swept = _positive(json['swept_open_minutes']);
    return LastPassSettings(
      doors: doors,
      parallel: parallel,
      timeout: Duration(milliseconds: ms),
      sweptOpenFor: swept == null ? null : Duration(minutes: swept),
    );
  }

  Map<String, dynamic> _toJson() => {
    'last_pass_doors': doors,
    'last_pass_parallel': parallel,
    'last_pass_timeout_ms': timeout.inMilliseconds,
    if (sweptOpenFor case final swept?) 'swept_open_minutes': swept.inMinutes,
  };
}

/// How the checklist skips a door that keeps failing on a network.
///
/// Without these the skip lasts until the UTC day ends, which in Tehran is
/// 03:30 the next morning, even for a door that failed only in one bad
/// hour. On 2026-10-09 one address carried a phone's tunnel at 08:29
/// Tehran and again at 10:13.
class SkipSettings {
  const SkipSettings({required this.failures, required this.skipFor});

  /// Failures in one UTC day on one network before a door is skipped
  /// (`skip_after_failures`).
  final int failures;

  /// How long the skip lasts after the door's latest failure
  /// (`skip_minutes`).
  final Duration skipFor;

  static SkipSettings? _fromJson(Map<dynamic, dynamic> json) {
    final failures = _positive(json['skip_after_failures']);
    final minutes = _positive(json['skip_minutes']);
    if (failures == null || minutes == null) return null;
    return SkipSettings(
      failures: failures,
      skipFor: Duration(minutes: minutes),
    );
  }

  Map<String, dynamic> _toJson() => {
    'skip_after_failures': failures,
    'skip_minutes': skipFor.inMinutes,
  };
}

/// How the checklist goes through the shared links once none of the
/// device's own doors carried a tunnel.
///
/// Without these it checks at most six, one at a time, after the 20
/// seconds spent on the device's own doors, and those checks add many
/// seconds more. Many users stop a tap before that, and few of the
/// community links the fallback checks let data through. Checked several
/// at a time, a whole group takes about as long as one check.
class FallbackSettings {
  const FallbackSettings({
    required this.links,
    required this.parallel,
    this.after,
    this.standby,
    this.ownFirst,
    this.closedFor,
  });

  /// The most shared links one fallback checks (`fallback_links`).
  final int links;

  /// How many of them are checked at once (`fallback_parallel`).
  final int parallel;

  /// How long the device's own doors are checked before the fallback
  /// starts (`fallback_after_ms`). When none of them is open by then, the
  /// shared links are checked, and the own doors the search had not
  /// reached are checked after them when none of those is open either.
  /// Null checks every own door first, within the finder's whole budget.
  ///
  /// On 2026-10-10 a tap reached the shared links about 21 seconds in, and
  /// users stopped a tap after 12 seconds (the median).
  final Duration? after;

  /// How many of the other shared links the fallback found open, or did
  /// not reach, the core holds next to the one it dials, and moves to when
  /// that one fails (`fallback_standby`). Null or zero holds none, and a
  /// community link that dies ends the tunnel. Only where the core has
  /// standby doors (see StandbyDoors).
  final int? standby;

  /// How many of the device's own doors the next tap checks beside a
  /// shared link the fallback chose, at the same time, before dialling it
  /// (`own_first_doors`). An own door found open is dialled instead.
  /// Null dials the shared link first, as a link the user picked is, and
  /// the user stays on it while it works, however long ago our own doors
  /// came back.
  final int? ownFirst;

  /// How long a shared link found closed on this network stays behind the
  /// others in the next fallbacks (`fallback_closed_minutes`). Null keeps
  /// it there until the day ends, as before.
  ///
  /// A carrier can close every link for a few minutes, and then the links
  /// that work the rest of the day are found closed with the others. Taps
  /// then found no shared link open while links another phone on the same
  /// carrier had got through in the hour before went unchecked: this phone
  /// had found them closed earlier the same day, so they waited behind
  /// about a hundred links it had not checked yet. The backend's order
  /// already puts the links that work on the carrier now first.
  final Duration? closedFor;

  static FallbackSettings? _fromJson(Map<dynamic, dynamic> json) {
    final links = _positive(json['fallback_links']);
    final parallel = _positive(json['fallback_parallel']);
    if (links == null || parallel == null) return null;
    final after = _positive(json['fallback_after_ms']);
    final closed = _positive(json['fallback_closed_minutes']);
    return FallbackSettings(
      links: links,
      parallel: parallel,
      after: after == null ? null : Duration(milliseconds: after),
      standby: _positive(json['fallback_standby']),
      ownFirst: _positive(json['own_first_doors']),
      closedFor: closed == null ? null : Duration(minutes: closed),
    );
  }

  Map<String, dynamic> _toJson() => {
    'fallback_links': links,
    'fallback_parallel': parallel,
    if (after case final after?) 'fallback_after_ms': after.inMilliseconds,
    'fallback_standby': ?standby,
    'own_first_doors': ?ownFirst,
    if (closedFor case final closedFor?)
      'fallback_closed_minutes': closedFor.inMinutes,
  };
}

/// How the checklist checks the device's own doors: [parallel] at once,
/// the first ones [stagger] apart (`door_parallel`, `door_stagger_ms`).
///
/// One at a time a closed door costs about 3 seconds. In the 24 hours to
/// 01:00 Tehran on 2026-10-12 a checklist reached 7 or 8 of a phone's 19 to
/// 22 doors: 24 of 26 taps that ended at every door closed left doors
/// unchecked, and 15 of 39 first taps the user stopped were stopped during
/// the checks, before any dial.
///
/// Unlike the other parts, null is not what the app did before: it is
/// [standard], because a phone that cannot reach the backend is the one
/// that needs this most. `door_parallel: 1` puts back the one-at-a-time
/// search of 1.7.0, so the backend can turn this off without a release.
///
/// A value out of range counts as [standard]'s, one field at a time: a
/// [parallel] below 1 or above [mostParallel], and a [stagger] below 0 or
/// above [longestStaggerMs] milliseconds.
class DoorCheckSettings {
  const DoorCheckSettings({required this.parallel, required this.stagger});

  /// Four at once, one more each second until then. A closed door answers
  /// after about 3 seconds (the native wait), so the fourth check starts as
  /// the first closed one answers. An open one answers in about 1 to 1.5
  /// seconds (DoorSweep's device measurement), so a top door that is open
  /// is usually dialled with at most one other check started. The shared
  /// fallback checks eight at once and the sweep twelve.
  static const standard = DoorCheckSettings(
    parallel: 4,
    stagger: Duration(seconds: 1),
  );

  /// The checklist of 1.7.0.
  static const oneAtATime = DoorCheckSettings(
    parallel: 1,
    stagger: Duration.zero,
  );

  /// The most checks at once the app accepts. Each native check holds one
  /// of Dispatchers.IO's 64 threads until the core returns, which can be
  /// long after its 3 second answer, and the shared fallback's eight and
  /// abandoned own checks can run beside these.
  static const mostParallel = 8;

  /// The longest stagger the app accepts, in milliseconds. It is already
  /// longer than the native wait of about 3 seconds for a closed door, so
  /// with it the search is close to one at a time, and a longer one is
  /// more likely a mistake than a setting.
  static const longestStaggerMs = 5000;

  final int parallel;
  final Duration stagger;

  static DoorCheckSettings? _fromJson(Map<dynamic, dynamic> json) {
    final parallel = _within(json['door_parallel'], 1, mostParallel);
    final ms = _within(json['door_stagger_ms'], 0, longestStaggerMs);
    if (parallel == null && ms == null) return null;
    return DoorCheckSettings(
      parallel: parallel ?? standard.parallel,
      stagger: ms == null ? standard.stagger : Duration(milliseconds: ms),
    );
  }

  Map<String, dynamic> _toJson() => {
    'door_parallel': parallel,
    'door_stagger_ms': stagger.inMilliseconds,
  };
}

/// How long the dial of the door that last worked on this network (the
/// fast path) runs on its own (`fast_path_beside_ms`), and how long it
/// must have run for a stop to forget that door (`fast_path_forget_ms`).
///
/// On Tehran day 2026-10-23, 113 such dials failed, at about 21 seconds
/// each, and only then did the checklist start. 564 taps were stopped, on
/// 159 phones, and users stopped a tap after 10 to 15 seconds. A dial that
/// works is verified within a few seconds. Past [besideAfter] the
/// checklist starts beside the dial, and the first of the two to find a
/// way carries the tunnel. A door the checklist finds open first is
/// dialled in place of the remembered one.
///
/// As with DoorCheckSettings, null is not what the app did before: it is
/// [standard], because a phone that cannot reach the backend gains the
/// most. Each key is read on its own. 0 turns its part off, which is what
/// the app did before. A value that is missing, not a whole number, below
/// 0 or above [longestMs] counts as [standard]'s, and a block with no
/// usable value for either is no part.
class FastPathSettings {
  const FastPathSettings({this.besideAfter, this.forgetAfter});

  /// Five seconds for both. The fast path's dial of a door that works is
  /// verified in about two seconds.
  static const standard = FastPathSettings(
    besideAfter: Duration(seconds: 5),
    forgetAfter: Duration(seconds: 5),
  );

  /// The longest value the app accepts, in milliseconds: the longest a
  /// dial waits for its tunnel (ConnectFlow.attemptTimeout). A longer one
  /// would never be reached.
  static const longestMs = 45000;

  /// How long the remembered door's dial runs alone before the checklist
  /// starts beside it. Null: the checklist waits for the dial to fail.
  final Duration? besideAfter;

  /// How long that dial must have run for a stop by the user to forget the
  /// door (PathMemory.forget), so the next tap starts with the checklist.
  /// Not counted as a failure. Null: a stop forgets nothing.
  final Duration? forgetAfter;

  static FastPathSettings? _fromJson(Map<dynamic, dynamic> json) {
    final beside = _within(json['fast_path_beside_ms'], 0, longestMs);
    final forget = _within(json['fast_path_forget_ms'], 0, longestMs);
    if (beside == null && forget == null) return null;
    Duration? read(int? ms, Duration? otherwise) {
      if (ms == null) return otherwise;
      return ms == 0 ? null : Duration(milliseconds: ms);
    }

    return FastPathSettings(
      besideAfter: read(beside, standard.besideAfter),
      forgetAfter: read(forget, standard.forgetAfter),
    );
  }

  Map<String, dynamic> _toJson() => {
    'fast_path_beside_ms': besideAfter?.inMilliseconds ?? 0,
    'fast_path_forget_ms': forgetAfter?.inMilliseconds ?? 0,
  };
}

/// When a tap that found nothing open tries again by itself.
///
/// Without these it ends at "All routes are blocked" and the user has to
/// tap again. Many such taps were on networks where most community links
/// were cut at TCP as well as our own doors: no order of links would have
/// helped, only trying again a little later.
///
/// Past the waits in [after], the tap keeps searching until data flows,
/// each wait twice the one before it, up to [longest]. Until 2026-10-13 it
/// stopped after the backend's four waits, about two and a half minutes
/// in all. In Iran's cuts of June 2025 and January 2026 a way through
/// opened and closed over hours, and a phone that had stopped trying
/// missed it unless its user tapped at the right moment.
class RetrySettings {
  const RetrySettings({required this.after, this.longest, this.recheck});

  /// The waits of a phone the backend has never answered
  /// (ChecklistSettings.builtIn): the backend's own default for
  /// CHECKLIST_RETRY_SECONDS on 2026-10-13, then [standardLongest].
  static const standard = RetrySettings(
    after: [
      Duration(seconds: 5),
      Duration(seconds: 10),
      Duration(seconds: 20),
      Duration(seconds: 30),
    ],
    longest: standardLongest,
    recheck: standardRecheck,
  );

  /// The longest wait between two tries when the backend does not say
  /// (`retry_longest_seconds` missing). A try costs a few door checks of a few
  /// kilobytes each, so a phone that keeps searching all day spends less
  /// than a minute of video.
  static const standardLongest = Duration(minutes: 10);

  /// How often a wait after no internet asks whether the way abroad is
  /// back when the backend does not say (`retry_recheck_seconds` missing).
  /// One request of a few hundred bytes, which fails at once on a phone
  /// with no network at all.
  static const standardRecheck = Duration(seconds: 20);

  /// How long to wait before each try, in order (`retry_seconds`).
  final List<Duration> after;

  /// The longest wait once [after] is used up (`retry_longest_seconds`).
  /// Null stops trying after the waits in [after], as before 1.9.0; the
  /// backend says so with 0.
  final Duration? longest;

  /// How often a wait after no internet or a cut way abroad asks a site
  /// abroad whether the way is back, and tries at once when it is
  /// (`retry_recheck_seconds`). Null asks nothing, and the wait runs its
  /// length, as before 2.2.0; the backend says so with 0.
  ///
  /// In the 72 hours to 2026-10-20 21:00 UTC, 248 of 493 tunnels that
  /// stopped carrying data in the middle of a session did so on a phone
  /// whose own internet was gone, and those phones were connected again a
  /// median of 15 minutes later. Internet that comes back on the same
  /// network brings no network change, and by the fifth try the waits are
  /// 1 to 10 minutes long.
  final Duration? recheck;

  /// The wait before try number [i], counted from 0, or null when no try
  /// is left.
  Duration? waitBefore(int i) {
    if (i < 0) return null;
    if (i < after.length) return after[i];
    final most = longest;
    if (most == null || after.isEmpty) return null;
    var wait = after.last;
    for (var k = after.length; k <= i && wait < most; k++) {
      wait *= 2;
    }
    return wait < most ? wait : most;
  }

  static RetrySettings? _fromJson(Map<dynamic, dynamic> json) {
    final raw = json['retry_seconds'];
    if (raw is! List || raw.isEmpty) return null;
    final seconds = [for (final s in raw) _positive(s)];
    if (seconds.any((s) => s == null)) return null;
    final raw2 = json['retry_longest_seconds'];
    final most = raw2 == null
        ? standardLongest
        : _within(raw2, 1, _longestSeconds) == null
        ? null
        : Duration(seconds: raw2 as int);
    final raw3 = json['retry_recheck_seconds'];
    final recheck = raw3 == null
        ? standardRecheck
        : _within(raw3, _fewestRecheckSeconds, _mostRecheckSeconds) == null
        ? null
        : Duration(seconds: raw3 as int);
    return RetrySettings(
      after: [for (final s in seconds) Duration(seconds: s!)],
      longest: most,
      recheck: recheck,
    );
  }

  /// One whole day, in seconds. A longer wait is more likely a mistake
  /// than a setting.
  static const _longestSeconds = 86400;

  /// The range a recheck may be set to. Under 5 seconds a phone with no
  /// internet would wake its radio for little; over an hour it would be
  /// slower than the waits it is there to cut short.
  static const _fewestRecheckSeconds = 5;
  static const _mostRecheckSeconds = 3600;

  Map<String, dynamic> _toJson() => {
    'retry_seconds': [for (final d in after) d.inSeconds],
    'retry_longest_seconds': longest?.inSeconds ?? 0,
    'retry_recheck_seconds': recheck?.inSeconds ?? 0,
  };
}

/// A whole number above zero, or null for anything else.
int? _positive(Object? value) => value is int && value > 0 ? value : null;

/// A whole number from [least] to [most], or null for anything else.
int? _within(Object? value, int least, int most) =>
    value is int && value >= least && value <= most ? value : null;
