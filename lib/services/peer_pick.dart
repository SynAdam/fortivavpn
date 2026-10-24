import 'dart:io';

import 'package:flutter/foundation.dart';

import 'tunnel_channels.dart';

/// How a try to get the fallback file from another phone came back.
enum PeerPickStatus {
  /// Text came back: what was in the code, or in the file.
  ok,

  /// The user came back without a photo or a file.
  cancelled,

  /// The camera app said it took a photo but handed none back: some ignore
  /// where they are asked to save it.
  noPhoto,

  /// The photo had no code in it that could be read.
  noCode,

  /// This device has no camera app or no file picker to open.
  unavailable,

  /// The file could not be read, or is far too big to be ours.
  unreadable,
}

/// The camera app and the file picker, opened from Android
/// (handler/PeerHandoff.kt) for PeerReceiveScreen.
abstract final class PeerPick {
  /// Whether this platform can open them.
  static bool get supported => !kIsWeb && Platform.isAndroid;

  /// Open the camera app, and read the QR code in the photo it takes.
  static Future<({PeerPickStatus status, String? text})> photograph() =>
      _call('peerPhotograph');

  /// Open the file picker, and read the file the user picks.
  static Future<({PeerPickStatus status, String? text})> openFile() =>
      _call('peerOpenFile');

  /// An answer that came back after Android stopped and restarted the app
  /// while the camera app or the picker was open, once, or null. Android
  /// often does that on a phone with little memory.
  static Future<({PeerPickStatus status, String? text})?> leftover() async {
    if (!supported) return null;
    try {
      final reply = await TunnelChannels.method
          .invokeMapMethod<String, Object?>('peerLeftover');
      return reply == null ? null : parse(reply);
    } catch (e) {
      debugPrint('PeerPick: no leftover answer ($e)');
      return null;
    }
  }

  static Future<({PeerPickStatus status, String? text})> _call(
    String method,
  ) async {
    if (!supported) return (status: PeerPickStatus.unavailable, text: null);
    try {
      final reply = await TunnelChannels.method
          .invokeMapMethod<String, Object?>(method);
      return parse(reply);
    } catch (e) {
      debugPrint('PeerPick: $method failed ($e)');
      return (status: PeerPickStatus.unavailable, text: null);
    }
  }

  /// The platform's answer, read. Anything unexpected is
  /// [PeerPickStatus.unavailable].
  @visibleForTesting
  static ({PeerPickStatus status, String? text}) parse(
    Map<String, Object?>? reply,
  ) {
    final text = reply?['text'];
    return switch (reply?['status']) {
      'ok' when text is String => (status: PeerPickStatus.ok, text: text),
      'cancelled' => (status: PeerPickStatus.cancelled, text: null),
      'no_photo' => (status: PeerPickStatus.noPhoto, text: null),
      'no_code' => (status: PeerPickStatus.noCode, text: null),
      'unreadable' => (status: PeerPickStatus.unreadable, text: null),
      _ => (status: PeerPickStatus.unavailable, text: null),
    };
  }
}
