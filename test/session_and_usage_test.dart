import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/connection_session.dart';
import 'package:fortiva_vpn/data/models/usage_stats.dart';
import 'package:fortiva_vpn/services/session_tracker.dart';

ConnectionSession session({
  required String id,
  required DateTime start,
  Duration? length,
  int? latency,
}) {
  return ConnectionSession(
    id: id,
    serverName: 'Fortiva FI Helsinki',
    serverCountry: 'FI',
    serverFlagEmoji: '\u{1F1EB}\u{1F1EE}',
    startTime: start,
    endTime: length == null ? null : start.add(length),
    avgLatencyMs: latency,
  );
}

void main() {
  group('UsageStats arithmetic', () {
    test('totalBytes is upload plus download', () {
      final stats = UsageStats(
        totalBytesUploaded: 1_500,
        totalBytesDownloaded: 8_500,
      );
      expect(stats.totalBytes, 10_000);
    });

    test('a fresh instance is all zeroes', () {
      final stats = UsageStats();
      expect(stats.totalBytes, 0);
      expect(stats.totalConnections, 0);
      expect(stats.totalConnectionTime, Duration.zero);
    });

    test('averageSessionDuration divides time by connections', () {
      final stats = UsageStats(
        totalConnections: 4,
        totalConnectionTime: const Duration(minutes: 20),
      );
      expect(stats.averageSessionDuration, const Duration(minutes: 5));
    });

    test('zero connections does not divide by zero', () {
      final stats = UsageStats(
        totalConnections: 0,
        totalConnectionTime: const Duration(minutes: 20),
      );
      expect(stats.averageSessionDuration, Duration.zero);
    });

    test('the average truncates to whole seconds', () {
      // Integer division, so 10s over 3 sessions is 3s and not 3.33s.
      final stats = UsageStats(
        totalConnections: 3,
        totalConnectionTime: const Duration(seconds: 10),
      );
      expect(stats.averageSessionDuration, const Duration(seconds: 3));
    });

    test('sub-second totals average to zero rather than to a fraction', () {
      final stats = UsageStats(
        totalConnections: 2,
        totalConnectionTime: const Duration(milliseconds: 900),
      );
      expect(stats.averageSessionDuration, Duration.zero);
    });

    test('copyWith replaces only what it is given', () {
      final original = UsageStats(
        totalConnections: 3,
        totalBytesUploaded: 100,
        totalBytesDownloaded: 200,
        totalConnectionTime: const Duration(minutes: 6),
      );

      final updated = original.copyWith(totalConnections: 4);

      expect(updated.totalConnections, 4);
      expect(updated.totalBytesUploaded, 100);
      expect(updated.totalBytesDownloaded, 200);
      expect(updated.totalConnectionTime, const Duration(minutes: 6));
    });

    test('a round trip through JSON preserves every counter', () {
      final original = UsageStats(
        totalConnections: 7,
        totalBytesUploaded: 12_345,
        totalBytesDownloaded: 67_890,
        totalConnectionTime: const Duration(hours: 2, minutes: 30),
        lastUpdated: DateTime.utc(2026, 8, 24, 12),
      );

      final restored = UsageStats.fromJson(original.toJson());

      expect(restored.totalConnections, 7);
      expect(restored.totalBytesUploaded, 12_345);
      expect(restored.totalBytesDownloaded, 67_890);
      expect(
        restored.totalConnectionTime,
        const Duration(hours: 2, minutes: 30),
      );
      expect(restored.lastUpdated, DateTime.utc(2026, 8, 24, 12));
    });

    test('JSON with missing fields reads as zero, not as an error', () {
      final restored = UsageStats.fromJson(const {});
      expect(restored.totalConnections, 0);
      expect(restored.totalBytes, 0);
      expect(restored.totalConnectionTime, Duration.zero);
    });

    test('duration survives as seconds, so sub-second precision is lost', () {
      final original = UsageStats(
        totalConnectionTime: const Duration(seconds: 90, milliseconds: 500),
      );
      final restored = UsageStats.fromJson(original.toJson());
      expect(restored.totalConnectionTime, const Duration(seconds: 90));
    });
  });

  group('ConnectionSession duration', () {
    test('a finished session measures end minus start', () {
      final s = session(
        id: '1',
        start: DateTime(2026, 8, 24, 10),
        length: const Duration(minutes: 45),
      );
      expect(s.duration, const Duration(minutes: 45));
      expect(s.isActive, isFalse);
    });

    test('an unfinished session is active and still counting', () {
      final s = session(id: '1', start: DateTime.now());
      expect(s.isActive, isTrue);
      expect(s.duration, greaterThanOrEqualTo(Duration.zero));
    });

    test('a round trip through the stored form keeps the times', () {
      final s = session(
        id: 'abc',
        start: DateTime.utc(2026, 8, 24, 9),
        length: const Duration(minutes: 12),
        latency: 47,
      );

      final restored = ConnectionSession.decodeList(
        ConnectionSession.encodeList([s]),
      ).single;

      expect(restored.id, 'abc');
      expect(restored.startTime, s.startTime);
      expect(restored.endTime, s.endTime);
      expect(restored.avgLatencyMs, 47);
      expect(restored.duration, const Duration(minutes: 12));
    });

    test('a stored session with no flag falls back to the globe', () {
      final restored = ConnectionSession.fromJson({
        'id': '1',
        'serverName': 'x',
        'serverCountry': 'FI',
        'startTime': DateTime.utc(2026, 8, 24).toIso8601String(),
      });
      expect(restored.serverFlagEmoji, '\u{1F30D}');
      expect(restored.isActive, isTrue);
    });
  });

  group('SessionTracker accounting', () {
    test('an empty tracker reports zeroes rather than dividing by zero', () {
      final tracker = SessionTracker();
      expect(tracker.totalSessions, 0);
      expect(tracker.totalConnectionTime, Duration.zero);
      expect(tracker.averageSessionDuration, Duration.zero);
      expect(tracker.sessions, isEmpty);
      expect(tracker.activeSession, isNull);
    });

    test('startSession opens an active session and notifies', () {
      final tracker = SessionTracker();
      var notified = 0;
      tracker.addListener(() => notified++);

      tracker.startSession(
        serverName: 'Fortiva FI Helsinki',
        serverCountry: 'FI',
        serverFlagEmoji: '\u{1F1EB}\u{1F1EE}',
      );

      expect(tracker.activeSession, isNotNull);
      expect(tracker.activeSession!.isActive, isTrue);
      expect(tracker.activeSession!.serverName, 'Fortiva FI Helsinki');
      // Not in the history until it ends.
      expect(tracker.totalSessions, 0);
      expect(notified, 1);
    });

    test('the exposed session list cannot be mutated by a caller', () {
      final tracker = SessionTracker();
      expect(
        () => tracker.sessions.add(
          session(id: '1', start: DateTime.now(), length: Duration.zero),
        ),
        throwsUnsupportedError,
      );
    });

    test('todaySessions and weekSessions filter by start time', () {
      // Exercised through the model rather than the tracker, whose
      // history is only reachable via SharedPreferences.
      //
      // The clock is pinned rather than read. This used to start from
      // DateTime.now() and place "today" an hour before it, which lands on
      // yesterday whenever the test runs in the first hour of a day. CI
      // runs in UTC, so it failed for one hour in every twenty-four and
      // passed on a rerun, which is the worst way for a test to fail.
      final now = DateTime(2026, 8, 25, 14, 30);
      final today = session(
        id: '1',
        start: now.subtract(const Duration(hours: 1)),
        length: const Duration(minutes: 5),
      );
      final lastWeek = session(
        id: '2',
        start: now.subtract(const Duration(days: 9)),
        length: const Duration(minutes: 5),
      );

      final startOfToday = DateTime(now.year, now.month, now.day);
      final weekAgo = now.subtract(const Duration(days: 7));

      expect(today.startTime.isAfter(startOfToday), isTrue);
      expect(lastWeek.startTime.isAfter(startOfToday), isFalse);
      expect(today.startTime.isAfter(weekAgo), isTrue);
      expect(lastWeek.startTime.isAfter(weekAgo), isFalse);
    });

    test('just after midnight, an hour ago is yesterday', () {
      // The case that made the test above flaky, pinned as behaviour
      // rather than left to whatever time CI happens to run at. A session
      // an hour before 00:30 belongs to yesterday, and "today" is right to
      // exclude it.
      final now = DateTime(2026, 8, 25, 0, 30);
      final anHourAgo = session(
        id: '1',
        start: now.subtract(const Duration(hours: 1)),
        length: const Duration(minutes: 5),
      );

      final startOfToday = DateTime(now.year, now.month, now.day);
      expect(anHourAgo.startTime.isAfter(startOfToday), isFalse);
      expect(
        anHourAgo.startTime.isAfter(now.subtract(const Duration(days: 7))),
        isTrue,
      );
    });
  });
}
