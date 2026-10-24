import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:fortiva_vpn/data/models/connection_data.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/ping_service.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The core's timed door check (backend issue #365, item 1): the same
/// check, which also says how far it got on the sockets it opened. A
/// failed check used to read the same whether the address never answered,
/// the handshake was cut, or our server replied and the traffic stalled.
Server door(String host, String door) => Server(
  id: 'dedicated-$host:8443',
  name: host,
  country: '',
  city: host,
  connectionUri:
      'vless://00000000-0000-0000-0000-000000000000@$host:8443'
      '?type=xhttp&security=reality&sni=www.samsung.com&pbk=PUBKEY#$host',
  flagEmoji: '',
  isDedicated: true,
  door: door,
  doorLabel: door,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final began = CheckTimeline(began: DateTime(2026, 10, 16, 8));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ConnectionData.current = ConnectionData.off;
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(tunnel, null);
    ConnectionData.current = ConnectionData.off;
  });

  group('what a timed check says', () {
    test('an open door, with its whole timeline', () {
      final r = PingService.readingOf({
        'timed': true,
        'ms': 412,
        'bootMs': 38,
        'coldMs': 690,
        'dialMs': 95,
        'firstByteMs': 181,
        'replyMs': 402,
        'bytesOut': 2210,
        'bytesIn': 6150,
        'dials': 1,
        'dialFails': 0,
        'phase': 'ok',
        'tcp': 'ok',
        'tcpMs': 88,
      }, began: began);
      expect(r.open, isTrue);
      expect(r.phase, 'ok');
      expect(r.tcpMs, 88);
      final t = r.timeline!;
      expect(t.began, began.began);
      expect(
        [t.bootMs, t.coldMs, t.dialMs, t.firstByteMs, t.replyMs],
        [38, 690, 95, 181, 402],
      );
      expect([t.bytesOut, t.bytesIn, t.dials, t.dialFails], [2210, 6150, 1, 0]);
    });

    test('a door whose server answered and then went quiet is "proxy", '
        'even though the plain connect worked', () {
      final r = PingService.readingOf({
        'timed': true,
        'ms': -1,
        'error': 'no answer in 3000 ms',
        'dialMs': 120,
        'firstByteMs': 240,
        'bytesOut': 3100,
        'bytesIn': 4400,
        'dials': 1,
        'dialFails': 0,
        'phase': 'proxy',
        'tcp': 'ok',
        'tcpMs': 110,
      }, began: began);
      expect(r.open, isFalse);
      expect(r.phase, 'proxy');
      expect(r.error, 'tcp ok 110ms; no answer in 3000 ms');
      expect(r.timeline!.firstByteMs, 240);
      expect(r.timeline!.replyMs, isNull);
    });

    test('the name lookup and the TLS handshake come through when the core '
        'measured them', () {
      final r = PingService.readingOf({
        'timed': true,
        'ms': 520,
        'dnsMs': 35,
        'dialMs': 95,
        'firstByteMs': 181,
        'tlsMs': 260,
        'replyMs': 402,
        'phase': 'ok',
      }, began: began);
      expect([r.timeline!.dnsMs, r.timeline!.tlsMs], [35, 260]);
      // A door at an address with no TLS has neither.
      final plain = PingService.readingOf({
        'timed': true,
        'ms': 300,
        'dialMs': 90,
        'phase': 'ok',
      }, began: began);
      expect([plain.timeline!.dnsMs, plain.timeline!.tlsMs], [null, null]);
    });

    test('a reply after the wait is "late"', () {
      final r = PingService.readingOf({
        'timed': true,
        'ms': -1,
        'error': 'no answer in 3000 ms',
        'coldMs': 2600,
        'replyMs': 2450,
        'phase': 'late',
      }, began: began);
      expect(r.phase, 'late');
      expect(r.timeline!.coldMs, 2600);
    });

    test(
      'a phase word the app does not know falls back to the old reading',
      () {
        final r = PingService.readingOf({
          'timed': true,
          'ms': -1,
          'error': 'EOF',
          'phase': 'quantum',
          'tcp': 'timeout',
        }, began: began);
        expect(r.phase, 'tcp');
      },
    );

    test('a plain check keeps only when it began', () {
      final r = PingService.readingOf({
        'ms': -1,
        'error': 'EOF',
        'dialMs': 120,
        'tcp': 'ok',
        'tcpMs': 90,
      }, began: began);
      expect(r.phase, isNull);
      expect(r.timeline!.began, began.began);
      expect(r.timeline!.dialMs, isNull);
    });
  });

  group('asking for one', () {
    Future<Map<dynamic, dynamic>> argsOf() async {
      Map<dynamic, dynamic>? asked;
      messenger.setMockMethodCallHandler(tunnel, (call) async {
        if (call.method == 'realPingDetail') {
          asked = call.arguments as Map<dynamic, dynamic>;
          return {'ms': 300, 'elapsedMs': 310};
        }
        return null;
      });
      final r = await PingService().readDoor(
        door('198.51.100.207', 'xhttp-reality'),
      );
      expect(r.timeline, isNotNull);
      return asked!;
    }

    test('only when the backend turned timed checks on', () async {
      expect((await argsOf()).containsKey('timed'), isFalse);
      ConnectionData.current = ConnectionData.fromJson({'timed_checks': true});
      expect((await argsOf())['timed'], isTrue);
    });

    test(
      'a check the native side never answered still says when it began',
      () async {
        messenger.setMockMethodCallHandler(tunnel, (call) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return null;
        });
        final before = DateTime.now();
        final r = await PingService().readDoor(
          door('198.51.100.207', 'xhttp-reality'),
          timeout: const Duration(milliseconds: 50),
        );
        expect(r.open, isFalse);
        expect(r.timeline!.began.isBefore(before), isFalse);
      },
    );
  });

  group('the rows the backend gets', () {
    late List<List<Map<String, dynamic>>> pieces;

    VpnEventReporter reporter() => VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, p, _) async => pieces.add(p),
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.11.0',
      platform: 'android',
      networkType: () async => 'mobile',
      linkFacts: () async => const {'transport': 'cellular'},
      queues: const [],
    );

    setUp(() => pieces = []);

    test('carry the timeline under the backend\'s names, and when the check '
        'began', () async {
      final now = DateTime.now();
      await reporter().recordProbes([
        ProbeResult(
          door: 'xhttp-reality',
          ok: false,
          phase: 'proxy',
          timeline: CheckTimeline(
            began: now.subtract(const Duration(seconds: 4)),
            bootMs: 41,
            dnsMs: 30,
            dialMs: 120,
            firstByteMs: 240,
            tlsMs: 380,
            bytesOut: 3100,
            bytesIn: 4400,
            dials: 1,
            dialFails: 0,
          ),
        ),
        ProbeResult(
          door: 'tcp-reality',
          ok: false,
          phase: 'tcp',
          timeline: CheckTimeline(began: now),
        ),
        const ProbeResult(door: 'ws-tls', ok: false),
      ]);
      final rows = [for (final p in pieces) ...p];
      final a = rows[0];
      expect(a['phase'], 'proxy');
      expect(a['began_ms'], inInclusiveRange(4000, 6000));
      expect(a['boot_ms'], 41);
      expect(a['dial_ms'], 120);
      expect(a['first_byte_ms'], 240);
      expect(a['dns_ms'], 30);
      expect(a['tls_ms'], 380);
      expect(a['bytes_out'], 3100);
      expect(a['bytes_in'], 4400);
      expect(a['dials'], 1);
      expect(a['dial_fails'], 0);
      expect(a.containsKey('reply_ms'), isFalse);
      expect(a.containsKey('cold_ms'), isFalse);
      expect(rows[1]['began_ms'], inInclusiveRange(0, 2000));
      expect(rows[1].containsKey('dial_ms'), isFalse);
      expect(rows[1].containsKey('dns_ms'), isFalse);
      expect(rows[1].containsKey('tls_ms'), isFalse);
      expect(rows[2].containsKey('began_ms'), isFalse);
      // No address in any of it beyond the server's own host, which the row
      // has always named.
      expect(jsonEncode(rows), isNot(contains('10.0.')));
    });

    // What the timeline costs a closed tap, which goes in uploads under
    // 1 KB: 7 rows (the median tap) of a timed check that failed after the
    // handshake. If this changes, the cost changed.
    test('a timed closed tap of 7 doors fits in 7 uploads', () async {
      final now = DateTime.now();
      await reporter().recordProbes(
        [
          for (var i = 0; i < 7; i++)
            ProbeResult(
              door: 'xhttp-reality',
              ok: false,
              serverHost: '198.51.100.207',
              ms: 3004,
              error: 'tcp ok 110ms; no answer in 3000 ms',
              tcpMs: 110,
              phase: 'proxy',
              strategy: const {
                'sni': 'www.samsung.com',
                'fragment': '1-3',
                'pbk_prefix': 'abcd',
              },
              timeline: CheckTimeline(
                began: now.subtract(const Duration(seconds: 3)),
                bootMs: 41,
                dialMs: 120,
                firstByteMs: 240,
                bytesOut: 3100,
                bytesIn: 4400,
                dials: 1,
                dialFails: 0,
              ),
            ),
        ],
        carrier: 'IR-MCI',
        attemptId: '0123456789abcdef0123456789abcdef',
      );
      expect(pieces.length, 7);
      for (final p in pieces) {
        expect(
          utf8.encode(jsonEncode(p)).length,
          lessThanOrEqualTo(VpnEventReporter.probeUploadBytes),
        );
      }
    });
  });

  group('a run that started without timed checks', () {
    late List<String> asked;
    setUp(() {
      asked = [];
      messenger.setMockMethodCallHandler(tunnel, (call) async {
        asked.add(call.method);
        return null;
      });
    });
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('asks Android for them as soon as the settings want them', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await AppConfigState.askForTimedChecks(
        const ConnectionData(timedChecks: true),
      );
      expect(asked, ['prepareTimedChecks']);
    });

    test(
      'asks nothing when the settings do not want them, or off Android',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        await AppConfigState.askForTimedChecks(
          const ConnectionData(networkKeys: true),
        );
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        await AppConfigState.askForTimedChecks(
          const ConnectionData(timedChecks: true),
        );
        expect(asked, isEmpty);
      },
    );

    test('a platform that cannot answer costs nothing', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      messenger.setMockMethodCallHandler(tunnel, (call) async {
        throw PlatformException(code: 'nope');
      });
      await AppConfigState.askForTimedChecks(
        const ConnectionData(timedChecks: true),
      );
    });
  });
}
