import 'dart:convert';

/// Model representing a VPN connection session for analytics
class ConnectionSession {
  final String id;
  final String serverName;
  final String serverCountry;
  final String serverFlagEmoji;
  final DateTime startTime;
  final DateTime? endTime;
  final int? avgLatencyMs;

  const ConnectionSession({
    required this.id,
    required this.serverName,
    required this.serverCountry,
    required this.serverFlagEmoji,
    required this.startTime,
    this.endTime,
    this.avgLatencyMs,
  });

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  bool get isActive => endTime == null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'serverName': serverName,
    'serverCountry': serverCountry,
    'serverFlagEmoji': serverFlagEmoji,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'avgLatencyMs': avgLatencyMs,
  };

  factory ConnectionSession.fromJson(Map<String, dynamic> json) {
    return ConnectionSession(
      id: json['id'] as String,
      serverName: json['serverName'] as String,
      serverCountry: json['serverCountry'] as String,
      serverFlagEmoji: json['serverFlagEmoji'] as String? ?? '🌍',
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      avgLatencyMs: json['avgLatencyMs'] as int?,
    );
  }

  ConnectionSession copyWith({DateTime? endTime, int? avgLatencyMs}) {
    return ConnectionSession(
      id: id,
      serverName: serverName,
      serverCountry: serverCountry,
      serverFlagEmoji: serverFlagEmoji,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      avgLatencyMs: avgLatencyMs ?? this.avgLatencyMs,
    );
  }

  /// Encode a list of sessions to JSON string for persistence
  static String encodeList(List<ConnectionSession> sessions) {
    return jsonEncode(sessions.map((s) => s.toJson()).toList());
  }

  /// Decode a list of sessions from JSON string
  static List<ConnectionSession> decodeList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list
        .map((e) => ConnectionSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
