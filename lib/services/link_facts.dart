import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'tunnel_channels.dart';

/// What Android says about the network this app's own sockets use, for the
/// door checks: `link_mtu`, `private_dns` and `transport`.
///
/// A failed check says "tcp ok; no answer in 3000 ms" and cannot say why.
/// Two of the causes we suspect for TCI home lines are a path that drops
/// large packets and a Private DNS setting that changes what the phone
/// resolves. The MTU the phone's link reports and the Private DNS mode are
/// read with each batch of door checks, so a check can be read against
/// them. The app is left out of its own tunnel, so this is the line under
/// the tunnel even while a user is connected.
///
/// System reads only: nothing is sent to read them. Android only; the
/// other platforms send none of the three, as older apps do.
class LinkFacts {
  LinkFacts({MethodChannel? channel, bool? android})
    : _channel = channel ?? TunnelChannels.method,
      _android = android ?? Platform.isAndroid;

  static const timeout = Duration(seconds: 1);

  static const _privateDnsModes = {'off', 'opportunistic', 'strict'};
  static const _transports = {'wifi', 'cellular', 'ethernet', 'other'};

  final MethodChannel _channel;
  final bool _android;

  /// The facts the platform gave, under the names a door-check row uses.
  /// A fact the platform did not give, or gave in a shape the backend
  /// would not accept, is left out. Never throws.
  Future<Map<String, Object>> read() async {
    if (!_android) return const {};
    try {
      final raw = await _channel
          .invokeMethod<Map<Object?, Object?>>('linkFacts')
          .timeout(timeout);
      if (raw == null) return const {};
      final mtu = raw['link_mtu'];
      final dns = raw['private_dns'];
      final transport = raw['transport'];
      return {
        if (mtu is int && mtu > 0) 'link_mtu': mtu,
        if (dns is String && _privateDnsModes.contains(dns)) 'private_dns': dns,
        if (transport is String && _transports.contains(transport))
          'transport': transport,
      };
    } catch (_) {
      // No native side (an older engine), a timeout, or a platform error.
      // The door checks go out without these rather than not at all.
      return const {};
    }
  }
}
