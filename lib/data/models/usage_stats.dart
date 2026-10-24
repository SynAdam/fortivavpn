class UsageStats {
  final int totalConnections;
  final int totalBytesUploaded;
  final int totalBytesDownloaded;
  final Duration totalConnectionTime;
  final DateTime lastUpdated;

  UsageStats({
    this.totalConnections = 0,
    this.totalBytesUploaded = 0,
    this.totalBytesDownloaded = 0,
    this.totalConnectionTime = Duration.zero,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  int get totalBytes => totalBytesUploaded + totalBytesDownloaded;

  Duration get averageSessionDuration {
    if (totalConnections == 0) return Duration.zero;
    return Duration(seconds: totalConnectionTime.inSeconds ~/ totalConnections);
  }

  UsageStats copyWith({
    int? totalConnections,
    int? totalBytesUploaded,
    int? totalBytesDownloaded,
    Duration? totalConnectionTime,
    DateTime? lastUpdated,
  }) {
    return UsageStats(
      totalConnections: totalConnections ?? this.totalConnections,
      totalBytesUploaded: totalBytesUploaded ?? this.totalBytesUploaded,
      totalBytesDownloaded: totalBytesDownloaded ?? this.totalBytesDownloaded,
      totalConnectionTime: totalConnectionTime ?? this.totalConnectionTime,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalConnections': totalConnections,
      'totalBytesUploaded': totalBytesUploaded,
      'totalBytesDownloaded': totalBytesDownloaded,
      'totalConnectionTimeSeconds': totalConnectionTime.inSeconds,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory UsageStats.fromJson(Map<String, dynamic> json) {
    return UsageStats(
      totalConnections: json['totalConnections'] as int? ?? 0,
      totalBytesUploaded: json['totalBytesUploaded'] as int? ?? 0,
      totalBytesDownloaded: json['totalBytesDownloaded'] as int? ?? 0,
      totalConnectionTime: Duration(
        seconds: json['totalConnectionTimeSeconds'] as int? ?? 0,
      ),
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : DateTime.now(),
    );
  }
}
