import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/stall_watch_settings.dart';

/// The stall watch's numbers come from the app config's stall_watch block.
void main() {
  test('no block keeps the numbers the app was built with', () {
    final s = StallWatchSettings.fromJson(null);
    expect(s.interval, const Duration(minutes: 1));
    expect(s.checks, 3);
    expect(s.checkGap, const Duration(seconds: 10));
    expect(s.resumeGap, const Duration(minutes: 2));
    expect(s.minUp, 1024);
    expect(s.minDown, 1024);
    // The download check and the throttle trigger only when asked for.
    expect(s.probeBytes, 0);
    expect(s.throttle, isFalse);
  });

  test('a block is read in full', () {
    final s = StallWatchSettings.fromJson({
      'interval_seconds': 30,
      'checks': 2,
      'check_gap_seconds': 5,
      'resume_gap_seconds': 60,
      'min_up_bytes': 2048,
      'min_down_bytes': 512,
      'probe_bytes': 65536,
      'probe_timeout_ms': 4000,
      'throttle': true,
      'throttle_ratio': 0.2,
      'throttle_window': 6,
      'throttle_min_normal_bytes': 100000,
      'throttle_cooldown_seconds': 0,
    });
    expect(s.interval, const Duration(seconds: 30));
    expect(s.checks, 2);
    expect(s.checkGap, const Duration(seconds: 5));
    expect(s.resumeGap, const Duration(minutes: 1));
    expect(s.minUp, 2048);
    expect(s.minDown, 512);
    expect(s.probeBytes, 65536);
    expect(s.probeTimeout, const Duration(seconds: 4));
    expect(s.throttle, isTrue);
    expect(s.throttleRatio, 0.2);
    expect(s.throttleReadings, 6);
    expect(s.throttleMinNormal, 100000);
    expect(s.throttleCooldown, Duration.zero);
  });

  test('a bad value falls back to its built-in number', () {
    final s = StallWatchSettings.fromJson({
      'interval_seconds': 'often',
      'checks': 0,
      'throttle_ratio': 1.5,
      'throttle_window': 1,
      'probe_timeout_ms': -1,
      'throttle': 'yes',
    });
    expect(s.interval, const Duration(minutes: 1));
    expect(s.checks, 3);
    expect(s.throttleRatio, 0.1);
    expect(s.throttleReadings, 10);
    expect(s.probeTimeout, const Duration(seconds: 5));
    expect(s.throttle, isFalse);
  });

  test('what is saved reads back the same', () {
    const s = StallWatchSettings(
      checks: 4,
      probeBytes: 65536,
      throttle: true,
      throttleRatio: 0.25,
    );
    final back = StallWatchSettings.fromJson(s.toJson());
    expect(back.toJson(), s.toJson());
  });

  test('the app config carries the block', () {
    final config = AppConfig.fromJson({
      'privacy_policy_url': 'p',
      'terms_of_service_url': 't',
      'eula_url': 'e',
      'support_email': 's',
      'force_update': {
        'ios': {
          'minimum_version': '1.0.0',
          'latest_version': '1.0.0',
          'update_url': 'u',
        },
        'android': {
          'minimum_version': '1.0.0',
          'latest_version': '1.0.0',
          'update_url': 'u',
        },
      },
      'stall_watch': {'throttle': true, 'probe_bytes': 65536},
    });
    expect(config.stallWatch.throttle, isTrue);
    expect(config.stallWatch.probeBytes, 65536);
    final none = AppConfig.fromJson({
      'privacy_policy_url': 'p',
      'terms_of_service_url': 't',
      'eula_url': 'e',
      'support_email': 's',
      'force_update': {
        'ios': {
          'minimum_version': '1.0.0',
          'latest_version': '1.0.0',
          'update_url': 'u',
        },
        'android': {
          'minimum_version': '1.0.0',
          'latest_version': '1.0.0',
          'update_url': 'u',
        },
      },
    });
    expect(none.stallWatch.throttle, isFalse);
  });
}
