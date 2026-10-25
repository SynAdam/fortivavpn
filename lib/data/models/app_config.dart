import '../../api/api_routes.dart';
import '../../api/bootstrap.dart';
import '../../utils/carrier_name.dart';
import 'checklist_settings.dart';
import 'connection_data.dart';
import 'psiphon_settings.dart';
import 'stall_watch_settings.dart';
import 'version_info.dart';

/// Announcement model for in-app messages
class Announcement {
  final String id;
  final String title;
  final String message;
  final String type; // e.g., 'info', 'warning', 'promo'
  final bool dismissible;

  const Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.dismissible,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String? ?? 'info',
      dismissible: json['dismissible'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'dismissible': dismissible,
    };
  }
}

/// Feature flags for controlling app behavior
class FeatureFlags {
  final bool showPremiumUpsell;
  final bool enableServerPing;
  final bool enableKillSwitch;
  final bool enableSplitTunneling;

  /// Whether to show the invite screen and offer to accept a code.
  ///
  /// Defaults to false, unlike the flags above, so a build that cannot
  /// reach the config endpoint hides the feature rather than showing an
  /// entry point into endpoints the backend may not have yet.
  final bool enableReferrals;

  /// The share of the daily allowance used, in percent (1 to 100), after
  /// which the home data line offers invites, before the allowance runs
  /// out. Null, which shows no link, when the backend sends none: it sends
  /// one only while [enableReferrals] is on and its INVITE_NUDGE_PERCENT is
  /// set. The app holds no number of its own.
  final int? inviteNudgePercent;

  /// How to split the TLS hello on TLS links, for example
  /// `tlshello,10-20,10-20`, or empty for not at all. See TlsFragment.
  final String tlsFragment;

  /// Whether the core holds other doors next to the one it dials, and moves
  /// to them when that one fails. See StandbyDoors.
  final bool standbyDoors;

  /// Whether the app may ask for a Google Play rating. Off by default, so
  /// the team can stop the asks for every phone without a release. See
  /// ReviewPrompt.
  final bool reviewPrompt;

  /// Whether the limit sheet opens: what a tap on Connect shows once the
  /// daily data is used up, and what the home screen shows by itself once
  /// per refill. The sheet says when the data refills and lists the free
  /// ways to more data, so it is not an offer, and every phone gets it.
  /// Its Premium row needs the backend's offer gate on top
  /// (BillingState.upsellOn). On unless the config sends
  /// `limit_sheet: false`, so a config without the key, an older backend
  /// and a phone that could not load the config all get it. See
  /// showLimitSheet.
  final bool limitSheet;

  /// Whether the app watches a live tunnel for one that carries nothing,
  /// and looks for another door when it finds one. On unless the config
  /// sends `stall_watch: false`, like [limitSheet], so the team can stop it
  /// for every phone without a release. See StallWatch.
  final bool stallWatch;

  const FeatureFlags({
    this.showPremiumUpsell = true,
    this.enableServerPing = true,
    this.enableKillSwitch = true,
    this.enableSplitTunneling = false,
    this.enableReferrals = false,
    this.inviteNudgePercent,
    this.tlsFragment = '',
    this.standbyDoors = false,
    this.reviewPrompt = false,
    this.limitSheet = true,
    this.stallWatch = true,
  });

  factory FeatureFlags.fromJson(Map<String, dynamic> json) {
    return FeatureFlags(
      showPremiumUpsell: json['show_premium_upsell'] as bool? ?? true,
      enableServerPing: json['enable_server_ping'] as bool? ?? true,
      enableKillSwitch: json['enable_kill_switch'] as bool? ?? true,
      enableSplitTunneling: json['enable_split_tunneling'] as bool? ?? false,
      enableReferrals: json['enable_referrals'] as bool? ?? false,
      tlsFragment: json['tls_fragment'] as String? ?? '',
      standbyDoors: json['standby_doors'] as bool? ?? false,
      // Read without a cast, unlike the keys above: a value of the wrong
      // type in a strict cast throws away the whole config, update rules
      // included, and this flag is not worth that. The same goes for the
      // one after it, which only an explicit false turns off.
      reviewPrompt: json['review_prompt'] == true,
      limitSheet: json['limit_sheet'] != false,
      stallWatch: json['stall_watch'] != false,
      inviteNudgePercent: _percent(json['invite_nudge_percent']),
    );
  }

