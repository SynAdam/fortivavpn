import 'dart:io';

import 'vless_link.dart';

/// Asks the core to send the TLS hello in small, spaced-out TCP segments.
///
/// A filter can reset the TLS handshake on our CDN links by the server
/// name. Split into segments, the name is not whole in any one packet.
///
/// The backend sets it in its remote config with a spec such as
/// `tlshello,10-20,10-20`: which packets, the segment sizes in bytes and
/// the gaps in ms. An empty spec turns it off. The app adds it to a TLS
/// link as a `fragment` parameter, which the Android core reads for the
/// connection and the probes alike, and which the event reports carry in
/// their strategy.
class TlsFragment {
  TlsFragment._();

  /// What the app splits with until the backend has answered.
  ///
  /// The same value the backend serves. A launch that cannot reach the
  /// backend is the one that needs the split most: a phone whose config
  /// request never arrived would dial the CDN link with a whole hello, and
  /// the filter resets that.
  static const builtIn = 'tlshello,10-20,1-2';

  /// The spec in force, or empty for off: the backend's last answer, kept
  /// across launches by AppConfigState, and [builtIn] before it has ever
  /// answered.
  static String spec = builtIn;

  /// The split this phone's own TLS doors dial with, when the backend wrote
  /// one into their links, or null. DedicatedState sets it each time it
  /// takes in the doors.
  ///
  /// The backend's door experiments write a split such as
  /// `tlshello,200-400,1-2` into the TLS door links of the phones in a
  /// test arm, and a promoted split into those of every phone on the
  /// carrier (door_experiments.apply). Door tests send this split, when
  /// there is one, as the splitter every test core carries, so the checks
  /// of this phone's doors dial the way its tunnel does. See
  /// PingService._testArgs.
  static String? doorSpec;

  static final _valid = RegExp(
    r'^tlshello,\d{1,4}(-\d{1,4})?,\d{1,4}(-\d{1,4})?$',
  );

  /// Whether the core can split with [spec]: the `tlshello,<lengths>,<gaps>`
  /// form, with no length of 0.
  ///
  /// The core refuses a length range that reaches 0 ("LengthMin can't be
  /// 0" in infra/conf/freedom.go, after it puts the two ends in order).
  /// Every door test core carries the app's splitter, so a refused one
  /// fails the whole test, Reality doors and shared links included. On
  /// 2026-10-12, with the pinned core, a Reality test passed without a
  /// splitter and failed at config load with `tlshello,0-20,1-2` or
  /// `tlshello,0,0`. Both ends are checked because `20-0` and `0000` fail
  /// the same way. The backend does not check the value it serves.
  static bool usable(String spec) {
    final s = spec.trim();
    if (!_valid.hasMatch(s)) return false;
    return !s.split(',')[1].split('-').any((n) => int.parse(n) == 0);
  }

  /// [uri] with the fragment parameter added, or unchanged.
  ///
  /// Only on Android and Windows, whose cores read the parameter (Windows
  /// splits the hello inside the door's own connection, windows/core/README.md).
  /// Only for TLS: a
  /// Reality handshake is a borrowed site's and works as it is. A link that
  /// already names a fragment keeps its own.
  static String apply(String uri, {String? spec, bool? android}) {
    final wanted = (spec ?? TlsFragment.spec).trim();
    if (!(android ?? (Platform.isAndroid || Platform.isWindows))) return uri;
    if (!usable(wanted)) return uri;
    if (!uri.startsWith('vless://') || VlessLink.security(uri) != 'tls') {
      return uri;
    }
    if (VlessLink.param(uri, 'fragment') != null) return uri;
    // An Encrypted Client Hello is never split: the outer name it carries
    // is a public one, and splitting would only make the hello look odd.
    if (VlessLink.param(uri, 'ech') != null) return uri;
    // A finalmask already cuts the hello its own way; splitting it as well
    // would act on the same bytes twice.
    if (VlessLink.param(uri, 'fm') != null) return uri;

    final hash = uri.indexOf('#');
    final body = hash == -1 ? uri : uri.substring(0, hash);
    final remark = hash == -1 ? '' : uri.substring(hash);
    final joiner = body.contains('?') ? '&' : '?';
    // Raw: the pattern above allows only letters, digits, commas and
    // dashes, all safe in a query, and the core does not decode a %2C.
    return '$body${joiner}fragment=$wanted$remark';
  }

