import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/connection_session.dart';

/// Service to track and persist VPN connection sessions for analytics
class SessionTracker extends ChangeNotifier {
  static const _storageKey = 'fortiva_connection_sessions';
  static const _maxSessions = 100;

  List<ConnectionSession> _sessions = [];
  ConnectionSession? _activeSession;

  List<ConnectionSession> get sessions => List.unmodifiable(_sessions);
  ConnectionSession? get activeSession => _activeSession;

  /// Total number of sessions
  int get totalSessions => _sessions.length;

  /// Total connection time across all sessions
  Duration get totalConnectionTime {
    return _sessions.fold(Duration.zero, (sum, s) => sum + s.duration);
  }

  /// Average session duration
  Duration get averageSessionDuration {
    if (_sessions.isEmpty) return Duration.zero;
    return Duration(
      milliseconds: totalConnectionTime.inMilliseconds ~/ _sessions.length,
    );
  }

  /// Sessions from today
  List<ConnectionSession> get todaySessions {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _sessions.where((s) => s.startTime.isAfter(today)).toList();
  }

  /// Sessions from the last 7 days
  List<ConnectionSession> get weekSessions {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _sessions.where((s) => s.startTime.isAfter(weekAgo)).toList();
  }

  /// Daily connection time for the last 7 days (for chart)
  Map<DateTime, Duration> get dailyConnectionTime {
    final result = <DateTime, Duration>{};
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      result[day] = Duration.zero;
    }

    for (final session in weekSessions) {
      final day = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );
      if (result.containsKey(day)) {
        result[day] = result[day]! + session.duration;
      }
    }

    return result;
  }

  /// Load sessions from disk
  Future<void> loadSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        _sessions = ConnectionSession.decodeList(jsonStr);
        // Sort newest first
        _sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[SessionTracker] Error loading sessions: $e');
    }
  }

  /// Start tracking a new session
  void startSession({
    required String serverName,
    required String serverCountry,
    required String serverFlagEmoji,
  }) {
    _activeSession = ConnectionSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      serverName: serverName,
      serverCountry: serverCountry,
      serverFlagEmoji: serverFlagEmoji,
      startTime: DateTime.now(),
    );
    notifyListeners();
  }

  /// End the current session and persist
  Future<void> endSession({int? avgLatencyMs}) async {
    if (_activeSession == null) return;

    final completed = _activeSession!.copyWith(
      endTime: DateTime.now(),
      avgLatencyMs: avgLatencyMs,
    );

    _sessions.insert(0, completed);

    // Trim to max sessions
    if (_sessions.length > _maxSessions) {
      _sessions = _sessions.sublist(0, _maxSessions);
    }

    _activeSession = null;
    notifyListeners();
    await _persist();
  }

  /// Drop every recorded session, in memory and on disk.
  ///
  /// Called by account deletion. Clearing only the stored copy would not
  /// be enough: the in-memory list survives, the analytics screen keeps
  /// showing it, and the next endSession() writes the whole history back.
  Future<void> clear() async {
    _sessions = [];
    _activeSession = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('[SessionTracker] Error clearing sessions: $e');
    }
  }

  /// Persist sessions to disk
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        ConnectionSession.encodeList(_sessions),
      );
    } catch (e) {
      debugPrint('[SessionTracker] Error persisting sessions: $e');
    }
  }
}
