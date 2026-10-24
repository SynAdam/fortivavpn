import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/update_check.dart';

void main() {
  group('compare', () {
    test('reads each part as a number, not as text', () {
      // The bug a string comparison makes: "1.10.0" sorts before "1.9.0".
      expect(UpdateCheck.compare('1.10.0', '1.9.0'), greaterThan(0));
      expect(UpdateCheck.compare('1.4.1', '1.4.10'), lessThan(0));
    });

    test('a missing part is a zero', () {
      expect(UpdateCheck.compare('1.4', '1.4.0'), 0);
      expect(UpdateCheck.compare('1.4', '1.4.1'), lessThan(0));
    });

    test('the build number is not part of the version', () {
      expect(UpdateCheck.compare('1.4.1+41', '1.4.1'), 0);
    });

    test('anything unreadable is null rather than a guess', () {
      expect(UpdateCheck.compare('not-a-version', '1.0.0'), isNull);
      expect(UpdateCheck.compare('1.0.0', ''), isNull);
      expect(UpdateCheck.compare(null, '1.0.0'), isNull);
    });
  });

  group('decide', () {
    UpdateNeed decide(
      String current,
      String latest,
      String minimum, {
      bool forced = false,
    }) => UpdateCheck.decide(
      current: current,
      latest: latest,
      minimum: minimum,
      serverSaysRequired: forced,
    );

    test('the newest build is told nothing', () {
      expect(decide('1.4.1', '1.4.1', '1.0.0'), UpdateNeed.none);
    });

    test('a build ahead of the store is told nothing', () {
      // An internal build, or a store listing that has not propagated yet.
      expect(decide('1.5.0', '1.4.1', '1.0.0'), UpdateNeed.none);
    });

    test('a build behind the store is offered an update', () {
      expect(decide('1.3.1', '1.4.1', '1.0.0'), UpdateNeed.optional);
    });

    test('a build below the minimum cannot dismiss it', () {
      expect(decide('1.2.0', '1.4.1', '1.3.0'), UpdateNeed.required);
    });

    test('the backend can force an update without moving the numbers', () {
      expect(
        decide('1.4.1', '1.4.1', '1.0.0', forced: true),
        UpdateNeed.required,
      );
    });

    test('a version the app cannot read never locks the user out', () {
      // A typo in an environment variable must not be able to wall off
      // every user, so an unreadable version means no prompt at all.
      expect(decide('1.4.1', 'oops', 'oops'), UpdateNeed.none);
      expect(
        UpdateCheck.decide(current: 'oops', latest: '9.9.9', minimum: '9.9.9'),
        UpdateNeed.none,
      );
    });

    test('the default backend values prompt nobody', () {
      // Both versions ship as 1.0.0, so an unconfigured backend is silent
      // rather than telling every user they are out of date.
      expect(decide('1.4.1', '1.0.0', '1.0.0'), UpdateNeed.none);
    });
  });

  group('a minimum newer than the latest release', () {
    UpdateNeed decide(String current, String latest, String minimum) =>
        UpdateCheck.decide(current: current, latest: latest, minimum: minimum);

    test('is never forced, because no build can satisfy it', () {
      // The minimum raised to 1.6.11 before 1.6.11 reached the store.
      expect(decide('1.6.4', '1.6.10', '1.6.11'), isNot(UpdateNeed.required));
      expect(decide('1.0.0', '1.6.10', '9.9.9'), isNot(UpdateNeed.required));
    });

    test('falls back to offering the latest release', () {
      expect(decide('1.6.4', '1.6.10', '1.6.11'), UpdateNeed.optional);
    });

    test('says nothing to a build already on the latest release', () {
      expect(decide('1.6.10', '1.6.10', '1.6.11'), UpdateNeed.none);
    });

    test('a minimum equal to the latest release is still forced', () {
      // The rule the bot follows: every release becomes the minimum once
      // it is live.
      expect(decide('1.6.10', '1.6.11', '1.6.11'), UpdateNeed.required);
    });

    test('an unreadable latest leaves the minimum as it was', () {
      expect(decide('1.6.3', 'oops', '1.6.4'), UpdateNeed.required);
    });
  });

  group('UpdateOpens', () {
    late DateTime now;
    late UpdateOpens opens;

    setUp(() {
      now = DateTime(2026, 10, 6, 12);
      opens = UpdateOpens(now: () => now);
    });

    /// Send the app to the background for [away] and bring it back.
    bool away(Duration away) {
      opens.wentToBackground();
      now = now.add(away);
      return opens.cameBack();
    }

    test('nothing is held on a cold start', () {
      expect(opens.optionalHeld, isFalse);
    });

    test('Later holds for the rest of the open', () {
      opens.optionalAnswered();
      expect(opens.optionalHeld, isTrue);
    });

    test('a quick switch to another app is the same open', () {
      opens.optionalAnswered();
      expect(away(const Duration(minutes: 14, seconds: 59)), isFalse);
      expect(opens.optionalHeld, isTrue);
    });

    test('15 minutes in the background starts a new open', () {
      opens.optionalAnswered();
      expect(away(UpdateOpens.newOpenAfter), isTrue);
      expect(opens.optionalHeld, isFalse);
    });

    test('a stay in the background is timed from when it started', () {
      // Android reports several steps on the way out.
      opens.optionalAnswered();
      opens.wentToBackground();
      now = now.add(const Duration(minutes: 10));
      opens.wentToBackground();
      now = now.add(const Duration(minutes: 6));
      expect(opens.cameBack(), isTrue);
      expect(opens.optionalHeld, isFalse);
    });

    test('a clock moved back while away starts a new open', () {
      opens.optionalAnswered();
      expect(away(const Duration(hours: -2)), isTrue);
      expect(opens.optionalHeld, isFalse);
    });

    test('coming back without having left is not a new open', () {
      // A system dialog, such as the VPN permission prompt, resumes the
      // app without it ever going to the background.
      opens.optionalAnswered();
      expect(opens.cameBack(), isFalse);
      expect(opens.optionalHeld, isTrue);
    });
  });
}
