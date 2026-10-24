import 'dart:convert';

/// Helpers for reading the display parts out of a `vless://` URI.
///
/// The app never parses these links to connect - they are handed to the
/// tunnel as-is - but it does need a human label and a host to show in a
/// list, and it must do that without putting a live credential on screen.
///
/// trojan and ss links are read the same way, and a `vmess://` link
/// through [vmess], whose JSON holds what the others carry in the URI.
class VlessLink {
  const VlessLink._();

  /// The brand prefix the backend puts at the front of every label it issues.
  static const _brand = 'Fortiva';

  /// First code point of the regional indicator block, 'A'.
  static const _regionalIndicatorA = 0x1F1E6;

  /// The label the backend put in the URI fragment, e.g. "Fortiva FI
  /// Helsinki". Falls back to a positional name when absent.
  static String label(String uri, int index) =>
      labelOrNull(uri) ?? 'Server ${index + 1}';

  /// The label the fragment carries, or null when it carries none.
  ///
  /// A caller holding something better to fall back on than a positional
  /// name (the host, say) has to be able to tell the two cases apart,
  /// and [label] cannot express the difference.
  static String? labelOrNull(String uri) {
    final hash = uri.indexOf('#');
    if (hash == -1 || hash == uri.length - 1) return null;
    final raw = uri.substring(hash + 1);
    try {
      final decoded = Uri.decodeComponent(raw);
      return decoded.trim().isEmpty ? null : decoded;
    } catch (_) {
      // decodeComponent throws ArgumentError on a malformed escape (not
      // FormatException, as its name suggests). Either way a bad label
      // should degrade to the raw text, never blow up a list tile.
      return raw;
    }
  }

  /// The `host:port` the config points at, for a subtitle line.
  ///
  /// Deliberately excludes the UUID that precedes the '@': that is the
  /// credential, and rendering it would leak it to anyone glancing at the
  /// screen or a screenshot.
  static String host(String uri) {
    final json = vmess(uri);
    if (json != null) return _vmessHost(json);
    // An '@' in the label is a channel's name, not the credential's end.
    final hash = uri.indexOf('#');
    final body = hash == -1 ? uri : uri.substring(0, hash);
    final at = body.indexOf('@');
    if (at == -1) return '';
    final rest = body.substring(at + 1);
    var end = rest.length;
    for (final stop in const ['?', '/']) {
      final i = rest.indexOf(stop);
      if (i != -1 && i < end) end = i;
    }
    return rest.substring(0, end);
  }

  /// The settings a `vmess://` link carries as base64 JSON, or null when
  /// [uri] is not such a link or cannot be read.
  ///
  /// A vmess link has no '@' and no query: the address, the port and the
  /// transport are all inside the JSON (`add`, `port`, `net`, `tls`). Read
  /// as a vless link it had no host, so its events named no server and
  /// the backend counted them as our own, and every vmess link had the
  /// same path key, so the fallback kept only one of them. A vmess link
  /// written the vless way, with an '@', is read as a vless link.
  static Map<String, dynamic>? vmess(String uri) {
    if (!uri.startsWith(_vmessScheme)) return null;
    if (_vmessRead.containsKey(uri)) return _vmessRead[uri];
    final hash = uri.indexOf('#');
    final body = uri
        .substring(_vmessScheme.length, hash == -1 ? uri.length : hash)
        .replaceAll(RegExp(r'\s'), '');
    Map<String, dynamic>? out;
    if (body.isNotEmpty && !body.contains('@')) {
      try {
        // Channels post both base64 alphabets, with and without padding.
        final plain = body
            .replaceAll('-', '+')
            .replaceAll('_', '/')
            .replaceAll('=', '');
        final padded = plain.padRight((plain.length + 3) ~/ 4 * 4, '=');
        final decoded = jsonDecode(
          utf8.decode(base64.decode(padded), allowMalformed: true),
        );
        if (decoded is Map<String, dynamic>) out = decoded;
      } catch (_) {
        // Not base64 or not JSON: a link the app cannot read, like a
        // vless link without an '@'.
      }
    }
    if (_vmessRead.length >= _vmessKeep) _vmessRead.clear();
    _vmessRead[uri] = out;
    return out;
  }

