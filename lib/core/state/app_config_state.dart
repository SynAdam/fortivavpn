import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_routes.dart';
import '../../api/app_config_service.dart';
import '../../api/bootstrap.dart';
import '../../data/models/app_config.dart';
import '../../data/models/checklist_settings.dart';
import '../../data/models/connection_data.dart';
import '../../data/models/psiphon_settings.dart';
import '../../data/models/stall_watch_settings.dart';
import '../../data/models/version_info.dart';
import '../../services/connect_trace.dart';
import '../../services/psiphon_entries.dart';
import '../../services/stall_watch.dart';
import '../../services/tunnel_channels.dart';
import '../../utils/standby_doors.dart';
import '../../utils/tls_fragment.dart';

/// Remote configuration, read for its feature flags and version rules.
///
/// Loaded at launch, and again when the app comes back to the foreground
/// with a stale copy, and never blocked on: when the fetch fails the app
/// keeps the defaults, which hide anything the backend has not confirmed
/// it supports.
///
/// The version rules are the exception. They are kept on the phone after
/// every fetch that lands, so a launch whose fetch fails still knows which
/// builds the backend no longer supports. Without that, a phone that could
/// not reach us was never told to update, which is often exactly the phone
/// running a build too old to reach us.
class AppConfigState extends ChangeNotifier {
  AppConfigState({
    Future<AppConfig> Function()? fetch,
    Future<String?> Function()? fallbackFile,
    Bootstrap? bootstrap,
    this.retryGaps = const [Duration(seconds: 5), Duration(seconds: 20)],
    DateTime Function()? now,
    PsiphonEntries? psiphonEntries,
  }) : _fetch = fetch ?? AppConfigService().getAppConfig,
       _fallbackFile = fallbackFile ?? AppConfigService().getFallbackFile,
       _bootstrap = bootstrap ?? Bootstrap.instance,
       _now = now ?? DateTime.now,
       _psiphonEntries = psiphonEntries ?? PsiphonEntries.instance;

  /// Where the backend's last TLS hello spec is kept between launches.
  static const tlsFragmentKey = 'remote_tls_fragment';

  /// Where the backend's last version rules (the `force_update` block) are
  /// kept between launches, as JSON.
  static const versionRulesKey = 'remote_version_rules';

  /// Where the backend's last checklist settings (the `checklist` block)
  /// are kept between launches, as JSON. Missing when the last config that
  /// landed had no such block.
  static const checklistKey = 'remote_checklist';

  /// Set while the backend's last config turned the connect trace on (the
  /// `connect_trace` block). Missing when the last config that landed had
  /// it off or had no such block.
  static const connectTraceKey = 'remote_connect_trace';

  /// Set while the backend's last config turned standby doors on (the
  /// `standby_doors` feature flag). Missing when the last config that
  /// landed had it off or had no feature flags.
  static const standbyDoorsKey = 'remote_standby_doors';

  /// Set while the last config said `stall_watch: false`, so the next
  /// launch keeps the watch off before a new config arrives.
  static const stallWatchOffKey = 'remote_stall_watch_off';

  /// Where the backend's last APN guide settings (the `apn_guide` block)
  /// are kept between launches, as JSON. Missing when the last config that
  /// landed had the guide off or had no such block.
  static const apnGuideKey = 'remote_apn_guide';

  /// Where the backend's last connection data settings (the
  /// `connection_data` block) are kept between launches, as JSON. Missing
  /// when the last config that landed had none of them on.
  static const connectionDataKey = 'remote_connection_data';

  /// The last config's stall_watch block, so a launch that cannot fetch
  /// the config watches the way the backend last asked for.
  static const stallWatchSettingsKey = 'remote_stall_watch_settings';

  /// Where the backend's last backup network settings (the `psiphon`
  /// block) are kept between launches, as JSON. Missing when the last
  /// config that landed had the block off or had none.
  static const psiphonKey = 'remote_psiphon';

  final Future<AppConfig> Function() _fetch;
  final Future<String?> Function() _fallbackFile;
  final Bootstrap _bootstrap;
  final DateTime Function() _now;

  /// Keeps the backup network's server list in line with the settings in
  /// force. Told after the saved settings are restored and after every
  /// fetch that lands, and never waited for.
  final PsiphonEntries _psiphonEntries;