  /// [value] when it is a whole percent from 1 to 100, else null. Read
  /// without a cast, as review_prompt is: a value of the wrong type must
  /// not throw away the whole config.
  static int? _percent(Object? value) =>
      value is int && value >= 1 && value <= 100 ? value : null;

  Map<String, dynamic> toJson() {
    return {
      'show_premium_upsell': showPremiumUpsell,
      'enable_server_ping': enableServerPing,
      'enable_kill_switch': enableKillSwitch,
      'enable_split_tunneling': enableSplitTunneling,
      'enable_referrals': enableReferrals,
      'invite_nudge_percent': inviteNudgePercent,
      'tls_fragment': tlsFragment,
      'standby_doors': standbyDoors,
      'review_prompt': reviewPrompt,
      'limit_sheet': limitSheet,
      'stall_watch': stallWatch,
    };
  }
}

/// What the size probe measures and how often, from the app config's
/// `size_probe` block. See SizeProbeRunner.
///
/// Every number comes from the backend. A block that is missing, says
/// `enabled: false`, or lacks a number the probe needs reads as null, and
/// null is off: the app has no sizes, interval or wait of its own to fall
/// back on.
class SizeProbeSettings {
  const SizeProbeSettings({
    required this.downSizes,
    required this.upSizes,
    required this.minInterval,
    required this.timeout,
  });

  /// The sizes to download, in bytes, in order.
  final List<int> downSizes;

  /// The sizes to upload, in bytes, in order.
  final List<int> upSizes;

  /// The shortest time between two runs on one network.
  final Duration minInterval;

  /// How long one transfer gets.
  final Duration timeout;

  /// The settings in [json], or null when the probe is off. Read without a
  /// cast, so a bad value turns the probe off and never throws away the
  /// rest of the config. A size that is not a whole number above zero is
  /// skipped.
  static SizeProbeSettings? fromJson(Object? json) {
    if (json is! Map || json['enabled'] != true) return null;
    final minutes = json['min_interval_minutes'];
    final ms = json['timeout_ms'];
    if (minutes is! int || minutes <= 0 || ms is! int || ms <= 0) return null;
    final down = _sizes(json['down_sizes']);
    final up = _sizes(json['up_sizes']);
    if (down.isEmpty && up.isEmpty) return null;
    return SizeProbeSettings(
      downSizes: down,
      upSizes: up,
      minInterval: Duration(minutes: minutes),
      timeout: Duration(milliseconds: ms),
    );
  }

  static List<int> _sizes(Object? value) => value is List
      ? List.unmodifiable([
          for (final v in value)
            if (v is int && v > 0) v,
        ])
      : const [];

  Map<String, dynamic> toJson() => {
    'enabled': true,
    'down_sizes': downSizes,
    'up_sizes': upSizes,
    'min_interval_minutes': minInterval.inMinutes,
    'timeout_ms': timeout.inMilliseconds,
  };
}

/// Which phones the APN guide on the home screen is for, from the app
/// config's `apn_guide` block. See ApnGuide.
///
/// The guide asks people to change a setting of their phone, so it shows
/// only where the backend says. A block that is missing (any backend from
/// before the guide), says `enabled: false`, or names no brand or no
/// carrier reads as null, and null is off. Read without a cast, so a bad
/// value turns the guide off and never throws away the rest of the config.
class ApnGuideSettings {
  const ApnGuideSettings._({required this.brands, required this.carriers});

  /// The makers the guide is for, lower-cased, as Android's
  /// Build.MANUFACTURER is compared with them: "samsung".
  final Set<String> brands;

  /// The operators the guide is for, each in the spelling the backend
  /// files it under (CarrierName.normalise), lower-cased.
  final Set<String> carriers;

