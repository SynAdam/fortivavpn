import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads the invite code Google Play carried through the install.
///
/// This is the only free install attribution left on either platform.
/// Firebase Dynamic Links shut down on 2025-08-25 and the alternatives
/// are paid measurement SDKs, which are not worth their data-sharing
/// disclosure in a VPN app.
///
/// It only works for installs that came from Google Play. A sideloaded
/// APK reports nothing, and sideloading is common among the users this
/// app is built for, so this is a convenience on top of typing the code
/// rather than a replacement for it. Every failure here is silent.
class InstallReferrer {
  InstallReferrer._();

  /// Set once the referrer has been read, whatever it contained. The Play
  /// API keeps answering for the life of the install, so without this the
  /// app would re-attempt a claim it has already made on every launch.
  static const String _prefRead = 'fortiva_install_referrer_read';

  /// The code Play carried, kept until a claim with it has an answer. A
  /// claim lost on the network is tried again on a later launch or
  /// connect, instead of being gone with the one read Play allows.
  static const String _prefPending = 'fortiva_install_referrer_pending';

  /// The parameter the invite link puts on the Play URL:
  /// `...&referrer=ref%3DABC123`.
  static const String _codeParam = 'ref';

  /// The invite code from the install referrer that still waits for a
  /// claim, or null.
  ///
  /// The first call reads Play and keeps the code it found. Later calls
  /// return the kept code until [settle] removes it. Returns null on every
  /// path that is not "Play handed us a code": iOS, a sideloaded install,
  /// no Play Services, a referrer without our parameter, or a code whose
  /// claim has had its answer.
  static Future<String?> pendingCode() async {
    if (!Platform.isAndroid) return null;

    final prefs = await _prefs();
    final kept = prefs?.getString(_prefPending);
    if (kept != null && kept.isNotEmpty) return kept;
    if (prefs?.getBool(_prefRead) ?? false) return null;

    String? raw;
    try {
      final details = await PlayInstallReferrer.installReferrer;
      raw = details.installReferrer;
    } catch (e) {
      // Thrown when Play Services is missing or the install did not come
      // from Play. Neither is a problem: the user can still type a code.
      debugPrint('InstallReferrer: unavailable ($e)');
    }

    final code = parseCode(raw);
    if (code != null) await prefs?.setString(_prefPending, code);
    // Marked as read even when nothing came back, so a device without Play
    // does not bind the service on every launch for an answer that cannot
    // change.
    await prefs?.setBool(_prefRead, true);
    return code;
  }

  /// The claim with the kept code had its answer (accepted or refused), so
  /// it is not tried again.
  static Future<void> settle() async {
    final prefs = await _prefs();
    await prefs?.remove(_prefPending);
  }

  /// Pull the invite code out of a raw install referrer string.
  ///
  /// Play hands back the query string it was given, so `ref=ABC123` and
  /// `utm_source=x&ref=ABC123` both have to work, as does the organic
  /// referrer Play sends when nobody set one.
  @visibleForTesting
  static String? parseCode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final params = Uri.splitQueryString(raw);
      final code = params[_codeParam]?.trim();
      if (code == null || code.isEmpty) return null;
      return code;
    } catch (_) {
      return null;
    }
  }

  /// Forget that the referrer was read, so the next launch tries again.
  ///
  /// Used by account deletion: the device comes back as a fresh install
  /// and should be able to accept the code it was invited with.
  static Future<void> reset() async {
    final prefs = await _prefs();
    await prefs?.remove(_prefRead);
    await prefs?.remove(_prefPending);
  }

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('InstallReferrer: preferences unavailable ($e)');
      return null;
    }
  }
}
