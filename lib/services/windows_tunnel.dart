import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:win32_registry/win32_registry.dart';

import 'tunnel_pipe.dart';

/// The Windows client's side of the tunnel service (windows/core).
///
/// The rest of the app reaches the tunnel through the method channel
/// `com.vpn.fortivavpn/tunnel` and the event channel
/// `com.vpn.fortivavpn/tunnel/status`, whose native code Android and iOS
/// register. Windows has no native code of its own: the tunnel is a separate
/// service. [method] and [status] are those two channels in name only. They
/// answer here, in the shapes the mobile platforms answer in, by calling the
/// service over its pipe, so nothing that uses the channels needs to know
/// which platform it is on.
class WindowsTunnel {
  WindowsTunnel({
    TunnelPipe? pipe,
    Future<Object?> Function()? installId,
    Future<Object?> Function(int bytes, int capMs)? throughputSample,
    @visibleForTesting this.retryDelay = const Duration(seconds: 2),
  }) : _client = TunnelClient(pipe ?? const NamedPipe()),
       _installId = installId ?? _machineGuid,
       _throughputSample = throughputSample ?? _download;

  static final instance = WindowsTunnel();

  final TunnelClient _client;
  final Future<Object?> Function() _installId;
  final Future<Object?> Function(int bytes, int capMs) _throughputSample;

  /// How long the status stream waits before asking a service that did not
  /// answer again.
  final Duration retryDelay;

  late final MethodChannel method = _TunnelMethodChannel(this);
  late final EventChannel status = _TunnelStatusChannel(this);

  /// Answers one call of the method channel.
  Future<Object?> invoke(String method, Object? arguments) async {
    final args = arguments is Map ? arguments : const {};
    try {
      switch (method) {
        case 'connect':
          await _client.call(
            'connect',
            params: {
              'link': args['link'],
              if (args['alternates'] case final List a when a.isNotEmpty)
                'alternates': a,
              if (args['exits'] case final List e when e.isNotEmpty) 'exits': e,
              if (args['penalties'] case final List p when p.isNotEmpty)
                'penalties': p,
              if (_dnsList(args['dns']) case final d when d.isNotEmpty)
                'dns': d,
            },
          );
          // The outcome arrives on the status stream, as on Android.
          return null;
        case 'disconnect':
          await _client.call('disconnect');
          return null;
        case 'getStatus':
          return statusLine(await _client.call('status'));
        case 'tunnelStats':
        case 'drainSiteStats':
        case 'diagnostics':
        case 'place':
          return await _client.call(method);
        case 'realPing':
        case 'realPingDetail':
          return await _client.call(method, params: {'link': args['link']});
        case 'installId':
          return await _installId();
        case 'throughputSample':
          // VpnService says how much and for how long; a call without both
          // gets no sample rather than sizes of this bridge's own.
          final bytes = args['bytes'];
          final capMs = args['capMs'];
          if (bytes is! int || capMs is! int) return null;
          return await _throughputSample(bytes, capMs);
        case 'privateDns':
          // A Private DNS setting that breaks lookups is an Android problem.
          return null;
      }
    } on TunnelCallException catch (e) {
      if (method == 'diagnostics' &&
          e.code == TunnelCallException.unavailable) {
        // A failure with the service gone is itself the finding.
        return {'tunnel_service': 'not_running'};
      }
      throw PlatformException(code: e.code, message: _message(e));
    }
    // testConnection and socksPort go through the core's SOCKS port, which
    // only Android opens; the review prompt and the Play listing are Play's.
    // The callers already expect these to be missing, as they are on iOS.
    throw MissingPluginException(
      'No implementation found for method $method on Windows',
    );
  }

  static String _message(TunnelCallException e) =>
      e.code == TunnelCallException.unavailable
      ? 'The Fortiva service is not running. Reinstall Fortiva to restore it.'
      : e.message;

  /// The DNS screen stores its resolvers as "ip,ip"; the service takes a
  /// list.
  static List<String> _dnsList(Object? value) => value is String
      ? [
          for (final part in value.split(','))
            if (part.trim().isNotEmpty) part.trim(),
        ]
      : const [];

