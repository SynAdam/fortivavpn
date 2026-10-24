/// Takes every line that names a site or an address out of the technical
/// log before a connection report carries it.
///
/// The native side already does this where it reads the log
/// (android/.../handler/LogPrivacy.kt). This runs the same rules again on
/// every report, so a line the native side lets through by mistake, or a log
/// from a platform without that filter, still never leaves the phone. Both
/// filters are tested against the sample lines in
/// test/fixtures/log_privacy_lines.txt.
///
/// A line is left out when its message has one of [destinationPhrases] or
/// holds a host name, an IPv4 address or an IPv6 address. Loopback
/// addresses and the app's own package name do not count. Lines about our
/// own servers are left out too, because a line cannot say which server it
/// is about. One line at the end says how many lines were left out.
class LogPrivacy {
  LogPrivacy._();

  /// Phrases of the lines that name a connection's destination or a DNS
  /// name. A line with one of these is left out even when its host has a
  /// form the address patterns do not catch. Lower case. The same list as
  /// the native side's.
  static const destinationPhrases = [
    // The core's own line for each connection's site name.
    'sniffed domain',
    'fake dns',
    'fake ip',
    // Routing: "taking detour [proxy] for [tcp:<host>:443]".
    'detour',
    'default route for',
    // The access log: "from tcp:127.0.0.1:5000 accepted tcp:<host>:443".
    'accepted',
    // Inbound and outbound requests and UDP packets.
    'request to',
    'redirecting request',
    'tunneling request',
    'send packet to',
    'writing back udp response',
    'udp connection from',
    'establishing new connection for',
    'replace destination',
    // Dials, which name our servers or, on the direct route, the site.
    'dialing',
    'downloading from',
    'creating connection to',
    'failed to dial',
    'connection opened to',
    'open connection to',
    // DNS.
    'app/dns',
    'proxy/dns',
    'got answer',
    'querying',
    'for domain',
    'domain replaced',
    'resolved to',
    'resolve ip for',
    'lookup',
    'ech config',
    // The app's lines that named another app before 1.6.21.
    'always-on vpn held by',
    'failed to configure app in vpn',
  ];

  /// The app's package name, which shows in its own file paths.
  static const _ownName = 'com.vpn.fortivavpn';

  /// `logcat -v time`: "10-07 09:16:12.345 I/GoLog   ( 4242): message".
  static final _logcatHeader = RegExp(
    r'^\d\d-\d\d \d\d:\d\d:\d\d\.\d+ [VDIWEFA]/[^(]*\(\s*\d+\): ?',
  );

  static const _label = r'[\p{L}\p{N}](?:[\p{L}\p{N}]|-+[\p{L}\p{N}])*';

  /// The last label starts with a letter and has two or more characters.
  static const _topLabel = r'\p{L}(?:[\p{L}\p{N}]|-+[\p{L}\p{N}])+';

  static final _hostName = RegExp('(?:$_label\\.)+$_topLabel', unicode: true);
  static final _ipv4 = RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b');

  /// Five groups or more, so a clock time such as 12:34:56 never matches.
  static final _ipv6Full = RegExp(
    r'(?:[0-9a-f]{1,4}:){4,7}[0-9a-f]{1,4}',
    caseSensitive: false,
  );
  static final _ipv6Short = RegExp(
    r'(?:[0-9a-f]{1,4}(?::[0-9a-f]{1,4}){0,6})?::'
    r'(?:[0-9a-f]{1,4}(?::[0-9a-f]{1,4}){0,6})?',
    caseSensitive: false,
  );

  /// Whether one log line names a site or an address.
  static bool namesDestination(String line) {
    final header = _logcatHeader.firstMatch(line);
    final message = header == null ? line : line.substring(header.end);
    final lower = message.toLowerCase();
    if (destinationPhrases.any(lower.contains)) return true;
    if (_hostName
        .allMatches(message)
        .any((m) => m[0]!.toLowerCase() != _ownName)) {
      return true;
    }
    if (_ipv4.allMatches(message).any((m) => !m[0]!.startsWith('127.'))) {
      return true;
    }
    if (_ipv6Full.hasMatch(message)) return true;
    return _ipv6Short.allMatches(message).any((m) => m[0] != '::1');
  }

  /// [log] without the lines that name a site or an address, and with one
  /// line at the end that says how many were left out. Returns [log]
  /// unchanged when no line was left out.
  static String scrub(String log) {
    var removed = 0;
    final kept = <String>[];
    for (final line in log.split('\n')) {
      if (namesDestination(line)) {
        removed++;
      } else {
        kept.add(line);
      }
    }
    if (removed == 0) return log;
    while (kept.isNotEmpty && kept.last.trim().isEmpty) {
      kept.removeLast();
    }
    kept.add(summary(removed));
    return kept.join('\n');
  }

  /// The line that replaces what was left out. It differs from the native
  /// side's summary, so a stored report shows which filter took a line out.
  static String summary(int removed) => removed == 1
      ? '[privacy] 1 line that names a site or an address was left out '
            'before sending.'
      : '[privacy] $removed lines that name a site or an address were left '
            'out before sending.';
}
