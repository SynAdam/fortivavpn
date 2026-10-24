import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/network_keys.dart';
import 'built_in.dart';
import 'server_clock.dart';

/// A relay: a server outside Iran that passes the app's calls on to the
/// backend.
///
/// The backend sits behind Cloudflare, and a carrier can cut part of the
/// connections to it: a phone then fetches the app config and never
/// manages to register, upload its failed connect or upload its door
/// checks, so its failure never reaches the live page. A relay is
/// a second way in that does not start on Cloudflare. It is dialled by
/// address, so there is no name for a resolver to poison, and its
/// certificate is pinned, so nothing between the phone and the relay can
/// stand in for it.
class ApiRelay {
  const ApiRelay({required this.url, required this.pin});

  /// Where the relay listens, such as `https://203.0.113.5:443`.
  final String url;

  /// The lowercase hex SHA-256 of the relay certificate's DER bytes.
  final String pin;

  static final _hex64 = RegExp(r'^[0-9a-f]{64}$');

  /// A relay from its JSON form, or null when it is not one this app can
  /// use safely: an https URL and a well-formed pin are both required.
  static ApiRelay? fromJson(Object? json) {
    if (json is! Map) return null;
    final url = json['url'];
    final pin = json['pin'];
    if (url is! String || pin is! String) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    final normalised = pin.toLowerCase();
    if (!_hex64.hasMatch(normalised)) return null;
    return ApiRelay(url: url.replaceAll(RegExp(r'/+$'), ''), pin: normalised);
  }

  Map<String, dynamic> toJson() => {'url': url, 'pin': pin};

  /// Whether [certificate] is the one this relay was built with.
  bool matches(X509Certificate certificate) =>
      sha256.convert(certificate.der).toString() == pin;

  @override
  bool operator ==(Object other) =>
      other is ApiRelay && other.url == url && other.pin == pin;

  @override
  int get hashCode => Object.hash(url, pin);
}

/// The relays this phone knows, from the backend when it has answered and
/// from [builtIn] until then, and how each one did on each network the
/// phone was on.
class ApiRelays {
  ApiRelays._();

  static const savedRelaysKey = 'api_relays';

  /// Compiled in, so a phone that has never reached the backend still has
  /// a relay to try. The backend's list replaces it once one arrives. The
  /// addresses are in [BuiltIn.relays].
  static final builtIn = <ApiRelay>[
    for (final r in BuiltIn.relays) ApiRelay(url: r.url, pin: r.pin),
  ];

  static const workedKey = 'api_relay_worked';

  /// What each network taught: the relay that last carried a call there,
  /// and the relays that failed there lately, with when. One JSON map,
  /// keyed by what [networkKey] answered there.
  static const memoryKey = 'api_relay_memory';

  /// When the backend's list under [savedRelaysKey] was saved.
  static const savedAtKey = 'api_relays_at';

  /// How long a relay that failed on a network goes after the others
  /// there.
  static const failedFor = Duration(minutes: 30);

  /// How many networks [memoryKey] keeps. The one written to longest ago
  /// goes first.
  static const maxNetworks = 20;

  /// Reads the key of the network the phone is on, the one the door memory
  /// is kept by: the transport and the carrier, such as "wifi" or
  /// "mobile:Irancell" (ConnectFlow.currentNetworkKey). Set at startup by
  /// main.dart. Null, as in tests, puts the relay that last carried a call
  /// on any network first, as builds up to 1.8.0 did.
  static Future<String> Function()? networkKey;

  /// How long ordering the relays, or noting how one did, waits for
  /// [networkKey]. On mobile data it asks the platform for the carrier,
  /// and ConnectDiagnostics gives that call 2.5 seconds. Without an answer
  /// in time the call goes as if the phone could not name its network. An
  /// answer that comes later is still kept, for the calls after it.
  static const networkWait = Duration(seconds: 1);

  /// How long one answer of [networkKey] is used before it is read again.
  /// Longer than one route's 10 second timeout (ApiConfig.timeout), so a
  /// relay that timed out right after its call read the network is noted
  /// under that same network. Short, so a phone that moved to another
  /// network reads the new one soon.
  static const networkFresh = Duration(seconds: 15);

  /// What [networkKey] answers when it names no network: none at all, or
  /// one whose transport it could not read. Neither is a network to
  /// remember relays by.
  static const _noNetwork = {'none', 'unknown'};

