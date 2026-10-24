import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/state_platforms.dart';
import 'api_client.dart';
import 'api_routes.dart';
import 'built_in.dart';

/// The fallback file, opened: what a phone needs when it cannot reach the
/// backend at all.
///
/// Everything the app connects through comes from the backend, which it
/// reaches directly, through its own tunnel, or through a relay. On some
/// networks the direct route often fails and the relays carry only part of
/// the calls they are given. A phone cut off from all of them had nothing
/// to dial, and a new install had a Connect button with nothing behind it.
///
/// The backend publishes this file on public hosts that are not ours. It
/// names the API relays and shared links that phones in Iran got through
/// lately. One of those links brings a tunnel up, and the app's calls to
/// the backend then go through the tunnel.
///
/// The file is one line, `<body>.<signature>`, both base64url. The
/// signature is Ed25519 over [context] and the body, and is checked before
/// anything else: a host that serves something else is ignored. The body
/// is a version byte, a 12 byte nonce and AES-256-GCM over the
/// zlib-compressed JSON, with [context] as associated data.
class BootstrapFile {
  const BootstrapFile({
    required this.issuedAt,
    required this.text,
    this.relays = const [],
    this.links = const [],
    this.mirrors = const [],
  });

  /// When the backend built it.
  final DateTime issuedAt;

  /// The API relays, as /app/config hands them out.
  final List<ApiRelay> relays;

  /// Shared links, best first.
  final List<String> links;

  /// More places the file is published.
  final List<String> mirrors;

  /// The line as it was read, so it can be saved and opened again.
  final String text;

  static const context = 'fortiva-bootstrap/1';

  /// Open [text], or null when it is not a whole file signed with the key
  /// whose public half is [publicKey].
  static Future<BootstrapFile?> open(
    String text, {
    required List<int> publicKey,
    required List<int> sealKey,
  }) async {
    final json = await openSealed(
      text,
      context: context,
      publicKey: publicKey,
      sealKey: sealKey,
    );
    return json == null ? null : _fromJson(json, text.trim());
  }

  static BootstrapFile? _fromJson(Map json, String text) {
    final seconds = json['issued_at'];
    if (seconds is! int) return null;
    return BootstrapFile(
      issuedAt: DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
        isUtc: true,
      ),
      relays: ApiRelays.parse(json['relays']) ?? const [],
      links: [
        for (final l in json['links'] as List? ?? const [])
          if (l is String && l.isNotEmpty) l,
      ],
      mirrors: Bootstrap.httpsOnly(json['mirrors']),
      text: text,
    );
  }
}

/// The JSON object sealed in [text], or null when [text] is not a whole
/// file signed with the key whose public half is [publicKey] under
/// [context].
///
/// The format of every file the backend publishes for phones that cannot
/// reach it: one line, `<body>.<signature>`, both base64url. The signature
/// is Ed25519 over [context] and the body, and is checked before anything
/// else. The body is a version byte, a 12 byte nonce and AES-256-GCM over
/// the zlib-compressed JSON, with [context] as associated data. Each kind
/// of file has its own [context], so one can never be taken for another.
Future<Map<String, dynamic>?> openSealed(
  String text, {
  required String context,
  required List<int> publicKey,
  required List<int> sealKey,
}) async {
  const version = 1;
  const nonceBytes = 12;
  const tagBytes = 16;
  try {
    final parts = text.trim().split('.');
    if (parts.length != 2) return null;
    final body = base64Url.decode(base64Url.normalize(parts[0]));
    final signature = base64Url.decode(base64Url.normalize(parts[1]));
    final aad = utf8.encode(context);
    final signed = await Ed25519().verify(
      [...aad, ...body],
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
      ),
    );
    if (!signed) return null;
    if (body.length <= 1 + nonceBytes + tagBytes || body[0] != version) {
      return null;
    }
    final sealed = body.sublist(1 + nonceBytes);
    final plain = await AesGcm.with256bits().decrypt(
      SecretBox(
        sealed.sublist(0, sealed.length - tagBytes),
        nonce: body.sublist(1, 1 + nonceBytes),
        mac: Mac(sealed.sublist(sealed.length - tagBytes)),
      ),
      secretKey: SecretKey(sealKey),
      aad: aad,
    );
    final json = jsonDecode(utf8.decode(ZLibCodec().decode(plain)));
    return json is Map ? json.cast<String, dynamic>() : null;
  } catch (e) {
    debugPrint('openSealed: could not open a $context file ($e)');
    return null;
  }
}

