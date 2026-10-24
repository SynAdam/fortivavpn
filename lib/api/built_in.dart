/// Addresses and keys compiled into the app: where the fallback file is
/// published, the keys it is checked and opened with, and the API relays a
/// phone tries before the backend has sent its own list.
///
/// This is the public copy of the file, and it is empty on purpose. The
/// relays and the fallback file are ways around censorship, and an address
/// that is easy to find is easy to block, so the values in the builds we
/// ship are not published here. A build from this source works the same
/// way, except that it has no relay to try and no fallback file to read
/// until the backend answers.
///
/// To use your own, fill these in. The fallback file format is described
/// at openSealed in lib/api/bootstrap.dart.
abstract final class BuiltIn {
  /// True in the public copy, where the tests that check these values are
  /// real skip.
  static const isPublicCopy = true;

  /// Where the fallback file is published.
  static const fallbackMirrors = <String>[];

  /// The Ed25519 public key fallback files are signed with, base64.
  static const fallbackPublicKey = '';

  /// The AES-256-GCM key fallback files are sealed with, base64.
  static const fallbackSealKey = '';

  /// API relays to try before the backend has sent its own list. The pin is
  /// the lowercase hex SHA-256 of the relay certificate's DER bytes.
  static const relays = <({String url, String pin})>[];
}
