import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_client.dart';
import '../../api/device_service.dart';
import '../../api/referral_service.dart';
import '../../services/vpn_event_reporter.dart';

/// Where an invite event happened.
enum InviteSurface {
  /// The invite card after a good connection, while the tunnel is up.
  afterConnect('after_connect'),

  /// The same card right after a good session the user ended in the app.
  afterDisconnect('after_disconnect'),

  /// The home screen's Invite friends shortcut opened the invite screen.
  homeButton('home_button'),

  /// The invite screen, opened from Settings, and every tap on it.
  inviteScreen('invite_screen'),

  /// The limit sheet's "See your invites" link opened the invite screen.
  limitSheet('limit_sheet'),

  /// The limit sheet with its invite card: opened, shared from, or closed
  /// with no share. Its shown event counts the sheet's opens.
  limitSheetOffer('limit_sheet_offer'),

  /// The introduction to the invite tree: opened, shared from on its last
  /// page, or closed before its last page.
  treeIntro('tree_intro'),

  /// The invite link on the server card while the daily data is used up
  /// opened the limit sheet.
  serverCard('server_card'),

  /// The invite link on the home data line, offered before the daily data
  /// runs out, opened the invite screen.
  quotaLine('quota_line');

  const InviteSurface(this.wire);
  final String wire;
}

/// What happened there.
enum InviteAction {
  shown('shown'),
  dismissed('dismissed'),
  telegram('telegram'),
  whatsapp('whatsapp'),
  copyLink('copy_link'),
  otherApps('other_apps');

  const InviteAction(this.wire);
  final String wire;
}

/// Whether the invite card and the invite screen were seen and which of
/// their buttons were tapped, for the backend's Invites page.
///
/// The rules are those of the Premium offer events (BillingState.logUpsell
/// and sendUpsellEvents): nothing is kept while "Share connection
/// diagnostics" is off (unset means on), turning it off drops what waits,
/// the events go in one call [sendEvery] after the first or when the app
/// is left, a backend without the route (404 or 405) drops the batch, and
/// a failed send keeps it. No event names whom the user sent anything to.
/// Never throws.
class InviteEvents {
  InviteEvents({
    ReferralService? service,
    Future<String> Function()? deviceId,
    Future<bool> Function()? sharing,
    DateTime Function()? clock,
  }) : _service = service ?? ReferralService(),
       _deviceId = deviceId ?? DeviceService().getDeviceId,
       _sharingCheck = sharing,
       _clock = clock ?? DateTime.now {
    unawaited(_readSharing());
  }

  /// The most events kept on the phone, and sent in one call. The
  /// backend refuses a larger batch.
  static const maxQueued = 50;

  /// How long after the first event the batch goes out.
  static const sendEvery = Duration(minutes: 1);

  final ReferralService _service;
  final Future<String> Function() _deviceId;
  final Future<bool> Function()? _sharingCheck;
  final DateTime Function() _clock;

  final List<Map<String, Object?>> _queue = [];
  bool _sharing = true;
  bool _sending = false;
  bool _sendAgain = false;
  bool _disposed = false;
  Timer? _timer;

  /// The events waiting to be sent, for tests.
  @visibleForTesting
  List<Map<String, Object?>> get queued => List.unmodifiable(_queue);

  /// Note one event. Never throws.
  void log(InviteSurface surface, InviteAction action) {
    if (_disposed || !_sharing) return;
    _queue.add({
      'surface': surface.wire,
      'action': action.wire,
      'at': _clock().toUtc().toIso8601String(),
    });
    _trim();
    _timer ??= Timer(sendEvery, () {
      _timer = null;
      unawaited(send());
    });
  }

  void _trim() {
    if (_queue.length > maxQueued) {
      _queue.removeRange(0, _queue.length - maxQueued);
    }
  }

  /// The user turned "Share connection diagnostics" on or off. Off drops
  /// the events waiting on the phone and keeps no new ones.
  void sharingChanged(bool on) {
    _sharing = on;
    if (!on) {
      _queue.clear();
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Read the diagnostics switch again. A switch that cannot be read is
  /// treated as off. Returns what it read.
  Future<bool> _readSharing() async {
    bool on;
    try {
      final check = _sharingCheck;
      if (check != null) {
        on = await check();
      } else {
        final prefs = await SharedPreferences.getInstance();
        on = prefs.get(VpnEventReporter.sharePrefKey) != false;
      }
    } catch (_) {
      on = false;
    }
    sharingChanged(on);
    return on;
  }

  /// Send the waiting events now. Called when the app is left and by the
  /// timer [log] starts. A call made while a send is going sends what
  /// arrived meanwhile right after it, when that send went through. Never
  /// throws.
  Future<void> send() async {
    if (_sending) {
      _sendAgain = true;
      return;
    }
    _timer?.cancel();
    _timer = null;
    if (_queue.isEmpty) return;
    _sending = true;
    var sent = false;
    try {
      if (!await _readSharing()) return;
      final batch = List.of(_queue);
      _queue.clear();
      try {
        final id = await _deviceId();
        await _service.inviteEvents(id, batch, sentAt: _clock());
        sent = true;
      } on ApiException catch (e) {
        debugPrint('InviteEvents: not sent ($e)');
        final gone = e.statusCode == 404 || e.statusCode == 405;
        final refused = e.statusCode == 413 || e.statusCode == 422;
        if (!gone && !refused) {
          _queue.insertAll(0, batch);
          _trim();
        }
      } catch (e) {
        // A timeout on every route: the batch waits for the next try.
        debugPrint('InviteEvents: not sent ($e)');
        _queue.insertAll(0, batch);
        _trim();
      }
    } finally {
      _sending = false;
    }
    final again = _sendAgain;
    _sendAgain = false;
    if (again && sent && !_disposed) await send();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
