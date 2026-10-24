import 'server.dart';

/// Model representing IP geolocation information
class IpInfo {
  final String ip;
  final String country;
  final String countryCode;
  final String city;
  final String region;
  final String isp;
  final String org;
  final double lat;
  final double lon;
  final String timezone;

  const IpInfo({
    required this.ip,
    required this.country,
    required this.countryCode,
    required this.city,
    required this.region,
    required this.isp,
    required this.org,
    required this.lat,
    required this.lon,
    required this.timezone,
  });

  factory IpInfo.fromJson(Map<String, dynamic> json) {
    return IpInfo(
      ip: json['query'] as String? ?? json['ip'] as String? ?? 'Unknown',
      country: json['country'] as String? ?? 'Unknown',
      countryCode: json['countryCode'] as String? ?? '',
      city: json['city'] as String? ?? 'Unknown',
      region: json['regionName'] as String? ?? json['region'] as String? ?? '',
      isp: json['isp'] as String? ?? 'Unknown',
      org: json['org'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
      timezone: json['timezone'] as String? ?? '',
    );
  }

  /// Build from `GET /api/v1/info/me`, which is our own backend.
  ///
  /// It reports the address and country it saw the request arrive from and
  /// nothing else, so the finer fields stay empty and the screen omits
  /// their rows. That is the point: the richer view used to come from a
  /// third-party lookup service, which meant handing a VPN user's real
  /// address to a company with no relationship to them.
  factory IpInfo.fromBackend(Map<String, dynamic> json) {
    final code = (json['country'] as String? ?? '').toUpperCase();
    return IpInfo(
      ip: json['ip'] as String? ?? 'Unknown',
      country: code.isEmpty ? '' : Server.countryName(code),
      countryCode: code,
      city: '',
      region: '',
      isp: '',
      org: '',
      lat: 0,
      lon: 0,
      timezone: '',
    );
  }

  /// Get flag emoji from country code
  String get flagEmoji {
    if (countryCode.length != 2) return '🌍';
    final code = countryCode.toUpperCase();
    final first = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final second = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCodes([first, second]);
  }
}
