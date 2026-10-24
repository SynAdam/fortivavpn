import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../core/design_system.dart';
import '../core/form_factor.dart';
import '../core/state/connect_flow.dart';
import '../core/state/dedicated_state.dart';
import '../core/state/dial_server.dart';
import '../core/state/server_state.dart';
import '../core/update_check.dart';
import '../data/models/app_config.dart';
import '../data/models/version_info.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/play_signature.dart';
import '../services/vpn_service.dart';
import 'message_dialog.dart';
import 'outside_link.dart';
import 'quota_card.dart';

/// Tells a user their build is out of date, and how out of date.
///
/// Two dialogs, because the two cases are not the same conversation. A build
/// below the minimum we support gets one with no way out: there is no Later
/// button, the back gesture does not close it, and tapping outside does
/// nothing, because carrying on is not something we can make work. A build
/// that is merely behind the store gets an offer, and Later puts it off
/// until the next time the app is opened (see [UpdateOpens]).
///
/// On Android both dialogs offer two places to update from: Google Play and
/// the Telegram channel where the APK is posted. Play cannot update a user
/// who installed that APK, because the two are signed differently, and many
/// users in Iran cannot reach Play at all. With only a Play button, the
/// dialog with no way out would leave those users with no way to update.
///
/// The first of the two is the one that updates this copy in place: Google
/// Play in the copy Google signed, the channel in the channel APK. Moving
/// between the copies means uninstalling, because they are signed
/// differently, and Android gives each signing key its own ANDROID_ID. So the
/// phone comes back as a new device, without its Premium, its referral and
/// promo bonus or its place in the day's allowance, and the dashboard counts
/// it twice. Every copy used to put Google Play first, and in the 30 days to
/// 2026-10-09 about 12 phones moved this way.
///
/// Every copy runs the same code, so which copy this is comes from the app's
/// own signing certificate, read at run time ([PlaySignature]). A check that
/// fails reads as "not Google's" and lists the channel first. The channel
/// APK is then right whether its check works or fails, and a Play copy whose
/// check failed still has Google Play as the second button.
///
/// The dialog with no way out also has a Connect button, first while the
/// tunnel is down. In Iran Telegram, and often Google Play, open only
/// through a VPN, so a user told to update while disconnected could
/// otherwise neither connect nor reach the update. Connect runs the home
/// screen's own connect path. Once connected the dialog offers Reconnect
/// and Disconnect instead. Those are the only things here that take a
/// tunnel down, and only when tapped.
///
/// Disconnect is there because this dialog covers the home screen and its
/// button. A tunnel that says it is connected and carries nothing, because
/// the server went down or the daily data ran out, holds all of the phone's
/// traffic, and Reconnect dials through the same path again. Without
/// Disconnect the only way out was to start another VPN app, which took
/// ours down as a side effect (issue #195).
///
/// While the tunnel is connected the dialog also checks, every half minute
/// and on every return to the app, that it still carries anything. When it
/// does not, the dialog says so instead of "You are connected", and reads
/// the allowance again, since a spent allowance is the usual reason.
///
/// Only one of these dialogs is ever on screen. The check runs on every
/// open and every return to the foreground, and a user who went to
/// Telegram to download the update comes back to the dialog they left,
/// not to a second copy stacked on it.
class UpdateDialog {
  /// Where builds up to 1.6.10 kept the newest version the user said Later
  /// to, and when. Later no longer outlives the visit, so these are only
  /// removed; see [forgetOldLater].
  static const dismissedPrefKey = 'pref_update_dismissed_version';
  static const dismissedAtPrefKey = 'pref_update_dismissed_at';

  /// The opens of this run of the app, which Later is counted against.
  static UpdateOpens opens = UpdateOpens();

  /// How often the forced dialog checks that a connected tunnel still
  /// carries anything, while the app is in front.
  static const liveCheckEvery = Duration(seconds: 30);

  /// How long the forced dialog waits before it checks a second time, so
  /// one lost request does not call a working tunnel dead.
  static const liveRetryGap = Duration(seconds: 3);

