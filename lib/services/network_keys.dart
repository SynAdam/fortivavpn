import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/connection_data.dart';
import 'tunnel_channels.dart';

/// The two keys of the Wi-Fi network the phone is on (backend issue #365,
/// items 3, 4 and 9). Made on the phone from the network's link properties
/// and hashed under this install's salt (NetworkKey on Android); nothing
/// they are made from leaves the phone.
@immutable
class WifiKeys {
  const WifiKeys({required this.local, this.shared});

  /// For the phone's own memory. The same for as long as the salt is kept.
  final String local;

  /// To send to the backend. Changes every period the backend sets, and is
  /// null when it sets none. What the phone remembers of the network for
  /// the backend is kept under it (NetworkHistory), so nothing sent with
  /// one period's key comes from the period before.
  final String? shared;
}

/// Reads [WifiKeys] for the network the phone is on.
///
/// Only while the backend's connection data settings turn network keys on;
/// otherwise every Wi-Fi network is the one network "wifi", as it always
/// was. The salt is 32 random bytes made on first use and kept in
/// [saltKey]; it goes with the account when the account is deleted, and
/// then every key changes.
class NetworkKeys {
  NetworkKeys._();

  /// Where this install's salt is kept.
  static const saltKey = 'fortiva_network_salt';

  /// The salt, once read. Every reading asks the platform afresh: it is a
  /// few system reads and two hashes, and a reading kept for even a few
  /// seconds would name the network the phone just left.
  static String? _saltValue;

  @visibleForTesting
  static MethodChannel channel = TunnelChannels.method;

  /// Moved on by [forget]. A reading begun before that is dropped.
  static int _generation = 0;

  /// The current generation: work that keeps something about a network
  /// checks it has not moved on since it began (NetworkHistory).
  static int get generation => _generation;

  static bool _closed = false;

  /// Whether an account deletion is removing what the phone knows of its
  /// networks ([close] to [reopen]). Nothing is handed out or kept then.
  static bool get closed => _closed;

  /// Whether an account deletion ran in this run of the app.
  static bool _deletedInThisRun = false;

  /// The local keys handed out since the last [forget].
  static final _issued = <String>{};

  /// Whether something may be stored now about [network], a memory key
  /// (`wifi:<key>`, `mobile:<carrier>`, ...). Every store kept by network
  /// asks right before it writes. Never while a deletion runs. After one
  /// in this run, a Wi-Fi key only when it was read since: a key read
  /// before was made with the salt the deletion removed, and work that
  /// held it across the deletion (a sweep, a connect) would put that
  /// network back.
  static bool mayKeep(String network) {
    if (_closed) return false;
    if (!_deletedInThisRun || !network.startsWith('wifi:')) return true;
    return _issued.contains(network.substring(5));
  }

  /// Forget the salt read into memory (tests, and account deletion, which
  /// removes it from storage). A reading under way when this runs gives
  /// null, so no key made with the old salt is handed out after it.
  static void forget() {
    _saltValue = null;
    _generation++;
    _issued.clear();
  }

  /// No key is read, made or handed out until [reopen]: account deletion
  /// removes the salt one store at a time, and a reading in between would
  /// load the old salt again.
  static void close() {
    _closed = true;
    _deletedInThisRun = true;
    forget();
  }

  /// After the deletion: the next reading makes a new salt.
  static void reopen() {
    forget();
    _closed = false;
  }

  @visibleForTesting
  static void resetForTest() {
    forget();
    _closed = false;
    _deletedInThisRun = false;
  }

  /// The keys of the Wi-Fi network the phone is on, or null: network keys
  /// are off, the phone is not on Wi-Fi, the platform cannot read them, or
  /// the network gives nothing to tell it by.
  static Future<WifiKeys?> read() async {
    final settings = ConnectionData.current;
    if (!settings.networkKeys || _closed) return null;
    final period = settings.networkKeyPeriod;
    final generation = _generation;
    WifiKeys? keys;
    try {
      final salt = await _salt();
      final result = await channel.invokeMethod<dynamic>('networkKey', {
        'salt': salt,
        'periodSeconds': period?.inSeconds ?? 0,
      });
      if (result is Map) {
        final local = result['local'];
        final shared = result['shared'];
        if (local is String && _hex.hasMatch(local)) {
          keys = WifiKeys(
            local: local,
            shared: shared is String && _hex.hasMatch(shared) ? shared : null,
          );
        }
      }
    } on MissingPluginException {
      keys = null;
    } catch (e) {
      debugPrint('NetworkKeys: could not read the network key ($e)');
      keys = null;
    }
    if (generation != _generation || _closed) return null;
    if (keys != null) _issued.add(keys.local);
    return keys;
  }

  /// The memory key for a Wi-Fi network: "wifi:" and its local key, or
  /// "wifi" when it has none.
  static Future<String> wifiMemoryKey() async {
    final keys = await read();
    return keys == null ? 'wifi' : 'wifi:${keys.local}';
  }

  /// The keys of [network], a memory key from [wifiMemoryKey], when it is
  /// the network the phone is on now and it has a key to send. Null for
  /// anything else: a key is sent only for the network it was read on.
  static Future<WifiKeys?> sharedFor(String? network) async {
    if (network == null || !network.startsWith('wifi:')) return null;
    final keys = await read();
    if (keys == null || keys.shared == null) return null;
    if ('wifi:${keys.local}' != network) return null;
    return keys;
  }

  static final _hex = RegExp(r'^[0-9a-f]{16}$');

  static Future<String> _salt() async {
    if (_saltValue != null) return _saltValue!;
    // A salt read before a [forget] is not kept in memory after it.
    final generation = _generation;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(saltKey);
    if (saved != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(saved)) {
      if (generation == _generation) _saltValue = saved;
      return saved;
    }
    final random = Random.secure();
    final salt = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await prefs.setString(saltKey, salt);
    if (generation == _generation) _saltValue = salt;
    return salt;
  }
}
