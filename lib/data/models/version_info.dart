/// Platform-specific version information
class PlatformVersion {
  final String latestVersion;
  final String minimumVersion;
  final bool updateRequired;
  final String updateUrl;
  final String? releaseNotes;

  /// `channel_url`, or null when the backend sent none, or something that is
  /// not a link to a page on t.me ([isChannelUrl]).
  ///
  /// Older builds on phones update from it and open it for their other links,
  /// so the backend keeps its value. It is one channel for every language, so
  /// this build opens it only for [contactChannel], and for a Persian reader
  /// when the backend sends no [channelUrls].
  final String? channelUrl;

  /// The page every copy of the app opens for every link to the channel,
  /// or null when the backend sent none (`play_channel_url`), and then the
  /// channel of the app's language is opened ([channelFor]).
  ///
  /// Google Play does not let a Play app link to a page that could lead to
  /// another way to pay. Every copy of the app runs the same code as the
  /// one on Google Play, so every copy follows this. It lets the backend
  /// move the app's links to a page that sells nothing, without a release
  /// and without touching the channels, which every channel APK needs for
  /// its updates ([updateChannelFor]). Only a value that passes
  /// [isChannelUrl] is kept.
  final String? playChannelUrl;

  /// `channel_urls`: the channel of each app language that has one, by its
  /// two-letter code. A language with no channel of its own is absent. A value
  /// that fails [isChannelUrl] is dropped.
  final Map<String, String> channelUrls;

  /// The English channel: the channel of every language that has none of its
  /// own, when the backend does not name it in [channelUrls].
  static const defaultChannelUrl = 'https://t.me/fortivavpn';

  /// The channel [contactChannel] opens when the backend names none. Only
  /// this channel's direct messages reach the support bot. It posts in
  /// Persian, so nothing but a way to message us may open it.
  static const supportChannelUrl = 'https://t.me/fortiva_vpn';

  /// Whether [url] may be opened as the channel: an https link to a page
  /// on t.me, with nothing before the host.
  ///
  /// A value that fails this check is never opened. Never throws. A path with
  /// a percent escape that is not UTF-8, such as https://t.me/%D8, makes
  /// Uri.pathSegments throw, and here it only fails the check, because this
  /// runs while the app config is parsed and one throw there loses the whole
  /// config.
  static bool isChannelUrl(String url) {
    try {
      final uri = Uri.tryParse(url.trim());
      return uri != null &&
          uri.scheme == 'https' &&
          uri.host == 't.me' &&
          uri.userInfo.isEmpty &&
          uri.pathSegments.any((s) => s.isNotEmpty);
    } catch (_) {
      return false;
    }
  }

  /// [value] trimmed when it is a channel link ([isChannelUrl]), else
  /// null. Never throws, whatever the type.
  static String? _channelLink(Object? value) =>
      value is String && isChannelUrl(value) ? value.trim() : null;

