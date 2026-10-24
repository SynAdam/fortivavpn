import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Result of a speed test measurement
class SpeedTestResult {
  final double downloadMbps;
  final double uploadMbps;
  final int pingMs;
  final DateTime timestamp;

  const SpeedTestResult({
    required this.downloadMbps,
    required this.uploadMbps,
    required this.pingMs,
    required this.timestamp,
  });
}

/// Lightweight download speed test service
/// Measures throughput by downloading a known file and timing it
class SpeedTestService extends ChangeNotifier {
  bool _isRunning = false;
  double _progress = 0.0;
  SpeedTestResult? _lastResult;
  String _phase = '';

  bool get isRunning => _isRunning;
  double get progress => _progress;
  SpeedTestResult? get lastResult => _lastResult;
  String get phase => _phase;

  // Use Cloudflare's speed test endpoints (reliable, global CDN)
  static const _downloadUrls = [
    'https://speed.cloudflare.com/__down?bytes=5000000', // 5MB
    'https://speed.cloudflare.com/__down?bytes=10000000', // 10MB
  ];

  /// Run a speed test measuring download speed and ping
  Future<void> runTest() async {
    if (_isRunning) return;
    _isRunning = true;
    _progress = 0.0;
    _phase = 'Measuring ping...';
    _lastResult = null;
    notifyListeners();

    try {
      // Phase 1: Ping measurement
      final pingMs = await _measurePing();
      _progress = 0.2;
      _phase = 'Testing download speed...';
      notifyListeners();

      // Phase 2: Download speed
      final downloadMbps = await _measureDownload();
      _progress = 0.8;
      _phase = 'Testing upload speed...';
      notifyListeners();

      // Phase 3: Upload speed (simplified — small payload)
      final uploadMbps = await _measureUpload();
      _progress = 1.0;
      _phase = 'Complete';

      _lastResult = SpeedTestResult(
        downloadMbps: downloadMbps,
        uploadMbps: uploadMbps,
        pingMs: pingMs,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[SpeedTest] Error: $e');
      _phase = 'Error';
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }

  Future<int> _measurePing() async {
    try {
      final stopwatch = Stopwatch()..start();
      await http
          .head(Uri.parse('https://speed.cloudflare.com/__down?bytes=0'))
          .timeout(const Duration(seconds: 5));
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return -1;
    }
  }

  Future<double> _measureDownload() async {
    double totalMbps = 0;
    int validTests = 0;

    for (int i = 0; i < _downloadUrls.length; i++) {
      try {
        final url = _downloadUrls[i];
        final stopwatch = Stopwatch()..start();

        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 15));
        stopwatch.stop();

        if (response.statusCode == 200) {
          final bytes = response.bodyBytes.length;
          final seconds = stopwatch.elapsedMilliseconds / 1000.0;
          final mbps = (bytes * 8) / (seconds * 1000000);
          totalMbps += mbps;
          validTests++;
        }

        _progress = 0.2 + (0.6 * (i + 1) / _downloadUrls.length);
        notifyListeners();
      } catch (e) {
        debugPrint('[SpeedTest] Download test $i failed: $e');
      }
    }

    return validTests > 0 ? totalMbps / validTests : 0.0;
  }

  Future<double> _measureUpload() async {
    try {
      // Generate 1MB of random-ish data
      final data = List.generate(1000000, (i) => i % 256);
      final bytes = data.length;

      final stopwatch = Stopwatch()..start();
      await http
          .post(Uri.parse('https://speed.cloudflare.com/__up'), body: data)
          .timeout(const Duration(seconds: 10));
      stopwatch.stop();

      final seconds = stopwatch.elapsedMilliseconds / 1000.0;
      return (bytes * 8) / (seconds * 1000000);
    } catch (e) {
      debugPrint('[SpeedTest] Upload test failed: $e');
      return 0.0;
    }
  }
}
