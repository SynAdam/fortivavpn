import 'package:flutter/foundation.dart';

import '../data/models/billing.dart';
import 'api_client.dart';

/// Where this device stands in the referral program.
///
/// [code] is this device's own invite code. [claimedCode] is the code it
/// used when somebody else invited it, which is null for most devices.
class ReferralStatus {
  final String code;
  final String shareUrl;

  /// Devices that entered this code. Not all of them pay: a referral is
  /// only worth bytes once the invited device has really used the VPN.
  final int invitedCount;
  final int confirmedCount;

  /// Bonus quota currently in effect, in bytes, already included in the
  /// limit reported by the dedicated-configs endpoint.
  final int bonusBytes;

  /// Normally null, because grants do not expire. Set only when a grant
  /// has been given an end date by hand on the backend.
  final DateTime? bonusExpiresAt;

  final String? claimedCode;

  /// What one confirmed friend adds to the daily allowance, in bytes.
  /// Null when the backend did not say. The invite screen names this
  /// number, so the reward is set by the backend alone and changing it
  /// never needs an app release.
  final int? bonusPerReferralBytes;

  /// The most that invites can add per day, in bytes. Null when the
  /// backend did not say.
  final int? maxBonusBytes;

  /// How long after registering a new install may enter a code, in hours.
  /// Null when the backend did not say, and then the app names no number.
  final int? claimWindowHours;

  /// On how many different days an invited device must use the VPN before
  /// the invite pays. Null when the backend did not say, and then the app
  /// names no number.
  final int? confirmActiveDays;

  /// Apps hidden from every invite share sheet: the state messengers
  /// (INVITE_SHARE_EXCLUDE_PACKAGES). Empty when the backend sent none. The
  /// app always hides its own built-in list too (InviteShare.excludeFor).
  final List<String> shareExcludePackages;

  /// The Premium days the next confirmed friend gives this device. Null
  /// when [earns] is false or the backend sent no number.
  final int? rewardPremiumDays;

  /// Premium days per confirmed friend while invites give Premium, else
  /// null.
  final int? premiumDaysEach;

  /// Premium days this device has earned from invites so far.
  final int premiumDaysEarned;

  /// The most Premium days one device can earn from invites, or null.
  final int? premiumDaysMax;

  /// Whether a confirmed friend still gives this device Premium days.
  final bool earns;

  /// Until when this install may still enter a code, or null.
  final DateTime? claimOpenUntil;

  /// Which rule the backend pays invites by: "tree" for the invite tree,
  /// null when it did not say (today's rule, a bonus per friend).
  final String? rules;

  /// Under the tree rule, this device's own first slots, in pairs and in
  /// order. Empty under today's rule.
  final List<TreePair> pairs;

  /// Under the tree rule, the levels below this device that have at least
  /// one person, from level 1 (this device's own friends), sorted, one
  /// entry per level. Empty under today's rule.
  final List<TreeLevel> levels;

  /// What the next friend this device invites adds a day once they are
  /// active, in bytes. Null when it adds nothing or the backend did not say.
  final int? nextInviteBytes;

  /// The bonus kept from invites made under the old rule, in bytes. The
  /// bonus never drops below it. Null when there is none.
  final int? keptBytes;

  /// A friend counts while they use the VPN on at least [activeDays] days
  /// in every [activeWindowDays] days. Null when the backend did not say,
  /// and then the app names no number.
  final int? activeDays;
  final int? activeWindowDays;

  /// The most the daily allowance can reach with invites, in bytes, or
  /// null.
  final int? maxTotalBytes;

  const ReferralStatus({
    required this.code,
    required this.shareUrl,
    required this.invitedCount,
    required this.confirmedCount,
    required this.bonusBytes,
    this.bonusExpiresAt,
    this.claimedCode,
    this.bonusPerReferralBytes,
    this.maxBonusBytes,
    this.claimWindowHours,
    this.confirmActiveDays,
    this.shareExcludePackages = const [],
    this.rewardPremiumDays,
    this.premiumDaysEach,
    this.premiumDaysEarned = 0,
    this.premiumDaysMax,
    this.earns = false,
    this.claimOpenUntil,
    this.rules,
    this.pairs = const [],
    this.levels = const [],
    this.nextInviteBytes,
    this.keptBytes,
    this.activeDays,
    this.activeWindowDays,
    this.maxTotalBytes,
  });

