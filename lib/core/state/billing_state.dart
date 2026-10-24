import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/billing_service.dart';
import '../../api/config_service.dart';
import '../../api/device_service.dart';
import '../../data/models/billing.dart';
import '../../services/play_billing.dart';
import '../../services/play_signature.dart';
import '../../services/vpn_event_reporter.dart';
import '../form_factor.dart';
import 'dedicated_state.dart';

/// Where a Google Play purchase stands, for the line under the plans.
enum PlayFlow {
  idle,

  /// Play's purchase sheet is open.
  buying,

  /// Play took the order but the money has not moved yet, for example a
  /// cash payment at a shop. Play reports it again when it goes through.
  pending,

  /// The backend is checking the purchase with Google.
  confirming,

  /// The backend confirmed it and this device has Premium.
  done,

  /// Paid, but the backend could not be reached or Google did not answer.
  /// The token is kept on the phone and sent again.
  retrying,

  /// The backend refused the purchase for good.
  refused,

  /// The backend refused it because Premium is not sold to this device
  /// (BillingException.notAvailable).
  notAvailable,

  /// The purchase did not go through in Play.
  failed,
}

/// What Restore purchases found. [notAvailable] means the backend restored
/// nothing and said Premium is not sold to this device.
enum RestoreOutcome { restored, nothing, unavailable, notAvailable, failed }

/// What Settings > Account shows for Premium (BillingState.tile).
enum PremiumTile {
  /// Nothing.
  hidden,

  /// "Premium", which opens the Premium screen.
  premium,

  /// "Enter a code", which opens the code dialog straight away.
  enterCode,
}

/// What became of one Play purchase sent to the backend.
enum _Confirmed { yes, no, notAvailable }

/// Premium for this device: whether it has it, what is on sale, and the
/// purchase flows.
///
/// Everything starts dark. Until GET .../billing answers `enabled: true`,
/// [enabled] is false and every entry point to the Premium screen stays
/// hidden, so a backend without payments, or one with sales switched off,
/// shows nothing new. The answer is not kept between launches, so a phone
/// that cannot reach us shows nothing either.
///
/// A Premium grant changes the allowance, and the quota card is drawn from
/// [DedicatedState]. Every grant (a key or a Play purchase) hands the new
/// quota to it when the answer carries one and asks it to refresh, so the
/// card says Unlimited at once.
///
/// Every copy of the app runs this same code: the one from Google Play and
/// the APK posted in the Telegram channel. They differ in one thing, read
/// at run time: Google Play Billing works only in the copy signed with
/// Google Play's app signing certificate ([PlaySignature]). A copy that is
/// not, such as the channel APK, never touches Play. It sells nothing, and
/// its Premium screen offers "Enter a code" and says that buying through
/// Google Play needs the Google Play version ([playSupported]).
///
/// Google Play: only on Android, in the copy Google signed, and Play is not
/// touched until the backend has turned on Play sales (Rails.googlePlay) or
/// Play restores (Rails.playRestore) for this device.
/// Restoring is apart from selling, so people who already pay can always
/// get their subscription back on a new phone, whatever is on sale: a
/// phone without Premium sends what the Google account already pays for
/// to the backend in the background, and shows no new way in while doing
/// it. That background check sends with auto true, so the backend never
/// moves to this phone a purchase that runs on another one (see
/// [_restoreOwned]). A purchase is completed (acknowledged) only after the
/// backend answered 200. Its token is kept on the phone until then and sent
/// again at launch and on every return to the app, because Play refunds a
/// purchase nobody acknowledges within a few days.
///
/// Offers (see [upsellOn]) start dark too. Each place in the app that may
/// offer Premium shows only when the backend's `upsell` block names it,
/// this copy can buy through Google Play ([playBilling]), and the device
/// is not Premium. The backend alone decides where offers show. The phone
/// never checks where it is for offers, so the same answer gives the same
/// offers in every country. None of it shows on a TV. The older ways in (the quota card, the spent
/// notice and the Settings tile) need the block too ([offersAllowed]), so
/// with no block nothing offers Premium.
///
/// What each offer did is sent to the backend only while the user shares
/// connection diagnostics (VpnEventReporter.sharePrefKey), as the in-app
/// message receipts are.
class BillingState extends ChangeNotifier {
  BillingState({
    BillingService? service,
    DedicatedState? dedicated,
    PlayBilling? Function()? playBilling,
    Future<bool> Function()? googleSigned,
    Future<String> Function()? deviceId,
    Future<bool> Function()? sharing,
    DateTime Function()? now,
    this.upsellSendEvery = const Duration(minutes: 1),
  }) : _service = service ?? BillingService(),
       _dedicated = dedicated,
       _playFactory = playBilling ?? playBillingOnThisPhone,
       _signedCheck = googleSigned ?? PlaySignature.shared.read,
       _deviceId = deviceId ?? DeviceService().getDeviceId,
       _sharingCheck = sharing,
       _now = now ?? DateTime.now;

  /// Play purchases the backend has not confirmed yet, as JSON. Kept when
  /// the account is deleted (see AccountService.keptPrefKeys).
  static const String _unconfirmedPlayKey = 'billing_play_unconfirmed';

  /// Every Play purchase token this phone has handled: bought here,
  /// restored by hand, restored on its own, or refused because another
  /// phone holds it (held_elsewhere). The background check of owned
  /// purchases ([_completeOwned]) never sends one of these to the backend
  /// again. Cleared when the account is deleted, because the new account
  /// should get back what the Google account pays for (see
  /// AccountService.accountPrefKeys).
  static const String _handledKey = 'billing_play_auto_restored';

  /// Set once the tunnel has been up and checked on this install. No offer
  /// shows before the first working connection. Cleared when the account
  /// is deleted.
  static const String _workedKey = 'upsell_after_first_connect';

  /// How long a loaded answer is trusted before a return to the app loads
  /// it again.
  static const refreshAfter = Duration(minutes: 10);

  /// The most unconfirmed Play purchases kept on the phone.
  static const _maxSavedPurchases = 20;