  /// How much data has to come down the tunnel between two failed checks
  /// for it to count as working anyway. A tunnel busy with the update
  /// download can be too slow to answer a check in time, and moves far
  /// more than this; a dead one, or one over its allowance, moves nothing.
  static const movingBytes = 16 * 1024;

  static _Shown? _shown;

  /// Whether a dialog has been shown in this run. One popup per run: the
  /// rating card does not follow an update offer.
  static bool get shownThisRun => _shownThisRun;
  static bool _shownThisRun = false;
  static bool _checking = false;

  /// Remove what the 24 hour Later of older builds left behind. Nothing
  /// reads it any more, and a user upgrading should not carry a hold that
  /// no longer means anything.
  static Future<void> forgetOldLater() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(dismissedPrefKey);
      await prefs.remove(dismissedAtPrefKey);
    } catch (e) {
      debugPrint('UpdateDialog: could not clear the old Later ($e)');
    }
  }

  /// Check the running build against [rules] and prompt if needed.
  ///
  /// Returns once the dialog is on screen, or once it is clear that none is
  /// needed, not when the user closes it. Never throws: a prompt that cannot
  /// be shown must not take the launch with it.
  ///
  /// When a dialog is already up this leaves it alone, unless the answer
  /// has changed: an offer is replaced by the dialog with no way out when
  /// the minimum has passed this build, and the dialog with no way out is
  /// taken down when the backend has lowered the minimum again.
  static Future<void> maybeShow(
    BuildContext context,
    ForceUpdate? rules, {
    String? currentVersion,
    bool? android,
    bool? windows,
    bool? googleSigned,
    Future<void> Function(Uri url)? open,
  }) async {
    if (rules == null || _checking) return;
    _checking = true;
    try {
      // Passed in by tests, which run on none of these platforms. Windows
      // reads its own numbers; anything else that is not iOS reads the
      // Android ones, as it always has.
      final isWindows = windows ?? (android == null && Platform.isWindows);
      final isAndroid = !isWindows && (android ?? !Platform.isIOS);
      final platform = isWindows
          ? rules.windows
          : isAndroid
          ? rules.android
          : rules.ios;
      // A backend that does not know Windows yet has nothing to offer it.
      if (platform == null) return;

      // Passed in by tests. In the app it comes from the running build,
      // which is a platform call and so has no answer inside a widget test.
      final current = currentVersion ?? await _runningVersion();
      final need = UpdateCheck.decide(
        current: current,
        latest: platform.latestVersion,
        minimum: platform.minimumVersion,
        serverSaysRequired: platform.updateRequired,
      );

      final shown = _shown != null && _shown!.route.isActive ? _shown : null;
      if (shown == null) _shown = null;
      switch (need) {
        case UpdateNeed.none:
          if (shown != null && shown.forced) _takeDown(shown);
          return;
        case UpdateNeed.optional:
          if (shown != null && !shown.forced) return;
          if (shown != null) _takeDown(shown);
          if (opens.optionalHeld) return;
        case UpdateNeed.required:
          if (shown != null && shown.forced) return;
          if (shown != null) _takeDown(shown);
      }

      // Passed in by tests, which run on no Android phone. Only the Android
      // buttons follow it, so nothing else asks.
      final signed =
          googleSigned ?? (isAndroid && await PlaySignature.shared.read());
      if (!context.mounted) return;
      _show(
        context,
        platform,
        need,
        android: isAndroid,
        googleSigned: signed,
        // Passed in by tests, where there is no platform to open a link.
        open: open ?? _openOutside,
      );
    } catch (e) {
      debugPrint('UpdateDialog: could not check for an update: $e');
    } finally {
      _checking = false;
    }
  }

  /// The version of the build the user is running, or null when the platform
  /// will not say. Null means no prompt, which is the safe way to fail.
  static Future<String?> _runningVersion() async {
    if (ApiConfig.appVersion == null) await ApiConfig.readAppBuild();
    return ApiConfig.appVersion;
  }

  /// Open [url] in the app that handles it: the Play Store, Telegram, or a
  /// browser when Telegram is not installed. On a TV, a QR code for a phone
  /// when the TV cannot open it.
  static Future<void> _openOutside(Uri url) async {
    try {
      await openOutside(url);
    } catch (e) {
      debugPrint('UpdateDialog: could not open $url: $e');
    }
  }

  /// Remove a dialog that no longer says the right thing. Not the user's
  /// answer to it, so an offer taken down this way is not counted as one.
  static void _takeDown(_Shown shown) {
    _shown = null;
    shown.route.navigator?.removeRoute(shown.route, _Closed.replaced);
  }

  static void _show(
    BuildContext context,
    PlatformVersion platform,
    UpdateNeed need, {
    required bool android,
    required bool googleSigned,
    required Future<void> Function(Uri url) open,
  }) {
    final forced = need == UpdateNeed.required;
    // A message popup gives way: telling a user their build is out of date
    // matters more, and two dialogs stacked on each other read as a bug.
    // The message goes back to the inbox unread.
    MessageDialog.closeForUpdate();
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<_Closed>(
      context: context,
      barrierDismissible: !forced,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      builder: (context) => Theme(
        data: _compactButtons(context),
        child: _UpdateDialogBody(
          platform: platform,
          forced: forced,
          android: android,
          googleSigned: googleSigned,
          open: open,
        ),
      ),
    );
    final shown = _Shown(route, forced: forced);
    _shown = shown;
    _shownThisRun = true;
    unawaited(
      navigator.push(route).then((closed) {
        if (identical(_shown, shown)) _shown = null;
        // Later, an update button, a tap outside or the back gesture. All
        // of them are an answer for this open.
        if (!forced && closed != _Closed.replaced) opens.optionalAnswered();
      }),
    );
  }

  /// Whether an update dialog is on screen. A message waits while it is.
  static bool get isShowing => _shown?.route.isActive ?? false;

  /// Forget every dialog and open, for tests that pump a new app each time.
  @visibleForTesting
  static void resetForTest() {
    _shown = null;
    _shownThisRun = false;
    _checking = false;
    opens = UpdateOpens();
  }

  /// Whether a dialog is on screen and whether it is the forced one, or
  /// null when none is. For tests.
  @visibleForTesting
  static bool? get showingForced {
    final shown = _shown;
    if (shown == null || !shown.route.isActive) return null;
    return shown.forced;
  }
}