  /// The settings in [json], or null when the guide is off.
  static ApnGuideSettings? fromJson(Object? json) {
    if (json is! Map || json['enabled'] != true) return null;
    final brands = _names(json['brands'], _brand);
    final carriers = _names(json['carriers'], _operator);
    if (brands.isEmpty || carriers.isEmpty) return null;
    return ApnGuideSettings._(brands: brands, carriers: carriers);
  }

  /// Whether the guide is for phones [manufacturer] makes.
  bool coversBrand(String? manufacturer) {
    final brand = _brand(manufacturer);
    return brand != null && brands.contains(brand);
  }

  /// Whether the guide is for the operator [carrier] names, in any of the
  /// spellings CarrierName knows.
  bool coversCarrier(String? carrier) {
    final operator = _operator(carrier);
    return operator != null && carriers.contains(operator);
  }

  static String? _brand(String? name) {
    final brand = name?.trim().toLowerCase() ?? '';
    return brand.isEmpty ? null : brand;
  }

  static String? _operator(String? name) =>
      CarrierName.normalise(name)?.toLowerCase();

  /// The names in [value] that [clean] keeps, or none when it is not a
  /// list. A name that is not text is skipped.
  static Set<String> _names(Object? value, String? Function(String) clean) =>
      value is List
      ? Set.unmodifiable({
          for (final v in value)
            if (v is String) ?clean(v),
        })
      : const <String>{};

  Map<String, dynamic> toJson() => {
    'enabled': true,
    'brands': brands.toList(),
    'carriers': carriers.toList(),
  };
}

/// Force update configuration
class ForceUpdate {
  final PlatformVersion ios;
  final PlatformVersion android;

  /// Absent from a backend that does not know Windows yet, and then a
  /// Windows build is offered no update.
  final PlatformVersion? windows;

  const ForceUpdate({required this.ios, required this.android, this.windows});

