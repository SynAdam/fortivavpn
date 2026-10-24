/// A link an operator wants measured from this phone's network.
///
/// Not a server. Nothing in the app may offer one of these as something to
/// connect through: the whole point is to learn whether a link works from
/// inside Iran without anyone's traffic riding it. It is dialled once by the
/// core's proxy-only delay test, the result is reported, and it is forgotten.
///
/// Kept as its own type rather than reusing [Server] precisely so that it
/// cannot reach the server list by being passed to the wrong function.
class ProbeCandidate {
  const ProbeCandidate({
    required this.id,
    required this.uri,
    required this.label,
  });

  /// The backend's id for this candidate, which the result is filed under.
  final int id;

  /// The link to test: vless, vmess, trojan or ss.
  final String uri;

  /// What the operator called it, for logs. Never shown to the user.
  final String label;

  static ProbeCandidate? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final uri = json['uri'];
    if (id is! int || uri is! String || uri.isEmpty) return null;
    final label = json['label'];
    return ProbeCandidate(
      id: id,
      uri: uri,
      label: label is String && label.isNotEmpty ? label : 'candidate-$id',
    );
  }
}
