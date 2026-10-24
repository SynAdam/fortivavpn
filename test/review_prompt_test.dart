import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/review_prompt.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 10:00 in Tehran on 2026-10-06.
final _t0 = DateTime.utc(2026, 10, 6, 6, 30);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late String? installer;
  late int requests;
  late Object? requestError;

  ReviewPrompt make() => ReviewPrompt(
    installer: () async => installer,
    request: () async {
      requests++;
      if (requestError != null) throw requestError!;
      return {'ok': true};
    },
    openListing: () async => true,
    clock: () => now,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = _t0;
    installer = ReviewPrompt.playInstaller;
    requests = 0;
    requestError = null;
  });

  /// A verified connect on each of [days] Tehran days, ending at [_t0].
  Future<void> goodDays(ReviewPrompt review, int days) async {
    for (var i = days - 1; i >= 0; i--) {
      now = _t0.subtract(Duration(days: i));
      review.record(VpnEventType.connected);
      // A second connect the same day counts once.
      review.record(VpnEventType.connected);
    }
    now = _t0;
  }

  /// A tunnel up long enough, as of now.
  DateTime longEnough() => now.subtract(ReviewPrompt.minSession);

  test('due on the third day with a tunnel up five minutes', () async {
    final review = make();
    await goodDays(review, 3);
    expect(await review.due(enabled: true, upSince: longEnough()), isTrue);
  });

  test('not due after two days, however many connects', () async {
    final review = make();
    await goodDays(review, 2);
    for (var i = 0; i < 10; i++) {
      review.record(VpnEventType.connected);
    }
    expect(await review.due(enabled: true, upSince: longEnough()), isFalse);
  });

  test('not due while the switch is off', () async {
    final review = make();
    await goodDays(review, 3);
    expect(await review.due(enabled: false, upSince: longEnough()), isFalse);
  });

  test('not due on an install that did not come from Play', () async {
    for (final other in [
      null,
      'org.telegram.messenger',
      'com.google.android.packageinstaller',
    ]) {
      SharedPreferences.setMockInitialValues({});
      installer = other;
      final review = make();
      await goodDays(review, 3);
      expect(
        await review.due(enabled: true, upSince: longEnough()),
        isFalse,
        reason: '$other',
      );
      expect(review.fromPlay, isFalse);
    }
  });

  test('knows a Play install, for the Settings item', () async {
    final review = make();
    await review.due(enabled: false, upSince: null);
    expect(review.fromPlay, isTrue);
  });

  test('not due until the tunnel has been up five minutes', () async {
    final review = make();
    await goodDays(review, 3);
    final justUp = now.subtract(const Duration(minutes: 4, seconds: 59));
    expect(await review.due(enabled: true, upSince: justUp), isFalse);
    expect(await review.due(enabled: true, upSince: null), isFalse);
  });

  test('a failure or a drop holds the ask for a day', () async {
    for (final failure in [
      VpnEventType.connectFailed,
      VpnEventType.verifyFailed,
      VpnEventType.dropped,
    ]) {
      SharedPreferences.setMockInitialValues({});
      final review = make();
      await goodDays(review, 3);
      review.record(failure);
      now = _t0.add(const Duration(hours: 23, minutes: 59));
      expect(
        await review.due(enabled: true, upSince: longEnough()),
        isFalse,
        reason: '$failure',
      );
      now = _t0.add(const Duration(hours: 24));
      expect(
        await review.due(enabled: true, upSince: longEnough()),
        isTrue,
        reason: '$failure',
      );
    }
  });

  test('a user disconnect or a heartbeat is not a failure', () async {
    final review = make();
    await goodDays(review, 3);
    review.record(VpnEventType.disconnected);
    review.record(VpnEventType.heartbeat);
    review.record(VpnEventType.doorSwitched);
    expect(await review.due(enabled: true, upSince: longEnough()), isTrue);
  });

  test('days are Tehran days', () async {
    final review = make();
    // 23:59 and 00:01 in Tehran: the same UTC date, two Tehran days.
    now = DateTime.utc(2026, 10, 4, 20, 29);
    review.record(VpnEventType.connected);
    now = DateTime.utc(2026, 10, 4, 20, 31);
    review.record(VpnEventType.connected);
    now = DateTime.utc(2026, 10, 5, 20, 31);
    review.record(VpnEventType.connected);
    expect(await review.due(enabled: true, upSince: longEnough()), isTrue);
    expect(
      ReviewPrompt.tehranDay(DateTime.utc(2026, 10, 4, 20, 29)),
      '2026-10-04',
    );
    expect(
      ReviewPrompt.tehranDay(DateTime.utc(2026, 10, 4, 20, 30)),
      '2026-10-05',
    );
  });

  test('asks once per run, then waits 90 days, at most three times', () async {
    var review = make();
    await goodDays(review, 3);
    await review.ask();
    expect(requests, 1);
    expect(review.askedThisRun, isTrue);
    expect(await review.due(enabled: true, upSince: longEnough()), isFalse);
    await review.ask();
    expect(requests, 1);

    // A new run the next day: the gap holds.
    now = _t0.add(const Duration(days: 1));
    review = make();
    expect(await review.due(enabled: true, upSince: longEnough()), isFalse);

    // After the gap, twice more, and then never again.
    for (var ask = 2; ask <= ReviewPrompt.maxAsks; ask++) {
      now = now.add(ReviewPrompt.askGap);
      review = make();
      expect(
        await review.due(enabled: true, upSince: longEnough()),
        isTrue,
        reason: 'ask $ask',
      );
      await review.ask();
    }
    expect(requests, ReviewPrompt.maxAsks);
    now = now.add(ReviewPrompt.askGap * 4);
    review = make();
    expect(await review.due(enabled: true, upSince: longEnough()), isFalse);
  });

  test('a failed request still counts as an ask and never throws', () async {
    final review = make();
    await goodDays(review, 3);
    requestError = Exception('Play is not there');
    await review.ask();
    expect(requests, 1);
    now = _t0.add(const Duration(days: 1));
    expect(await make().due(enabled: true, upSince: longEnough()), isFalse);
  });

  test('an unreadable record starts over instead of failing', () async {
    SharedPreferences.setMockInitialValues({ReviewPrompt.stateKey: '{nope'});
    final review = make();
    expect(await review.due(enabled: true, upSince: longEnough()), isFalse);
    await goodDays(review, 3);
    expect(await review.due(enabled: true, upSince: longEnough()), isTrue);
  });

  group('review_prompt flag', () {
    test('defaults to off and reads only a true', () {
      expect(FeatureFlags.fromJson({}).reviewPrompt, isFalse);
      expect(
        FeatureFlags.fromJson({'review_prompt': true}).reviewPrompt,
        isTrue,
      );
      expect(
        FeatureFlags.fromJson({'review_prompt': false}).reviewPrompt,
        isFalse,
      );
    });

    test('a value of the wrong type is off, not a broken config', () {
      for (final bad in ['true', 1, <String, dynamic>{}, null]) {
        expect(
          FeatureFlags.fromJson({'review_prompt': bad}).reviewPrompt,
          isFalse,
          reason: '$bad',
        );
      }
    });
  });
}
