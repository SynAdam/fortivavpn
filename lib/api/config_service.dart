import 'api_client.dart';
import '../data/models/door_outbound.dart';
import '../data/models/probe_candidate.dart';
import '../data/models/server.dart';
import '../data/models/variant_test.dart';

/// The slice of [ConfigService] that [ServerRepository] depends on.
///
/// Exists so the repository can be exercised against a fake without a
/// network stack. [ConfigService] itself is a singleton with a private
/// constructor, which cannot be subclassed from another library.
abstract interface class ServerConfigSource {
  Future<List<Server>> getOfficialConfigs();
  Future<List<String>> getCommunityConfigs();
}

/// The slice [CandidateProber] depends on, for the same reason.
abstract interface class CandidateSource {
  Future<List<ProbeCandidate>> getProbeCandidates();
}

/// Service for fetching VPN server configurations
class ConfigService implements ServerConfigSource, CandidateSource {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  final ApiClient _client = ApiClient();

  /// Get all official configs from backend
  ///
  /// GET /api/v1/configs/official
  ///
  /// Returns a list of Server objects parsed from the API response
  @override
  Future<List<Server>> getOfficialConfigs() async {
    final response = await _client.get('/api/v1/configs/official');

    if (response is! List) {
      throw ApiException(
        statusCode: 0,
        message: 'Invalid response format: expected array',
      );
    }

    return response
        .map((json) => Server.fromApiJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get community configs (from Telegram channels and other sources)
  ///
  /// GET /api/v1/configs/community
  ///
  /// Returns a list of raw connection URI strings
  @override
  Future<List<String>> getCommunityConfigs() async {
    final response = await _client.get('/api/v1/configs/community');

    if (response is! List) {
      throw ApiException(
        statusCode: 0,
        message: 'Invalid response format: expected array',
      );
    }

    return response.cast<String>();
  }

  /// Get the links an operator wants measured from this network.
  ///
  /// GET /api/v1/configs/candidates
  ///
  /// Almost always empty. These are NOT servers: they are dialled once by
  /// the delay test so the backend can learn whether they work from inside
  /// Iran, and must never be offered to the user as something to connect
  /// through. Malformed rows are dropped rather than failing the batch, so
  /// one bad entry cannot stop the rest being measured.
  @override
  Future<List<ProbeCandidate>> getProbeCandidates() async {
    final response = await _client.get('/api/v1/configs/candidates');

    if (response is! List) {
      throw ApiException(
        statusCode: 0,
        message: 'Invalid response format: expected array',
      );
    }

    return [
      for (final row in response)
        if (row is Map<String, dynamic>) ?ProbeCandidate.fromJson(row),
    ];
  }
}

/// Rolling-quota status for the device's dedicated access.
class QuotaStatus {
  final bool unlimited;
  final int limitBytes;
  final int usedBytes;
  final int remainingBytes;
  final bool blocked;
  final DateTime? resetsAt;

  /// How much of [limitBytes] was earned by inviting people. Reported by
  /// the backend so the allowance can be broken down without asking for a
  /// referral code first, which would mint one for every device.
  final int bonusBytes;

  const QuotaStatus({
    required this.unlimited,
    required this.limitBytes,
    required this.usedBytes,
    required this.remainingBytes,
    required this.blocked,
    this.resetsAt,
    this.bonusBytes = 0,
  });

  factory QuotaStatus.fromJson(Map<String, dynamic> json) {
    final resets = json['resets_at'] as String?;
    return QuotaStatus(
      unlimited: json['unlimited'] as bool? ?? false,
      limitBytes: json['limit_bytes'] as int? ?? 0,
      usedBytes: json['used_bytes'] as int? ?? 0,
      remainingBytes: json['remaining_bytes'] as int? ?? 0,
      blocked: json['blocked'] as bool? ?? false,
      resetsAt: resets == null ? null : DateTime.tryParse(resets),
      bonusBytes: json['bonus_bytes'] as int? ?? 0,
    );
  }

  double get usedFraction =>
      (unlimited || limitBytes == 0) ? 0 : (usedBytes / limitBytes).clamp(0, 1);

  /// Whether any of this allowance came from invites.
  bool get hasReferralBonus => !unlimited && bonusBytes > 0;
}

/// One way into one server: a door, with the link that goes through it.
///
/// The backend returns every door of every reachable server, in the order
/// to try them for the network the request came from. `preferred` marks
/// the one a phone with no memory of its own should dial first.
class DedicatedPath {
  final int serverId;
  final int inboundId;
  final String door;
  final String label;
  final String uri;
  final bool preferred;

  /// Milliseconds the core's door group adds to this door's score: the
  /// backend's measure of how often the door fails in the middle of a
  /// session, which the core's probes cannot see. A door can answer probes
  /// fast and still be left far more often than the others, and without
  /// this the core kept choosing it. 0 for none, and for every door from a
  /// backend older than the field.
  final int penaltyMs;

  /// The backend's own outbound for this door, when it sent one
  /// ([DoorOutbound]). Null for every door from a backend that sends none,
  /// and the door is then dialled from [uri] alone.
  final DoorOutbound? outbound;

  const DedicatedPath({
    required this.serverId,
    required this.inboundId,
    required this.door,
    required this.label,
    required this.uri,
    this.preferred = false,
    this.penaltyMs = 0,
    this.outbound,
  });

  factory DedicatedPath.fromJson(Map<String, dynamic> json) => DedicatedPath(
    serverId: (json['server_id'] as num?)?.toInt() ?? 0,
    inboundId: (json['inbound_id'] as num?)?.toInt() ?? 0,
    door: json['door'] as String? ?? '',
    label: json['label'] as String? ?? '',
    uri: json['uri'] as String? ?? '',
    preferred: json['preferred'] as bool? ?? false,
    penaltyMs: penaltyOf(json['penalty_ms']),
    outbound: DoorOutbound.fromPath(json),
  );

  /// The core holds a penalty as a 32-bit number.
  static const maxPenaltyMs = 0x7fffffff;

  /// [value] as a penalty: 0 for anything that is not a positive number,
  /// so a malformed field costs that door its penalty, not the whole list.
  static int penaltyOf(Object? value) {
    if (value is! num || !value.isFinite || value <= 0) return 0;
    return value >= maxPenaltyMs ? maxPenaltyMs : value.toInt();
  }

  bool get isUsable => uri.isNotEmpty && door.isNotEmpty;
}

/// What a test point is told: how often to check every door, and which
/// ClientHello splits to try on the TLS doors. Only a phone the team keeps
/// inside Iran as a test point is sent one.
class TestPointConfig {
  const TestPointConfig({required this.interval, required this.specs});

  final Duration interval;
  final List<String> specs;

  /// Null when the backend sent none, or one that cannot be used.
  static TestPointConfig? fromJson(Object? json) {
    if (json is! Map) return null;
    final seconds = json['interval_seconds'];
    if (seconds is! int || seconds < 60) return null;
    final specs = (json['specs'] as List? ?? const [])
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
    return TestPointConfig(
      interval: Duration(seconds: seconds),
      specs: specs,
    );
  }
}

/// A carrier's paired door test, as one phone runs it.
///
/// The backend compares a new ClientHello setting with the current one by
/// having every phone on the carrier check one of its TLS doors twice after
/// it connects: as the phone has it, and as [testUri], one after the other
/// in random order. Nobody's connection changes. See DoorPairRunner.
class DoorPairCheck {
  const DoorPairCheck({
    required this.experimentId,
    required this.serverId,
    required this.door,
    required this.testUri,
    required this.interval,
    required this.gap,
    required this.timeout,
  });

  final int experimentId;

  /// Which of the phone's doors to check: [door] on server [serverId].
  final int serverId;
  final String door;

  /// That door's link with the test's setting written in.
  final String testUri;

  /// At most one round per network this often.
  final Duration interval;

  /// How long between the two checks of a round.
  final Duration gap;

  /// How long each check gets.
  final Duration timeout;

  /// Null when the backend sent none, or one that cannot be used.
  static DoorPairCheck? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['experiment_id'];
    final serverId = json['server_id'];
    final door = json['door'];
    final testUri = json['test_uri'];
    final interval = json['interval_seconds'];
    final gap = json['gap_ms'];
    final timeout = json['timeout_ms'];
    if (id is! int ||
        serverId is! int ||
        door is! String ||
        door.isEmpty ||
        testUri is! String ||
        testUri.isEmpty ||
        interval is! int ||
        interval < 60 ||
        gap is! int ||
        gap < 0 ||
        timeout is! int ||
        timeout <= 0) {
      return null;
    }
    return DoorPairCheck(
      experimentId: id,
      serverId: serverId,
      door: door,
      testUri: testUri,
      interval: Duration(seconds: interval),
      gap: Duration(milliseconds: gap),
      timeout: Duration(milliseconds: timeout),
    );
  }
}

/// The device's own configs plus where it stands against its quota.
class DedicatedConfigs {
  /// One URI per reachable server, already ordered by the backend. The app
  /// should fail over through them locally rather than re-requesting: a
  /// server being down is exactly when the network is least dependable.
  final List<String> configs;

