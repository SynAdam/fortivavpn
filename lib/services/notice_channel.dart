import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What Android says about notifications for messages from the Fortiva
/// team.
enum NoticePermission {
  /// They show.
  granted,

  /// Android 13 or later has not granted POST_NOTIFICATIONS. Its dialog may
  /// still show, or may not: Android shows none after the user refused
  /// twice. See [NoticeChannel.rationale].
  ask,

  /// The permission is not the problem: Android 12 or earlier, or the app's
  /// or this channel's notifications are off in the system settings, which
  /// only the user can change there ([NoticeChannel.openSettings]). Also
  /// the answer off Android.
  denied,
}

/// The Android side of messages as notifications: the background check
/// (NoticeJobService), the notification itself (NoticeNotifier), and what
/// the app asks of both (MainActivity). The same channel name on both
/// engines, the app's and the background check's; each answers only the
/// calls its side has.
abstract final class NoticeChannel {
  static const _channel = MethodChannel('com.vpn.fortivavpn/notices');

  // ── the background check's engine ──────────────────────────────────

  /// The tunnel's SOCKS port while a tunnel is up, else null.
  static Future<int?> socksPort() async {
    try {
      return await _channel.invokeMethod<int>('socksPort');
    } catch (e) {
      debugPrint('NoticeChannel: no SOCKS port ($e)');
      return null;
    }
  }

  /// The phone's country from its network, SIM or time zone, upper case,
  /// or null.
  static Future<String?> country() async {
    try {
      return await _channel.invokeMethod<String>('country');
    } catch (e) {
      debugPrint('NoticeChannel: no country ($e)');
      return null;
    }
  }

  /// Post a notification for message [id]. Whether it was posted: false
  /// when the user does not allow notifications.
  static Future<bool> show({
    required int id,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('show', {
            'id': id,
            'title': title,
            'body': body,
            'channelName': channelName,
            'channelDescription': channelDescription,
          }) ??
          false;
    } catch (e) {
      debugPrint('NoticeChannel: could not post ($e)');
      return false;
    }
  }

  /// Tell the background check's engine it can stop.
  static Future<void> done() async {
    try {
      await _channel.invokeMethod<void>('done');
    } catch (e) {
      debugPrint('NoticeChannel: could not say done ($e)');
    }
  }

  // ── the app's engine ───────────────────────────────────────────────

  /// The message a tapped notification opened the app for, once, or null.
  static Future<int?> takeOpened() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<int>('opened');
    } catch (e) {
      debugPrint('NoticeChannel: could not read the tapped message ($e)');
      return null;
    }
  }

  /// Whether Android would show its dialog again because the user refused
  /// once (shouldShowRequestPermissionRationale). False before the first
  /// refusal and after the second.
  static Future<bool> rationale() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('rationale') ?? false;
    } catch (e) {
      debugPrint('NoticeChannel: could not read the rationale ($e)');
      return false;
    }
  }

  /// Open the system page with this app's notification settings. Whether
  /// one opened.
  static Future<bool> openSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openSettings') ?? false;
    } catch (e) {
      debugPrint('NoticeChannel: could not open the settings ($e)');
      return false;
    }
  }

  /// What on this phone may stop the background checks, read from the
  /// system; nothing leaves the phone. Null off Android or on failure.
  static Future<Map<String, Object?>?> background() async {
    if (!Platform.isAndroid) return null;
    try {
      final facts = await _channel.invokeMethod<Map<Object?, Object?>>(
        'background',
      );
      return facts?.map((k, v) => MapEntry('$k', v));
    } catch (e) {
      debugPrint('NoticeChannel: could not read the background facts ($e)');
      return null;
    }
  }

  /// Open the screen where the user lets the app run in the background:
  /// the phone maker's own where it has one. Which kind opened ("data",
  /// "maker", "battery", "details"), or null.
  static Future<String?> openBackground() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('openBackground');
    } catch (e) {
      debugPrint('NoticeChannel: could not open the battery settings ($e)');
      return null;
    }
  }

  static Future<NoticePermission> permission() => _permissionCall('permission');

  /// Show Android's dialog, and say what the user answered.
  static Future<NoticePermission> askPermission() =>
      _permissionCall('askPermission');

  static Future<NoticePermission> _permissionCall(String method) async {
    if (!Platform.isAndroid) return NoticePermission.denied;
    try {
      final answer = await _channel.invokeMethod<String>(method);
      return NoticePermission.values.firstWhere(
        (p) => p.name == answer,
        orElse: () => NoticePermission.denied,
      );
    } catch (e) {
      debugPrint('NoticeChannel: could not read the permission ($e)');
      return NoticePermission.denied;
    }
  }
}