  /// The channel links in [value], keeping only those that pass
  /// [isChannelUrl]. Never throws, whatever the type.
  static Map<String, String> _channelLinks(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final MapEntry(:key, value: url) in value.entries)
        if (key is String) key: ?_channelLink(url),
    };
  }

  /// The channel of [language], whatever [playChannelUrl] says.
  ///
  /// A language with no channel of its own gets the English one. A backend, or
  /// rules saved by an older build, may have no [channelUrls] at all. Then a
  /// Persian reader keeps [channelUrl], which has always been the Persian
  /// channel, and every other reader gets the English channel.
  String _languageChannel(String language) {
    final sent = channelUrl;
    if (language == 'fa' && channelUrls.isEmpty && sent != null) return sent;
    return channelUrls[language] ?? channelUrls['en'] ?? defaultChannelUrl;
  }

  /// The channel a link opens for a person whose app is in [language], a
  /// two-letter code: [playChannelUrl] when the backend sent one, and the
  /// channel of that language otherwise.
  String channelFor(String language) =>
      playChannelUrl ?? _languageChannel(language);

  /// The channel the update prompt's Telegram button opens for a person whose
  /// app is in [language].
  ///
  /// A copy Google signed opens [channelFor], as a link to the channel does.
  /// Any other copy, such as the channel APK, opens the channel of the language
  /// even when the backend sent [playChannelUrl], because only a release posted
  /// there can update it in place: Play cannot, and a page that sells nothing
  /// does not post one.
  String updateChannelFor({
    required bool googleSigned,
    required String language,
  }) => googleSigned ? channelFor(language) : _languageChannel(language);

  /// The channel a person messages to reach us: [playChannelUrl] when the
  /// backend sent one, then [channelUrl], then [supportChannelUrl]. It does not
  /// depend on the language, because only that channel's direct messages reach
  /// the support bot.
  String get contactChannel =>
      playChannelUrl ?? channelUrl ?? supportChannelUrl;

  /// The @name of the channel [url] opens, such as @fortiva_vpn for
  /// https://t.me/fortiva_vpn or one of its posts, or null when the link
  /// names none, such as an invite link. Never throws.
  static String? channelHandle(Uri url) {
    final List<String> segments;
    try {
      segments = url.pathSegments;
    } catch (_) {
      return null;
    }
    final name = segments.isEmpty ? '' : segments.first;
    final post = segments.length == 2 && int.tryParse(segments[1]) != null;
    if ((segments.length != 1 && !post) || !_handle.hasMatch(name)) {
      return null;
    }
    return '@$name';
  }

  /// A Telegram public name: a letter, then letters, digits and _.
  static final _handle = RegExp(r'^[A-Za-z][A-Za-z0-9_]{3,31}$');

  const PlatformVersion({
    required this.latestVersion,
    required this.minimumVersion,
    required this.updateRequired,
    required this.updateUrl,
    this.releaseNotes,
    this.channelUrl,
    this.playChannelUrl,
    this.channelUrls = const {},
  });

  factory PlatformVersion.fromJson(Map<String, dynamic> json) {
    final notes = json['release_notes'];
    return PlatformVersion(
      latestVersion: json['latest_version'] as String,
      minimumVersion: json['minimum_version'] as String,
      // The optional fields are read leniently, unlike the ones above. A
      // throw here fails the whole config, update rules and feature flags
      // included, and none of these is worth that.
      updateRequired: json['update_required'] == true,
      updateUrl: json['update_url'] as String,
      releaseNotes: notes is String ? notes : null,
      channelUrl: _channelLink(json['channel_url']),
      playChannelUrl: _channelLink(json['play_channel_url']),
      channelUrls: _channelLinks(json['channel_urls']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latest_version': latestVersion,
      'minimum_version': minimumVersion,
      'update_required': updateRequired,
      'update_url': updateUrl,
      'release_notes': releaseNotes,
      if (channelUrl != null) 'channel_url': channelUrl,
      if (playChannelUrl != null) 'play_channel_url': playChannelUrl,
      if (channelUrls.isNotEmpty) 'channel_urls': channelUrls,
    };
  }
}

/// Version info for both platforms
class VersionInfo {
  final PlatformVersion ios;
  final PlatformVersion android;

  /// Absent from a backend that does not know Windows yet, and then a
  /// Windows build is offered no update.
  final PlatformVersion? windows;

  const VersionInfo({required this.ios, required this.android, this.windows});

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    final windows = json['windows'];
    return VersionInfo(
      ios: PlatformVersion.fromJson(json['ios'] as Map<String, dynamic>),
      android: PlatformVersion.fromJson(
        json['android'] as Map<String, dynamic>,
      ),
      windows: windows is Map<String, dynamic>
          ? PlatformVersion.fromJson(windows)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ios': ios.toJson(),
      'android': android.toJson(),
      if (windows case final windows?) 'windows': windows.toJson(),
    };
  }
}