  /// How long to wait before each further try after a failed fetch.
  ///
  /// The first request of a launch is the one most likely to fail: the
  /// network is still coming up, or a tunnel from the last session is on
  /// its way down. One try meant a launch that lost that request ran on
  /// defaults until the app was closed.
  final List<Duration> retryGaps;

  AppConfig? _config;
  ForceUpdate? _savedRules;
  ApnGuideSettings? _apnGuide;
  DateTime? _loadedAt;
  Future<void>? _inFlight;
  bool _isLoading = false;

  AppConfig? get config => _config;
  bool get isLoading => _isLoading;

  /// When a fetch last landed in this run of the app, or null when none has.
  DateTime? get loadedAt => _loadedAt;

  /// The version rules to check the running build against: the ones from
  /// the last fetch that landed, in this run of the app or an earlier one.
  /// Null only when the backend has never answered on this phone.
  ForceUpdate? get versionRules => _config?.forceUpdate ?? _savedRules;

  /// Flags for the running build. Defaults until the fetch lands, which
  /// is why every flag that gates a new feature defaults to false.
  FeatureFlags get flags => _config?.featureFlags ?? const FeatureFlags();

  bool get referralsEnabled => flags.enableReferrals;

  /// Whether the config says invites run under the tree rule. False while
  /// invites are off, before a config has landed in this run of the app,
  /// and when the backend did not say which rule it runs.
  bool get inviteTreeOn => referralsEnabled && flags.referralRules == 'tree';

  /// The share of the daily allowance used, in percent, after which the
  /// home data line offers invites, or null for no link: while invites are
  /// off, before a config has landed in this run of the app, and when the
  /// backend sent no number. See FeatureFlags.inviteNudgePercent.
  int? get inviteNudgePercent =>
      referralsEnabled ? flags.inviteNudgePercent : null;

  /// The Telegram channel the app's links open: Contact us in Settings
  /// while the chat is off, and the chat's own fallback. Kept between
  /// launches with the version rules. The update prompt picks its own
  /// (PlatformVersion.updateChannelFor).
  ///
  /// Every copy of the app opens `force_update.android.play_channel_url`
  /// when the backend sends one, and `channel_url` otherwise
  /// (PlatformVersion.channelLink). Google Play does not let a Play app
  /// link to a page that could lead to another way to pay, and every copy
  /// runs the same code as the one on Google Play, so the backend can move
  /// the app's links to a page that sells nothing, without a release. A
  /// link compiled into the app could only change with a release.
  /// `channel_url` stays the update link of every channel APK.
  ///
  /// Either one is used only when it is an https link to a page on t.me,
  /// and the official channel is opened otherwise.
  Uri get channelUrl {
    final url = PlatformVersion.channelUrlFrom(
      versionRules?.android.channelLink,
    );
    return Uri.tryParse(url) ?? Uri.parse(PlatformVersion.defaultChannelUrl);
  }

  /// How many days copies of a deleted account stay in backups and
  /// anonymous server logs, or null when the backend has not said in this
  /// run of the app. Not kept between launches: without a fresh answer the
  /// delete-account confirmation names no number.
  int? get deletedDataRetentionDays => _config?.deletedDataRetentionDays;

  /// What the size probe measures, or null when it is off or no config has
  /// landed in this run of the app. Not kept between launches: a phone that
  /// cannot fetch the config runs no probe. See SizeProbeRunner.
  SizeProbeSettings? get sizeProbe => _config?.sizeProbe;

  /// Which phones the APN guide is for, from the last config that landed,
  /// in this run of the app or an earlier one. Null, which is off, on a
  /// phone the backend has never answered and after a config that had the
  /// guide off. See ApnGuide.
  ApnGuideSettings? get apnGuide => _apnGuide;

