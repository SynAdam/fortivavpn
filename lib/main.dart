// Copyright (C) 2026 NimusAI. LICENSING.md says which licence this code is
// under in each build, and gives the additional terms under GPL-3.0
// section 7.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/design_system.dart';
import 'core/form_factor.dart';
import 'core/state/apn_guide.dart';
import 'core/state/billing_state.dart';
import 'core/state/server_state.dart';
import 'core/state/device_state.dart';
import 'core/state/app_config_state.dart';
import 'core/state/chat_connection.dart';
import 'core/state/connect_flow.dart';
import 'core/state/dedicated_state.dart';
import 'core/state/dial_server.dart';
import 'core/state/invite_events.dart';
import 'core/state/invite_prompt.dart';
import 'core/state/invite_tree_intro.dart';
import 'core/state/referral_state.dart';
import 'core/state/locale_state.dart';
import 'core/state/message_state.dart';
import 'core/state/premium_prompt.dart';
import 'core/state/review_prompt.dart';
import 'core/state/stall_recovery.dart';
import 'core/state/support_state.dart';
import 'core/update_gate.dart';
import 'api/api_client.dart';
import 'api/api_routes.dart';
import 'api/bootstrap.dart';
import 'services/community_checks.dart';
import 'services/delivery_log.dart';
import 'services/door_refresh.dart';
import 'services/report_schedule.dart';
import 'services/size_probe.dart';
import 'services/vpn_event_reporter.dart';
import 'services/vpn_service.dart';
import 'services/speed_test_service.dart';
import 'services/session_tracker.dart';
import 'services/test_point.dart';
import 'services/variant_tests.dart';
import 'screens/home_screen.dart';
import 'screens/language_setup_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/focus_ring.dart';
import 'widgets/outside_link.dart';
import 'widgets/readable_width.dart';
import 'widgets/update_dialog.dart';
import 'l10n/generated/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FormFactor.read();
  if (FormFactor.isTv) {
    // The remote's focus is drawn from the first frame, not only after
    // the first key press as on a phone. See FocusRing.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  }
  await _setWindow();
  SystemChrome.setSystemUIOverlayStyle(AppDesign.systemBars);

  // Load persisted locale before app renders
  final localeState = LocaleState();
  await localeState.loadLocale();

  // Before the first request, so every call to the backend says which
  // build sent it. A quick platform call that never throws.
  await ApiConfig.readAppBuild();

  // Before the first request too, so every upload try from launch on is in
  // the log. See DeliveryLog.
  DeliveryLog.install();
  // The fallback file an earlier run read, not awaited: it checks a
  // signature, and the first frame does not wait for that. A new read when
  // a call to the backend fails on the phone's own network.
  unawaited(Bootstrap.instance.restore());
  ApiClient.onDirectFailed = Bootstrap.instance.readSoon;
  // Which relay works, and which fails, is kept per network, under the key
  // the door memory uses. Read only when a call needs a relay.
  ApiRelays.networkKey = ConnectFlow.currentNetworkKey;

  runApp(FortivaVpnApp(localeState: localeState));
}

/// How the app's window is set up. Android keeps both per activity, and
/// the engine outlives the activity (AppEngine), so the app sets them again
/// when a new activity shows it (_AppBootstrapState).
///
/// Never throws. With no activity there is nothing to answer the call: the
/// one that started the app can go before main() gets here. main() must
/// still reach runApp, because the kept engine does not run it again.
Future<void> _setWindow() async {
  // Portrait on a phone. A TV cannot turn, and a box that is asked for
  // portrait shows the app sideways or in a strip down the middle.
  if (!FormFactor.isTv) {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]).timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('No portrait lock for now ($e)');
    }
  }

  // Edge to edge on every Android version, with both bars transparent, so
  // the canvas runs to the bottom of the screen. Before this, phones below
  // Android 15 laid the app out above the navigation bar, and the bar showed
  // as a dark strip of its own color under every screen. Android 15 and
  // later already draw apps edge to edge. Screens keep their content above
  // the bar with SafeArea (MediaQuery.viewPadding).
  unawaited(
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    ).catchError((Object e) => debugPrint('No edge to edge for now ($e)')),
  );
}

class FortivaVpnApp extends StatelessWidget {
  final LocaleState localeState;