/// How a dialog was closed, when it was not the user closing it.
enum _Closed { answered, replaced }

class _Shown {
  _Shown(this.route, {required this.forced});

  final Route<_Closed> route;
  final bool forced;
}

class _UpdateDialogBody extends StatefulWidget {
  const _UpdateDialogBody({
    required this.platform,
    required this.forced,
    required this.android,
    required this.googleSigned,
    required this.open,
  });

  final PlatformVersion platform;
  final bool forced;
  final bool android;

  /// Whether Google signed this copy, so Google Play updates it and comes
  /// first. Any other copy, such as the channel APK, lists the channel first.
  final bool googleSigned;
  final Future<void> Function(Uri url) open;

  @override
  State<_UpdateDialogBody> createState() => _UpdateDialogBodyState();
}

/// Holds the forced dialog's connecting state. It lives here, above both
/// the line in the text and the button below it, because Reconnect sits in
/// the line and Connect in the buttons, and a reconnect that starts in one
/// finishes in the other once the tunnel is down.
class _UpdateDialogBodyState extends State<_UpdateDialogBody> {
  /// Waiting for this device's servers or allowance before dialling, the
  /// same wait the home screen shows as connecting, or for a tunnel to come
  /// down before Reconnect dials again.
  bool _waiting = false;

  void _setWaiting(bool waiting) {
    if (mounted) setState(() => _waiting = waiting);
  }