/// How a file from another phone was taken. See [Bootstrap.takeFromPeer].
enum PeerTake {
  /// Newer than the one this phone had: kept, saved and in use.
  taken,

  /// Signed by us, but this phone already has the same file or a newer one.
  notNewer,

  /// Not a whole file signed by us.
  refused,
}

/// Reads the fallback file ([BootstrapFile]) from every place it is
/// published, keeps the newest one that opens, and saves it for the next
/// launch.
///
/// Read when a call to the backend fails on the phone's own network
/// ([ApiClient.onDirectFailed]) and the file this phone has is not fresh,
/// not on every launch: a phone that reaches the backend has everything in
/// the file already, and fresher.
class Bootstrap extends ChangeNotifier {
  Bootstrap({
    http.Client Function()? client,
    Future<SharedPreferences> Function()? prefs,
    DateTime Function()? now,
    List<String>? builtIn,
    List<int>? publicKey,
    List<int>? sealKey,
    Duration grace = Bootstrap.grace,
    Future<String?> Function()? seed,
    Future<http.Client?> Function()? tunnel,
  }) : _seed = seed ?? _bundledSeed,
       _tunnel = tunnel ?? _tunnelClient,
       _grace = grace,
       _client = client ?? http.Client.new,
       _prefs = prefs ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now,
       _builtIn = builtIn ?? builtInMirrors,
       _publicKey = publicKey ?? base64.decode(_publicKeyB64),
       _sealKey = sealKey ?? base64.decode(_sealKeyB64);

  /// The one the app uses.
  static final instance = Bootstrap();

  /// Where the backend publishes the file: public hosts that are not ours.
  /// The addresses are in [BuiltIn.fallbackMirrors]. More come from
  /// /app/config and the file itself.
  static const builtInMirrors = BuiltIn.fallbackMirrors;

  /// The copy of the file built into the app (assets/fallback/index.txt),
  /// refreshed before each release by tool/fallback_seed.sh. A new install
  /// that can reach neither the backend nor any host still has relays and
  /// links to try. Any file read later is newer and replaces it.
  static const seedAsset = 'assets/fallback/index.txt';

  static Future<String?> _bundledSeed() async {
    try {
      return await rootBundle.loadString(seedAsset);
    } catch (_) {
      return null;
    }
  }

  /// A client through the running tunnel, or null when none is up.
  static Future<http.Client?> _tunnelClient() async {
    final port = await ApiClient.tunnelSocksPort?.call();
    return port == null ? null : tunnelClient(port, timeout: readTimeout);
  }

  /// What a read of [url] asks for. GitHub's API sends JSON about the file
  /// unless asked for the file itself.
  static Map<String, String> headersFor(String url) =>
      Uri.tryParse(url)?.host == 'api.github.com'
      ? const {'Accept': 'application/vnd.github.raw+json'}
      : const {};

  /// Whether the keys compiled in are keys: 32 bytes each.
  @visibleForTesting
  static bool get keysCompiledIn =>
      base64.decode(_publicKeyB64).length == 32 &&
      base64.decode(_sealKeyB64).length == 32;

  /// The public half of BOOTSTRAP_SIGNING_KEY. A file signed with any other
  /// key is ignored.
  static const _publicKeyB64 = BuiltIn.fallbackPublicKey;

  /// BOOTSTRAP_SEAL_KEY ([BuiltIn.fallbackSealKey]).
  static const _sealKeyB64 = BuiltIn.fallbackSealKey;

  /// The keys compiled in, for the other files the backend seals with them
  /// (NoticesFile).
  static List<int> get publicKey => base64.decode(_publicKeyB64);
  static List<int> get sealKey => base64.decode(_sealKeyB64);

  static const savedKey = 'bootstrap_file';
  static const extraMirrorsKey = 'bootstrap_mirrors';

  /// How long one host gets to answer.
  static const readTimeout = Duration(seconds: 8);

  /// Once one host has given a file that opens, how long the others still
  /// have to give a newer one. A CDN can hold an older copy for hours.
  static const grace = Duration(seconds: 2);

  /// No new read for this long after one that found no file at all: every
  /// host failed, or the phone has no network.
  static const quietAfterNothing = Duration(minutes: 5);

  /// No new read while the file this phone has was built less than this
  /// long ago, or a read got a file that opened less than this long ago.
  /// The backend builds a file at least every hour, and a host can serve
  /// one up to an hour old, so a read that got an old file is not repeated
  /// at once: api.github.com allows 60 reads an hour per address, and many
  /// phones share one address behind a carrier's NAT.
  static const freshFor = Duration(minutes: 30);

