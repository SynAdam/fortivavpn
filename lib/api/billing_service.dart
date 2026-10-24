import '../data/models/billing.dart';
import 'api_client.dart';

/// Why a payment call was refused, as a short reason the screens map to
/// their own text.
///
/// The backend sends the reason in `detail.reason` of a refusal (for
/// example `{"detail": {"reason": "expired", "message": "..."}}`).
/// ApiException.message cannot carry it, because a `detail` that is an
/// object turns into the generic 'Validation error' there, so it is read
/// from the body. Refusals with no reason get one from the status: [network]
/// when no route reached the backend, [rateLimited] for 429, [notFound] for
/// 404, [unavailable] for 503 and [server] for any other 5xx.
class BillingException implements Exception {
  BillingException(this.reason, {this.statusCode = 0});

  /// Builds one from what [ApiClient] threw.
  factory BillingException.from(ApiException e) =>
      BillingException(reasonOf(e), statusCode: e.statusCode);

  static const network = 'network';
  static const rateLimited = 'rate_limited';
  static const notFound = 'not_found';
  static const unavailable = 'unavailable';
  static const server = 'server';
  static const badAnswer = 'bad_answer';
  static const unknown = 'unknown';

  /// Premium is not sold to this device. Redeem and Google Play can both
  /// send it (422).
  /// Not retryable: the same call is refused again until the backend
  /// changes its mind, and a fresh GET .../billing then shows what is left.
  static const notAvailable = 'not_available';

  /// Google Play only (409): the purchase runs on another phone that still
  /// exists, and the app sent it from its silent check of owned purchases
  /// (auto true), so the backend left it there. It is final for that token
  /// on this phone: the app notes the token, never sends it from that
  /// check again, and shows nothing. A send the user made (auto false)
  /// never gets this answer.
  static const heldElsewhere = 'held_elsewhere';

  final String reason;

  /// The HTTP status, or 0 when no answer arrived.
  final int statusCode;

  /// Whether the same call may work later without the user doing anything
  /// different: no route, too many calls, the backend busy or not knowing
  /// this device yet.
  bool get isRetryable => const {
    network,
    rateLimited,
    notFound,
    unavailable,
    server,
    badAnswer,
  }.contains(reason);

  static String reasonOf(ApiException e) {
    // The limiter's answer is always "too many calls", whatever it says.
    if (e.statusCode == 429) return rateLimited;
    final body = e.body;
    if (body is Map) {
      final detail = body['detail'];
      if (detail is Map) {
        final reason = detail['reason'];
        if (reason is String && reason.trim().isNotEmpty) return reason.trim();
      }
    }
    if (e.statusCode == 0) return network;
    if (e.statusCode == 404) return notFound;
    if (e.statusCode == 503) return unavailable;
    if (e.statusCode >= 500) return server;
    return unknown;
  }

  @override
  String toString() => 'BillingException($statusCode, $reason)';
}

/// The calls behind Premium: the catalog and status, codes and Google Play
/// purchases.
///
/// All of them sit under /api/v1/devices/{device_id}/billing, because the
/// relays forward only /api/v1/(app|configs|devices|info)/, and the phones
/// that most need another route are the ones on networks that cut ours.
/// Every call goes through [ApiClient] with its fallback routes, so a POST
/// can reach the backend twice when an answer is lost on the way back. The
/// backend makes each one safe to repeat: a key already on this device and
/// a purchase token it has seen both answer as the first time did.
///
/// Every method throws [BillingException] for a refusal or a failed call.
class BillingService {
  BillingService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// What every call that names a store sends as `store`.
  ///
  /// Every copy of the app runs the same code and shows the same Premium
  /// screen, so every copy sends play. Builds 1.6.16 and 1.6.17 sent direct
  /// from the channel APK, and the backend still answers those as it did.
  static const store = 'play';

  String _base(String deviceId) => '/api/v1/devices/$deviceId/billing';

  /// GET /api/v1/devices/{device_id}/billing?store=play
  ///
  /// An older backend may still send rails, prices and networks for ways
  /// to pay this app no longer shows. BillingInfo.fromJson reads past them.
  Future<BillingInfo> info(String deviceId) => _call(
    () => _client.get('${_base(deviceId)}?store=$store'),
    BillingInfo.fromJson,
  );

  /// POST /api/v1/devices/{device_id}/billing/redeem
  ///
  /// [code] is an access key or a promo code, as the user typed it. The
  /// backend normalises it.
  Future<RedeemResult> redeem(String deviceId, String code) => _call(
    () => _client.post('${_base(deviceId)}/redeem', body: {'code': code}),
    RedeemResult.fromJson,
  );

  /// POST /api/v1/devices/{device_id}/billing/google
  ///
  /// [auto] is true only for a purchase the app sends from its silent
  /// check of what the Google account owns, at launch and on return to the
  /// app. The backend then never moves a purchase that runs on another
  /// phone, and refuses it with [BillingException.heldElsewhere] instead.
  /// It is false for a purchase made in the app and for Restore purchases,
  /// which move the purchase to this device as the user asked.
  ///
  /// [source] names the place in the app the Premium screen was opened
  /// from (PremiumSource.wire), so the backend can count which offers
  /// sell. Left out of the body when null.
  Future<PlayConfirmation> confirmPlay(
    String deviceId, {
    required String productId,
    required String purchaseToken,
    String? basePlanId,
    bool auto = false,
    String? source,
  }) => _call(
    () => _client.post(
      '${_base(deviceId)}/google',
      body: {
        'product_id': productId,
        'purchase_token': purchaseToken,
        'base_plan_id': basePlanId,
        'auto': auto,
        'source': ?source,
      },
    ),
    PlayConfirmation.fromJson,
  );

  /// POST /api/v1/devices/{device_id}/billing/upsell-events?store=play
  ///
  /// When each offer was shown, tapped or closed, at most [maxEvents] at a
  /// time. The backend answers 204 with no body.
  ///
  /// [sentAt] is the phone's clock as the batch goes out. The backend
  /// compares it with its own to move each event's `at` onto its clock, as
  /// it does for the connection events, so a phone whose clock is wrong
  /// still files an event on the right day. [store] goes in the query, as
  /// on [info], and in the body with the batch, so a backend that reads
  /// either finds it.
  Future<void> upsellEvents(
    String deviceId,
    List<Map<String, Object?>> events, {
    DateTime? sentAt,
  }) => _call(
    () => _client.post(
      '${_base(deviceId)}/upsell-events?store=$store',
      body: {
        'events': events,
        if (sentAt != null) 'sent_at': sentAt.toUtc().toIso8601String(),
        'store': store,
      },
    ),
    (_) {},
  );

  /// The most events the backend takes in one call.
  static const maxEvents = 50;

  Future<T> _call<T>(
    Future<dynamic> Function() send,
    T Function(Object? json) parse,
  ) async {
    final Object? response;
    try {
      response = await send();
    } on ApiException catch (e) {
      throw BillingException.from(e);
    } on Exception {
      // A timeout on every route reaches here as itself, not as an
      // ApiException.
      throw BillingException(BillingException.network);
    }
    try {
      return parse(response);
    } on FormatException {
      throw BillingException(BillingException.badAnswer, statusCode: 200);
    }
  }
}