  /// Google Play's page for subscriptions, where the user changes or
  /// cancels one.
  static const playSubscriptionsPage =
      'https://play.google.com/store/account/subscriptions';

  /// This app on Google Play, for [playSubscriptionsPage].
  static const playPackage = 'com.vpn.fortivavpn';

  /// How long offer events wait on the phone before they are sent, so they
  /// go in one call at most this often. Leaving the app sends them at once.
  final Duration upsellSendEvery;

  final BillingService _service;
  final DedicatedState? _dedicated;
  final PlayBilling? Function() _playFactory;
  final Future<bool> Function() _signedCheck;
  final Future<String> Function() _deviceId;
  final Future<bool> Function()? _sharingCheck;
  final DateTime Function() _now;

  /// Whether the tunnel has been up and checked on this install.
  bool _worked = false;

  /// Whether the user shares connection diagnostics, as last read. Offer
  /// events are neither kept nor sent while this is false.
  bool _sharing = true;

  /// Offer events not sent yet, and the surfaces already counted as shown
  /// in this run of the app.
  final List<Map<String, Object?>> _upsellEvents = [];
  final Set<UpsellSurface> _shownThisRun = {};
  Timer? _upsellTimer;
  bool _sendingUpsell = false;

  /// Set when a send was asked for while one was going, so the events
  /// that arrived meanwhile go right after it.
  bool _sendUpsellAgain = false;

  /// Where each open Premium screen was opened from, newest last. A
  /// purchase made there carries the newest one as its source.
  final List<PremiumSource> _screens = [];

  /// The source of the Play purchase whose sheet is open.
  PremiumSource? _buyingSource;

  BillingInfo _info = BillingInfo.off;
  bool _loaded = false;
  bool _loading = false;
  bool _loadFailed = false;
  DateTime? _loadedAt;
  Future<void>? _refreshing;
  bool _started = false;
  bool _disposed = false;

  /// Whether this copy is signed with Google Play's app signing
  /// certificate. False until the check has answered, so a copy that cannot
  /// tell never touches Play.
  bool _googleSigned = false;

  PlayBilling? _play;
  bool _playMade = false;
  StreamSubscription<List<PlayPurchase>>? _playPurchases;
  bool _playAvailable = false;
  bool _playLoading = false;
  Map<String, PlayProduct> _products = const {};
  PlayFlow _playFlow = PlayFlow.idle;

  /// The purchase [playFlow] is about, so a confirmation that lands in the
  /// background can settle the line under the plans.
  String? _flowToken;
  Plan? _buying;
  bool _restoring = false;
  final Set<String> _confirming = {};

  /// The Play products this Google account owns, as Play last said.
  Set<String> _ownedProducts = const {};

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Whether sales are on for this device. Every entry point is hidden
  /// while this is false.
  bool get enabled => _info.enabled;

  Premium get premium => _info.premium;

  /// Whether this copy can buy something here: sales are on, the backend
  /// sells at least one plan through Google Play, and this copy can buy
  /// through Play on this phone ([playBilling]). The backend can turn sales
  /// on and offer nothing but the code box, so [enabled] alone does not say
  /// this.
  ///
  /// Play's prices are not waited for, only its answer that it can sell
  /// here. The Premium screen says so when Play then has no price for a
  /// plan. A copy that cannot buy through Play, such as the channel APK,
  /// is offered nothing, wherever it is opened.
  bool get canBuy =>
      enabled &&
      playBilling &&
      rails.googlePlay &&
      plans.any((plan) => plan.google != null);

  /// Whether there is something to buy here and this device does not have
  /// Premium yet. The places that offer Premium ask [offersAllowed], which
  /// adds the backend's `upsell` block.
  bool get showUpsell => canBuy && !premium.active;

  /// Whether this phone may be offered Premium at all: [showUpsell] and the
  /// backend sent an `upsell` block. The older ways in (the quota card and
  /// the spent notice on My servers, and the Settings tile of a device
  /// without Premium) ask this, and so does every offer through [upsellOn].
  ///
  /// The backend leaves the block out when it wants no offer on this
  /// device, so with no block this is false. Nothing here depends on where
  /// the phone is.
  bool get offersAllowed => showUpsell && _info.upsell != null;

  /// The backend's offer settings for this device, or null when it sent
  /// none. Never while sales are off.
  Upsell? get upsell => _info.upsell;

  /// The reminder before Premium ends and the note after it ended, or null
  /// while the backend sends neither.
  Renewal? get renewal => _info.renewal;

  /// Whether the backend has turned [s] on for this device. Never on a TV,
  /// where the home screen is laid out for a remote and nothing new may
  /// take a place in its focus order. Every offer asks [upsellOn], which
  /// adds the rest of the gate. The limit sheet itself does not ask either:
  /// it opens for every phone (FeatureFlags.limitSheet), and only its
  /// Premium row asks [upsellOn].
  bool upsellListed(UpsellSurface s) =>
      !FormFactor.isTv && (_info.upsell?.surfaces.contains(s) ?? false);

  /// Whether [s] may offer Premium now: the backend turned it on for this
  /// device, there is something to buy here and the device does not have
  /// Premium ([offersAllowed]), and the tunnel has worked on this install at
  /// least once.
  bool upsellOn(UpsellSurface s) =>
      offersAllowed && upsellListed(s) && _hasWorked;

  /// Whether the tunnel has worked on this install: noted on a checked
  /// connection, or seen in the allowance used so far today.
  bool get _hasWorked => _worked || (_dedicated?.quota?.usedBytes ?? 0) > 0;

  /// What Settings > Account shows for Premium.
  ///
  /// A device that has Premium always gets the tile, even while sales are
  /// off, so the user can read and copy the key. Otherwise the tile needs
  /// sales on. When nothing can be bought here but codes are taken, it is
  /// "Enter a code" and opens the code dialog itself. That is the tile of
  /// every copy that cannot buy through Google Play ([canBuy]). The Premium
  /// screen would hold little more than that box, under a headline that
  /// invites the user to buy, and nothing here is on sale. With no code
  /// box either, there is no tile.
  ///
  /// A subscription the Google account already pays for comes back without
  /// a tile: it is restored in the background ([_restoreOwned]), and the
  /// tile then shows because the device has Premium.
  ///
  /// A device without Premium gets the Premium tile only when it may be
  /// offered Premium ([offersAllowed]). Otherwise, for example with no
  /// `upsell` block, it gets "Enter a code" when codes are taken, and no
  /// tile otherwise.
  PremiumTile get tile {
    if (premium.active || offersAllowed) return PremiumTile.premium;
    if (enabled && rails.codes) return PremiumTile.enterCode;
    return PremiumTile.hidden;
  }