  /// How far ahead of this phone's clock a file's build time may be and
  /// still count. Further ahead, the phone's clock is behind, and the build
  /// time says nothing about how old the file is.
  static const clockSlack = Duration(minutes: 5);

  /// The biggest answer read as a file. The real one is a few KB.
  static const maxBytes = 256 * 1024;

  /// How old a file may be and still be handed to another phone (see
  /// [shareable]). Long, because a phone that has been cut off for days
  /// still has nothing newer to get, and the June 2025 shutdown lasted
  /// about two weeks. The other phone keeps it only when it is newer than
  /// its own, so an old one costs it nothing but the try.
  static const shareFor = Duration(days: 14);

  /// How old the file this phone holds may get, while the backend answers,
  /// before the app asks the backend for a newer one ([refreshFromBackend]).
  /// The backend builds one when asked, so this only sets how often a phone
  /// asks: about twice a day for a phone in daily use.
  static const refreshAfter = Duration(hours: 12);

  final Future<String?> Function() _seed;
  final Future<http.Client?> Function() _tunnel;
  final Duration _grace;
  final http.Client Function() _client;
  final Future<SharedPreferences> Function() _prefs;
  final DateTime Function() _now;
  final List<String> _builtIn;
  final List<int> _publicKey;
  final List<int> _sealKey;

  BootstrapFile? _file;
  List<String> _extra = const [];
  Future<void>? _restoring;
  Future<BootstrapFile?>? _reading;
  DateTime? _quietUntil;
  DateTime? _lastGot;
  bool _nothingFound = false;
  DateTime? _askedBackendAt;

  /// The newest file this phone has opened, in this run or an earlier one.
  BootstrapFile? get file => _file;

  /// Whether the last read found no file at all: every host failed, or the
  /// phone had no network. With the backend out of reach too (a read
  /// starts only when a call to it fails), another phone is the one place
  /// left to get a newer file from. False again once one is found, or
  /// taken from another phone.
  bool get nothingFound => _nothingFound;

  /// The file to hand to another phone, or null when this phone has none
  /// to give: the newest file it opened, checked like every other, and
  /// built less than [shareFor] ago.
  BootstrapFile? get shareable {
    final file = _file;
    if (file == null) return null;
    return _now().difference(file.issuedAt) < shareFor ? file : null;
  }

  /// Every place to read the file, built-in first, each once.
  List<String> get mirrors =>
      {..._builtIn, ..._extra, ...?_file?.mirrors}.toList();

  /// Only the https URLs in [value], when it is a list, and only those the
  /// app may ask (StatePlatforms.mayAsk): never a mirror on a state
  /// platform.
  static List<String> httpsOnly(Object? value) => [
    for (final u in value is List ? value : const [])
      if (u is String && u.startsWith('https://') && StatePlatforms.mayAsk(u))
        u,
  ];

  /// Take up the file and the extra places saved by an earlier run. Once
  /// per run; later calls wait for the first.
  Future<void> restore() => _restoring ??= _restore();

  Future<void> _restore() async {
    try {
      final prefs = await _prefs();
      _extra = httpsOnly(jsonDecode(prefs.getString(extraMirrorsKey) ?? '[]'));
      final text = prefs.getString(savedKey);
      final saved = text == null
          ? null
          : await BootstrapFile.open(
              text,
              publicKey: _publicKey,
              sealKey: _sealKey,
            );
      if (saved != null) _take(saved);
    } catch (e) {
      debugPrint('Bootstrap: could not read the saved file ($e)');
    }
    // The copy built into the app, when nothing was read on this phone yet
    // or it is newer than what was: an update brings a newer one.
    final seed = await _seed();
    if (seed == null) return;
    final built = await BootstrapFile.open(
      seed,
      publicKey: _publicKey,
      sealKey: _sealKey,
    );
    final known = _file;
    if (built != null &&
        (known == null || built.issuedAt.isAfter(known.issuedAt))) {
      _take(built, inBuild: true);
    }
  }

  /// Keep the extra places /app/config names (BOOTSTRAP_MIRRORS), so a new
  /// place needs no release. An empty list clears them.
  Future<void> adoptMirrors(List<String> urls) async {
    _extra = List.unmodifiable(httpsOnly(urls));
    try {
      final prefs = await _prefs();
      await prefs.setString(extraMirrorsKey, jsonEncode(_extra));
    } catch (e) {
      debugPrint('Bootstrap: could not save the places ($e)');
    }
  }

