import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'tunnel_channels.dart';

/// Whether this copy of the app is the one Google Play signed.
///
/// Every copy runs the same code: the one installed from Google Play and
/// the APK posted in the Telegram channel. Google Play Billing sells only in
/// a copy signed with Google Play's app signing certificate, because Play
/// signs the copies it delivers with it. The channel APK is signed with our
/// upload key, so Play refuses to sell in it. The app reads its own signing
/// certificate when it starts and offers Google Play only when it is
/// Google's. That is the only difference between the copies, and it is
/// read at run time, never chosen when the app is built.
///
/// A debug build is signed with the debug key, so it is never Google's.
/// Tests pass the answer in.
class PlaySignature {
  PlaySignature({MethodChannel? channel, bool? android})
    : _channel = channel ?? TunnelChannels.method,
      _android = android ?? Platform.isAndroid;

  /// The SHA-256 of Google Play's app signing certificate for
  /// com.vpn.fortivavpn, exactly as Play Console shows it under App
  /// integrity.
  static const googleCertSha256 =
      'E1:F5:F9:1D:AA:A7:F9:AE:07:FF:3B:02:06:0F:6E:33:'
      'BA:21:21:5C:16:F2:EA:70:9B:E0:B1:96:D7:C9:08:A5';

  static const timeout = Duration(seconds: 2);

  /// The one the app asks, so Premium (BillingState) and the update prompt
  /// (UpdateDialog) share one answer and Android is asked once.
  static final shared = PlaySignature();

  final MethodChannel _channel;
  final bool _android;

  /// The answer, once there is one.
  bool? _known;

  /// The question while it is out, so callers at the same moment share it.
  Future<bool>? _asking;

  /// True only when Android says this copy is signed with
  /// [googleCertSha256]. Asked once and remembered. Never throws: anything
  /// that goes wrong is false, so a copy that cannot tell offers no Google
  /// Play purchase.
  ///
  /// The answer is kept as a bool, and every call returns a new Future.
  /// [shared] lives as long as the process, and a test that awaits a Future
  /// kept from an earlier test's fake clock never gets past the await.
  Future<bool> read() async {
    final known = _known;
    if (known != null) return known;
    final asking = _asking ??= _ask();
    try {
      return await asking;
    } finally {
      if (identical(_asking, asking)) _asking = null;
    }
  }

  Future<bool> _ask() async {
    // Google Play Billing exists only on Android.
    if (!_android) return _known = false;
    try {
      final digests = await _channel
          .invokeListMethod<Object?>('signingCertificates')
          .timeout(timeout);
      return _known = isGoogle(digests ?? const []);
    } on TimeoutException {
      // No answer is not a "no". The next read asks again.
      return false;
    } catch (_) {
      // MissingPluginException (tests, an old native side) or a
      // PlatformException.
      return _known = false;
    }
  }

  /// Whether one of [digests], each the SHA-256 of a signing certificate in
  /// hex with or without colons, is Google Play's.
  static bool isGoogle(Iterable<Object?> digests) {
    final google = normalise(googleCertSha256);
    return digests.any((d) => d is String && normalise(d) == google);
  }

  /// [digest] in upper case with no colons or spaces.
  static String normalise(String digest) =>
      digest.replaceAll(RegExp(r'[\s:]'), '').toUpperCase();
}
