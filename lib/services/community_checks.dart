import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/device_service.dart';
import '../utils/link_id.dart';
import '../utils/shared_link.dart';
import '../utils/vless_link.dart';
import 'connect_diagnostics.dart';
import 'tunnel_channels.dart';
import 'vpn_event_reporter.dart';

/// Why a community link was checked. Mirrors the kinds the backend takes.
enum CommunityCheckKind {
  /// The connect flow checked it after none of this device's own doors
  /// carried a tunnel.
  fallback,

  /// The user tested it on the public list.
  ping;

  String get wire => name;
}

/// One check of one community link: did data flow through it, and how fast.
@immutable
class CommunityCheck {
  const CommunityCheck({
    required this.link,
    required this.kind,
    required this.ok,
    required this.at,
    this.ms,
    this.error,
  });

  /// The link as the public list gave it. Never sent: the row names it by
  /// its lid, scheme, host and port.
  final String link;
  final CommunityCheckKind kind;
  final bool ok;

  /// When the check ended.
  final DateTime at;

  /// The round trip of a check that passed. For one that failed, how long
  /// it took to fail, as the door checks report it: a link that is cut
  /// fails at once, one that is dropped waits out the timeout.
  final int? ms;

  /// Why a failed check failed, when the check could say.
  final String? error;
}

/// Sends one upload of community checks to the backend.
typedef CommunityCheckSender =
    Future<void> Function(
      String deviceId,
      List<Map<String, dynamic>> checks,
      bool viaTunnel,
    );

/// Tells the backend what this phone found when it checked community links.
///
/// The connect flow's fallback and the public list's "Test all" dial
/// community links from phones in Iran, through the core's proxy-only delay
/// test. They are the best reading there is of which of those links work on
/// which carrier, and until this they stayed on the phone.
///
/// Sent the way the candidate checks are (CandidateProber): the same
/// client, only while the app's own requests go around the tunnel, and only
/// while the diagnostics switch is on. Nothing is kept on the phone. An
/// upload that fails is tried once more and then dropped with the rest of
/// that report. A backend without the endpoint answers 404, and that ends
/// the report quietly.
class CommunityChecks {
  CommunityChecks({
    CommunityCheckSender? send,
    BackendPost? post,
    DateTime Function()? clock,
    Future<String> Function()? deviceId,
    Future<String> Function()? appVersion,
    String? platform,
    NetworkTypeProbe? networkType,
    Future<String?> Function()? carrier,
    this.throughTunnel,
  }) : _send = send ?? _postChecks(post ?? _apiPost, clock ?? DateTime.now),
       _deviceId = deviceId ?? (() => DeviceService().getDeviceId()),
       _appVersion = appVersion ?? (() => DeviceService().getAppVersion()),
       _platform = platform ?? DeviceService().platform,
       _networkType = networkType ?? VpnEventReporter.currentNetworkType,
       _carrier = carrier ?? _defaultCarrier;

  /// The most checks one upload carries. The backend takes no more.
  static const maxPerUpload = 16;

  /// The longest error kept, as for a door check.
  static const _maxError = 200;

  final CommunityCheckSender _send;
  final Future<String> Function() _deviceId;
  final Future<String> Function() _appVersion;
  final String _platform;
  final NetworkTypeProbe _networkType;
  final Future<String?> Function() _carrier;

  /// Whether the app's own requests, and with them its delay tests, go
  /// through the tunnel right now. A check made through our tunnel says
  /// nothing about the carrier, so then nothing is sent. Null counts as
  /// yes, so a reporter nobody set up sends nothing.
  bool Function()? throughTunnel;

  /// The report being sent, so the next one waits for it rather than
  /// sending beside it.
  Future<void> _queue = Future<void>.value();

  static Future<void> _apiPost(String path, Map<String, dynamic> body) async {
    await ApiClient().post(path, body: body);
  }

  /// The default [CommunityCheckSender]. [clock] is read for `sent_at`
  /// only; each check's `client_ts` is still when it ended.
  static CommunityCheckSender _postChecks(
    BackendPost post,
    DateTime Function() clock,
  ) =>
      (deviceId, checks, viaTunnel) =>
          post('/api/v1/devices/$deviceId/community-checks', {
            'checks': checks,
            'via_tunnel': viaTunnel,
            // The server compares this with its own clock and corrects
            // each client_ts by the gap, because some phones' clocks are
            // hours or days off.
            'sent_at': clock().toUtc().toIso8601String(),
          });

