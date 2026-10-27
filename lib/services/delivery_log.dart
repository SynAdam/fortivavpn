import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import '../api/api_routes.dart';
import '../api/bootstrap.dart';
import 'report_queue.dart';
import 'vpn_event_reporter.dart';

/// A record of the app's own uploads to the backend: every try of every
/// upload, on every route, with its size, how long it took and how it
/// ended. Sent later to POST /api/v1/devices/{id}/delivery-log.
///
/// A line can carry every small call from a phone and none of its larger
/// uploads, on any route. The backend sees only the calls that arrive, so
/// it cannot tell a phone whose uploads were cut from a phone that sent
/// none. The phone knows: each try leaves a row here, failed or not, and
/// the rows go out in small uploads ([VpnEventReporter.probeUploadBytes]),
/// the size such a line still carries.
///
/// A row names the endpoint as a template ("/devices/{id}/events"), never
/// with the device id or a query. It names the route (direct, tunnel, or
/// the relay's own address), never the phone's address or the request's
/// contents.
///
/// Reads of the fallback file are kept too, as GET calls to "/bootstrap"
/// on the route "mirror:" and the host (Bootstrap). They are how the backend
/// learns which public hosts phones on each carrier can read it from.
///
/// Otherwise only uploads are kept: POST calls. Two are left out:
///
/// * the delivery log's own uploads. Each upload of the log would
///   otherwise add a row to the log, and that row would need an upload of
///   its own: a phone whose uploads arrive would send the log for ever, one
///   row at a time, and a line that cuts uploads would fill the log with
///   rows about the log until the cap pushed out the rows about the
///   reports. Left out, the log only grows when another report is sent, so
///   it drains. Whether the log itself got out is plain on the backend:
///   its rows arrive or they do not.
/// * the size probe's own transfers, which it reports itself
///   (SizeProbeRunner). They do not go through ApiClient, so they never
///   reach here; the check is for safety.
///
/// A try made while the platform names no network is not kept either. With
/// no network every route fails at once, and the backend files a row whose
/// network type is empty under the carrier the log is later sent from, so
/// a phone in a lift would add failures to the next line it reached.
class DeliveryLog {
  DeliveryLog({
    ReportQueue? queue,
    NetworkTypeProbe? networkType,
    DateTime Function()? clock,
  }) : _queue = queue ?? ReportQueue.deliveryLog(),
       _networkType = networkType ?? VpnEventReporter.currentNetworkType,
       _clock = clock ?? DateTime.now;

  final ReportQueue _queue;
  final NetworkTypeProbe _networkType;
  final DateTime Function() _clock;

  /// How long a row waits for the platform to say which network the phone
  /// is on. A system read; a row with no answer in time is not kept, as a
  /// try with no network is not.
  static const networkTimeout = Duration(seconds: 1);

  /// The endpoints whose tries are not kept. See the class comment.
  static const notLogged = {'/devices/{id}/delivery-log', '/probe/bytes'};

  /// Hear every call [ApiClient] makes from now on. Called once at startup.
  static void install([DeliveryLog? log]) {
    ApiClient.onRouteAttempt = (log ?? DeliveryLog()).record;
  }

  /// Keep one try. Synchronous up to taking its place in the queue, so a
  /// flush started after this call sees the row. Never throws.
  void record(RouteAttempt attempt) {
    try {
      final endpoint = pathTemplate(attempt.endpoint);
      if (attempt.method != 'POST' && endpoint != Bootstrap.endpoint) return;
      if (notLogged.contains(endpoint)) return;
      final status = attempt.status;
      final ok = status != null && status >= 200 && status < 300;
      // When the try started: when the upload left the phone.
      final at = _clock().subtract(attempt.elapsed).toUtc().toIso8601String();
      unawaited(
        _queue.addLater(() async {
          String? network;
          try {
            network = await _networkType().timeout(networkTimeout);
          } catch (_) {}
          if (network == null) return const [];
          return [
            {
              'endpoint': endpoint,
              'route': attempt.route,
              'bytes': attempt.bytes,
              'ok': ok,
              'status': status,
              'ms': attempt.elapsed.inMilliseconds,
              'error': status == null ? errorClass(attempt.error) : null,
              'network_type': network,
              'client_ts': at,
            },
          ];
        }),
      );
    } catch (e) {
      debugPrint('DeliveryLog: could not keep a try: $e');
    }
  }

  /// [endpoint] as a template: under /api/v1 and without it, with the
  /// query dropped and every segment that is not a plain word replaced by
  /// {id}. The segment after /devices/ is always {id} unless it is
  /// register, the one device call that names no device.
  static String pathTemplate(String endpoint) {
    var path = endpoint;
    final cut = path.indexOf(RegExp('[?#]'));
    if (cut >= 0) path = path.substring(0, cut);
    if (path.startsWith('/api/v1/')) path = path.substring('/api/v1'.length);
    final segments = path.split('/');
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      if (s.isEmpty) continue;
      final afterDevices = i > 0 && segments[i - 1] == 'devices';
      final named = afterDevices
          ? _deviceCalls.contains(s)
          : _word.hasMatch(s) && s.length <= _longestWord;
      if (!named) segments[i] = '{id}';
    }
    return segments.join('/');
  }

  /// The call under /devices/ that is not about one device.
  static const _deviceCalls = {'register'};

  /// A path segment that names a call rather than a thing: a lowercase
  /// word, with - or _ inside.
  static final _word = RegExp(r'^[a-z][a-z_-]*$');

  /// Longer than any call name the backend has. A segment longer than this
  /// is an id even when it is all letters.
  static const _longestWord = 32;

  /// [error] in one word, at most 200 characters, with no address in it.
  ///
  /// The message of a socket error names the host and port it dialled,
  /// which is our own server, and may name more on some platforms. Only the
  /// kind of failure leaves the phone: timeout, refused, reset,
  /// unreachable, dns, tls, certificate, closed, socks, socket, or the
  /// error's type.
  static String? errorClass(Object? error) {
    if (error == null) return null;
    final text = error.toString().toLowerCase();
    final String kind;
    if (error is TimeoutException) {
      kind = 'timeout';
    } else if (error is SocksException) {
      kind = 'socks';
    } else if (text.contains('certificate')) {
      kind = 'certificate';
    } else if (error is TlsException) {
      kind = 'tls';
    } else if (text.contains('failed host lookup') ||
        text.contains('no address associated')) {
      kind = 'dns';
    } else if (text.contains('refused')) {
      kind = 'refused';
    } else if (text.contains('reset')) {
      kind = 'reset';
    } else if (text.contains('unreachable') || text.contains('no route')) {
      kind = 'unreachable';
    } else if (text.contains('timed out')) {
      kind = 'timeout';
    } else if (text.contains('closed') || text.contains('terminated')) {
      kind = 'closed';
    } else if (error is SocketException) {
      kind = 'socket';
    } else if (error is http.ClientException) {
      kind = 'client';
    } else {
      kind = error.runtimeType.toString();
    }
    return kind.length > 200 ? kind.substring(0, 200) : kind;
  }
}
