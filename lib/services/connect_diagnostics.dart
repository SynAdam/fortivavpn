import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/checklist_settings.dart';

/// What was true about the network at the moment a connection failed.
///
/// About one second of checks, run in parallel, each with its own cap, so a
/// failure report costs the user nothing they would notice. Four questions
/// the server cannot answer on its own:
///
///  * did the server's name resolve,
///  * did TCP to the server open,
///  * did a TLS handshake carrying the Reality SNI complete,
///  * does the phone reach a known-open site at all (a control), and when
///    it does not, does it reach one inside the country.
///
/// Plus whatever the platform knows: carrier, network type, power and data
/// settings, the core's own log tail. The backend turns these into a verdict
/// such as "blocked at TLS on this carrier"; the app does not interpret them.
class ConnectDiagnostics {
  ConnectDiagnostics({MethodChannel? channel}) : _channel = channel;

  static const timeout = Duration(milliseconds: 2500);

  /// The control sites abroad [controlCheck] races when the backend sends
  /// none (ChecklistSettings.control).
  static const controlUrls = [
    'http://connectivitycheck.gstatic.com/generate_204',
    'http://cp.cloudflare.com/generate_204',
  ];

  /// How long [controlCheck] gives each site to connect and answer. Until
  /// 2.2.0 it was [timeout] for each step, one site after the other, so a
  /// slow line could take 10 seconds to answer and a site that needed 3
  /// seconds failed.
  static const controlTimeout = Duration(seconds: 4);

  /// The sites [controlCheck] races: the backend's, or [controlUrls].
  static List<String> get currentControlUrls =>
      ChecklistSettings.current?.control ?? controlUrls;

  /// Sites inside Iran for [homeCheck], when the backend sends none
  /// (ChecklistSettings.homeControl). Each one has its name servers and its
  /// hosting inside Iran, on two different networks (Digikala's own and
  /// Sotoon), so its name still resolves and it still answers when only
  /// the national network is up: the June 2025 cut dropped about 90% of
  /// traffic abroad, and in January 2026 the routes abroad were withdrawn
  /// altogether, while sites like these kept working. Aparat, Snapp and
  /// Varzesh3 were left out: their name servers are abroad.
  ///
  /// A third site, Bale's web app, was dropped on 2026-10-24. Bale is a
  /// state platform, and the app never asks one by itself
  /// (StatePlatforms).
  static const homeUrls = ['https://www.digikala.com/', 'https://divar.ir/'];

  /// How long [homeCheck] waits for each of the connection and the answer.
  /// Longer than [timeout]: it runs only once the sites abroad failed, on a
  /// network that may be slow, and a phone that is offline fails at once.
  static const homeTimeout = Duration(seconds: 4);

  /// The sites [homeCheck] tries: the backend's, or [homeUrls].
  static List<String> get currentHomeUrls =>
      ChecklistSettings.current?.homeControl ?? homeUrls;

  final MethodChannel? _channel;

  /// Run every check. [host] null means no server was being dialled, so
  /// only the control fetch and the platform report run.
  Future<Map<String, dynamic>> collect({
    String? host,
    int port = 443,
    String? sni,
  }) async {
    final started = Stopwatch()..start();
    final parts = await Future.wait<Map<String, dynamic>>([
      host == null ? Future.value({}) : dnsCheck(host),
      host == null ? Future.value({}) : tcpTlsCheck(host, port, sni),
      controlCheck().then(
        (control) async => control['control'] == 'ok'
            ? control
            : {...control, ...await homeCheck()},
      ),
      platformReport(),
    ]);
    return {
      for (final p in parts) ...p,
      'diag_ms': started.elapsedMilliseconds,
    };
  }

  /// Where the tunnel's own DNS setting is kept. The native side reads
  /// the same key, so both halves of this report name one resolver.
  static const prefRemoteDns = 'pref_remote_dns';

  /// Only the platform's report: carrier, network type and so on. Cheap
  /// enough to attach to successful connections too, which is what gives
  /// the per-carrier baseline its denominator.
  Future<Map<String, dynamic>> platformReport() async {
    final report = await _nativeReport();
    if (report.containsKey('resolver')) return report;

    // The platform answers with the resolver the core is really running
    // with, defaults included. Where there is no native side to ask, the
    // user's own setting is the most that can honestly be said, and a
    // guess at the core's default would go stale the day it changes.
    final configured = await _configuredResolver();
    if (configured == null) return report;
    return {...report, 'resolver': configured};
  }

