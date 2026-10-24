import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart'
    show RecurrenceMode;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// One plan as Google Play sells it to this user.
class PlayProduct {
  const PlayProduct({
    required this.productId,
    required this.price,
    this.basePlanId,
    this.renews = false,
    this.billingPeriod,
    this.details,
  });

  final String productId;

  /// The subscription's base plan, or null for a product with none.
  final String? basePlanId;

  /// The price as Play formats it for this user, in their currency. Shown
  /// as is: the app never writes a price of its own.
  final String price;

  /// Whether Play charges for it again and again until the user cancels:
  /// an auto-renewing subscription. False for a one-time product and for a
  /// prepaid plan.
  final bool renews;

  /// How often Play charges for it, as Play gives it, in ISO 8601 (P1M,
  /// P1Y). Null when Play gave none. Read with [PlayPeriod.parse].
  final String? billingPeriod;

  /// The plugin's own object, handed back to [PlayBilling.buy].
  final Object? details;
}

/// What a billing period counts in.
enum PlayPeriodUnit { day, week, month, year }

/// How often Play charges for a subscription: [count] times [unit], such
/// as every month or every three months.
///
/// The number comes from Play's product details, never from the app, so
/// the screen can say how often a plan bills without naming a number of
/// its own.
class PlayPeriod {
  const PlayPeriod(this.count, this.unit);

  final int count;
  final PlayPeriodUnit unit;

  /// A period in the one-unit ISO 8601 form Play uses (P1W, P1M, P3M,
  /// P1Y, P7D), or null for anything else, including null.
  static PlayPeriod? parse(String? iso) {
    if (iso == null) return null;
    final match = _iso.firstMatch(iso.trim().toUpperCase());
    if (match == null) return null;
    final count = int.tryParse(match.group(1)!);
    if (count == null || count <= 0) return null;
    final unit = switch (match.group(2)) {
      'D' => PlayPeriodUnit.day,
      'W' => PlayPeriodUnit.week,
      'M' => PlayPeriodUnit.month,
      'Y' => PlayPeriodUnit.year,
      _ => null,
    };
    return unit == null ? null : PlayPeriod(count, unit);
  }

  static final _iso = RegExp(r'^P(\d+)([DWMY])$');
}

/// Google Play could not say what this Google account owns.
class PlayQueryException implements Exception {
  const PlayQueryException(this.message);

  final String message;

  @override
  String toString() => 'PlayQueryException($message)';
}

enum PlayPurchaseStatus { pending, purchased, restored, canceled, error }

/// One purchase as Google Play reports it.
class PlayPurchase {
  const PlayPurchase({
    required this.productId,
    required this.token,
    required this.status,
    this.needsCompleting = false,
    this.details,
  });

  final String productId;

  /// The purchase token, which the backend verifies with Google.
  final String token;
  final PlayPurchaseStatus status;

  /// Whether Play still waits for the app to complete (acknowledge) it.
  /// Play refunds a purchase nobody acknowledges within a few days.
  final bool needsCompleting;

  /// The plugin's own object, handed back to [PlayBilling.complete].
  final Object? details;
}

/// The part of Google Play Billing the app uses, so the purchase flow can
/// be tested without Play.
abstract interface class PlayBilling {
  /// Purchases as they happen: bought, pending, canceled or failed.
  Stream<List<PlayPurchase>> get purchases;

  /// Whether Play can sell on this phone at all.
  Future<bool> isAvailable();

  /// The products with these ids, one per base plan. Offers are left out,
  /// so the price shown is the plan's own.
  Future<List<PlayProduct>> products(Set<String> productIds);

  /// Opens Play's purchase sheet. [accountId] goes to Play as the
  /// obfuscated account id (BillingState.playAccountId). Google hands it
  /// back to the backend with the purchase, which uses it to find this
  /// device for a purchase the phone never reported. False when the sheet
  /// did not open; the outcome of one that did arrives on [purchases].
  Future<bool> buy(PlayProduct product, {required String accountId});

  /// Tells Play the purchase was delivered (acknowledges it).
  Future<void> complete(PlayPurchase purchase);

  /// What this Google account owns now, including purchases made on other
  /// phones. Throws when Play could not say, so a failed query never reads
  /// as owning nothing.
  Future<List<PlayPurchase>> owned();
}

