import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
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
  late String? reached;
  late int onlineAsked;
  late bool apiAnswered;
  late bool tunnelUp;
  late List<String> notified;
  late int cleared;

  Keeper keeper() => Keeper(
    reporter: recorder,
    stats: () async => stats,
    probe: () async {
      probesMade++;
      return probes.isEmpty ? true : probes.removeAt(0);
    },
    reach: () async {
      onlineAsked++;
      return reached;
    },
    answeredSince: (_) => apiAnswered,
    tunnelUp: () async => tunnelUp,
    appRunning: () async => appBack,
    notify: (language) async => notified.add(language),
    clear: () async => cleared++,
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
    reached = 'control';
    onlineAsked = 0;
    apiAnswered = false;
    tunnelUp = true;
    notified = [];
    cleared = 0;
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
    // Carrying: a notification from an earlier run goes.
    expect(cleared, 1);
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
    expect(onlineAsked, 0);
    expect(notified, isEmpty);
  });

  test('a dead tunnel is reported once, the user told, and heartbeats stop '
      'until it carries again', () async {
    stats = {'bytes_up': 50000, 'bytes_down': 100, 'carrier': 'MCI'};
    probes = [false, false, false, false];
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
    expect(dropped.diag, containsPair('stall_online', 'control'));
    expect(dropped.diag, containsPair('stall_probes', Keeper.checks + 1));
    expect(dropped.diag!.containsKey('stall_offline_skips'), isFalse);
    // The checks, then one more once the phone showed it is online.
    expect(probesMade, Keeper.checks + 1);
    expect(onlineAsked, 1);
    expect(notified, ['fa']);
    expect(cleared, 0);

    // Still dead five minutes later: nothing more.
    recorder.events.clear();
    stats = {'bytes_up': 9000, 'bytes_down': 0};
    await keeper().run();
    expect(recorder.events, isEmpty);
    expect(notified, hasLength(1));
    expect(cleared, 0);

    // Carrying again: heartbeats again, and the notification goes.
    stats = {'bytes_up': 9000, 'bytes_down': 500000};
    await keeper().run();
    expect(recorder.events.map((e) => e.type), [VpnEventType.heartbeat]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(Keeper.stalledKey), isFalse);
    expect(cleared, 1);
  });

  test('a tunnel that fails every check while the phone reaches nothing '
      'outside it either is not called dead, and the next run looks '
      'again', () async {
    stats = {'bytes_up': 50000, 'bytes_down': 0};
    probes = [false, false, false];
    reached = null;
    await keeper().run();
    expect(recorder.events.map((e) => e.type), [VpnEventType.heartbeat]);
    expect(probesMade, Keeper.checks);
    expect(onlineAsked, 1);
    expect(notified, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(Keeper.stalledKey), isFalse);

    // Five minutes later the phone is back and the tunnel still fails.
    recorder.events.clear();
    probes = [false, false, false, false];
    reached = 'control';
    await keeper().run();
    expect(recorder.events.map((e) => e.type), [
      VpnEventType.heartbeat,
      VpnEventType.dropped,
    ]);
    // The heartbeat says how many runs were left unreported.
    expect(recorder.events.first.diag, containsPair('offline_skips', 1));
    expect(recorder.events.last.diag, containsPair('stall_offline_skips', 1));
    expect(notified, ['fa']);
    expect(prefs.containsKey(Keeper.offlineSkipsKey), isFalse);
  });

  test('no network at all: no check, nothing reported or shown', () async {
    stats = {'bytes_up': 50000, 'bytes_down': 0, 'network': 'none'};
    probes = [false, false, false, false];
    await keeper().run();
    expect(recorder.events.map((e) => e.type), [VpnEventType.heartbeat]);
    expect(probesMade, 0);
    expect(onlineAsked, 0);
    expect(notified, isEmpty);
  });

  test('an answer from our API on the phone\'s own network shows it is '
      'online, whatever the sites say', () async {
    stats = {'bytes_up': 50000, 'bytes_down': 0};
    probes = [false, false, false, false];
    reached = null;
    apiAnswered = true;
    await keeper().run();
    expect(recorder.events.last.type, VpnEventType.dropped);
    expect(recorder.events.last.diag, containsPair('stall_online', 'api'));
    expect(onlineAsked, 0);
    expect(notified, ['fa']);
  });

  test('a phone that looks offline run after run is reported once the '
      'backend\'s limit of runs is reached', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConfigState.stallWatchSettingsKey,
      jsonEncode({'keeper_offline_skip_runs': 2}),
    );
    stats = {'bytes_up': 50000, 'bytes_down': 0};
    reached = null;
    for (var run = 0; run < 2; run++) {
      probes = [false, false, false];
      await keeper().run();
    }
    expect(notified, isEmpty);
    expect(
      recorder.events.map((e) => e.type),
      everyElement(VpnEventType.heartbeat),
    );

    recorder.events.clear();
    probes = [false, false, false, false];
    await keeper().run();
    expect(recorder.events.map((e) => e.type), [
      VpnEventType.heartbeat,
      VpnEventType.dropped,
    ]);
    final dropped = recorder.events.last;
    expect(dropped.diag, containsPair('stall_online', 'skip_limit'));
    expect(dropped.diag, containsPair('stall_offline_skips', 2));
    expect(notified, ['fa']);
  });

  test('with nothing saved the built-in limit applies, and 0 reports at '
      'once', () async {
    stats = {'bytes_up': 50000, 'bytes_down': 0};
    reached = null;
    for (var run = 0; run < 6; run++) {
      probes = [false, false, false];
      await keeper().run();
    }
    expect(notified, isEmpty);
    probes = [false, false, false, false];
    await keeper().run();
    expect(notified, hasLength(1));

    SharedPreferences.setMockInitialValues({
      AppConfigState.stallWatchSettingsKey: jsonEncode({
        'keeper_offline_skip_runs': 0,
      }),
    });
    probes = [false, false, false, false];
    await keeper().run();
    expect(notified, hasLength(2));
  });

  test('the count of offline runs starts again once the tunnel '
      'carries', () async {
    final prefs = await SharedPreferences.getInstance();
    stats = {'bytes_up': 50000, 'bytes_down': 0};
    reached = null;
    probes = [false, false, false];
    await keeper().run();
    expect(prefs.containsKey(Keeper.offlineSkipsKey), isTrue);

    stats = {'bytes_up': 50000, 'bytes_down': 900000};
    await keeper().run();
    expect(prefs.containsKey(Keeper.offlineSkipsKey), isFalse);
  });

  test('a line back during the last check: the extra check passes and '
      'nothing is reported', () async {
    stats = {'bytes_up': 50000, 'bytes_down': 0};
    probes = [false, false, false, true];
    await keeper().run();
    expect(probesMade, Keeper.checks + 1);
    expect(recorder.events.map((e) => e.type), [VpnEventType.heartbeat]);
    expect(notified, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(Keeper.stalledKey), isFalse);
  });

  test('a tunnel stopped while it was checked is not reported', () async {
    stats = {'bytes_up': 50000, 'bytes_down': 0};
    probes = [false, false, false, false];
    tunnelUp = false;
    await keeper().run();
    expect(recorder.events.map((e) => e.type), [VpnEventType.heartbeat]);
    expect(notified, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(Keeper.stalledKey), isFalse);
  });

  test('a tunnel with no attempt is reported once, and the next tunnel on '
      'its own', () async {
    SharedPreferences.setMockInitialValues({'pref_locale': 'fa'});
    stats = {'bytes_up': 50000, 'bytes_down': 0, 'tunnel': '101'};
    probes = [false, false, false, false];
    await keeper().run();
    expect(notified, hasLength(1));

    // Still dead five minutes later: nothing more, and no repeated sound.
    recorder.events.clear();
    probes = [false, false, false, false];
    await keeper().run();
    expect(recorder.events, isEmpty);
    expect(notified, hasLength(1));

    // Started again from the quick settings tile, still dead.
    stats = {'bytes_up': 50000, 'bytes_down': 0, 'tunnel': '102'};
    probes = [false, false, false, false];
    await keeper().run();
    expect(recorder.events.map((e) => e.type), [
      VpnEventType.heartbeat,
      VpnEventType.dropped,
    ]);
    expect(notified, hasLength(2));
  });

  test('the same attempt on a tunnel started again is checked again, and '
      'the old mark goes', () async {
    stats = {'bytes_up': 50000, 'bytes_down': 0, 'tunnel': '101'};
    probes = [false, false, false, false];
    await keeper().run();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(Keeper.stalledKey), 'tap-7');
    expect(prefs.getString(Keeper.stalledTunnelKey), '101');

    recorder.events.clear();
    stats = {'bytes_up': 50000, 'bytes_down': 0, 'tunnel': '102'};
    probes = [false, false, false, false];
    await keeper().run();
    expect(recorder.events.map((e) => e.type), [
      VpnEventType.heartbeat,
      VpnEventType.dropped,
    ]);
    expect(notified, hasLength(2));
    expect(prefs.getString(Keeper.stalledKey), 'tap-7');
    expect(prefs.getString(Keeper.stalledTunnelKey), '102');

    // Carrying on the new tunnel: both marks go.
    stats = {'bytes_up': 50000, 'bytes_down': 900000, 'tunnel': '102'};
    await keeper().run();
    expect(prefs.containsKey(Keeper.stalledKey), isFalse);
    expect(prefs.containsKey(Keeper.stalledTunnelKey), isFalse);
  });

  test('the keeper asks the control and home sites the backend '
      'sent', () async {
    addTearDown(() => ChecklistSettings.current = null);
    SharedPreferences.setMockInitialValues({
      AppConfigState.checklistKey: jsonEncode({
        'control_urls': ['http://203.0.113.7/generate_204'],
        'home_control_urls': ['https://198.51.100.9/'],
      }),
    });
    await Keeper.restoreSettings();
    expect(ChecklistSettings.current?.control, [
      'http://203.0.113.7/generate_204',
    ]);
    expect(ChecklistSettings.current?.homeControl, ['https://198.51.100.9/']);
  });

  test('the app coming back during the online check leaves the tunnel to '
      'it', () async {
    stats = {'bytes_up': 50000, 'bytes_down': 0};
    probes = [false, false, false];
    // Asked once before the checks and once after each of them; the app is
    // back on the next question, after the online check.
    var asked = 0;
    final k = Keeper(
      reporter: recorder,
      stats: () async => stats,
      probe: () async => probes.removeAt(0),
      reach: () async {
        onlineAsked++;
        return 'control';
      },
      answeredSince: (_) => false,
      tunnelUp: () async => true,
      appRunning: () async => ++asked > Keeper.checks + 1,
      notify: (language) async => notified.add(language),
      clear: () async => cleared++,
      wait: (_) async {},
      now: () => now,
    );
    await k.run();
    expect(onlineAsked, 1);
    expect(recorder.events.map((e) => e.type), [VpnEventType.heartbeat]);
    expect(notified, isEmpty);
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
