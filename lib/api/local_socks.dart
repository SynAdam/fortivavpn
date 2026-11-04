/// Where the running tunnel's local SOCKS5 proxy listens, and the
/// credentials it asks for.
///
/// On Android the core's SOCKS port asks for a user name and password that
/// are made new for every start of the tunnel, so other apps on the phone
/// cannot send traffic through it. This app reads them from the platform
/// with the port, and sends them in the SOCKS5 handshake (RFC 1929).
class LocalSocks {
  const LocalSocks({required this.port, this.user, this.pass});

  /// A proxy that asks for no credentials, as the core's port did before
  /// it had them, and as test proxies do.
  const LocalSocks.noAuth(this.port) : user = null, pass = null;

  final int port;
  final String? user;
  final String? pass;

  /// Whether the handshake offers the credentials.
  bool get hasAuth =>
      user != null && pass != null && user!.isNotEmpty && pass!.isNotEmpty;

  /// What the platform answered: a map with `port`, `user` and `pass`, or
  /// a bare port from an older build of the native side. Null for no
  /// tunnel, or for anything else.
  static LocalSocks? fromChannel(Object? raw) {
    if (raw is int) return raw > 0 ? LocalSocks.noAuth(raw) : null;
    if (raw is! Map) return null;
    final port = raw['port'];
    if (port is! int || port <= 0 || port > 65535) return null;
    final user = raw['user'];
    final pass = raw['pass'];
    if (user is String && pass is String && user.isNotEmpty) {
      return LocalSocks(port: port, user: user, pass: pass);
    }
    return LocalSocks.noAuth(port);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalSocks &&
      other.port == port &&
      other.user == user &&
      other.pass == pass;

  @override
  int get hashCode => Object.hash(port, user, pass);

  /// Names the port only. The credentials never go into a log.
  @override
  String toString() =>
      'LocalSocks($port${hasAuth ? ', with credentials' : ''})';
}