  /// The phone's clock, for when a relay failed and when the network was
  /// read. Tests set it.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  static List<ApiRelay>? _current;
  static DateTime? _currentAt;

  /// Whether [_current] is a list the backend sent, rather than [builtIn].
  static bool _currentFromBackend = false;

  /// The relays the fallback file named (Bootstrap), and when the backend
  /// built that file.
  static List<ApiRelay>? _found;
  static DateTime? _foundAt;

  /// Whether [_found] is the copy built into the app, not one read from a
  /// host.
  static bool _foundInBuild = false;

  /// The url of the relay that last carried a call, on any network, read
  /// once per run.
  static String? _worked;
  static bool _workedRead = false;

  /// What [memoryKey] holds, read once per run.
  static Map<String, Map<String, dynamic>>? _networks;

  /// [networkKey]'s last answer that named a network, and when it came.
  static String? _network;
  static DateTime? _networkAt;

  /// The read of [networkKey] under way. Calls that need the network while
  /// it runs wait for it rather than start another.
  static Future<String?>? _networkRead;

  /// Moved on by [forgetNetworks]. A read or note begun before that keeps
  /// nothing it held.
  static int _generation = 0;

  /// Forget what this run holds of the networks the phone was on. Account
  /// deletion removes [memoryKey] from storage, and without this the next
  /// note would write the map held in memory back.
  static void forgetNetworks() {
    _generation++;
    _networks = null;
    _network = null;
    _networkAt = null;
    _networkRead = null;
  }

  static bool _closed = false;

  /// No memory of networks is read, kept or saved until [reopenNetworks]:
  /// account deletion removes [memoryKey] in the middle of a long removal,
  /// and a relay call in between would read the old map and save it back.
  /// Relays keep working meanwhile, in the backend's order with the relay
  /// that last carried a call first.
  static void closeNetworks() {
    _closed = true;
    forgetNetworks();
  }

  static void reopenNetworks() {
    forgetNetworks();
    _closed = false;
  }

  /// The relays to try. One list decides, the newer one, never a mix: the
  /// backend's from /app/config, or the fallback file's when that file was
  /// built after the backend's list was saved, or when none was ever saved
  /// with its time. [builtIn] when there is neither. Each list is taken
  /// whole, so the backend's order, a relay it took out and an empty list
  /// that turns relays off all hold, and a copy of the file built into an
  /// older release cannot undo them.
  ///
  /// Within the list, on the network the phone is on: the relay that last
  /// carried a call there first, then the relays that have not failed there
  /// in the last [failedFor], in list order, then the ones that have, the
  /// one that failed longest ago first. A relay that failed there in that
  /// time never goes first, not even the one that last carried a call
  /// there, and none is ever left out. How often a relay answers depends
  /// a great deal on the network, and an IPv6 relay answers nothing on a
  /// line with no IPv6. Phones are often dual-SIM or move between Wi-Fi
  /// and mobile data. With one relay remembered for every network, such a
  /// phone tried first the relay that had worked on its other network, and
  /// a relay that had just timed out went first again on the next call.
  ///
  /// On a network where no relay in the list carried a call yet, and on
  /// every network when the phone cannot name it (see [networkKey]), the
  /// relay that last carried a call on any network goes first, as before,
  /// unless it failed on this network lately. That is also how what a phone
  /// learned before this memory existed is kept ([workedKey]).
  static Future<List<ApiRelay>> current() async {
    final known = await _known();
    final found = _found;
    final foundAt = _foundAt;
    final knownAt = _currentAt;
    // A list saved with no time, by a build up to 1.7.0, came from the
    // backend at some point after the copy built into this release could
    // have been made, as far as anyone knows, so only a file read from a
    // host replaces it.
    final useFound =
        found != null &&
        foundAt != null &&
        (knownAt != null
            ? foundAt.isAfter(knownAt)
            : !(_foundInBuild && _currentFromBackend));
    final list = useFound ? found : known;
    // Nothing to put in order.
    if (list.length < 2) return list;
    final worked = await _workedUrl();
    final network = await _currentNetwork();
    final memory = network == null ? null : (await _memory())[network];
    return _ordered(list, memory, worked);
  }

