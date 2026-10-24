import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/services/door_sweep.dart';
import 'package:fortiva_vpn/services/link_facts.dart';
import 'package:fortiva_vpn/services/path_finder.dart';
import 'package:fortiva_vpn/services/ping_service.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A failed door check used to reach the backend as "tcp ok 84ms; EOF" and
/// nothing else, so a cut handshake, a slow server and a small MTU all read
/// the same. Each check now also says how far it got (phase), how long the
/// bare TCP connect took (tcp_ms), and what the phone's line says about
/// itself (link_mtu, private_dns, transport).
Server door(String host, String door) => Server(
  id: 'dedicated-$host:443',
  name: host,
  country: '',
  city: host,
  connectionUri:
      'vless://00000000-0000-0000-0000-000000000000@$host:443'
      '?type=ws&security=tls&sni=cdn.example.site#$host',
  flagEmoji: '🌍',
  isDedicated: true,
  door: door,
  doorLabel: door,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final cdn = door('198.51.100.215', 'ws-tls');

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => messenger.setMockMethodCallHandler(tunnel, null));

  group('what the native check says', () {
    test('an open door, with the connect time when it was in', () {
      final r = PingService.readingOf({
        'ms': 212,
        'tcp': 'ok',
        'tcpMs': 61,
        'elapsedMs': 230,
      });
      expect(r.open, isTrue);
      expect(r.ms, 212);
      expect(r.phase, 'ok');
      expect(r.tcpMs, 61);
      expect(r.error, isNull);
    });

    test('an open door whose connect was not in yet has no connect time', () {
      final r = PingService.readingOf({'ms': 212, 'elapsedMs': 230});
      expect(r.phase, 'ok');
      expect(r.tcpMs, isNull);
    });

    test('an address that takes no TCP connection stops at tcp', () {
      final r = PingService.readingOf({
        'ms': -1,
        'tcp': 'timeout',
        'tcpMs': 2500,
        'error': 'no answer in 3000 ms',
      });
      expect(r.open, isFalse);
      expect(r.phase, 'tcp');
      // A failed connect has no connect time; how it failed is in the error.
      expect(r.tcpMs, isNull);
      expect(r.error, 'tcp timeout; no answer in 3000 ms');
    });

    test('an open address, then nothing, cannot say which step stopped', () {
      final r = PingService.readingOf({
        'ms': -1,
        'tcp': 'ok',
        'tcpMs': 84,
        'error': 'EOF',
      });
      expect(r.phase, isNull);
      expect(r.tcpMs, 84);
      expect(r.error, 'tcp ok 84ms; EOF');
    });

    for (final error in [
      'remote error: tls: handshake failure',
      'tls: first record does not look like a TLS handshake',
      'x509: certificate signed by unknown authority',
      'REALITY: received real certificate (potential MITM or redirection)',
    ]) {
      test('"$error" stops at tls', () {
        final r = PingService.readingOf({
          'ms': -1,
          'tcp': 'ok',
          'tcpMs': 90,
          'error': error,
        });
        expect(r.phase, 'tls');
        expect(r.tcpMs, 90);
      });
    }

    test('a handshake error with no TCP reading still stops at tls', () {
      expect(
        PingService.readingOf({
          'ms': -1,
          'error': 'remote error: tls: bad record MAC',
        }).phase,
        'tls',
      );
    });

    test('a failed TCP connect wins over the core\'s words', () {
      expect(
        PingService.readingOf({
          'ms': -1,
          'tcp': 'reset',
          'tcpMs': 40,
          'error': 'tls: handshake failure',
        }).phase,
        'tcp',
      );
    });
  });

  group('readDoor', () {
    test('carries the phase and connect time from the native side', () async {
      messenger.setMockMethodCallHandler(tunnel, (call) async {
        expect(call.method, 'realPingDetail');
        return {'ms': -1, 'tcp': 'ok', 'tcpMs': 91, 'error': 'EOF'};
      });
      final r = await PingService().readDoor(cdn);
      expect(r.open, isFalse);
      expect(r.tcpMs, 91);
      expect(r.error, 'tcp ok 91ms; EOF');
    });

    test('checkDoor still throws the same reason', () async {
      messenger.setMockMethodCallHandler(tunnel, (call) async {
        return {'ms': -1, 'tcp': 'ok', 'tcpMs': 91, 'error': 'EOF'};
      });
      await expectLater(
        PingService().checkDoor(cdn),
        throwsA(
          isA<DoorCheckFailed>().having(
            (e) => e.reason,
            'reason',
            'tcp ok 91ms; EOF',
          ),
        ),
      );
    });
  });

  group('the checklist and the sweep keep it', () {
    Future<DoorOutcome> read(Server _) async =>
        const DoorOutcome(ms: -1, error: 'tcp ok 84ms; EOF', tcpMs: 84);

    test('a checklist row', () async {
      final finder = PathFinder(read: read, internet: () async => true);
      final check = (await finder.find([cdn])).checks.single;
      expect(check.state, PathCheckState.blocked);
      expect(check.error, 'tcp ok 84ms; EOF');
      expect(check.tcpMs, 84);
      expect(check.phase, isNull);
    });

    test('an open checklist row has its phase and no error', () async {
      final finder = PathFinder(
        read: (_) async => const DoorOutcome(ms: 150, tcpMs: 40, phase: 'ok'),
        internet: () async => true,
      );
      final check = (await finder.find([cdn])).checks.single;
      expect(check.state, PathCheckState.open);
      expect(check.ms, 150);
      expect(check.phase, 'ok');
      expect(check.tcpMs, 40);
      expect(check.error, isNull);
    });

    test('a swept door', () async {
      final sweep = DoorSweep(read: read, appBypassesTunnel: true);
      final result = (await sweep.probeAll([cdn])).single;
      expect(result.ok, isFalse);
      expect(result.tcpMs, 84);
      expect(result.error, 'tcp ok 84ms; EOF');
    });
  });

  group('the rows the backend gets', () {
    late List<Map<String, dynamic>> probes;

    VpnEventReporter reporter(Map<String, Object> link) => VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, p, _) async => probes = p,
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.6.18',
      platform: 'android',
      networkType: () async => 'wifi',
      linkFacts: () async => link,
      queues: const [],
    );

    test('carry the new fields when the phone knows them', () async {
      await reporter({
        'link_mtu': 1500,
        'private_dns': 'off',
        'transport': 'wifi',
      }).recordProbes(const [
        ProbeResult(door: 'xhttp-reality', ok: false, tcpMs: 84),
        ProbeResult(door: 'tcp-reality', ok: false, phase: 'tcp'),
        ProbeResult(door: 'ws-tls', ok: true, ms: 212, tcpMs: 61, phase: 'ok'),
      ]);
      expect(probes[0]['tcp_ms'], 84);
      expect(probes[0].containsKey('phase'), isFalse);
      expect(probes[1]['phase'], 'tcp');
      expect(probes[1].containsKey('tcp_ms'), isFalse);
      expect(probes[2]['phase'], 'ok');
      expect(probes[2]['tcp_ms'], 61);
      for (final p in probes) {
        expect(p['link_mtu'], 1500);
        expect(p['private_dns'], 'off');
        expect(p['transport'], 'wifi');
      }
    });

    // What the new fields cost a closed tap, which goes in uploads under
    // 1 KB. The rows here are about the median closed-tap row of 1.6.13
    // (411 bytes, 7 days to 2026-10-07), and 7 is the median tap. Two such
    // rows fitted in one upload; with the new fields one does. Each piece
    // is enough for the stuck rule on its own, so the first upload that
    // gets out says as much as before, but the whole tap takes more
    // uploads. If this changes, the cost changed.
    test('a median closed tap goes from 4 uploads to 7', () async {
      Future<List<List<Map<String, dynamic>>>> tap({required bool detail}) {
        final pieces = <List<Map<String, dynamic>>>[];
        final r = VpnEventReporter(
          send: (_, _, _) async {},
          sendProbes: (_, p, _) async => pieces.add(p),
          deviceId: () async => 'DEV-1',
          appVersion: () async => '1.6.13',
          platform: 'android',
          networkType: () async => 'wifi',
          linkFacts: () async => detail
              ? const {
                  'link_mtu': 1500,
                  'private_dns': 'opportunistic',
                  'transport': 'wifi',
                }
              : const {},
          queues: const [],
        );
        return r
            .recordProbes(
              [
                for (var i = 0; i < 7; i++)
                  ProbeResult(
                    door: 'xhttp-reality',
                    ok: false,
                    serverHost: '198.51.100.206',
                    ms: 3012,
                    error: 'tcp ok; no answer in 3000 ms',
                    tcpMs: detail ? 182 : null,
                    phase: detail ? 'tls' : null,
                    strategy: const {
                      'sni': 'www.speedtest.net',
                      'fragment': '100-200,10-20,tlshello',
                      'pbk_prefix': 'AbCdEfGh',
                    },
                  ),
              ],
              carrier: 'TCI',
              attemptId: 'e1691a9e-0c2f-4c1d-9d5e-6b8a4f3e2d10',
            )
            .then((_) => pieces);
      }

      final before = await tap(detail: false);
      final rowBytes = utf8.encode(jsonEncode(before.first.first)).length;
      expect(rowBytes, inInclusiveRange(400, 440), reason: 'a median row');
      expect(before, hasLength(4));

      final after = await tap(detail: true);
      expect(after, hasLength(7));
      for (final piece in after) {
        expect(
          VpnEventReporter.uploadBytes(piece),
          lessThanOrEqualTo(VpnEventReporter.probeUploadBytes),
        );
      }
    });

    test('carry none of them when it does not, as older apps', () async {
      await reporter(
        const {},
      ).recordProbes(const [ProbeResult(door: 'ws-tls', ok: false)]);
      for (final key in [
        'tcp_ms',
        'phase',
        'link_mtu',
        'private_dns',
        'transport',
        // The core exposes neither, so the app never sends them.
        'first_byte_ms',
        'bytes_out',
        'bytes_in',
      ]) {
        expect(probes.single.containsKey(key), isFalse, reason: key);
      }
    });
  });

  group('LinkFacts', () {
    const channel = MethodChannel('test/link_facts');
    late List<String> asked;

    void answer(Object? value) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        asked.add(call.method);
        return value;
      });
    }

    setUp(() => asked = []);
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('keeps what the backend accepts', () async {
      answer({
        'link_mtu': 1280,
        'private_dns': 'strict',
        'transport': 'cellular',
      });
      expect(await LinkFacts(channel: channel, android: true).read(), {
        'link_mtu': 1280,
        'private_dns': 'strict',
        'transport': 'cellular',
      });
      expect(asked, ['linkFacts']);
    });

    test('drops what it would not', () async {
      answer({
        'link_mtu': 0,
        'private_dns': 'hostname',
        'transport': 'vpn',
        'ip': '10.1.2.3',
      });
      expect(await LinkFacts(channel: channel, android: true).read(), isEmpty);
    });

    test('off Android the platform is not asked', () async {
      answer({'link_mtu': 1500});
      expect(await LinkFacts(channel: channel, android: false).read(), isEmpty);
      expect(asked, isEmpty);
    });

    test(
      'a platform without the call, or one that fails, gives none',
      () async {
        // No handler: MissingPluginException.
        expect(
          await LinkFacts(channel: channel, android: true).read(),
          isEmpty,
        );
        messenger.setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: 'boom'),
        );
        expect(
          await LinkFacts(channel: channel, android: true).read(),
          isEmpty,
        );
      },
    );
  });
}