  /// The tunnel, which the forced dialog watches for the live check. Null
  /// on the offer, which can be shown where no tunnel is provided.
  VpnService? _vpn;
  AppLifecycleListener? _lifecycle;
  Timer? _liveTimer;

  /// Whether the tunnel was connected at the last change, so only a change
  /// of that starts or stops the live check.
  bool _wasConnected = false;

  /// Whether the tunnel was seen dialling, connecting or under the
  /// service's own check, since it was last not connected.
  bool _dialled = false;

  /// Counts the tunnel's connected spells. A check that started in one and
  /// finishes in another is about a tunnel that is gone, so it is dropped.
  int _spell = 0;

  /// The spell a check is running for, so a second one for the same spell
  /// does not start. A check still running for an older spell does not
  /// hold up the new one.
  int? _checkingSpell;

  /// Set when the tunnel says it is connected and the live check found
  /// nothing getting through. Cleared by a check that passes, and whenever
  /// the tunnel stops being connected.
  bool _notCarrying = false;

  /// Whether the allowance has been read since the tunnel was found dead.
  /// A read that failed leaves this unset, so the next dead check asks
  /// again.
  bool _allowanceRead = false;
  bool _readingAllowance = false;

  @override
  void initState() {
    super.initState();
    if (!widget.forced) return;
    final vpn = context.read<VpnService>();
    _vpn = vpn;
    vpn.addListener(_onTunnel);
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_checkLive()));
    _onTunnel();
  }

  @override
  void dispose() {
    _vpn?.removeListener(_onTunnel);
    _lifecycle?.dispose();
    _liveTimer?.cancel();
    super.dispose();
  }

  /// Start the live check when the tunnel becomes connected, and stop it
  /// and forget its answers when the tunnel stops being connected. No
  /// setState: the dialog watches the tunnel, so the change that called
  /// this rebuilds it anyway.
  ///
  /// A tunnel seen coming up has just passed the service's own check, so
  /// the first live check waits its turn. One that turns up connected
  /// without that, because it was up before the dialog opened or was found
  /// up after a restart of the app, has passed no check in this run, and
  /// is checked at once.
  void _onTunnel() {
    final vpn = _vpn!;
    if (vpn.status == VpnStatus.connecting || vpn.isVerifying) {
      _dialled = true;
    }
    final connected = _connectedOf(vpn);
    if (connected == _wasConnected) return;
    _wasConnected = connected;
    _spell++;
    _notCarrying = false;
    _allowanceRead = false;
    _liveTimer?.cancel();
    _liveTimer = null;
    final dialled = _dialled;
    _dialled = false;
    if (!connected) return;
    _liveTimer = Timer.periodic(
      UpdateDialog.liveCheckEvery,
      (_) => unawaited(_checkLive()),
    );
    if (!dialled) unawaited(_checkLive());
  }

  /// Whether the app is in front. A null state is a test, or a start too
  /// early to say, and counts as in front.
  static bool get _inFront {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  /// Check that a tunnel that says it is connected still carries anything,
  /// and say so on the dialog when it does not.
  ///
  /// The service checks once, right after connecting. Without this the
  /// dialog went on saying "You are connected. Download the update now."
  /// over a tunnel that had died since (issue #195). Nothing is taken down
  /// for a failed check: a working tunnel taken down is worse than a dead
  /// one left up, so the user decides, with Reconnect and Disconnect right
  /// there. See [_carries] for what counts as dead.
  ///
  /// Runs only while the app is in front, when someone can read the
  /// answer, and at once on a return to the app, which is when a user who
  /// found that Google Play or Telegram would not load looks again.
  Future<void> _checkLive() async {
    final vpn = _vpn;
    if (vpn == null || _waiting || !_inFront) return;
    if (!_connectedOf(vpn) || _checkingSpell == _spell) return;
    final spell = _spell;
    bool sameSpell() => mounted && spell == _spell;
    _checkingSpell = spell;
    bool? carrying;
    try {
      carrying = await _carries(vpn, sameSpell);
    } catch (e) {
      debugPrint('UpdateDialog: could not check the tunnel ($e)');
    } finally {
      if (_checkingSpell == spell) _checkingSpell = null;
    }
    if (carrying == null || !sameSpell()) return;
    if (carrying) {
      _allowanceRead = false;
      if (_notCarrying) setState(() => _notCarrying = false);
      return;
    }
    if (!_notCarrying) setState(() => _notCarrying = true);
    if (!_allowanceRead) await _readAllowance(spell);
  }

  /// Whether the tunnel carries anything: a check that passes, or, when
  /// two checks a few seconds apart both fail, data that came down the
  /// tunnel between them. A tunnel busy with the update download can be
  /// too slow to answer a check in time and still be working, and telling
  /// that user to reconnect or disconnect would break their download.
  /// Null when the tunnel changed while this ran, so the answer is about a
  /// tunnel that is gone.
  Future<bool?> _carries(VpnService vpn, bool Function() sameSpell) async {
    if (await vpn.checkTraffic()) return true;
    if (!sameSpell()) return null;
    // The counters reset on every read, so this one starts the count that
    // the read after the second check finishes.
    await vpn.tunnelBytesDown();
    await Future<void>.delayed(UpdateDialog.liveRetryGap);
    if (!sameSpell()) return null;
    if (await vpn.checkTraffic()) return true;
    final down = await vpn.tunnelBytesDown();
    if (!sameSpell()) return null;
    return down != null && down >= UpdateDialog.movingBytes;
  }

  /// Read the allowance again, after the tunnel was found dead.
  ///
  /// A device over its daily allowance has its servers turned off, so its
  /// tunnel stops carrying anything and still says it is connected. When
  /// the allowance is spent, refreshAllowance takes the tunnel down and the
  /// dialog says the data is used up and when it refills. Read once per
  /// dead spell when it works, and again on the next dead check when it
  /// did not. It does not hold up the checks, which go on while it runs.
  Future<void> _readAllowance(int spell) async {
    final vpn = _vpn;
    if (vpn == null || _readingAllowance) return;
    final dedicated = context.read<DedicatedState>();
    _readingAllowance = true;
    try {
      await refreshAllowance(vpn: vpn, dedicated: dedicated);
      if (mounted && spell == _spell && dedicated.errorMessage == null) {
        _allowanceRead = true;
      }
    } catch (e) {
      debugPrint('UpdateDialog: could not read the allowance ($e)');
    } finally {
      _readingAllowance = false;
    }
  }

  /// What Connect does. A tap while connecting does nothing, because the
  /// button is not on screen then.
  Future<void> _connect() async {
    final vpn = context.read<VpnService>();
    final flow = context.read<ConnectFlow>();
    final dedicated = context.read<DedicatedState>();
    final servers = context.read<ServerState>();

    var server = activeServer(dedicated, servers);
    if (server == null) {
      // Nothing to dial: the allowance is spent, or no server has loaded
      // yet. connectFromButton then asks for both again and returns at
      // once, which the home screen explains with its status line and
      // server card. Here those are behind the dialog and the button
      // looked dead, so the same asks are awaited with the button shown
      // as busy, and what they bring is dialled, because the user asked
      // to connect.
      _setWaiting(true);
      try {
        await refreshAllowance(vpn: vpn, dedicated: dedicated);
        if (!dedicated.isBlocked && servers.selectedServer == null) {
          await servers.loadServers();
        }
      } catch (e) {
        debugPrint('UpdateDialog: could not load servers to connect ($e)');
      } finally {
        _setWaiting(false);
      }
      if (!mounted) return;
      server = activeServer(dedicated, servers);
      // Still spent: [_ConnectLine] says so and when it refills.
      if (server == null) return;
    }
    await connectFromButton(
      server,
      vpn: vpn,
      flow: flow,
      dedicated: dedicated,
      servers: servers,
      onWaitingForOwn: _setWaiting,
      stillWanted: () => mounted,
    );
  }

  /// What Reconnect does: take the tunnel down and run Connect again.
  Future<void> _reconnect() async {
    final vpn = context.read<VpnService>();
    _setWaiting(true);
    try {
      await vpn.disconnect();
      await _downSettled(vpn);
    } catch (e) {
      debugPrint('UpdateDialog: could not take the tunnel down ($e)');
    } finally {
      _setWaiting(false);
    }
    if (!mounted) return;
    await _connect();
  }

  /// What Disconnect does: stop a connect in flight and take the tunnel
  /// down, as a tap on the home screen's button does while it is up. The
  /// dialog stays, and Connect comes back in place of the line that says
  /// the user is connected.
  Future<void> _disconnect() => stopConnecting(
    vpn: context.read<VpnService>(),
    flow: context.read<ConnectFlow>(),
  );

  /// Wait until the tunnel has finished coming down, so the next dial does
  /// not start while the old one is still being torn down. The service
  /// forces the status after 4 seconds when the platform does not report
  /// it, so the wait here is only a backstop.
  static Future<void> _downSettled(VpnService vpn) async {
    if (vpn.status != VpnStatus.disconnecting) return;
    final down = Completer<void>();
    void listener() {
      if (vpn.status != VpnStatus.disconnecting && !down.isCompleted) {
        down.complete();
      }
    }

    vpn.addListener(listener);
    try {
      await down.future.timeout(const Duration(seconds: 6), onTimeout: () {});
    } finally {
      vpn.removeListener(listener);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final platform = widget.platform;
    final forced = widget.forced;

    // The dialog stays up on a forced update: the store opens in another
    // app and the user comes back to this same screen until they have
    // actually updated.
    void openFrom(String url) {
      widget.open(Uri.parse(url));
      if (!forced) Navigator.of(context).pop(_Closed.answered);
    }

    void later() => Navigator.of(context).pop(_Closed.answered);

    // Only the forced dialog reads the tunnel, so the offer can be shown
    // where the connect state is not provided.
    final connected = forced && _isConnected(context);
    final body = forced
        ? s.updateRequiredBody
        : s.updateBody(platform.latestVersion);
    final connect = _ConnectFirst(waiting: _waiting, onConnect: _connect);
    // The way that updates this copy in place comes first and filled; the
    // other copy second (see [UpdateDialog]).
    void fromPlay() => openFrom(platform.updateUrl);
    void fromChannel() =>
        openFrom(platform.updateChannelFor(googleSigned: widget.googleSigned));
    const playIcon = Icon(Icons.shop_outlined);
    const channelIcon = Icon(Icons.send_rounded);
    final updates = widget.googleSigned
        ? [
            FilledButton.icon(
              onPressed: fromPlay,
              icon: playIcon,
              label: Text(s.updateFromPlay),
            ),
            const SizedBox(height: AppDesign.space8),
            FilledButton.tonalIcon(
              onPressed: fromChannel,
              style: _tonal,
              icon: channelIcon,
              label: Text(s.updateFromTelegram),
            ),
          ]
        : [
            FilledButton.icon(
              onPressed: fromChannel,
              icon: channelIcon,
              label: Text(s.updateFromTelegram),
            ),
            const SizedBox(height: AppDesign.space8),
            FilledButton.tonalIcon(
              onPressed: fromPlay,
              style: _tonal,
              icon: playIcon,
              label: Text(s.updateFromPlay),
            ),
          ];
    // Once connected, Disconnect takes the row Connect leaves, below the
    // update buttons because downloading is what a connected user is
    // here for. It sits with the buttons, which do not scroll, so it is on
    // screen on any phone and at any text size. Not while connecting: the
    // progress line holds that row then, a fourth row does not fit a small
    // phone at large text, and a connect ends on its own with Connect
    // back.
    final disconnect = TextButton.icon(
      onPressed: _disconnect,
      style: _quiet,
      icon: const Icon(Icons.power_settings_new_rounded),
      label: Text(s.updateDisconnect),
    );

    return PopScope(
      canPop: !forced,
      child: AlertDialog(
        // The title and text scroll when the dialog is taller than the
        // screen, as it is on a small phone with large text, so the
        // buttons below them always stay on screen.
        scrollable: true,
        title: Text(forced ? s.updateRequiredTitle : s.updateTitle),
        // The line about the tunnel, and Reconnect with it, sit with the
        // text, which scrolls, rather than with the buttons, which do not,
        // so neither ever pushes a button off a small screen.
        content: forced
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(body),
                  const SizedBox(height: 12),
                  _ConnectLine(
                    connected: connected,
                    carrying: !_notCarrying,
                    busy: _waiting,
                    onReconnect: _reconnect,
                  ),
                ],
              )
            : Text(body),
        actions: widget.android
            ? [
                // One full-width button per row. Three buttons with
                // labels like these do not fit side by side on a narrow
                // phone in every language, and a column lays out the
                // same way in RTL.
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (forced && !connected) ...[
                      connect,
                      const SizedBox(height: AppDesign.space8),
                    ],
                    ...updates,
                    if (!forced) ...[
                      const SizedBox(height: AppDesign.space4),
                      TextButton(
                        onPressed: later,
                        style: _quiet,
                        child: Text(s.updateLater),
                      ),
                    ],
                    if (connected) ...[
                      const SizedBox(height: AppDesign.space4),
                      disconnect,
                    ],
                  ],
                ),
              ]
            : [
                if (forced && !connected)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: connect,
                  ),
                if (!forced)
                  TextButton(
                    onPressed: later,
                    style: _quiet,
                    child: Text(s.updateLater),
                  ),
                if (connected) disconnect,
                FilledButton(
                  onPressed: () => openFrom(platform.updateUrl),
                  child: Text(s.updateNow),
                ),
              ],
      ),
    );
  }
}