  Future<Map<String, dynamic>> _nativeReport() async {
    final channel = _channel;
    if (channel == null) return {};
    try {
      final raw = await channel
          .invokeMethod<Map<Object?, Object?>>('diagnostics')
          .timeout(timeout);
      if (raw == null) return {};
      return raw.map((k, v) => MapEntry(k.toString(), v));
    } on MissingPluginException {
      return {}; // iOS has no native side for this yet
    } catch (_) {
      return {};
    }
  }

  Future<String?> _configuredResolver() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(prefRemoteDns)?.trim();
      return (value == null || value.isEmpty) ? null : value;
    } catch (_) {
      return null;
    }
  }

  static bool isIpLiteral(String host) =>
      InternetAddress.tryParse(host) != null;

  Future<Map<String, dynamic>> dnsCheck(String host) async {
    if (isIpLiteral(host)) return {'dns': 'skipped'};
    final sw = Stopwatch()..start();
    try {
      final addrs = await InternetAddress.lookup(host).timeout(timeout);
      return {
        'dns': addrs.isEmpty ? 'empty' : 'ok',
        'dns_ms': sw.elapsedMilliseconds,
      };
    } on TimeoutException {
      return {'dns': 'timeout', 'dns_ms': sw.elapsedMilliseconds};
    } catch (e) {
      return {
        'dns': 'fail',
        'dns_ms': sw.elapsedMilliseconds,
        'dns_error': _short(e),
      };
    }
  }

  /// TCP to the server, then a TLS handshake over that socket carrying the
  /// Reality SNI. The certificate is not checked: what matters is whether
  /// the handshake completes or is cut, not who signed it.
  Future<Map<String, dynamic>> tcpTlsCheck(
    String host,
    int port,
    String? sni,
  ) async {
    final out = <String, dynamic>{};
    final sw = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      out['tcp'] = 'ok';
      out['tcp_ms'] = sw.elapsedMilliseconds;
    } on TimeoutException {
      return {
        'tcp': 'timeout',
        'tcp_ms': sw.elapsedMilliseconds,
        'tls': 'skipped',
      };
    } on SocketException catch (e) {
      return {
        'tcp': classifySocketError(e),
        'tcp_ms': sw.elapsedMilliseconds,
        'tcp_error': _short(e),
        'tls': 'skipped',
      };
    } catch (e) {
      return {
        'tcp': 'fail',
        'tcp_ms': sw.elapsedMilliseconds,
        'tcp_error': _short(e),
        'tls': 'skipped',
      };
    }

    if (sni == null || sni.isEmpty) {
      socket.destroy();
      return {...out, 'tls': 'skipped'};
    }
    sw.reset();
    SecureSocket? secure;
    try {
      secure = await SecureSocket.secure(
        socket,
        host: sni,
        onBadCertificate: (_) => true,
      ).timeout(timeout);
      out['tls'] = 'ok';
      out['tls_ms'] = sw.elapsedMilliseconds;
      final proto = secure.selectedProtocol;
      if (proto != null) out['tls_alpn'] = proto;
    } on TimeoutException {
      out['tls'] = 'timeout';
      out['tls_ms'] = sw.elapsedMilliseconds;
    } on HandshakeException catch (e) {
      out['tls'] = classifyTlsError(e);
      out['tls_ms'] = sw.elapsedMilliseconds;
      out['tls_error'] = _short(e);
    } on SocketException catch (e) {
      out['tls'] = classifySocketError(e) == 'reset' ? 'reset' : 'fail';
      out['tls_ms'] = sw.elapsedMilliseconds;
      out['tls_error'] = _short(e);
    } catch (e) {
      out['tls'] = 'fail';
      out['tls_ms'] = sw.elapsedMilliseconds;
      out['tls_error'] = _short(e);
    } finally {
      secure?.destroy();
      socket.destroy();
    }
    return out;
  }

  /// Known-open sites abroad ([urls], null: [currentControlUrls]), raced:
  /// `control` is `ok` as soon as one answers 204 or 200 within
  /// [controlTimeout], and `fail` once none did. If this fails the phone
  /// may have no internet, and the failure is not ours to count. An answer
  /// from our own API during the tap says otherwise (PathFinder.answered,
  /// verdictFor).
  ///
  /// Every site starts at once, so the check takes as long as the fastest
  /// answer, and [controlTimeout] at most. The rest are closed then.
  ///
  /// [only204] counts only a 204 and follows no redirect. A captive portal
  /// answers the 204 page with its login page, or a redirect to it, and
  /// the default check counts that as ok. The keeper asks this way
  /// (Keeper.phoneReach), because there a portal must not read as online.
  Future<Map<String, dynamic>> controlCheck({
    List<String>? urls,
    bool only204 = false,
  }) async {
    final list = urls ?? currentControlUrls;
    if (list.isEmpty) return {'control': 'fail'};
    final sw = Stopwatch()..start();
    final clients = <HttpClient>[];
    final first = Completer<String?>();
    var left = list.length;
    for (final url in list) {
      final client = HttpClient()..connectionTimeout = controlTimeout;
      clients.add(client);
      unawaited(() async {
        try {
          final ok = await () async {
            final req = await client.getUrl(Uri.parse(url));
            if (only204) req.followRedirects = false;
            final res = await req.close();
            if (only204) return res.statusCode == 204;
            return res.statusCode == 204 || res.statusCode == 200;
          }().timeout(controlTimeout);
          if (ok && !first.isCompleted) first.complete(url);
        } catch (_) {
          // The others may still answer.
        } finally {
          left -= 1;
          if (left == 0 && !first.isCompleted) first.complete(null);
        }
      }());
    }
    final url = await first.future;
    for (final c in clients) {
      c.close(force: true);
    }
    if (url == null) return {'control': 'fail'};
    return {
      'control': 'ok',
      'control_ms': sw.elapsedMilliseconds,
      'control_url': url,
    };
  }

  /// Does the phone reach a site inside the country, for a phone that
  /// reached none abroad ([controlCheck]). `control_home` is `ok` when one
  /// of [urls] (null: [currentHomeUrls]) answered, `fail` when none did.
  ///
  /// The phone's network is then up and only its way abroad is cut, as in
  /// Iran in June 2025 and January 2026: not "no internet", and the app
  /// keeps searching (ConnectStage.cutOff). The sites are tried at once.
  /// Any answer counts, a redirect or an error page too: over HTTPS with
  /// the certificate checked it can only come from the site itself, so a
  /// captive portal or a block page does not pass.
  ///
  /// Run only after the sites abroad failed, never on its own: a phone
  /// that reaches them says nothing to a site inside the country. No
  /// user agent is sent.
  Future<Map<String, dynamic>> homeCheck({List<String>? urls}) async {
    final list = urls ?? currentHomeUrls;
    if (list.isEmpty) return {'control_home': 'fail'};
    final sw = Stopwatch()..start();
    final clients = <HttpClient>[];
    final first = Completer<String?>();
    var left = list.length;
    for (final url in list) {
      final client = HttpClient()
        ..connectionTimeout = homeTimeout
        ..userAgent = null;
      clients.add(client);
      unawaited(() async {
        try {
          final req = await client.getUrl(Uri.parse(url)).timeout(homeTimeout);
          req.followRedirects = false;
          await req.close().timeout(homeTimeout);
          if (!first.isCompleted) first.complete(url);
        } catch (_) {
          // The others may still answer.
        } finally {
          left -= 1;
          if (left == 0 && !first.isCompleted) first.complete(null);
        }
      }());
    }
    final url = await first.future;
    for (final c in clients) {
      c.close(force: true);
    }
    final ms = sw.elapsedMilliseconds;
    if (url == null) return {'control_home': 'fail', 'control_home_ms': ms};
    return {
      'control_home': 'ok',
      'control_home_ms': ms,
      'control_home_url': url,
    };
  }

  /// `reset`, `refused`, `unreachable`, `timeout` or `fail`, from the OS
  /// error: Linux's numbers (Android), the BSDs' (iOS, macOS), and Windows'
  /// WSA ones. Windows words its messages in the display language, Persian
  /// on many of the PCs this runs on, so there only the number is read.
  static String classifySocketError(SocketException e) {
    final code = e.osError?.errorCode;
    final msg = (e.osError?.message ?? e.message).toLowerCase();
    if (code == 104 || code == 54 || code == 10054 || msg.contains('reset')) {
      return 'reset';
    }
    if (code == 111 || code == 61 || code == 10061 || msg.contains('refused')) {
      return 'refused';
    }
    if (code == 113 ||
        code == 101 ||
        code == 51 ||
        code == 10051 ||
        code == 10065 ||
        msg.contains('unreachable')) {
      return 'unreachable';
    }
    if (code == 10060 || msg.contains('timed out')) return 'timeout';
    return 'fail';
  }

  /// `reset` when the handshake was cut mid-way (the censorship signature),
  /// otherwise `handshake`.
  static String classifyTlsError(HandshakeException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('reset') ||
        msg.contains('eof') ||
        msg.contains('closed')) {
      return 'reset';
    }
    return 'handshake';
  }

  static String _short(Object e) {
    final s = e.toString();
    return s.length > 160 ? s.substring(0, 160) : s;
  }
}
