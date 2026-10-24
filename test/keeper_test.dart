import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:fortiva_vpn/services/keeper.dart';
import 'package:fortiva_vpn/services/stall_watch.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The heartbeat and the dead tunnel check while the app's own engine is
/// gone and the tunnel runs on (Keeper on the Android side starts a run).

class _Event {
  _Event(this.type, this.attemptId, this.error, this.diag, this.up, this.down);
  final VpnEventType type;
  final String? attemptId;
  final String? error;
  final Map<String, dynamic>? diag;
  final int? up;
  final int? down;
}

class _Recorder extends VpnEventReporter {
  _Recorder() : super(send: (_, _, _) async {}, sendProbes: (_, _, _) async {});

  final events = <_Event>[];
  var flushes = 0;

  @override
  Future<void> record(
    VpnEventType type, {
    String? serverHost,
    String? door,
    String? attemptId,
    Map<String, dynamic>? strategy,
    Duration? duration,
    String? error,
    Map<String, dynamic>? diag,
    int? bytesUp,
    int? bytesDown,
    DateTime? at,
  }) async {
    events.add(_Event(type, attemptId, error, diag, bytesUp, bytesDown));
  }

  @override
  Future<void> flush() async => flushes++;
}

void main() {
  final now = DateTime.utc(2026, 10, 16, 18);
  late _Recorder recorder;
  late Map<String, dynamic>? stats;
  late List<bool> probes;
  late int probesMade;
  late bool appBack;
  late List<String> notified;

  Keeper keeper() => Keeper(
    reporter: recorder,
    stats: () async => stats,
    probe: () async {
      probesMade++;
      return probes.isEmpty ? true : probes.removeAt(0);
    },
    appRunning: () async => appBack,
    notify: (language) async => notified.add(language),
    wait: (_) async {},
    now: () => now,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      Keeper.attemptKey: jsonEncode({
        'attempt_id': 'tap-7',
        'door': 'xhttp-reality',
        'server_host': 'edge.example',
        'verified_at': now
            .subtract(const Duration(minutes: 20))
            .toIso8601String(),
        'moves': 2,
        'failovers': 1,
      }),
      Keeper.startTimeKey: now
          .subtract(const Duration(minutes: 21))
          .toIso8601String(),
      'pref_locale': 'fa',
    });
    recorder = _Recorder();
    stats = {
      'bytes_up': 50000,
      'bytes_down': 900000,
      'carrier': 'MCI',
      'network': 'mobile',
      'session': {'samples': 60},
    };
    probes = [];
    probesMade = 0;
    appBack = false;
    notified = [];
  });

  test('sends the heartbeat the app would, with its attempt', () async {
    await keeper().run();
    final beat = recorder.events.single;
    expect(beat.type, VpnEventType.heartbeat);
    expect(beat.attemptId, 'tap-7');
    expect((beat.up, beat.down), (50000, 900000));
    expect(beat.diag, {
      'carrier': 'MCI',
      'network': 'mobile',
      'verified_s': 1200,
      'moves': 2,
      'failovers': 1,
      'session': {'samples': 60},
      'keeper': true,
    });
    expect(probesMade, 0);
    expect(recorder.flushes, 1);
  });

  test('does nothing with no tunnel, or when the app came back', () async {
    stats = null;
    await keeper().run();
    stats = {'bytes_up': 50000, 'bytes_down': 0};
    appBack = true;
    await keeper().run();
    expect(recorder.events, isEmpty);
    expect(probesMade, 0);
  });

  test('a tunnel that answers a check is not called dead', () async {
    stats = {'bytes_up': 50000, 'bytes_down': 0};
    probes = [false, true];
    await keeper().run();
    expect(recorder.events.map((e) => e.type), [VpnEventType.heartbeat]);
    expect(probesMade, 2);
    expect(notified, isEmpty);
  });

  test('a dead tunnel is reported once, the user told, and heartbeats stop '
      'until it carries again', () async {
    stats = {'bytes_up': 50000, 'bytes_down': 100, 'carrier': 'MCI'};
    probes = [false, false, false];
    await keeper().run();
    expect(recorder.events.map((e) => e.type), [
      VpnEventType.heartbeat,
      VpnEventType.dropped,
    ]);
    final dropped = recorder.events.last;
    expect(dropped.error, 'stalled');
    expect(dropped.attemptId, 'tap-7');
    expect(dropped.diag, containsPair('drop_reason', 'stalled'));
    expect(dropped.diag, containsPair('stall_trigger', 'keeper'));
    expect(dropped.diag, containsPair('carrier', 'MCI'));
    expect(probesMade, Keeper.checks);
    expect(notified, ['fa']);

    // Still dead five minutes later: nothing more.
    recorder.events.clear();
    stats = {'bytes_up': 9000, 'bytes_down': 0};
    await keeper().run();
    expect(recorder.events, isEmpty);
    expect(notified, hasLength(1));

    // Carrying again: heartbeats again.
    stats = {'bytes_up': 9000, 'bytes_down': 500000};
    await keeper().run();
    expect(recorder.events.map((e) => e.type), [VpnEventType.heartbeat]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(Keeper.stalledKey), isFalse);
  });

  test('no check while the backend has the dead tunnel check off, or when '
      'the phone sent nothing', () async {
    stats = {'bytes_up': 50000, 'bytes_down': 0};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfigState.stallWatchOffKey, true);
    await keeper().run();
    await prefs.remove(AppConfigState.stallWatchOffKey);
    stats = {'bytes_up': StallWatch.minUp - 1, 'bytes_down': 0};
    await keeper().run();
    expect(probesMade, 0);
    expect(
      recorder.events.every((e) => e.type == VpnEventType.heartbeat),
      isTrue,
    );
  });
}