  /// [list] in the order to try it on a network whose memory is [memory],
  /// null for none (see [current]). [anywhere] is the url of the relay that
  /// last carried a call on any network.
  static List<ApiRelay> _ordered(
    List<ApiRelay> list,
    Map<String, dynamic>? memory,
    String? anywhere,
  ) {
    final failed = _failures(memory, clock());
    final here = memory?['worked'];
    var first = here is String && list.any((r) => r.url == here)
        ? here
        : anywhere;
    if (failed.containsKey(first)) first = null;
    final heldBack = [
      for (final (i, r) in list.indexed)
        if (failed.containsKey(r.url)) (i, r),
    ];
    // Two that failed at the same moment keep their order in the list.
    heldBack.sort((a, b) {
      final byTime = failed[a.$2.url]!.compareTo(failed[b.$2.url]!);
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    });
    return [
      ...list.where((r) => r.url == first),
      ...list.where((r) => r.url != first && !failed.containsKey(r.url)),
      for (final (_, r) in heldBack) r,
    ];
  }

  /// The relays that failed on a network in the last [failedFor], by url,
  /// with when, from its [memory]. A failure dated after [now] is left
  /// out: the clock was set back since, and the failure would otherwise
  /// hold its relay back until the clock caught up with it.
  static Map<String, DateTime> _failures(
    Map<String, dynamic>? memory,
    DateTime now,
  ) {
    final raw = memory?['failed'];
    if (raw is! Map) return {};
    final out = <String, DateTime>{};
    raw.forEach((url, at) {
      final when = DateTime.tryParse(at is String ? at : '');
      if (when == null) return;
      final age = now.difference(when);
      if (!age.isNegative && age < failedFor) out[url.toString()] = when;
    });
    return out;
  }

