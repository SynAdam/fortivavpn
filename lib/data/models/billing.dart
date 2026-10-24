/// What the payment endpoints answer, read leniently.
///
/// Every field is optional on the wire. A field that is missing or has the
/// wrong type reads as null, false or empty instead of failing the whole
/// answer, because a strict cast that throws would take the Premium screen
/// down with it. Prices, days and limits are never filled in by the app:
/// a number the backend did not send is shown as text that names none.
///
/// The shapes follow the payments contract (GET and POST under
/// /api/v1/devices/{device_id}/billing). An older backend may still send
/// USDT and Stars prices, crypto networks and the crypto and Telegram
/// rails. The app shows no such way to pay, so it does not read them, and
/// an answer that carries them reads the same as one that does not.
library;

import '../../api/config_service.dart';

/// Whether this device has Premium, and until when.
///
/// The backend sends this even while sales are off, so a phone that has
/// Premium always sees it.
class Premium {
  const Premium({
    required this.active,
    this.until,
    this.plan,
    this.source,
    this.autoRenewing,
    this.code,
  });

  static const none = Premium(active: false);

  final bool active;

  /// The end of the unbroken run of paid time that covers now.
  final DateTime? until;

  /// The plan code, such as unlimited_30d.
  final String? plan;

  /// How it was paid: voucher, crypto, stars, google_play or manual.
  final String? source;

  /// Whether Google Play renews it. Null for anything not bought in Play.
  final bool? autoRenewing;

  /// The access key that covers now, as the backend shows it, such as
  /// K7QD-3MWX-9TZB-H2CF. Null for a Google Play purchase, which has none.
  final String? code;

  factory Premium.fromJson(Object? json) {
    if (json is! Map) return none;
    final renewing = json['auto_renewing'];
    return Premium(
      active: json['active'] == true,
      until: readTime(json['until']),
      plan: readText(json['plan']),
      source: readText(json['source']),
      autoRenewing: renewing is bool ? renewing : null,
      code: readText(json['code']),
    );
  }
}

/// Which Play product sells a plan.
class PlayProductRef {
  const PlayProductRef({required this.productId, this.basePlanId});

  final String productId;

  /// The subscription's base plan, or null for a product with none.
  final String? basePlanId;

  static PlayProductRef? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = readText(json['product_id']);
    if (id == null) return null;
    return PlayProductRef(
      productId: id,
      basePlanId: readText(json['base_plan_id']),
    );
  }
}

/// One thing on sale, such as 30 days of Premium, and the Play product
/// that sells it.
class Plan {
  const Plan({required this.code, this.days, this.google});

  final String code;

  /// How long it lasts. Null when the backend did not say, and then the
  /// screen names no number.
  final int? days;

  /// The Play product that sells it, or null when Play does not.
  final PlayProductRef? google;

  static Plan? fromJson(Object? json) {
    if (json is! Map) return null;
    final code = readText(json['code']);
    if (code == null) return null;
    return Plan(
      code: code,
      days: readPositiveInt(json['days']),
      google: PlayProductRef.fromJson(json['google']),
    );
  }
}

/// The ways to pay the backend allows for this device.
class Rails {
  const Rails({
    this.googlePlay = false,
    this.codes = false,
    this.playRestore = false,
  });

  static const none = Rails();

  /// Whether Google Play sells here: the plans and their Buy buttons, in a
  /// copy that can buy through Play (BillingState.playBilling).
  final bool googlePlay;

  /// Whether the "Enter a code" box is shown.
  final bool codes;

  /// Whether a copy that can use Google Play may bring back what this
  /// Google account already pays for in Google Play (`play_restore`): Restore purchases, and the
  /// check for purchases Play still holds at launch and on every return to
  /// the app. Apart from [googlePlay], so people who already pay can always
  /// restore, whether or not anything is on sale. The backend sends it on
  /// whenever Google Play is set up on its side, even while sales are off.
  final bool playRestore;

  factory Rails.fromJson(Object? json) {
    if (json is! Map) return none;
    return Rails(
      googlePlay: json['google_play'] == true,
      codes: json['codes'] == true,
      playRestore: json['play_restore'] == true,
    );
  }
}

/// A place in the app that may offer Premium, as the backend names it in
/// the `upsell` block.
enum UpsellSurface {
  topChip('top_chip'),
  limitSheet('limit_sheet'),
  serverCard('server_card'),
  quotaLine('quota_line'),
  myServersCard('my_servers_card'),
  calmCard('calm_card'),
  lockedServers('locked_servers');

  const UpsellSurface(this.wire);

  /// The name on the wire.
  final String wire;

  /// The surface named [wire], or null for a name this build does not know.
  static UpsellSurface? fromWire(Object? wire) {
    for (final s in values) {
      if (s.wire == wire) return s;
    }
    return null;
  }
}

/// What someone did with an offer, as the upsell events route takes it.
enum UpsellAction { shown, tapped, dismissed }

