import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/connection_data.dart';

void main() {
  test('a missing or unreadable block turns every part off', () {
    expect(ConnectionData.fromJson(null), ConnectionData.off);
    expect(ConnectionData.fromJson('on'), ConnectionData.off);
    final bad = ConnectionData.fromJson({
      'timed_checks': 'yes',
      'network_keys': 1,
      'network_key_days': -3,
      'session_sample_ms': 'fast',
      'session_stall_ms': 0,
      'session_busy_bytes': 2.5,
    });
    expect(bad, ConnectionData.off);
    expect(bad.sessionReadings, isFalse);
  });

  test('every number comes from the backend', () {
    final data = ConnectionData.fromJson({
      'timed_checks': true,
      'network_keys': true,
      'network_key_days': 7,
      'session_sample_ms': 2000,
      'session_stall_ms': 8000,
      'session_busy_bytes': 4096,
    });
    expect(data.timedChecks, isTrue);
    expect(data.networkKeys, isTrue);
    expect(data.networkKeyPeriod, const Duration(days: 7));
    expect(data.sessionSample, const Duration(seconds: 2));
    expect(data.stallAfter, const Duration(seconds: 8));
    expect(data.busyBytes, 4096);
    expect(data.sessionReadings, isTrue);
  });

  test('session readings need both a period and a stall length', () {
    expect(
      ConnectionData.fromJson({'session_sample_ms': 2000}).sessionReadings,
      isFalse,
    );
  });

  test('what is saved reads back the same', () {
    final data = ConnectionData.fromJson({
      'timed_checks': true,
      'network_key_days': 30,
      'session_sample_ms': 1000,
      'session_stall_ms': 6000,
    });
    expect(
      ConnectionData.fromJson(jsonDecode(jsonEncode(data.toJson()))),
      data,
    );
    expect(ConnectionData.off.toJson(), isEmpty);
  });
}