  static const _vmessScheme = 'vmess://';

  /// The vmess links read so far. A list is read again and again while it
  /// is drawn and ordered, and each read decoded every link.
  static final _vmessRead = <String, Map<String, dynamic>?>{};
  static const _vmessKeep = 500;

  /// The name of the query parameter each vmess JSON field stands for, so
  /// [param], and with it [security], [transport] and [strategy], read a
  /// vmess link as they read the others.
  static const _vmessFields = {
    'type': 'net',
    'security': 'tls',
    'sni': 'sni',
    'fp': 'fp',
    'alpn': 'alpn',
    'host': 'host',
    'path': 'path',
    'headerType': 'type',
  };

  /// [host] of a vmess link: `add`, with `port` when it has one. An IPv6
  /// address gets its brackets, as it has in the other links.
  static String _vmessHost(Map<String, dynamic> json) {
    final add = '${json['add'] ?? ''}'.trim();
    if (add.isEmpty) return '';
    final address = add.contains(':') && !add.startsWith('[') ? '[$add]' : add;
    final port = int.tryParse('${json['port'] ?? ''}'.trim());
    return port == null ? address : '$address:$port';
  }

  /// The host alone: [host] without the `:port`. IPv6 literals keep their
  /// brackets stripped.
  static String hostname(String uri) {
    final hostPort = host(uri);
    if (hostPort.isEmpty) return '';
    if (hostPort.startsWith('[')) {
      final close = hostPort.indexOf(']');
      return close == -1 ? hostPort : hostPort.substring(1, close);
    }
    final colon = hostPort.lastIndexOf(':');
    return colon == -1 ? hostPort : hostPort.substring(0, colon);
  }

  /// The port, or 443 when the link carries none.
  static int port(String uri) {
    final hostPort = host(uri);
    final colon = hostPort.lastIndexOf(':');
    if (colon == -1 || hostPort.endsWith(']')) return 443;
    return int.tryParse(hostPort.substring(colon + 1)) ?? 443;
  }

  /// The `host:port` of the server a link reaches, which is not always the
  /// one it dials.
  ///
  /// A TLS link behind a CDN can be dialled at a CDN address and name its
  /// server only in the handshake. The backend dials every Cloudflare door
  /// at the same Cloudflare address, so two servers' Cloudflare doors have
  /// the same [host] and differ only in that name. A Reality link's name is
  /// borrowed from someone else's site and says nothing about the server,
  /// so it keeps [host], as does a link that dials the name it presents.
  static String endpoint(String uri) {
    final dialled = host(uri);
    if (security(uri) != 'tls') return dialled;
    final name = sni(uri) ?? param(uri, 'host');
    if (name == null || name == hostname(uri)) return dialled;
    return '$name:${port(uri)}';
  }

  /// The `sni` query parameter, which is the name the Reality handshake
  /// carries. Null when the link has none.
  static String? sni(String uri) => param(uri, 'sni');

  /// The `security` parameter, lower-cased: `reality`, `tls` or `none`.
  static String security(String uri) =>
      (param(uri, 'security') ?? 'none').toLowerCase();

  /// The transport (`type` parameter), lower-cased: `tcp`, `ws`, `grpc`...
  static String transport(String uri) =>
      (param(uri, 'type') ?? 'tcp').toLowerCase();