  static Future<List<ApiRelay>> _known() async {
    final known = _current;
    if (known != null) return known;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(savedRelaysKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          // Builds up to 1.7.0 saved no time; such a list is older than
          // any file.
          _currentAt = DateTime.tryParse(prefs.getString(savedAtKey) ?? '');
          _currentFromBackend = true;
          return _current = [for (final e in decoded) ?ApiRelay.fromJson(e)];
        }
      }
    } catch (e) {
      debugPrint('ApiRelays: could not read the saved relays ($e)');
    }
    return _current = builtIn;
  }

  static Future<String?> _workedUrl() async {
    if (_workedRead) return _worked;
    _workedRead = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _worked ??= prefs.getString(workedKey);
    } catch (e) {
      debugPrint('ApiRelays: could not read the last relay ($e)');
    }
    return _worked;
  }

  /// [relay] carried a call on the phone's own network: try it first on
  /// this network from now on, in this run and the next. The relay the
  /// backend lists first is not always the one that answers best, and
  /// without this every call that needed a relay waited out the first
  /// one's timeout before reaching the second.
  ///
  /// It is also kept as the relay that last carried a call on any network
  /// ([workedKey]), for the networks [current] has nothing else for.
  static Future<void> noteWorked(ApiRelay relay) async {
    final generation = _generation;
    if (_worked != relay.url) {
      _worked = relay.url;
      _workedRead = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(workedKey, relay.url);
      } catch (e) {
        debugPrint('ApiRelays: could not save the last relay ($e)');
      }
    }
    final network = await _currentNetwork();
    if (network == null) return;
    final all = await _memory();
    final memory = all[network];
    final failed = _failures(memory, clock());
    if (memory?['worked'] == relay.url && !failed.containsKey(relay.url)) {
      return;
    }
    // A relay that works here is not one that failed here.
    failed.remove(relay.url);
    await _save(all, network, {
      'worked': relay.url,
      ..._failedJson(failed),
    }, generation);
  }

  /// [relay] did not carry a call on the phone's own network: for
  /// [failedFor] it goes after the relays that did not fail on this
  /// network, also when it is the one that last carried a call here.
  static Future<void> noteFailed(ApiRelay relay) async {
    final generation = _generation;
    final network = await _currentNetwork();
    if (network == null) return;
    final all = await _memory();
    final memory = all[network];
    final now = clock();
    final worked = memory?['worked'];
    final failed = _failures(memory, now)..[relay.url] = now;
    await _save(all, network, {
      if (worked is String) 'worked': worked,
      ..._failedJson(failed),
    }, generation);
  }

  /// [failed] as a network's memory stores it, with nothing when it is
  /// empty.
  static Map<String, dynamic> _failedJson(Map<String, DateTime> failed) => {
    if (failed.isNotEmpty)
      'failed': {
        for (final e in failed.entries)
          e.key: e.value.toUtc().toIso8601String(),
      },
  };

  /// What [memoryKey] holds. Read once per run, so every note changes the
  /// same map and two notes at once cannot undo each other.
  static Future<Map<String, Map<String, dynamic>>> _memory() async {
    if (_closed) return {};
    final known = _networks;
    if (known != null) return known;
    final generation = _generation;
    var read = <String, Map<String, dynamic>>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(memoryKey);
      final decoded = raw == null ? null : jsonDecode(raw);
      if (decoded is Map) {
        read = {
          for (final e in decoded.entries)
            if (e.value is Map)
              e.key.toString(): Map<String, dynamic>.from(e.value as Map),
        };
      }
    } catch (e) {
      debugPrint('ApiRelays: could not read the relay memory ($e)');
    }
    // Read before a forget: not kept, and the note that asked saves nothing.
    if (generation != _generation) return read;
    // A read that ran beside this one may have finished first, and notes
    // may already have changed what it read.
    return _networks ??= read;
  }

  /// Keep [memory] as what [network] taught, in [all], and save [all].
  /// [network] goes last, so past [maxNetworks] the network written to
  /// longest ago is the one that goes. Nothing is saved when [forgetNetworks]
  /// ran since the note began ([generation]).
  static Future<void> _save(
    Map<String, Map<String, dynamic>> all,
    String network,
    Map<String, dynamic> memory,
    int generation,
  ) async {
    if (_closed || generation != _generation) return;
    if (!NetworkKeys.mayKeep(network)) return;
    all.remove(network);
    all[network] = memory;
    while (all.length > maxNetworks) {
      all.remove(all.keys.first);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(memoryKey, jsonEncode(all));
    } catch (e) {
      debugPrint('ApiRelays: could not save the relay memory ($e)');
    }
  }

  /// The key of the network the phone is on, or null when there is none to
  /// go by: no [networkKey], an answer that names no network, or none
  /// within [networkWait]. Never throws.
  static Future<String?> _currentNetwork() {
    final read = networkKey;
    if (read == null || _closed) return Future.value();
    final at = _networkAt;
    if (at != null) {
      final age = clock().difference(at);
      if (!age.isNegative && age < networkFresh) return Future.value(_network);
    }
    // Cleared once the read is over, never before it is in place: a
    // callback on a future always runs later.
    return _networkRead ??= _readNetwork(read).whenComplete(() {
      _networkRead = null;
    });
  }

  static Future<String?> _readNetwork(Future<String> Function() read) async {
    final generation = _generation;
    try {
      // _heard runs whenever the answer comes, also after the wait.
      return await Future.sync(
        read,
      ).then((key) => _heard(key, generation)).timeout(networkWait);
    } catch (e) {
      debugPrint('ApiRelays: no network to go by ($e)');
      return null;
    }
  }

  /// Keep [key], [networkKey]'s answer, for [networkFresh] when it names a
  /// network. Returns it then, and null otherwise.
  static String? _heard(String key, int generation) {
    // A network read with the salt a deletion removed is not kept.
    if (_closed || generation != _generation) return null;
    final named = key.isNotEmpty && !_noNetwork.contains(key);
    _network = named ? key : null;
    _networkAt = named ? clock() : null;
    return _network;
  }

  /// The relays the fallback file named, in a file the backend built at
  /// [issuedAt]. See [current] for when they count.
  static void addFound(
    List<ApiRelay> relays, {
    required DateTime issuedAt,
    bool inBuild = false,
  }) {
    _found = List.unmodifiable(relays);
    _foundAt = issuedAt;
    _foundInBuild = inBuild;
  }

  /// Keep the backend's list. An empty list is kept as empty: it is the
  /// backend saying not to use any relay, for example after one was
  /// found to be compromised. A config without the key never reaches here.
  static Future<void> adopt(List<ApiRelay> relays) async {
    _current = List.unmodifiable(relays);
    _currentFromBackend = true;
    // The backend's time, so it compares with the time a file was made
    // whatever this phone's clock says.
    final at = _currentAt = ServerClock.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        savedRelaysKey,
        jsonEncode([for (final r in relays) r.toJson()]),
      );
      await prefs.setString(savedAtKey, at.toIso8601String());
    } catch (e) {
      debugPrint('ApiRelays: could not save the relays ($e)');
    }
  }

  /// Parse the `api_relays` value of the app config. Null when the key is
  /// absent, so an older backend does not wipe what the phone knows.
  static List<ApiRelay>? parse(Object? value) {
    if (value is! List) return null;
    return [for (final e in value) ?ApiRelay.fromJson(e)];
  }

  @visibleForTesting
  static void resetForTest() {
    _current = null;
    _currentAt = null;
    _currentFromBackend = false;
    _found = null;
    _foundAt = null;
    _foundInBuild = false;
    _worked = null;
    _workedRead = false;
    _networks = null;
    _network = null;
    _networkAt = null;
    _networkRead = null;
    _generation = 0;
    _closed = false;
    networkKey = null;
    clock = DateTime.now;
  }
}

