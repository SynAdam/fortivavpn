import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'api_routes.dart';
import 'server_clock.dart';

/// API configuration - update this with your backend URL
class ApiConfig {
  static const String productionBaseUrl = 'https://api.fortivavpn.com';

  /// A backend for local testing, given at build time with
  /// `--dart-define=FORTIVA_API_BASE=http://10.0.2.2:8000` (the emulator's
  /// name for the computer it runs on). A release build ignores it, so a
  /// stray define can never point the store app anywhere else.
  static const String _baseOverride = String.fromEnvironment(
    'FORTIVA_API_BASE',
  );

  /// Whether this build talks to a local backend instead of ours.
  static const bool baseOverridden = !kReleaseMode && _baseOverride != '';

  static const String baseUrl = baseOverridden
      ? _baseOverride
      : productionBaseUrl;

  static const Duration timeout = Duration(seconds: 10);

  /// The running build's version, such as `1.6.11`, with no build number.
  /// Null until [readAppBuild] has run, or when the platform would not say.
  static String? appVersion;

  /// The running build's build number, such as `56`.
  static String? appBuild;

  /// `android`, `ios` or `windows`, as the device registration names the
  /// platform.
  static String? appPlatform;

  /// Read the running build once, at startup, for [headers].
  ///
  /// It is a platform call, and [headers] is read on every request, so the
  /// answer is kept rather than asked for each time. Never throws: a build
  /// that cannot say what it is still talks to the backend, just without
  /// the headers that would have said so.
  static Future<void> readAppBuild() async {
    appPlatform = Platform.isAndroid
        ? 'android'
        : Platform.isIOS
        ? 'ios'
        : Platform.isWindows
        ? 'windows'
        : null;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = _clean(info.version.split('+').first);
      appBuild = _clean(info.buildNumber);
    } catch (e) {
      debugPrint('ApiConfig: could not read the running build ($e)');
    }
  }

  static String? _clean(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Sent with every call to the backend, on every route.
  ///
  /// The app headers say which build is calling, so the backend can treat
  /// each version differently, for example by telling only old builds to
  /// update. Builds up to 1.6.10 never said, which left the backend unable
  /// to send them anything different. A value that is not known is left
  /// out rather than sent empty, so the backend never mistakes an empty
  /// string for a version.
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-App-Version': ?appVersion,
    'X-App-Build': ?appBuild,
    'X-App-Platform': ?appPlatform,
  };
}

/// API Exception for handling HTTP errors
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic body;

  ApiException({required this.statusCode, required this.message, this.body});

  @override
  String toString() => 'ApiException($statusCode): $message';

  bool get isNotFound => statusCode == 404;
  bool get isUnauthorized => statusCode == 401;
  bool get isValidationError => statusCode == 422;
  bool get isServerError => statusCode >= 500;
}

/// A file ([ApiClient.getBytes]) whose route answered and whose body then
/// did not arrive whole: the answer broke off, took longer than its time,
/// or was larger than the most the call takes. [reason] says which, and
/// never holds any of the body.
class DownloadCutOff implements Exception {
  const DownloadCutOff(this.reason);

  final String reason;

  @override
  String toString() => 'DownloadCutOff: $reason';
}

/// How long a file's body may take, and how large it may be.
typedef _File = ({Duration timeout, int maxBytes});

/// One try of one call on one route, as [ApiClient.onRouteAttempt] hears
/// it.
///
/// [status] is the HTTP status when an answer came back, of any kind, and
/// null when the route did not carry the call. [error] is then what went
/// wrong.
class RouteAttempt {
  const RouteAttempt({
    required this.method,
    required this.endpoint,
    required this.route,
    required this.bytes,
    required this.elapsed,
    this.status,
    this.error,
  });

  final String method;

  /// The path as it was called, ids included. Whoever keeps it turns it
  /// into a template first (see DeliveryLog.pathTemplate).
  final String endpoint;

  /// "direct", "tunnel", or "relay:" and the relay's host.
  final String route;

  /// The size of the request body in bytes, 0 when there was none.
  final int bytes;
  final Duration elapsed;
  final int? status;
  final Object? error;
}

