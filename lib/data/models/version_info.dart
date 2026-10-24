/// Platform-specific version information
class PlatformVersion {
  final String latestVersion;
  final String minimumVersion;
  final bool updateRequired;
  final String updateUrl;
  final String? releaseNotes;

  /// The Telegram channel where the Android APK is posted.
  ///
  /// The second way to update on Android, next to [updateUrl]. The channel
  /// APK and the Play copy are signed with different keys, so Play cannot
  /// update a user who installed the APK, and many users in Iran cannot
  /// reach Play at all. Always set: a backend that does not send
  /// `channel_url`, or sends something that is not a link to a page on
  /// t.me ([isChannelUrl]), gets [defaultChannelUrl].
  ///
  /// This is the update link of every channel APK, so the backend must keep
  /// it on a page that posts the current channel APK. The channel APKs of
  /// builds up to 1.6.17 open it for every link to the channel. Newer builds
  /// open it only for the update of a copy Google did not sign
  /// ([updateChannelFor]), and [playChannelUrl] for every other link when
  /// the backend sends one ([channelLink]).
  final String channelUrl;

  /// The page every copy of the app opens for every link to the channel,
  /// or null when the backend sent none (`play_channel_url`), and then
  /// [channelUrl] is opened.
  ///
  /// Google Play does not let a Play app link to a page that could lead to
  /// another way to pay. Every copy of the app runs the same code as the
  /// one on Google Play, so every copy follows this. It lets the backend
  /// move the app's links to a page that sells nothing, without a release
  /// and without touching [channelUrl], which every channel APK needs for
  /// its updates. Only a value that passes [isChannelUrl] is kept.
  final String? playChannelUrl;

  /// The official channel, for backends that predate `channel_url`.
  static const defaultChannelUrl = 'https://t.me/fortiva_vpn';

  /// Whether [url] may be opened as the channel: an https link to a page
  /// on t.me, with nothing before the host.
  ///
  /// A value that fails this check is never opened: the official channel
  /// is opened instead. Never throws. A path with a percent escape that is
  /// not UTF-8, such as https://t.me/%D8, makes Uri.pathSegments throw, and
  /// here it only fails the check, because this runs while the app config
  /// is parsed and one throw there loses the whole config.
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

  /// [value] when it is a channel link ([isChannelUrl]), else
  /// [defaultChannelUrl]. Never throws, whatever the type.
  static String channelUrlFrom(Object? value) =>
      _channelLink(value) ?? defaultChannelUrl;

  /// [value] trimmed when it is a channel link ([isChannelUrl]), else
  /// null. Never throws, whatever the type.
  static String? _channelLink(Object? value) =>
      value is String && isChannelUrl(value) ? value.trim() : null;

  /// The channel the app opens: [playChannelUrl] when the backend sent one,
  /// and [channelUrl] otherwise. The same in every copy.
  String get channelLink => playChannelUrl ?? channelUrl;

  /// The channel the update prompt's Telegram button opens.
  ///
  /// A copy Google signed opens [channelLink], as every other link does.
  /// Any other copy, such as the channel APK, opens [channelUrl], because
  /// only the APK posted there can update it in place: Play cannot, and an
  /// APK from a page that does not post it cannot either.
  String updateChannelFor({required bool googleSigned}) =>
      googleSigned ? channelLink : channelUrl;

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
    this.channelUrl = defaultChannelUrl,
    this.playChannelUrl,
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
      channelUrl: channelUrlFrom(json['channel_url']),
      playChannelUrl: _channelLink(json['play_channel_url']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latest_version': latestVersion,
      'minimum_version': minimumVersion,
      'update_required': updateRequired,
      'update_url': updateUrl,
      'release_notes': releaseNotes,
      'channel_url': channelUrl,
      if (playChannelUrl != null) 'play_channel_url': playChannelUrl,
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
