import '../../utils/link_id.dart';
import '../../utils/vless_link.dart';

/// Server model representing a VPN server location
class Server {
  final String id;
  final String name;
  final String country;
  final String city;
  final String connectionUri;
  final String flagEmoji;
  final String remark;
  final int? latencyMs;
  final ServerLoad load;
  final bool isPremium;

  /// Prefix of the ids [fromConnectionUri] hands out.
  static const communityIdPrefix = 'telegram-';

  /// Whether this is a link the crawler picked up from a public channel.
  ///
  /// Read off the id, because that is where [fromConnectionUri] already
  /// records it. A field serialised through every cache would buy nothing
  /// for a distinction only the list and the home card draw.
  bool get isCommunity => id.startsWith(communityIdPrefix);

  /// The name a community link with no country is stored under:
  /// "Community 3". English and Western digits on purpose, because it is
  /// also what gets persisted (the session log, the last connection), and
  /// screens turn it into the phone's language when they show it
  /// ([communityNumberOf], serverTitle).
  static String communityFallbackName(int number) => 'Community $number';

  /// The number in a [communityFallbackName], or null for any other name.
  static int? communityNumberOf(String name) {
    final match = _fallbackName.firstMatch(name);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  // At most six digits: a list never holds a million links, and a saved
  // label such as "Community 99999999999999999999" must not throw.
  static final _fallbackName = RegExp(r'^Community (\d{1,6})$');

  /// The 1-based position of a community link in its list, read off the
  /// id. What a tile calls the link when it says no country, so that two
  /// links with nothing else to tell them apart still read differently.
  /// 0 for anything that is not a community link.
  int get communityNumber {
    if (!isCommunity) return 0;
    return (int.tryParse(id.substring(communityIdPrefix.length)) ?? -1) + 1;
  }

  /// The id of [psiphon], the backup network.
  static const psiphonId = 'psiphon';

  /// What the events of a session on the backup network name as its
  /// server: always this, never an address of the network's.
  static const psiphonHost = 'psiphon';

  /// The name a session on the backup network is stored under, in the
  /// session log and the last connection. Screens show it in the phone's
  /// language (storedServerTitle).
  static const psiphonName = 'Backup network';

  /// The backup network, dialled by the connect flow when nothing else
  /// connected (PsiphonSettings). Not a link: it has its own id and its
  /// own [pathKey], so it is never taken for a link whose server cannot
  /// be read, and the memory never holds it.
  static const psiphon = Server(
    id: psiphonId,
    name: psiphonName,
    country: '',
    city: '',
    connectionUri: 'psiphon://',
    flagEmoji: '🌐',
  );

  /// Whether this is [psiphon].
  bool get isPsiphon => id == psiphonId;

  /// Whether this server was provisioned for this device alone.
  ///
  /// Dedicated servers come from `/configs/dedicated` and carry credentials
  /// issued to this install only. Everything else on the list is a shared
  /// link, handed to every user who asks for it.
  final bool isDedicated;

  /// Which door this link goes through: "tcp-reality", "ws-tls" and so on,
  /// as the backend labels them. A server offers several doors and a
  /// censor blocks them separately, so the same server appears once per
  /// door in the list the diagnosis walks. Null for shared and community
  /// links, which carry no such label.
  final String? door;

  /// The backend's short name for the door, "Reality over XHTTP".
  final String? doorLabel;

  /// The server's own id on the backend, when it is one of ours.
  final int? serverId;

  /// Milliseconds the core's door group adds to this door's score, from
  /// the backend ([DedicatedPath.penaltyMs]). 0 for none, and for every
  /// link that is not one of our doors.
  final int penaltyMs;

  /// What the memory and the scoreboard key on: this server through this
  /// door. Two links to the same server through the same door are the same
  /// path even if the credential differs.
  ///
  /// The server is the one the link reaches ([VlessLink.endpoint]), not the
  /// address it dials. Two servers' Cloudflare doors are dialled at one
  /// Cloudflare address, and keyed by that address they were one path: the
  /// standby list kept whichever came first and dropped the other.
  ///
  /// A community link is keyed by its lid ([LinkId]) instead. Links from
  /// strangers to one address differ in everything that decides whether
  /// they work, and keyed by the address they were one path: the fallback
  /// kept the first and never tried the others. Every vmess link had the
  /// same key, because none had an address the app could read.
  String get pathKey => isPsiphon
      ? '$psiphonId|'
      : isCommunity
      ? 'lid:${LinkId.of(connectionUri)}|'
      : '${VlessLink.endpoint(connectionUri)}|${door ?? ''}';

  /// Whether this link and [other] reach the same server.
  ///
  /// The backend's server id decides when both links carry one. Without
  /// it, the same id or the same [VlessLink.endpoint] host does. The
  /// address a link dials is not enough: every Cloudflare door shares one.
  bool sameServerAs(Server other) {
    // The backup network has no server to compare: it is the same only as
    // itself.
    if (isPsiphon || other.isPsiphon) return isPsiphon && other.isPsiphon;
    if (serverId != null && other.serverId != null) {
      return serverId == other.serverId;
    }
    return id == other.id ||
        _hostOf(VlessLink.endpoint(connectionUri)) ==
            _hostOf(VlessLink.endpoint(other.connectionUri));
  }

  static String _hostOf(String hostPort) {
    if (hostPort.startsWith('[')) {
      final close = hostPort.indexOf(']');
      return close == -1 ? hostPort : hostPort.substring(1, close);
    }
    final colon = hostPort.lastIndexOf(':');
    return colon == -1 ? hostPort : hostPort.substring(0, colon);
  }

  const Server({
    required this.id,
    required this.name,
    required this.country,
    required this.city,
    required this.connectionUri,
    required this.flagEmoji,
    this.remark = '',
    this.latencyMs,
    this.load = ServerLoad.normal,
    this.isPremium = false,
    this.isDedicated = false,
    this.door,
    this.doorLabel,
    this.serverId,
    this.penaltyMs = 0,
  });

  Server copyWith({
    String? id,
    String? name,
    String? country,
    String? city,
    String? connectionUri,
    String? flagEmoji,
    String? remark,
    int? latencyMs,
    ServerLoad? load,
    bool? isPremium,
    bool? isDedicated,
    String? door,
    String? doorLabel,
    int? serverId,
    int? penaltyMs,
  }) {
    return Server(
      id: id ?? this.id,
      name: name ?? this.name,
      country: country ?? this.country,
      city: city ?? this.city,
      connectionUri: connectionUri ?? this.connectionUri,
      flagEmoji: flagEmoji ?? this.flagEmoji,
      remark: remark ?? this.remark,
      latencyMs: latencyMs ?? this.latencyMs,
      load: load ?? this.load,
      isPremium: isPremium ?? this.isPremium,
      isDedicated: isDedicated ?? this.isDedicated,
      door: door ?? this.door,
      doorLabel: doorLabel ?? this.doorLabel,
      serverId: serverId ?? this.serverId,
      penaltyMs: penaltyMs ?? this.penaltyMs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'country': country,
      'city': city,
      'connectionUri': connectionUri,
      'flagEmoji': flagEmoji,
      'remark': remark,
      'latencyMs': latencyMs,
      'load': load.name,
      'isPremium': isPremium,
      'isDedicated': isDedicated,
      'door': ?door,
      'doorLabel': ?doorLabel,
      'serverId': ?serverId,
      if (penaltyMs > 0) 'penaltyMs': penaltyMs,
    };
  }

  factory Server.fromJson(Map<String, dynamic> json) {
    return Server(
      id: json['id'] as String,
      name: json['name'] as String,
      country: json['country'] as String,
      city: json['city'] as String,
      connectionUri:
          json['connectionUri'] as String? ?? json['vlessLink'] as String,
      flagEmoji: json['flagEmoji'] as String,
      remark: json['remark'] as String? ?? '',
      latencyMs: json['latencyMs'] as int?,
      load: ServerLoad.values.firstWhere(
        (e) => e.name == json['load'],
        orElse: () => ServerLoad.normal,
      ),
      isPremium: json['isPremium'] as bool? ?? false,
      isDedicated: json['isDedicated'] as bool? ?? false,
      door: json['door'] as String?,
      doorLabel: json['doorLabel'] as String?,
      serverId: json['serverId'] as int?,
      penaltyMs: json['penaltyMs'] as int? ?? 0,
    );
  }

  /// Factory constructor for API response format
  /// Maps backend fields: uri -> connectionUri, country_code -> country
  factory Server.fromApiJson(Map<String, dynamic> json) {
    final countryCode = json['country_code'] as String? ?? '';
    final city = json['city'] as String? ?? '';
    final remark = json['remark'] as String? ?? '';
    final type = json['type'] as String? ?? 'free';

    // Use remark as display name if available, otherwise fall back to city/country
    final displayName = remark.isNotEmpty
        ? remark
        : (city.isNotEmpty ? city : countryName(countryCode));

    return Server(
      id: (json['id'] as int?)?.toString() ?? json['id'].toString(),
      name: displayName,
      country: countryName(countryCode),
      city: city,
      connectionUri: json['uri'] as String,
      flagEmoji: _getFlagEmoji(countryCode),
      remark: remark,
      latencyMs: null, // Will be measured by ping
      load: ServerLoad.normal,
      isPremium: type == 'premium',
    );
  }

  /// Factory constructor for parsing a raw connection URI string
  /// Used for community configs which return plain protocol links
  /// Format: vless://uuid@host:port?params#fragment, or the same for
  /// trojan and ss, or vmess://base64 (see [VlessLink.vmess])
  factory Server.fromConnectionUri(String connectionUri, {int index = 0}) {
    String displayName = 'Server ${index + 1}';
    String host = '';

    try {
      // Extract fragment (after #) as display name
      final fragmentIndex = connectionUri.indexOf('#');
      if (fragmentIndex != -1 && fragmentIndex < connectionUri.length - 1) {
        displayName = _decodeFragment(
          connectionUri.substring(fragmentIndex + 1),
        );
      } else {
        // A vmess link keeps its name inside, as `ps`.
        final ps = '${VlessLink.vmess(connectionUri)?['ps'] ?? ''}'.trim();
        if (ps.isNotEmpty) displayName = ps;
      }

      host = VlessLink.hostname(connectionUri);
    } catch (_) {
      // Fallback to defaults on parse error
    }

    // Use host as fallback name if no fragment
    if (displayName == 'Server ${index + 1}' && host.isNotEmpty) {
      displayName = host;
    }

    // Channels tag their links with a flag, and it is the only location
    // the link carries. Lifted out of the label so the tile can show it
    // where the flag goes and say the country in words, instead of a
    // globe next to "Unknown" beside a label that starts with a flag.
    final flagged = _splitLeadingFlag(displayName);
    final country = flagged.code == null ? '' : countryName(flagged.code!);

    return Server(
      id: '$communityIdPrefix$index',
      // The country is the one thing about a scraped link a user can act
      // on, so it is the name. The channel's own label ("161315 | Telegram
      // @foo") stays behind as the remark so search still finds it, but
      // is never the name: it says who posted the link, which is nobody's
      // business, and a host says nothing a user can act on. A link with
      // no flag is named by its number; the tiles say it in the phone's
      // language (serverTitle), this is the fallback for anything else.
      name: country.isNotEmpty ? country : communityFallbackName(index + 1),
      country: country,
      city: '',
      connectionUri: connectionUri,
      flagEmoji: flagged.flag ?? '🌍',
      remark: flagged.rest,
      latencyMs: null,
      load: ServerLoad.normal,
      isPremium: false,
    );
  }

  /// One of this device's own links through one named door.
  ///
  /// Same server as [fromDedicatedUri] would build from the primary link,
  /// with the door attached, so the id still names the server: the
  /// selection on the servers screen is per server, and the door is a
  /// detail of how the diagnosis reached it.
  factory Server.fromDedicatedPath({
    required String uri,
    required String door,
    required String doorLabel,
    int? serverId,
    int penaltyMs = 0,
    int index = 0,
  }) {
    return Server.fromDedicatedUri(uri, index: index).copyWith(
      door: door,
      doorLabel: doorLabel,
      serverId: serverId,
      penaltyMs: penaltyMs,
    );
  }

  /// Build a server from one of this device's own dedicated links.
  ///
  /// The identifier is derived from the endpoint rather than from the
  /// position in the list, because the backend omits any server it could
  /// not reach on that call and so the ordering shifts between refreshes.
  /// A positional id would quietly reattach the previous latency reading,
  /// and the persisted choice of server, to whatever slid into that slot.
  ///
  /// The endpoint is the server the link reaches, not the address it
  /// dials (see [VlessLink.endpoint]). Two servers whose first door is a
  /// Cloudflare door are dialled at one Cloudflare address, and by that
  /// address they had one id: choosing the second selected the first.
  factory Server.fromDedicatedUri(String uri, {int index = 0}) {
    final label = VlessLink.labelOrNull(uri);
    final endpoint = VlessLink.endpoint(uri);
    final parsed = label == null
        ? (region: '', place: '')
        : VlessLink.parts(label);

    final colon = endpoint.indexOf(':');
    final host = colon == -1 ? endpoint : endpoint.substring(0, colon);
    // The host beats a positional name: "fi.example.com" tells the user
    // something, a numbered "Server N" does not.
    final place = parsed.place.isNotEmpty
        ? parsed.place
        : (host.isNotEmpty ? host : 'Server ${index + 1}');

    return Server(
      id: 'dedicated-${endpoint.isNotEmpty ? endpoint : index}',
      name: place,
      country: parsed.region.isEmpty ? '' : countryName(parsed.region),
      city: parsed.place,
      connectionUri: uri,
      flagEmoji: parsed.region.isEmpty ? '🌍' : _getFlagEmoji(parsed.region),
      remark: label ?? '',
      isDedicated: true,
    );
  }

  /// The English name for an ISO country code, or the code itself when
  /// the table does not cover it.
  ///
  /// Public because the IP screen resolves the same codes, and duplicating
  /// the table would let the two drift.
  static String countryName(String countryCode) {
    const countryNames = {
      'US': 'United States',
      'GB': 'United Kingdom',
      'DE': 'Germany',
      'FR': 'France',
      'NL': 'Netherlands',
      'SE': 'Sweden',
      'SG': 'Singapore',
      'JP': 'Japan',
      'CA': 'Canada',
      'AU': 'Australia',
      'HK': 'Hong Kong',
      'KR': 'South Korea',
      'IN': 'India',
      'BR': 'Brazil',
      'CH': 'Switzerland',
      'IT': 'Italy',
      'ES': 'Spain',
      'RU': 'Russia',
      'TR': 'Turkey',
      'PL': 'Poland',
      // The fleet's own locations. Without these a dedicated server reads
      // as "Helsinki, FI" on the home screen, since an unmapped code is
      // returned verbatim.
      'FI': 'Finland',
      'NO': 'Norway',
      'DK': 'Denmark',
      'IE': 'Ireland',
      'IS': 'Iceland',
      'AT': 'Austria',
      'BE': 'Belgium',
      'CZ': 'Czechia',
      'HU': 'Hungary',
      'RO': 'Romania',
      'BG': 'Bulgaria',
      'GR': 'Greece',
      'PT': 'Portugal',
      'LU': 'Luxembourg',
      'EE': 'Estonia',
      'LV': 'Latvia',
      'LT': 'Lithuania',
      'UA': 'Ukraine',
      'AE': 'United Arab Emirates',
      'IL': 'Israel',
      'QA': 'Qatar',
      'KZ': 'Kazakhstan',
      'AM': 'Armenia',
      'GE': 'Georgia',
      'AZ': 'Azerbaijan',
      'TW': 'Taiwan',
      'TH': 'Thailand',
      'VN': 'Vietnam',
      'MY': 'Malaysia',
      'ID': 'Indonesia',
      'PH': 'Philippines',
      'NZ': 'New Zealand',
      'MX': 'Mexico',
      'AR': 'Argentina',
      'CL': 'Chile',
      'ZA': 'South Africa',
    };
    return countryNames[countryCode.toUpperCase()] ?? countryCode;
  }

  /// Percent-decode a link's fragment, keeping it verbatim when that fails.
  ///
  /// [Uri.decodeComponent] rejects any non-ASCII input outright, and
  /// channels paste flags and lightning bolts into fragments unencoded.
  /// Those links used to lose their name entirely and show up as a bare
  /// host, which is the one thing in the link the user cannot read.
  static String _decodeFragment(String fragment) {
    try {
      return Uri.decodeComponent(fragment);
    } on ArgumentError {
      return fragment;
    }
  }

  /// Two regional-indicator symbols at the start of a name, which is how
  /// a flag is spelled in Unicode.
  static final _leadingFlag = RegExp(
    r'^\s*([\u{1F1E6}-\u{1F1FF}]{2})[\s|:\-–—·]*',
    unicode: true,
  );

  /// Split a leading flag off a display name.
  ///
  /// Returns the flag, its ISO code and the rest of the name; the flag and
  /// code are null when the name does not start with one, and the name is
  /// then returned untouched.
  static ({String? flag, String? code, String rest}) _splitLeadingFlag(
    String name,
  ) {
    final match = _leadingFlag.firstMatch(name);
    if (match == null) return (flag: null, code: null, rest: name);
    final flag = match.group(1)!;
    final code = String.fromCharCodes([
      for (final rune in flag.runes) rune - 0x1F1E6 + 0x41,
    ]);
    final rest = name.substring(match.end).trim();
    // A name that was only a flag keeps it, or the tile would be blank.
    return (flag: flag, code: code, rest: rest.isEmpty ? name.trim() : rest);
  }

  /// Get flag emoji from ISO country code
  /// The flag for an ISO 3166 alpha-2 code, or a globe for anything else.
  static String flagFor(String countryCode) => _getFlagEmoji(countryCode);

  static String _getFlagEmoji(String countryCode) {
    if (countryCode.length != 2) return '🌍';

    final code = countryCode.toUpperCase();
    final firstLetter = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final secondLetter = code.codeUnitAt(1) - 0x41 + 0x1F1E6;

    return String.fromCharCodes([firstLetter, secondLetter]);
  }
}

enum ServerLoad { low, normal, high }

extension ServerLoadExtension on ServerLoad {
  String get displayName {
    switch (this) {
      case ServerLoad.low:
        return 'Low';
      case ServerLoad.normal:
        return 'Normal';
      case ServerLoad.high:
        return 'High';
    }
  }
}
