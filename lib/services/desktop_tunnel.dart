import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:win32_registry/win32_registry.dart';

import 'mac_daemon.dart';
import 'tunnel_pipe.dart';

/// The desktop clients' side of the tunnel service (windows/core): a Windows
/// service on Windows, a launchd daemon on macOS.
///
/// The rest of the app reaches the tunnel through the method channel
/// `com.vpn.fortivavpn/tunnel` and the event channel
/// `com.vpn.fortivavpn/tunnel/status`, whose native code Android and iOS
/// register. The desktops have no native tunnel code of their own: the
/// tunnel is a separate process that runs with the rights a tunnel needs.
/// [method] and [status] are those two channels in name only. They answer
/// here, in the shapes the mobile platforms answer in, by calling the
/// service over its pipe or socket, so nothing that uses the channels needs
/// to know which platform it is on.
class DesktopTunnel {
  DesktopTunnel({
    TunnelPipe? pipe,
    Future<Object?> Function()? installId,
    Future<Object?> Function(int bytes, int capMs)? throughputSample,
    MacDaemon? daemon,
    @visibleForTesting this.retryDelay = const Duration(seconds: 2),
    @visibleForTesting this.daemonStartWait = const Duration(seconds: 8),
    @visibleForTesting this.settingsEvery = const Duration(minutes: 2),
  }) : _client = TunnelClient(pipe ?? const NamedPipe()),
       _installId = installId ?? _machineGuid,
       _throughputSample = throughputSample ?? _download,
       _daemon = daemon;

  /// The app's tunnel: the Windows service's pipe, or the macOS daemon's
  /// socket with the daemon itself to add when it is not there yet.
  static final instance = Platform.isMacOS
      ? DesktopTunnel(
          pipe: const UnixSocketPipe(macSocket),
          installId: _platformUuid,
          daemon: const MacDaemon(),
        )
      : DesktopTunnel();

  /// The macOS daemon's socket (windows/core/internal/control/listen_darwin.go).
  static const macSocket = '/var/run/fortiva-tunnel.sock';

  /// The code a connect fails with on macOS while the person has not
  /// allowed the daemon yet. The app has opened System Settings for them.
  static const approvalCode = 'SERVICE_APPROVAL';

  final TunnelClient _client;
  final Future<Object?> Function() _installId;
  final Future<Object?> Function(int bytes, int capMs) _throughputSample;

  /// The macOS daemon, null on Windows, where the installer adds the
  /// service.
  final MacDaemon? _daemon;

  /// How long the status stream waits before asking a service that did not
  /// answer again.
  final Duration retryDelay;

  /// How long a connect waits for a daemon launchd has just been allowed
  /// to start.
  final Duration daemonStartWait;

  /// System Settings opens at most once in this time. Door checks run in
  /// the background too, and each would otherwise open it again.
  final Duration settingsEvery;
  DateTime? _settingsOpened;

  late final MethodChannel method = _TunnelMethodChannel(this);
  late final EventChannel status = _TunnelStatusChannel(this);

  /// Answers one call of the method channel.
  Future<Object?> invoke(String method, Object? arguments) async {
    final args = arguments is Map ? arguments : const {};
    try {
      switch (method) {
        case 'connect':
          await _withService(
            () => _client.call(
              'connect',
              params: {
                'link': args['link'],
                if (args['alternates'] case final List a when a.isNotEmpty)
                  'alternates': a,
                if (args['exits'] case final List e when e.isNotEmpty)
                  'exits': e,
                if (args['penalties'] case final List p when p.isNotEmpty)
                  'penalties': p,
                if (_dnsList(args['dns']) case final d when d.isNotEmpty)
                  'dns': d,
              },
            ),
          );
          // The outcome arrives on the status stream, as on Android.
          return null;
        case 'disconnect':
          await _client.call('disconnect');
          return null;
        case 'getStatus':
          return statusLine(await _client.call('status'));
        case 'tunnelStats':
        case 'diagnostics':
        case 'place':
          return await _client.call(method);
        case 'realPing':
        case 'realPingDetail':
          final params = {'link': args['link']};
          if (_daemon == null) {
            return await _client.call(method, params: params);
          }
          // A connect checks its doors before it sends "connect", so on a
          // first run the door check is what finds the daemon missing and
          // adds it. A check the daemon cannot run yet fails with the
          // reason, as a door that does not answer does, so the connect
          // flow carries on to its end and says so.
          try {
            return await _withService(
              () => _client.call(method, params: params),
            );
          } on TunnelCallException catch (e) {
            if (e.code != approvalCode &&
                e.code != TunnelCallException.unavailable) {
              rethrow;
            }
            return method == 'realPing' ? -1 : {'ms': -1, 'error': _message(e)};
          }
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
        return {
          'tunnel_service': 'not_running',
          if (_daemon != null) 'daemon': (await _daemonState()).name,
        };
      }
      throw PlatformException(code: e.code, message: _message(e));
    }
    // testConnection and localSocks go through the core's SOCKS port, which
    // only Android opens; the review prompt and the Play listing are Play's.
    // The callers already expect these to be missing.
    throw MissingPluginException(
      'No implementation found for method $method on '
      '${_daemon != null ? 'macOS' : 'Windows'}',
    );
  }

