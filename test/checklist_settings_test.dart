import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';

/// The app config's `checklist` block. Every number comes from the
/// backend, and a block that is missing, or a part of it that lacks a
/// number, keeps the checklist as it was before the block existed.
const full = {
  'last_pass_doors': 16,
  'last_pass_parallel': 4,
  'last_pass_timeout_ms': 5000,
  'swept_open_minutes': 180,
  'skip_after_failures': 3,
  'skip_minutes': 30,
  'fallback_links': 16,
  'fallback_parallel': 8,
};

Map<String, dynamic> configJson([Object? checklist]) => {
  'privacy_policy_url': 'https://example.com/privacy',
  'terms_of_service_url': 'https://example.com/terms',
  'eula_url': 'https://example.com/eula',
  'support_email': 'support@example.com',
  'force_update': {
    for (final os in ['ios', 'android'])
      os: {
        'latest_version': '1.0.0',
        'minimum_version': '1.0.0',
        'update_url': 'https://example.com/update',
      },
  },
  'checklist': ?checklist,
};

void main() {
  test('a full block gives every part', () {
    final s = ChecklistSettings.fromJson(full)!;
    expect(s.lastPass!.doors, 16);
    expect(s.lastPass!.parallel, 4);
    expect(s.lastPass!.timeout, const Duration(milliseconds: 5000));
    expect(s.lastPass!.sweptOpenFor, const Duration(minutes: 180));
    expect(s.skip!.failures, 3);
    expect(s.skip!.skipFor, const Duration(minutes: 30));
    expect(s.fallback!.links, 16);
    expect(s.fallback!.parallel, 8);
  });

  test('no block, or one that is not an object, is no settings', () {
    expect(ChecklistSettings.fromJson(null), isNull);
    expect(ChecklistSettings.fromJson('on'), isNull);
    expect(ChecklistSettings.fromJson(const []), isNull);
    expect(ChecklistSettings.fromJson(const {}), isNull);
  });

  test('each part stands on its own', () {
    final lastPassOnly = ChecklistSettings.fromJson({
      'last_pass_doors': 8,
      'last_pass_parallel': 2,
      'last_pass_timeout_ms': 4000,
    })!;
    expect(lastPassOnly.lastPass, isNotNull);
    expect(lastPassOnly.skip, isNull);

    final skipOnly = ChecklistSettings.fromJson({
      'skip_after_failures': 2,
      'skip_minutes': 15,
    })!;
    expect(skipOnly.lastPass, isNull);
    expect(skipOnly.skip!.failures, 2);
    expect(skipOnly.fallback, isNull);

    final fallbackOnly = ChecklistSettings.fromJson({
      'fallback_links': 12,
      'fallback_parallel': 6,
    })!;
    expect(fallbackOnly.lastPass, isNull);
    expect(fallbackOnly.skip, isNull);
    expect(fallbackOnly.fallback!.links, 12);
    expect(fallbackOnly.fallback!.parallel, 6);
  });

  test('a part that lacks a number it needs is off', () {
    for (final key in [
      'last_pass_doors',
      'last_pass_parallel',
      'last_pass_timeout_ms',
    ]) {
      final s = ChecklistSettings.fromJson({...full}..remove(key))!;
      expect(s.lastPass, isNull, reason: key);
      expect(s.skip, isNotNull, reason: key);
    }
    for (final key in ['skip_after_failures', 'skip_minutes']) {
      final s = ChecklistSettings.fromJson({...full}..remove(key))!;
      expect(s.skip, isNull, reason: key);
      expect(s.lastPass, isNotNull, reason: key);
    }
    for (final key in ['fallback_links', 'fallback_parallel']) {
      final s = ChecklistSettings.fromJson({...full}..remove(key))!;
      expect(s.fallback, isNull, reason: key);
      expect(s.lastPass, isNotNull, reason: key);
    }
  });

  test('without swept_open_minutes the sweep does not change the order', () {
    final s = ChecklistSettings.fromJson(
      {...full}..remove('swept_open_minutes'),
    )!;
    expect(s.lastPass, isNotNull);
    expect(s.lastPass!.sweptOpenFor, isNull);
  });

  test('a value that is not a whole number above zero turns its part off', () {
    for (final bad in [0, -3, 2.5, '16', true, null]) {
      final s = ChecklistSettings.fromJson({...full, 'last_pass_doors': bad});
      expect(s!.lastPass, isNull, reason: '$bad');
      final t = ChecklistSettings.fromJson({...full, 'skip_minutes': bad});
      expect(t!.skip, isNull, reason: '$bad');
      final u = ChecklistSettings.fromJson({...full, 'fallback_parallel': bad});
      expect(u!.fallback, isNull, reason: '$bad');
    }
  });

  test('reads back what it writes', () {
    final s = ChecklistSettings.fromJson(full)!;
    expect(s.toJson(), full);
    final partial = ChecklistSettings.fromJson({
      'skip_after_failures': 2,
      'skip_minutes': 15,
    })!;
    expect(ChecklistSettings.fromJson(partial.toJson())!.skip!.failures, 2);
    expect(ChecklistSettings.fromJson(partial.toJson())!.lastPass, isNull);
  });

  group('the fallback and retry numbers', () {
    test('are read when the backend sends them', () {
      final s = ChecklistSettings.fromJson({
        'fallback_links': 16,
        'fallback_parallel': 8,
        'fallback_after_ms': 8000,
        'fallback_standby': 3,
        'own_first_doors': 1,
        'fallback_closed_minutes': 30,
        'retry_seconds': [5, 10, 20, 30],
      })!;
      expect(s.fallback!.after, const Duration(seconds: 8));
      expect(s.fallback!.standby, 3);
      expect(s.fallback!.ownFirst, 1);
      expect(s.fallback!.closedFor, const Duration(minutes: 30));
      expect(s.retry!.after, [
        const Duration(seconds: 5),
        const Duration(seconds: 10),
        const Duration(seconds: 20),
        const Duration(seconds: 30),
      ]);
      expect(ChecklistSettings.fromJson(s.toJson())!.toJson(), s.toJson());
    });

    test('each is off when missing or not a whole number above zero', () {
      for (final bad in [null, 0, -1, 2.5, '8000']) {
        final s = ChecklistSettings.fromJson({
          'fallback_links': 16,
          'fallback_parallel': 8,
          'fallback_after_ms': bad,
          'fallback_standby': bad,
          'own_first_doors': bad,
          'fallback_closed_minutes': bad,
        })!;
        expect(s.fallback!.after, isNull, reason: '$bad');
        expect(s.fallback!.standby, isNull, reason: '$bad');
        expect(s.fallback!.ownFirst, isNull, reason: '$bad');
        expect(s.fallback!.closedFor, isNull, reason: '$bad');
      }
    });

    test('a retry list with anything but whole seconds above zero is off', () {
      for (final bad in [
        <Object?>[],
        [5, 0],
        [5, -1],
        [5, '10'],
        [5, null],
        'often',
      ]) {
        expect(
          ChecklistSettings.fromJson({'retry_seconds': bad}),
          isNull,
          reason: '$bad',
        );
      }
      final only = ChecklistSettings.fromJson({
        'retry_seconds': [5],
      })!;
      expect(only.retry!.after, [const Duration(seconds: 5)]);
      expect(only.fallback, isNull);
    });

    // Keep searching (#269): past the backend's waits the tap goes on
    // trying. A backend that says nothing gets it, and 0 turns it off.
    test('the longest wait is ten minutes when the backend does not say, off '
        'with 0 or a bad value, and kept through a save', () {
      RetrySettings retry(Object? longest) => ChecklistSettings.fromJson({
        'retry_seconds': [5],
        'retry_longest_seconds': ?longest,
      })!.retry!;
      expect(retry(null).longest, RetrySettings.standardLongest);
      expect(retry(900).longest, const Duration(seconds: 900));
      for (final off in [0, -1, 2.5, '600', 86401]) {
        expect(retry(off).longest, isNull, reason: '$off');
      }
      for (final r in [retry(null), retry(900), retry(0)]) {
        final saved = ChecklistSettings(retry: r).toJson();
        expect(ChecklistSettings.fromJson(saved)!.retry!.longest, r.longest);
      }
    });

    test('a wait after no internet asks for the way back every 20 seconds '
        'when the backend does not say, and not at all with 0', () {
      RetrySettings retry(Object? recheck) => ChecklistSettings.fromJson({
        'retry_seconds': [5],
        'retry_recheck_seconds': ?recheck,
      })!.retry!;
      expect(retry(null).recheck, RetrySettings.standardRecheck);
      expect(RetrySettings.standardRecheck, const Duration(seconds: 20));
      expect(RetrySettings.standard.recheck, RetrySettings.standardRecheck);
      expect(retry(45).recheck, const Duration(seconds: 45));
      for (final off in [0, -1, 4, 2.5, '20', 3601]) {
        expect(retry(off).recheck, isNull, reason: '$off');
      }
      for (final r in [retry(null), retry(45), retry(0)]) {
        final saved = ChecklistSettings(retry: r).toJson();
        expect(ChecklistSettings.fromJson(saved)!.retry!.recheck, r.recheck);
      }
    });
  });

  group('the sites inside the country', () {
    test('are read when the backend sends them, alone too, and kept through '
        'a save', () {
      final s = ChecklistSettings.fromJson({
        'home_control_urls': ['https://a.example/', 'https://b.example/x'],
      })!;
      expect(s.homeControl, ['https://a.example/', 'https://b.example/x']);
      expect(s.retry, isNull);
      expect(
        ChecklistSettings.fromJson(s.toJson())!.homeControl,
        s.homeControl,
      );
    });

    test('an empty list is the backend turning the check off', () {
      final s = ChecklistSettings.fromJson({'home_control_urls': <Object>[]})!;
      expect(s.homeControl, isEmpty);
    });

    test('a list the app cannot use leaves it its own', () {
      for (final bad in [
        'https://a.example/',
        ['http://a.example/'],
        ['https://a.example/', 5],
        ['not a site'],
        [for (var i = 0; i < 7; i++) 'https://a$i.example/'],
      ]) {
        final s = ChecklistSettings.fromJson({
          'home_control_urls': bad,
          'retry_seconds': [5],
        })!;
        expect(s.homeControl, isNull, reason: '$bad');
      }
    });
  });

  // How the own doors are checked: several at once unless the backend says
  // otherwise. door_parallel 1 is the backend's switch back to the search
  // of 1.7.0, so a bad value must never turn the checks off or into
  // something the app was not built for.
  group('the door checks', () {
    test('are read when the backend sends them, alone too', () {
      final s = ChecklistSettings.fromJson({
        'door_parallel': 3,
        'door_stagger_ms': 500,
      })!;
      expect(s.doors!.parallel, 3);
      expect(s.doors!.stagger, const Duration(milliseconds: 500));
      expect(s.lastPass, isNull);
      expect(s.skip, isNull);
      expect(s.fallback, isNull);
      expect(s.retry, isNull);
    });

    test('are null when the backend sends neither, which the connect flow '
        'reads as the standard', () {
      expect(ChecklistSettings.fromJson(full)!.doors, isNull);
      expect(DoorCheckSettings.standard.parallel, 4);
      expect(DoorCheckSettings.standard.stagger, const Duration(seconds: 1));
    });

    test('door_parallel 1 is one at a time', () {
      final s = ChecklistSettings.fromJson({'door_parallel': 1})!;
      expect(s.doors!.parallel, 1);
    });

    test('the ends of each range are kept', () {
      for (final (parallel, ms) in [(1, 0), (8, 5000)]) {
        final s = ChecklistSettings.fromJson({
          'door_parallel': parallel,
          'door_stagger_ms': ms,
        })!;
        expect(s.doors!.parallel, parallel);
        expect(s.doors!.stagger, Duration(milliseconds: ms));
      }
    });

    test('a door_parallel out of range, or not a whole number, is the '
        'standard one', () {
      for (final bad in [0, -1, 9, 64, 2.5, '4', true]) {
        final s = ChecklistSettings.fromJson({
          'door_parallel': bad,
          'door_stagger_ms': 250,
        })!;
        expect(
          s.doors!.parallel,
          DoorCheckSettings.standard.parallel,
          reason: '$bad',
        );
        expect(s.doors!.stagger, const Duration(milliseconds: 250));
      }
    });

    test('a door_stagger_ms missing, out of range, or not a whole number is '
        'the standard one', () {
      for (final bad in [null, -1, 5001, 60000, 2.5, '1000']) {
        final s = ChecklistSettings.fromJson({
          'door_parallel': 2,
          'door_stagger_ms': bad,
        })!;
        expect(s.doors!.parallel, 2, reason: '$bad');
        expect(
          s.doors!.stagger,
          DoorCheckSettings.standard.stagger,
          reason: '$bad',
        );
      }
      final zero = ChecklistSettings.fromJson({
        'door_parallel': 2,
        'door_stagger_ms': 0,
      })!;
      expect(zero.doors!.stagger, Duration.zero);
    });

    test('a block with no usable value for either is no part', () {
      expect(
        ChecklistSettings.fromJson({'door_parallel': 0, 'door_stagger_ms': -5}),
        isNull,
      );
      expect(
        ChecklistSettings.fromJson({
          ...full,
          'door_parallel': '4',
          'door_stagger_ms': 9999,
        })!.doors,
        isNull,
      );
    });

    test('reads back what it writes', () {
      final s = ChecklistSettings.fromJson({
        ...full,
        'door_parallel': 6,
        'door_stagger_ms': 750,
      })!;
      final back = ChecklistSettings.fromJson(s.toJson())!;
      expect(back.doors!.parallel, 6);
      expect(back.doors!.stagger, const Duration(milliseconds: 750));
      expect(back.toJson(), s.toJson());
      expect(back.lastPass!.doors, 16);

      final config = AppConfig.fromJson(
        configJson({'door_parallel': 1, 'door_stagger_ms': 0}),
      );
      final again = AppConfig.fromJson(config.toJson()).checklist!.doors!;
      expect(again.parallel, 1);
      expect(again.stagger, Duration.zero);
    });
  });

  // The remembered door's dial on its own: on 2026-10-23, 113 of them
  // failed at about 21 seconds each before the checklist started.
  group('the fast path times', () {
    test('are read when the backend sends them, alone too', () {
      final s = ChecklistSettings.fromJson({
        'fast_path_beside_ms': 4000,
        'fast_path_forget_ms': 7000,
      })!;
      expect(s.fastPath!.besideAfter, const Duration(milliseconds: 4000));
      expect(s.fastPath!.forgetAfter, const Duration(milliseconds: 7000));
      expect(s.doors, isNull);
      expect(s.fallback, isNull);
    });

    test('are null when the backend sends neither, which the connect flow '
        'reads as the standard', () {
      expect(ChecklistSettings.fromJson(full)!.fastPath, isNull);
      expect(FastPathSettings.standard.besideAfter, const Duration(seconds: 5));
      expect(FastPathSettings.standard.forgetAfter, const Duration(seconds: 5));
    });

    test('0 turns each part off on its own', () {
      final s = ChecklistSettings.fromJson({
        'fast_path_beside_ms': 0,
        'fast_path_forget_ms': 6000,
      })!;
      expect(s.fastPath!.besideAfter, isNull);
      expect(s.fastPath!.forgetAfter, const Duration(milliseconds: 6000));
      final t = ChecklistSettings.fromJson({'fast_path_forget_ms': 0})!;
      expect(t.fastPath!.forgetAfter, isNull);
      expect(t.fastPath!.besideAfter, FastPathSettings.standard.besideAfter);
    });

    test('a value missing, out of range, or not a whole number is the '
        'standard one', () {
      for (final bad in [null, -1, 45001, 2.5, '5000', true]) {
        final s = ChecklistSettings.fromJson({
          'fast_path_beside_ms': bad,
          'fast_path_forget_ms': 3000,
        })!;
        expect(
          s.fastPath!.besideAfter,
          FastPathSettings.standard.besideAfter,
          reason: '$bad',
        );
        expect(
          s.fastPath!.forgetAfter,
          const Duration(milliseconds: 3000),
          reason: '$bad',
        );
      }
      final most = ChecklistSettings.fromJson({'fast_path_beside_ms': 45000})!;
      expect(most.fastPath!.besideAfter, const Duration(seconds: 45));
    });

    test('a block with no usable value for either is no part', () {
      expect(
        ChecklistSettings.fromJson({
          'fast_path_beside_ms': -1,
          'fast_path_forget_ms': '5000',
        }),
        isNull,
      );
    });

    test('reads back what it writes, the parts turned off too', () {
      final s = ChecklistSettings.fromJson({
        ...full,
        'fast_path_beside_ms': 0,
        'fast_path_forget_ms': 8000,
      })!;
      final back = ChecklistSettings.fromJson(s.toJson())!;
      expect(back.fastPath!.besideAfter, isNull);
      expect(back.fastPath!.forgetAfter, const Duration(milliseconds: 8000));
      expect(back.toJson(), s.toJson());
      expect(back.lastPass!.doors, 16);
    });

    test('skipping the fast path on no network is off unless the backend '
        'sends true', () {
      expect(FastPathSettings.standard.skipOffline, isFalse);
      expect(
        ChecklistSettings.fromJson({
          'fast_path_beside_ms': 4000,
        })!.fastPath!.skipOffline,
        isFalse,
      );
      for (final notTrue in [false, 'true', 1, null]) {
        final s = ChecklistSettings.fromJson({
          'fast_path_forget_ms': 3000,
          'fast_path_skip_offline': notTrue,
        })!;
        expect(s.fastPath!.skipOffline, isFalse, reason: '$notTrue');
      }
    });

    test('skipping the fast path on no network is a part on its own, and '
        'keeps the standard times', () {
      final s = ChecklistSettings.fromJson({'fast_path_skip_offline': true})!;
      expect(s.fastPath!.skipOffline, isTrue);
      expect(s.fastPath!.besideAfter, FastPathSettings.standard.besideAfter);
      expect(s.fastPath!.forgetAfter, FastPathSettings.standard.forgetAfter);
    });

    test('skipping the fast path on no network reads back, and is not '
        'written while off', () {
      final on = ChecklistSettings.fromJson({
        ...full,
        'fast_path_skip_offline': true,
      })!;
      final back = ChecklistSettings.fromJson(on.toJson())!;
      expect(back.fastPath!.skipOffline, isTrue);
      expect(back.toJson(), on.toJson());

      final off = ChecklistSettings.fromJson({
        ...full,
        'fast_path_beside_ms': 4000,
      })!;
      expect(off.toJson(), isNot(contains('fast_path_skip_offline')));
    });
  });

  group('in the app config', () {
    test('is read from the checklist key', () {
      final config = AppConfig.fromJson(configJson(full));
      expect(config.checklist!.lastPass!.doors, 16);
      expect(AppConfig.fromJson(config.toJson()).checklist!.skip!.failures, 3);
    });

    test('is null when the backend sent none', () {
      final config = AppConfig.fromJson(configJson());
      expect(config.checklist, isNull);
      expect(config.toJson().containsKey('checklist'), isFalse);
    });

    test('a bad block never throws away the rest of the config', () {
      final config = AppConfig.fromJson(
        configJson({'last_pass_doors': 'many', 'skip_minutes': -1}),
      );
      expect(config.checklist, isNull);
      expect(config.supportEmail, 'support@example.com');
    });
  });
}
