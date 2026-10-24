import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/app_config.dart';
import '../../services/ipv6_reach.dart';
import '../../services/tunnel_channels.dart';
import '../../utils/carrier_name.dart';
import '../form_factor.dart';

/// What the phone says about itself and the network it is on, as
/// [ApnGuide] reads it. A null is a fact the platform did not give.
typedef ApnGuidePhone = ({
  String? manufacturer,
  String? network,
  String? carrier,
  bool? ipv6Route,
});

/// When the home screen shows the card on giving the SIM IPv6 (by setting
/// the phone's APN protocol to "IPv4/IPv6"), what it reads from the phone
/// to decide, and the card's "Not now". The card is ApnGuideCard.
///
/// IPv6 often gets through where our IPv4 door addresses are blocked, so a
/// phone with IPv6 connects more often. Many phones on mobile data have no
/// IPv6, and it splits by maker. The likely cause is the APN protocol the
/// phone keeps for the SIM: Samsung ships "IPv4" for some Iranian operators.
///
/// Off until the backend turns it on (the `apn_guide` block, see
/// ApnGuideSettings), which waits for the owner to try the steps on a
/// real Samsung with an MCI SIM. Then [shouldShow] decides.
///
/// Nothing about the guide is sent anywhere: not that it showed, nor that
/// anyone followed it, because reporting it would change what the Play
/// Data safety form declares. Its effect is measured from what the
/// backend already has: the IPv6 door checks phones report, which show by
/// maker and carrier how many phones have an IPv6 route.
///
/// Every read here is of the phone's own settings and sends nothing, and
/// none of it throws.
class ApnGuide extends ChangeNotifier {
  ApnGuide({
    bool? android,
    Future<String?> Function()? manufacturer,
    Future<({String? network, String? carrier})> Function()? network,
    Future<bool?> Function()? ipv6Route,
    Future<bool> Function()? openSettings,
    DateTime Function()? clock,
  }) : _android = android ?? Platform.isAndroid,
       _readManufacturer = manufacturer ?? _platformManufacturer,
       _readNetwork = network ?? _platformNetwork,
       _readIpv6Route = ipv6Route ?? Ipv6Reach.platformRoute,
       _openSettings = openSettings ?? _platformOpenSettings,
       _clock = clock ?? DateTime.now;

  /// When "Not now" was last tapped, as ISO text in UTC.
  static const apnGuideDismissedKey = 'apn_guide_dismissed_at';

  /// How long "Not now" keeps the card away.
  static const quietFor = Duration(days: 14);

  /// The access point each operator's SIM carries mobile data through, as
  /// the steps name it. The steps name none for any other operator.
  static const apnNames = {
    CarrierName.hamrahAval: 'mcinet',
    CarrierName.irancell: 'mtnirancell',
  };

  /// How long one read of the platform may take.
  static const _timeout = Duration(seconds: 2);

  final bool _android;
  final Future<String?> Function() _readManufacturer;
  final Future<({String? network, String? carrier})> Function() _readNetwork;
  final Future<bool?> Function() _readIpv6Route;
  final Future<bool> Function() _openSettings;
  final DateTime Function() _clock;

  ApnGuideSettings? _settings;
  ApnGuidePhone? _phone;

  /// Read once: the maker does not change while the app runs.
  String? _manufacturer;

  DateTime? _dismissedAt;
  bool _dismissalRead = false;

  /// Counts the reads [refresh] starts. A read that a later one overtook
  /// is dropped when it ends.
  int _reads = 0;

  /// Whether the card shows, from everything it depends on. Pure, so each
  /// condition has its own test.
  ///
  /// All of these must hold: the backend turned the guide on
  /// ([settings]); the app runs on Android and not on a TV; the phone's
  /// maker is one of the backend's brands; the phone is on mobile data,
  /// from one of the backend's carriers in any of its spellings; the
  /// phone has no IPv6 route right now ([ipv6Route] false; null, which is
  /// a phone that could not tell, keeps the card away); "Not now" was not
  /// tapped within [quietFor]; and no connect is under way.
  static bool shouldShow({
    required ApnGuideSettings? settings,
    required bool android,
    required bool tv,
    required String? manufacturer,
    required String? network,
    required String? carrier,
    required bool? ipv6Route,
    required DateTime? dismissedAt,
    required DateTime now,
    required bool connecting,
  }) {
    if (settings == null) return false;
    if (!android || tv) return false;
    if (!settings.coversBrand(manufacturer)) return false;
    if (network != 'mobile') return false;
    if (!settings.coversCarrier(carrier)) return false;
    if (ipv6Route != false) return false;
    if (dismissedAt != null && now.difference(dismissedAt) < quietFor) {
      return false;
    }
    return !connecting;
  }