  /// The line the status stream carries for a status of the service: the
  /// state as the mobile platforms spell it, and, for a tunnel the service
  /// took down by stopping, the reason after a colon ("disconnected:killed").
  /// A failure carries no reason: the app files any reason it sees as the
  /// cause of the next drop.
  @visibleForTesting
  static String statusLine(Object? status) {
    if (status is! Map) return 'disconnected';
    final state = status['state'] as String? ?? 'disconnected';
    final reason = status['reason'] as String?;
    if (state == 'disconnected' && reason != null && reason.isNotEmpty) {
      return '$state:$reason';
    }
    return state;
  }

  StreamController<String>? _statuses;
  bool _watching = false;

  /// The tunnel's status, current first, then every change, as the event
  /// channel carries it on Android and iOS. One "watch" call is held open
  /// at a time; the service answers it the moment the status changes.
  Stream<String> get statusStream {
    return (_statuses ??= StreamController<String>.broadcast(
      onListen: () {
        _watching = true;
        unawaited(_watch());
      },
      onCancel: () => _watching = false,
    )).stream;
  }

  Future<void> _watch() async {
    // -1: nothing heard yet, so ask for the status rather than wait for a
    // change.
    var seen = -1;
    var reachable = true;
    while (_watching) {
      try {
        final status = seen < 0
            ? await _client.call('status')
            : await _client.call(
                'watch',
                params: {'after': seen, 'timeoutMs': 25000},
              );
        final seq = status is Map ? (status['seq'] as int? ?? 0) : 0;
        // A number lower than the last means the service restarted, and
        // its state is news too.
        if (seq != seen && _watching) _statuses?.add(statusLine(status));
        seen = seq;
        reachable = true;
      } on TunnelCallException {
        // No service, no tunnel. Said once, then asked again until it
        // answers.
        if (reachable && _watching) _statuses?.add('disconnected');
        reachable = false;
        seen = -1;
        await Future<void>.delayed(retryDelay);
      } catch (e) {
        debugPrint('WindowsTunnel: status watch failed ($e)');
        seen = -1;
        await Future<void>.delayed(retryDelay);
      }
    }
  }

  /// MachineGuid: made when Windows is installed, the same for every user
  /// of the PC, and unchanged by reinstalling the app. That is what the
  /// install ID needs (DeviceIdentity salts and hashes it; it never leaves
  /// the PC as it is). Readable without administrator rights.
  static Future<Object?> _machineGuid() async {
    try {
      return LOCAL_MACHINE.getString(
        'MachineGuid',
        path: r'SOFTWARE\Microsoft\Cryptography',
      );
    } catch (e) {
      debugPrint('WindowsTunnel: no MachineGuid ($e)');
      return null;
    }
  }

  /// [bytes] downloaded from Cloudflare's speed test, stopped at [capMs], as
  /// Android's throughputSample does. Android reaches it through the core's
  /// SOCKS port because the app is outside its own tunnel; here the app's
  /// traffic is inside the tunnel, so a plain request measures it.
  static Future<Object?> _download(int bytes, int capMs) async {
    final client = HttpClient()
      ..connectionTimeout = Duration(milliseconds: capMs);
    try {
      final watch = Stopwatch()..start();
      final request = await client.getUrl(
        Uri.https('speed.cloudflare.com', '/__down', {'bytes': '$bytes'}),
      );
      final response = await request.close().timeout(
        Duration(milliseconds: capMs),
      );
      var read = 0;
      await for (final chunk in response) {
        read += chunk.length;
        if (watch.elapsedMilliseconds >= capMs) break;
      }
      final ms = watch.elapsedMilliseconds;
      return read > 0 && ms > 0 ? {'bytes': read, 'ms': ms} : null;
    } catch (e) {
      debugPrint('WindowsTunnel: throughput sample failed ($e)');
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

class _TunnelMethodChannel extends MethodChannel {
  _TunnelMethodChannel(this._tunnel) : super('com.vpn.fortivavpn/tunnel');

  final WindowsTunnel _tunnel;

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async =>
      await _tunnel.invoke(method, arguments) as T?;
}

class _TunnelStatusChannel extends EventChannel {
  _TunnelStatusChannel(this._tunnel)
    : super('com.vpn.fortivavpn/tunnel/status');

  final WindowsTunnel _tunnel;

  @override
  Stream<dynamic> receiveBroadcastStream([dynamic arguments]) =>
      _tunnel.statusStream;
}