  /// Runs [call]. On macOS a daemon that is not there is added first:
  /// macOS asks the person to allow it, and the app opens System Settings
  /// where they do. Once it is allowed, launchd starts it, and the call is
  /// made again until the daemon answers or [daemonStartWait] has passed.
  Future<T> _withService<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on TunnelCallException catch (e) {
      final daemon = _daemon;
      if (daemon == null || e.code != TunnelCallException.unavailable) {
        rethrow;
      }
      final state = await _daemonState(ensure: true);
      if (state == MacDaemonState.requiresApproval) {
        final now = DateTime.now();
        final last = _settingsOpened;
        if (last == null || now.difference(last) >= settingsEvery) {
          _settingsOpened = now;
          try {
            await daemon.openSettings();
          } catch (e) {
            debugPrint('DesktopTunnel: could not open System Settings ($e)');
          }
        }
        throw const TunnelCallException(approvalCode, 'not allowed yet');
      }
      if (state != MacDaemonState.enabled) rethrow;
      final deadline = DateTime.now().add(daemonStartWait);
      while (true) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        try {
          return await call();
        } on TunnelCallException catch (again) {
          if (again.code != TunnelCallException.unavailable ||
              DateTime.now().isAfter(deadline)) {
            rethrow;
          }
        }
      }
    }
  }

  /// Adds the macOS daemon when it is not there yet, without opening System
  /// Settings: macOS itself then says that Fortiva added a background item.
  /// Called once at launch, so the daemon is there before the first
  /// connect. Does nothing on Windows, whose installer adds the service.
  Future<void> prepareService() async {
    if (_daemon == null) return;
    await _daemonState(ensure: true);
  }

  /// The daemon's state, added first when [ensure]. Unknown when the app's
  /// native code cannot say.
  Future<MacDaemonState> _daemonState({bool ensure = false}) async {
    final daemon = _daemon;
    if (daemon == null) return MacDaemonState.unknown;
    try {
      return ensure ? await daemon.ensure() : await daemon.status();
    } catch (e) {
      debugPrint('DesktopTunnel: the daemon cannot be asked ($e)');
      return MacDaemonState.unknown;
    }
  }

  String _message(TunnelCallException e) {
    if (e.code == approvalCode) {
      return 'Allow Fortiva VPN in System Settings, under General, '
          'Login Items & Extensions, then connect again.';
    }
    if (e.code != TunnelCallException.unavailable) return e.message;
    return _daemon != null
        ? 'The Fortiva service is not running. Quit Fortiva VPN, open it '
              'again and connect.'
        : 'The Fortiva service is not running. Reinstall Fortiva to restore it.';
  }

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
        debugPrint('DesktopTunnel: status watch failed ($e)');
        seen = -1;
        await Future<void>.delayed(retryDelay);
      }
    }
  }

  /// IOPlatformUUID: the Mac's own identifier, the same for every user of
  /// the Mac and unchanged by reinstalling the app or macOS, which is
  /// MachineGuid's part on Windows. Readable without administrator rights.
  static Future<Object?> _platformUuid() async {
    try {
      final result = await Process.run('/usr/sbin/ioreg', [
        '-rd1',
        '-c',
        'IOPlatformExpertDevice',
      ]);
      return platformUuidOf('${result.stdout}');
    } catch (e) {
      debugPrint('DesktopTunnel: no IOPlatformUUID ($e)');
      return null;
    }
  }

  /// The IOPlatformUUID line of ioreg's answer, or null.
  @visibleForTesting
  static String? platformUuidOf(String ioreg) => RegExp(
    r'"IOPlatformUUID"\s*=\s*"([0-9A-Fa-f-]{36})"',
  ).firstMatch(ioreg)?.group(1);

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
      debugPrint('DesktopTunnel: no MachineGuid ($e)');
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
      debugPrint('DesktopTunnel: throughput sample failed ($e)');
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

class _TunnelMethodChannel extends MethodChannel {
  _TunnelMethodChannel(this._tunnel) : super('com.vpn.fortivavpn/tunnel');

  final DesktopTunnel _tunnel;

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async =>
      await _tunnel.invoke(method, arguments) as T?;
}

class _TunnelStatusChannel extends EventChannel {
  _TunnelStatusChannel(this._tunnel)
    : super('com.vpn.fortivavpn/tunnel/status');

  final DesktopTunnel _tunnel;

  @override
  Stream<dynamic> receiveBroadcastStream([dynamic arguments]) =>
      _tunnel.statusStream;
}
