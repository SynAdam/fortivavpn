import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/account_service.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/device_state.dart';
import 'package:fortiva_vpn/services/report_queue.dart';
import 'package:fortiva_vpn/services/session_tracker.dart';

/// Tests for the account deletion path required by App Store Review
/// Guideline 5.1.1(v).
///
/// The network half is covered by the backend's own tests; what is worth
/// pinning here is the local clean-up, because a key that nobody
/// remembers to clear leaves user data on the phone after the user was
/// told it was gone.
void main() {
  group('AccountService preference coverage', () {
    /// Every SharedPreferences key the app writes, read out of the source
    /// rather than listed by hand so a new one cannot go unnoticed.
    ///
    /// Write sites name the key either as a literal or as a `static const`
    /// holding one, so both are resolved. A site the scan cannot resolve
    /// is reported rather than skipped, because a silent miss here turns
    /// this whole test into a rubber stamp.
    ({Set<String> keys, List<String> unresolved}) writtenPrefKeys() {
      final writes = RegExp(
        // `prefs?.` as well as `prefs.`: a null-aware write stores the
        // same key, and matching only the plain form made those sites
        // invisible to this scan rather than merely unresolved.
        // A constant named through its class (Keeper.stalledKey) is
        // resolved by its own name.
        r"""prefs\??\.(?:set[A-Za-z]+|remove)\(\s*(?:\n\s*)?(?:[A-Z][A-Za-z0-9_]*\.)?([A-Za-z0-9_']+)""",
      );
      final constant = RegExp(
        r"""static const (?:String )?([A-Za-z0-9_]+) =\s*'([A-Za-z0-9_]+)'""",
      );

      final sources = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        sources.add(entity.readAsStringSync());
      }

      // Many files have a constant of the same name (storageKey), so a
      // write is resolved by its own file's constant first, and only then
      // by every value that name has anywhere. One map of name to value
      // kept only the last file's, and the other files' keys went unseen.
      Map<String, String> constantsIn(String source) => {
        for (final match in constant.allMatches(source))
          match.group(1)!: match.group(2)!,
      };
      final everywhere = <String, Set<String>>{};
      for (final source in sources) {
        constantsIn(source).forEach((name, value) {
          everywhere.putIfAbsent(name, () => <String>{}).add(value);
        });
      }

      final keys = <String>{};
      final unresolved = <String>[];
      for (final source in sources) {
        final local = constantsIn(source);
        for (final match in writes.allMatches(source)) {
          final argument = match.group(1)!;
          if (argument.startsWith("'")) {
            keys.add(argument.replaceAll("'", ''));
          } else if (local.containsKey(argument)) {
            keys.add(local[argument]!);
          } else if (everywhere.containsKey(argument)) {
            keys.addAll(everywhere[argument]!);
          } else if (argument != 'key') {
            // 'key' is AccountService's own loop variable over the list
            // this test is checking, so it is not a missed write site.
            unresolved.add(argument);
          }
        }
      }
      return (keys: keys, unresolved: unresolved);
    }

    test('every key the app writes is either cleared or kept on purpose', () {
      final accounted = {
        ...AccountService.accountPrefKeys,
        ...AccountService.keptPrefKeys,
      };
      final scan = writtenPrefKeys();
      expect(
        scan.unresolved,
        isEmpty,
        reason:
            'The scan could not resolve these preference keys to a string, '
            'so it cannot tell whether deletion clears them.',
      );
      final unaccounted = scan.keys.difference(accounted);

      expect(
        unaccounted,
        isEmpty,
        reason:
            'These preference keys are written by the app but neither '
            'cleared on account deletion nor listed as deliberately kept. '
            'Add each to AccountService.accountPrefKeys or '
            'AccountService.keptPrefKeys.',
      );
    });

    test('every network key removed twice is one the deletion clears', () {
      expect(
        AccountService.accountPrefKeys,
        containsAll(AccountService.networkPrefKeys),
      );
    });

    test('the scan actually finds keys, so an empty result is not a pass', () {
      final keys = writtenPrefKeys().keys;
      expect(keys, contains('fortiva_connection_sessions'));
      expect(keys, contains('fortivavpn_device_id'));
      expect(keys, contains('pref_remote_dns'));
      // Several files name their key storageKey; each must be found.
      expect(
        keys,
        containsAll(['fortiva_path_memory', 'fortiva_door_sweep_marks']),
      );
      expect(keys.length, greaterThanOrEqualTo(9));
    });

    test('every report queue is cleared', () {
      // ReportQueue writes through its storageKey field, which the scan
      // above reads as VpnEventReporter's constant of the same name, so the
      // scan cannot see these keys.
      expect(AccountService.accountPrefKeys, containsAll(ReportQueue.allKeys));
    });

    test('a key is never both cleared and kept', () {
      expect(
        AccountService.accountPrefKeys.toSet().intersection(
          AccountService.keptPrefKeys.toSet(),
        ),
        isEmpty,
      );
    });

    test('the chosen language survives deletion', () {
      // Resetting it would drop the user back to English in the middle of
      // a flow they just confirmed in their own language.
      expect(AccountService.keptPrefKeys, contains('pref_locale'));
      expect(AccountService.accountPrefKeys, isNot(contains('pref_locale')));
    });

    test('connection history and the last connected server are erased', () {
      expect(
        AccountService.accountPrefKeys,
        containsAll([
          'fortiva_connection_sessions',
          'vpn_connected_server_id',
          'vpn_connected_server_name',
          'vpn_connected_start_time',
        ]),
      );
    });

    test('the Premium offers start over for a new account', () {
      // When the limit sheet and the calm card last showed, the note after
      // Premium ended, and whether the tunnel has worked: all of it is
      // about this account's use and Premium.
      expect(
        AccountService.accountPrefKeys,
        containsAll([
          'limit_sheet_shown_for',
          'premium_prompt_state',
          'renewal_lapse_seen',
          'upsell_after_first_connect',
        ]),
      );
    });

    test('the app comes back looking like a first launch', () {
      expect(
        AccountService.accountPrefKeys,
        contains('fortiva_onboarding_completed'),
      );
    });

    test('the device id is not cleared through preferences alone', () {
      // It also lives in the Keychain / EncryptedSharedPreferences, so
      // removing only the plain-prefs mirror would leave the real value
      // behind. DeviceIdentity.clear() owns both.
      expect(
        AccountService.accountPrefKeys,
        isNot(contains('fortivavpn_device_id')),
      );
      expect(AccountService.keptPrefKeys, contains('fortivavpn_device_id'));
    });
  });

  group('state resets', () {
    test('DeviceState.reset clears the cached device and notifies', () {
      final state = DeviceState();
      var notified = 0;
      state.addListener(() => notified++);

      state.reset();

      expect(state.device, isNull);
      expect(state.isRegistered, isFalse);
      expect(state.isPremium, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.isLoading, isFalse);
      expect(notified, 1);
    });

    test('SessionTracker.clear empties the history it holds in memory', () {
      // The stored copy is only half of it: an in-memory list that
      // survives gets written straight back by the next endSession().
      final tracker = SessionTracker();
      var notified = 0;
      tracker.addListener(() => notified++);

      tracker.startSession(
        serverName: 'Fortiva FI Helsinki',
        serverCountry: 'Finland',
        serverFlagEmoji: '\u{1F1EB}\u{1F1EE}',
      );
      expect(tracker.activeSession, isNotNull);

      tracker.clear();

      expect(tracker.sessions, isEmpty);
      expect(tracker.activeSession, isNull);
      expect(tracker.totalSessions, 0);
      expect(tracker.totalConnectionTime, Duration.zero);
      expect(notified, greaterThanOrEqualTo(2));
    });

    test('DedicatedState.reset drops configs, quota and the account', () {
      final state = DedicatedState();
      var notified = 0;
      state.addListener(() => notified++);

      state.reset();

      expect(state.configs, isEmpty);
      expect(state.hasConfigs, isFalse);
      expect(state.quota, isNull);
      expect(state.isBlocked, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.selectedByUser, isFalse);
      expect(notified, 1);
    });
  });
}