  List<Plan> get plans => _info.plans;
  int? get moveLimit => _info.moveLimit;
  int? get moveWindowDays => _info.moveWindowDays;

  /// The rails the backend allows. Google Play's two need a copy that can
  /// use Play ([playSupported]) as well, which the screens and [canBuy]
  /// check.
  Rails get rails => _info.rails;

  /// Whether Play is asked anything on this device: to sell, or to restore.
  bool get _playOn => rails.googlePlay || rails.playRestore;

  bool get isLoading => _loading;
  bool get hasLoaded => _loaded;

  /// Whether the last load failed. What an earlier one loaded is kept.
  bool get loadFailed => _loadFailed;

  /// Whether this copy can use Google Play Billing on this phone at all:
  /// it runs on Android and is signed with Google Play's app signing
  /// certificate. False until the signature check has answered. Where this
  /// is false the Premium screen shows no Play plans, Restore or Manage,
  /// and says that buying through Google Play needs the Google Play
  /// version.
  bool get playSupported => _playBilling != null;

  /// Whether Play answered and can sell on this phone.
  bool get playAvailable => _playAvailable;

  /// Whether this copy can buy through Google Play on this phone now: it
  /// is the copy Google signed ([playSupported]) and Play's billing client
  /// said it can sell here ([playAvailable]). Every offer needs it
  /// ([canBuy]).
  bool get playBilling => playSupported && _playAvailable;

  bool get playLoading => _playLoading;
  PlayFlow get playFlow => _playFlow;
  bool get playBusy =>
      _playFlow == PlayFlow.buying || _playFlow == PlayFlow.confirming;
  bool get isRestoring => _restoring;

  /// Play, only once this copy is known to be the one Google signed. Play
  /// is never created in any other copy.
  PlayBilling? get _playBilling {
    if (!_googleSigned) return null;
    if (!_playMade) {
      _playMade = true;
      _play = _playFactory();
    }
    return _play;
  }

  /// The Play product that sells [plan], with Play's price, or null when
  /// Play does not sell it or has not answered.
  ///
  /// A plan that names a product but no base plan takes the product's base
  /// plans that no other plan names, as the backend does when it matches a
  /// purchase to a plan. It is offered only when exactly one is left,
  /// because with several there is no telling which price and period it
  /// stands for, and Play lists them in no set order.
  PlayProduct? playProductFor(Plan plan) {
    final ref = plan.google;
    if (ref == null) return null;
    final exact = _products[_productKey(ref.productId, ref.basePlanId)];
    if (exact != null || ref.basePlanId != null) return exact;
    final named = {
      for (final other in plans)
        if (other.google?.productId == ref.productId) ?other.google?.basePlanId,
    };
    final left = [
      for (final p in _products.values)
        if (p.productId == ref.productId && !named.contains(p.basePlanId)) p,
    ];
    return left.length == 1 ? left.single : null;
  }

  /// The plan this device's Premium comes from in Google Play, or null when
  /// its Premium is not from Play or the plan is not in the catalog.
  Plan? get currentPlayPlan {
    if (!premium.active || premium.source != 'google_play') return null;
    return plans
        .where((p) => p.code == premium.plan && p.google != null)
        .firstOrNull;
  }

  /// Whether [plan] is the one this device's Premium comes from in Play.
  bool isCurrentPlayPlan(Plan plan) => currentPlayPlan?.code == plan.code;

  /// Whether this phone already subscribes to [plan]'s Play product: Play
  /// says the Google account owns it, or this device's Premium comes from
  /// it. Play holds one base plan of a product per account at a time, so
  /// [plan] is not offered for sale then. The user changes or cancels the
  /// subscription in Google Play ([playManageUrl]).
  bool playSubscribedTo(Plan plan) {
    final product = plan.google?.productId;
    if (product == null) return false;
    return _ownedProducts.contains(product) ||
        currentPlayPlan?.google?.productId == product;
  }

  /// Google Play's page for the subscription this phone has, or the list
  /// of all the account's subscriptions when there is no telling which.
  Uri get playManageUrl {
    final owned = _ownedProducts.length == 1 ? _ownedProducts.single : null;
    return playSubscriptionsUrl(currentPlayPlan?.google?.productId ?? owned);
  }

  /// Google Play's page for [productId]'s subscription in this app, or the
  /// list of all subscriptions when [productId] is null.
  static Uri playSubscriptionsUrl(String? productId) {
    final page = Uri.parse(playSubscriptionsPage);
    if (productId == null) return page;
    return page.replace(
      queryParameters: {'sku': productId, 'package': playPackage},
    );
  }

  /// The plans Play sells on this phone right now.
  List<Plan> get playPlans => [
    if (rails.googlePlay)
      for (final plan in plans)
        if (playProductFor(plan) != null) plan,
  ];

  static String _productKey(String productId, String? basePlanId) =>
      '$productId/${basePlanId ?? ''}';

  /// What goes to Play as the obfuscated account id: the SHA-256 of the
  /// device id's UTF-8 bytes, in lower-case hex. Play never sees the id
  /// itself, which is this device's only credential.
  ///
  /// Google returns it with the purchase
  /// (externalAccountIdentifiers.obfuscatedExternalAccountId). When the
  /// backend meets a purchase no phone has reported, from a Play
  /// notification or its own check, it finds the device whose id hashes to
  /// this value and gives the purchase to it, under the same rules as a
  /// purchase the phone reports. That covers a buyer whose app was
  /// closed before it could report the purchase. A purchase the phone
  /// reports is matched by its token, whatever this value is, so Restore
  /// purchases on a new phone still works.
  static String playAccountId(String deviceId) =>
      sha256.convert(utf8.encode(deviceId)).toString();