  const FortivaVpnApp({super.key, required this.localeState});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceState()),
        ChangeNotifierProvider(create: (_) => AppConfigState()),
        // The home screen's APN guide card. It reads nothing from the
        // phone until the config turns the guide on.
        ChangeNotifierProvider(create: (_) => ApnGuide()),
        ChangeNotifierProvider(create: (_) => DedicatedState()),
        // The shared invite link opens the invite page in the app's language.
        ChangeNotifierProvider(
          create: (_) => ReferralState(
            language: () => MessageState.appLanguage(localeState.locale),
          ),
        ),
        // Premium. A grant changes the allowance the quota card shows, so
        // it is handed the device's servers state, listed above.
        ChangeNotifierProvider(
          create: (ctx) => BillingState(dedicated: ctx.read<DedicatedState>()),
        ),
        // The calm Premium card's record. It hears every Premium grant, so
        // a purchase stops the card for good, and is created at launch for
        // that reason.
        ChangeNotifierProvider(
          lazy: false,
          create: (ctx) => PremiumPrompt(billing: ctx.read<BillingState>()),
        ),
        ChangeNotifierProvider(create: (_) => VpnService()),
        // Reports the app's checks of community links. It asks the VPN
        // whether the app's requests go through the tunnel, so it is listed
        // after the VPN. The server list and the connect flow use it, so
        // they are listed after it.
        Provider(
          create: (ctx) {
            final vpn = ctx.read<VpnService>();
            return CommunityChecks(
              throughTunnel: () =>
                  vpn.reporter.reportsGoThroughTunnel?.call() ?? true,
            );
          },
        ),
        ChangeNotifierProvider(
          create: (ctx) => ServerState(
            communityChecks: ctx.read<CommunityChecks>(),
            bootstrap: Bootstrap.instance,
          ),
        ),
        // The fallback file, for the screens that pass it between phones
        // and the home screen's offer to get it from a friend.
        ChangeNotifierProvider<Bootstrap>.value(value: Bootstrap.instance),
        ChangeNotifierProvider(
          create: (ctx) => ConnectFlow(
            vpn: ctx.read<VpnService>(),
            communityChecks: ctx.read<CommunityChecks>(),
            // A tap that waits to try again tries at once when the phone
            // moves to another network, or gets one back.
            networkChanges: () => Connectivity().onConnectivityChanged.asyncMap(
              (_) => ConnectFlow.currentNetworkKey(),
            ),
            doorPair: () => ctx.read<DedicatedState>().doorPair,
            // Whether the backend lets this device use the backup network,
            // and where its allowance stands.
            psiphonDevice: () => ctx.read<DedicatedState>().psiphonDevice,
          ),
        ),
        // Does nothing unless the backend says this phone is a test point.
        ChangeNotifierProvider(
          lazy: false,
          create: (ctx) => TestPointRunner(
            ctx.read<DedicatedState>(),
            otherVpnUp: ctx.read<VpnService>().otherVpnUp,
          ),
        ),
        // A tunnel that stops carrying data gets the connect button's search
        // without a tap (VpnService.stalled).
        Provider(
          lazy: false,
          create: (ctx) {
            final vpn = ctx.read<VpnService>();
            final flow = ctx.read<ConnectFlow>();
            final dedicated = ctx.read<DedicatedState>();
            final servers = ctx.read<ServerState>();
            return StallRecovery(
              vpn: vpn,
              flow: flow,
              redial: () async {
                // A shared link the user picked is dialled first by any
                // tap. The dead one is not dialled again: the pick failed,
                // the same as a pick another door replaced.
                final dead = vpn.activeDoor;
                if (dead != null &&
                    !dead.isDedicated &&
                    servers.isChosen &&
                    servers.selectedServer?.pathKey == dead.pathKey) {
                  servers.clearChoice();
                }
                final server = activeServer(dedicated, servers);
                if (server == null) return;
                await dialServer(
                  server,
                  vpn: vpn,
                  flow: flow,
                  dedicated: dedicated,
                  servers: servers,
                  afterStall: true,
                );
              },
            );
          },
          dispose: (_, recovery) => recovery.dispose(),
        ),
        ChangeNotifierProvider(create: (_) => SpeedTestService()),
        ChangeNotifierProvider(create: (_) => SessionTracker()),
        // Messages are fetched in the language the app shows, and not
        // before the user has chosen one.
        ChangeNotifierProvider(
          create: (_) => MessageState(
            language: () => MessageState.appLanguage(localeState.locale),
            languageChosen: () => localeState.hasChosen,
          ),
        ),
        // The support chat. A message carries whether the tunnel is up,
        // whether the app is still looking for a way in, while a failure
        // is on screen what kind of problem it was, how the latest taps
        // ended, and whether this copy can buy through Google Play. The
        // chat only reads these; it never starts or stops the tunnel.
        ChangeNotifierProvider(
          create: (ctx) {
            final vpn = ctx.read<VpnService>();
            final flow = ctx.read<ConnectFlow>();
            final billing = ctx.read<BillingState>();
            return SupportState(
              language: () => MessageState.appLanguage(localeState.locale),
              playBilling: billing.checkPlayBilling,
              connected: () => chatConnected(vpn),
              problem: () => vpn.errorMessage == null
                  ? null
                  : SupportState.problemCategory(vpn.failureVerdict),
              searching: () => chatSearching(vpn, flow),
              recentTaps: flow.recentTaps.toContext,
            );
          },
        ),
        // The invite card's record, and its events for the backend while
        // the user shares connection diagnostics. Above the rating card,
        // which hands it every tunnel outcome.
        ChangeNotifierProvider(lazy: false, create: (_) => InvitePrompt()),
        // Whether the introduction to the invite tree has opened by itself.
        Provider<InviteTreeIntroRecord>(create: (_) => InviteTreeIntroRecord()),
        Provider(
          create: (_) => InviteEvents(),
          dispose: (_, InviteEvents events) => events.dispose(),
        ),
        // Created at launch rather than when first read, because it has to
        // hear every connect and failure from the start to know the user's
        // good days. The invite card hears the same outcomes:
        // VpnService.onOutcome has one slot.
        ChangeNotifierProvider(
          lazy: false,
          create: (ctx) {
            final review = ReviewPrompt();
            final invite = ctx.read<InvitePrompt>();
            ctx.read<VpnService>().onOutcome = (type) {
              review.record(type);
              invite.record(type);
            };
            return review;
          },
        ),
        ChangeNotifierProvider.value(value: localeState),
      ],
      child: Consumer<LocaleState>(
        builder: (context, locale, _) {
          // The language the app is drawn in, set before the theme is built
          // so AppDesign.textTheme and AppDesign.ls follow it. Before the
          // user has chosen, MaterialApp picks from the phone's languages,
          // and the same pick is made here.
          final shown =
              locale.locale ??
              basicLocaleListResolution(
                WidgetsBinding.instance.platformDispatcher.locales,
                S.supportedLocales,
              );
          AppDesign.activeLocale = shown;
          return MaterialApp(
            title: 'Fortiva',
            debugShowCheckedModeBanner: false,
            navigatorKey: appNavigatorKey,
            // The bar style is set once before runApp, but nothing re-applied
            // it on screens without an AppBar: after a cold start the home
            // screen kept a black navigation bar until a screen with an AppBar
            // had been opened. An AnnotatedRegion at the root re-applies it on
            // every frame for every screen.
            builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: AppDesign.systemBars,
              child: FocusRing(child: child ?? const SizedBox.shrink()),
            ),
            theme: AppDesign.darkThemeForLocale(shown),
            locale: locale.locale,
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            home: const _AppBootstrap(),
          );
        },
      ),
    );
  }
}