  /// Every door on every reachable server, in the order to try them. Empty
  /// from a backend that predates doors; the app then walks [configs].
  final List<DedicatedPath> paths;
  final QuotaStatus quota;

  /// Set only on a test point. See [TestPointConfig].
  final TestPointConfig? testPoint;

  /// Set while the phone's carrier has a paired door test. See
  /// [DoorPairCheck].
  final DoorPairCheck? doorPair;

  /// Whether this device may use the backup network (PsiphonSettings), or
  /// null from a backend older than the field.
  final bool? psiphon;

  /// Variants of this device's doors to check in the background. See
  /// [VariantTest]. Empty unless the backend's variant tests are on for
  /// this build.
  final List<VariantTest> variantTests;

  /// How the variant tests are run, or null when the answer says nothing
  /// usable, which runs none. See [VariantTestParams].
  final VariantTestParams? variantTestParams;

  /// The backend's answer as it came, so the phone can keep it for a launch
  /// that cannot reach the backend. Null when built in code.
  final Map<String, dynamic>? raw;

  const DedicatedConfigs({
    required this.configs,
    required this.quota,
    this.paths = const [],
    this.testPoint,
    this.doorPair,
    this.psiphon,
    this.variantTests = const [],
    this.variantTestParams,
    this.raw,
  });

