import 'package:flutter/foundation.dart';

import '../../api/api_client.dart';
import '../../api/device_service.dart';
import '../../api/referral_service.dart';
import '../../services/install_referrer.dart';

/// This device's invite code, what it has earned, and the claim it made.
///
/// The whole feature is optional. Nothing here is loaded until the user
/// opens the invite screen or taps a button on the invite card, except the
/// Android install-referrer read, which runs on an early launch and is
/// silent when it finds nothing.
class ReferralState extends ChangeNotifier {
  /// [language] gives the app's language for `?lang=`, so the shared link
  /// opens the invite page in it. The other arguments are for tests.
  ReferralState({
    String Function()? language,
    ReferralService? service,
    Future<String> Function()? deviceId,
    Future<void> Function()? register,
    Future<String?> Function()? pendingReferrer,
    Future<void> Function()? settleReferrer,
  }) : _language = language,
       _service = service ?? ReferralService(),
       _deviceId = deviceId ?? DeviceService().getDeviceId,
       _register = register ?? _registerDevice,
       _pendingReferrer = pendingReferrer ?? InstallReferrer.pendingCode,
       _settleReferrer = settleReferrer ?? InstallReferrer.settle;

  final String Function()? _language;
  final ReferralService _service;
  final Future<String> Function() _deviceId;
  final Future<void> Function() _register;
  final Future<String?> Function() _pendingReferrer;
  final Future<void> Function() _settleReferrer;

  static Future<void> _registerDevice() async {
    await DeviceService().registerDevice();
  }

  ReferralStatus? _status;
  bool _isLoading = false;
  bool _isClaiming = false;
  String? _errorMessage;

  /// Set when a claim succeeds, so the screen that asked can confirm it
  /// without re-reading the status first.
  bool _justClaimed = false;

  /// A claim with the install referrer's code is under way. One at a time
  /// per run, whichever of launch, the config reload or a connect asked.
  bool _referrerRunning = false;

  ReferralStatus? get status => _status;
  bool get isLoading => _isLoading;
  bool get isClaiming => _isClaiming;
  String? get errorMessage => _errorMessage;
  bool get justClaimed => _justClaimed;

  bool get hasStatus => _status != null;

  /// Whether this device can still be invited by someone.
  ///
  /// Only ever a hint for the UI. The backend owns the real rule, which
  /// also includes the claim window (claim_window_hours) this cannot see.
  bool get canClaim => !(_status?.hasClaimed ?? false) && !_justClaimed;

  /// Whether this device has used an invite code, as far as this run knows:
  /// a claim in this run, or the loaded status says so.
  bool get hasClaimed => _justClaimed || (_status?.hasClaimed ?? false);

  /// Whether this device's invites have already added the most daily data
  /// that invites give (ReferralStatus.maxBonusBytes), so a further invite
  /// adds none. False while no status is loaded in this run of the app (the
  /// invite screen loads it), so before then invites still count as a free
  /// way to more data.
  bool get dataBonusSpent {
    final status = this.status;
    final most = status?.maxBonusBytes;
    return status != null && most != null && status.bonusBytes >= most;
  }

  /// Whether a further invite adds no daily data: the bonus is at the most
  /// ([dataBonusSpent]), or, under the tree rule, the backend says the next
  /// friend adds nothing (ReferralStatus.nextInviteBytes is null). False
  /// while no status is loaded, so before then invites still count as a
  /// free way to more data. The limit sheet, the invite link on the spent
  /// server card, the home data line and the tree introduction all ask
  /// this one question.
  bool get invitesAddNoMore {
    final status = this.status;
    if (status == null) return false;
    return dataBonusSpent || (status.isTree && status.nextInviteBytes == null);
  }

  Future<ReferralStatus> _load(String deviceId) =>
      _service.getStatus(deviceId, lang: _language?.call());

  /// The load under way, which a second caller waits for.
  Future<void>? _inFlight;

  /// Load the code and counts, minting the code on the backend if this is
  /// the first time this device has asked for one.
  ///
  /// A call made while a load is under way waits for that load instead of
  /// starting a second one. The limit sheet starts a load as it opens, and
  /// a quick tap on its Share button must wait for that load rather than
  /// find no code.
  Future<void> refresh() =>
      _inFlight ??= _refresh().whenComplete(() => _inFlight = null);

