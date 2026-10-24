/// Connection information and metadata
class ConnectionInfo {
  final DateTime startTime;
  final String serverId;
  final String serverName;
  final int bytesUploaded;
  final int bytesDownloaded;

  const ConnectionInfo({
    required this.startTime,
    required this.serverId,
    required this.serverName,
    this.bytesUploaded = 0,
    this.bytesDownloaded = 0,
  });

  ConnectionInfo copyWith({
    DateTime? startTime,
    String? serverId,
    String? serverName,
    int? bytesUploaded,
    int? bytesDownloaded,
  }) {
    return ConnectionInfo(
      startTime: startTime ?? this.startTime,
      serverId: serverId ?? this.serverId,
      serverName: serverName ?? this.serverName,
      bytesUploaded: bytesUploaded ?? this.bytesUploaded,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
    );
  }

  Duration get duration => DateTime.now().difference(startTime);

  int get totalBytes => bytesUploaded + bytesDownloaded;

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime.toIso8601String(),
      'serverId': serverId,
      'serverName': serverName,
      'bytesUploaded': bytesUploaded,
      'bytesDownloaded': bytesDownloaded,
    };
  }

  factory ConnectionInfo.fromJson(Map<String, dynamic> json) {
    return ConnectionInfo(
      startTime: DateTime.parse(json['startTime'] as String),
      serverId: json['serverId'] as String,
      serverName: json['serverName'] as String,
      bytesUploaded: json['bytesUploaded'] as int? ?? 0,
      bytesDownloaded: json['bytesDownloaded'] as int? ?? 0,
    );
  }
}

/// VPN connection status
enum VpnStatus { disconnected, connecting, connected, disconnecting, error }

extension VpnStatusExtension on VpnStatus {
  String get displayName {
    switch (this) {
      case VpnStatus.disconnected:
        return 'Disconnected';
      case VpnStatus.connecting:
        return 'Connecting';
      case VpnStatus.connected:
        return 'Connected';
      case VpnStatus.disconnecting:
        return 'Disconnecting';
      case VpnStatus.error:
        return 'Error';
    }
  }

  bool get isActive =>
      this == VpnStatus.connecting ||
      this == VpnStatus.connected ||
      this == VpnStatus.disconnecting;
}