/// The name the app puts in its hello to a relay.
///
/// A relay is dialled by address, and when Dart dials an address it puts
/// that address in the hello as the name. A line test on Hamrah Aval mobile
/// data on 2026-10-09 showed that it cuts an IPv4 hello whose name is an
/// address, and one with no name at all: the app's own client never got an
/// answer from a relay over IPv4 there. The same relay answered with this
/// name on the same line. The relay serves the same certificate whatever
/// the name, and the pin decides, so the name only changes what the network
/// sees.
const relayServerName = 'www.samsung.com';

/// A client that sends every request to a relay and accepts only the
/// relay's own certificate.
///
/// No trusted roots at all, so every certificate reaches the pin check:
/// with the system roots, a certificate some public authority issued for
/// the relay's address, or for [relayServerName], would be accepted
/// without one.
///
/// The TLS handshake is done in the connection factory, because HttpClient
/// names the address itself when it dials one. The factory always dials the
/// relay, so the client never uses a proxy: with one set in the
/// environment, HttpClient would send its CONNECT request to the relay
/// inside the finished handshake, and the relay would refuse it.
http.Client relayClient(ApiRelay relay, {required Duration timeout}) {
  final context = SecurityContext(withTrustedRoots: false);
  final client = HttpClient()
    ..connectionTimeout = timeout
    ..findProxy = ((_) => 'DIRECT')
    ..connectionFactory = (uri, _, _) async {
      final task = await Socket.startConnect(uri.host, uri.port);
      final ready = task.socket.then((socket) async {
        try {
          return await SecureSocket.secure(
            socket,
            host: relayServerName,
            context: context,
            onBadCertificate: relay.matches,
          );
        } catch (_) {
          socket.destroy();
          rethrow;
        }
      });
      return ConnectionTask.fromSocket(ready, task.cancel);
    };
  return IOClient(client);
}

/// A client that sends every request to [relay] through the SOCKS port of
/// the running tunnel, and accepts only the relay's own certificate.
///
/// For a tunnel whose exit cannot reach Cloudflare. On 2026-10-11 a phone
/// with the API and every relay cut on its own network got a tunnel from a
/// link in the fallback file, and could still not reach us: that link's
/// exit loaded GitHub and Google and timed out on every Cloudflare address.
/// The relays are on other networks, and through the tunnel they are
/// dialled from abroad, where their addresses are not blocked.
http.Client tunnelRelayClient(
  int socksPort,
  ApiRelay relay, {
  required Duration timeout,
}) {
  final context = SecurityContext(withTrustedRoots: false);
  final client = HttpClient()
    ..connectionTimeout = timeout
    ..findProxy = ((_) => 'DIRECT')
    ..connectionFactory = (uri, _, _) async {
      final task = await Socket.startConnect('127.0.0.1', socksPort);
      final port = uri.hasPort ? uri.port : 443;
      final ready = task.socket.then((socket) async {
        try {
          await socks5Handshake(socket, uri.host, port);
          return await SecureSocket.secure(
            socket,
            host: relayServerName,
            context: context,
            onBadCertificate: relay.matches,
          );
        } catch (_) {
          socket.destroy();
          rethrow;
        }
      });
      return ConnectionTask.fromSocket(ready, task.cancel);
    };
  return IOClient(client);
}

/// A client that sends every request through the SOCKS port of the
/// running tunnel.
///
/// Android leaves this app out of its own tunnel, or the core's traffic
/// would loop back into it, so an ordinary request goes out on the phone's
/// own network whether or not a tunnel is up. When that network is the
/// thing cutting us off, the core's local SOCKS port is the way through.
///
/// [onBadCertificate] is for tests, whose servers have no public
/// certificate.
http.Client tunnelClient(
  int socksPort, {
  required Duration timeout,
  @visibleForTesting bool Function(X509Certificate)? onBadCertificate,
}) {
  final client = HttpClient()
    ..connectionTimeout = timeout
    ..connectionFactory = socksConnector(
      socksPort,
      onBadCertificate: onBadCertificate,
    );
  return IOClient(client);
}