  factory ReferralStatus.fromJson(Map<String, dynamic> json) {
    final expires = json['bonus_expires_at'] as String?;
    return ReferralStatus(
      code: json['code'] as String? ?? '',
      shareUrl: json['share_url'] as String? ?? '',
      invitedCount: json['invited_count'] as int? ?? 0,
      confirmedCount: json['confirmed_count'] as int? ?? 0,
      bonusBytes: json['bonus_bytes'] as int? ?? 0,
      bonusExpiresAt: expires == null ? null : DateTime.tryParse(expires),
      claimedCode: json['claimed_code'] as String?,
      bonusPerReferralBytes: _positiveBytes(json['bonus_per_referral_bytes']),
      maxBonusBytes: _positiveBytes(json['max_bonus_bytes']),
      claimWindowHours: _positiveInt(json['claim_window_hours']),
      confirmActiveDays: _positiveInt(json['confirm_active_days']),
      shareExcludePackages: [
        for (final p in readList(json['share_exclude_packages']))
          if (p is String && p.isNotEmpty) p,
      ],
      rewardPremiumDays: _positiveInt(json['reward_premium_days']),
      premiumDaysEach: _positiveInt(json['premium_days_each']),
      premiumDaysEarned: _positiveInt(json['premium_days_earned']) ?? 0,
      premiumDaysMax: _positiveInt(json['premium_days_max']),
      earns: json['earns'] == true,
      claimOpenUntil: readTime(json['claim_open_until']),
      rules: readText(json['rules']),
      pairs: [for (final p in readList(json['pairs'])) ?TreePair.fromJson(p)],
      levels: TreeLevel.listFromJson(json['levels']),
      nextInviteBytes: _positiveBytes(json['next_invite_bytes']),
      keptBytes: _positiveBytes(json['kept_bytes']),
      activeDays: _positiveInt(json['active_days']),
      activeWindowDays: _positiveInt(json['active_window_days']),
      maxTotalBytes: _positiveBytes(json['max_total_bytes']),
    );
  }

  /// Whether the backend pays invites by the invite tree. Under that rule
  /// no text may say the bonus stays, so this is true whenever the backend
  /// says so, even when it sent no slots that could be read. The screen
  /// then leaves out the slots and names no number of slots.
  bool get isTree => rules == 'tree';

  /// Whether the bonus is above the part kept from the old rule. The bonus
  /// never drops below [keptBytes], so only then would a friend who stops
  /// lower it.
  bool get bonusAboveKept => bonusBytes > (keptBytes ?? 0);

  /// How many slots this device has of its own, counted from [pairs].
  int get treeSlots => pairs.fold(0, (n, p) => n + p.slots.length);

  /// A byte count the backend may or may not send. Backends older than
  /// these fields send nothing, so anything that is not a positive whole
  /// number reads as null instead of failing the whole status.
  static int? _positiveBytes(Object? value) {
    if (value is int) return value > 0 ? value : null;
    if (value is double &&
        value.isFinite &&
        value > 0 &&
        value == value.truncateToDouble()) {
      return value.toInt();
    }
    return null;
  }

  /// A byte count where zero is a real answer, such as what a pair pays
  /// now. Anything that is not a whole number of zero or more reads as
  /// null.
  static int? _bytesOrZero(Object? value) =>
      value == 0 ? 0 : _positiveBytes(value);

  /// A count the backend may or may not send, such as hours or days.
  /// Anything that is not a whole number above zero reads as null, so the
  /// screen falls back to text that names no number.
  static int? _positiveInt(Object? value) =>
      value is int && value > 0 ? value : null;

  /// A count where zero is a real answer, such as how many people on a
  /// level are active. Null for anything else.
  static int? _countOrZero(Object? value) =>
      value is int && value >= 0 ? value : null;

  /// Invites that have been accepted but have not earned anything yet,
  /// because the invited device has not used the VPN enough.
  int get pendingCount {
    final pending = invitedCount - confirmedCount;
    return pending < 0 ? 0 : pending;
  }

  bool get hasClaimed => claimedCode != null;
}

/// One slot of a pair under the tree rule.
enum TreeSlot {
  /// Nobody is in it yet.
  empty,

  /// A friend whose invite qualified is in it but is not active now. The
  /// backend's word for it is "joined"; the screen says "Not active now".
  joined,

  /// A friend is in it and is active.
  active;

  /// The slot for the backend's word. Anything else reads as empty, so a
  /// word a newer backend adds never claims a friend is active.
  static TreeSlot fromWire(Object? value) => switch (value) {
    'active' => TreeSlot.active,
    'joined' => TreeSlot.joined,
    _ => TreeSlot.empty,
  };
}

/// One pair of this device's own slots under the tree rule.
class TreePair {
  /// The two slots of the pair, in order. Always two: a slot the backend
  /// left out reads as empty.
  final List<TreeSlot> slots;

  /// What the pair pays a day when both are active, or null.
  final int? fullBytes;