/// Google Play Billing on this phone, or null where there is none: Windows,
/// and anything else that is not Android.
///
/// BillingState asks for it only once this copy has been found to be the
/// one Google Play signed (PlaySignature), because Play sells in no other
/// copy. Creating it does not touch Play. The plugin connects to Play on its
/// first call, and the app makes none until the backend has turned Play
/// sales or restores on for this device.
PlayBilling? playBillingOnThisPhone() {
  if (!Platform.isAndroid) return null;
  return GooglePlayBilling();
}

/// [PlayBilling] through the in_app_purchase plugin.
class GooglePlayBilling implements PlayBilling {
  InAppPurchase get _iap => InAppPurchase.instance;

  @override
  Stream<List<PlayPurchase>> get purchases =>
      _iap.purchaseStream.map((list) => [for (final p in list) ?_purchase(p)]);

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<List<PlayProduct>> products(Set<String> productIds) async {
    if (productIds.isEmpty) return const [];
    final response = await _iap.queryProductDetails(productIds);
    return [
      for (final d in response.productDetails)
        if (d is GooglePlayProductDetails) ?_product(d),
    ];
  }

  /// A subscription comes back once per base plan and once per offer on
  /// it. Only the base plans are kept.
  ///
  /// The billing period and whether it renews come from the base plan's
  /// last pricing phase, the one that repeats. A base plan with no offer
  /// has only that one.
  PlayProduct? _product(GooglePlayProductDetails d) {
    final index = d.subscriptionIndex;
    if (index == null) {
      return PlayProduct(productId: d.id, price: d.price, details: d);
    }
    final offers = d.productDetails.subscriptionOfferDetails;
    if (offers == null || index >= offers.length) return null;
    final offer = offers[index];
    if (offer.offerId != null) return null;
    final phase = offer.pricingPhases.lastOrNull;
    return PlayProduct(
      productId: d.id,
      basePlanId: offer.basePlanId,
      price: d.price,
      // A prepaid plan is a subscription that does not renew.
      renews:
          phase == null || phase.recurrenceMode != RecurrenceMode.nonRecurring,
      billingPeriod: phase?.billingPeriod,
      details: d,
    );
  }

  @override
  Future<bool> buy(PlayProduct product, {required String accountId}) async {
    final details = product.details;
    if (details is! ProductDetails) return false;
    return _iap.buyNonConsumable(
      purchaseParam: GooglePlayPurchaseParam(
        productDetails: details,
        applicationUserName: accountId,
      ),
    );
  }

  @override
  Future<void> complete(PlayPurchase purchase) async {
    final details = purchase.details;
    if (details is PurchaseDetails && details.pendingCompletePurchase) {
      await _iap.completePurchase(details);
    }
  }

  @override
  Future<List<PlayPurchase>> owned() async {
    final android = _iap
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    return ownedFrom(await android.queryPastPurchases());
  }

  /// The purchases in a query's answer.
  ///
  /// The plugin does not throw when Play fails. It asks for one-time
  /// products and for subscriptions separately, and reports a failure as
  /// [QueryPurchaseDetailsResponse.error] next to whatever did come back.
  /// A failed query with nothing in it throws [PlayQueryException], so
  /// Restore purchases says Play is not available instead of telling a
  /// subscriber they own nothing. Purchases that did come back are kept
  /// even when the other half failed.
  @visibleForTesting
  static List<PlayPurchase> ownedFrom(QueryPurchaseDetailsResponse response) {
    final error = response.error;
    if (error != null && response.pastPurchases.isEmpty) {
      throw PlayQueryException('${error.code}: ${error.message}');
    }
    return [for (final p in response.pastPurchases) ?_purchase(p)];
  }

  /// Null for a purchase that says it was paid but carries no token,
  /// because there is nothing the backend could verify.
  static PlayPurchase? _purchase(PurchaseDetails p) {
    final token = p.verificationData.serverVerificationData;
    final status = switch (p.status) {
      PurchaseStatus.pending => PlayPurchaseStatus.pending,
      PurchaseStatus.purchased => PlayPurchaseStatus.purchased,
      PurchaseStatus.restored => PlayPurchaseStatus.restored,
      PurchaseStatus.canceled => PlayPurchaseStatus.canceled,
      PurchaseStatus.error => PlayPurchaseStatus.error,
    };
    final paid =
        status == PlayPurchaseStatus.purchased ||
        status == PlayPurchaseStatus.restored;
    if (paid && token.isEmpty) return null;
    return PlayPurchase(
      productId: p.productID,
      token: token,
      status: status,
      needsCompleting: p.pendingCompletePurchase,
      details: p,
    );
  }
}
