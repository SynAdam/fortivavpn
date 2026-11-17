import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/desktop_core.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/services/desktop_tunnel.dart';
import 'package:fortiva_vpn/services/mac_daemon.dart';
import 'package:fortiva_vpn/services/tunnel_pipe.dart';

import 'desktop_tunnel_test.dart' show FakeService;

/// The app's native side of the launchd daemon, as SMAppService would
/// answer it.
class FakeDaemon extends MacDaemon {
  FakeDaemon(
    this.state, {
    this.afterRegister = MacDaemonState.requiresApproval,
  });

  MacDaemonState state;
  final MacDaemonState afterRegister;
  int registers = 0;
  int settingsOpened = 0;

  @override
  Future<MacDaemonState> status() async => state;

  @override
  Future<MacDaemonState> register() async {
    registers++;
    return state = afterRegister;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

/// A socket nobody listens on for the first [fails] calls, as the daemon's
/// is while launchd starts it.
class LatePipe implements TunnelPipe {
  LatePipe(this.inner, this.fails);

  final TunnelPipe inner;
  int fails;

  @override
  Future<String> exchange(String request, Duration timeout) {
    if (fails-- > 0) {
      throw const TunnelCallException(
        TunnelCallException.unavailable,
        'not listening yet',
      );
    }
    return inner.exchange(request, timeout);
  }
}

void main() {
  FakeService? service;
  tearDown(() async => service?.close());

  group('the macOS daemon', () {
    test(
      'a daemon not added yet is added, and System Settings opens',
      () async {
        service = await FakeService.start((m, p) => null);
        final daemon = FakeDaemon(MacDaemonState.notRegistered);
        final tunnel = DesktopTunnel(
          pipe: UnixSocketPipe('${service!.path}-missing'),
          daemon: daemon,
          settingsEvery: Duration.zero,
        );
        await expectLater(
          tunnel.method.invokeMethod('connect', {'link': 'vless://a'}),
          throwsA(
            isA<PlatformException>()
                .having((e) => e.code, 'code', DesktopTunnel.approvalCode)
                .having(
                  (e) => e.message,
                  'message',
                  contains('System Settings'),
                ),
          ),
        );
        expect(daemon.registers, 1);
        expect(daemon.settingsOpened, 1);

        // Asked again before the person allows it: not added twice.
        await expectLater(
          tunnel.method.invokeMethod('connect', {'link': 'vless://a'}),
          throwsA(isA<PlatformException>()),
        );
        expect(daemon.registers, 1);
        expect(daemon.settingsOpened, 2);
      },
    );

    test(
      'a first run\'s door check adds the daemon and opens System Settings once',
      () async {
        service = await FakeService.start((m, p) => null);
        final daemon = FakeDaemon(MacDaemonState.notRegistered);
        final tunnel = DesktopTunnel(
          pipe: UnixSocketPipe('${service!.path}-missing'),
          daemon: daemon,
        );
        // A connect checks its doors before it sends "connect": the check
        // is what finds the daemon missing. It fails with the reason, as a
        // door that does not answer does.
        final detail = await tunnel.method.invokeMethod('realPingDetail', {
          'link': 'vless://a',
        });
        expect(detail, {'ms': -1, 'error': contains('System Settings')});
        expect(await tunnel.method.invokeMethod('realPing', {'link': 'b'}), -1);
        expect(daemon.registers, 1);
        // The second check came within settingsEvery.
        expect(daemon.settingsOpened, 1);
      },
    );

    test('a daemon macOS has no record of is added too', () async {
      // macOS answers notFound, not notRegistered, before the first add.
      final daemon = FakeDaemon(MacDaemonState.notFound);
      await DesktopTunnel(daemon: daemon).prepareService();
      expect(daemon.registers, 1);
      expect(daemon.state, MacDaemonState.requiresApproval);
    });

    test('launch adds the daemon without opening System Settings', () async {
      final daemon = FakeDaemon(MacDaemonState.notRegistered);
      await DesktopTunnel(daemon: daemon).prepareService();
      expect(daemon.registers, 1);
      expect(daemon.settingsOpened, 0);
      // Already added: nothing more.
      await DesktopTunnel(daemon: daemon).prepareService();
      expect(daemon.registers, 1);
    });

    test(
      'an allowed daemon launchd is still starting gets the connect',
      () async {
        service = await FakeService.start(
          (m, p) => {'seq': 1, 'state': 'connecting'},
        );
        final daemon = FakeDaemon(MacDaemonState.enabled);
        final tunnel = DesktopTunnel(
          pipe: LatePipe(UnixSocketPipe(service!.path), 2),
          daemon: daemon,
        );
        await tunnel.method.invokeMethod('connect', {'link': 'vless://a'});
        expect(service!.requests.single['method'], 'connect');
        expect(daemon.registers, 0);
        expect(daemon.settingsOpened, 0);
      },
    );

    test('a daemon that never answers is said so, after a wait', () async {
      service = await FakeService.start((m, p) => null);
      final tunnel = DesktopTunnel(
        pipe: UnixSocketPipe('${service!.path}-missing'),
        daemon: FakeDaemon(MacDaemonState.enabled),
        daemonStartWait: const Duration(milliseconds: 700),
      );
      await expectLater(
        tunnel.method.invokeMethod('connect', {'link': 'vless://a'}),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', TunnelCallException.unavailable)
              .having(
                (e) => e.message,
                'message',
                contains('Quit Fortiva VPN'),
              ),
        ),
      );
    });

    test('diagnostics say where the daemon is', () async {
      service = await FakeService.start((m, p) => null);
      final tunnel = DesktopTunnel(
        pipe: UnixSocketPipe('${service!.path}-missing'),
        daemon: FakeDaemon(MacDaemonState.requiresApproval),
      );
      expect(await tunnel.method.invokeMethod('diagnostics'), {
        'tunnel_service': 'not_running',
        'daemon': 'requiresApproval',
      });
    });

    test('the native side\'s names', () {
      expect(MacDaemon.stateOf('enabled'), MacDaemonState.enabled);
      expect(
        MacDaemon.stateOf('requiresApproval'),
        MacDaemonState.requiresApproval,
      );
      expect(MacDaemon.stateOf('notRegistered'), MacDaemonState.notRegistered);
      expect(MacDaemon.stateOf('notFound'), MacDaemonState.notFound);
      expect(MacDaemon.stateOf(null), MacDaemonState.unknown);
    });
  });

  test('the install id is the Mac\'s IOPlatformUUID', () {
    const ioreg = '''
+-o J314sAP  <class IOPlatformExpertDevice, id 0x100000256, registered>
    {
      "IOPlatformSerialNumber" = "XXXXXXXXXX"
      "IOPlatformUUID" = "0A1B2C3D-4E5F-6071-8293-A4B5C6D7E8F9"
    }
''';
    expect(
      DesktopTunnel.platformUuidOf(ioreg),
      '0A1B2C3D-4E5F-6071-8293-A4B5C6D7E8F9',
    );
    expect(DesktopTunnel.platformUuidOf('no such line'), isNull);
  });

  test('under test macOS is no desktop client unless a test says so', () {
    expect(DesktopCore.isMacOS, isFalse);
    DesktopCore.macOSForTest = true;
    addTearDown(() => DesktopCore.macOSForTest = null);
    expect(DesktopCore.isMacOS, isTrue);
    expect(DesktopCore.active, isTrue);
  });

  test('the backend\'s macOS update rules are read, and kept', () {
    final rules = ForceUpdate.fromJson({
      'ios': {
        'latest_version': '1.0.0',
        'minimum_version': '1.0.0',
        'update_url': 'u',
      },
      'android': {
        'latest_version': '2.4.1',
        'minimum_version': '2.0.0',
        'update_url': 'u',
      },
      'macos': {
        'latest_version': '2.5.0',
        'minimum_version': '2.5.0',
        'update_url': 'https://fortivavpn.com/macos',
      },
    });
    expect(rules.macos?.latestVersion, '2.5.0');
    expect(rules.windows, isNull);
    expect(rules.toJson()['macos'], isNotNull);
    expect(
      ForceUpdate.fromJson({
        'ios': {
          'latest_version': '1.0.0',
          'minimum_version': '1.0.0',
          'update_url': 'u',
        },
        'android': {
          'latest_version': '2.4.1',
          'minimum_version': '2.0.0',
          'update_url': 'u',
        },
      }).macos,
      isNull,
    );
  });
}