  /// Load the status and catalog, then send any Play purchase still waiting
  /// for the backend. Called once, at launch. Never throws.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _readWorked();
    await _readSharing();
    await refresh();
    await _retrySaved();
  }

  Future<void> _readWorked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _worked = prefs.getBool(_workedKey) ?? false;
    } catch (_) {}
  }

  /// Read the diagnostics switch again. Off drops the offer events waiting
  /// on the phone. Returns what it read. Never throws.
  Future<bool> _readSharing() async {
    bool on;
    try {
      final check = _sharingCheck;
      if (check != null) {
        on = await check();
      } else {
        // Unset means on, as for the connection reports.
        final prefs = await SharedPreferences.getInstance();
        on = prefs.get(VpnEventReporter.sharePrefKey) != false;
      }
    } catch (_) {
      // A switch that cannot be read is treated as off: nothing is sent
      // that the user may have said no to.
      on = false;
    }
    sharingChanged(on);
    return on;
  }

  /// The user turned "Share connection diagnostics" on or off. Off drops
  /// the offer events waiting on the phone at once and keeps no new ones,
  /// because the user has said no and an event kept from before must not
  /// go out after that. A purchase still names the offer it came from,
  /// because that is part of the purchase.
  void sharingChanged(bool on) {
    _sharing = on;
    if (on) return;
    _upsellEvents.clear();
    _upsellTimer?.cancel();
    _upsellTimer = null;
  }

  /// The tunnel is up and its traffic checked. From now on offers may show
  /// on this install. Never throws.
  Future<void> noteWorkingConnection() async {
    if (_worked) return;
    _worked = true;
    _notify();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_workedKey, true);
    } catch (e) {
      debugPrint('BillingState: could not note the connection ($e)');
    }
  }

  /// The app came back to the front. Sends any waiting Play purchase, asks
  /// Play for purchases it still holds, and loads again when the last
  /// answer is old. Never throws.
  void resumed() {
    if (!_started) return;
    unawaited(_readSharing());
    unawaited(_retrySaved());
    final at = _loadedAt;
    if (at == null || _now().difference(at) >= refreshAfter) {
      unawaited(refresh());
    } else if (_playOn) {
      final play = _playBilling;
      if (play != null) unawaited(_completeOwned(play));
    }
  }

  /// GET .../billing. Never throws. A call made while one is running
  /// waits for that one.
  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<void> _refresh() async {
    final before = _loaded ? _info.premium : null;
    _loading = true;
    _notify();
    await _readSigned();
    try {
      final id = await _deviceId();
      _info = await _service.info(id);
      _loaded = true;
      _loadFailed = false;
      _loadedAt = _now();
    } catch (e) {
      debugPrint('BillingState: could not load ($e)');
      _loadFailed = true;
    } finally {
      _loading = false;
      _notify();
    }
    _premiumMayHaveChanged(before);
    if (_playOn) await _startPlay(sell: enabled && rails.googlePlay);
  }

  /// Whether this copy is the one Google Play signed, before each load.
  /// PlaySignature asks Android once and remembers the answer, and asks
  /// again only after a check that timed out. Never throws: a check that
  /// fails reads as not signed, so the copy never touches Play.
  Future<void> _readSigned() async {
    bool signed;
    try {
      signed = await _signedCheck();
    } catch (e) {
      debugPrint('BillingState: could not read the signature ($e)');
      signed = false;
    }
    if (signed == _googleSigned) return;
    _googleSigned = signed;
    _notify();
  }

  /// After a load: when Premium came on or went off since [before], the
  /// allowance changed with it, so the quota card is loaded again. Premium
  /// bought outside the app, as a key typed in on another phone or a
  /// purchase the backend found by itself, reaches the phone only this way.
  void _premiumMayHaveChanged(Premium? before) {
    final now = _info.premium;
    if (before == null || before.active == now.active) return;
    final dedicated = _dedicated;
    if (dedicated != null) unawaited(dedicated.refresh());
  }

  /// Listen to Play and finish any purchase Play still holds, and load the
  /// prices when [sell] is set. Only once the backend sells or restores
  /// through Play on this device.
  Future<void> _startPlay({required bool sell}) async {
    final play = _playBilling;
    if (play == null) return;
    try {
      _playPurchases ??= play.purchases.listen(
        _onPurchases,
        onError: (Object e) => debugPrint('BillingState: Play said $e'),
      );
    } catch (e) {
      debugPrint('BillingState: could not listen to Play ($e)');
      return;
    }
    if (sell) await _loadProducts(play);
    await _completeOwned(play);
  }

  Future<void> _loadProducts(PlayBilling play) async {
    final ids = {
      for (final plan in plans)
        if (plan.google != null) plan.google!.productId,
    };
    if (ids.isEmpty) {
      _products = const {};
      return;
    }
    _playLoading = true;
    _notify();
    try {
      _playAvailable = await play.isAvailable();
      // The offers wait for this answer, not for the prices.
      _notify();
      final found = _playAvailable
          ? await play.products(ids)
          : const <PlayProduct>[];
      _products = {
        for (final p in found) _productKey(p.productId, p.basePlanId): p,
      };
    } catch (e) {
      debugPrint('BillingState: could not load Play products ($e)');
      _playAvailable = false;
    } finally {
      _playLoading = false;
      _notify();
    }
  }

  /// Whether this copy can buy through Google Play on this phone, for the
  /// support chat, which sends it with each question as `play_billing`:
  /// the same as [playBilling], except that Play is asked whether it can
  /// sell here when no load has asked it yet, such as while Play sales are
  /// off. A copy Google did not sign never asks Play. Never throws: a Play
  /// that does not answer reads as false.
  Future<bool> checkPlayBilling() async {
    await _readSigned();
    final play = _playBilling;
    if (play == null) return false;
    if (_playAvailable) return true;
    try {
      _playAvailable = await play.isAvailable();
    } catch (e) {
      debugPrint('BillingState: could not ask Play ($e)');
      _playAvailable = false;
    }
    _notify();
    return _playAvailable;
  }

  /// Open Play's purchase sheet for [plan]. The outcome arrives through
  /// Play and shows in [playFlow]. False when the sheet did not open.
  Future<bool> buyOnPlay(Plan plan) async {
    final play = _playBilling;
    final product = playProductFor(plan);
    if (play == null || product == null || playBusy) return false;
    if (playSubscribedTo(plan)) return false;
    _buying = plan;
    _buyingSource = _screens.lastOrNull;
    _flowToken = null;
    _setFlow(PlayFlow.buying);
    try {
      final id = await _deviceId();
      final opened = await play.buy(product, accountId: playAccountId(id));
      if (!opened) {
        _buying = null;
        _setFlow(PlayFlow.failed);
      }
      return opened;
    } catch (e) {
      debugPrint('BillingState: Play did not open ($e)');
      _buying = null;
      _setFlow(PlayFlow.failed);
      return false;
    }
  }

  void _setFlow(PlayFlow flow) {
    _playFlow = flow;
    _notify();
  }

  void _onPurchases(List<PlayPurchase> purchases) {
    for (final p in purchases) {
      switch (p.status) {
        case PlayPurchaseStatus.pending:
          _flowToken = p.token;
          _setFlow(PlayFlow.pending);
        case PlayPurchaseStatus.canceled:
          _buying = null;
          if (_playFlow == PlayFlow.buying) _setFlow(PlayFlow.idle);
        case PlayPurchaseStatus.error:
          _buying = null;
          if (_playFlow == PlayFlow.buying || _playFlow == PlayFlow.pending) {
            _setFlow(PlayFlow.failed);
          }
        case PlayPurchaseStatus.purchased:
        case PlayPurchaseStatus.restored:
          // Bought in the app, so the user asked for it here.
          unawaited(_confirm(p, auto: false));
      }
    }
  }

  /// Send a paid Play purchase to the backend, then complete it in Play.
  /// [show] false keeps [playFlow] as it is, for purchases found in the
  /// background. [auto] is true only for the background check of owned
  /// purchases (see [BillingService.confirmPlay]).
  Future<_Confirmed> _confirm(
    PlayPurchase p, {
    bool show = true,
    required bool auto,
  }) async {
    if (!_confirming.add(p.token)) return _Confirmed.no;
    final buying = _buying;
    final bought = buying != null && buying.google?.productId == p.productId;
    final purchase = _SavedPurchase(
      productId: p.productId,
      token: p.token,
      basePlanId: bought
          ? playProductFor(buying)?.basePlanId ?? buying.google?.basePlanId
          : _basePlanFor(p.productId),
      auto: auto,
      // Only a purchase made from a Premium screen has a source. One found
      // in the background, or restored, has none.
      source: bought && !auto ? _buyingSource?.wire : null,
    );
    if (show) {
      _flowToken = p.token;
      _setFlow(PlayFlow.confirming);
    }
    try {
      await _sendPlay(await _remember(purchase));
      await _completeInPlay(p);
      if (show) _setFlow(PlayFlow.done);
      return _Confirmed.yes;
    } on BillingException catch (e) {
      debugPrint('BillingState: Play purchase not confirmed ($e)');
      final notAvailable = e.reason == BillingException.notAvailable;
      if (show) {
        _setFlow(_flowAfter(e));
        // The plans on screen are out of date. Not for a purchase found in
        // the background: a load can find that same purchase again.
        if (notAvailable) unawaited(refresh());
      }
      return notAvailable ? _Confirmed.notAvailable : _Confirmed.no;
    } finally {
      _confirming.remove(p.token);
      if (bought) {
        _buying = null;
        _buyingSource = null;
      }
    }
  }

  /// A refusal worth sending again later. unknown_product is one: it
  /// means the plan is not set up on the backend yet, and the money is
  /// already taken. not_available is not: Premium is not sold to this
  /// device, and a purchase nobody completes is refunded by Play.
  static bool _keepTrying(BillingException e) =>
      e.isRetryable || e.reason == 'unknown_product';

  /// What the line under the plans says after the backend refused a
  /// purchase with [e]. held_elsewhere shows nothing: only the background
  /// check can get it, and the purchase stays on the phone that has it.
  static PlayFlow _flowAfter(BillingException e) {
    if (_keepTrying(e)) return PlayFlow.retrying;
    return switch (e.reason) {
      BillingException.notAvailable => PlayFlow.notAvailable,
      BillingException.heldElsewhere => PlayFlow.idle,
      _ => PlayFlow.refused,
    };
  }

  /// Tell Play the purchase was delivered. A failure is only logged,
  /// because the backend acknowledges it with Google too.
  Future<void> _completeInPlay(PlayPurchase p) async {
    try {
      await _playBilling?.complete(p);
    } catch (e) {
      debugPrint('BillingState: could not complete in Play ($e)');
    }
  }

  /// The base plan of the only plan sold through [productId], or null.
  String? _basePlanFor(String productId) {
    final matching = [
      for (final plan in plans)
        if (plan.google?.productId == productId) plan.google!,
    ];
    return matching.length == 1 ? matching.single.basePlanId : null;
  }

  /// POST .../billing/google for one purchase, with the auto flag it was
  /// saved with. Forgets the token once the backend has answered for good,
  /// either way.
  ///
  /// A success or a held_elsewhere answer also notes the token as handled
  /// ([_noteHandled]), so the background check never sends it again. The
  /// note is written before the token is forgotten, so a check that finds
  /// the token in neither list knows nobody has handled it.
  ///
  /// When the line under the plans is about this purchase and still says
  /// it is pending or being retried, it is settled here too, because a
  /// purchase sent again in the background never goes through [_confirm]
  /// with the line shown.
  Future<void> _sendPlay(_SavedPurchase saved) async {
    final id = await _deviceId();
    try {
      final result = await _service.confirmPlay(
        id,
        productId: saved.productId,
        purchaseToken: saved.token,
        basePlanId: saved.basePlanId,
        auto: saved.auto,
        source: saved.source,
      );
      await _noteHandled(saved.token);
      await _forget(saved.token);
      _grant(result.premium, result.quota);
      _settleFlow(saved.token, PlayFlow.done);
    } on BillingException catch (e) {
      if (!_keepTrying(e)) {
        if (e.reason == BillingException.heldElsewhere) {
          await _noteHandled(saved.token);
        }
        await _forget(saved.token);
        _settleFlow(saved.token, _flowAfter(e));
      }
      rethrow;
    }
  }

  /// Move the line under the plans to [flow] when it is about [token] and
  /// still waits on the backend or on Play.
  void _settleFlow(String token, PlayFlow flow) {
    if (_flowToken != token) return;
    if (_playFlow != PlayFlow.retrying && _playFlow != PlayFlow.pending) {
      return;
    }
    _flowToken = null;
    _setFlow(flow);
  }

  /// Send every Play purchase the backend has not confirmed yet. Needs only
  /// the backend, not Play. Never throws.
  Future<void> _retrySaved() async {
    for (final saved in await _saved()) {
      if (!_confirming.add(saved.token)) continue;
      try {
        await _sendPlay(saved);
      } catch (e) {
        debugPrint('BillingState: saved Play purchase not sent ($e)');
      } finally {
        _confirming.remove(saved.token);
      }
    }
  }

  /// The silent background check of owned purchases, at launch and on
  /// every return to the app. Confirms the purchases Play still waits on,
  /// such as one paid while the app was closed, notes what the account
  /// owns, and on a phone without Premium restores what the account
  /// already pays for. Every new send from here has auto true. A purchase
  /// already waiting as the user's own request keeps auto false (see
  /// [_remember]). Never throws.
  ///
  /// A purchase Play still waits on whose token this phone has already
  /// handled is completed in Play without asking the backend again: the
  /// backend took it up, here or on another phone, and acknowledges it
  /// with Google too, so this only covers an acknowledgement that failed.
  Future<void> _completeOwned(PlayBilling play) async {
    final List<PlayPurchase> owned;
    try {
      owned = await play.owned();
    } catch (e) {
      debugPrint('BillingState: could not ask Play what is owned ($e)');
      return;
    }
    _noteOwned(owned);
    final handled = await _handled();
    for (final p in owned) {
      if (p.status != PlayPurchaseStatus.purchased || !p.needsCompleting) {
        continue;
      }
      if (handled.contains(p.token)) {
        await _completeInPlay(p);
      } else {
        await _confirm(p, show: false, auto: true);
      }
    }
    if (rails.playRestore && !premium.active) await _restoreOwned(owned);
  }

  /// Restore purchases on its own, for a phone without Premium whose Google
  /// account already pays for a subscription: a subscriber on a new phone
  /// or after a factory reset, which gives the phone a new device id.
  /// Nothing new shows on screen unless Premium comes on.
  ///
  /// The send has auto true. The backend takes up a purchase no other
  /// phone holds, under the same rules as Restore purchases, but
  /// never moves one that runs on another phone that still exists: it
  /// answers held_elsewhere, and this phone notes the token and shows
  /// nothing. Two phones signed in to one Google account therefore never
  /// take the subscription from each other in the background, and never
  /// use up the move limit doing so. The user moves it with Restore
  /// purchases on the Premium screen, which sends auto false.
  ///
  /// Only tokens this phone has not handled yet are sent ([_handledKey]),
  /// and each is noted before it is sent, so it is sent from here once. A
  /// send that gets no answer is not lost: [_confirm] keeps the token with
  /// its auto flag, and it is sent again at launch and on every return to
  /// the app until the backend answers.
  Future<void> _restoreOwned(List<PlayPurchase> owned) async {
    // The waiting list is read first. A send that finishes in between
    // notes its token before forgetting it, so it shows up in one of them.
    final waiting = {for (final s in await _saved()) s.token};
    final handled = await _handled();
    for (final p in owned) {
      if (premium.active) return;
      final paid =
          p.status == PlayPurchaseStatus.purchased ||
          p.status == PlayPurchaseStatus.restored;
      if (!paid || p.needsCompleting || handled.contains(p.token)) continue;
      // Already on its way to the backend: being sent now, or waiting to
      // be sent again with the flag it was first sent with.
      if (_confirming.contains(p.token) || waiting.contains(p.token)) continue;
      await _noteHandled(p.token);
      await _confirm(p, show: false, auto: true);
    }
  }

  /// What Play just said this Google account owns, for [playSubscribedTo].
  void _noteOwned(List<PlayPurchase> owned) {
    final products = {
      for (final p in owned)
        if (p.status == PlayPurchaseStatus.purchased ||
            p.status == PlayPurchaseStatus.restored)
          p.productId,
    };
    if (setEquals(products, _ownedProducts)) return;
    _ownedProducts = products;
    _notify();
  }

  /// Restore purchases: send every purchase this Google account owns to
  /// the backend, which moves it to this device. For a new phone, or after
  /// a reinstall.
  ///
  /// The user asked for it, so each send has auto false and may move a
  /// purchase from another phone, counted against the move limit. The
  /// backend never answers held_elsewhere to such a send, so there is no
  /// text for it here. A token restored this way is noted as handled, and
  /// the background check never sends it again.
  Future<RestoreOutcome> restorePlay() async {
    final play = _playBilling;
    if (play == null || _restoring) return RestoreOutcome.unavailable;
    _restoring = true;
    _notify();
    try {
      final List<PlayPurchase> owned;
      try {
        if (!await play.isAvailable()) return RestoreOutcome.unavailable;
        owned = await play.owned();
      } catch (e) {
        debugPrint('BillingState: could not restore ($e)');
        return RestoreOutcome.unavailable;
      }
      _noteOwned(owned);
      final paid = [
        for (final p in owned)
          if (p.status == PlayPurchaseStatus.purchased ||
              p.status == PlayPurchaseStatus.restored)
            p,
      ];
      if (paid.isEmpty) return RestoreOutcome.nothing;
      var restored = false;
      var notAvailable = false;
      for (final p in paid) {
        switch (await _confirm(p, show: false, auto: false)) {
          case _Confirmed.yes:
            restored = true;
          case _Confirmed.notAvailable:
            notAvailable = true;
          case _Confirmed.no:
            break;
        }
      }
      if (restored) return RestoreOutcome.restored;
      if (!notAvailable) return RestoreOutcome.failed;
      unawaited(refresh());
      return RestoreOutcome.notAvailable;
    } finally {
      _restoring = false;
      _notify();
    }
  }

  /// POST .../billing/redeem. Throws [BillingException] for a refusal.
  Future<RedeemResult> redeem(String code) async {
    final id = await _deviceId();
    final result = await _refusedWith(() => _service.redeem(id, code));
    _grant(result.premium, result.quota);
    return result;
  }

  /// Run [call], and load again when the backend says Premium is not sold
  /// to this device. The answer the phone holds still offers Premium, so
  /// the entry points should follow the backend's new answer now rather
  /// than at the next load. Only for calls the user made, because a load
  /// can find a background Play purchase again, and that must not loop.
  Future<T> _refusedWith<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on BillingException catch (e) {
      if (e.reason == BillingException.notAvailable) unawaited(refresh());
      rethrow;
    }
  }

  /// A Premium screen opened from [source]. Purchases made while it is the
  /// newest one open carry [source].
  ///
  /// The offer events waiting on the phone go now, before any purchase can
  /// start. The backend notes for each batch whether this device could be
  /// offered Premium when it arrived, and a batch that landed after the
  /// purchase would count the buyer's own offer as one shown to a device
  /// that may not see offers.
  void premiumScreenOpened(PremiumSource source) {
    _screens.add(source);
    unawaited(sendUpsellEvents());
  }

  /// That screen closed.
  void premiumScreenClosed(PremiumSource source) {
    final at = _screens.lastIndexOf(source);
    if (at >= 0) _screens.removeAt(at);
  }

  /// Note what happened to an offer, for the backend's count of which
  /// offers are seen and which sell. "shown" counts once per surface per
  /// run of the app. The events wait on the phone and go in one call
  /// [upsellSendEvery] after the first, when a Premium screen opens, or
  /// when the app is left ([sendUpsellEvents]). Nothing is kept while the
  /// user does not share connection diagnostics, and no "shown" once the
  /// device has Premium (see [sendUpsellEvents]). Never throws.
  void logUpsell(UpsellSurface surface, UpsellAction action) {
    if (_disposed || !_sharing) return;
    if (action == UpsellAction.shown) {
      if (premium.active || !_shownThisRun.add(surface)) return;
    }
    _upsellEvents.add({
      'surface': surface.wire,
      'action': action.name,
      'at': _now().toUtc().toIso8601String(),
    });
    _trimUpsellEvents();
    _upsellTimer ??= Timer(upsellSendEvery, () {
      _upsellTimer = null;
      unawaited(sendUpsellEvents());
    });
  }

  void _trimUpsellEvents() {
    const most = BillingService.maxEvents;
    if (_upsellEvents.length > most) {
      _upsellEvents.removeRange(0, _upsellEvents.length - most);
    }
  }

  /// Send the waiting offer events now. Called when the app is left, when
  /// a Premium screen opens, and by the timer [logUpsell] starts. A call
  /// made while a send is going sends what arrived meanwhile right after
  /// it, when that send went through. A send that gets no answer is kept
  /// for the next one. A backend without the route (404 or 405) gets
  /// nothing again until the next event. The diagnostics switch is read
  /// again first, and off drops the events instead. Never throws.
  ///
  /// The batch carries the phone's clock when it goes out (`sent_at`), so
  /// the backend can put each event on its own clock and file it on the
  /// right Tehran day.
  ///
  /// Once the device has Premium, the "shown" events still waiting are
  /// dropped. The backend checks the offer gate when a batch arrives, and a
  /// Premium device is outside it, so a view sent after the purchase it
  /// led to would be counted as an offer shown to a device that may not
  /// see one. What was tapped or closed still goes.
  Future<void> sendUpsellEvents() async {
    if (_sendingUpsell) {
      _sendUpsellAgain = true;
      return;
    }
    _upsellTimer?.cancel();
    _upsellTimer = null;
    if (premium.active) {
      _upsellEvents.removeWhere((e) => e['action'] == UpsellAction.shown.name);
    }
    if (_upsellEvents.isEmpty) return;
    _sendingUpsell = true;
    var sent = false;
    try {
      if (!await _readSharing()) return;
      final batch = List.of(_upsellEvents);
      _upsellEvents.clear();
      try {
        final id = await _deviceId();
        await _service.upsellEvents(id, batch, sentAt: _now());
        sent = true;
      } on BillingException catch (e) {
        debugPrint('BillingState: offer events not sent ($e)');
        if (e.isRetryable && e.reason != BillingException.notFound) {
          _upsellEvents.insertAll(0, batch);
          _trimUpsellEvents();
        }
      } catch (e) {
        debugPrint('BillingState: offer events not sent ($e)');
      }
    } finally {
      _sendingUpsell = false;
    }
    final again = _sendUpsellAgain;
    _sendUpsellAgain = false;
    // After a failed send the events wait for the timer, which an event
    // that arrived meanwhile has started, rather than going again at once.
    if (again && sent && !_disposed) await sendUpsellEvents();
  }

  /// The offer events waiting to be sent, for tests.
  @visibleForTesting
  List<Map<String, Object?>> get pendingUpsellEvents =>
      List.unmodifiable(_upsellEvents);

  /// A new Premium status from an answer. The allowance changes with it,
  /// so the quota card is told at once and the servers are loaded again.
  void _grant(Premium premium, QuotaStatus? quota) {
    _info = _info.withPremium(premium);
    _notify();
    final dedicated = _dedicated;
    if (dedicated == null) return;
    if (quota != null) dedicated.adoptQuota(quota);
    unawaited(dedicated.refresh());
  }

  /// What a load would leave behind, with Play's products and the
  /// products Play says the account owns, for tests that have no backend
  /// and no Play.
  ///
  /// [googleSigned] is what the signature check would have said. Play's
  /// answer that it can sell here ([playAvailable]) is yes unless
  /// [playAvailable] says otherwise. A copy can buy through Play only with
  /// a Play to talk to as well, which the test passes to the constructor.
  @visibleForTesting
  void adoptForTest(
    BillingInfo info, {
    List<PlayProduct> products = const [],
    Set<String> owned = const {},
    bool googleSigned = true,
    bool playAvailable = true,
  }) {
    _info = info;
    _loaded = true;
    _loadFailed = false;
    _googleSigned = googleSigned;
    _playAvailable = playAvailable;
    _products = {
      for (final p in products) _productKey(p.productId, p.basePlanId): p,
    };
    _ownedProducts = owned;
    _notify();
  }

  /// Whether the tunnel has worked on this install, for tests.
  @visibleForTesting
  void adoptWorkedForTest({bool worked = true}) {
    _worked = worked;
    _notify();
  }

  /// Forget everything about the deleted account. In memory only.
  /// Unconfirmed Play purchases are kept, because they are paid for and
  /// must still reach the backend.
  void reset() {
    _info = BillingInfo.off;
    _loaded = false;
    _loadFailed = false;
    _loadedAt = null;
    _products = const {};
    _playFlow = PlayFlow.idle;
    _flowToken = null;
    _buying = null;
    _buyingSource = null;
    _worked = false;
    // They name the deleted device.
    _upsellEvents.clear();
    _upsellTimer?.cancel();
    _upsellTimer = null;
    _sendUpsellAgain = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _playPurchases?.cancel();
    _upsellTimer?.cancel();
    super.dispose();
  }

  // The phone's notes: Play purchases waiting for the backend, and the
  // tokens already handled.

  Future<List<_SavedPurchase>> _saved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_unconfirmedPlayKey);
      if (raw == null) return const [];
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [for (final e in list) ?_SavedPurchase.fromJson(e)];
    } catch (e) {
      debugPrint('BillingState: could not read saved purchases ($e)');
      return const [];
    }
  }

  Future<void> _writeSaved(List<_SavedPurchase> saved) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (saved.isEmpty) {
        await prefs.remove(_unconfirmedPlayKey);
      } else {
        await prefs.setString(
          _unconfirmedPlayKey,
          jsonEncode([for (final s in saved) s.toJson()]),
        );
      }
    } catch (e) {
      debugPrint('BillingState: could not save purchases ($e)');
    }
  }

  /// Keep [purchase] until the backend answers for good, and return what
  /// is kept. A token already waiting as a send the user made (auto false)
  /// stays one: the user asked for that move, and finding the purchase
  /// again in the background check does not take the request back.
  Future<_SavedPurchase> _remember(_SavedPurchase purchase) async {
    final before = await _saved();
    final asked = before.any((s) => s.token == purchase.token && !s.auto);
    // Found again in the background, it keeps the source it was bought with.
    final source =
        purchase.source ??
        before.where((s) => s.token == purchase.token).firstOrNull?.source;
    final kept = _SavedPurchase(
      productId: purchase.productId,
      token: purchase.token,
      basePlanId: purchase.basePlanId,
      auto: asked ? false : purchase.auto,
      source: source,
    );
    final saved = [
      for (final s in before)
        if (s.token != purchase.token) s,
      kept,
    ];
    final start = saved.length > _maxSavedPurchases
        ? saved.length - _maxSavedPurchases
        : 0;
    await _writeSaved(saved.sublist(start));
    return kept;
  }

  Future<void> _forget(String token) async {
    final saved = await _saved();
    final left = [
      for (final s in saved)
        if (s.token != token) s,
    ];
    if (left.length != saved.length) await _writeSaved(left);
  }

  /// The Play purchase tokens this phone has handled ([_handledKey]).
  Future<Set<String>> _handled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {...?prefs.getStringList(_handledKey)};
    } catch (_) {
      return const {};
    }
  }

  /// Note [token] as handled, so the background check never sends it to
  /// the backend again. The newest notes are kept. A Google account owns
  /// few purchases at a time, and a token that falls off the end is sent
  /// again only with auto true, which never takes a purchase from a phone
  /// that still has it.
  Future<void> _noteHandled(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokens = <String>[
        for (final t in prefs.getStringList(_handledKey) ?? const [])
          if (t != token) t,
        token,
      ];
      final start = tokens.length > _maxSavedPurchases
          ? tokens.length - _maxSavedPurchases
          : 0;
      await prefs.setStringList(_handledKey, tokens.sublist(start));
    } catch (e) {
      debugPrint('BillingState: could not note the purchase ($e)');
    }
  }

  /// The tokens of the Play purchases waiting for the backend, for tests.
  @visibleForTesting
  Future<List<String>> savedPlayTokens() async => [
    for (final s in await _saved()) s.token,
  ];

  /// The Play purchase tokens this phone has handled, for tests.
  @visibleForTesting
  Future<Set<String>> handledPlayTokens() => _handled();
}

/// A Play purchase the backend has not confirmed yet.
class _SavedPurchase {
  const _SavedPurchase({
    required this.productId,
    required this.token,
    this.basePlanId,
    this.auto = false,
    this.source,
  });

  final String productId;
  final String token;
  final String? basePlanId;

  /// Where the Premium screen it was bought on was opened from
  /// (PremiumSource.wire), or null.
  final String? source;

  /// Whether it came from the background check of owned purchases.
  /// Sending it again keeps the flag, so a background send never turns
  /// into a move. False, as the backend's default is, for an entry saved
  /// without it.
  final bool auto;

  static _SavedPurchase? fromJson(Object? json) {
    if (json is! Map) return null;
    final product = readText(json['product_id']);
    final token = readText(json['purchase_token']);
    if (product == null || token == null) return null;
    return _SavedPurchase(
      productId: product,
      token: token,
      basePlanId: readText(json['base_plan_id']),
      auto: json['auto'] == true,
      source: readText(json['source']),
    );
  }

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'purchase_token': token,
    'base_plan_id': basePlanId,
    'auto': auto,
    'source': ?source,
  };
}