/// Fires background data loads then shows the home screen.
class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  bool _showSplash = true;

  /// Whether the language question still has to be asked, and what to
  /// pre-select when it is. Resolved during the splash so the picker
  /// opens already pointing at the right row.
  bool _needsLanguage = false;
  String _suggestedLanguage = 'en';
  bool _languageResolved = false;

  VpnService? _vpnService;
  bool _wasConnected = false;

  /// Whether the tunnel was up and checked at the last status change, so
  /// messages are checked once per connection rather than on every change.
  bool _wasVerified = false;

  /// Whether this run has tried the install referrer claim on a working
  /// connection.
  bool _referrerTriedOnConnect = false;
  LocaleState? _localeState;

  /// Runs the update check at launch and on every return to the
  /// foreground. Created once the providers can be read.
  UpdateGate? _updateGate;

  /// Tries the waiting reports again on a network change and every few
  /// minutes while the app is in front. Created once the providers can be
  /// read.
  ReportSchedule? _reportSchedule;

  /// Fetches the device's own servers again while a tunnel stays up, so the
  /// next tap after a long session dials the addresses in use now
  /// (DoorRefresh).
  DoorRefresh? _doorRefresh;

  /// Measures which transfer sizes reach the backend from this network,
  /// when the config asks for it. Tried after the config loads and with
  /// every try of the waiting reports. Created once the providers can be
  /// read.
  SizeProbeRunner? _sizeProbe;

  /// Checks the variants of this device's doors that the backend hands out
  /// in its answer, with the tunnel down. Tried when the answer changes and
  /// with every try of the waiting reports, and in the background on a
  /// timer when the backend asks for one; does nothing while the answer
  /// carries none. Created once the providers can be read.
  VariantTester? _variantTests;
  late final AppLifecycleListener _lifecycle;

  /// Set when the activity that showed the app went (see _setWindow). True
  /// at first: an activity can go, and the next one come, before this state
  /// exists to hear it.
  bool _windowLost = true;

  @override
  void initState() {
    super.initState();

    _lifecycle = AppLifecycleListener(
      onHide: () {
        _updateGate?.hidden();
        _reportSchedule?.background();
        _variantTests?.hidden();
        // Which offers were seen, before the app may be closed.
        _billing((b) => unawaited(b.sendUpsellEvents()));
        _inviteEvents((e) => unawaited(e.send()));
      },
      // The activity went, and the engine with the app stayed (AppEngine).
      onDetach: () => _windowLost = true,
      onResume: () {
        // A new activity shows the app, with Android's own window settings.
        if (_windowLost) {
          _windowLost = false;
          unawaited(_setWindow());
        }
        _updateGate?.resumed();
        _reportSchedule?.foreground();
        _variantTests?.shown();
        _refreshMessages();
        _support((s) => s.resumed());
        _billing((b) => b.resumed());
      },
    );
    // Already on screen, so no resume comes for the activity showing it now.
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive) {
      _windowLost = false;
      unawaited(_setWindow());
    }
    // What the 24 hour Later of older builds saved is no longer read.
    unawaited(UpdateDialog.forgetOldLater());

    // Runs alongside the splash. A device that has already chosen skips
    // this entirely, so the cost falls only on a genuine first launch.
    _resolveLanguage();

    // Defer to after first frame so notifyListeners() doesn't crash
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Fire and forget: none of these blocks the UI.
      final device = context.read<DeviceState>();
      final dedicated = context.read<DedicatedState>();
      final vpn = context.read<VpnService>();
      // A register that lands late, after the retries in DeviceState, is
      // what the backend was waiting on: until then it refuses this
      // device's reports and has no servers of its own for it.
      device.onRegistered = () {
        unawaited(vpn.flushReports());
        // Kept servers from an earlier run count as none: they may be old.
        // Through refreshAllowance, so a tunnel on a shared link comes down
        // when the answer says the allowance is spent.
        if (!dedicated.hasServers || dedicated.fromSaved) {
          unawaited(refreshAllowance(vpn: vpn, dedicated: dedicated));
        }
        _refreshMessages();
        // A phone the backend did not know yet could not be told whether
        // the chat is on for it.
        _support((s) => s.checkStatus());
        // Nor whether Premium is on sale for it. Also how a new account
        // finds out, after a deletion.
        _billing((b) => b.refresh());
      };
      device.registerDevice();
      final flow = context.read<ConnectFlow>();
      final appConfig = context.read<AppConfigState>();
      final servers = context.read<ServerState>();
      // A phone whose own traffic goes through another app's VPN would
      // measure that app's route, filed under the phone's carrier. The size
      // probe and the variant tests wait for the phone's own network. Up to
      // 2.2.0 their report took the slot from the other app instead.
      Future<String?> ownNetworkType() async => await vpn.otherVpnUp()
          ? null
          : await VpnEventReporter.currentNetworkType();
      _sizeProbe = SizeProbeRunner(
        settings: () => appConfig.sizeProbe,
        // Nothing runs while the user waits on a connect, nor beside the
        // variant tests, whose checks it would slow.
        busy: () =>
            flow.isBusy ||
            vpn.isConnecting ||
            vpn.isVerifying ||
            vpn.awaitingPermission ||
            (_variantTests?.running ?? false),
        // Nor where the app's own requests would go through the tunnel.
        throughTunnel: () =>
            vpn.reporter.reportsGoThroughTunnel?.call() ?? true,
        // Never on settings older than a return to the foreground would
        // trust, so turning the probe off reaches a phone kept alive in the
        // background by its tunnel.
        stale: () => UpdateGate.isStale(appConfig.loadedAt, DateTime.now()),
        reload: appConfig.load,
        network: ConnectFlow.currentNetworkKey,
        networkType: ownNetworkType,
      );
      _variantTests = VariantTester(
        dedicated,
        // Never beside a connect, a tunnel going down, a list being tested
        // or a size probe.
        idle: () =>
            !vpn.isConnecting &&
            vpn.status != VpnStatus.disconnecting &&
            !vpn.isVerifying &&
            !vpn.awaitingPermission &&
            !flow.isBusy &&
            !dedicated.isPingingAll &&
            !servers.isPingingAll &&
            !(_sizeProbe?.running ?? false),
        // And with the tunnel down when the backend says so.
        tunnelUp: () => vpn.isConnected,
        throughTunnel: () =>
            vpn.reporter.reportsGoThroughTunnel?.call() ?? true,
        networkType: ownNetworkType,
      );
      _reportSchedule = ReportSchedule(
        flush: () {
          // Before the size probe, which marks itself running before it
          // knows whether this network is due.
          _testVariants();
          _probeSizes();
          return vpn.flushReports();
        },
      )..start();
      servers.loadServers();
      context.read<SessionTracker>().loadSessions();
      // Started here rather than on the home screen so that the device's
      // own servers are already on their way while the splash is up.
      dedicated.refresh();
      _doorRefresh = DoorRefresh(refresh: dedicated.refresh);
      // Remote config first, because the install-referrer read below
      // must not run on a build where referrals are still switched off.
      _loadConfigThenReferrer();

      // Bridge VPN status → SessionTracker
      _vpnService = context.read<VpnService>();
      _vpnService!.addListener(_onVpnStatusChange);
      // The tunnel's own throughput reading steps aside for a speed test
      // the user started: two downloads at once measure each other, and
      // theirs is the one on screen.
      final speedTest = context.read<SpeedTestService>();
      _vpnService!.speedTestRunning = () => speedTest.isRunning;

      // The first check waits for the language, so choosing it on the
      // first launch is what starts it. A later change fetches the
      // messages again in the new language.
      _localeState = context.read<LocaleState>()..addListener(_refreshMessages);

      // After the first frame and not awaited, so the chat's entry points
      // can never hold up launch or the connect button.
      _support((s) => s.checkStatus(force: true));

      // Premium status and catalog, and any Play purchase still waiting
      // for the backend. Not awaited, for the same reason.
      _billing((b) => b.start());
    });
  }

  /// Ask again, now that a tunnel is up, for what a network that cuts our
  /// calls kept from us: the registration, this device's own servers and
  /// the public lists. The app's calls go around its own tunnel, and after
  /// they fail there they go through it. A phone that started on a link
  /// from the fallback file gets its own servers this way. Never throws.
  void _catchUpThroughTunnel() {
    try {
      final device = context.read<DeviceState>();
      if (!device.isRegistered) {
        // A late register refreshes the device's own servers itself
        // (onRegistered).
        unawaited(device.registerDevice());
      } else {
        final dedicated = context.read<DedicatedState>();
        // Up on a shared link while the allowance is spent: nothing meters
        // the shared links, so the tunnel comes down.
        final vpn = context.read<VpnService>();
        if (dedicated.isBlocked) {
          unawaited(vpn.disconnect());
          return;
        }
        if (dedicated.lastRefreshFailed || dedicated.isLoading) {
          // A refresh under way started before the tunnel and may fail;
          // it is waited for, and asked again when it did. Through
          // refreshAllowance, so a tunnel on a shared link comes down when
          // the answer says the allowance is spent.
          unawaited(
            dedicated.refresh().then((_) {
              if (dedicated.lastRefreshFailed) {
                return refreshAllowance(vpn: vpn, dedicated: dedicated);
              }
              if (dedicated.isBlocked &&
                  (vpn.isConnected || vpn.isConnecting)) {
                return vpn.disconnect();
              }
            }),
          );
        }
      }
      final servers = context.read<ServerState>();
      if (servers.communityLoadFailed || servers.errorMessage != null) {
        unawaited(servers.loadServers(forceRefresh: true));
      }
      final appConfig = context.read<AppConfigState>();
      if (appConfig.loadedAt == null) {
        // A Play referrer claim waits for the config that says invites are
        // on. Through the tunnel it may arrive only now.
        unawaited(appConfig.load().then((_) => _claimInstallReferrer()));
      }
    } catch (e) {
      debugPrint('App: could not catch up through the tunnel ($e)');
    }
  }

  /// Claim the code the Play install referrer carried, when invites are on
  /// and a claim with it still waits for an answer (see
  /// ReferralState.claimFromInstallReferrer). Not awaited and never throws.
  void _claimInstallReferrer() {
    try {
      if (!mounted) return;
      if (!context.read<AppConfigState>().referralsEnabled) return;
      unawaited(context.read<ReferralState>().claimFromInstallReferrer());
    } catch (e) {
      debugPrint('App: install referrer claim not started ($e)');
    }
  }

  /// Run [action] on the invite events. Never throws.
  void _inviteEvents(void Function(InviteEvents events) action) {
    try {
      if (!mounted) return;
      action(context.read<InviteEvents>());
    } catch (e) {
      debugPrint('App: invite events not sent ($e)');
    }
  }

  /// Measure transfer sizes if the config asks and this network is due.
  /// Not awaited and never throws.
  void _probeSizes() {
    final runner = _sizeProbe;
    if (runner != null) unawaited(runner.maybeRun());
  }

  /// Check the variants the backend handed out, if any wait and the phone
  /// is idle. Not awaited and never throws.
  void _testVariants() {
    final tester = _variantTests;
    if (tester != null) unawaited(tester.maybeRun());
  }

  /// Run [action] on Premium's state. Never throws.
  void _billing(void Function(BillingState billing) action) {
    try {
      if (!mounted) return;
      action(context.read<BillingState>());
    } catch (e) {
      debugPrint('App: Premium check failed ($e)');
    }
  }

  /// Run [action] on the support chat's state. Never throws.
  void _support(void Function(SupportState support) action) {
    try {
      if (!mounted) return;
      action(context.read<SupportState>());
    } catch (e) {
      debugPrint('App: support chat check failed ($e)');
    }
  }

  /// Check for messages from the Fortiva team. Not awaited and never
  /// throws, so nothing it does can hold up launch or a connect.
  void _refreshMessages({bool force = false}) {
    try {
      if (!mounted) return;
      final messages = context.read<MessageState>();
      // What a check with the app off screen found first, so a message it
      // got from the public file is listed even when the app's own check
      // cannot reach us.
      unawaited(
        messages.adoptBackground().then((_) => messages.refresh(force: force)),
      );
    } catch (e) {
      debugPrint('App: could not check for messages ($e)');
    }
  }

  /// Work out whether to ask for a language, and which one to offer.
  ///
  /// The lookup behind this can reach the network, so it runs while the
  /// splash is still up rather than in front of the user.
  Future<void> _resolveLanguage() async {
    final localeState = context.read<LocaleState>();
    if (localeState.hasChosen) {
      if (mounted) setState(() => _languageResolved = true);
      return;
    }

    final suggested = await localeState.suggestedLanguage();
    if (!mounted) return;
    setState(() {
      _suggestedLanguage = suggested;
      _needsLanguage = true;
      _languageResolved = true;
    });
  }

  /// Load remote config, then read the Play install referrer if the
  /// feature is on.
  ///
  /// Sequential because the referrer can only be read once per install:
  /// firing it before the flag is known would spend that one read on a
  /// build that then discards the answer.
  Future<void> _loadConfigThenReferrer() async {
    final appConfig = context.read<AppConfigState>();
    final referrals = context.read<ReferralState>();
    _updateGate = UpdateGate(
      config: appConfig,
      opens: UpdateDialog.opens,
      check: (rules) async {
        if (mounted) await UpdateDialog.maybeShow(context, rules);
      },
    );
    final fetching = appConfig.load();
    // Before anything else the config is used for: a user on a build we no
    // longer support has to be told so. The check runs at once on the rules
    // saved by an earlier launch, without waiting for this fetch, which can
    // take over a minute to fail when every route to us is blocked, and
    // again when the fetch ends. Not awaited by the referrer path below, so
    // nothing the dialog does holds up the rest of launch.
    unawaited(_updateGate!.launched(fetching));
    await fetching;
    if (!mounted) return;
    // The size probe has its settings only once the config has landed.
    _probeSizes();
    if (!appConfig.referralsEnabled) return;
    // Silent by design. On iOS, a sideloaded APK, or a device without
    // Play Services this does nothing, and the user can still type a code.
    await referrals.claimFromInstallReferrer();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _reportSchedule?.dispose();
    _doorRefresh?.dispose();
    _variantTests?.dispose();
    _vpnService?.removeListener(_onVpnStatusChange);
    _localeState?.removeListener(_refreshMessages);
    super.dispose();
  }

  /// Track sessions, and run what waits for a verified tunnel: messages,
  /// the support chat, and the first-working-connection note for offers.
  void _onVpnStatusChange() {
    if (!mounted) return;
    final vpn = _vpnService!;
    final tracker = context.read<SessionTracker>();
    final isConnected = vpn.isConnected;

    if (isConnected && !_wasConnected) {
      // VPN just connected — start a session
      final conn = vpn.currentConnection;
      final serverState = context.read<ServerState>();
      // Through the backup network the selection is not what carries the
      // session, so its country and flag are not the session's.
      final server = vpn.onPsiphon ? null : serverState.selectedServer;

      tracker.startSession(
        serverName: conn?.serverName ?? server?.name ?? 'Unknown',
        serverCountry: server?.country ?? '',
        serverFlagEmoji: server?.flagEmoji ?? '🌐',
      );
    } else if (!isConnected && _wasConnected) {
      // VPN just disconnected — end the session
      tracker.endSession();
    }
    _wasConnected = isConnected;

    // A phone whose network cuts our calls often reaches us only through
    // the tunnel, so a check that failed before is tried again as soon as
    // one is up and checked.
    final verified = isConnected && !vpn.isVerifying;
    if (verified && !_wasVerified) {
      try {
        _refreshMessages(force: context.read<MessageState>().lastAttemptFailed);
      } catch (e) {
        debugPrint('App: could not check for messages ($e)');
      }
      // A reply or a message waiting to go may only get through now.
      _support((s) => s.connectVerified());
      _catchUpThroughTunnel();
      _doorRefresh?.connected();
      // No offer shows before the first working connection.
      _billing((b) => unawaited(b.noteWorkingConnection()));
      // A Play referrer claim lost on the network earlier is tried again
      // on the first working connection of the run.
      if (!_referrerTriedOnConnect) {
        _referrerTriedOnConnect = true;
        _claimInstallReferrer();
      }
    }
    if (!isConnected) _doorRefresh?.disconnected();
    _wasVerified = verified;
  }

  @override
  Widget build(BuildContext context) {
    // Cross-fade rather than a hard cut: the splash dissolving into the app
    // is most of what makes a launch feel considered instead of abrupt.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _screen(),
    );
  }

  Widget _screen() {
    // The splash also covers the language lookup, so a first launch never
    // shows an empty frame while the suggestion is being worked out.
    if (_showSplash || !_languageResolved) {
      return SplashScreen(
        key: const ValueKey('splash'),
        onFinished: () {
          if (mounted) setState(() => _showSplash = false);
        },
      );
    }

    if (_needsLanguage) {
      return ReadableWidth(
        key: const ValueKey('language'),
        child: LanguageSetupScreen(
          localeState: context.read<LocaleState>(),
          suggested: _suggestedLanguage,
          onDone: () {
            if (mounted) setState(() => _needsLanguage = false);
          },
        ),
      );
    }

    return const HomeScreen(key: ValueKey('home'));
  }
}