/// Central HTTP client for all API calls.
///
/// A call goes out on the phone's own network first. When that fails
/// before any answer arrives (no connection, a reset, a TLS handshake cut
/// off, a timeout), the same call is tried again through the running
/// tunnel's SOCKS port, then through a relay inside the tunnel, then
/// through each relay (see [ApiRelay]). An answer
/// of any status ends the search: a 404 or a 500 came from the backend and
/// another route would get the same one.
///
/// After the phone's own network has failed and another route carried a
/// call, the other routes go first for [preferOthersFor], so a network
/// that drops our calls costs one timeout rather than one per call.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal()
    : _direct = http.Client(),
      _tunnelFor = ((port) => tunnelClient(port, timeout: ApiConfig.timeout)),
      _relayFor = ((relay) => relayClient(relay, timeout: ApiConfig.timeout)),
      _tunnelRelayFor = ((port, relay) =>
          tunnelRelayClient(port, relay, timeout: ApiConfig.timeout)),
      // The relays forward to our own backend, so a build pointed at a
      // local one must never fall back to them.
      _relays = ApiConfig.baseOverridden
          ? (() async => const <ApiRelay>[])
          : ApiRelays.current,
      _relayWorked = ApiRelays.noteWorked,
      _relayFailed = ApiRelays.noteFailed,
      _tunnelPort = null,
      _now = DateTime.now;

  /// A client whose routes are given, for tests that have no network.
  @visibleForTesting
  ApiClient.forTest({
    required http.Client direct,
    http.Client Function(int port)? tunnel,
    http.Client Function(ApiRelay relay)? relay,
    http.Client Function(int port, ApiRelay relay)? tunnelRelay,
    Future<List<ApiRelay>> Function()? relays,
    Future<int?> Function()? tunnelPort,
    DateTime Function()? now,
    Future<void> Function(ApiRelay relay)? relayWorked,
    Future<void> Function(ApiRelay relay)? relayFailed,
  }) : _direct = direct,
       _tunnelFor = tunnel ?? ((_) => direct),
       _relayFor = relay ?? ((_) => direct),
       _tunnelRelayFor = tunnelRelay ?? ((_, _) => direct),
       _relays = relays ?? (() async => const []),
       _relayWorked = relayWorked ?? ((_) async {}),
       _relayFailed = relayFailed ?? ((_) async {}),
       _tunnelPort = tunnelPort,
       _now = now ?? DateTime.now;

  /// The SOCKS port of a running tunnel, or null when none is up or the
  /// tunnel cannot carry this app's calls. Set by VpnService, which owns
  /// the answer.
  static Future<int?> Function()? tunnelSocksPort;

  /// Told about every try of every call, on every route, when it ends. Set
  /// at startup by DeliveryLog.install. Called synchronously and never
  /// awaited; a listener that throws does not change the call.
  static void Function(RouteAttempt attempt)? onRouteAttempt;

  /// When our API last answered this phone on its own network, on the
  /// phone's clock: on the direct route, or through a relay reached on the
  /// phone's own network. An answer of any status counts, because it came
  /// back. Null before any did. Set where [onRouteAttempt] hears the answer.
  ///
  /// Such an answer says the phone has internet, whatever the control fetch
  /// says (ConnectFlow, verdictFor). On 2026-10-23 about 10 to 25 taps a
  /// day ended at no internet on phones whose own calls to us were being
  /// answered. An answer through the tunnel is left out: it says the
  /// tunnel works, not the phone's own network.
  static DateTime? lastAnsweredAt;

  /// Whether our API answered this phone on its own network at or after
  /// [since] ([lastAnsweredAt]).
  static bool answeredSince(DateTime since) {
    final at = lastAnsweredAt;
    return at != null && !at.isBefore(since);
  }

  /// Told when a call fails on the phone's own network before any answer.
  /// Set at startup to read the fallback file (Bootstrap.readSoon), which
  /// decides itself whether a read is due. Not after every route failed: on
  /// a phone cut off from all of them, the relays' timeouts alone took 40
  /// seconds. Called synchronously and never awaited.
  static void Function()? onDirectFailed;

  /// How long the other routes go first once the phone's own network has
  /// failed and another route carried the call.
  static const preferOthersFor = Duration(minutes: 10);

  /// How many relays a call tries through the tunnel. Each that does not
  /// answer costs a timeout, and a tunnel that carries nothing would fail
  /// them all.
  static const tunnelRelays = 2;

  final http.Client _direct;
  final http.Client Function(int port) _tunnelFor;
  final http.Client Function(ApiRelay relay) _relayFor;
  final http.Client Function(int port, ApiRelay relay) _tunnelRelayFor;
  final Future<List<ApiRelay>> Function() _relays;
  final Future<void> Function(ApiRelay relay) _relayWorked;
  final Future<void> Function(ApiRelay relay) _relayFailed;
  final Future<int?> Function()? _tunnelPort;
  final DateTime Function() _now;

  final Map<int, http.Client> _tunnelClients = {};
  final Map<ApiRelay, http.Client> _relayClients = {};
  final Map<(int, ApiRelay), http.Client> _tunnelRelayClients = {};
  DateTime? _directFailedAt;

  /// When a relay through the tunnel last carried a call after the tunnel
  /// itself failed: that tunnel's exit cannot reach us, so for
  /// [preferOthersFor] the relays inside it go before it, and a call does
  /// not wait out the tunnel's timeout every time.
  DateTime? _tunnelExitFailedAt;

  /// GET request. [fallback] false keeps the call on the phone's own
  /// network, for a call whose answer depends on the route it took.
  Future<dynamic> get(String endpoint, {bool fallback = true}) =>
      _send('GET', endpoint, null, fallback: fallback);

  /// POST request
  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) =>
      _send('POST', endpoint, body, fallback: true);

  /// DELETE request
  Future<dynamic> delete(String endpoint) =>
      _send('DELETE', endpoint, null, fallback: true);

  /// How long the body of a file ([getBytes]) may take to arrive once its
  /// route has answered. The backup network's server list can be a few
  /// megabytes, which on a slow line takes minutes, not the seconds of
  /// [ApiConfig.timeout] a JSON answer gets.
  static const fileTimeout = Duration(minutes: 3);

  /// The largest file [getBytes] takes: the most the backend serves
  /// (MAX_SERVER_ENTRIES_BYTES in its psiphon service).
  static const fileMaxBytes = 16 * 1024 * 1024;

  /// GET a file: the body's bytes exactly as they arrived, for an answer
  /// that is not JSON. Takes every route [get] takes, and each route has
  /// the same [ApiConfig.timeout] to answer. Throws [ApiException] for an
  /// answer that is not a success.
  ///
  /// Once a route has answered, the body has [bodyTimeout] to arrive and
  /// may be at most [maxBytes] long. A body that does not arrive whole
  /// throws [DownloadCutOff]. That says nothing about whether the route
  /// carries calls, so the route is not marked failed for it, and no other
  /// route is tried, because each would download the file again. A route
  /// that has not answered in time, and a body that is cut off, are
  /// closed, so nothing more is downloaded once the call has ended.
  Future<Uint8List> getBytes(
    String endpoint, {
    Duration bodyTimeout = fileTimeout,
    int maxBytes = fileMaxBytes,
  }) async =>
      await _send(
            'GET',
            endpoint,
            null,
            fallback: true,
            file: (timeout: bodyTimeout, maxBytes: maxBytes),
          )
          as Uint8List;

  /// [file] is set for [getBytes], and null for a JSON call.
  Future<dynamic> _send(
    String method,
    String endpoint,
    Map<String, dynamic>? body, {
    required bool fallback,
    _File? file,
  }) async {
    final routes = fallback ? _routes() : Stream.value(_Route.direct());
    var tunnelFailed = false;
    Object? firstError;
    StackTrace? firstStack;
    await for (final route in routes) {
      final encoded = _encode(route, body);
      final watch = Stopwatch()..start();
      final http.BaseResponse response;
      try {
        response = file == null
            ? await _attempt(route, method, endpoint, encoded)
            : await _open(route, endpoint);
      } catch (e, st) {
        _observe(method, endpoint, route, encoded, watch, error: e);
        if (!_isRouteFailure(e)) rethrow;
        debugPrint('ApiClient: $method $endpoint failed on ${route.name} ($e)');
        if (route.kind == _RouteKind.direct) {
          _directFailedAt = _now();
          _directFailed();
        }
        if (route.kind == _RouteKind.tunnel) tunnelFailed = true;
        // Only a relay on the phone's own network, as for one that worked
        // below: one that failed through the tunnel says nothing about
        // which relays this network lets through.
        if (route.kind == _RouteKind.relay) {
          unawaited(_relayFailed(route.relay!));
        }
        if (firstError == null) {
          firstError = e;
          firstStack = st;
        }
        continue;
      }
      _observe(
        method,
        endpoint,
        route,
        encoded,
        watch,
        status: response.statusCode,
      );
      ServerClock.heard(response.headers['date'], _now());
      if (route.kind == _RouteKind.direct || route.kind == _RouteKind.relay) {
        lastAnsweredAt = _now();
      }
      if (route.kind == _RouteKind.direct) {
        _directFailedAt = null;
      } else if (route.kind == _RouteKind.tunnel) {
        _tunnelExitFailedAt = null;
      }
      // Only when the tunnel itself failed on this call. While the relays
      // go first nobody tries the tunnel, so after [preferOthersFor] it
      // gets its turn again, for an exit that can reach us by then, or
      // another link.
      if (route.kind == _RouteKind.tunnelRelay && tunnelFailed) {
        _tunnelExitFailedAt = _now();
      }
      if (route.kind != _RouteKind.direct) {
        debugPrint('ApiClient: $method $endpoint went through ${route.name}');
      }
      // Only a relay on the phone's own network: one that worked through
      // the tunnel says nothing about which relay this network lets
      // through, and would put a blocked one first.
      if (route.kind == _RouteKind.relay) {
        unawaited(_relayWorked(route.relay!));
      }
      // The route has answered. What happens to the body from here is
      // not the route's failure.
      return file == null
          ? _handleResponse(response as http.Response)
          : await _read(response as http.StreamedResponse, file);
    }
    // Every route failed. The first error is the one the phone's own
    // network gave, which is what callers have always been told.
    final e = firstError!;
    if (e is SocketException) {
      throw ApiException(statusCode: 0, message: 'No internet connection');
    }
    if (e is http.ClientException) {
      throw ApiException(statusCode: 0, message: 'Network error: ${e.message}');
    }
    Error.throwWithStackTrace(e, firstStack!);
  }

  static void _directFailed() {
    try {
      onDirectFailed?.call();
    } catch (e) {
      debugPrint('ApiClient: direct failure listener failed ($e)');
    }
  }

  /// The routes to try, in order.
  ///
  /// With a tunnel up: the tunnel, then the first [tunnelRelays] relays
  /// through it, then the relays on the phone's own network. Through the
  /// tunnel the relays are dialled from abroad, where their addresses are
  /// not blocked; on the phone's own network they often are.
  ///
  /// A generator that runs only as far as the call has asked. When the
  /// phone's own network goes first, the other routes are worked out only
  /// once it has failed, so a call that network carries never waits for
  /// the relays to be put in order: that reads which network the phone is
  /// on, and on mobile data asks the platform for the carrier
  /// (ApiRelays.current).
  Stream<_Route> _routes() async* {
    final failedAt = _directFailedAt;
    final directFailedLately =
        failedAt != null && _now().difference(failedAt) < preferOthersFor;
    if (!directFailedLately) yield _Route.direct();
    final others = <_Route>[];
    int? port;
    try {
      port = await (_tunnelPort ?? tunnelSocksPort)?.call();
    } catch (e) {
      debugPrint('ApiClient: could not read the tunnel port ($e)');
    }
    final exitFailedAt = _tunnelExitFailedAt;
    final exitFailedLately =
        exitFailedAt != null &&
        _now().difference(exitFailedAt) < preferOthersFor;
    if (port != null && !exitFailedLately) others.add(_Route.tunnel(port));
    try {
      final relays = await _relays();
      if (port != null) {
        for (final relay in relays.take(tunnelRelays)) {
          others.add(_Route.tunnelRelay(port, relay));
        }
        // Its exit could not reach us lately: the tunnel goes after the
        // relays inside it.
        if (exitFailedLately) others.add(_Route.tunnel(port));
      }
      for (final relay in relays) {
        others.add(_Route.relay(relay));
      }
    } catch (e) {
      debugPrint('ApiClient: could not read the relays ($e)');
    }
    for (final route in others) {
      yield route;
    }
    if (directFailedLately) yield _Route.direct();
  }

  /// The body [route] sends, as JSON, or null when there is none.
  ///
  /// Through the tunnel the call reaches the backend from our own exit
  /// server, so a body that says how it travelled has to say so. A relay
  /// passes the phone's own address on, so the phone's answer stands.
  static String? _encode(_Route route, Map<String, dynamic>? body) {
    if (body == null) return null;
    final sent = route.port != null && body.containsKey('via_tunnel')
        ? {...body, 'via_tunnel': true}
        : body;
    return jsonEncode(sent);
  }

  /// Tell [onRouteAttempt] how one try went. Never throws.
  static void _observe(
    String method,
    String endpoint,
    _Route route,
    String? encoded,
    Stopwatch watch, {
    int? status,
    Object? error,
  }) {
    final listener = onRouteAttempt;
    if (listener == null) return;
    try {
      listener(
        RouteAttempt(
          method: method,
          endpoint: endpoint,
          route: route.label,
          bytes: encoded == null ? 0 : utf8.encode(encoded).length,
          elapsed: watch.elapsed,
          status: status,
          error: error,
        ),
      );
    } catch (e) {
      debugPrint('ApiClient: route listener failed ($e)');
    }
  }

  Future<http.Response> _attempt(
    _Route route,
    String method,
    String endpoint,
    String? encoded,
  ) {
    final (client, base) = _clientFor(route);
    final uri = Uri.parse('$base$endpoint');
    final Future<http.Response> request = switch (method) {
      'GET' => client.get(uri, headers: ApiConfig.headers),
      'POST' => client.post(uri, headers: ApiConfig.headers, body: encoded),
      'DELETE' => client.delete(uri, headers: ApiConfig.headers),
      _ => throw ArgumentError.value(method, 'method'),
    };
    return request.timeout(ApiConfig.timeout);
  }

  /// Asks [route] for a file ([getBytes]) and waits up to
  /// [ApiConfig.timeout] for the answer to begin. [_read] then reads the
  /// body. A route that has not answered by then is closed, so the request
  /// stops there instead of downloading the file in the background.
  Future<http.StreamedResponse> _open(_Route route, String endpoint) {
    final (client, base) = _clientFor(route);
    final abort = Completer<void>();
    final request = http.AbortableRequest(
      'GET',
      Uri.parse('$base$endpoint'),
      abortTrigger: abort.future,
    )..headers.addAll(ApiConfig.headers);
    final sent = client.send(request);
    return sent.timeout(
      ApiConfig.timeout,
      onTimeout: () {
        abort.complete();
        // An answer that still arrives is closed unread.
        unawaited(
          sent.then(
            (answer) => answer.stream.listen(null, onError: (_) {}).cancel(),
            onError: (_) {},
          ),
        );
        throw TimeoutException('no answer', ApiConfig.timeout);
      },
    );
  }

  /// The body of a file [_open] got an answer for, read within [file]'s
  /// time and size. A body that does not arrive whole throws
  /// [DownloadCutOff], and its connection is closed. An answer that is not
  /// a success throws [ApiException], as for any call.
  Future<Uint8List> _read(http.StreamedResponse response, _File file) async {
    final length = response.contentLength;
    if (length != null && length > file.maxBytes) {
      unawaited(response.stream.listen(null, onError: (_) {}).cancel());
      throw DownloadCutOff('$length bytes, more than ${file.maxBytes}');
    }
    final done = Completer<Uint8List>();
    final bytes = BytesBuilder(copy: false);
    StreamSubscription<List<int>>? body;
    void cut(String why) {
      if (done.isCompleted) return;
      unawaited(body?.cancel());
      done.completeError(DownloadCutOff(why));
    }

    final timer = Timer(
      file.timeout,
      () => cut('not whole after ${file.timeout.inSeconds} s'),
    );
    body = response.stream.listen(
      (chunk) {
        bytes.add(chunk);
        if (bytes.length > file.maxBytes) {
          cut('more than ${file.maxBytes} bytes');
        }
      },
      onError: (Object e) => cut('the answer broke off ($e)'),
      onDone: () {
        if (!done.isCompleted) done.complete(bytes.takeBytes());
      },
      cancelOnError: true,
    );
    final Uint8List received;
    try {
      received = await done.future;
    } finally {
      timer.cancel();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return received;
    }
    throw _errorOf(
      http.Response.bytes(
        received,
        response.statusCode,
        headers: response.headers,
      ),
    );
  }

  /// The client that carries a call on [route], and the base URL the call
  /// goes to there.
  (http.Client, String) _clientFor(_Route route) {
    return switch (route.kind) {
      _RouteKind.direct => (_direct, ApiConfig.baseUrl),
      _RouteKind.tunnel => (
        _tunnelClients.putIfAbsent(route.port!, () => _tunnelFor(route.port!)),
        ApiConfig.baseUrl,
      ),
      _RouteKind.tunnelRelay => (
        _tunnelRelayClients.putIfAbsent((
          route.port!,
          route.relay!,
        ), () => _tunnelRelayFor(route.port!, route.relay!)),
        route.relay!.url,
      ),
      _RouteKind.relay => (
        _relayClients.putIfAbsent(route.relay!, () => _relayFor(route.relay!)),
        route.relay!.url,
      ),
    };
  }

  /// Whether [e] means the route did not deliver the call, rather than the
  /// backend answering it.
  static bool _isRouteFailure(Object e) =>
      e is IOException || e is http.ClientException || e is TimeoutException;

  /// Handle HTTP response
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    throw _errorOf(response);
  }

  ApiException _errorOf(http.Response response) {
    // Parse error body if available
    dynamic errorBody;
    try {
      errorBody = jsonDecode(response.body);
    } catch (_) {
      errorBody = response.body;
    }

    return ApiException(
      statusCode: response.statusCode,
      message: _getErrorMessage(response.statusCode, errorBody),
      body: errorBody,
    );
  }

  String _getErrorMessage(int statusCode, dynamic body) {
    // Try to extract message from common error formats
    if (body is Map) {
      if (body.containsKey('detail')) {
        final detail = body['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          return detail.map((e) => e['msg'] ?? e.toString()).join(', ');
        }
      }
      if (body.containsKey('message')) return body['message'];
    }

    // Default messages
    switch (statusCode) {
      case 400:
        return 'Bad request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not found';
      case 422:
        return 'Validation error';
      case 500:
        return 'Server error';
      default:
        return 'Request failed';
    }
  }
}