/// Where the Premium screen was opened from. Sent with a purchase as
/// `source`, so the backend can count which offers sell.
enum PremiumSource {
  settings('settings'),
  topChip('top_chip'),
  limitSheet('limit_sheet'),
  serverCard('server_card'),
  quotaLine('quota_line'),
  quotaCard('quota_card'),
  spentNotice('spent_notice'),
  myServersCard('my_servers_card'),
  calmCard('calm_card'),
  lockedServer('locked_server');

  const PremiumSource(this.wire);

  /// The name on the wire, at most 32 characters.
  final String wire;

  /// Whether the user came here because the daily allowance ran out or is
  /// running out, so the screen leads with "No daily limit".
  bool get aboutTheLimit => switch (this) {
    limitSheet || serverCard || quotaLine || quotaCard || spentNotice => true,
    _ => false,
  };
}

/// A Premium location this device may not use yet, shown locked on My
/// servers. The backend sends a place and nothing that leads to the
/// server: no host, address, port or door.
class LockedServer {
  const LockedServer({
    required this.id,
    required this.countryCode,
    required this.city,
  });

  final int id;

  /// ISO 3166 alpha-2, upper case.
  final String countryCode;
  final String city;

  static final _countryCode = RegExp(r'^[A-Za-z]{2}$');

  /// Null unless the id, a two-letter country and the city are all there.
  static LockedServer? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final country = readText(json['country_code']);
    final city = readText(json['city']);
    if (id is! int || country == null || city == null) return null;
    if (!_countryCode.hasMatch(country)) return null;
    return LockedServer(id: id, countryCode: country.toUpperCase(), city: city);
  }
}

/// Where Premium may be offered on this device, and the numbers each
/// offer needs (the `upsell` block).
///
/// The backend sends the block only when sales are on and this device can
/// buy and is not Premium. Without the block nothing offers Premium, the
/// older ways in included (BillingState.offersAllowed). A surface missing
/// from [surfaces] stays hidden, and so does one whose number is missing.
///
/// Offers follow this block alone, the same way in every country. Older
/// backends also send `hide_phone_countries` and `hide_time_zones` in it.
/// The app ignores both, and reads the block the same with or without
/// them.
class Upsell {
  const Upsell({
    this.surfaces = const {},
    this.nudgeUsedPercent,
    this.promptEveryHours,
    this.promptMax,
    this.lockedServers = const [],
  });

  final Set<UpsellSurface> surfaces;

  /// How much of the daily allowance is used, in percent, before the home
  /// data line offers Premium. Null unless it is between 1 and 100.
  final int? nudgeUsedPercent;

  /// The shortest gap between two calm cards, and the most there may ever
  /// be. The calm card stays hidden while either is null.
  final int? promptEveryHours;
  final int? promptMax;
  final List<LockedServer> lockedServers;

  static Upsell? fromJson(Object? json) {
    if (json is! Map) return null;
    final nudge = json['nudge_used_percent'];
    return Upsell(
      surfaces: {
        for (final s in readList(json['surfaces'])) ?UpsellSurface.fromWire(s),
      },
      nudgeUsedPercent: nudge is int && nudge >= 1 && nudge <= 100
          ? nudge
          : null,
      promptEveryHours: readPositiveInt(json['prompt_every_hours']),
      promptMax: readPositiveInt(json['prompt_max']),
      lockedServers: [
        for (final s in readList(json['locked_servers']))
          ?LockedServer.fromJson(s),
      ],
    );
  }
}

/// When Premium that does not renew by itself ends, or when it ended (the
/// `renewal` block). The backend sends it only while reminders are on.
///
/// Older backends also send `can_renew`, for a Renew button that only the
/// channel APK of builds 1.6.16 and 1.6.17 showed. This app has no Renew
/// button and does not read it.
class Renewal {
  const Renewal({this.until, this.endedAt, this.noticeHours});

  /// The current end, while Premium is on.
  final DateTime? until;

  /// The last end, for a while after Premium ended.
  final DateTime? endedAt;

  /// How long before [until] the reminder shows. No reminder while null.
  final int? noticeHours;

  static Renewal? fromJson(Object? json) {
    if (json is! Map) return null;
    return Renewal(
      until: readTime(json['until']),
      endedAt: readTime(json['ended_at']),
      noticeHours: readPositiveInt(json['notice_hours']),
    );
  }

  /// Whether the reminder before the end shows at [now]: [premium] is on
  /// and ends within [noticeHours]. Never for a Google Play subscription
  /// that renews by itself, because it does not end. Never for Premium an
  /// operator made by hand (source manual): there are no keys to add time
  /// to, so a purchase made early would start that day and lose the days
  /// left.
  bool reminderDue(Premium premium, DateTime now) {
    final end = until;
    final notice = noticeHours;
    if (!premium.active || end == null || notice == null) return false;
    if (premium.autoRenewing == true) return false;
    if (premium.source == 'manual') return false;
    final left = end.difference(now);
    return !left.isNegative && left <= Duration(hours: notice);
  }
}