  /// [uri] with its fragment parameter set to [spec], replacing any it had.
  ///
  /// A link that names a fragment keeps it, so this is how a test point
  /// checks a door with a split other than the app's. An unparsable value
  /// such as `off` makes the core send the hello whole.
  static String withSpec(String uri, String spec) {
    if (spec == echSpec) {
      return _withParams(uri, {'ech': echConfig, 'fragment': 'off'});
    }
    if (spec == ffSpec) {
      return _withParams(uri, {
        'fm': ffMask,
        'cs': ffCipherSuites,
        'fp': 'unsafe',
        'fragment': 'off',
      });
    }
    return _withParams(uri, {'fragment': spec});
  }

  /// The spec a test point uses for the channels' "F&F", which a public
  /// config channel reported as getting through to Cloudflare: the core
  /// cuts the hello into TLS records itself ([ffMask]) and dials with
  /// Go's own TLS (fingerprint `unsafe`) offering [ffCipherSuites].
  static const ffSpec = 'ff';

  /// The finalmask, percent-encoded: an empty TLS record, one of 104 bytes,
  /// then single bytes, all in one write; then the first write after the
  /// hello cut into up to 11 pieces. Taken from the published configs of
  /// the channel that reported it (patterniha/Free-Configs).
  static final ffMask = Uri.encodeComponent(
    '{"tcp":[{"type":"fragment","settings":{"packets":"tlshello",'
    '"lengths":["0","104","1"],"delays":["0"],"maxSplit":"0"}},'
    '{"type":"fragment","settings":{"packets":"1-1",'
    '"lengths":["114","1"],"delays":["1"],"maxSplit":"11"}}]}',
  );

  /// Go cipher suite names in Python's order, as the same configs publish
  /// them, percent-encoded. The core drops a name it does not know.
  static final ffCipherSuites = Uri.encodeComponent(
    [
      'TLS_AES_256_GCM_SHA384',
      'TLS_CHACHA20_POLY1305_SHA256',
      'TLS_AES_128_GCM_SHA256',
      'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384',
      'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384',
      'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256',
      'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256',
      'TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256',
      'TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256',
      'TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA',
      'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA',
      'TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256',
      'TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256',
    ].join(':'),
  );

  /// The spec a test point uses for Encrypted Client Hello: the core looks
  /// up Cloudflare's ECH config over UDP DNS at 1.1.1.1 and sends the hello
  /// whole, with our name inside it.
  static const echSpec = 'ech';

  /// `cloudflare-ech.com+udp://1.1.1.1`, percent-encoded: the Android link
  /// parser decodes query values, and a raw `+` would become a space.
  static const echConfig = 'cloudflare-ech.com%2Budp%3A%2F%2F1.1.1.1';

  static String _withParams(String uri, Map<String, String> set) {
    final hash = uri.indexOf('#');
    final body = hash == -1 ? uri : uri.substring(0, hash);
    final remark = hash == -1 ? '' : uri.substring(hash);
    final added = [for (final e in set.entries) '${e.key}=${e.value}'];
    final query = body.indexOf('?');
    if (query == -1) return '$body?${added.join('&')}$remark';
    final kept = body
        .substring(query + 1)
        .split('&')
        .where((p) => p.isNotEmpty && !set.keys.any((k) => p.startsWith('$k=')))
        .toList();
    return '${body.substring(0, query)}?${[...kept, ...added].join('&')}$remark';
  }
}