  Future<void> _refresh() async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final deviceId = await _deviceId();
      _status = await _load(deviceId);
    } on ApiException catch (e) {
      // A device the backend has never seen has no code yet. Registering
      // is cheap and idempotent, and it is what the rest of the app does
      // in the same situation.
      if (e.isNotFound) {
        try {
          await _register();
          final deviceId = await _deviceId();
          _status = await _load(deviceId);
        } on ApiException catch (retry) {
          _errorMessage = retry.message;
        }
      } else {
        _errorMessage = e.message;
      }
    } catch (_) {
      _errorMessage = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Enter a code somebody shared.
  ///
  /// Returns the outcome so the caller can word its own message. Nothing
  /// is granted to this device by claiming: the reward goes to whoever
  /// shared the code, and only after this device has really used the VPN.
  ///
  /// A claim that goes through re-reads the status only when one was
  /// loaded already. The first read mints a code, and a friend who only
  /// entered a code has not asked for one. A 409 (another code was used
  /// before) re-reads nothing either.
  Future<ReferralClaimResult> claim(
    String code, {
    String source = 'manual',
  }) async {
    if (_isClaiming) {
      return const ReferralClaimResult.failed(null);
    }
    _isClaiming = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final deviceId = await _deviceId();
      var result = await _service.claim(deviceId, code, source: source);

      // The provisioning path registers lazily too, so a claim can be the
      // first call this install ever makes.
      if (result.failure == ReferralClaimFailure.unknownDevice) {
        await _register();
        result = await _service.claim(deviceId, code, source: source);
      }

      if (result.claimed) {
        _justClaimed = true;
        // Refreshing rewrites claimed_code, which is what the invite
        // screen shows back to the user.
        if (_status != null) await _reloadQuietly();
      }
      return result;
    } finally {
      _isClaiming = false;
      notifyListeners();
    }
  }

  /// Claim the code the Play install referrer carried, if one still waits.
  ///
  /// Android only, and silent throughout. On iOS, a sideloaded APK, or a
  /// device without Play Services this does nothing at all, which is why
  /// entering a code by hand has to stay available everywhere. The code is
  /// kept until the claim has an answer, accepted or refused, so a claim
  /// lost on the network is tried again at the next launch, config reload
  /// or connect. Never throws.
  Future<void> claimFromInstallReferrer() async {
    if (_referrerRunning) return;
    _referrerRunning = true;
    try {
      final code = await _pendingReferrer();
      if (code == null || code.isEmpty) return;
      final result = await claim(code, source: 'play_referrer');
      if (_answered(result)) await _settleReferrer();
    } catch (e) {
      debugPrint('ReferralState: install referrer claim failed ($e)');
    } finally {
      _referrerRunning = false;
    }
  }

  /// Whether the backend gave [result] as its answer about the code, so
  /// trying again would get the same one.
  static bool _answered(ReferralClaimResult result) {
    if (result.claimed) return true;
    return switch (result.failure) {
      ReferralClaimFailure.alreadyClaimed ||
      ReferralClaimFailure.tooLate ||
      ReferralClaimFailure.unknownCode ||
      ReferralClaimFailure.ownCode ||
      ReferralClaimFailure.mutual ||
      ReferralClaimFailure.rejected => true,
      ReferralClaimFailure.limited ||
      ReferralClaimFailure.unexpected ||
      ReferralClaimFailure.unknownDevice ||
      ReferralClaimFailure.network ||
      null => false,
    };
  }

  Future<void> _reloadQuietly() async {
    try {
      final deviceId = await _deviceId();
      _status = await _load(deviceId);
    } catch (_) {
      // The claim already succeeded. Failing to re-read the counts is a
      // stale screen, not a failed action, and the next refresh fixes it.
    }
  }

  /// Drop everything after an account deletion.
  ///
  /// The backend row is gone, so the code and the counts describe a
  /// device that no longer exists.
  void reset() {
    _status = null;
    _isLoading = false;
    _isClaiming = false;
    _errorMessage = null;
    _justClaimed = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// What a load would leave behind, for tests that have no backend.
  @visibleForTesting
  void adoptForTest(ReferralStatus status) {
    _status = status;
    notifyListeners();
  }
}
