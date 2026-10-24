import 'dart:typed_data';

import 'api_client.dart';
import '../data/models/app_config.dart';
import '../data/models/version_info.dart';

/// Service for fetching app configuration and version info
class AppConfigService {
  static final AppConfigService _instance = AppConfigService._internal();
  factory AppConfigService() => _instance;
  AppConfigService._internal();

  final ApiClient _client = ApiClient();

  /// Get app configuration including URLs, feature flags, and announcements
  ///
  /// GET /api/v1/app/config
  Future<AppConfig> getAppConfig() async {
    final response = await _client.get('/api/v1/app/config');
    return AppConfig.fromJson(response as Map<String, dynamic>);
  }

  /// The fallback file as the backend builds it now, or null when it has
  /// none (Bootstrap.refreshFromBackend).
  ///
  /// GET /api/v1/app/fallback-file
  Future<String?> getFallbackFile() async {
    final response = await _client.get('/api/v1/app/fallback-file');
    final file = response is Map ? response['file'] : null;
    return file is String ? file : null;
  }

  /// The backup network's server list, as the bytes the backend serves.
  /// Throws [ApiException] with status 404 when it serves none.
  ///
  /// GET /api/v1/app/psiphon/server-entries
  Future<Uint8List> getPsiphonServerEntries() =>
      _client.getBytes('/api/v1/app/psiphon/server-entries');

  /// Get version information for iOS and Android apps
  ///
  /// GET /api/v1/app/version
  Future<VersionInfo> getAppVersion() async {
    final response = await _client.get('/api/v1/app/version');
    return VersionInfo.fromJson(response as Map<String, dynamic>);
  }
}