  /// Whether the card is on the home screen now. [connecting] is whether
  /// a connect is under way, which the screen knows without a read.
  bool shows({required bool connecting}) {
    final phone = _phone;
    if (phone == null || !_dismissalRead) return false;
    return shouldShow(
      settings: _settings,
      android: _android,
      tv: FormFactor.isTv,
      manufacturer: phone.manufacturer,
      network: phone.network,
      carrier: phone.carrier,
      ipv6Route: phone.ipv6Route,
      dismissedAt: _dismissedAt,
      now: _clock(),
      connecting: connecting,
    );
  }

  /// The access point the steps name for the operator the phone is on,
  /// or null for an operator whose access point the app does not know.
  String? get apn => apnNames[CarrierName.normalise(_phone?.carrier)];

  /// Read the phone again, for [settings], the backend's latest.
  ///
  /// The home screen calls this when it opens, when the config changes,
  /// and when the app comes back to the front, which is when a change made
  /// in the APN screen takes effect. Reads nothing while the guide is off
  /// or cannot show here (iOS, Windows, a TV). Never throws.
  Future<void> refresh(ApnGuideSettings? settings) async {
    final read = ++_reads;
    _settings = settings;
    if (settings == null || !_android || FormFactor.isTv) {
      _phone = null;
      notifyListeners();
      return;
    }
    ApnGuidePhone? phone;
    try {
      await _readDismissal();
      final manufacturer = _manufacturer ??= await _readManufacturer();
      final network = await _readNetwork();
      final route = await _readIpv6Route();
      phone = (
        manufacturer: manufacturer,
        network: network.network,
        carrier: network.carrier,
        ipv6Route: route,
      );
    } catch (e) {
      debugPrint('ApnGuide: could not read the phone ($e)');
    }
    if (read != _reads) return;
    _phone = phone;
    notifyListeners();
  }

  /// "Not now": the card goes away for [quietFor]. Never throws.
  Future<void> dismiss() async {
    final now = _clock();
    _dismissedAt = now;
    _dismissalRead = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        apnGuideDismissedKey,
        now.toUtc().toIso8601String(),
      );
    } catch (e) {
      debugPrint('ApnGuide: could not save "Not now" ($e)');
    }
  }

  /// Open the phone's list of access points, or the closest screen it has.
  /// False when nothing opened. Never throws.
  Future<bool> openApnSettings() async {
    try {
      return await _openSettings();
    } catch (e) {
      debugPrint('ApnGuide: could not open the APN settings ($e)');
      return false;
    }
  }

  /// When "Not now" was last tapped, read from the phone's storage once
  /// per run. A copy that cannot be read is no "Not now".
  Future<void> _readDismissal() async {
    if (_dismissalRead) return;
    DateTime? at;
    try {
      final prefs = await SharedPreferences.getInstance();
      at = DateTime.tryParse(prefs.getString(apnGuideDismissedKey) ?? '');
    } catch (e) {
      debugPrint('ApnGuide: could not read "Not now" ($e)');
    }
    // A tap on "Not now" while the read ran is newer than what it found.
    if (_dismissalRead) return;
    _dismissedAt = at;
    _dismissalRead = true;
  }

  /// Android's name for the maker (Build.MANUFACTURER), "samsung" or
  /// "Xiaomi", read through device_info_plus as register reads it for the
  /// device model (DeviceFacts). Null when the platform did not say, and
  /// then the next refresh asks again.
  static Future<String?> _platformManufacturer() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo.timeout(_timeout);
      final maker = info.manufacturer.trim();
      return maker.isEmpty ? null : maker;
    } catch (_) {
      return null;
    }
  }

  /// The network the app's own sockets use ("mobile" for mobile data) and
  /// the operator the phone is on, as MainActivity.networkFacts reads them.
  /// The app is left out of its own tunnel, so this is the line under the
  /// tunnel even while connected.
  static Future<({String? network, String? carrier})> _platformNetwork() async {
    try {
      final raw = await TunnelChannels.method
          .invokeMethod<Map<Object?, Object?>>('networkFacts')
          .timeout(_timeout);
      final network = raw?['network'];
      final carrier = raw?['carrier'];
      return (
        network: network is String ? network : null,
        carrier: carrier is String ? carrier : null,
      );
    } catch (_) {
      // An older native side, a timeout or a platform error: the card
      // stays away.
      return (network: null, carrier: null);
    }
  }

  static Future<bool> _platformOpenSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      return await TunnelChannels.method.invokeMethod<bool>(
            'openApnSettings',
          ) ??
          false;
    } catch (_) {
      // An older native side or a platform error. The steps still say
      // where the screen is.
      return false;
    }
  }
}
