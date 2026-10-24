import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vpn_event_reporter.dart';
import 'tunnel_channels.dart';

/// Where the phone is, as the phone knows it, for the backend to place the
/// device in a country.
///
/// The backend used to read the country off the address a call arrived
/// from. Many users open the app with another VPN on, so their calls arrive
/// from that VPN's server and they were counted in Germany or the US. The
/// cell network's country, the SIM's country and the time zone do not
/// change with a VPN, and the backend decides from them first.
///
/// Sent with register and with every events batch, as `place`. Country
/// codes and a time zone id only: nothing finer than a country is read, and
/// nothing is sent when the user has turned diagnostics off.
class DevicePlace {
  DevicePlace({
    MethodChannel? channel,
    Future<SharedPreferences> Function()? prefs,
  }) : _channel = channel ?? TunnelChannels.method,
       _prefs = prefs ?? SharedPreferences.getInstance;

  static const timeout = Duration(seconds: 1);

  /// The keys the backend reads. Anything else the platform adds stays on
  /// the phone.
  static const keys = {
    'network_country',
    'sim_country',
    'roaming',
    'time_zone',
    'other_vpn',
  };

  final MethodChannel _channel;
  final Future<SharedPreferences> Function() _prefs;

  /// The place, or null when there is nothing to send. Never throws: a
  /// registration or a batch goes out without it rather than not at all.
  Future<Map<String, dynamic>?> read() async {
    try {
      final prefs = await _prefs();
      if (prefs.getBool(VpnEventReporter.sharePrefKey) == false) return null;
      final raw = await _channel
          .invokeMethod<Map<Object?, Object?>>('place')
          .timeout(timeout);
      if (raw == null) return null;
      final place = <String, dynamic>{
        for (final entry in raw.entries)
          if (keys.contains(entry.key) && _usable(entry.value))
            entry.key.toString(): entry.value,
      };
      return place.isEmpty ? null : place;
    } catch (_) {
      // No native side (tests, an old engine), a timeout, or a platform
      // error. None of them is worth failing the call this rides on.
      return null;
    }
  }

  /// The SIM card's country code, for the first-run language only.
  ///
  /// This stays on the phone and is never sent, so it does not follow the
  /// diagnostics switch that [read] honours: that switch is about what goes
  /// to the backend. Null when there is no SIM (Windows, most TVs), no
  /// native side, or the platform does not say.
  Future<String?> simCountry() async {
    try {
      final raw = await _channel
          .invokeMethod<Map<Object?, Object?>>('place')
          .timeout(timeout);
      final value = raw?['sim_country'];
      if (value is! String || value.trim().isEmpty) return null;
      return value.trim();
    } catch (_) {
      // Same as read: no native side, a timeout or a platform error. The
      // picker falls back to the phone's own settings.
      return null;
    }
  }

  static bool _usable(Object? value) =>
      value is bool || (value is String && value.trim().isNotEmpty);
}