  factory DedicatedConfigs.fromJson(Map<String, dynamic> json) {
    return DedicatedConfigs(
      raw: json,
      configs: (json['configs'] as List? ?? const [])
          .map((e) => e as String)
          .toList(),
      paths: (json['paths'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => DedicatedPath.fromJson(m.cast<String, dynamic>()))
          .where((p) => p.isUsable)
          .toList(),
      quota: QuotaStatus.fromJson(
        (json['quota'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      testPoint: TestPointConfig.fromJson(json['test_point']),
      doorPair: DoorPairCheck.fromJson(json['door_pair']),
      psiphon: json['psiphon'] is bool ? json['psiphon'] as bool : null,
      variantTests: VariantTest.listFromJson(json['variant_tests']),
      variantTestParams: VariantTestParams.fromJson(
        json['variant_test_params'],
      ),
    );
  }
}

extension DedicatedConfigApi on ConfigService {
  /// Fetch this device's dedicated configs, provisioning them on first call.
  ///
  /// POST /api/v1/configs/dedicated
  ///
  /// Safe to call on every launch: the backend is idempotent. When the
  /// device is over quota the server returns no configs at all, so there is
  /// nothing usable for the app to fall back onto by accident.
  ///
  /// [viaTunnel] says whether this request leaves through the tunnel. The
  /// backend orders the doors for the network the request came from, and
  /// can only tell which that is when the request went around the tunnel.
  /// Null when the app does not know, which the backend treats as through.
  Future<DedicatedConfigs> getDedicatedConfigs(
    String deviceId, {
    bool? viaTunnel,
  }) async {
    final response = await ApiClient().post(
      '/api/v1/configs/dedicated',
      // door_pairs: this build runs paired door checks (DoorPairRunner).
      body: {
        'device_id': deviceId,
        'via_tunnel': ?viaTunnel,
        'door_pairs': true,
      },
    );

    if (response is! Map) {
      throw ApiException(
        statusCode: 0,
        message: 'Invalid response format: expected object',
      );
    }

    return DedicatedConfigs.fromJson(response.cast<String, dynamic>());
  }
}
