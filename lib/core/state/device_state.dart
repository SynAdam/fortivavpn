import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../api/device_service.dart';
import '../../api/api_client.dart';
import '../../data/models/device.dart';

/// State manager for device registration and subscription status
class DeviceState extends ChangeNotifier {
  DeviceState({
    Future<Device> Function()? register,
    this.retryGaps = const [
      Duration(seconds: 10),
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 2),
      Duration(minutes: 5),
    ],
  }) : _register = register ?? DeviceService().registerDevice;

  final DeviceService _deviceService = DeviceService();
  final Future<Device> Function() _register;

  /// How long to wait before each further try after a failed register.
  /// The last gap repeats for as long as the app runs.
  ///
  /// Registration used to be tried once per launch. A phone whose network
  /// was cutting part of our calls lost that one call and the two the
  /// provisioning retry made, so the backend had never heard of it: no own
  /// server, and its failed connect and door checks refused. Some of its
  /// calls were getting through, so trying again was all it needed.
  final List<Duration> retryGaps;

  /// Told each time a register succeeds, so whatever waited on it (the
  /// device's own servers, the reports queued on the phone) can go ahead.
  VoidCallback? onRegistered;

  Timer? _retry;
  int _failures = 0;

  /// Set by [dispose]. A register in flight when the state is disposed
  /// still finishes, and must then neither notify nor schedule another.
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Device? _device;
  bool _isLoading = false;
  bool _isRegistered = false;
  String? _errorMessage;

  Device? get device => _device;
  bool get isLoading => _isLoading;
  bool get isRegistered => _isRegistered;
  String? get errorMessage => _errorMessage;

  /// Check if current device has premium subscription
  bool get isPremium => _device?.hasActiveSubscription ?? false;

  /// Get device ID (even if not yet registered with backend)
  Future<String> get deviceId => _deviceService.getDeviceId();

  /// Register device with backend
  /// Should be called on app launch
  Future<void> registerDevice() async {
    if (_isLoading || _disposed) return;

    _isLoading = true;
    _errorMessage = null;
    _notify();

    try {
      _device = await _register();
      _isRegistered = true;
      _failures = 0;
      _retry?.cancel();
      _retry = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      // Don't block the app if registration fails
      _isRegistered = false;
    } catch (e) {
      _errorMessage = 'Failed to register device: $e';
      _isRegistered = false;
    } finally {
      _isLoading = false;
      _notify();
    }
    if (_disposed) return;
    if (_isRegistered) {
      onRegistered?.call();
    } else {
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (retryGaps.isEmpty || (_retry?.isActive ?? false)) return;
    final gap = retryGaps[_failures.clamp(0, retryGaps.length - 1)];
    _failures++;
    _retry = Timer(gap, registerDevice);
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    super.dispose();
  }

  /// Refresh device info from backend
  Future<void> refreshDevice() async {
    try {
      _device = await _deviceService.getDevice();
      if (_device != null) {
        _isRegistered = true;
      }
      notifyListeners();
    } on ApiException {
      // A failed refresh keeps the last-known device rather than clearing it,
      // so a transient backend blip does not blank the UI.
    }
  }

  /// Forget the device entirely, after the account has been deleted.
  ///
  /// The backend row is gone at this point, so keeping the cached Device
  /// around would let the UI keep showing a premium badge or a quota that
  /// no longer exists anywhere.
  void reset() {
    _retry?.cancel();
    _retry = null;
    _failures = 0;
    _device = null;
    _isRegistered = false;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Clear any errors
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