  /// [read], unless one is under way, the last read found nothing less
  /// than [quietAfterNothing] ago, or what this phone has is fresh (see
  /// [freshFor]). For callers that cannot wait: never throws, never
  /// awaited.
  void readSoon() {
    if (_reading != null) return;
    final now = _now();
    final quiet = _quietUntil;
    if (quiet != null && now.isBefore(quiet)) return;
    if (_fresh(now)) return;
    unawaited(read());
  }

  bool _fresh(DateTime now) {
    final issued = _file?.issuedAt;
    final built =
        issued != null &&
        !issued.isAfter(now.add(clockSlack)) &&
        now.difference(issued) < freshFor;
    final got = _lastGot;
    return built || (got != null && now.difference(got) < freshFor);
  }

  /// [read], unless what this phone has is fresh (see [freshFor]). For a
  /// phone about to hand its file to another: one whose calls to the
  /// backend work never reads the hosts by itself, and may hold only the
  /// copy built into the app. Returns the newest file now known.
  ///
  /// A connected phone reads through its tunnel. Android leaves this app out
  /// of its own tunnel, so a plain read goes out on the phone's network,
  /// which may be the one cutting the hosts off, and the tunnel is often the
  /// one way abroad. Those reads say nothing about the phone's network, so
  /// they are not reported, and one that finds nothing leaves [nothingFound]
  /// and [readSoon] as they were. Without a tunnel, a read that found nothing
  /// less than [quietAfterNothing] ago is not repeated.
  Future<BootstrapFile?> readForSharing() async {
    await restore();
    final now = _now();
    if (_fresh(now)) return _file;
    http.Client? through;
    try {
      through = await _tunnel();
    } catch (e) {
      debugPrint('Bootstrap: no client through the tunnel ($e)');
    }
    if (through != null) return _readWith(tunnel: through);
    final quiet = _quietUntil;
    if (quiet != null && now.isBefore(quiet)) return _file;
    return read();
  }

  /// Take a file another phone passed on: scanned from its screen, sent as
  /// a file or pasted. It goes through [BootstrapFile.open] like a file
  /// read from a host, so a phone can pass on only what the backend signed,
  /// and it is kept only when it is newer than the one this phone has.
  Future<PeerTake> takeFromPeer(String text) async {
    await restore();
    if (text.length > maxBytes) return PeerTake.refused;
    final opened = await BootstrapFile.open(
      text,
      publicKey: _publicKey,
      sealKey: _sealKey,
    );
    if (opened == null) return PeerTake.refused;
    if (!await _adopt(opened)) return PeerTake.notNewer;
    if (_nothingFound) {
      _nothingFound = false;
      notifyListeners();
    }
    return PeerTake.taken;
  }

