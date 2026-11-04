import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vpn_service.dart';

/// What the app's engine saved about the running tunnel, read by the
/// engines that run with no screen (the keeper and the message check),
/// which have no VpnService of their own.
abstract final class SavedTunnel {
  /// Whether the tunnel goes through a community server, as the app last
  /// saved it (VpnService.attemptKey): true when its doors held a community
  /// link or it was dialled through one, false for one of ours or the
  /// backup network, null when nothing was saved or it cannot be read.
  /// Never throws.
  ///
  /// It reads what the app saved, not the core, so a move the core made
  /// while the app was away is not seen. A tunnel whose doors held a
  /// community link counts as community whichever door carries it.
  static Future<bool?> onCommunity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return fromSaved(prefs.getString(VpnService.attemptKey));
    } catch (e) {
      debugPrint('SavedTunnel: could not read the saved attempt ($e)');
      return null;
    }
  }

  /// [onCommunity] for the JSON the app saved.
  @visibleForTesting
  static bool? fromSaved(String? saved) {
    if (saved == null) return null;
    try {
      final facts = jsonDecode(saved);
      if (facts is! Map) return null;
      if (facts['community_held'] == true) return true;
      final strategy = facts['strategy'];
      if (strategy is! Map) return null;
      return VpnService.communitySource(strategy['src']);
    } catch (_) {
      return null;
    }
  }
}