/// GET /api/v1/devices/{device_id}/billing
class BillingInfo {
  const BillingInfo({
    required this.enabled,
    this.premium = Premium.none,
    this.plans = const [],
    this.rails = Rails.none,
    this.moveLimit,
    this.moveWindowDays,
    this.upsell,
    this.renewal,
  });

  /// Nothing on sale and no Premium: what a phone shows before the backend
  /// has answered, and on a backend without payments.
  static const off = BillingInfo(enabled: false);

  /// Whether sales are on for this device. Every entry point to the
  /// Premium screen is hidden while this is false.
  final bool enabled;
  final Premium premium;
  final List<Plan> plans;
  final Rails rails;

  /// How many times a key may move to a new phone in [moveWindowDays].
  /// Null when the backend did not say.
  final int? moveLimit;
  final int? moveWindowDays;

  /// Where Premium may be offered. Null on a backend that sends no block,
  /// and then nothing new offers it.
  final Upsell? upsell;

  /// The reminder before Premium ends and the note after it ended. Null
  /// while reminders are off.
  final Renewal? renewal;

  /// While sales are off, the plans, rails and the upsell block are
  /// dropped whatever the backend sent, so nothing can be offered by
  /// mistake. The Premium status is kept, and so is Rails.playRestore,
  /// which sells nothing: it lets people who already pay restore what they
  /// paid for. The renewal block is kept too, so a phone with a key still
  /// sees when it ends.
  factory BillingInfo.fromJson(Object? json) {
    if (json is! Map) return off;
    final enabled = json['enabled'] == true;
    final premium = Premium.fromJson(json['premium']);
    final rails = Rails.fromJson(json['rails']);
    final renewal = Renewal.fromJson(json['renewal']);
    if (!enabled) {
      return BillingInfo(
        enabled: false,
        premium: premium,
        rails: Rails(playRestore: rails.playRestore),
        renewal: renewal,
      );
    }
    return BillingInfo(
      enabled: true,
      premium: premium,
      plans: [for (final p in readList(json['plans'])) ?Plan.fromJson(p)],
      rails: rails,
      moveLimit: readPositiveInt(json['move_limit']),
      moveWindowDays: readPositiveInt(json['move_window_days']),
      upsell: Upsell.fromJson(json['upsell']),
      renewal: renewal,
    );
  }

  BillingInfo withPremium(Premium premium) => BillingInfo(
    enabled: enabled,
    premium: premium,
    plans: plans,
    rails: rails,
    moveLimit: moveLimit,
    moveWindowDays: moveWindowDays,
    upsell: upsell,
    renewal: renewal,
  );
}

/// What a redeemed code did: a key that made this device Premium, or a
/// promo code that added data.
class RedeemResult {
  const RedeemResult({
    required this.kind,
    this.premium = Premium.none,
    this.moved = false,
    this.quota,
    this.bonusBytes,
  });

  /// premium or promo.
  final String kind;
  final Premium premium;

  /// Whether the key came from another phone.
  final bool moved;

  /// The allowance after the code, or null when the backend sent none
  /// that could be read.
  final QuotaStatus? quota;

  /// What a promo code added, in bytes. Null when it did not say.
  final int? bonusBytes;

  bool get isPremium => kind == 'premium';

  factory RedeemResult.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('redeem: not an object');
    return RedeemResult(
      kind: readText(json['kind']) ?? 'premium',
      premium: Premium.fromJson(json['premium']),
      moved: json['moved'] == true,
      quota: readQuota(json['quota']),
      bonusBytes: readPositiveInt(json['bonus_bytes']),
    );
  }
}

/// POST .../billing/google: the Premium a Play purchase gave.
class PlayConfirmation {
  const PlayConfirmation({required this.premium, this.quota});

  final Premium premium;
  final QuotaStatus? quota;

  factory PlayConfirmation.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('google: not an object');
    return PlayConfirmation(
      premium: Premium.fromJson(json['premium']),
      quota: readQuota(json['quota']),
    );
  }
}

/// A non-empty string, or null.
String? readText(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

/// A whole number above zero, or null.
int? readPositiveInt(Object? value) => value is int && value > 0 ? value : null;

/// A timestamp in UTC, or null.
DateTime? readTime(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

/// A list, or an empty one.
List<Object?> readList(Object? value) =>
    value is List ? value : const <Object?>[];

/// The allowance, or null when it is missing or has a field of the wrong
/// type. QuotaStatus.fromJson casts strictly, so it is guarded here.
QuotaStatus? readQuota(Object? value) {
  if (value is! Map) return null;
  try {
    return QuotaStatus.fromJson(value.cast<String, dynamic>());
  } catch (_) {
    return null;
  }
}