enum _RouteKind { direct, tunnel, tunnelRelay, relay }

/// One way a call can reach the backend.
class _Route {
  const _Route._(this.kind, {this.port, this.relay});

  factory _Route.direct() => const _Route._(_RouteKind.direct);
  factory _Route.tunnel(int port) => _Route._(_RouteKind.tunnel, port: port);
  factory _Route.relay(ApiRelay relay) =>
      _Route._(_RouteKind.relay, relay: relay);
  factory _Route.tunnelRelay(int port, ApiRelay relay) =>
      _Route._(_RouteKind.tunnelRelay, port: port, relay: relay);

  final _RouteKind kind;
  final int? port;
  final ApiRelay? relay;

  String get name => switch (kind) {
    _RouteKind.direct => 'the direct route',
    _RouteKind.tunnel => 'the tunnel',
    _RouteKind.tunnelRelay => 'relay ${relay!.url} through the tunnel',
    _RouteKind.relay => 'relay ${relay!.url}',
  };

  /// The route as the delivery log and the size probe name it.
  String get label => switch (kind) {
    _RouteKind.direct => 'direct',
    // Through the tunnel: the backend sees the tunnel's exit, as it does
    // for the tunnel route, so the delivery log files it the same way.
    _RouteKind.tunnel || _RouteKind.tunnelRelay => 'tunnel',
    _RouteKind.relay => relayLabel(relay!),
  };
}

/// "relay:" and the relay's host, such as `relay:203.0.113.5`. The host is
/// our own server's address, never the phone's.
String relayLabel(ApiRelay relay) =>
    'relay:${Uri.tryParse(relay.url)?.host ?? relay.url}';