/// The second way to update, and Connect: a raised tone with light text,
/// so the one brand button, the way that updates this copy in place, is
/// the clear first choice. The app theme gives every FilledButton the
/// brand fill, the tonal ones included, so these say so here.
final ButtonStyle _tonal = FilledButton.styleFrom(
  backgroundColor: AppDesign.surfaceBright,
  foregroundColor: AppDesign.textPrimary,
  iconColor: AppDesign.textPrimary,
);

/// Later and Disconnect: text in a quiet tone, not the brand's.
final ButtonStyle _quiet = TextButton.styleFrom(
  foregroundColor: AppDesign.textSecondary,
  iconColor: AppDesign.textSecondary,
);

/// The app theme with lower buttons, for the update dialogs.
///
/// The forced dialog stacks up to four buttons in one column, and they must
/// all fit a 320 by 568 phone at the largest text size (update_dialog_test).
/// The theme's 52dp buttons with a fixed 14dp of padding above and below
/// the label pushed the last one off that screen. Here the buttons are 44dp
/// high, and their padding shrinks as the text grows, the way Material's
/// own button padding does. The tap target stays 48dp, because Material
/// pads a smaller button's hit area to that.
ThemeData _compactButtons(BuildContext context) {
  final theme = Theme.of(context);
  final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
  final compact = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(64, 44)),
    padding: WidgetStatePropertyAll(
      ButtonStyleButton.scaledPadding(
        const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        const EdgeInsets.symmetric(horizontal: 8),
        textScale,
      ),
    ),
  );
  return theme.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: compact.merge(theme.filledButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: compact.merge(theme.textButtonTheme.style),
    ),
  );
}