  /// Ask the backend for the file ([fetch], GET /api/v1/app/fallback-file),
  /// when the one this phone holds was built more than [refreshAfter] ago,
  /// and keep it when it is newer. Called once the backend has answered
  /// (AppConfigState). Never throws.
  ///
  /// The hosts are read only when the backend cannot be reached, so a phone
  /// that always reached it held nothing newer than the copy built into its
  /// release, and a cut found it with that: relays and links as old as the
  /// release. With this, it holds a file built that day, and one fresh
  /// enough to hand to a friend ([shareable]).
  Future<bool> refreshFromBackend(Future<String?> Function() fetch) async {
    try {
      await restore();
      final now = _now();
      final asked = _askedBackendAt;
      if (asked != null && now.difference(asked) < refreshAfter) return false;
      final issued = _file?.issuedAt;
      if (issued != null &&
          !issued.isAfter(now.add(clockSlack)) &&
          now.difference(issued) < refreshAfter) {
        return false;
      }
      _askedBackendAt = now;
      final text = await fetch();
      if (text == null || text.length > maxBytes) return false;
      final opened = await BootstrapFile.open(
        text,
        publicKey: _publicKey,
        sealKey: _sealKey,
      );
      if (opened == null || !await _adopt(opened)) return false;
      if (_nothingFound) {
        _nothingFound = false;
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Bootstrap: could not get the file from the backend ($e)');
      return false;
    }
  }

  /// Read the file from every place at once. Returns the newest file now
  /// known, which is the saved one when no place gave a newer one.
  Future<BootstrapFile?> read() => _readWith();

  /// [read], through [tunnel] when one is given. [tunnel] is closed when
  /// the read ends, or at once when a read is already under way: that one
  /// is waited for rather than a second started.
  Future<BootstrapFile?> _readWith({http.Client? tunnel}) {
    final reading = _reading;
    if (reading != null) {
      tunnel?.close();
      return reading;
    }
    return _reading = _read(tunnel).whenComplete(() {
      _reading = null;
    });
  }

  /// Without [tunnel], the read goes out on the phone's own network, and
  /// only such a read is reported and says whether the hosts are cut off
  /// here ([nothingFound], [quietAfterNothing]). A file read through the
  /// tunnel is kept all the same.
  Future<BootstrapFile?> _read(http.Client? tunnel) async {
    final ownNetwork = tunnel == null;
    await restore();
    final urls = mirrors;
    if (urls.isEmpty) {
      tunnel?.close();
      return _file;
    }
    // A file taken from another phone while this read runs.
    final atStart = _file;
    final client = tunnel ?? _client();
    final done = Completer<void>();
    var left = urls.length;
    var over = false;
    Timer? graceTimer;
    BootstrapFile? best;
    for (final url in urls) {
      unawaited(
        _readOne(client, url, () => over, observe: ownNetwork)
            .then((opened) {
              if (opened == null) return;
              if (best == null || opened.issuedAt.isAfter(best!.issuedAt)) {
                best = opened;
              }
              graceTimer ??= Timer(_grace, () {
                if (!done.isCompleted) done.complete();
              });
            })
            .whenComplete(() {
              if (--left == 0 && !done.isCompleted) done.complete();
            }),
      );
    }
    await done.future;
    over = true;
    graceTimer?.cancel();
    // Reads still under way are dropped. They are not failures of their
    // hosts, so they are not reported as any.
    client.close();
    final found = best;
    final before = _nothingFound;
    if (ownNetwork) {
      if (found != null) {
        _nothingFound = false;
      } else if (identical(_file, atStart)) {
        // Not when another phone's file arrived meanwhile: there is one now.
        _nothingFound = true;
      }
    }
    if (found != null) {
      // Through the tunnel too: this phone now has what the hosts have,
      // and their limits count every read (see [freshFor]).
      _lastGot = _now();
      await _adopt(found);
    } else if (ownNetwork) {
      _quietUntil = _now().add(quietAfterNothing);
    }
    if (_nothingFound != before) notifyListeners();
    return _file;
  }

  Future<BootstrapFile?> _readOne(
    http.Client client,
    String url,
    bool Function() over, {
    required bool observe,
  }) async {
    final watch = Stopwatch()..start();
    int? status;
    Object? error;
    BootstrapFile? opened;
    try {
      final response = await client
          .get(Uri.parse(url), headers: headersFor(url))
          .timeout(readTimeout);
      status = response.statusCode;
      if (status == 200 && response.bodyBytes.length <= maxBytes) {
        opened = await BootstrapFile.open(
          utf8.decode(response.bodyBytes, allowMalformed: true),
          publicKey: _publicKey,
          sealKey: _sealKey,
        );
      }
      if (status == 200 && opened == null) {
        // An answer that is not our file: a block page, or a host that
        // has something else at this path. Not a working host.
        status = null;
        error = const FormatException('not the file');
      }
    } catch (e) {
      error = e;
    }
    if (observe && !over()) _observe(url, watch.elapsed, status, error);
    return opened;
  }

  /// Tell the delivery log how a read went, as a call on the route
  /// "mirror:" and the host, so the backend learns which hosts work where.
  static void _observe(
    String url,
    Duration elapsed,
    int? status,
    Object? error,
  ) {
    final listener = ApiClient.onRouteAttempt;
    if (listener == null) return;
    try {
      listener(
        RouteAttempt(
          method: 'GET',
          endpoint: endpoint,
          route: 'mirror:${Uri.tryParse(url)?.host ?? ''}',
          bytes: 0,
          elapsed: elapsed,
          status: status,
          error: status == null ? error : null,
        ),
      );
    } catch (e) {
      debugPrint('Bootstrap: route listener failed ($e)');
    }
  }

  /// The endpoint a read is logged under.
  static const endpoint = '/bootstrap';

  /// Keep [found] and save it, when it is newer than the file this phone
  /// has. Returns whether it was.
  Future<bool> _adopt(BootstrapFile found) async {
    final known = _file;
    if (known != null && !found.issuedAt.isAfter(known.issuedAt)) {
      return false;
    }
    _take(found);
    try {
      final prefs = await _prefs();
      await prefs.setString(savedKey, found.text);
    } catch (e) {
      debugPrint('Bootstrap: could not save the file ($e)');
    }
    return true;
  }

  void _take(BootstrapFile file, {bool inBuild = false}) {
    _file = file;
    ApiRelays.addFound(file.relays, issuedAt: file.issuedAt, inBuild: inBuild);
    notifyListeners();
  }
}
