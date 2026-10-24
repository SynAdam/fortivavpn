import 'dart:io';

import 'package:flutter/foundation.dart';

/// Which links from the public list, or from the backend's candidates, the
/// app can dial and test.
///
/// The core reads vless, vmess, trojan and ss. A hysteria2 (hy2) link
/// cannot carry traffic, because the build does not ship the program that
/// runs it, and wireguard and the rest are not read for a delay test. A
/// TLS link that sets allowInsecure makes the core refuse the whole
/// config, so the tunnel never starts and the user is told to try another
/// location. None of these is listed, tested or dialled.
class SharedLink {
  const SharedLink._();

  /// Every scheme the phone cores dial and test.
  static const _allSchemes = {'vless', 'vmess', 'trojan', 'ss'};

  /// Stands in for the platform check in tests, which run on a desktop.
  @visibleForTesting
  static bool? windowsOverride;

  /// The schemes the core can dial and the delay test can read. The
  /// Windows core reads vless links only (windows/core/internal/link), so
  /// there a link of another kind would fail every test and every dial.
  static Set<String> get usableSchemes =>
      (windowsOverride ?? Platform.isWindows) ? const {'vless'} : _allSchemes;

  /// The scheme of [uri], lower-cased, or empty when it has none.
  static String scheme(String uri) {
    final colon = uri.indexOf('://');
    if (colon <= 0) return '';
    return uri.substring(0, colon).trim().toLowerCase();
  }

  /// Whether [uri] can be dialled and tested: a usable scheme, and no
  /// allowInsecure.
  static bool usable(String uri) =>
      usableSchemes.contains(scheme(uri)) && !insecure(uri);

  /// Whether the query of [uri] sets allowInsecure to 1 or true. The name
  /// and the value are read in any case, and an HTML-encoded `&amp;`
  /// separates parameters as `&` does, because the core is given the link
  /// with those cleaned up.
  static bool insecure(String uri) {
    final q = uri.indexOf('?');
    if (q == -1) return false;
    final hash = uri.indexOf('#', q);
    final query = uri
        .substring(q + 1, hash == -1 ? uri.length : hash)
        .replaceAll('&amp;', '&');
    for (final pair in query.split('&')) {
      final eq = pair.indexOf('=');
      if (eq == -1) continue;
      if (pair.substring(0, eq).trim().toLowerCase() != 'allowinsecure') {
        continue;
      }
      final value = pair.substring(eq + 1).trim().toLowerCase();
      if (value == '1' || value == 'true') return true;
    }
    return false;
  }
}