  /// What one active person alone pays a day. Zero means one alone pays
  /// nothing. Null when the backend did not say.
  final int? oneBytes;

  /// What the pair pays a day now, zero included, or null.
  final int? nowBytes;

  const TreePair({
    required this.slots,
    this.fullBytes,
    this.oneBytes,
    this.nowBytes,
  });

  /// The pair in [value], or null when it is not an object.
  static TreePair? fromJson(Object? value) {
    if (value is! Map) return null;
    final states = readList(value['states']);
    return TreePair(
      slots: [
        for (var i = 0; i < _slotsPerPair; i++)
          TreeSlot.fromWire(i < states.length ? states[i] : null),
      ],
      fullBytes: ReferralStatus._positiveBytes(value['full_bytes']),
      oneBytes: ReferralStatus._bytesOrZero(value['one_bytes']),
      nowBytes: ReferralStatus._bytesOrZero(value['now_bytes']),
    );
  }

  /// A pair is two slots. This is what the word means, not a rule the
  /// backend sets.
  static const _slotsPerPair = 2;

  /// Whether every slot holds an active friend.
  bool get full => slots.every((s) => s == TreeSlot.active);
}

/// One level below this device under the tree rule. Level 1 is this
/// device's own friends, level 2 the people in their slots, and so on.
class TreeLevel {
  final int level;

  /// People on this level, and how many of them are active now.
  final int people;
  final int active;

  /// What this level pays a day now, zero included, or null.
  final int? bytes;

  const TreeLevel({
    required this.level,
    required this.people,
    required this.active,
    this.bytes,
  });

  /// The levels in [value], sorted by level. The first entry for a level
  /// number wins and later ones are dropped. An entry with nobody in it,
  /// or with more active people than people, is left out, so the screen
  /// never shows a count that cannot be true.
  static List<TreeLevel> listFromJson(Object? value) {
    final byLevel = <int, TreeLevel>{};
    for (final item in readList(value)) {
      final level = fromJson(item);
      if (level == null) continue;
      if (level.people == 0 || level.active > level.people) continue;
      byLevel.putIfAbsent(level.level, () => level);
    }
    return byLevel.values.toList()..sort((a, b) => a.level - b.level);
  }

  /// The level in [value], or null when it is not an object or its level
  /// or counts are not whole numbers.
  static TreeLevel? fromJson(Object? value) {
    if (value is! Map) return null;
    final level = ReferralStatus._positiveInt(value['level']);
    final people = ReferralStatus._countOrZero(value['people']);
    final active = ReferralStatus._countOrZero(value['active']);
    if (level == null || people == null || active == null) return null;
    return TreeLevel(
      level: level,
      people: people,
      active: active,
      bytes: ReferralStatus._bytesOrZero(value['bytes']),
    );
  }
}

/// Why a claim was refused.
///
/// Read from the backend's `reason` slug when it sends one, else from the
/// HTTP status. The app decides what to say, so only the shape of the
/// failure travels.
enum ReferralClaimFailure {
  /// This device already used a different code. Claiming is once per
  /// device, ever.
  alreadyClaimed,

  /// The claim window (claim_window_hours) after the install has passed
  /// (`too_late`).
  tooLate,

  /// No device holds this code, or it is not a code at all
  /// (`unknown_code`, `invalid_code`).
  unknownCode,

  /// The device's own code (`self_referral`).
  ownCode,

  /// The owner of the code was invited by this device
  /// (`mutual_referral`).
  mutual,

  /// A 422 with no slug this build knows, such as from an older backend.
  rejected,

  /// Too many tries (429). Worth trying again later, unlike [rejected].
  limited,

  /// A status the claim route does not send, such as a 403 or a 400 from
  /// something on the way. The code may still be good, so the install
  /// referrer keeps it for a later try.
  unexpected,

  /// The backend has never seen this device. The caller should register
  /// and try again.
  unknownDevice,

  network,
}

class ReferralClaimResult {
  final bool claimed;
  final ReferralClaimFailure? failure;

  /// The referrer's code as the backend stored it, on a claim that went
  /// through.
  final String? claimedCode;

  /// Whether this device had already claimed this same code, so this was a
  /// retry of a claim that went through. Still a success.
  final bool already;

  /// On how many different days this device must use the VPN before the
  /// invite pays (REFERRAL_CONFIRM_ACTIVE_DAYS), or null when not sent.
  final int? confirmActiveDays;

  const ReferralClaimResult.ok({
    this.claimedCode,
    this.already = false,
    this.confirmActiveDays,
  }) : claimed = true,
       failure = null;
  const ReferralClaimResult.failed(this.failure)
    : claimed = false,
      claimedCode = null,
      already = false,
      confirmActiveDays = null;