  static Future<String?> _defaultCarrier() async {
    try {
      final report = await ConnectDiagnostics(
        channel: TunnelChannels.method,
      ).platformReport();
      final c = report['carrier'] ?? report['sim_carrier'];
      return c is String && c.isNotEmpty ? c : null;
    } catch (_) {
      return null;
    }
  }

  /// Send [checks], in uploads of at most [maxPerUpload]. [carrier] when
  /// the caller has read it already; otherwise it is read here.
  ///
  /// Never throws. Completes when the report is sent or dropped, after any
  /// report before it.
  Future<void> report(List<CommunityCheck> checks, {String? carrier}) {
    if (checks.isEmpty) return Future<void>.value();
    // Asked now, while it still describes the moment the checks ran.
    if (throughTunnel?.call() ?? true) return Future<void>.value();
    final run = _queue.then((_) => _report(checks, carrier));
    _queue = run;
    return run;
  }

  Future<void> _report(List<CommunityCheck> checks, String? carrier) async {
    try {
      if (!await _sharing()) return;
      final network = await _networkType();
      final where = carrier ?? await _carrier();
      final appVersion = await _appVersion();
      final rows = [
        for (final c in checks)
          ?row(
            c,
            appVersion: appVersion,
            platform: _platform,
            networkType: network,
            carrier: where,
          ),
      ];
      if (rows.isEmpty) return;
      final deviceId = await _deviceId();
      for (var i = 0; i < rows.length; i += maxPerUpload) {
        // Read again before every upload, as for door checks: a switch
        // turned off while a report is going out stops the rest of it.
        if (!await _sharing()) return;
        final upload = rows.sublist(i, min(i + maxPerUpload, rows.length));
        if (!await _deliver(deviceId, upload)) return;
      }
    } catch (e) {
      debugPrint('CommunityChecks: could not report: $e');
    }
  }

  /// The row the backend stores for [check]. Null for a link of a kind the
  /// app does not dial, which no check of the app's can be about.
  @visibleForTesting
  static Map<String, dynamic>? row(
    CommunityCheck check, {
    required String appVersion,
    required String platform,
    String? networkType,
    String? carrier,
  }) {
    final scheme = SharedLink.scheme(check.link);
    if (!SharedLink.usableSchemes.contains(scheme)) return null;
    final host = VlessLink.hostname(check.link);
    final ms = check.ms;
    final error = check.error;
    return {
      'lid': LinkId.of(check.link),
      'scheme': scheme,
      'host': host.isEmpty ? null : host,
      'port': host.isEmpty ? null : VlessLink.port(check.link),
      'kind': check.kind.wire,
      'ok': check.ok,
      'ms': ms == null || ms < 0 ? null : ms,
      'error': error == null || error.isEmpty
          ? null
          : (error.length > _maxError ? error.substring(0, _maxError) : error),
      'app_version': appVersion,
      'platform': platform,
      'network_type': networkType,
      'carrier': carrier,
      'client_ts': check.at.toUtc().toIso8601String(),
    };
  }

  /// Send one upload. True when it went. One more try after a failure
  /// that a second try can get past; none after one it cannot.
  Future<bool> _deliver(
    String deviceId,
    List<Map<String, dynamic>> upload,
  ) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        // Always false: nothing is sent while the app's requests go
        // through the tunnel (see [throughTunnel]).
        await _send(deviceId, upload, false);
        return true;
      } on ApiException catch (e) {
        debugPrint('CommunityChecks: backend answered $e');
        if (!worthAnotherTry(e)) return false;
      } catch (e) {
        debugPrint('CommunityChecks: could not send: $e');
      }
    }
    return false;
  }

  /// Whether the answer [e] can change on a second try: no answer at all
  /// (status 0), a timeout (408), a rate limit (429) or a fault on our side
  /// (5xx). A 404 is a backend without this endpoint or a device it does
  /// not know, and any other 4xx is about the upload itself.
  static bool worthAnotherTry(ApiException e) =>
      e.statusCode == 0 ||
      e.statusCode == 408 ||
      e.statusCode == 429 ||
      e.statusCode >= 500;

  /// Whether the user lets the app send reports. Unset means yes, as for
  /// every other report.
  static Future<bool> _sharing() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.get(VpnEventReporter.sharePrefKey) != false;
  }
}
