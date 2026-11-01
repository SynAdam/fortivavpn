import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads what Google Play carried through the install: the invite code,
/// and the campaign the install came from.
///
/// This is the only free install attribution left on either platform.
/// Firebase Dynamic Links shut down on 2025-08-25 and the alternatives
/// are paid measurement SDKs, which are not worth their data-sharing
/// disclosure in a VPN app.
///
/// It only works for installs that came from Google Play. A sideloaded
/// APK gets nothing useful: Play answers a copy it did not install with its
/// default referrer, which carries no code, and the install source is kept
/// only for a copy Play installed (see [_installedByPlay]). Sideloading is
/// common among the users this app is built for, so this is a convenience on
/// top of typing the code rather than a replacement for it. Every failure
/// here is silent.
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

  /// Set once the install source has been read, whatever it contained.
  ///
  /// A flag of its own rather than [_prefRead], because phones that
  /// installed a build from before the source was kept have set
  /// [_prefRead] already. They still read the source once after the
  /// update, while Play keeps the referrer (about 90 days from the
  /// install), and their invite code is not claimed a second time.
  static const String _prefSourceRead = 'fortiva_install_source_read';

  /// The source Play carried, as JSON, kept until a registration that
  /// carried it succeeds. A registration lost on the network sends it
  /// again with the next one.
  static const String _prefSource = 'fortiva_install_source';

  /// The parameter the invite link puts on the Play URL:
  /// `...&referrer=ref%3DABC123`.
  static const String _codeParam = 'ref';

  /// The campaign parameters kept as the install source. Play sends
  /// `utm_source=google-play&utm_medium=organic` for an install nobody
  /// linked to, and our Telegram posts link with `utm_source` alone.
  static const List<String> sourceParams = [
    'utm_source',
    'utm_medium',
    'utm_campaign',
  ];

  /// The most UTF-16 code units kept of each source value, so a long
  /// referrer cannot grow the register body or the backend's columns.
  @visibleForTesting
  static const int maxSourceLength = 64;

  /// Stands in for the platform check in tests, which run on a desktop.
  @visibleForTesting
  static bool? androidOverride;

  /// Stands in for Play's answer in tests.
  @visibleForTesting
  static Future<String?> Function()? readOverride;

  /// Stands in for [_installedByPlay] and [_hasInstallTime] in tests: whether
  /// Google Play installed this copy.
  @visibleForTesting
  static Future<bool> Function()? fromPlayOverride;

  /// The installer of a copy from Google Play, as in ReviewPrompt.
  static const String _playInstaller = 'com.android.vending';

  /// Play's answer in this run of the app, shared by the invite code and
  /// the install source: the referrer, and when Play says the install began
  /// (0 when it has no such install). Binding the Play service is the slow
  /// part and the answer does not change for the install, so Play is asked
  /// at most once per run, however many callers ask at the same time.
  static Future<({String? referrer, int installBegin})>? _raw;

  static bool get _android => androidOverride ?? Platform.isAndroid;

  /// Forget this run's answer from Play, as a new launch would.
  @visibleForTesting
  static void newRunForTest() => _raw = null;

  /// The invite code from the install referrer that still waits for a
  /// claim, or null.
  ///
  /// The first call reads Play and keeps the code it found. Later calls
  /// return the kept code until [settle] removes it. Returns null on every
  /// path that is not "Play handed us a code": iOS, a sideloaded install,
  /// no Play Services, a referrer without our parameter, or a code whose
  /// claim has had its answer.
  static Future<String?> pendingCode() async {
    if (!_android) return null;

    final prefs = await _prefs();
    final kept = prefs?.getString(_prefPending);
    if (kept != null && kept.isNotEmpty) return kept;
    if (prefs?.getBool(_prefRead) ?? false) return null;

    final code = parseCode(await _referrer());
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

  /// The install source that still waits to go with a registration, or
  /// null: `utm_source`, `utm_medium` and `utm_campaign`, each only when
  /// Play carried it.
  ///
  /// The first call reads Play and keeps the source it found. Later calls
  /// return the kept source until [sourceSent] removes it. Returns null off
  /// Android, for a copy Play did not install (see [_installedByPlay]) or
  /// one without Play Services, for a referrer without these parameters, and
  /// once the source was sent.
  static Future<Map<String, String>?> pendingSource() async {
    if (!_android) return null;

    final prefs = await _prefs();
    final kept = _keptSource(prefs?.getString(_prefSource));
    if (kept != null) return kept;
    if (prefs?.getBool(_prefSourceRead) ?? false) return null;

    // The installer first: a copy Play did not install has no source whatever
    // Play answers, so register does not wait for the answer.
    final answer = await _installedByPlay() ? await _answer() : null;
    final source = answer != null && _hasInstallTime(answer.installBegin)
        ? parseSource(answer.referrer)
        : null;
    if (source != null) {
      await prefs?.setString(_prefSource, jsonEncode(source));
    }
    // Marked as read even when nothing came back, as for the code.
    await prefs?.setBool(_prefSourceRead, true);
    return source;
  }

  /// A registration that carried the kept source succeeded, so it is not
  /// sent again.
  static Future<void> sourceSent() async {
    final prefs = await _prefs();
    await prefs?.remove(_prefSource);
  }

  /// Play's answer, asked once per run (see [_raw]).
  static Future<({String? referrer, int installBegin})> _answer() =>
      _raw ??= _readPlay();

  /// The referrer of Play's answer. Null when Play has none to give.
  static Future<String?> _referrer() async => (await _answer()).referrer;

  static Future<({String? referrer, int installBegin})> _readPlay() async {
    try {
      final read = readOverride;
      if (read != null) return (referrer: await read(), installBegin: 0);
      final details = await PlayInstallReferrer.installReferrer;
      return (
        referrer: details.installReferrer,
        installBegin: details.installBeginTimestampSeconds,
      );
    } catch (e) {
      // Thrown when Play Services is missing or the install did not come
      // from Play. Neither is a problem: the user can still type a code.
      debugPrint('InstallReferrer: unavailable ($e)');
      return (referrer: null, installBegin: 0);
    }
  }

  /// Whether the installer of this copy is the Play Store. Never throws: an
  /// installer that cannot be read is not Play.
  ///
  /// Play also answers a copy it did not install, such as the APK from the
  /// website or the channel on a phone that has the Play Store: with its
  /// default `utm_source=google-play&utm_medium=organic` and an install
  /// time of 0. Kept, that would count every such APK as a Play install.
  /// So both must hold: the installer is the Play Store, and Play has a time
  /// the install began ([_hasInstallTime]).
  static Future<bool> _installedByPlay() async {
    final override = fromPlayOverride;
    if (override != null) return override();
    try {
      return (await PackageInfo.fromPlatform()).installerStore ==
          _playInstaller;
    } catch (e) {
      debugPrint('InstallReferrer: installer unknown ($e)');
      return false;
    }
  }

  /// Whether Play has a time the install began. See [_installedByPlay].
  static bool _hasInstallTime(int installBegin) =>
      fromPlayOverride != null || installBegin > 0;

  /// The source [json] holds, or null when it holds none. A value that is
  /// not the shape [pendingSource] writes counts as none.
  static Map<String, String>? _keptSource(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) return null;
      final source = <String, String>{
        for (final name in sourceParams)
          if (decoded[name] case final String value when value.isNotEmpty)
            name: value,
      };
      return source.isEmpty ? null : source;
    } catch (_) {
      return null;
    }
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

  /// Pull the install source ([sourceParams]) out of a raw install
  /// referrer string, or null when it carries none of them.
  ///
  /// Each pair is decoded on its own, so a pair that is not valid percent
  /// encoding loses only itself, not the source next to it. Values keep
  /// what Play gave apart from [cleanSourceValue], so Play's `(not set)`
  /// stays `(not set)`. When a parameter comes twice, the first usable
  /// value counts.
  @visibleForTesting
  static Map<String, String>? parseSource(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final source = <String, String>{};
    for (final pair in raw.split('&')) {
      final at = pair.indexOf('=');
      if (at <= 0) continue;
      try {
        final name = Uri.decodeQueryComponent(pair.substring(0, at));
        if (!sourceParams.contains(name) || source.containsKey(name)) {
          continue;
        }
        final value = cleanSourceValue(
          Uri.decodeQueryComponent(pair.substring(at + 1)),
        );
        if (value != null) source[name] = value;
      } catch (_) {
        // Not valid percent encoding. The other pairs still count.
      }
    }
    return source.isEmpty ? null : source;
  }

  static final _control = RegExp(r'[\x00-\x1f\x7f]');

  /// [value] without control characters or the spaces around it, and at
  /// most [maxSourceLength] long, or null when nothing is left.
  @visibleForTesting
  static String? cleanSourceValue(String value) {
    // Control characters are removed before the trim, so spaces next to
    // them at either end are trimmed too.
    var clean = value.replaceAll(_control, '').trim();
    if (clean.length > maxSourceLength) {
      var end = maxSourceLength;
      // A cut after the first half of a surrogate pair would leave half a
      // character, which is not valid text.
      final last = clean.codeUnitAt(end - 1);
      if (last >= 0xD800 && last <= 0xDBFF) end--;
      clean = clean.substring(0, end);
    }
    return clean.isEmpty ? null : clean;
  }

  /// Forget that the referrer was read, so the next launch tries again.
  ///
  /// Account deletion clears the same keys (AccountService.accountPrefKeys):
  /// the device comes back as a fresh install and should be able to accept
  /// the code it was invited with, and send its install source with the
  /// new device row.
  static Future<void> reset() async {
    final prefs = await _prefs();
    await prefs?.remove(_prefRead);
    await prefs?.remove(_prefPending);
    await prefs?.remove(_prefSourceRead);
    await prefs?.remove(_prefSource);
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