/// Whether the tunnel is up and has passed its check, rebuilding the
/// caller when that changes.
bool _isConnected(BuildContext context) =>
    _connectedOf(context.watch<VpnService>());

/// Whether [vpn] is up and has passed its check.
bool _connectedOf(VpnService vpn) =>
    vpn.status == VpnStatus.connected && !vpn.isVerifying;

/// The line on the forced update dialog that says where the tunnel stands.
///
/// Over the allowance: the daily data is used up and when it refills,
/// because Connect cannot dial anything until then, and the home screen
/// that would say so is behind this dialog. With the tunnel still up over
/// a spent allowance it carries nothing, so the line sends the user to
/// Disconnect rather than offering Reconnect, which would dial nothing.
/// Connected: the user can download the update now, with Reconnect under
/// it. Connected, but the live check found nothing getting through: says
/// so, and points at Reconnect and Disconnect. Otherwise: tap Connect
/// first if Play or Telegram does not open.
///
/// Reconnect is there because a tunnel can say it is connected and carry
/// nothing: on 2026-10-04 and 10-05 doors on two Iranian carriers stopped
/// passing traffic while the status stayed connected. On the home screen
/// the user would disconnect and connect again or pick another server, but
/// this dialog covers that screen, so without Reconnect a user in that
/// state had no way online from inside the app.
class _ConnectLine extends StatelessWidget {
  const _ConnectLine({
    required this.connected,
    required this.carrying,
    required this.busy,
    required this.onReconnect,
  });

