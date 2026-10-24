import '../../utils/state_platforms.dart';

/// One variant of one of this phone's own doors, which the backend wants
/// measured from the phone's network (`variant_tests` in the
/// /configs/dedicated answer).
///
/// The backend sends the core config the check runs ([config]), with this
/// phone's own client id in it, so it carries a credential like every door
/// link. Nothing in the app may connect through it, list it or show it. It
/// is checked once in a core of its own (VariantTester), the result is
/// reported under [assignmentId], and then it is forgotten.
///
/// It has a type of its own so that it cannot reach the server list by
/// being passed to the wrong function. ProbeCandidate is kept apart from
/// [Server] for the same reason.
class VariantTest {
  const VariantTest({
    required this.assignmentId,
    required this.variantKey,
    required this.door,
    required this.deadline,
    this.uri = '',
    this.config,
    this.serverId,
  });

  /// The backend's id for this hand-out, which the result is filed under.
  final int assignmentId;

  /// The variant's name on the backend ("xhttp-reality#v=a3f1c2d0e5b4"),
  /// for the app's log. Never shown to the user.
  final String variantKey;

  /// The server whose link the variant is written onto, when it is one of
  /// ours.
  final int? serverId;

  /// The plain door id of that link ("xhttp-reality-v6"), never a variant
  /// key. For the log only.
  final String door;

  /// The variant's link. Dialled only when the backend sent no [config],
  /// as a backend older than the config does.
  final String uri;

  /// The core config the check runs as the backend wrote it: an outbound
  /// tagged proxy first, then any helper outbounds it refers to. Null from
  /// a backend that sends only the link.
  final Map<String, dynamic>? config;

  /// When the backend stops taking a result for it, in UTC. A test not
  /// started by then is dropped.
  final DateTime deadline;

  /// Null for a row the app cannot use: no whole id, no door, no deadline
  /// it can read, a config the check cannot run, or neither a config nor a
  /// link. Read without a cast, so one bad row never throws away the rest
  /// of the answer.
  static VariantTest? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['assignment_id'];
    final door = json['door'];
    final uri = json['uri'];
    final deadline = DateTime.tryParse('${json['deadline']}');
    final config = json['config'];
    if (id is! int || door is! String || door.isEmpty || deadline == null) {
      return null;
    }
    if (config != null && !runnable(config)) return null;
    final link = uri is String ? uri : '';
    if (config == null && link.isEmpty) return null;
    final key = json['variant_key'];
    final serverId = json['server_id'];
    return VariantTest(
      assignmentId: id,
      variantKey: key is String && key.isNotEmpty ? key : door,
      serverId: serverId is int ? serverId : null,
      door: door,
      uri: link,
      config: config == null
          ? null
          : Map<String, dynamic>.from(config as Map<dynamic, dynamic>),
      deadline: deadline.toUtc(),
    );
  }

  /// Whether [config] is one the door check can run: an object whose
  /// `outbounds` list starts with an object tagged proxy that names a
  /// protocol. The check dials the first outbound. The Android side reads
  /// it by the same rule (DoorOutbounds.checkConfig).
  static bool runnable(Object? config) {
    if (config is! Map) return false;
    final outbounds = config['outbounds'];
    if (outbounds is! List || outbounds.isEmpty) return false;
    final first = outbounds.first;
    if (first is! Map || first['tag'] != 'proxy') return false;
    final protocol = first['protocol'];
    return protocol is String && protocol.trim().isNotEmpty;
  }

  /// The usable rows of a `variant_tests` list, in the order sent. Empty
  /// when the answer has none, which is every answer while the backend's
  /// VARIANT_TESTS switch is off.
  static List<VariantTest> listFromJson(Object? json) {
    if (json is! List) return const [];
    return [for (final row in json) ?fromJson(row)];
  }
}

/// How the phone runs the variant tests of an answer:
/// `variant_test_params` in the /configs/dedicated answer (variant loop
/// contract v2, section 1). The app has no value of its own for any of
/// these: an answer whose parameters are missing, or any of the first five
/// unusable, runs no variant test at all. The optional [backgroundEvery]
/// never stops a test.
class VariantTestParams {
  const VariantTestParams({
    required this.testUrl,
    required this.timeout,
    required this.maxPerRun,
    required this.minGap,
    required this.onlyWhenTunnelDown,
    this.backgroundEvery,
  });

  /// What each check fetches through the variant.
  final String testUrl;

  /// How long the core waits for data in each check.
  final Duration timeout;

  /// The most tests one run dials.
  final int maxPerRun;

  /// The least time from one run that dialled to the next.
  final Duration minGap;

  /// Whether a test may run only while the tunnel is down. False lets one
  /// run beside a connected tunnel; the check never goes through it.
  final bool onlyWhenTunnelDown;

  /// How often the tests are tried while the app is out of sight
  /// (`background_minutes`). Null, as from a backend without the key,
  /// tries them in the background only when an answer arrives or the
  /// network changes, as 2.0.0 does.
  final Duration? backgroundEvery;

  /// Null when [json] is not an object, or any value is missing or not of
  /// a usable type: an http or https URL the app may ask
  /// (StatePlatforms.mayAsk), a wait above zero, at least one test per run,
  /// a gap of zero or more, and a yes or no.
  ///
  /// `background_minutes` is optional. Missing, or anything but a whole
  /// number from 1 to 1440, it reads as none and the rest still count, so
  /// a bad value never stops the tests a build without the key would run.
  static VariantTestParams? fromJson(Object? json) {
    if (json is! Map) return null;
    final url = json['test_url'];
    final timeout = json['timeout_ms'];
    final perRun = json['max_per_run'];
    final gap = json['min_gap_minutes'];
    final down = json['only_when_tunnel_down'];
    final background = json['background_minutes'];
    if (url is! String ||
        timeout is! int ||
        timeout <= 0 ||
        perRun is! int ||
        perRun <= 0 ||
        gap is! int ||
        gap < 0 ||
        down is! bool) {
      return null;
    }
    final parsed = Uri.tryParse(url.trim());
    if (parsed == null ||
        !(parsed.isScheme('http') || parsed.isScheme('https')) ||
        parsed.host.isEmpty ||
        !StatePlatforms.mayAsk(url)) {
      return null;
    }
    return VariantTestParams(
      testUrl: url.trim(),
      timeout: Duration(milliseconds: timeout),
      maxPerRun: perRun,
      minGap: Duration(minutes: gap),
      onlyWhenTunnelDown: down,
      backgroundEvery:
          background is int && background >= 1 && background <= 1440
          ? Duration(minutes: background)
          : null,
    );
  }
}
