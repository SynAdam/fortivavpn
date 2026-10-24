import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'device_facts.dart';
import 'device_identity.dart';
import '../data/models/device.dart';
import '../services/device_place.dart';
import '../services/test_lab.dart';
import '../services/vpn_event_reporter.dart';

/// Service for device registration and management
class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal()
    : _client = ApiClient(),
      _place = DevicePlace(),
      _testLab = TestLab(),
      _facts = DeviceFacts();

  /// A service whose network and platform reads are given, for tests.
  @visibleForTesting
  DeviceService.forTest({
    required ApiClient client,
    DevicePlace? place,
    TestLab? testLab,
    DeviceFacts? facts,
  }) : _client = client,
       _place = place ?? DevicePlace(),
       _testLab = testLab ?? TestLab(),
       _facts = facts ?? DeviceFacts();

  final ApiClient _client;
  final DevicePlace _place;
  final TestLab _testLab;
  final DeviceFacts _facts;

  /// Resolve the persistent device ID.
  ///
  /// Delegates to [DeviceIdentity], which prefers a value that survives a
  /// reinstall over a freshly minted random one. See that class for why.
  Future<String> getDeviceId() => DeviceIdentity.instance.resolve();

  /// Get current platform string
  String get platform {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    return 'unknown';
  }

  String? _cachedVersion;

  /// The running build's version, read from the platform package info.
  ///
  /// This was hardcoded to '1.0.2' while the app shipped as 1.0.23, which
  /// silently broke force-update: the backend compares what we report here
  /// against its configured minimum, so it was comparing against a version
  /// that had not existed for twenty releases.
  Future<String> getAppVersion() async {
    if (_cachedVersion != null) return _cachedVersion!;
    try {
      final info = await PackageInfo.fromPlatform();
      _cachedVersion = info.version;
    } catch (_) {
      // Never block registration on this; an unknown version is better
      // than no device record at all.
      _cachedVersion = '0.0.0';
    }
    return _cachedVersion!;
  }

  /// Register device with backend
  ///
  /// POST /api/v1/devices/register
  /// Whether an account deletion runs ([AccountService.deleteAccount]).
  static bool get deleting => _deleting;
  static bool _deleting = false;

  /// Set and cleared by AccountService around a deletion. No device is
  /// registered meanwhile: an upload that comes back 404 once the backend
  /// removed the row would make it again under the id the deletion is
  /// about to forget, and nobody could name or delete that row afterwards.
  static void deletionRuns(bool runs) => _deleting = runs;

  Future<Device> registerDevice({
    String? deviceModel,
    String? osVersion,
    String? pushToken,
    String? language,
  }) async {
    if (_deleting) {
      // Status 0, as for no answer: every caller keeps what it was sending
      // and tries again later, by then under the new id.
      throw ApiException(
        statusCode: 0,
        message: 'the account is being deleted',
      );
    }
    // Started first so they run alongside the reads below. Neither throws.
    final testLab = _testLab.read();
    final facts = _facts.read();
    final deviceId = await getDeviceId();
    // The model and Android version go only while the user shares
    // diagnostics, like the place below. Register replaces both columns, so
    // turning sharing off also clears them on the backend.
    final phone = await _sharing()
        ? await facts
        : (model: null, osVersion: null);

    final body = {
      'device_id': deviceId,
      'platform': platform,
      'app_version': await getAppVersion(),
      'device_model': ?(deviceModel ?? phone.model),
      'os_version': ?(osVersion ?? phone.osVersion),
      'push_token': ?pushToken,
      'language': ?language,
      // Where the phone is, so the backend does not count a user behind
      // another VPN in that VPN's country. See DevicePlace.
      'place': ?await _place.read(),
      // Only Google's pre-launch test devices send this, so the backend can
      // leave them out of operator views and alerts. See TestLab.
      if (await testLab) 'test_lab': true,
    };

    final response = await _client.post('/api/v1/devices/register', body: body);
    return Device.fromJson(response as Map<String, dynamic>);
  }

  /// Whether the user shares diagnostics. Unset means yes, as everywhere.
  static Future<bool> _sharing() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.get(VpnEventReporter.sharePrefKey) != false;
    } catch (_) {
      return false;
    }
  }

  /// Delete this device's account and every trace of it on the backend.
  ///
  /// DELETE /api/v1/devices/{device_id}
  ///
  /// Required by App Store Review Guideline 5.1.1(v): an account created
  /// in the app has to be deletable from inside the app.
  ///
  /// A 404 counts as success. It means the backend has no row for this
  /// install, which is the state the caller was asking for. Anything else
  /// throws, because reporting a deletion that did not happen is worse
  /// than showing an error.
  ///
  /// Server-side clean-up only. The caller is responsible for clearing
  /// local state afterwards, so a failure here never leaves the app
  /// pointing at a device row that is already gone.
  Future<void> deleteAccount() async {
    final deviceId = await getDeviceId();

    try {
      await _client.delete('/api/v1/devices/$deviceId');
    } on ApiException catch (e) {
      if (e.isNotFound) return;
      rethrow;
    }
  }

  /// Get device info from backend
  ///
  /// GET /api/v1/devices/{device_id}
  Future<Device?> getDevice() async {
    final deviceId = await getDeviceId();

    try {
      final response = await _client.get('/api/v1/devices/$deviceId');
      return Device.fromJson(response as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.isNotFound) {
        return null;
      }
      rethrow;
    }
  }
}
