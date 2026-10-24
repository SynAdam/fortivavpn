import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<List<Map<String, dynamic>>> sent;
  late List<bool> sentViaTunnel;
  late bool failSends;

  VpnEventReporter reporter({String? network = 'mobile'}) => VpnEventReporter(
    send: (deviceId, events, viaTunnel) async {
      if (failSends) throw Exception('offline');
      expect(deviceId, 'DEV-1');
      sent.add(events);
      sentViaTunnel.add(viaTunnel);
    },
    deviceId: () async => 'DEV-1',
    appVersion: () async => '1.3.0',
    platform: 'android',
    osVersion: '14',
    networkType: () async => network,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sent = [];
    sentViaTunnel = [];
    failSends = false;
  });

  test('records the wire shape and sends it', () async {
    final r = reporter();
    await r.record(
      VpnEventType.dropped,
      serverHost: '198.51.100.202',
      duration: const Duration(minutes: 30, seconds: 20),
    );
    await r.flush();
    expect(sent, hasLength(1));
    final e = sent.single.single;
    expect(e['type'], 'dropped');
    expect(e['server_host'], '198.51.100.202');
    expect(e['duration_seconds'], 1820);
    expect(e['app_version'], '1.3.0');
    expect(e['platform'], 'android');
    expect(e['os_version'], '14');
    expect(e['client_ts'], endsWith('Z'));
    expect(e.containsKey('error'), isFalse);
    expect(await r.pending(), 0);
  });

  test('carries carrier, network type and the diagnosis', () async {
    final r = reporter();
    await r.record(
      VpnEventType.verifyFailed,
      error: 'Server not working',
      diag: {
        'carrier': 'Irancell',
        'network': 'mobile',
        'tcp': 'ok',
        'tls': 'reset',
      },
    );
    await r.flush();
    final e = sent.single.single;
    expect(e['carrier'], 'Irancell');
    expect(e['network_type'], 'mobile');
    expect(e['diag'], containsPair('tls', 'reset'));
  });

  // The keys and typical values of a verify_failed diagnosis on 1.6.13,
  // from production rows of 2026-10-07. At the median (245 events over the
  // two days to 2026-10-07) the diagnosis had 6,748 characters and its
  // core_log about 6,000 of them.
  Map<String, dynamic> failureDiag() => {
    'core_log': 'x' * 6000,
    'timeline': {'started': 120, 'connected': 940},
    'carrier': 'TCI',
    'sim_carrier': 'IR-MCI',
    'sim_country': 'ir',
    'roaming': false,
    'network': 'wifi',
    'device': 'samsung SM-A515F',
    'sdk_int': 33,
    'resolver': 'system',
    'dns': 'ok',
    'dns_ms': 41,
    'tcp': 'timeout',
    'tcp_ms': 5001,
    'tcp_error':
        'SocketException: Connection timed out (OS Error: Connection timed '
        'out, errno = 110), address = 198.51.100.206, port = 443',
    'tls': 'skipped',
    'control': 'ok',
    'control_ms': 312,
    'control_url': 'http://connectivitycheck.gstatic.com/generate_204',
    'diag_ms': 5480,
    'through_vpn': false,
    'validated': true,
    'metered': false,
    'down_kbps': 30000,
    'private_dns': 'off',
    'vpn_permission': true,
    'data_saver': false,
    'power_save': false,
    'battery_optimized': true,
    'background_restricted': false,
  };

  test('a failure event leaves the core log on the phone', () async {
    final r = reporter(network: 'wifi');
    for (final type in [
      VpnEventType.connectFailed,
      VpnEventType.verifyFailed,
    ]) {
      sent.clear();
      await r.record(
        type,
        serverHost: '198.51.100.206',
        door: 'xhttp-reality',
        attemptId: 'e1691a9e-0c2f-4c1d-9d5e-6b8a4f3e2d10',
        strategy: const {
          'transport': 'xhttp',
          'security': 'reality',
          'port': 443,
          'sni': 'www.example.org',
          'fp': 'chrome',
          'path': '/xh',
          'mode': 'auto',
          'pbk_prefix': 'AbCdEfGh',
        },
        error: 'Server not working, try another',
        diag: failureDiag(),
      );
      await r.flush();
      final e = sent.single.single;
      final diag = e['diag'] as Map<String, dynamic>;
      expect(diag.containsKey('core_log'), isFalse, reason: type.wire);
      // What the backend reads from a failure: the verdict's fields and
      // the place. The timeline stays, at about 20 characters.
      for (final key in [
        'control',
        'vpn_permission',
        'dns',
        'tcp',
        'tls',
        'sim_country',
        'roaming',
        'timeline',
      ]) {
        expect(diag.containsKey(key), isTrue, reason: '${type.wire} $key');
      }
      final size = utf8.encode(jsonEncode(e)).length;
      final before =
          size + utf8.encode(jsonEncode({'core_log': 'x' * 6000})).length;
      // ignore: avoid_print
      print('${type.wire} event: $size bytes, was about $before');
      expect(size, lessThan(1200), reason: type.wire);
    }
  });

  test(
    'a failure whose diagnosis holds only a core log sends no diag',
    () async {
      final r = reporter();
      await r.record(VpnEventType.verifyFailed, diag: {'core_log': 'tail'});
      await r.flush();
      expect(sent.single.single.containsKey('diag'), isFalse);
    },
  );

  // The team reads the core log by hand, for lines such as this one.
  test('every event but a failure keeps the core log', () async {
    const log =
        '10-11 09:16:12.355 I/GoLog   ( 4242): [Info] [1406141838] '
        'app/proxyman/inbound: connection ends > io: read/write on closed pipe';
    final r = reporter();
    for (final type in VpnEventType.values) {
      sent.clear();
      await r.record(type, diag: {'core_log': log, 'dns': 'ok'});
      await r.flush();
      final diag = sent.single.single['diag'] as Map<String, dynamic>;
      final failure =
          type == VpnEventType.connectFailed ||
          type == VpnEventType.verifyFailed;
      expect(diag['core_log'], failure ? isNull : log, reason: type.wire);
      expect(diag['dns'], 'ok', reason: type.wire);
    }
  });

  // Until 1.6.21 a connected event carried one "sniffed domain: <host>"
  // line for each connection in the minutes before it (issue #244).
  test('no event sends a log line that names a site', () async {
    const log =
        '10-11 09:16:12.345 I/GoLog   ( 4242): [Info] [1] app/dispatcher: '
        'sniffed domain: example.com\n'
        '10-11 09:16:12.346 I/GoLog   ( 4242): from tcp:127.0.0.1:43210 '
        'accepted tcp:example.com:443 [socks -> proxy]\n'
        '10-11 09:16:12.347 I/GoLog   ( 4242): [Info] [1] proxy/socks: TCP '
        'Connect request to tcp:203.0.113.7:443\n'
        '10-11 09:16:12.355 I/GoLog   ( 4242): [Warning] core: Xray 26.8.20 '
        'started\n';
    final r = reporter();
    for (final type in VpnEventType.values) {
      sent.clear();
      await r.record(type, diag: {'core_log': log, 'dns': 'ok'});
      await r.flush();
      final event = sent.single.single;
      final text = jsonEncode(event);
      expect(text, isNot(contains('example.com')), reason: type.wire);
      expect(text, isNot(contains('203.0.113.7')), reason: type.wire);
      final diag = event['diag'] as Map<String, dynamic>;
      final failure =
          type == VpnEventType.connectFailed ||
          type == VpnEventType.verifyFailed;
      if (failure) continue;
      final sentLog = diag['core_log'] as String;
      expect(sentLog, contains('Xray 26.8.20 started'), reason: type.wire);
      expect(sentLog, endsWith('were left out before sending.'));
    }
  });

  test('a heartbeat carries its bytes at the top level', () async {
    final r = reporter();
    await r.record(
      VpnEventType.heartbeat,
      serverHost: '198.51.100.202',
      duration: const Duration(minutes: 25),
      bytesUp: 184320,
      bytesDown: 2097152,
      diag: {'carrier': 'Irancell', 'network': 'mobile'},
    );
    await r.flush();
    final e = sent.single.single;
    expect(e['type'], 'heartbeat');
    expect(e['bytes_up'], 184320);
    expect(e['bytes_down'], 2097152);
    expect(e['duration_seconds'], 1500);
    // The stall rule needs the carrier, and the backend cannot read it from
    // the address a batch arrives on while the tunnel is up.
    expect(e['carrier'], 'Irancell');
  });

  test('a beat that moved nothing says so rather than omitting it', () async {
    final r = reporter();
    await r.record(VpnEventType.heartbeat, bytesUp: 0, bytesDown: 0);
    await r.flush();
    final e = sent.single.single;
    expect(e['bytes_up'], 0);
    expect(e['bytes_down'], 0);
  });

  test('every other event type leaves the byte fields off', () async {
    final r = reporter();
    await r.record(VpnEventType.dropped, error: 'killed');
    await r.flush();
    final e = sent.single.single;
    expect(e.containsKey('bytes_up'), isFalse);
    expect(e.containsKey('bytes_down'), isFalse);
  });

  test('records nothing when the user turned sharing off', () async {
    SharedPreferences.setMockInitialValues({
      VpnEventReporter.sharePrefKey: false,
    });
    final r = reporter();
    await r.record(VpnEventType.dropped);
    await r.flush();
    expect(sent, isEmpty);
    expect(await r.pending(), 0);
  });

  test('keeps the queue when offline and sends it later', () async {
    failSends = true;
    final r = reporter();
    await r.record(VpnEventType.connectFailed, error: 'tunnel did not start');
    await r.record(VpnEventType.verifyFailed);
    await r.flush();
    expect(sent, isEmpty);
    expect(await r.pending(), 2);

    failSends = false;
    await r.flush();
    expect(sent.single.map((e) => e['type']), [
      'connect_failed',
      'verify_failed',
    ]);
    expect(await r.pending(), 0);
  });

  test('flushes in backend-sized batches, oldest first', () async {
    failSends = true;
    final r = reporter();
    for (var i = 0; i < 120; i++) {
      await r.record(VpnEventType.connected, error: 'n$i');
    }
    failSends = false;
    await r.flush();
    expect(sent.map((b) => b.length), [50, 50, 20]);
    expect(sent.first.first['error'], 'n0');
    expect(sent.last.last['error'], 'n119');
  });

  test(
    'caps the queue so a long offline stretch cannot grow it forever',
    () async {
      failSends = true;
      final r = reporter();
      for (var i = 0; i < VpnEventReporter.maxQueued + 25; i++) {
        await r.record(VpnEventType.dropped, error: 'n$i');
      }
      expect(await r.pending(), VpnEventReporter.maxQueued);
      failSends = false;
      await r.flush();
      expect(sent.first.first['error'], 'n25'); // the oldest were dropped
    },
  );

  test('a failed batch leaves the remainder queued', () async {
    failSends = true;
    final r = reporter();
    for (var i = 0; i < 60; i++) {
      await r.record(VpnEventType.disconnected);
    }
    var calls = 0;
    final flaky = VpnEventReporter(
      send: (_, events, _) async {
        calls++;
        if (calls == 2) throw Exception('blip');
        sent.add(events);
      },
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.3.0',
      platform: 'android',
      osVersion: '14',
      networkType: () async => 'mobile',
    );
    await flaky.flush();
    expect(sent.map((b) => b.length), [50]);
    expect(await flaky.pending(), 10);
  });

  // An event recorded while a batch is in flight joins that run. When the
  // batch then fails, for example on the network the phone has just left,
  // the run goes round again rather than leave the new event for the next
  // try.
  test(
    'an event recorded during a failed batch goes in the same run',
    () async {
      final gate = Completer<void>();
      var calls = 0;
      final r = VpnEventReporter(
        send: (_, events, _) async {
          calls++;
          if (calls == 1) {
            await gate.future;
            throw Exception('cut on the old network');
          }
          sent.add(events);
        },
        sendProbes: (_, _, _) async {},
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.13',
        platform: 'android',
        networkType: () async => 'mobile',
      );
      SharedPreferences.setMockInitialValues({
        VpnEventReporter.storageKey: jsonEncode([
          {'type': 'verify_failed', 'app_version': '1.6.13'},
        ]),
      });
      final flushing = r.flush();
      await pumpEventQueue();
      expect(calls, 1);
      await r.record(VpnEventType.connected);
      await pumpEventQueue();
      gate.complete();
      await flushing;
      expect(sent.single.map((e) => e['type']), ['verify_failed', 'connected']);
      expect(await r.pending(), 0);
    },
  );

  test('an events run stops after maxRounds rounds', () async {
    var sends = 0;
    late final VpnEventReporter r;
    r = VpnEventReporter(
      send: (_, _, _) async {
        sends++;
        // A new event while every batch fails. Capped, so a run that did
        // not stop fails the test instead of hanging it.
        if (sends < 10) {
          unawaited(r.record(VpnEventType.heartbeat, bytesUp: 0));
          await pumpEventQueue();
        }
        throw Exception('offline');
      },
      sendProbes: (_, _, _) async {},
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.6.13',
      platform: 'android',
      networkType: () async => 'mobile',
    );
    SharedPreferences.setMockInitialValues({
      VpnEventReporter.storageKey: jsonEncode([
        {'type': 'verify_failed', 'app_version': '1.6.13'},
      ]),
    });
    await r.flush();
    expect(sends, VpnEventReporter.maxRounds);
    expect(await r.pending(), 1 + VpnEventReporter.maxRounds);
  });

  test('records the network the phone was on', () async {
    final r = reporter(network: 'wifi');
    await r.record(VpnEventType.connectFailed);
    await r.flush();
    expect(sent.single.single['network_type'], 'wifi');
  });

  test('leaves network_type out when connectivity cannot be read', () async {
    final r = reporter(network: null);
    await r.record(VpnEventType.connectFailed);
    await r.flush();
    expect(sent.single.single.containsKey('network_type'), isFalse);
  });

  test('reports a batch sent outside the tunnel as such', () async {
    final r = reporter()..reportsGoThroughTunnel = () => false;
    await r.record(VpnEventType.connectFailed);
    await r.flush();
    expect(sentViaTunnel, [false]);
  });

  test('reports a batch sent through the tunnel as such', () async {
    final r = reporter()..reportsGoThroughTunnel = () => true;
    await r.record(VpnEventType.connected);
    await r.flush();
    expect(sentViaTunnel, [true]);
  });

  test('assumes the tunnel is up when nothing has said otherwise', () async {
    // The conservative reading: the backend then declines to attribute the
    // carrier rather than blaming our own exit server's network.
    final r = reporter();
    await r.record(VpnEventType.connectFailed);
    await r.flush();
    expect(sentViaTunnel, [true]);
  });
  test('carries the door the link went through', () async {
    final r = reporter();
    await r.record(
      VpnEventType.connected,
      serverHost: '198.51.100.202',
      door: 'xhttp-reality',
    );
    await r.flush();
    expect(sent.single.single['door'], 'xhttp-reality');
  });

  test(
    'sends a diagnosis as one probe batch, and keeps nothing once sent',
    () async {
      late List<Map<String, dynamic>> probes;
      late bool viaTunnel;
      final r = VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (deviceId, p, via) async {
          expect(deviceId, 'DEV-1');
          probes = p;
          viaTunnel = via;
        },
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.5.0',
        platform: 'android',
        networkType: () async => 'mobile',
      );
      r.reportsGoThroughTunnel = () => false;

      await r.recordProbes(const [
        ProbeResult(door: 'tcp-reality', ok: false, serverHost: 'hel'),
        ProbeResult(
          door: 'xhttp-reality',
          ok: true,
          serverHost: 'hel',
          ms: 210,
        ),
      ], carrier: 'Irancell');

      expect(viaTunnel, isFalse);
      expect(probes, hasLength(2));
      expect(probes[0]['door'], 'tcp-reality');
      expect(probes[0]['ok'], isFalse);
      expect(probes[0].containsKey('ms'), isFalse);
      expect(probes[1]['ms'], 210);
      expect(probes[1]['carrier'], 'Irancell');
      expect(probes[1]['network_type'], 'mobile');
      expect(probes[1]['app_version'], '1.5.0');
      expect(probes[1]['client_ts'], endsWith('Z'));
      expect(await r.pending(), 0);
    },
  );

  test(
    'a probe carries the settings that change on the phone, and none when unknown',
    () async {
      late List<Map<String, dynamic>> probes;
      final r = VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, p, _) async => probes = p,
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.9',
        platform: 'android',
        networkType: () async => 'wifi',
      );

      await r.recordProbes(const [
        ProbeResult(
          door: 'ws-tls',
          ok: false,
          strategy: {
            'transport': 'ws',
            'security': 'tls',
            'port': 443,
            'fp': 'chrome',
            'path': '/ws',
            'sni': 'cdn.example.com',
            'host': 'cdn.example.com',
            'fragment': 'tlshello,10-20,1-2',
          },
        ),
        ProbeResult(
          door: 'xhttp-reality',
          ok: false,
          strategy: {
            'transport': 'xhttp',
            'security': 'reality',
            'sni': 'www.example.org',
            'host': 'edge.example.net',
            'pbk_prefix': 'AbCdEfGh',
            'mode': 'auto',
          },
        ),
        ProbeResult(door: 'tcp-reality', ok: true),
      ]);

      // The door fixes transport, security, port, fingerprint and path.
      // A host that repeats the sni is left out: the backend reads host
      // first and sni after it.
      expect(probes[0]['strategy'], {
        'sni': 'cdn.example.com',
        'fragment': 'tlshello,10-20,1-2',
      });
      expect(probes[1]['strategy'], {
        'host': 'edge.example.net',
        'sni': 'www.example.org',
        'pbk_prefix': 'AbCdEfGh',
      });
      expect(probes[2].containsKey('strategy'), isFalse);
    },
  );

  test('a test point keeps every setting it dialled with', () async {
    late List<Map<String, dynamic>> probes;
    final r = VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, p, _) async => probes = p,
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.6.13',
      platform: 'android',
      networkType: () async => 'mobile',
    );
    const strategy = {
      'transport': 'ws',
      'security': 'tls',
      'port': 443,
      'fp': 'chrome',
      'path': '/ws',
      'mode': 'auto',
      'sni': 'cdn.example.com',
      'host': 'cdn.example.com',
      'fragment': 'tlshello,1-3,1-2',
    };
    // Both kinds of test point row: the timed check of every door, and the
    // split users do not get.
    for (final source in [ProbeSource.testpoint, ProbeSource.experiment]) {
      await r.recordProbes(const [
        ProbeResult(door: 'ws-tls', ok: false, strategy: strategy),
      ], source: source);
      expect(probes.single['source'], source.wire);
      expect(probes.single['strategy'], strategy, reason: source.wire);
    }
  });

  test(
    'probes respect the diagnostics switch and survive a failed send',
    () async {
      var sends = 0;
      final r = VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, _, _) async {
          sends++;
          throw Exception('offline');
        },
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.5.0',
        platform: 'android',
        networkType: () async => 'mobile',
      );
      await r.recordProbes(const [ProbeResult(door: 'ws-tls', ok: true)]);
      expect(sends, 1);

      SharedPreferences.setMockInitialValues({
        VpnEventReporter.sharePrefKey: false,
      });
      await r.recordProbes(const [ProbeResult(door: 'ws-tls', ok: true)]);
      expect(sends, 1);
    },
  );

  group('the diagnostics switch', () {
    // Queues an event and a door check that could not be sent.
    Future<VpnEventReporter> queued() async {
      final r = VpnEventReporter(
        send: (_, events, _) async {
          if (failSends) throw Exception('offline');
          sent.add(events);
        },
        sendProbes: (_, p, _) async {
          if (failSends) throw Exception('offline');
          sent.add(p);
        },
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.13',
        platform: 'android',
        networkType: () async => 'wifi',
      );
      failSends = true;
      await r.record(VpnEventType.verifyFailed);
      await r.recordProbes(const [ProbeResult(door: 'ws-tls', ok: false)]);
      await r.flush();
      expect(await r.pending(), 1);
      expect(await r.pendingProbeBatches(), 1);
      failSends = false;
      return r;
    }

    test('turned off drops every report waiting on the phone', () async {
      final r = await queued();
      await VpnEventReporter.setSharing(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(VpnEventReporter.sharePrefKey), isFalse);
      expect(await r.pending(), 0);
      expect(await r.pendingProbeBatches(), 0);
      await r.flush();
      expect(sent, isEmpty);
    });

    test('turned on keeps what is waiting', () async {
      final r = await queued();
      await VpnEventReporter.setSharing(true);
      expect(await r.pending(), 1);
      expect(await r.pendingProbeBatches(), 1);
      await r.flush();
      expect(sent, hasLength(2));
    });

    test('is read again at every flush', () async {
      final r = await queued();
      // Turned off without the settings screen's call, for example by a
      // record that read the switch just before it changed.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(VpnEventReporter.sharePrefKey, false);
      await r.flush();
      expect(sent, isEmpty);
      expect(await r.pending(), 0);
      expect(await r.pendingProbeBatches(), 0);
    });

    test('turned off during a send stops the rest of that run', () async {
      final gate = Completer<void>();
      final probes = <List<Map<String, dynamic>>>[];
      final r = VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, p, _) async {
          if (probes.isEmpty) await gate.future;
          probes.add(p);
        },
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.13',
        platform: 'android',
        networkType: () async => 'wifi',
      );
      final prefs = await SharedPreferences.getInstance();
      // Two taps queued, then a flush whose first upload is held.
      await prefs.setString(
        VpnEventReporter.probeStorageKey,
        jsonEncode([
          for (final door in ['ws-tls', 'xhttp-reality'])
            {
              'queued_at': DateTime.now().toUtc().toIso8601String(),
              'all_closed': true,
              'via_tunnel': false,
              'probes': [
                {'door': door, 'ok': false},
              ],
            },
        ]),
      );
      final flushing = r.flush();
      await pumpEventQueue();
      await prefs.setBool(VpnEventReporter.sharePrefKey, false);
      gate.complete();
      await flushing;
      // The upload already on its way finishes; nothing after it goes.
      expect(probes.single.single['door'], 'ws-tls');
      expect(await r.pendingProbeBatches(), 0);
    });
  });

  group('a device the backend has never seen', () {
    ApiException notFound() =>
        ApiException(statusCode: 404, message: 'Device not found');

    test('a batch answered 404 registers the device and goes again', () async {
      var registered = false;
      final batches = <List<Map<String, dynamic>>>[];
      final r = VpnEventReporter(
        send: (_, events, _) async {
          if (!registered) throw notFound();
          batches.add(events);
        },
        register: () async => registered = true,
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.11',
        platform: 'android',
        networkType: () async => 'mobile',
      );
      await r.record(VpnEventType.connectFailed, error: 'tls cut');
      await r.flush();
      expect(registered, isTrue);
      expect(batches.single.single['type'], 'connect_failed');
      expect(await r.pending(), 0);
    });

    test('a 404 that registering cannot fix keeps the queue', () async {
      var sends = 0;
      var registers = 0;
      final r = VpnEventReporter(
        send: (_, _, _) async {
          sends++;
          throw notFound();
        },
        register: () async {
          registers++;
          throw ApiException(statusCode: 0, message: 'No internet connection');
        },
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.11',
        platform: 'android',
        networkType: () async => 'mobile',
      );
      await r.record(VpnEventType.connectFailed);
      await r.flush();
      expect(registers, 1);
      expect(sends, 1);
      expect(await r.pending(), 1);
    });

    test('door checks answered 404 register the device and go again', () async {
      var registered = false;
      final sent = <List<Map<String, dynamic>>>[];
      final r = VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, p, _) async {
          if (!registered) throw notFound();
          sent.add(p);
        },
        register: () async => registered = true,
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.11',
        platform: 'android',
        networkType: () async => 'mobile',
      );
      await r.recordProbes(const [ProbeResult(door: 'ws-tls', ok: false)]);
      expect(sent.single.single['door'], 'ws-tls');
      expect(await r.pendingProbeBatches(), 0);
    });
  });

  group('door checks that could not be sent', () {
    late DateTime now;
    late bool offline;
    late List<List<Map<String, dynamic>>> sent;

    VpnEventReporter probing() => VpnEventReporter(
      send: (_, _, _) async {},
      sendProbes: (_, p, _) async {
        if (offline) throw Exception('offline');
        sent.add(p);
      },
      clock: () => now,
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.6.11',
      platform: 'android',
      networkType: () async => 'mobile',
    );

    setUp(() {
      now = DateTime.utc(2026, 10, 6, 5, 10);
      offline = true;
      sent = [];
    });

    test('wait, and go out with the next flush', () async {
      final r = probing();
      await r.recordProbes(const [
        ProbeResult(door: 'xhttp-reality', ok: false),
        ProbeResult(door: 'ws-tls', ok: true, ms: 140),
      ]);
      expect(sent, isEmpty);
      expect(await r.pendingProbeBatches(), 1);

      offline = false;
      now = now.add(const Duration(minutes: 20));
      await r.flush();
      expect(sent.single.map((p) => p['door']), ['xhttp-reality', 'ws-tls']);
      expect(await r.pendingProbeBatches(), 0);
    });

    test('with an open door, older than half an hour are dropped', () async {
      final r = probing();
      await r.recordProbes(const [
        ProbeResult(door: 'xhttp-reality', ok: false),
        ProbeResult(door: 'ws-tls', ok: true, ms: 140),
      ]);
      offline = false;
      now = now.add(const Duration(minutes: 31));
      await r.flush();
      expect(sent, isEmpty);
      expect(await r.pendingProbeBatches(), 0);
    });

    // A phone found every door closed on its home line and reached us
    // hours later over another network. Its checks were dropped at 30
    // minutes.
    test('with every door closed, wait twelve hours', () async {
      final r = probing();
      await r.recordProbes(const [
        ProbeResult(door: 'xhttp-reality', ok: false),
        ProbeResult(door: 'ws-tls', ok: false),
      ], attemptId: 'tap-1');
      offline = false;
      now = now.add(const Duration(hours: 6, minutes: 42));
      await r.flush();
      expect(sent.single.map((p) => p['door']), ['xhttp-reality', 'ws-tls']);
      expect(await r.pendingProbeBatches(), 0);
    });

    test('with every door closed, are dropped after twelve hours', () async {
      final r = probing();
      await r.recordProbes(const [ProbeResult(door: 'ws-tls', ok: false)]);
      offline = false;
      now = now.add(VpnEventReporter.closedProbesKeptFor);
      await r.flush();
      expect(sent, isEmpty);
      expect(await r.pendingProbeBatches(), 0);
    });

    test('a sweep with every door closed keeps the half hour', () async {
      final r = probing();
      await r.recordProbes(const [
        ProbeResult(door: 'ws-tls', ok: false),
      ], source: ProbeSource.sweep);
      offline = false;
      now = now.add(const Duration(minutes: 31));
      await r.flush();
      expect(sent, isEmpty);
    });

    test('go out even when the events cannot', () async {
      var eventsDown = true;
      final events = <List<Map<String, dynamic>>>[];
      final r = VpnEventReporter(
        send: (_, e, _) async {
          if (eventsDown) throw Exception('offline');
          events.add(e);
        },
        sendProbes: (_, p, _) async {
          if (offline) throw Exception('offline');
          sent.add(p);
        },
        clock: () => now,
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.11',
        platform: 'android',
        networkType: () async => 'mobile',
      );
      await r.record(VpnEventType.connectFailed);
      await r.flush();
      await r.recordProbes(const [ProbeResult(door: 'ws-tls', ok: false)]);
      expect(await r.pendingProbeBatches(), 1);
      offline = false;
      await r.flush();
      // One failure event a line would not carry used to hold the door
      // checks back for hours.
      expect(events, isEmpty);
      expect(await r.pending(), 1);
      expect(sent.single.single['door'], 'ws-tls');
      expect(await r.pendingProbeBatches(), 0);

      eventsDown = false;
      await r.flush();
      expect(events, hasLength(1));
      expect(sent, hasLength(1));
    });

    test('go out before the events', () async {
      final order = <String>[];
      offline = false;
      final r = VpnEventReporter(
        send: (_, e, _) async => order.add('events'),
        sendProbes: (_, p, _) async => order.add('probes'),
        clock: () => now,
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.13',
        platform: 'android',
        networkType: () async => 'mobile',
      );
      SharedPreferences.setMockInitialValues({
        VpnEventReporter.storageKey:
            '[{"type":"connected","app_version":"1.6.13","platform":"android"}]',
        VpnEventReporter.probeStorageKey:
            '[{"queued_at":"${now.toIso8601String()}","all_closed":true,'
            '"probes":[{"door":"ws-tls","ok":false}]}]',
      });
      await r.flush();
      // The stuck rule compares arrival times. A late check that found
      // every door closed has to land before the connect that followed.
      expect(order, ['probes', 'events']);
    });

    test('are queued before the send starts', () async {
      final gate = Completer<void>();
      offline = false;
      final r = VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, p, _) async {
          await gate.future;
          sent.add(p);
        },
        clock: () => now,
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.13',
        platform: 'android',
        networkType: () async => 'wifi',
      );
      final recording = r.recordProbes(const [
        ProbeResult(door: 'ws-tls', ok: false),
      ]);
      // An app closed while the send is still trying its routes keeps the
      // checks: they are already stored.
      await pumpEventQueue();
      expect(await r.pendingProbeBatches(), 1);
      gate.complete();
      await recording;
      expect(sent, hasLength(1));
      expect(await r.pendingProbeBatches(), 0);
    });

    test('two reporters flushing at once send each upload once', () async {
      final gate = Completer<void>();
      var sends = 0;
      VpnEventReporter make() => VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, p, _) async {
          sends++;
          await gate.future;
        },
        clock: () => now,
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.13',
        platform: 'android',
        networkType: () async => 'wifi',
      );
      final a = make();
      final b = make();
      final recording = a.recordProbes(const [
        ProbeResult(door: 'ws-tls', ok: false),
      ]);
      await pumpEventQueue();
      final flushing = b.flush();
      gate.complete();
      await Future.wait([recording, flushing]);
      expect(sends, 1);
      expect(await a.pendingProbeBatches(), 0);
    });

    test('keep the tunnel answer of the reporter that queued them', () async {
      final via = <bool>[];
      final queuing = VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, _, _) async => throw Exception('offline'),
        clock: () => now,
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.13',
        platform: 'android',
        networkType: () async => 'wifi',
      )..reportsGoThroughTunnel = () => false;
      await queuing.recordProbes(const [
        ProbeResult(door: 'ws-tls', ok: false),
      ]);
      // A reporter nobody told about the tunnel says "through it", which
      // would cost the row its carrier.
      final flushing = VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, _, v) async => via.add(v),
        clock: () => now,
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.13',
        platform: 'android',
        networkType: () async => 'wifi',
      );
      await flushing.flush();
      expect(via, [false]);
    });

    test(
      'with every door closed, go in pieces under the upload size',
      () async {
        final r = probing();
        final results = [
          for (var i = 0; i < 11; i++)
            ProbeResult(
              door: i.isEven ? 'xhttp-reality' : 'ws-tls',
              ok: false,
              serverHost: '198.51.100.206',
              ms: 4000,
              error: 'tcp timeout; no answer in 3000 ms',
              strategy: const {
                'transport': 'xhttp',
                'security': 'reality',
                'port': 443,
                'fp': 'chrome',
                'path': '/xh',
                'mode': 'auto',
                'sni': 'www.example.org',
                'pbk_prefix': 'AbCdEfGh',
              },
            ),
        ];
        await r.recordProbes(
          results,
          carrier: 'TCI',
          attemptId: 'e1691a9e-0c2f-4c1d-9d5e-6b8a4f3e2d10',
        );
        final pieces = await r.pendingProbeBatches();
        expect(pieces, greaterThan(1));

        offline = false;
        await r.flush();
        expect(sent, hasLength(pieces));
        for (final piece in sent) {
          expect(
            VpnEventReporter.uploadBytes(piece),
            lessThanOrEqualTo(VpnEventReporter.probeUploadBytes),
          );
        }
        // Every row arrives, in the order the doors were checked.
        expect(sent.expand((p) => p).map((p) => p['position']), [
          for (var i = 1; i <= 11; i++) i,
        ]);
      },
    );

    // On 2026-10-09 an emulator sent the 12 checks of one sweep as one
    // upload of 4,794 bytes. A line that cuts larger uploads and passes the
    // small calls would lose a sweep of that size. Every door-check upload
    // now goes in pieces.

    const sweepId = 'sw-5c1f0e2a-7d4b-4e1a-9b2c-3f6d8a0e4b71';

    /// The checks of one round of [n] doors, rows about the size the
    /// emulator sent: a third of the doors open, the rest closed, or every
    /// door closed when [anyOpen] is false.
    List<ProbeResult> checksOf(int n, {bool anyOpen = true}) => [
      for (var i = 0; i < n; i++)
        ProbeResult(
          door: const [
            'xhttp-reality',
            'ws-tls',
            'xhttp-reality-b',
            'ws-tls-v6',
          ][i % 4],
          ok: anyOpen && i % 3 == 0,
          serverHost: '198.51.100.206',
          ms: anyOpen && i % 3 == 0 ? 412 : 5001,
          error: anyOpen && i % 3 == 0 ? null : 'tcp ok; no answer in 5000 ms',
          tcpMs: 181,
          phase: anyOpen && i % 3 == 0 ? 'ok' : 'tls',
          strategy: const {
            'transport': 'xhttp',
            'security': 'reality',
            'port': 443,
            'fp': 'chrome',
            'sni': 'www.speedtest.net',
            'fragment': '100-200,10-20,tlshello',
            'pbk_prefix': 'AbCdEfGh',
          },
        ),
    ];

    /// A reporter whose door-check bodies are kept exactly as they would
    /// leave the phone, sent_at and via_tunnel included.
    VpnEventReporter posting(List<Map<String, dynamic>> bodies) =>
        VpnEventReporter(
          send: (_, _, _) async {},
          post: (path, body) async {
            expect(path, '/api/v1/devices/DEV-1/probes');
            bodies.add(body);
          },
          clock: () => now,
          deviceId: () async => 'DEV-1',
          appVersion: () async => '1.6.18',
          platform: 'android',
          networkType: () async => 'wifi',
          linkFacts: () async => const {
            'link_mtu': 1500,
            'private_dns': 'opportunistic',
            'transport': 'wifi',
          },
          queues: const [],
        );

    List<Map<String, dynamic>> rowsOf(List<Map<String, dynamic>> bodies) => [
      for (final body in bodies)
        ...(body['probes'] as List).cast<Map<String, dynamic>>(),
    ];

    test('a sweep of 12 doors goes in bodies under the upload size', () async {
      final bodies = <Map<String, dynamic>>[];
      final checks = checksOf(12);
      await posting(bodies).recordProbes(
        checks,
        carrier: 'TCI',
        attemptId: sweepId,
        source: ProbeSource.sweep,
      );
      final rows = rowsOf(bodies);
      // In one body these rows would be several times the upload size.
      expect(
        VpnEventReporter.uploadBytes(rows),
        greaterThan(4 * VpnEventReporter.probeUploadBytes),
      );
      expect(bodies.length, greaterThan(1));
      for (final body in bodies) {
        // The wire format is the same as before: only fewer rows a body.
        expect(body.keys, unorderedEquals(['probes', 'via_tunnel', 'sent_at']));
        expect(
          utf8.encode(jsonEncode(body)).length,
          lessThanOrEqualTo(VpnEventReporter.probeUploadBytes),
        );
      }
      // Every check arrives once, in the order the doors were checked, and
      // the backend joins them again by the sweep's id.
      expect(rows.map((p) => p['position']), [for (var i = 1; i <= 12; i++) i]);
      expect(rows.map((p) => p['door']), checks.map((c) => c.door));
      expect(rows.map((p) => p['attempt_id']).toSet(), {sweepId});
      expect(rows.map((p) => p['source']).toSet(), {'sweep'});
      expect(await posting(bodies).pendingProbeBatches(), 0);
    });

    test('a sweep of one door stays one body', () async {
      final bodies = <Map<String, dynamic>>[];
      await posting(bodies).recordProbes(
        checksOf(1),
        attemptId: sweepId,
        source: ProbeSource.sweep,
      );
      expect(bodies, hasLength(1));
      final row = (bodies.single['probes'] as List).single as Map;
      expect(row['position'], 1);
      expect(row['source'], 'sweep');
    });

    test(
      'a diagnosis with an open door and a test point go in pieces too',
      () async {
        for (final source in [
          ProbeSource.diagnosis,
          ProbeSource.testpoint,
          ProbeSource.experiment,
        ]) {
          SharedPreferences.setMockInitialValues({});
          final bodies = <Map<String, dynamic>>[];
          await posting(bodies).recordProbes(
            checksOf(12),
            carrier: 'TCI',
            attemptId: 'e1691a9e-0c2f-4c1d-9d5e-6b8a4f3e2d10',
            source: source,
          );
          expect(bodies.length, greaterThan(1), reason: source.wire);
          for (final body in bodies) {
            expect(
              utf8.encode(jsonEncode(body)).length,
              lessThanOrEqualTo(VpnEventReporter.probeUploadBytes),
              reason: source.wire,
            );
          }
          final rows = rowsOf(bodies);
          expect(rows.map((p) => p['position']), [
            for (var i = 1; i <= 12; i++) i,
          ], reason: source.wire);
          // The open rows arrive once each, like every other row.
          expect(
            rows.where((p) => p['ok'] == true),
            hasLength(4),
            reason: source.wire,
          );
        }
      },
    );

    test('the pieces of a sweep keep the half hour', () async {
      final r = probing();
      // Every door closed, so only the source keeps the shorter time.
      await r.recordProbes(
        checksOf(12, anyOpen: false),
        attemptId: sweepId,
        source: ProbeSource.sweep,
      );
      expect(await r.pendingProbeBatches(), greaterThan(1));
      final prefs = await SharedPreferences.getInstance();
      final stored =
          jsonDecode(prefs.getString(VpnEventReporter.probeStorageKey)!)
              as List;
      expect(stored.any((e) => (e as Map).containsKey('all_closed')), isFalse);
      offline = false;
      now = now.add(const Duration(minutes: 31));
      await r.flush();
      expect(sent, isEmpty);
      expect(await r.pendingProbeBatches(), 0);
    });

    test('a sweep piece that fails is sent again, the others once', () async {
      final r = probing();
      await r.recordProbes(
        checksOf(12),
        attemptId: sweepId,
        source: ProbeSource.sweep,
      );
      final pieces = await r.pendingProbeBatches();
      expect(pieces, greaterThan(2));
      var calls = 0;
      final flaky = VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, p, _) async {
          calls++;
          if (calls == 2) throw Exception('cut');
          sent.add(p);
        },
        clock: () => now,
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.18',
        platform: 'android',
        networkType: () async => 'wifi',
      );
      await flaky.flush();
      // The first piece arrived and the second was cut. The flush stops
      // there and keeps the second piece and every piece after it.
      expect(sent, hasLength(1));
      expect(await flaky.pendingProbeBatches(), pieces - 1);
      await flaky.flush();
      expect(calls, pieces + 1);
      expect(sent, hasLength(pieces));
      // The piece that arrived before the cut was not sent again.
      expect(sent.expand((p) => p).map((p) => p['position']), [
        for (var i = 1; i <= 12; i++) i,
      ]);
      expect(await flaky.pendingProbeBatches(), 0);
    });

    test('a piece that fails keeps the rest for the next flush', () async {
      final r = probing();
      await r.recordProbes([
        for (var i = 0; i < 11; i++)
          ProbeResult(
            door: 'ws-tls',
            ok: false,
            serverHost: '198.51.100.206',
            error: 'tcp timeout; no answer in 3000 ms',
          ),
      ], attemptId: 'e1691a9e-0c2f-4c1d-9d5e-6b8a4f3e2d10');
      final pieces = await r.pendingProbeBatches();
      expect(pieces, greaterThan(1));
      var calls = 0;
      final flaky = VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, p, _) async {
          calls++;
          if (calls == 2) throw Exception('cut');
          sent.add(p);
        },
        clock: () => now,
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.13',
        platform: 'android',
        networkType: () async => 'wifi',
      );
      await flaky.flush();
      // Stops at the piece that failed rather than trying every route for
      // every piece on a line that is cutting them.
      expect(sent, hasLength(1));
      expect(await flaky.pendingProbeBatches(), pieces - 1);
      await flaky.flush();
      expect(sent, hasLength(pieces));
      expect(await flaky.pendingProbeBatches(), 0);
    });

    // An answer about the upload itself would come back on every try, and
    // a closed tap waits up to twelve hours: kept at the head of the
    // queue, it would hold every newer door check back for that long.
    test('an upload refused for good is dropped, and the next goes', () async {
      for (final code in [400, 403, 413, 422]) {
        SharedPreferences.setMockInitialValues({});
        sent.clear();
        final r = probing();
        await r.recordProbes(const [ProbeResult(door: 'refused', ok: false)]);
        await r.recordProbes(const [ProbeResult(door: 'next', ok: false)]);
        expect(await r.pendingProbeBatches(), 2);
        final answering = VpnEventReporter(
          send: (_, _, _) async {},
          sendProbes: (_, p, _) async {
            if (p.single['door'] == 'refused') {
              throw ApiException(statusCode: code, message: 'refused');
            }
            sent.add(p);
          },
          clock: () => now,
          deviceId: () async => 'DEV-1',
          appVersion: () async => '1.6.13',
          platform: 'android',
          networkType: () async => 'wifi',
        );
        await answering.flush();
        expect(sent.single.single['door'], 'next', reason: '$code');
        expect(await answering.pendingProbeBatches(), 0, reason: '$code');
      }
    });

    test('an upload that may go later stays, and stops the flush', () async {
      final failures = <Object>[
        ApiException(statusCode: 0, message: 'No internet connection'),
        ApiException(statusCode: 404, message: 'Device not found'),
        ApiException(statusCode: 408, message: 'Request timeout'),
        ApiException(statusCode: 429, message: 'Rate limited'),
        ApiException(statusCode: 500, message: 'Internal server error'),
        ApiException(statusCode: 503, message: 'Unavailable'),
        TimeoutException('no answer'),
        Exception('connection reset'),
      ];
      for (final failure in failures) {
        SharedPreferences.setMockInitialValues({});
        final r = probing();
        await r.recordProbes(const [ProbeResult(door: 'first', ok: false)]);
        await r.recordProbes(const [ProbeResult(door: 'second', ok: false)]);
        var calls = 0;
        final answering = VpnEventReporter(
          send: (_, _, _) async {},
          sendProbes: (_, _, _) async {
            calls++;
            throw failure;
          },
          // The 404 case: a register that cannot get through.
          register: () async =>
              throw ApiException(statusCode: 0, message: 'No internet'),
          clock: () => now,
          deviceId: () async => 'DEV-1',
          appVersion: () async => '1.6.13',
          platform: 'android',
          networkType: () async => 'wifi',
        );
        await answering.flush();
        expect(calls, 1, reason: '$failure');
        expect(await answering.pendingProbeBatches(), 2, reason: '$failure');
      }
    });

    // A tap queued while an upload is in flight joins that run. When the
    // upload then fails, for example on the network the phone has just
    // left, the run goes round again rather than leave the new tap for the
    // next try.
    test('a tap queued during a failed upload goes in the same run', () async {
      final gate = Completer<void>();
      var calls = 0;
      final r = VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, p, _) async {
          calls++;
          if (calls == 1) {
            await gate.future;
            throw Exception('cut on the old network');
          }
          sent.add(p);
        },
        clock: () => now,
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.13',
        platform: 'android',
        networkType: () async => 'wifi',
      );
      final first = r.recordProbes(const [
        ProbeResult(door: 'tap-1', ok: false),
      ]);
      await pumpEventQueue();
      expect(calls, 1);
      final second = r.recordProbes(const [
        ProbeResult(door: 'tap-2', ok: false),
      ]);
      await pumpEventQueue();
      expect(await r.pendingProbeBatches(), 2);
      gate.complete();
      await Future.wait([first, second]);
      expect(sent.map((p) => p.single['door']), ['tap-1', 'tap-2']);
      expect(await r.pendingProbeBatches(), 0);
    });

    test('a register that never helps stops after maxRounds rounds', () async {
      var sends = 0;
      var registers = 0;
      late final VpnEventReporter r;
      r = VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, _, _) async {
          sends++;
          // A new tap while every upload fails. Capped, so a run that did
          // not stop fails the test instead of hanging it.
          if (sends < 20) {
            unawaited(
              r.recordProbes([ProbeResult(door: 'tap-$sends', ok: false)]),
            );
            await pumpEventQueue();
          }
          throw ApiException(statusCode: 404, message: 'Device not found');
        },
        register: () async => registers++,
        clock: () => now,
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.13',
        platform: 'android',
        networkType: () async => 'wifi',
      );
      await r.recordProbes(const [ProbeResult(door: 'tap-0', ok: false)]);
      // Each round sends, registers and sends once more.
      expect(registers, VpnEventReporter.maxRounds);
      expect(sends, 2 * VpnEventReporter.maxRounds);
      // Nothing was lost: every tap waits for a later try.
      expect(await r.pendingProbeBatches(), 1 + 2 * VpnEventReporter.maxRounds);
    });

    test('keep a bounded number of uploads, dropping the oldest', () async {
      final r = probing();
      const cap = VpnEventReporter.maxQueuedProbeBatches;
      for (var i = 0; i < cap + 2; i++) {
        await r.recordProbes([ProbeResult(door: 'door-$i', ok: false)]);
      }
      expect(await r.pendingProbeBatches(), cap);
      offline = false;
      await r.flush();
      expect(sent.first.single['door'], 'door-2');
      expect(sent.last.single['door'], 'door-${cap + 1}');
    });

    // Rows as recordProbes builds them on Android since 2026-10-09, with
    // tcp_ms, phase and the link facts. A row that failed with "tcp ok;
    // no answer" is about 480 to 510 bytes, so each one is a piece of its
    // own. Until 2026-10-12 the queue held 40 pieces, and one press of the
    // button on a phone where every door is closed pushed out the pieces
    // queued before it, the open row of the tap before it among them. The
    // backend then read that tap as one that found every door closed.
    test('hold one press of the button where every door is closed, with its '
        'tries, and the open row of the tap before it', () async {
      final r = VpnEventReporter(
        send: (_, _, _) async {},
        sendProbes: (_, p, _) async {
          if (offline) throw Exception('offline');
          sent.add(p);
        },
        clock: () => now,
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.7.1',
        platform: 'android',
        networkType: () async => 'mobile',
        linkFacts: () async => const {
          'link_mtu': 1500,
          'private_dns': 'opportunistic',
          'transport': 'cellular',
        },
        queues: const [],
      );
      const kinds = [
        'xhttp-reality',
        'xhttp-reality-b',
        'xhttp-reality-v6',
        'ws-tls',
        'httpupgrade-tls',
      ];
      ProbeResult closed(int i) => ProbeResult(
        door: kinds[i % kinds.length],
        ok: false,
        serverHost: '192.0.2.${10 + i}',
        ms: 3012,
        error: 'tcp ok 133ms; no answer in 3000 ms',
        tcpMs: 133,
        phase: 'tls',
        strategy: const {
          'transport': 'xhttp',
          'security': 'reality',
          'sni': 'www.samsung.com',
          'pbk_prefix': 'AbCdEfGh',
        },
      );
      // The last piece of an earlier tap, with its open row, still waiting.
      await r.recordProbes(
        const [
          ProbeResult(
            door: 'xhttp-reality',
            ok: true,
            serverHost: '198.51.100.214',
            ms: 412,
            tcpMs: 133,
            phase: 'ok',
          ),
        ],
        carrier: 'MCI',
        attemptId: 'tap-0',
      );
      // A tap and the backend's 4 tries after it (CHECKLIST_RETRY_SECONDS
      // 5,10,20,30 on 2026-10-11), each with the own-first check's row and
      // 22 doors closed.
      const taps = 5;
      const doors = 22;
      for (var tap = 1; tap <= taps; tap++) {
        await r.recordProbes(
          [closed(0)],
          carrier: 'MCI',
          attemptId: 'tap-$tap',
        );
        await r.recordProbes(
          [for (var i = 0; i < doors; i++) closed(i)],
          carrier: 'MCI',
          attemptId: 'tap-$tap',
        );
      }
      offline = false;
      await r.flush();
      final rows = [for (final p in sent) ...p];
      expect(rows, hasLength(1 + taps * (1 + doors)));
      expect(rows.first['attempt_id'], 'tap-0');
      expect(rows.first['ok'], isTrue);
    });
  });

  // The server corrects each client_ts by the gap between sent_at and its
  // own clock, so sent_at has to be the moment a request is built.

  test('an events batch carries sent_at in UTC', () async {
    final posted = <(String, Map<String, dynamic>)>[];
    // A local time, so the test shows it is converted rather than
    // passed through.
    final at = DateTime(2026, 9, 27, 13, 30, 5);
    final r = VpnEventReporter(
      post: (path, body) async => posted.add((path, body)),
      clock: () => at,
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.6.1',
      platform: 'android',
      networkType: () async => 'mobile',
    );

    await r.record(VpnEventType.connectFailed);
    await r.flush();

    final (path, body) = posted.single;
    expect(path, '/api/v1/devices/DEV-1/events');
    expect(body['events'], hasLength(1));
    expect(body['via_tunnel'], isTrue);
    final sentAt = body['sent_at'] as String;
    expect(sentAt, endsWith('Z'));
    expect(DateTime.parse(sentAt).isUtc, isTrue);
    expect(DateTime.parse(sentAt).isAtSameMomentAs(at), isTrue);
  });

  // The backend places the device in a country from where the phone says
  // it is, before the address the batch arrived from.

  test('an events batch carries where the phone is', () async {
    final posted = <Map<String, dynamic>>[];
    final r = VpnEventReporter(
      post: (_, body) async => posted.add(body),
      place: () async => {'network_country': 'ir', 'time_zone': 'Asia/Tehran'},
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.6.5',
      platform: 'android',
      networkType: () async => 'mobile',
    );

    await r.record(VpnEventType.connected);
    await r.flush();

    expect(posted.single['place'], {
      'network_country': 'ir',
      'time_zone': 'Asia/Tehran',
    });
  });

  test('an events batch goes out without a place when there is none', () async {
    final posted = <Map<String, dynamic>>[];
    final r = VpnEventReporter(
      post: (_, body) async => posted.add(body),
      place: () async => null,
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.6.5',
      platform: 'android',
      networkType: () async => 'mobile',
    );

    await r.record(VpnEventType.connected);
    await r.flush();

    expect(posted.single.containsKey('place'), isFalse);
    expect(posted.single['events'], hasLength(1));
  });

  test('a retried batch gets a new sent_at, and the same client_ts', () async {
    final attempts = <Map<String, dynamic>>[];
    var now = DateTime.utc(2026, 9, 27, 10);
    var offline = true;
    final r = VpnEventReporter(
      post: (_, body) async {
        attempts.add(body);
        if (offline) throw Exception('offline');
      },
      clock: () => now,
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.6.1',
      platform: 'android',
      networkType: () async => 'mobile',
    );

    await r.record(VpnEventType.dropped);
    await r.flush();
    expect(await r.pending(), 1);

    now = DateTime.utc(2026, 9, 27, 10, 5);
    offline = false;
    await r.flush();

    expect(attempts.first['sent_at'], '2026-09-27T10:00:00.000Z');
    expect(attempts.last['sent_at'], '2026-09-27T10:05:00.000Z');
    final first = (attempts.first['events'] as List).single;
    final last = (attempts.last['events'] as List).single;
    expect(last['client_ts'], first['client_ts']);
    expect(await r.pending(), 0);
  });

  test('a probe batch carries sent_at in UTC', () async {
    final posted = <(String, Map<String, dynamic>)>[];
    final r = VpnEventReporter(
      post: (path, body) async => posted.add((path, body)),
      clock: () => DateTime.utc(2026, 9, 27, 10, 0, 7),
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.6.1',
      platform: 'android',
      networkType: () async => 'mobile',
    );

    await r.recordProbes(const [ProbeResult(door: 'ws-tls', ok: true)]);

    final (path, body) = posted.single;
    expect(path, '/api/v1/devices/DEV-1/probes');
    expect(body['probes'], hasLength(1));
    expect(body['sent_at'], '2026-09-27T10:00:07.000Z');
  });

  group('reportDomains', () {
    final posted = <(String, Map<String, dynamic>)>[];
    VpnEventReporter domainReporter() => VpnEventReporter(
      post: (path, body) async => posted.add((path, body)),
      deviceId: () async => 'DEV-1',
      appVersion: () async => '1.6.5',
      platform: 'android',
      networkType: () async => 'mobile',
    );

    setUp(posted.clear);

    test('sends the counts to the domains endpoint', () async {
      await domainReporter().reportDomains({'bbc.com': 5, 'github.com': 2});
      final (path, body) = posted.single;
      expect(path, '/api/v1/devices/DEV-1/domains');
      expect(body['domains'], {'bbc.com': 5, 'github.com': 2});
    });

    test('sends nothing when there is nothing to send', () async {
      await domainReporter().reportDomains({});
      expect(posted, isEmpty);
    });

    test('sends nothing when sharing is off', () async {
      SharedPreferences.setMockInitialValues({
        VpnEventReporter.sharePrefKey: false,
      });
      await domainReporter().reportDomains({'bbc.com': 1});
      expect(posted, isEmpty);
    });

    test('a send that worked lets the caller drop the counts', () async {
      expect(await domainReporter().reportDomains({'bbc.com': 1}), isTrue);
    });

    test('a send that failed asks the caller to keep the counts', () async {
      final reporter = VpnEventReporter(
        post: (path, body) async => throw Exception('no route'),
        deviceId: () async => 'DEV-1',
        appVersion: () async => '1.6.6',
        platform: 'android',
        networkType: () async => 'mobile',
      );
      expect(await reporter.reportDomains({'bbc.com': 1}), isFalse);
    });

    test('counts are dropped, not kept, when sharing is off', () async {
      SharedPreferences.setMockInitialValues({
        VpnEventReporter.sharePrefKey: false,
      });
      // True, so the caller clears them: they are meant never to be sent,
      // not held until the switch comes back on.
      expect(await domainReporter().reportDomains({'bbc.com': 1}), isTrue);
      expect(posted, isEmpty);
    });
  });
}
