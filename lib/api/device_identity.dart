import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/tunnel_channels.dart';

/// Resolves the stable identifier the backend uses to provision VPN access
/// and meter quota.
///
/// This identifier is the *only* credential behind a device's VLESS
/// configs and its rolling 24h allowance, which pulls it in two directions:
///
///  * It must be unguessable, or anyone could enumerate other people's
///    configs. So it is never the raw hardware id — always a hash of it
///    with an app-specific salt.
///  * It should survive a reinstall. A purely random id stored in app
///    storage means clearing app data mints a brand new device with a
///    brand new free allowance, and strands the previous device's clients
///    on every panel.
///
/// Resolution order, first hit wins:
///   1. in-memory cache
///   2. secure storage (Keychain / EncryptedSharedPreferences)
///   3. the legacy SharedPreferences key, migrated forward
///   4. a value derived from the platform's install identifier
///   5. a random UUIDv4, if the platform gives us nothing usable
///
/// Step 3 is load-bearing: existing installs already have an id, and
/// changing it would reset their quota and orphan their panel clients.
class DeviceIdentity {
  DeviceIdentity._();

  static final DeviceIdentity instance = DeviceIdentity._();

  /// Key used before secure storage existed. Still read, never dropped.
  static const String legacyPrefsKey = 'fortivavpn_device_id';
  static const String _secureKey = 'fortivavpn_device_id_v2';

  /// Domain separation, so the value we send is not the raw SSAID/IDFV.
  /// Anyone who learns a device's hardware id still cannot derive its
  /// Fortiva identity without this.
  static const String _salt = 'fortiva-device-id-v1';

  /// Android used to be given `encryptedSharedPreferences: true`, which
  /// selected the Jetpack Security backend. Google deprecated that
  /// library, the plugin ignores the flag from v10 and rejects it in v11,
  /// and anything still on the old backend is migrated to the plugin's
  /// own ciphers the first time it is read. Passing it now would only
  /// stop the next upgrade compiling.
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  String? _cached;

  Future<String> resolve() async {
    if (_cached != null) return _cached!;

    final existing = await _readExisting();
    if (existing != null) {
      _cached = existing;
      return existing;
    }

    final derived = await _derive();
    await _persist(derived);
    _cached = derived;
    return derived;
  }

  /// The identity this install already has, or null when it has none
  /// yet. Never makes one: for the background check for messages, which
  /// must not register a phone the app itself has not.
  Future<String?> existing() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final stored = await _secure.read(key: _secureKey);
      if (stored != null && stored.isNotEmpty) return stored;
    } catch (e) {
      debugPrint('DeviceIdentity: secure storage unreadable ($e)');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(legacyPrefsKey);
      if (legacy != null && legacy.isNotEmpty) return legacy;
    } catch (e) {
      debugPrint('DeviceIdentity: preferences unreadable ($e)');
    }
    return null;
  }

  Future<String?> _readExisting() async {
    // Secure storage can throw on devices with a broken keystore; that is
    // a reason to fall back, not to fail the app's launch.
    try {
      final stored = await _secure.read(key: _secureKey);
      if (stored != null && stored.isNotEmpty) return stored;
    } catch (e) {
      debugPrint('DeviceIdentity: secure storage unreadable ($e)');
    }

    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(legacyPrefsKey);
    if (legacy != null && legacy.isNotEmpty) {
      // Migrate forward so the next launch takes the secure path, but keep
      // the value itself identical — it is already known to the backend.
      await _persist(legacy);
      return legacy;
    }
    return null;
  }

  Future<void> _persist(String id) async {
    try {
      await _secure.write(key: _secureKey, value: id);
    } catch (e) {
      debugPrint('DeviceIdentity: secure storage unwritable ($e)');
    }
    // Mirrored to plain prefs as a fallback for devices where secure
    // storage fails outright; losing both is what we are guarding against.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(legacyPrefsKey, id);
  }

  Future<String> _derive() async {
    final hardwareId = await _platformInstallId();
    if (hardwareId == null || hardwareId.isEmpty) return _randomUuidV4();
    return _uuidFromSeed('$_salt:$hardwareId');
  }

  /// The channel the Android identifier is read over.
  ///
  /// The tunnel channel rather than a new one, because it is already
  /// registered before anything asks for an identity.
  @visibleForTesting
  static final MethodChannel platformChannel = TunnelChannels.method;

  /// The most stable per-device identifier each platform will give us.
  ///
  /// Android answers with Settings.Secure.ANDROID_ID, which is scoped to
  /// this app's signing key and this device: it survives a reinstall and
  /// resets on a factory reset.
  ///
  /// It used to read `DeviceInfoPlugin().androidInfo.id`, which is not
  /// that. It is Build.ID, the ROM build label, so every phone running the
  /// same build derived the same identity and shared one device row, one
  /// VLESS client and one daily allowance. See #124.
  ///
  /// iOS identifierForVendor resets once every app from the vendor is
  /// removed, which is why the Keychain copy above matters more there.
  /// Everything that is not iOS asks the channel, rather than Android
  /// asking and everything else being written off. A platform with no
  /// handler answers MissingPluginException, which lands in the catch and
  /// mints a random id, so the desktop targets in this repo behave the
  /// same as before while the branch stays testable off-device.
  Future<String?> _platformInstallId() async {
    try {
      if (Platform.isIOS) {
        return (await DeviceInfoPlugin().iosInfo).identifierForVendor;
      }
      return await platformChannel.invokeMethod<String>('installId');
    } catch (e) {
      debugPrint('DeviceIdentity: platform id unavailable ($e)');
    }
    return null;
  }

  /// Format a SHA-256 digest as a v4-shaped UUID.
  ///
  /// The shape matters only for readability in logs and the admin panel;
  /// the entropy comes from the digest, not from the version bits.
  String _uuidFromSeed(String seed) {
    final digest = sha256.convert(utf8.encode(seed)).bytes;
    return _formatUuid(Uint8List.fromList(digest.sublist(0, 16)));
  }

  String _randomUuidV4() {
    final rng = Random.secure();
    final bytes = Uint8List(16);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return _formatUuid(bytes);
  }

  String _formatUuid(Uint8List bytes) {
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Forget this install's identity everywhere it is stored.
  ///
  /// Used by account deletion. The next [resolve] re-derives from the
  /// platform install id, so the app comes back as an unregistered device
  /// rather than one that silently keeps talking about a row the backend
  /// no longer has.
  Future<void> clear() async {
    _cached = null;
    try {
      await _secure.delete(key: _secureKey);
    } catch (e) {
      debugPrint('DeviceIdentity: secure storage not clearable ($e)');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(legacyPrefsKey);
  }

  @visibleForTesting
  void resetCacheForTest() => _cached = null;
}