  /// Fetch the config, with retries. A call made while a fetch is already
  /// running waits for that one rather than starting another, so a caller
  /// that awaits this always sees the outcome of a fetch.
  Future<void> load() {
    final running = _inFlight;
    if (running != null) return running;
    _isLoading = true;
    notifyListeners();
    return _inFlight = _load().whenComplete(() {
      _inFlight = null;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> _load() async {
    // Before the fetch, so a dial made while it is in flight, or after it
    // has failed, splits the hello the way the backend last asked for and
    // holds the standby doors it last turned on, and an update check made
    // after a failed fetch has rules to go on.
    await _restoreTlsFragment();
    await _restoreChecklist();
    await _restoreConnectTrace();
    await _restoreStandbyDoors();
    await _restoreStallWatch();
    await _restoreApnGuide();
    await _restoreConnectionData();
    await _restoreStallWatchSettings();
    await _restorePsiphon();
    // In the background: a download must never hold up a tap. Usually
    // there is nothing to do, because the list for the saved sha is on the
    // phone already.
    unawaited(_psiphonEntries.sync(PsiphonSettings.current));
    await restoreSaved();

    try {
      _config = await _fetchWithRetries();
      _loadedAt = _now();
      // Replaces what was saved, including when the backend lowered the
      // minimum: the newest answer is the one that counts.
      await _keepVersionRules(_config!.forceUpdate);
      // Read by the connection and the probes, which live outside the
      // widget tree.
      TlsFragment.spec = flags.tlsFragment;
      StandbyDoors.enabled = flags.standbyDoors;
      StallWatch.enabled = flags.stallWatch;
      await _keepTlsFragment(flags.tlsFragment);
      await _keepStandbyDoors(flags.standbyDoors);
      await _keepStallWatch(flags.stallWatch);
      // A config with no block turns the settings off here and on the
      // next launch: the newest answer is the one that counts.
      ChecklistSettings.current = _config!.checklist;
      await _keepChecklist(_config!.checklist);
      ConnectTraces.enabled = _config!.connectTrace;
      await _keepConnectTrace(_config!.connectTrace);
      _apnGuide = _config!.apnGuide;
      await _keepApnGuide(_apnGuide);
      ConnectionData.current = _config!.connectionData;
      await _keepConnectionData(_config!.connectionData);
      StallWatchSettings.current = _config!.stallWatch;
      await _keepStallWatchSettings(_config!.stallWatch);
      unawaited(askForTimedChecks(_config!.connectionData));
      PsiphonSettings.current = _config!.psiphon;
      await _keepPsiphon(_config!.psiphon);
      unawaited(_psiphonEntries.sync(_config!.psiphon));
      final relays = _config?.apiRelays;
      if (relays != null) await ApiRelays.adopt(relays);
      final mirrors = _config?.bootstrapMirrors;
      if (mirrors != null) await _bootstrap.adoptMirrors(mirrors);
      // The backend answers, so this is the time to get a fresh fallback
      // file, before a cut that would leave only the hosts to read it from.
      unawaited(_bootstrap.refreshFromBackend(_fallbackFile));
    } catch (e) {
      // Remote config is an enhancement, not a dependency. A device that
      // cannot reach it still connects.
      debugPrint('AppConfigState: could not load remote config ($e)');
    }
  }

  Future<AppConfig> _fetchWithRetries() async {
    for (final gap in retryGaps) {
      try {
        return await _fetch();
      } catch (e) {
        debugPrint('AppConfigState: fetch failed, trying again ($e)');
        await Future.delayed(gap);
      }
    }
    return _fetch();
  }

  /// Put the spec the backend gave on an earlier launch back in force.
  ///
  /// Nothing saved means the backend has never answered on this phone, and
  /// the built-in spec stays. A saved empty string is the backend having
  /// turned the split off, and is kept as off.
  Future<void> _restoreTlsFragment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(tlsFragmentKey);
      if (saved != null) TlsFragment.spec = saved;
    } catch (e) {
      debugPrint('AppConfigState: could not read the saved spec ($e)');
    }
  }

  Future<void> _keepTlsFragment(String spec) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(tlsFragmentKey, spec);
    } catch (e) {
      debugPrint('AppConfigState: could not save the spec ($e)');
    }
  }

  /// Put the connection data settings an earlier launch saved back in
  /// force, so a check made before the fetch lands, or on a launch whose
  /// fetch failed, measures what the backend last asked for. Nothing saved,
  /// or a copy that cannot be read, leaves everything off.
  Future<void> _restoreConnectionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(connectionDataKey);
      if (saved == null) return;
      ConnectionData.current = ConnectionData.fromJson(jsonDecode(saved));
      unawaited(askForTimedChecks(ConnectionData.current));
    } catch (e) {
      debugPrint('AppConfigState: could not read the connection data ($e)');
    }
  }

  /// Ask Android to turn the timed door check on in this run when
  /// [settings] want it. Android reads the saved settings once, as the app
  /// starts, so a run that started without them, as a fresh install's first
  /// run does, checked doors without timings until the next start
  /// (DoorChecks.prepareLater). A run that has the timed check already, or
  /// a platform without it, does nothing.
  @visibleForTesting
  static Future<void> askForTimedChecks(ConnectionData settings) async {
    if (!settings.timedChecks ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await TunnelChannels.method.invokeMethod<void>('prepareTimedChecks');
    } catch (e) {
      debugPrint('AppConfigState: the timed check was not asked for ($e)');
    }
  }

  Future<void> _keepConnectionData(ConnectionData settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (settings == ConnectionData.off) {
        await prefs.remove(connectionDataKey);
      } else {
        await prefs.setString(connectionDataKey, jsonEncode(settings.toJson()));
      }
    } catch (e) {
      debugPrint('AppConfigState: could not save the connection data ($e)');
    }
  }

  Future<void> _restoreStallWatchSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(stallWatchSettingsKey);
      if (saved == null) return;
      StallWatchSettings.current = StallWatchSettings.fromJson(
        jsonDecode(saved),
      );
    } catch (e) {
      debugPrint(
        'AppConfigState: could not read the stall watch settings ($e)',
      );
    }
  }

  Future<void> _keepStallWatchSettings(StallWatchSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        stallWatchSettingsKey,
        jsonEncode(settings.toJson()),
      );
    } catch (e) {
      debugPrint(
        'AppConfigState: could not save the stall watch settings ($e)',
      );
    }
  }

  /// Put the backup network settings an earlier launch saved back in
  /// force.
  ///
  /// Kept because the backup network is for the tap that reaches nothing
  /// else, and on such a line the fetch fails too. Nothing saved, or a
  /// copy that cannot be read, leaves the network off.
  Future<void> _restorePsiphon() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(psiphonKey);
      if (saved == null) return;
      PsiphonSettings.current = PsiphonSettings.fromJson(jsonDecode(saved));
    } catch (e) {
      debugPrint('AppConfigState: could not read the backup network ($e)');
    }
  }

  Future<void> _keepPsiphon(PsiphonSettings? settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (settings == null) {
        await prefs.remove(psiphonKey);
      } else {
        await prefs.setString(psiphonKey, jsonEncode(settings.toJson()));
      }
    } catch (e) {
      debugPrint('AppConfigState: could not save the backup network ($e)');
    }
  }

  /// Put the checklist settings an earlier launch saved back in force.
  ///
  /// Kept for the same reason as the TLS spec: a phone whose every route
  /// to us is blocked is the one whose checklist most needs them, and the
  /// one whose fetch fails. A copy that cannot be read leaves the settings
  /// as they are. Nothing saved means the backend has never answered on
  /// this phone, and the built-in settings apply
  /// ([ChecklistSettings.builtIn]) until it does.
  Future<void> _restoreChecklist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(checklistKey);
      if (saved == null) {
        ChecklistSettings.current ??= ChecklistSettings.builtIn;
        return;
      }
      ChecklistSettings.current = ChecklistSettings.fromJson(jsonDecode(saved));
    } catch (e) {
      debugPrint('AppConfigState: could not read the checklist ($e)');
    }
  }

  Future<void> _keepChecklist(ChecklistSettings? settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (settings == null) {
        // Kept as an empty block rather than removed: nothing saved is a
        // phone the backend has never answered (_restoreChecklist).
        await prefs.setString(checklistKey, '{}');
      } else {
        await prefs.setString(checklistKey, jsonEncode(settings.toJson()));
      }
    } catch (e) {
      debugPrint('AppConfigState: could not save the checklist ($e)');
    }
  }

  /// Put the connect trace back on when an earlier launch's config turned
  /// it on.
  ///
  /// Kept for the reason the checklist settings are: the taps whose trace
  /// we most need are on a line that blocks our calls, and there the fetch
  /// fails too. Nothing saved leaves the trace as it is, which is off on a
  /// phone the backend has never answered.
  Future<void> _restoreConnectTrace() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(connectTraceKey) == true) ConnectTraces.enabled = true;
    } catch (e) {
      debugPrint('AppConfigState: could not read the connect trace ($e)');
    }
  }

  Future<void> _keepConnectTrace(bool on) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (on) {
        await prefs.setBool(connectTraceKey, true);
      } else {
        await prefs.remove(connectTraceKey);
      }
    } catch (e) {
      debugPrint('AppConfigState: could not save the connect trace ($e)');
    }
  }

  /// Put standby doors back on when an earlier launch's config turned
  /// them on.
  ///
  /// Kept for the reason the TLS spec is. The flag is read when a tap
  /// dials (StandbyDoors.pick), and until this run's fetch landed it was
  /// off, so a tap made before then, or on a launch whose fetch failed,
  /// dialled its door with no other door next to it for the core to move
  /// to. Nothing saved leaves them off, as on a phone the backend has
  /// never answered.
  Future<void> _restoreStandbyDoors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(standbyDoorsKey) == true) StandbyDoors.enabled = true;
    } catch (e) {
      debugPrint('AppConfigState: could not read standby doors ($e)');
    }
  }

  /// Put a saved "off" for the stall watch back in force. Nothing saved
  /// leaves it on, as on a phone the backend has never answered.
  Future<void> _restoreStallWatch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(stallWatchOffKey) == true) StallWatch.enabled = false;
    } catch (e) {
      debugPrint('AppConfigState: could not read the stall watch ($e)');
    }
  }

  Future<void> _keepStallWatch(bool on) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (on) {
        await prefs.remove(stallWatchOffKey);
      } else {
        await prefs.setBool(stallWatchOffKey, true);
      }
    } catch (e) {
      debugPrint('AppConfigState: could not save the stall watch ($e)');
    }
  }

  Future<void> _keepStandbyDoors(bool on) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (on) {
        await prefs.setBool(standbyDoorsKey, true);
      } else {
        await prefs.remove(standbyDoorsKey);
      }
    } catch (e) {
      debugPrint('AppConfigState: could not save standby doors ($e)');
    }
  }

  /// Put the APN guide settings an earlier launch saved back in force.
  ///
  /// Kept for the reason the checklist settings are: the guide is for
  /// phones on Hamrah Aval and Irancell, the lines whose blocks also stop
  /// the fetch. The home screen is told at once, rather than when a fetch
  /// that has every route blocked fails, which takes over a minute.
  /// Nothing saved, or a copy that cannot be read, leaves the guide off.
  Future<void> _restoreApnGuide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(apnGuideKey);
      if (saved == null) return;
      _apnGuide = ApnGuideSettings.fromJson(jsonDecode(saved));
      if (_apnGuide != null) notifyListeners();
    } catch (e) {
      debugPrint('AppConfigState: could not read the APN guide ($e)');
    }
  }

  Future<void> _keepApnGuide(ApnGuideSettings? settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (settings == null) {
        await prefs.remove(apnGuideKey);
      } else {
        await prefs.setString(apnGuideKey, jsonEncode(settings.toJson()));
      }
    } catch (e) {
      debugPrint('AppConfigState: could not save the APN guide ($e)');
    }
  }

  /// Put the version rules an earlier fetch saved into [versionRules],
  /// without fetching. Reads the phone's storage only once per run of the
  /// app, and every later call waits for that one read.
  ///
  /// [load] does this before it fetches. The update check also calls it on
  /// its own, so it can run on the saved rules at once rather than after a
  /// fetch that, when every route to us is blocked, takes over a minute to
  /// fail through its retries.
  Future<void> restoreSaved() => _restoring ??= _restoreVersionRules();

  Future<void>? _restoring;

  /// Read the version rules an earlier fetch saved. Only once per run of
  /// the app, because after that a fetch that landed has replaced them.
  Future<void> _restoreVersionRules() async {
    if (_savedRules != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(versionRulesKey);
      if (raw == null) return;
      _savedRules = ForceUpdate.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      // A saved copy that cannot be read is no rules at all, the same as
      // a phone the backend has never answered.
      debugPrint('AppConfigState: could not read the saved rules ($e)');
    }
  }

  Future<void> _keepVersionRules(ForceUpdate rules) async {
    _savedRules = rules;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(versionRulesKey, jsonEncode(rules.toJson()));
    } catch (e) {
      debugPrint('AppConfigState: could not save the rules ($e)');
    }
  }
}