/// Something went wrong between this app and a SOCKS proxy.
class SocksException implements IOException {
  const SocksException(this.message);

  final String message;

  @override
  String toString() => 'SocksException: $message';
}

/// An [HttpClient.connectionFactory] that opens every connection through
/// the SOCKS5 proxy at [proxyHost]:[proxyPort], with no authentication.
///
/// https only. The TLS handshake is done here, over the proxied socket,
/// because HttpClient uses whatever socket the factory returns as it is.
/// A plain socket could not be handed back: the SOCKS replies were read
/// from it, and a socket's bytes can be read by one listener only.
Future<ConnectionTask<Socket>> Function(Uri, String?, int?) socksConnector(
  int proxyPort, {
  String proxyHost = '127.0.0.1',
  bool Function(X509Certificate)? onBadCertificate,
}) {
  return (uri, _, _) async {
    if (uri.scheme != 'https') {
      throw SocksException('only https goes through the tunnel: $uri');
    }
    final task = await Socket.startConnect(proxyHost, proxyPort);
    final port = uri.hasPort ? uri.port : 443;
    final ready = task.socket.then((socket) async {
      try {
        await socks5Handshake(socket, uri.host, port);
        return await SecureSocket.secure(
          socket,
          host: uri.host,
          onBadCertificate: onBadCertificate,
        );
      } catch (_) {
        socket.destroy();
        rethrow;
      }
    });
    return ConnectionTask.fromSocket(ready, task.cancel);
  };
}

/// Ask the SOCKS5 proxy on [socket] to connect it to [host]:[port].
///
/// Reads exactly the proxy's replies, then pauses its listener rather than
/// cancelling it: cancelling shuts the socket's read side, and the caller
/// still has a TLS handshake to run over it.
@visibleForTesting
Future<void> socks5Handshake(Socket socket, String host, int port) async {
  final reader = _ByteReader(socket);
  try {
    socket.add(const [0x05, 0x01, 0x00]);
    final hello = await reader.take(2);
    if (hello[0] != 0x05 || hello[1] != 0x00) {
      throw const SocksException('proxy refused no-authentication');
    }

    socket.add([0x05, 0x01, 0x00, ..._address(host), port >> 8, port & 0xff]);
    final head = await reader.take(4);
    if (head[0] != 0x05) throw const SocksException('not a SOCKS5 reply');
    if (head[1] != 0x00) {
      throw SocksException('proxy could not connect (reply ${head[1]})');
    }
    final bound = switch (head[3]) {
      0x01 => 4,
      0x04 => 16,
      0x03 => (await reader.take(1))[0],
      _ => throw SocksException('unknown address type ${head[3]}'),
    };
    await reader.take(bound + 2);
  } finally {
    reader.pause();
  }
}

/// The address part of a SOCKS5 connect request.
List<int> _address(String host) {
  final ip = InternetAddress.tryParse(host);
  if (ip != null) {
    return [
      ip.type == InternetAddressType.IPv6 ? 0x04 : 0x01,
      ...ip.rawAddress,
    ];
  }
  final name = utf8.encode(host);
  if (name.length > 255) throw const SocksException('host name too long');
  return [0x03, name.length, ...name];
}

/// Serves a socket's bytes a fixed number at a time.
class _ByteReader {
  _ByteReader(Socket socket) {
    _subscription = socket.listen(
      (data) {
        _buffer.add(data);
        _serve();
      },
      onError: (Object e) => _fail(e),
      onDone: () => _fail(const SocksException('proxy closed the connection')),
    );
  }

  late final StreamSubscription<Uint8List> _subscription;
  final _buffer = BytesBuilder();
  int _wanted = 0;
  Completer<Uint8List>? _waiting;

  Future<Uint8List> take(int count) {
    _wanted = count;
    final waiting = _waiting = Completer<Uint8List>();
    _serve();
    return waiting.future;
  }

  void pause() => _subscription.pause();

  void _serve() {
    final waiting = _waiting;
    if (waiting == null || _buffer.length < _wanted) return;
    final bytes = _buffer.takeBytes();
    _waiting = null;
    if (bytes.length > _wanted) _buffer.add(bytes.sublist(_wanted));
    waiting.complete(Uint8List.sublistView(bytes, 0, _wanted));
  }

  void _fail(Object error) {
    final waiting = _waiting;
    _waiting = null;
    if (waiting != null && !waiting.isCompleted) waiting.completeError(error);
  }
}