  final bool connected;

  /// The size of the icon at the start of the line.
  static const double _lineIcon = 20;

  /// False when the live check found nothing getting through.
  final bool carrying;
  final bool busy;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final dedicated = context.watch<DedicatedState>();
    if (dedicated.isBlocked) {
      final quota = dedicated.quota;
      final refill = quota == null ? '' : QuotaCard.resetLabel(s, quota);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.data_usage_rounded,
            color: AppDesign.error,
            size: _lineIcon,
          ),
          const SizedBox(width: AppDesign.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.quotaUsedUp,
                  style: const TextStyle(
                    color: AppDesign.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(refill.isEmpty ? s.myServersBlockedWait : refill),
                if (connected) ...[
                  const SizedBox(height: AppDesign.space4),
                  Text(s.updateDisconnectHint),
                ],
              ],
            ),
          ),
        ],
      );
    }
    if (connected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              carrying
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: AppDesign.protected,
                      size: _lineIcon,
                    )
                  : const Icon(
                      Icons.error_outline_rounded,
                      color: AppDesign.warning,
                      size: _lineIcon,
                    ),
              const SizedBox(width: AppDesign.space8),
              Expanded(
                child: Text(
                  carrying ? s.updateConnected : s.updateNotCarrying,
                  style: const TextStyle(color: AppDesign.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.space4),
          TextButton.icon(
            // Disabled while a reconnect runs, except on a TV: there a
            // disabled button gives up the remote's focus, so it stays
            // enabled and the press is ignored.
            onPressed: busy ? (FormFactor.isTv ? () {} : null) : onReconnect,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(s.updateReconnect),
          ),
        ],
      );
    }
    return Text(s.updateConnectHint);
  }
}