  /// The 200 answer of a claim. A body that is not an object still counts
  /// as a claim that went through, with nothing more known.
  factory ReferralClaimResult.fromBody(Object? body) {
    if (body is! Map) return const ReferralClaimResult.ok();
    final code = body['claimed_code'];
    return ReferralClaimResult.ok(
      claimedCode: code is String && code.isNotEmpty ? code : null,
      already: body['already'] == true,
      confirmActiveDays: ReferralStatus._positiveInt(
        body['confirm_active_days'],
      ),
    );
  }
}

/// Talks to the referral endpoints.
class ReferralService {
  static final ReferralService _instance = ReferralService._internal();
  factory ReferralService() => _instance;
  ReferralService._internal() : _client = ApiClient();

  /// A service with its own client, for tests that have no network.
  @visibleForTesting
  ReferralService.forTest({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// This device's code and earnings.
  ///
  /// GET /api/v1/devices/{device_id}/referral?lang={lang}
  ///
  /// The first call mints the code, which is why a device that never
  /// opens the invite screen never consumes one. [lang] is the app's
  /// language, so share_url opens the invite page in that language.
  Future<ReferralStatus> getStatus(String deviceId, {String? lang}) async {
    final query = lang == null || lang.isEmpty
        ? ''
        : '?lang=${Uri.encodeQueryComponent(lang)}';
    final response = await _client.get(
      '/api/v1/devices/$deviceId/referral$query',
    );
    if (response is! Map) {
      throw ApiException(
        statusCode: 0,
        message: 'Invalid response format: expected object',
      );
    }
    return ReferralStatus.fromJson(response.cast<String, dynamic>());
  }

  /// Attribute this device to whoever owns [code].
  ///
  /// POST /api/v1/devices/{device_id}/referral/claim
  ///
  /// [source] is `manual` (typed), `paste` (the Paste button or a paste
  /// into the field), `play_referrer` or `link`.
  ///
  /// Never throws for a refusal. A claim failing is an ordinary outcome
  /// on a screen the user is already looking at, and on Android it
  /// happens unprompted in the background, where an exception would be
  /// noise rather than information.
  Future<ReferralClaimResult> claim(
    String deviceId,
    String code, {
    String source = 'manual',
  }) async {
    try {
      final body = await _client.post(
        '/api/v1/devices/$deviceId/referral/claim',
        body: {'code': code, 'source': source},
      );
      return ReferralClaimResult.fromBody(body);
    } on ApiException catch (e) {
      return ReferralClaimResult.failed(failureFor(e));
    }
  }

  /// POST /api/v1/devices/{device_id}/invite-events
  ///
  /// What happened to the invite card and the invite screen, at most
  /// InviteEvents.maxQueued at a time. The backend answers 204. [sentAt]
  /// is the phone's clock as the batch goes out, so the backend can move
  /// each event onto its own clock. Throws ApiException when it fails.
  Future<void> inviteEvents(
    String deviceId,
    List<Map<String, Object?>> events, {
    required DateTime sentAt,
  }) async {
    await _client.post(
      '/api/v1/devices/$deviceId/invite-events',
      body: {'events': events, 'sent_at': sentAt.toUtc().toIso8601String()},
    );
  }

  /// The refusal in [e]. The body's shape is not assumed: the backend
  /// sends `{"detail": {"reason": ...}}` on a refusal from 1.9.0 on, a
  /// string detail before that and on 429 and 404, and FastAPI's own 422
  /// sends a list.
  @visibleForTesting
  static ReferralClaimFailure failureFor(ApiException e) {
    final b = e.body;
    final d = b is Map ? b['detail'] : null;
    final reason = d is Map ? d['reason'] : null;
    if (reason is String) {
      switch (reason) {
        case 'already_claimed':
          return ReferralClaimFailure.alreadyClaimed;
        case 'too_late':
          return ReferralClaimFailure.tooLate;
        case 'invalid_code':
        case 'unknown_code':
          return ReferralClaimFailure.unknownCode;
        case 'self_referral':
          return ReferralClaimFailure.ownCode;
        case 'mutual_referral':
          return ReferralClaimFailure.mutual;
      }
      // A slug this build does not know falls through to the status.
    }
    if (e.statusCode == 409) return ReferralClaimFailure.alreadyClaimed;
    if (e.statusCode == 429) return ReferralClaimFailure.limited;
    if (e.statusCode == 404) return ReferralClaimFailure.unknownDevice;
    if (e.isValidationError) return ReferralClaimFailure.rejected;
    if (e.statusCode == 0 || e.isServerError) {
      return ReferralClaimFailure.network;
    }
    return ReferralClaimFailure.unexpected;
  }
}