  factory ForceUpdate.fromJson(Map<String, dynamic> json) {
    final windows = json['windows'];
    return ForceUpdate(
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

/// App configuration from backend
class AppConfig {
  final String privacyPolicyUrl;
  final String termsOfServiceUrl;
  final String eulaUrl;
  final String supportEmail;
  final String? supportUrl;
  final String? faqUrl;
  final ForceUpdate forceUpdate;
  final bool maintenanceMode;
  final String? maintenanceMessage;
  final List<Announcement> announcements;
  final FeatureFlags featureFlags;

  /// How the connect checklist runs, or null when the backend sent no
  /// `checklist` block. See [ChecklistSettings].
  final ChecklistSettings? checklist;

  /// The relays to try when a call to the backend cannot get through, or
  /// null when the backend did not say. See [ApiRelay].
  final List<ApiRelay>? apiRelays;

  /// More places the fallback file is published (Bootstrap), or null when
  /// the backend did not say.
  final List<String>? bootstrapMirrors;

  /// How many days copies of a deleted account stay in backups and
  /// anonymous server logs. The delete-account confirmation names it. Null
  /// when the backend did not say, and then the confirmation names no
  /// number, so the promise is set by the backend alone.
  final int? deletedDataRetentionDays;

  /// What the size probe measures, or null when it is off. See
  /// [SizeProbeSettings].
  final SizeProbeSettings? sizeProbe;

  /// Whether the app records what each connect tap did and sends it to
  /// POST /devices/{id}/connect-traces (ConnectTraces), from the
  /// `connect_trace` block's `enabled`. A missing block is off.
  final bool connectTrace;

  /// Which phones the APN guide is for, or null when it is off. See
  /// [ApnGuideSettings].
  final ApnGuideSettings? apnGuide;

  /// What the backend asks the phone to measure about its connections. All
  /// off when the block is missing. See [ConnectionData].
  final ConnectionData connectionData;

  /// The backup network, or null when it is off. See [PsiphonSettings].
  final PsiphonSettings? psiphon;

  /// How the stall watch decides. The built-in numbers when the block is
  /// missing. See [StallWatchSettings].
  final StallWatchSettings stallWatch;

  const AppConfig({
    required this.privacyPolicyUrl,
    required this.termsOfServiceUrl,
    required this.eulaUrl,
    required this.supportEmail,
    this.supportUrl,
    this.faqUrl,
    required this.forceUpdate,
    this.maintenanceMode = false,
    this.maintenanceMessage,
    this.announcements = const [],
    this.featureFlags = const FeatureFlags(),
    this.checklist,
    this.apiRelays,
    this.bootstrapMirrors,
    this.deletedDataRetentionDays,
    this.sizeProbe,
    this.connectTrace = false,
    this.apnGuide,
    this.connectionData = ConnectionData.off,
    this.psiphon,
    this.stallWatch = StallWatchSettings.builtIn,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      privacyPolicyUrl: json['privacy_policy_url'] as String,
      termsOfServiceUrl: json['terms_of_service_url'] as String,
      eulaUrl: json['eula_url'] as String,
      supportEmail: json['support_email'] as String,
      supportUrl: json['support_url'] as String?,
      faqUrl: json['faq_url'] as String?,
      forceUpdate: ForceUpdate.fromJson(
        json['force_update'] as Map<String, dynamic>,
      ),
      maintenanceMode: json['maintenance_mode'] as bool? ?? false,
      maintenanceMessage: json['maintenance_message'] as String?,
      announcements:
          (json['announcements'] as List<dynamic>?)
              ?.map((e) => Announcement.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      featureFlags: json['feature_flags'] != null
          ? FeatureFlags.fromJson(json['feature_flags'] as Map<String, dynamic>)
          : const FeatureFlags(),
      checklist: ChecklistSettings.fromJson(json['checklist']),
      apiRelays: ApiRelays.parse(json['api_relays']),
      bootstrapMirrors: json['bootstrap_mirrors'] is List
          ? Bootstrap.httpsOnly(json['bootstrap_mirrors'])
          : null,
      deletedDataRetentionDays: _positiveInt(
        json['deleted_data_retention_days'],
      ),
      sizeProbe: SizeProbeSettings.fromJson(json['size_probe']),
      connectTrace: connectTraceOn(json['connect_trace']),
      apnGuide: ApnGuideSettings.fromJson(json['apn_guide']),
      connectionData: ConnectionData.fromJson(json['connection_data']),
      psiphon: PsiphonSettings.fromJson(json['psiphon']),
      stallWatch: StallWatchSettings.fromJson(json['stall_watch']),
    );
  }

  /// Whether the `connect_trace` block [json] turns the trace on. Read
  /// without a cast, like the other optional blocks: anything but a block
  /// that says `enabled: true` is off, and never throws away the rest of
  /// the config.
  static bool connectTraceOn(Object? json) =>
      json is Map && json['enabled'] == true;

  /// Read without a cast, like feature_flags.review_prompt: a value of the
  /// wrong type must not throw away the whole config. Anything that is not
  /// a whole number above zero reads as null.
  static int? _positiveInt(Object? value) =>
      value is int && value > 0 ? value : null;

  Map<String, dynamic> toJson() {
    return {
      'privacy_policy_url': privacyPolicyUrl,
      'terms_of_service_url': termsOfServiceUrl,
      'eula_url': eulaUrl,
      'support_email': supportEmail,
      'support_url': supportUrl,
      'faq_url': faqUrl,
      'force_update': forceUpdate.toJson(),
      'maintenance_mode': maintenanceMode,
      'maintenance_message': maintenanceMessage,
      'announcements': announcements.map((a) => a.toJson()).toList(),
      'feature_flags': featureFlags.toJson(),
      if (checklist case final checklist?) 'checklist': checklist.toJson(),
      if (apiRelays != null)
        'api_relays': [for (final r in apiRelays!) r.toJson()],
      if (bootstrapMirrors != null) 'bootstrap_mirrors': bootstrapMirrors,
      if (deletedDataRetentionDays != null)
        'deleted_data_retention_days': deletedDataRetentionDays,
      if (sizeProbe case final sizeProbe?) 'size_probe': sizeProbe.toJson(),
      if (connectTrace) 'connect_trace': {'enabled': true},
      if (apnGuide case final apnGuide?) 'apn_guide': apnGuide.toJson(),
      if (psiphon case final psiphon?) 'psiphon': psiphon.toJson(),
      'stall_watch': stallWatch.toJson(),
    };
  }
}