  /// Every knob inside the link that a censor could be reacting to.
  ///
  /// The door id says `ws-tls`. It does not say which SNI the handshake
  /// carried, which TLS fingerprint the core imitated, or what it
  /// negotiated for ALPN. Those are the settings an experiment varies, so
  /// an attempt that does not record them cannot be compared with another.
  ///
  /// Only our own dialling settings, never anything about the user or what
  /// they asked for. Keys absent from the link are absent here rather than
  /// null, so a row stays small and a missing key means "the link did not
  /// set it".
  static Map<String, dynamic> strategy(String uri) {
    final out = <String, dynamic>{
      'transport': transport(uri),
      'security': security(uri),
      'port': port(uri),
    };
    for (final name in const [
      'sni',
      'fp',
      'alpn',
      'flow',
      'headerType',
      'mode',
      'path',
      'serviceName',
      'host',
      'fragment',
      'extra',
      'ech',
      'fm',
      'cs',
    ]) {
      final v = param(uri, name);
      if (v != null) out[name] = v;
    }
    // The Reality public key identifies which key pair the server is
    // serving, which changes when we rotate one. The key itself is not a
    // secret (every client link carries it), but only its first bytes are
    // needed to tell one rotation from another.
    final pbk = param(uri, 'pbk');
    if (pbk != null) {
      out['pbk_prefix'] = pbk.length > 8 ? pbk.substring(0, 8) : pbk;
    }
    return out;
  }

  /// One query parameter, decoded. Null when the link has none by that
  /// name, or an empty one. For a vmess link, the JSON field that stands
  /// for it.
  static String? param(String uri, String name) {
    final json = vmess(uri);
    if (json != null) {
      final field = _vmessFields[name];
      final v = field == null ? '' : '${json[field] ?? ''}'.trim();
      return v.isEmpty ? null : v;
    }
    final q = uri.indexOf('?');
    if (q == -1) return null;
    var query = uri.substring(q + 1);
    final frag = query.indexOf('#');
    if (frag != -1) query = query.substring(0, frag);
    for (final pair in query.split('&')) {
      final eq = pair.indexOf('=');
      if (eq == -1) continue;
      if (pair.substring(0, eq) == name) {
        final raw = pair.substring(eq + 1);
        String v;
        try {
          v = Uri.decodeComponent(raw);
        } on ArgumentError {
          // Non-ASCII in a scraped link; the raw text beats an exception.
          v = raw;
        }
        return v.isEmpty ? null : v;
      }
    }
    return null;
  }

  /// Split a backend label into its region code and the place name.
  ///
  /// The backend builds the fragment as `Fortiva {flag} {city}`, and the
  /// column behind `{flag}` is two characters wide. Live data holds either
  /// a regional indicator pair ("🇫🇮") or the bare country code ("FI"),
  /// so both are read here and normalised to an upper-case code.
  ///
  /// A label that carries no region at all yields an empty [region] and
  /// the whole remainder as [place], because a name is always more useful
  /// on screen than a blank tile.
  static ({String region, String place}) parts(String label) {
    var rest = label.trim();
    if (rest.length >= _brand.length &&
        rest.substring(0, _brand.length).toLowerCase() ==
            _brand.toLowerCase()) {
      rest = rest.substring(_brand.length).trimLeft();
    }

    final runes = rest.runes.toList();
    if (runes.length >= 2 &&
        _isRegionalIndicator(runes[0]) &&
        _isRegionalIndicator(runes[1])) {
      final code = String.fromCharCodes([
        runes[0] - _regionalIndicatorA + 0x41,
        runes[1] - _regionalIndicatorA + 0x41,
      ]);
      return (
        region: code,
        place: String.fromCharCodes(runes.skip(2)).trimLeft(),
      );
    }

    // A bare code, e.g. "FI Helsinki". Upper case is required so that a
    // place whose name simply starts with a two-letter word ("Ho Chi Minh
    // City") is not read as a country.
    final bare = RegExp(r'^([A-Z]{2})(\s|$)').firstMatch(rest);
    if (bare != null) {
      return (region: bare.group(1)!, place: rest.substring(2).trimLeft());
    }

    return (region: '', place: rest);
  }

  static bool _isRegionalIndicator(int rune) =>
      rune >= _regionalIndicatorA && rune <= _regionalIndicatorA + 25;
}