/// The Connect control on the forced update dialog.
///
/// Shows Connect while the tunnel is down or failed, and progress while it
/// is coming up or while [waiting]. Once it is up the dialog drops this
/// control and [_ConnectLine] says the user is connected. A tap runs
/// [connectFromButton], the home screen's own connect path, so the
/// servers, doors and fallbacks are the same ones.
class _ConnectFirst extends StatelessWidget {
  const _ConnectFirst({required this.waiting, required this.onConnect});

  final bool waiting;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final vpn = context.watch<VpnService>();
    final flow = context.watch<ConnectFlow>();

    final busy =
        waiting ||
        flow.isBusy ||
        vpn.isConnecting ||
        vpn.isVerifying ||
        vpn.status == VpnStatus.disconnecting;
    if (busy) {
      return ConstrainedBox(
        // The height of the button it replaces (see _compactButtons), so
        // the dialog does not jump.
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppDesign.steelLight,
              ),
            ),
            const SizedBox(width: AppDesign.space12),
            Flexible(child: Text(s.statusConnecting)),
          ],
        ),
      );
    }

    // Tonal: the way to update stays the one brand button. Connect is
    // the step for when it does not open (the line in the text says so).
    return FilledButton.icon(
      onPressed: onConnect,
      style: _tonal,
      icon: const Icon(Icons.power_settings_new_rounded),
      label: Text(s.updateConnect),
    );
  }
}
