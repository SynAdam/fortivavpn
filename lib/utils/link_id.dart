import 'dart:convert';

import 'package:crypto/crypto.dart';

/// A short name for one shared link that the phone and the backend both
/// compute: `lid`.
///
/// The first 12 hex characters of the SHA-256 of the link, without its
/// `#` label and the whitespace around it. The label is left out because
/// channels rename a link they repost, and it is still the same link. The
/// backend computes the same value from the list it serves, so a report
/// that carries a lid names one link without carrying the link, whose
/// credential is in it.
class LinkId {
  const LinkId._();

  /// How many hex characters a lid has.
  static const length = 12;

  /// The ids worked out so far, by link. A list is read again and again
  /// while the checklist orders it, and every read hashed every link.
  static final _known = <String, String>{};

  /// More links than any list holds. Past it the map starts again rather
  /// than grow for as long as the app runs.
  static const _keep = 2000;

  /// The lid of [uri].
  static String of(String uri) {
    final known = _known[uri];
    if (known != null) return known;
    final hash = uri.indexOf('#');
    final body = (hash == -1 ? uri : uri.substring(0, hash)).trim();
    final id = sha256
        .convert(utf8.encode(body))
        .toString()
        .substring(0, length);
    if (_known.length >= _keep) _known.clear();
    _known[uri] = id;
    return id;
  }
}
