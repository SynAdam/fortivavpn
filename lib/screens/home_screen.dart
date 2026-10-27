import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/bootstrap.dart';
import '../api/config_service.dart';
import '../core/design_system.dart';
import '../core/form_factor.dart';
import '../core/haptics.dart';
import '../core/page_transitions.dart';
import '../core/update_check.dart';
import '../core/state/apn_guide.dart';
import '../core/state/app_config_state.dart';
import '../core/state/billing_state.dart';
import '../core/state/connect_flow.dart';
import '../core/state/dedicated_state.dart';
import '../core/state/dial_server.dart';
import '../core/state/message_state.dart';
import '../core/state/notice_permission_prompt.dart';
import '../core/state/premium_prompt.dart';
import '../core/state/review_prompt.dart';
import '../core/state/server_state.dart';
import '../core/state/support_state.dart';
import '../data/models/billing.dart';
import '../data/models/connection_info.dart';
import '../data/models/server.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/candidate_prober.dart';
import '../services/connect_trace.dart';
import '../services/failure_verdict.dart';
import '../services/notice_channel.dart';
import '../services/peer_pick.dart';
import '../services/test_point.dart';
import '../services/vpn_service.dart';
import '../utils/number_localizer.dart';
import '../widgets/apn_guide_card.dart';
import '../widgets/elapsed_time.dart';
import '../widgets/power_button.dart';
import '../widgets/power_face.dart';
import '../widgets/state_wash.dart';
import '../widgets/ui/pressable.dart';
import '../widgets/ui/signal_bars.dart';
import '../core/state/locale_state.dart';
import '../widgets/language_picker.dart';
import '../widgets/limit_sheet.dart';
import '../widgets/message_bell.dart';
import '../widgets/message_dialog.dart';
import '../widgets/corner_button_layout.dart';
import '../widgets/path_checklist.dart';
import '../widgets/premium_offers.dart';
import '../widgets/quota_card.dart';
import '../widgets/readable_width.dart';
import '../widgets/server_card.dart' show FlagDisc;
import '../widgets/support_button.dart';
import '../widgets/update_dialog.dart';
import '../widgets/server_title.dart';
import 'inbox_screen.dart';
import 'invite_screen.dart';
import 'my_servers_screen.dart';
import 'peer_receive_screen.dart';
import 'premium_screen.dart';
import 'server_list_screen.dart';
import 'settings_screen.dart';
import 'speed_test_screen.dart';
import '../core/state/device_state.dart';
import '../core/state/invite_events.dart';
import '../core/state/invite_prompt.dart';
import '../core/state/referral_state.dart';
import '../api/referral_service.dart';
import '../services/invite_share.dart';
import '../widgets/invite_card.dart';
import '../widgets/invite_code_dialog.dart';

part 'home_invite.dart';

/// The home screen.
///
/// The subject of this screen is the server that belongs to this device.
/// Every install is provisioned its own client on every server in the
/// fleet, with credentials no one else holds, and that is what the button
/// connects through, so the screen names it, says plainly that it is not
/// shared, shows how it is performing, and offers the way to move to
/// another one.
///
/// The shared community and official lists are still there, but they are
/// the fallback: what the app uses on a first run before provisioning has
/// landed. They are not a way around the allowance. Once the window is
/// spent the button refuses to connect until it refills, because a limit
/// that only applies to one of two doors is not a limit. A screen built
/// around the shared list first would be describing the wrong product.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// How long after a tap that starts a connect the power button does not
  /// take a tap as a stop.
  ///
  /// The button is a toggle, so the second tap of a double tap stopped the
  /// connect the first tap had just started, and the user had to tap again
  /// and wait for a new search. In the 24 hours to 01:00 Tehran on
  /// 2026-10-12, 30 taps were stopped within 3 seconds of their dial, and
  /// 14 of those phones connected on a later tap within a minute. A stop
  /// after this works as before.
  static const doubleTapGuard = Duration(seconds: 1);

  /// How long the status line says the search stopped, after a tap on the
  /// button stopped one. On Tehran day 2026-10-23, 448 stops came after
  /// steps that had all failed, and 284 of them were followed by another
  /// tap within a minute (clients #342).
  static const stoppedNote = Duration(seconds: 3);

  /// How long a search runs before a second line under the status says it
  /// can take a while and that the button stops it. Users stopped a search
  /// after 10 to 15 seconds on Tehran day 2026-10-23 (clients #342).
  static const slowSearchHint = Duration(seconds: 15);

  /// How long after a tap's search ended without a tunnel a late answer
  /// that the data is used up still counts as that tap's, and opens the
  /// limit sheet at once.
  ///
  /// On a slow line the allowance question can outlast the 4 seconds the
  /// search waits for it, and the tap then ends as an ordinary failure. The
  /// question keeps running, and its answer turns the phone blocked a
  /// moment later. App-side timing, not a rule of the service.
  static const tapSheetLate = Duration(seconds: 15);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _didAutoPing = false;

  /// Reads Private DNS again when the user comes back from the phone's
  /// settings, so the warning goes away as soon as they have turned it off.
  late final AppLifecycleListener _lifecycle;

  /// A tap's connect has not finished: from the tap, through the wait for
  /// this device's own servers and the whole connect flow. The button is
  /// shown connecting all that time, and a tap on it is a stop.
  bool _starting = false;

  /// Increased by every tap that starts or stops a connect. A connect that
  /// a later tap stopped sees the change, and does not dial when the wait
  /// for its servers ends. A tap the double-tap guard ignores leaves it as
  /// it is, so that connect still dials.
  int _tap = 0;

  /// Runs for [HomeScreen.doubleTapGuard] from a tap that starts a
  /// connect. While it runs, a tap on the power button that would stop
  /// that connect is ignored.
  Timer? _stopGuard;

  /// Runs for [HomeScreen.stoppedNote] from a tap that stopped a search.
  /// While it runs, the status line says the search stopped.
  Timer? _stoppedNote;

  /// When the tap that is connecting now ([_starting]) was made. The second
  /// line under the status counts from it during the tap's first try,
  /// including the wait for this device's servers before it.
  DateTime? _tapAt;

  /// Whether that tap waits for this device's servers before its first try
  /// (connectFromButton's onWaitingForOwn). The stages show meanwhile.
  bool _waitingForOwn = false;
  final _prober = CandidateProber();

  /// The power button's focus. On a TV the remote starts on the button.
  final _powerFocus = FocusNode(debugLabel: 'power button');

  /// True for the first frame after the app opened or came back to the
  /// front, and only that frame. A connect that finished while the app was
  /// away first shows in that frame, and it did not happen in front of the
  /// user, so the power button gets no success moment for it. A connect
  /// still under way then, which lands later while the user watches, does
  /// get one.
  bool _justOpened = true;

  /// The connect under way started by itself: the tunnel stopped carrying
  /// data and the app went looking for another path (ConnectFlow.afterStall).
  /// A connection that came back on its own is not the user's success, so
  /// the power button does not celebrate it. Kept until that connect ends,
  /// because the flow stops saying so before the tunnel is checked.
  bool _cameBackByItself = false;

  /// The Private DNS host the user closed the warning for. It comes back
  /// only if the setting changes to another host.
  String? _privateDnsDismissed;

  /// Whether the user closed the offer to get help from a friend's phone.
  /// It comes back on the next tap of the button.
  bool _friendOfferClosed = false;

  /// Whether Android reported no network at all, no mobile data and no
  /// wifi, the last time it was asked: at launch, on return to the app and
  /// after each tap. A friend's phone cannot help then, so the offer stays
  /// hidden.
  bool _noNetwork = false;

  /// How long the tunnel must have been up and checked, with nothing else
  /// going on, before a message may pop up. A popup that lands while the
  /// user is still looking at the button turning green is in the way.
  static const popupSettle = Duration(seconds: 5);

  /// What the message popup watches. Null when there is no MessageState
  /// above this screen, as in tests of the screen itself.
  MessageState? _messages;
  VpnService? _popupVpn;
  ConnectFlow? _popupFlow;

  /// Since when the screen has been in a state a popup may appear in.
  DateTime? _calmSince;
  Timer? _popupTimer;

  /// How long the screen must have been calm before the rating card is
  /// asked for. Longer than [popupSettle]: someone who opened the app to
  /// disconnect or switch servers does it within a few seconds, and the
  /// card must not land on that tap.
  static const reviewSettle = Duration(seconds: 10);

  /// What the rating card watches. Null when there is no ReviewPrompt
  /// above this screen, as in tests of the screen itself.
  ReviewPrompt? _review;
  VpnService? _reviewVpn;
  ConnectFlow? _reviewFlow;
  Timer? _reviewTimer;

  /// What the question about notifications waits on (see
  /// NoticePermissionPrompt). Android only.
  VpnService? _noticeVpn;
  ConnectFlow? _noticeFlow;
  Timer? _noticeTimer;

  /// Whether the tunnel was up and checked at the last look, and whether
  /// this run saw it come up while the app was on screen. Null before the
  /// first look, so an app opened with the tunnel already up does not count
  /// as seeing it come up.
  bool? _noticeWasUp;
  bool _noticeSawConnect = false;

  /// How long after the tunnel came up on screen the question is asked:
  /// while the user still looks at the button turning green, before they
  /// put the phone away, and before a message popup ([popupSettle]).
  static const noticeAfterConnect = Duration(seconds: 2);

  /// The start of the connection the record last said no for. Nothing in
  /// the record changes during a connection, so it is not read again until
  /// the next one.
  DateTime? _reviewRefusedFor;

  /// What the calm Premium card watches. Null when there is no
  /// PremiumPrompt or BillingState above this screen.
  PremiumPrompt? _premiumPrompt;
  BillingState? _promptBilling;
  VpnService? _promptVpn;
  ConnectFlow? _promptFlow;
  Timer? _premiumTimer;
  DateTime? _premiumRefusedFor;

  /// Whether the calm Premium card is on screen.
  bool _calmCardUp = false;

  /// The invite card. See _HomeInviteCard, in home_invite.dart. First read
  /// in initState, where reading a provider is allowed.
  late final _HomeInviteCard _invite = _HomeInviteCard(
    host: this,
    prompt: context.read<InvitePrompt?>(),
    onChanged: () {
      if (mounted) setState(() {});
    },
  );

  /// The refill ([QuotaStatus.resetsAt], as ISO text) the limit sheet last
  /// opened for. It opens by itself at most once per refill. Cleared when
  /// the account is deleted.
  static const _limitSheetKey = 'limit_sheet_shown_for';

  /// What the limit sheet watches. Null when there is no AppConfigState
  /// above this screen, as in tests of the screen itself.
  AppConfigState? _limitConfig;
  DedicatedState? _limitDedicated;
  VpnService? _limitVpn;
  ConnectFlow? _limitFlow;
  Timer? _limitTimer;
  bool _limitSheetOpen = false;
  bool _limitSheetShownThisRun = false;

  /// The tap that already got its limit sheet, so a late answer for the
  /// same tap does not open a second one.
  int _tapSheetFor = 0;

  /// The tap whose search last ended with no tunnel. A blocked answer
  /// while [_tapLate] runs, HomeScreen.tapSheetLate after that end, is
  /// that tap's. A timer, not a clock reading, so the window follows the
  /// same time as every other wait on this screen.
  int? _tapEndedFor;
  Timer? _tapLate;

  /// What the APN guide card reads. Null when there is no ApnGuide or
  /// AppConfigState above this screen, as in tests of the screen itself.
  ApnGuide? _apnGuide;
  AppConfigState? _apnConfig;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (!mounted) return;
        _quietForOneFrame();
        context.read<VpnService>().checkPrivateDns();
        unawaited(_checkNetwork());
        // The wait before a popup starts again now the user can see it.
        _checkPopup();
        _checkReview();
        _checkNoticePrompt();
        // A tap on a message notification brings the app back here.
        unawaited(_openTappedMessage());
        _checkPremiumPrompt();
        _checkLimitSheet();
        // The phone may be on another network now, or back from the APN
        // screen with an IPv6 route, which takes the card away.
        _refreshApnGuide();
        _invite.check();
      },
      onHide: () {
        _checkPopup();
        _checkReview();
        _checkNoticePrompt();
        _checkPremiumPrompt();
        _invite.check();
        _limitTimer?.cancel();
        _limitTimer = null;
      },
    );
    _watchForMessages();
    _watchForReview();
    _watchForNoticePrompt();
    _watchForPremiumPrompt();
    _watchForLimitSheet();
    _watchForApnGuide();
    _invite.watch(context);
    unawaited(_checkNetwork());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _justOpened = false;
      _takeLeftover();
      // Asked for outright rather than by autofocus, which gives way to
      // whatever had focus before: on a first launch, the language list
      // this screen fades in over.
      if (FormFactor.isTv) _powerFocus.requestFocus();
      // This is what the connect button runs on, not decoration for the
      // quota line, so a failure here is worth retrying rather than
      // swallowing.
      _refreshQuota();
      _measureCandidates();
      // The app was started by a tap on a message notification.
      unawaited(_openTappedMessage());
      // After the first frame, not in initState: the read notifies, and a
      // notification while this screen is being built is an error.
      _refreshApnGuide();
    });
  }

  /// The app is back in front. Frames stop while it is away, so whatever
  /// changed meanwhile (a connect that finished, say) is drawn in the next
  /// frame; that frame shows it as it is, with no success moment.
  void _quietForOneFrame() {
    _justOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _justOpened = false);
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _checkNetwork() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final none = results.every((r) => r == ConnectivityResult.none);
      if (mounted && none != _noNetwork) setState(() => _noNetwork = none);
    } catch (e) {
      debugPrint('HomeScreen: network ($e)');
    }
  }

  /// A photo or a file from a friend's phone that came back after Android
  /// stopped and restarted the app while the camera app or the picker was
  /// open, which it often does on a phone with little memory. It goes on
  /// where it was cut off.
  Future<void> _takeLeftover() async {
    final answer = await PeerPick.leftover();
    if (answer == null || !mounted) return;
    unawaited(PeerReceiveScreen.open(context, start: answer));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _powerFocus.dispose();
    _popupTimer?.cancel();
    _messages?.removeListener(_checkPopup);
    _popupVpn?.removeListener(_checkPopup);
    _popupFlow?.removeListener(_checkPopup);
    _reviewTimer?.cancel();
    _reviewVpn?.removeListener(_checkReview);
    _reviewFlow?.removeListener(_checkReview);
    _noticeTimer?.cancel();
    _noticeVpn?.removeListener(_checkNoticePrompt);
    _noticeFlow?.removeListener(_checkNoticePrompt);
    _premiumTimer?.cancel();
    _promptVpn?.removeListener(_checkPremiumPrompt);
    _promptFlow?.removeListener(_checkPremiumPrompt);
    _promptBilling?.removeListener(_checkPremiumPrompt);
    _limitTimer?.cancel();
    _stopGuard?.cancel();
    _stoppedNote?.cancel();
    _tapLate?.cancel();
    _limitConfig?.removeListener(_checkLimitSheet);
    _limitDedicated?.removeListener(_checkLimitSheet);
    _limitVpn?.removeListener(_checkLimitSheet);
    _limitFlow?.removeListener(_checkLimitSheet);
    _apnConfig?.removeListener(_refreshApnGuide);
    _invite.dispose();
    super.dispose();
  }

  /// Listen for a message to pop up. Read here, not in [build], so this
  /// screen never rebuilds for messages and works the same without them.
  void _watchForMessages() {
    try {
      final messages = context.read<MessageState?>();
      if (messages == null) return;
      final vpn = context.read<VpnService>();
      final flow = context.read<ConnectFlow>();
      messages.addListener(_checkPopup);
      vpn.addListener(_checkPopup);
      flow.addListener(_checkPopup);
      _messages = messages;
      _popupVpn = vpn;
      _popupFlow = flow;
      _checkPopup();
    } catch (e) {
      debugPrint('HomeScreen: messages not watched ($e)');
    }
  }

  /// Whether a message may pop up now: the app is on screen, the tunnel is
  /// up and checked, the connect button has nothing in progress, and no
  /// checklist is showing. Never while the user is connecting or reading
  /// why it failed. Never in the background either, because most people
  /// leave the app as soon as the tunnel is up, and a popup pushed then
  /// would be counted as shown and lose its badge without being seen.
  bool _calm() => _calmWith(_popupVpn, _popupFlow);

  static bool _calmWith(VpnService? vpn, ConnectFlow? flow) {
    if (vpn == null || flow == null) return false;
    return WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed &&
        vpn.status == VpnStatus.connected &&
        !vpn.isVerifying &&
        !flow.isBusy &&
        !flow.showChecklist;
  }

  /// Pop up the waiting message once the screen has been calm for
  /// [popupSettle]. Never throws: whatever goes wrong here, the message
  /// still waits in the inbox with the badge.
  void _checkPopup() {
    try {
      if (!mounted) return;
      if (!_calm()) {
        _calmSince = null;
        _popupTimer?.cancel();
        _popupTimer = null;
        return;
      }
      final since = _calmSince ??= DateTime.now();
      if (_messages?.pendingPopup == null || _popupTimer != null) return;
      final wait = popupSettle - DateTime.now().difference(since);
      _popupTimer = Timer(wait.isNegative ? Duration.zero : wait, _popUp);
    } catch (e) {
      debugPrint('HomeScreen: message popup check failed ($e)');
    }
  }

  void _popUp() {
    _popupTimer = null;
    try {
      final messages = _messages;
      if (!mounted || messages == null || !_calm()) return;
      final message = messages.pendingPopup;
      if (message == null) return;
      // One popup per run. The card is asked for only when no message is
      // waiting, so this is a message that arrived after it; it waits in
      // the inbox with the badge. The same goes for the calm Premium card.
      if (_review?.askedThisRun ?? false) return;
      if (_premiumPrompt?.shownThisRun ?? false) return;
      if (_invite.prompt?.shownThisRun ?? false) return;
      // Something else has the screen: another page on top, the update
      // dialog, or a popup already up. Look again shortly rather than
      // stacking on it.
      final onTop = ModalRoute.of(context)?.isCurrent ?? false;
      if (!onTop || UpdateDialog.isShowing || MessageDialog.isShowing) {
        _popupTimer = Timer(popupSettle, _popUp);
        return;
      }
      unawaited(messages.markPopped(message.id));
      unawaited(MessageDialog.show(context, message, state: messages));
    } catch (e) {
      debugPrint('HomeScreen: message popup failed ($e)');
    }
  }

  /// Open the message a tapped notification is for, over this screen, as
  /// the popup would. When the message is no longer listed (it ended, or
  /// was withdrawn), the inbox opens instead. Waits when the update dialog
  /// or another message is on screen: the message stays in the inbox with
  /// the badge. Never throws.
  Future<void> _openTappedMessage() async {
    try {
      final messages = _messages;
      if (messages == null) return;
      final id = await NoticeChannel.takeOpened();
      if (id == null) return;
      // The background check may have found it while the app was closed.
      await messages.adoptBackground();
      if (!mounted || UpdateDialog.isShowing || MessageDialog.isShowing) {
        return;
      }
      final message = messages.byId(id);
      if (message == null) {
        unawaited(
          Navigator.of(
            context,
          ).push(SlideUpFadeTransition(page: const InboxScreen())),
        );
        return;
      }
      unawaited(messages.markPopped(message.id));
      unawaited(MessageDialog.show(context, message, state: messages));
    } catch (e) {
      debugPrint('HomeScreen: could not open a tapped message ($e)');
    }
  }

  /// Listen for the moment to ask whether messages may come as
  /// notifications. Android only: elsewhere the app shows them inside
  /// itself only.
  void _watchForNoticePrompt() {
    // Not on a TV either: it is never asked there (NoticePermissionPrompt).
    if (defaultTargetPlatform != TargetPlatform.android || FormFactor.isTv) {
      return;
    }
    try {
      final vpn = context.read<VpnService>();
      final flow = context.read<ConnectFlow>();
      vpn.addListener(_checkNoticePrompt);
      flow.addListener(_checkNoticePrompt);
      _noticeVpn = vpn;
      _noticeFlow = flow;
      _checkNoticePrompt();
    } catch (e) {
      debugPrint('HomeScreen: notification question not watched ($e)');
    }
  }

  /// Whether the screen is at rest for the question: the app on screen,
  /// nothing in progress, and either the tunnel up and checked or the
  /// tunnel down with no failure on screen. A phone that never gets a
  /// tunnel is still reached by the background check through the public
  /// file, so its user is asked too.
  static bool _noticeCalmWith(VpnService? vpn, ConnectFlow? flow) {
    if (vpn == null || flow == null) return false;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return false;
    }
    if (flow.isBusy || flow.showChecklist) return false;
    if (vpn.isVerifying || vpn.awaitingPermission) return false;
    if (vpn.errorMessage != null || vpn.privateDnsHost != null) return false;
    return vpn.status == VpnStatus.connected ||
        vpn.status == VpnStatus.disconnected;
  }

  /// Whether the question may show now. Not [_cardMayShow]: the question
  /// is about the app, not this build, so a newer version waiting does not
  /// hold it back, and neither does a message that popped up earlier in
  /// this run (the question is about exactly those messages). Never on top
  /// of anything: another page, the update dialog, a message, a card or
  /// sheet, or a message that is about to pop up.
  bool _noticeMayShow(VpnService vpn, ConnectFlow? flow) {
    if (FormFactor.isTv) return false;
    if (!_noticeCalmWith(vpn, flow)) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    if (UpdateDialog.isShowing || MessageDialog.isShowing) return false;
    if (_calmCardUp || _limitSheetOpen) return false;
    if (_review?.askedThisRun ?? false) return false;
    if ((_invite.prompt?.shownThisRun ?? false) || _invite.up) return false;
    // A message pops up only with the tunnel up; it goes first, and the
    // question follows once it is closed.
    final messages = _messages;
    if (vpn.status == VpnStatus.connected &&
        messages != null &&
        messages.pendingPopup != null) {
      return false;
    }
    return true;
  }

  /// Start the wait for the question while the screen is at rest, and stop
  /// it as soon as it is not. The wait is [noticeAfterConnect] when this
  /// run saw the tunnel come up on screen, else [reviewSettle]: an app
  /// opened with the tunnel up, or a home screen left idle. Never throws.
  void _checkNoticePrompt() {
    try {
      final prompt = NoticePermissionPrompt.instance;
      final vpn = _noticeVpn;
      if (!mounted || vpn == null) return;
      final up = vpn.status == VpnStatus.connected && !vpn.isVerifying;
      final resumed =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (_noticeWasUp == false && up && resumed) _noticeSawConnect = true;
      _noticeWasUp = up;
      if (prompt.askedThisRun || prompt.settledThisRun) return;
      if (!_noticeCalmWith(vpn, _noticeFlow)) {
        _noticeTimer?.cancel();
        _noticeTimer = null;
        return;
      }
      _noticeTimer ??= Timer(
        _noticeSawConnect && up ? noticeAfterConnect : reviewSettle,
        () => unawaited(_askNoticePermission()),
      );
    } catch (e) {
      debugPrint('HomeScreen: notification question check failed ($e)');
    }
  }

  Future<void> _askNoticePermission() async {
    _noticeTimer = null;
    try {
      final prompt = NoticePermissionPrompt.instance;
      final vpn = _noticeVpn;
      if (!mounted || vpn == null) return;
      if (!_noticeMayShow(vpn, _noticeFlow)) {
        // Something is on top or about to be: another page, a dialog, the
        // message popup. Nothing reports when it goes, so look again
        // shortly, as the popup does, while the screen stays at rest.
        if (_noticeCalmWith(vpn, _noticeFlow) &&
            !(_review?.askedThisRun ?? false)) {
          _noticeTimer = Timer(
            popupSettle,
            () => unawaited(_askNoticePermission()),
          );
        }
        return;
      }
      if (!await prompt.due()) return;
      // The answer took a moment. Anything that changed meanwhile wins.
      if (!mounted || !_noticeMayShow(vpn, _noticeFlow)) return;
      await prompt.ask();
    } catch (e) {
      debugPrint('HomeScreen: notification question failed ($e)');
    }
  }

  /// Listen for the moment to ask for a Google Play rating. Read here, not
  /// in [build], for the same reasons as [_watchForMessages].
  void _watchForReview() {
    try {
      final review = context.read<ReviewPrompt?>();
      if (review == null) return;
      final vpn = context.read<VpnService>();
      final flow = context.read<ConnectFlow>();
      vpn.addListener(_checkReview);
      flow.addListener(_checkReview);
      _review = review;
      _reviewVpn = vpn;
      _reviewFlow = flow;
      _checkReview();
    } catch (e) {
      debugPrint('HomeScreen: rating card not watched ($e)');
    }
  }

  /// Start the wait for the rating card while the screen is calm, and
  /// stop it as soon as it is not. The wait runs until the tunnel has been
  /// up for [ReviewPrompt.minSession] and the screen calm for
  /// [reviewSettle], whichever is later. Never throws.
  void _checkReview() {
    try {
      if (!mounted || _review == null || _review!.askedThisRun) return;
      final upSince = _reviewVpn?.currentConnection?.startTime;
      if (!_calmWith(_reviewVpn, _reviewFlow) || upSince == null) {
        _reviewTimer?.cancel();
        _reviewTimer = null;
        return;
      }
      if (_reviewTimer != null || upSince == _reviewRefusedFor) return;
      final untilLongEnough =
          ReviewPrompt.minSession - DateTime.now().difference(upSince);
      final wait = untilLongEnough > reviewSettle
          ? untilLongEnough
          : reviewSettle;
      _reviewTimer = Timer(wait, () => unawaited(_askForReview()));
    } catch (e) {
      debugPrint('HomeScreen: rating card check failed ($e)');
    }
  }

  /// Ask for the rating card if everything still allows it. The card is
  /// the least important thing that can pop up, so it gives way to all of
  /// them, and it never follows another popup in the same run.
  Future<void> _askForReview() async {
    _reviewTimer = null;
    try {
      final review = _review;
      final vpn = _reviewVpn;
      if (!mounted || review == null || vpn == null) return;
      if (!_reviewMayShow(vpn)) return;
      final enabled = context.read<AppConfigState>().flags.reviewPrompt;
      final upSince = vpn.currentConnection?.startTime;
      final due = await review.due(enabled: enabled, upSince: upSince);
      if (!due) {
        _reviewRefusedFor = upSince;
        return;
      }
      // The answer took a moment. Anything that changed meanwhile wins.
      if (!mounted || !_reviewMayShow(vpn)) return;
      // Never on the Tehran day the invite card showed.
      if (await _invite.prompt?.lastShownDay() ==
          ReviewPrompt.tehranDay(DateTime.now())) {
        return;
      }
      if (!mounted || !_reviewMayShow(vpn)) return;
      await review.ask();
    } catch (e) {
      debugPrint('HomeScreen: rating card failed ($e)');
    }
  }

  /// Whether the screen is in a state the rating card may appear in: calm,
  /// on top, no warning on screen, no popup shown or waiting in this run,
  /// no update pending, the allowance not spent, and not a team test phone.
  bool _reviewMayShow(VpnService vpn) => _cardMayShow(vpn, _reviewFlow);

  /// The rule [_reviewMayShow] states, for the rating card and the calm
  /// Premium card alike. Neither shows in a run the other showed in.
  bool _cardMayShow(VpnService vpn, ConnectFlow? flow) {
    // Play's rating card is made for phones. On a TV the Settings item,
    // which opens the store, is the way to rate.
    if (FormFactor.isTv) return false;
    if (!_calmWith(vpn, flow)) return false;
    if (_premiumPrompt?.shownThisRun ?? false) return false;
    if (_invite.prompt?.shownThisRun ?? false) return false;
    if (NoticePermissionPrompt.instance.askedThisRun) return false;
    if (vpn.errorMessage != null || vpn.privateDnsHost != null) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    if (UpdateDialog.isShowing || UpdateDialog.shownThisRun) return false;
    if (MessageDialog.isShowing) return false;
    final messages = _messages;
    if (messages != null &&
        (messages.poppedThisRun || messages.pendingPopup != null)) {
      return false;
    }
    if (context.read<DedicatedState>().isBlocked) return false;
    if (context.read<TestPointRunner?>()?.active ?? false) return false;
    final rules = context.read<AppConfigState>().versionRules?.android;
    if (rules != null &&
        UpdateCheck.decide(
              current: ApiConfig.appVersion,
              latest: rules.latestVersion,
              minimum: rules.minimumVersion,
              serverSaysRequired: rules.updateRequired,
            ) !=
            UpdateNeed.none) {
      return false;
    }
    return true;
  }

  /// Listen for the moment to show the calm Premium card. Read here, not in
  /// [build], for the same reasons as [_watchForMessages].
  void _watchForPremiumPrompt() {
    try {
      final prompt = context.read<PremiumPrompt?>();
      final billing = context.read<BillingState?>();
      if (prompt == null || billing == null) return;
      final vpn = context.read<VpnService>();
      final flow = context.read<ConnectFlow>();
      vpn.addListener(_checkPremiumPrompt);
      flow.addListener(_checkPremiumPrompt);
      billing.addListener(_checkPremiumPrompt);
      _premiumPrompt = prompt;
      _promptBilling = billing;
      _promptVpn = vpn;
      _promptFlow = flow;
      _checkPremiumPrompt();
    } catch (e) {
      debugPrint('HomeScreen: Premium card not watched ($e)');
    }
  }

  /// Start the wait for the calm Premium card while the screen is calm, and
  /// take the card away as soon as it is not. The wait is the rating
  /// card's, a little longer, so the rating card goes first when both are
  /// due. Never throws.
  void _checkPremiumPrompt() {
    try {
      final prompt = _premiumPrompt;
      if (!mounted || prompt == null) return;
      final vpn = _promptVpn;
      final offered = _promptBilling?.upsellOn(UpsellSurface.calmCard) ?? false;
      // A card up when the device got Premium (bought through another way
      // in), or when the offer was turned off or the phone's reading
      // changed, goes away at once.
      if (!offered && _calmCardUp) setState(() => _calmCardUp = false);
      if (!_calmWith(vpn, _promptFlow)) {
        _premiumTimer?.cancel();
        _premiumTimer = null;
        if (_calmCardUp) setState(() => _calmCardUp = false);
        return;
      }
      if (prompt.shownThisRun || _premiumTimer != null) return;
      if (!offered) return;
      final upSince = vpn?.currentConnection?.startTime;
      if (upSince == null || upSince == _premiumRefusedFor) return;
      final untilLongEnough =
          ReviewPrompt.minSession - DateTime.now().difference(upSince);
      final settle = reviewSettle + popupSettle;
      final wait = untilLongEnough > settle ? untilLongEnough : settle;
      _premiumTimer = Timer(wait, () => unawaited(_askPremiumPrompt()));
    } catch (e) {
      debugPrint('HomeScreen: Premium card check failed ($e)');
    }
  }

  /// Show the calm Premium card if everything still allows it.
  Future<void> _askPremiumPrompt() async {
    _premiumTimer = null;
    try {
      final prompt = _premiumPrompt;
      final vpn = _promptVpn;
      final billing = _promptBilling;
      if (!mounted || prompt == null || vpn == null || billing == null) return;
      if (_review?.askedThisRun ?? false) return;
      if (!_cardMayShow(vpn, _promptFlow)) return;
      final upSince = vpn.currentConnection?.startTime;
      if (!await prompt.due(billing)) {
        _premiumRefusedFor = upSince;
        return;
      }
      // The answer took a moment. Anything that changed meanwhile wins.
      if (!mounted || !_cardMayShow(vpn, _promptFlow)) return;
      if (_review?.askedThisRun ?? false) return;
      setState(() => _calmCardUp = true);
      billing.logUpsell(UpsellSurface.calmCard, UpsellAction.shown);
      await prompt.shown();
    } catch (e) {
      debugPrint('HomeScreen: Premium card failed ($e)');
    }
  }

  void _closeCalmCard({required bool buy}) {
    setState(() => _calmCardUp = false);
    _promptBilling?.logUpsell(
      UpsellSurface.calmCard,
      buy ? UpsellAction.tapped : UpsellAction.dismissed,
    );
    if (buy) PremiumScreen.open(context, source: PremiumSource.calmCard);
  }

  /// Listen for the allowance running out, to open the limit sheet once
  /// per refill. Read here, not in [build], for the same reasons as
  /// [_watchForMessages]. The connect and the tunnel are watched too, so a
  /// sheet a connect kept from opening opens once it ends.
  void _watchForLimitSheet() {
    try {
      final config = context.read<AppConfigState?>();
      if (config == null) return;
      final dedicated = context.read<DedicatedState>();
      final vpn = context.read<VpnService>();
      final flow = context.read<ConnectFlow>();
      config.addListener(_checkLimitSheet);
      dedicated.addListener(_checkLimitSheet);
      vpn.addListener(_checkLimitSheet);
      flow.addListener(_checkLimitSheet);
      _limitConfig = config;
      _limitDedicated = dedicated;
      _limitVpn = vpn;
      _limitFlow = flow;
      _checkLimitSheet();
    } catch (e) {
      debugPrint('HomeScreen: limit sheet not watched ($e)');
    }
  }

  /// Whether the limit sheet is switched on for this phone: by the app
  /// config (FeatureFlags.limitSheet), which is on unless the backend sends
  /// `limit_sheet: false`. It is the same for every phone, because the
  /// sheet offers nothing but the free ways to more data; its Premium row
  /// has its own gate (see showLimitSheet). Never on a TV, where nothing
  /// new may take a place in the remote's focus order.
  bool _limitSheetOn() =>
      !FormFactor.isTv && (_limitConfig?.flags.limitSheet ?? false);

  /// Whether the limit sheet is wanted now: it is switched on, the
  /// allowance is spent and says when it refills, and the app is in front.
  bool _limitSheetWanted() {
    final dedicated = _limitDedicated;
    if (!mounted || dedicated == null) return false;
    if (_limitSheetOpen) return false;
    if (!_limitSheetOn()) return false;
    if (!dedicated.isBlocked || dedicated.quota?.resetsAt == null) {
      return false;
    }
    return WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  /// Whether the limit sheet may open by itself now: it is wanted, this
  /// screen is on top with no dialog over it, and no connect is under way.
  bool _limitSheetMayOpen() {
    if (!_limitSheetWanted() || _starting) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    if (UpdateDialog.isShowing || MessageDialog.isShowing) return false;
    return !(_limitFlow?.isBusy ?? false);
  }

  /// Open the limit sheet by itself, after [popupSettle], once per refill.
  /// Never throws.
  void _checkLimitSheet() {
    try {
      // A blocked answer that lands just after a tap's search ended is
      // that tap's answer: the sheet opens at once, as it would have if
      // the answer had come in time.
      if ((_tapLate?.isActive ?? false) &&
          _tapEndedFor == _tap &&
          _tapSheetFor != _tap &&
          _limitDedicated?.isBlocked == true &&
          !(_limitVpn?.status.isActive ?? false) &&
          _limitSheetMayOpen()) {
        _tapSheetFor = _tap;
        _tapLate?.cancel();
        _tapLate = null;
        unawaited(_limitSheetAfterTap());
        return;
      }
      if (_limitTimer != null || !_limitSheetWanted()) return;
      _limitTimer = Timer(popupSettle, () => unawaited(_autoLimitSheet()));
    } catch (e) {
      debugPrint('HomeScreen: limit sheet check failed ($e)');
    }
  }

  /// The wait for the sheet is over: open it, unless this refill has had
  /// it already.
  ///
  /// When something else has the screen at that moment (a connect, another
  /// page, the update dialog, a message), it looks again after
  /// [popupSettle] for as long as the sheet is wanted. Until 2026-10-08 it
  /// gave up and waited for the allowance, the config or the payments to
  /// change, and on a quiet screen nothing did, so a sheet that met the
  /// update dialog at launch never opened.
  Future<void> _autoLimitSheet() async {
    _limitTimer = null;
    try {
      if (!_limitSheetWanted()) return;
      final resets = _limitDedicated?.quota?.resetsAt;
      if (resets == null) return;
      final refill = resets.toUtc().toIso8601String();
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_limitSheetKey) == refill) return;
      if (!_limitSheetMayOpen()) {
        _checkLimitSheet();
        return;
      }
      await prefs.setString(_limitSheetKey, refill);
      await _openLimitSheet();
    } catch (e) {
      debugPrint('HomeScreen: limit sheet failed ($e)');
    }
  }

  /// A tap on Connect found the allowance spent: say so, every time, and
  /// count this refill as shown so the sheet does not open again by
  /// itself for it.
  Future<void> _limitSheetAfterTap() async {
    try {
      final dedicated = context.read<DedicatedState>();
      if (!dedicated.isBlocked || !_limitSheetOn()) return;
      final resets = dedicated.quota?.resetsAt;
      if (resets != null) unawaited(_noteLimitSheetShown(resets));
      await _openLimitSheet();
    } catch (e) {
      debugPrint('HomeScreen: limit sheet failed ($e)');
    }
  }

  Future<void> _noteLimitSheetShown(DateTime resets) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_limitSheetKey, resets.toUtc().toIso8601String());
    } catch (e) {
      debugPrint('HomeScreen: limit sheet not noted ($e)');
    }
  }

  /// Note an invite event while the user shares diagnostics. Never throws.
  void _logInvite(InviteSurface surface, InviteAction action) {
    try {
      context.read<InviteEvents?>()?.log(surface, action);
    } catch (e) {
      debugPrint('HomeScreen: invite event not kept ($e)');
    }
  }

  Future<void> _openLimitSheet() async {
    if (_limitSheetOpen || !mounted) return;
    _limitTimer?.cancel();
    _limitTimer = null;
    _limitSheetOpen = true;
    _limitSheetShownThisRun = true;
    try {
      await showLimitSheet(context);
    } finally {
      _limitSheetOpen = false;
    }
  }

  /// Listen for the config, which turns the APN guide on and off and says
  /// which phones it is for. Read here, not in [build], for the same
  /// reasons as [_watchForMessages].
  void _watchForApnGuide() {
    try {
      final guide = context.read<ApnGuide?>();
      final config = context.read<AppConfigState?>();
      if (guide == null || config == null) return;
      config.addListener(_refreshApnGuide);
      _apnGuide = guide;
      _apnConfig = config;
    } catch (e) {
      debugPrint('HomeScreen: APN guide not watched ($e)');
    }
  }

  /// Have the APN guide read the phone again under the config's latest
  /// settings. Never throws.
  void _refreshApnGuide() {
    final guide = _apnGuide;
    if (!mounted || guide == null) return;
    unawaited(guide.refresh(_apnConfig?.apnGuide));
  }

  /// Measure any link an operator wants tested from this network.
  ///
  /// Last in the launch sequence and gated on the core being free, because
  /// it is the least important thing the app does and the native cores are
  /// shared: a probe started underneath a connect breaks both. Usually there
  /// is nothing to measure and this costs one request every six hours.
  /// Nothing here is ever connected through or shown to the user; see
  /// CandidateProber.
  void _measureCandidates() {
    final vpn = context.read<VpnService>();
    final flow = context.read<ConnectFlow>();
    final dedicated = context.read<DedicatedState>();
    final servers = context.read<ServerState>();
    _prober.maybeRun(
      idle:
          !vpn.isConnected &&
          !vpn.isConnecting &&
          !flow.isBusy &&
          !dedicated.isPingingAll &&
          !servers.isPingingAll,
    );
  }

  /// Re-read this device's servers and allowance. See [refreshAllowance].
  Future<void> _refreshQuota() => refreshAllowance(
    vpn: context.read<VpnService>(),
    dedicated: context.read<DedicatedState>(),
  );

  /// Measure the active server once per launch, so the card can show its
  /// health without the user having to ask for it.
  void _autoPingOnce(Server server) {
    if (_didAutoPing) return;
    _didAutoPing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (server.isDedicated) {
        final dedicated = context.read<DedicatedState>();
        if (dedicated.pingFor(server.id) == null) {
          dedicated.pingServer(server);
        }
      } else {
        final servers = context.read<ServerState>();
        if (servers.getPingResult(server.id) == null) {
          servers.pingServer(server);
        }
      }
    });
  }

  int? _latencyFor(
    Server? server,
    DedicatedState dedicated,
    ServerState servers,
  ) {
    if (server == null) return null;
    return server.isDedicated
        ? dedicated.pingFor(server.id)
        : servers.getPingResult(server.id);
  }

  /// What a tap on the button does.
  ///
  /// While any part of a connect is under way, or the tunnel is up, a tap
  /// is a stop. That covers the wait for this device's own servers, the
  /// checklist, the tunnel starting and its traffic being checked. Until
  /// 2026-10-07 a tap while the screen said "Checking connection" did
  /// nothing, and the user could only wait for the check to end.
  ///
  /// The one exception is a tap on the power button ([fromButton]) within
  /// [HomeScreen.doubleTapGuard] of the tap that started the connect. It is
  /// the second tap of a double tap, and the connect goes on. The error
  /// bar's offer of another server is not the button, and stops as before.
  ///
  /// While the tunnel is still coming down from a stop, a tap does
  /// nothing, so a quick second tap cannot start a connect over the
  /// teardown. Otherwise a tap connects.
  ///
  /// [trigger] says what started a connect, for its trace: the button
  /// ([TraceTrigger.tap]), or the error bar's offer ([TraceTrigger.pick]).
  void _toggle(
    VpnService vpn,
    ConnectFlow flow,
    Server? server, {
    bool fromButton = false,
    TraceTrigger trigger = TraceTrigger.tap,
  }) {
    if (_starting ||
        flow.isBusy ||
        vpn.isConnecting ||
        vpn.isVerifying ||
        vpn.status == VpnStatus.connected) {
      // The second tap of a double tap: the connect the first tap started
      // goes on. See HomeScreen.doubleTapGuard.
      if (fromButton && (_stopGuard?.isActive ?? false)) return;
      _stopGuard?.cancel();
      _cameBackByItself = false;
      _tap++;
      // A search the tap stops, not a tunnel it takes down: the status
      // line says so for a moment.
      final searching = _starting || flow.isBusy;
      _stoppedNote?.cancel();
      _stoppedNote = searching
          ? Timer(HomeScreen.stoppedNote, () {
              if (mounted) setState(() {});
            })
          : null;
      setState(() => _starting = false);
      unawaited(stopConnecting(vpn: vpn, flow: flow));
      return;
    }
    if (vpn.status == VpnStatus.disconnecting) return;
    _stoppedNote?.cancel();
    final dedicated = context.read<DedicatedState>();
    final servers = context.read<ServerState>();
    final tap = ++_tap;
    // Shared with the Connect button on the forced update dialog, so both
    // reach the tunnel the same way. See connectFromButton.
    Future<void> connect() => connectFromButton(
      server,
      vpn: vpn,
      flow: flow,
      dedicated: dedicated,
      servers: servers,
      stillWanted: () => mounted && tap == _tap,
      onWaitingForOwn: (waiting) {
        if (mounted && tap == _tap) setState(() => _waitingForOwn = waiting);
      },
      trigger: trigger,
    );
    if (server == null && dedicated.isBlocked) {
      // Over the allowance there is no server to dial, and the tap used to
      // do nothing anyone could see. It asks whether the data has refilled
      // since the last look, and the limit sheet says when it will, at
      // once and on every tap, without waiting for that answer.
      unawaited(connect());
      _tapSheetFor = tap;
      unawaited(_limitSheetAfterTap());
      return;
    }
    setState(() {
      _starting = true;
      _tapAt = DateTime.now();
      _waitingForOwn = false;
      _friendOfferClosed = false;
      _cameBackByItself = false;
    });
    _stopGuard?.cancel();
    _stopGuard = Timer(HomeScreen.doubleTapGuard, () {});
    unawaited(
      connect().whenComplete(() {
        if (!mounted || tap != _tap) return;
        unawaited(_checkNetwork());
        setState(() => _starting = false);
        if (dedicated.isBlocked && !vpn.status.isActive) {
          // The tap was made on an older reading of the allowance, and the
          // look before dialling found it spent: the same sheet.
          _tapSheetFor = tap;
          unawaited(_limitSheetAfterTap());
        } else {
          if (!vpn.status.isActive) {
            // The answer may still land: see HomeScreen.tapSheetLate.
            _tapEndedFor = tap;
            _tapLate?.cancel();
            _tapLate = Timer(HomeScreen.tapSheetLate, () => _tapLate = null);
          }
          // A sheet the connect kept from opening by itself may open now.
          _checkLimitSheet();
        }
      }),
    );
  }

  /// Open the list the active server came from: this device's own servers,
  /// or the shared list while that is what is in use. Over the allowance
  /// it is the device's own list, since that is where the refill time and
  /// the way to raise the limit live.
  /// Open the picker behind the server card.
  ///
  /// Keyed on whether this device has servers of its own, not on which
  /// server happens to be active. A user who has picked a community
  /// server still needs the screen that lists their own, and it is the
  /// only way back onto them; that screen carries the link on to the
  /// shared list, so nothing is unreachable from it.
  void _openServerList() {
    final dedicated = context.read<DedicatedState>();
    final useOwn = dedicated.hasServers || dedicated.isBlocked;
    Navigator.push(
      context,
      SlideUpFadeTransition(
        page: useOwn ? const MyServersScreen() : const ServerListScreen(),
      ),
    );
  }

  /// The error bar, saying what the diagnosis found and what to try.
  ///
  /// The plain message is the fallback, not the default. The app already
  /// runs a one second diagnosis on every failure and knew things like
  /// "TCP to this server timed out while the internet works" while
  /// telling the user "Server not working, try another".
  Widget _errorBar(
    S l10n,
    VpnService vpn,
    ConnectFlow flow,
    DedicatedState dedicated,
    ServerState servers,
  ) {
    final verdict = vpn.failureVerdict;
    final message = verdict == null
        ? vpn.errorMessage!
        : _verdictSentence(l10n, verdict);

    // The platform's own permission signal outranks the diagnosis: it is
    // set from the error the platform returned, not inferred from probes.
    final action = vpn.errorNeedsVpnSettings
        ? FailureAction.openVpnSettings
        : verdict == null
        ? FailureAction.none
        : actionFor(verdict);

    final alternative = _alternativeServer(dedicated, servers, flow);
    return _ErrorBar(
      message: message,
      onDismiss: vpn.clearError,
      details: vpn.lastDiagnosis,
      askSupport: true,
      actionLabel: switch (action) {
        FailureAction.openVpnSettings => l10n.openVpnSettings,
        FailureAction.checkInternet => l10n.diagCheckInternet,
        FailureAction.tryAnotherServer =>
          alternative == null
              ? null
              : l10n.diagTryServer(serverTitle(context, alternative)),
        FailureAction.none => null,
      },
      onAction: switch (action) {
        FailureAction.openVpnSettings => vpn.openVpnSettings,
        // Naming the problem is the whole of the advice here; there is no
        // screen in this app that fixes the phone's own connection.
        FailureAction.checkInternet => null,
        FailureAction.tryAnotherServer =>
          alternative == null
              ? null
              : () => _switchTo(alternative, vpn, dedicated, servers),
        FailureAction.none => null,
      },
    );
  }

  String _verdictSentence(S l10n, FailureVerdict verdict) => switch (verdict) {
    FailureVerdict.noInternet => l10n.diagVerdictNoInternet,
    FailureVerdict.cutOff => l10n.diagVerdictCutOff,
    FailureVerdict.needsPermission => l10n.diagVerdictNeedsPermission,
    FailureVerdict.serverUnreachable => l10n.diagVerdictServerUnreachable,
    FailureVerdict.blockedTls => l10n.diagVerdictBlockedTls,
    FailureVerdict.throttled => l10n.diagVerdictThrottled,
    // Nothing useful to say beyond what the platform already said.
    FailureVerdict.unknown => l10n.diagTryAnotherServer,
  };

  /// Whether to offer getting help from a friend's phone: this phone is not
  /// connected and cannot get anything newer by itself. The backend did not
  /// answer, and the last read of the fallback file's hosts found nothing
  /// ([Bootstrap.nothingFound]; a read starts only when a call to the
  /// backend fails). Shown once a tap has ended without a tunnel, or while
  /// there is no server at all to dial.
  bool _offerFriend(
    Bootstrap? bootstrap,
    VpnService vpn,
    ConnectFlow flow,
    Server? active,
  ) {
    if (bootstrap == null || !bootstrap.nothingFound) return false;
    // A TV has no camera, and seldom a friend's file to open.
    if (FormFactor.isTv || _noNetwork) return false;
    if (_friendOfferClosed || _starting) return false;
    if (vpn.status.isActive || vpn.isConnecting || vpn.isVerifying) {
      return false;
    }
    return active == null ||
        vpn.status == VpnStatus.error ||
        switch (flow.stage) {
          ConnectStage.noInternet ||
          // Only the way abroad is cut (#269): the hosts abroad are what
          // failed, and a friend's phone may have what they could not give.
          ConnectStage.cutOff ||
          ConnectStage.nothingOpen ||
          ConnectStage.failed ||
          ConnectStage.waiting => true,
          _ => false,
        };
  }

  /// A server to offer instead of the one that just failed.
  ///
  /// This device's own first, because they are the ones the allowance
  /// covers and the ones least likely to be blocked. Null when there is
  /// nothing else to offer, and the bar then names the problem without
  /// promising a fix.
  ///
  /// Never one whose paths the last search found closed
  /// ([ConnectFlow.foundClosed]). Until clients #342 the bar offered
  /// Nuremberg while the list above it showed every Nuremberg path
  /// blocked.
  Server? _alternativeServer(
    DedicatedState dedicated,
    ServerState servers,
    ConnectFlow flow,
  ) {
    final current = activeServer(dedicated, servers);
    bool other(Server s) => s.id != current?.id && !flow.foundClosed(s);
    if (!dedicated.isBlocked) {
      final own = dedicated.servers.where(other).firstOrNull;
      if (own != null) return own;
    }
    return servers.officialServers.where(other).firstOrNull ??
        servers.communityServers.where(other).firstOrNull;
  }

  /// Move to [server] and dial it, which is what the user asked for by
  /// tapping an offer to try it. The offer says it starts a new search.
  void _switchTo(
    Server server,
    VpnService vpn,
    DedicatedState dedicated,
    ServerState servers,
  ) {
    // A server pick, the same click the lists give one.
    AppHaptics.selection();
    vpn.clearError();
    if (server.isDedicated) {
      servers.clearChoice();
      // The user tapped an offer that names this server, so it is a pick.
      dedicated.select(server);
    } else {
      servers.selectServer(server);
    }
    final flow = context.read<ConnectFlow>();
    // The wait for the next try belongs to the search the offer replaces.
    // Left running, the tap below would read as a stop.
    if (flow.stage == ConnectStage.waiting) flow.cancel();
    _toggle(vpn, flow, server, trigger: TraceTrigger.pick);
  }

  /// One short line describing the current state, in plain words.
  ///
  /// [stopped] while a tap that stopped a search is fresh
  /// ([HomeScreen.stoppedNote]). [community] when the card names a
  /// community server.
  String _statusLabel(
    S l10n,
    VpnService vpn,
    ConnectFlow flow, {
    required bool hasServer,
    required bool blocked,
    required bool starting,
    bool stopped = false,
    bool community = false,
  }) {
    // The tap stopped a search: said for a moment, while the tunnel comes
    // down and after, rather than "Disconnecting" or "Tap to connect".
    if (stopped &&
        !starting &&
        !flow.isBusy &&
        !vpn.isConnecting &&
        vpn.status != VpnStatus.connected) {
      return l10n.searchStopped;
    }
    // The stage of the search while it runs: what the app tries now, also
    // while the tunnel through it is checked, which is not yet a working
    // connection. Not for the search after a dead tunnel, which says why
    // it looks.
    final stageLine = flow.afterStall ? null : _stageLine(l10n, flow);
    if (stageLine != null) return stageLine;
    if (vpn.isVerifying) return l10n.homeChecking;
    // Nothing else connected, and the app dials the backup network by
    // itself (ConnectFlow.tryingBackup), after a tap or a dead tunnel.
    if (flow.tryingBackup) return l10n.homeTryingBackup;
    // Looking without a tap, because the tunnel stopped carrying data.
    if (flow.afterStall) return l10n.homeStallSearching;
    switch (flow.stage) {
      case ConnectStage.diagnosing:
        return l10n.homeFindingPath;
      case ConnectStage.noInternet:
        return l10n.diagNoInternet;
      case ConnectStage.cutOff:
        return l10n.diagCutOff;
      case ConnectStage.nothingOpen:
        return l10n.diagNothingOpen;
      case ConnectStage.waiting:
        // Why it waits: the last try's end.
        return switch (flow.waitingAfter) {
          ConnectStage.cutOff => l10n.homeCutOffTryingAgain,
          ConnectStage.noInternet => l10n.homeOfflineTryingAgain,
          _ => l10n.homeTryingAgain,
        };
      case ConnectStage.failed:
        if (vpn.status != VpnStatus.connected) return l10n.diagPathFailed;
      default:
        break;
    }
    // A tap's connect before the tunnel has a state of its own, or between
    // two doors. The button's light is sweeping, so the line must not say
    // "Tap to connect", or name the failure of a door the flow has moved
    // on from.
    if (starting && !vpn.status.isActive) return l10n.statusConnecting;
    switch (vpn.status) {
      case VpnStatus.connected:
        // Up, and found carrying nothing (VpnService.stalled).
        if (vpn.stalled) return l10n.homeStalled;
        // Up, and a check through it failed already: it may be dead or
        // throttled, so it is not called connected until the check ends.
        if (vpn.checkingTunnel) return l10n.homeChecking;
        // The kind of route that connected, past our own servers.
        if (vpn.onPsiphon) return l10n.homeConnectedBackup;
        return community ? l10n.homeConnectedCommunity : l10n.statusConnected;
      case VpnStatus.connecting:
        return l10n.statusConnecting;
      case VpnStatus.disconnecting:
        return l10n.homeDisconnecting;
      case VpnStatus.error:
        return l10n.errorConnectionFailed;
      case VpnStatus.disconnected:
        if (blocked) return l10n.quotaUsedUp;
        return hasServer ? l10n.homeTapToConnect : l10n.homePreparing;
    }
  }

  /// What the search tries now, while it runs: one line per stage
  /// (clients #342). Null when no stage runs.
  static String? _stageLine(S l10n, ConnectFlow flow) => switch (flow.route) {
    RouteKind.own => l10n.stageTryingOwn,
    RouteKind.community =>
      flow.stageState(RouteKind.own) == StageState.failed
          ? l10n.stageOwnFailedTryingCommunity
          : l10n.stageTryingCommunity,
    RouteKind.backup => l10n.homeTryingBackup,
    null => null,
  };

  /// Whether [status] is one of [_statusLabel]'s sentences: what went wrong
  /// and what happens or what to do next, rather than a state in a few
  /// words. The status line draws those a step smaller.
  static bool _isSentence(S l10n, String status) => {
    l10n.homeTryingBackup,
    l10n.stageOwnFailedTryingCommunity,
    l10n.homeStallSearching,
    l10n.diagNoInternet,
    l10n.diagCutOff,
    l10n.diagNothingOpen,
    l10n.homeCutOffTryingAgain,
    l10n.homeOfflineTryingAgain,
    l10n.homeTryingAgain,
    l10n.diagPathFailed,
  }.contains(status);

  /// What the power button and the light behind it show, worked out from
  /// the same signals and in the same order as [_statusLabel], so the
  /// button and the words under it never disagree.
  ///
  /// One difference: while any part of a connect runs, the face is busy
  /// even where the line still names the last door's failure, because the
  /// button's light sweeps then (its status is connecting).
  PowerFace _powerFace(
    VpnService vpn,
    ConnectFlow flow, {
    required bool blocked,
    required bool starting,
  }) {
    if (vpn.isVerifying) return PowerFace.verifying;
    if (flow.tryingBackup || flow.afterStall) return PowerFace.connecting;
    switch (flow.stage) {
      case ConnectStage.diagnosing:
      case ConnectStage.waiting:
        return PowerFace.connecting;
      case ConnectStage.noInternet:
      case ConnectStage.cutOff:
      case ConnectStage.nothingOpen:
        return PowerFace.failed;
      case ConnectStage.failed:
        if (vpn.status != VpnStatus.connected) return PowerFace.failed;
      default:
        break;
    }
    if ((starting || flow.isBusy) && !vpn.status.isActive) {
      return PowerFace.connecting;
    }
    switch (vpn.status) {
      case VpnStatus.connected:
        if (vpn.stalled) return PowerFace.stalled;
        return vpn.checkingTunnel ? PowerFace.verifying : PowerFace.connected;
      case VpnStatus.connecting:
        return PowerFace.connecting;
      case VpnStatus.disconnecting:
        return PowerFace.disconnecting;
      case VpnStatus.error:
        return PowerFace.failed;
      case VpnStatus.disconnected:
        return blocked ? PowerFace.spent : PowerFace.off;
    }
  }

  /// Whether a connect that lands now gets the power button's success
  /// moment: only one the user started, in front of them. Not on the first
  /// frame after the app opened or came back, and not for a connection
  /// that came back by itself.
  ///
  /// Called once per build. It writes only the latch, and gives the same
  /// answer and the same latch for the same flow and face, so a second
  /// build of the same frame changes nothing.
  bool _celebrate(ConnectFlow flow, PowerFace face, {bool checking = false}) {
    // A tunnel that a stall check passed, or that the app replaced after a
    // stall, came back without a tap.
    if (flow.afterStall || checking) _cameBackByItself = true;
    final celebrate = !_justOpened && !_cameBackByItself;
    // That connect has ended, one way or the other.
    if (face != PowerFace.connecting && face != PowerFace.verifying) {
      _cameBackByItself = false;
    }
    return celebrate;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final vpn = context.watch<VpnService>();
    final flow = context.watch<ConnectFlow>();
    final serverState = context.watch<ServerState>();
    final dedicated = context.watch<DedicatedState>();

    final active = activeServer(dedicated, serverState);
    final latency = _latencyFor(active, dedicated, serverState);
    final isConnected = vpn.status == VpnStatus.connected && !vpn.isVerifying;
    // Null in tests of the screen built without payments.
    final billing = context.watch<BillingState?>();
    // Null in tests of the screen built without it.
    final bootstrap = context.watch<Bootstrap?>();
    final apnGuide = context.watch<ApnGuide?>();

    if (active != null) _autoPingOnce(active);

    // No offer while a connect is under way, on an error or the checklist,
    // or with no internet.
    final offerCalm =
        !_starting &&
        !flow.isBusy &&
        !flow.showChecklist &&
        flow.stage != ConnectStage.noInternet &&
        flow.stage != ConnectStage.cutOff &&
        flow.stage != ConnectStage.nothingOpen &&
        flow.stage != ConnectStage.failed &&
        !vpn.isConnecting &&
        !vpn.isVerifying &&
        vpn.errorMessage == null &&
        vpn.status != VpnStatus.disconnecting &&
        vpn.status != VpnStatus.error;
    bool offer(UpsellSurface s) => offerCalm && (billing?.upsellOn(s) ?? false);

    final topBar = _TopBar(
      chip: PremiumTopChip(calm: offerCalm),
      onSettings: () => Navigator.push(
        context,
        SlideUpFadeTransition(page: const SettingsScreen()),
      ),
    );

    final status = _statusLabel(
      l10n,
      vpn,
      flow,
      hasServer: active != null,
      blocked: dedicated.isBlocked,
      starting: _starting,
      stopped: _stoppedNote?.isActive ?? false,
      community: active?.isCommunity ?? false,
    );
    final face = _powerFace(
      vpn,
      flow,
      blocked: dedicated.isBlocked,
      starting: _starting,
    );

    final button = <Widget>[
      PowerButton(
        focusNode: _powerFocus,
        // The checklist is part of connecting, so the button animates
        // through it rather than sitting idle while the rows fill in.
        status: (flow.isBusy || _starting) && !vpn.status.isActive
            ? VpnStatus.connecting
            : vpn.status,
        isVerifying: vpn.isVerifying,
        face: face,
        celebrate: _celebrate(flow, face, checking: vpn.checkingTunnel),
        // A screen reader on the button hears what the line under it says,
        // and during a search that a tap stops it.
        semanticLabel: status,
        semanticHint: (flow.searchRunning || _starting) && !isConnected
            ? l10n.searchSlowHint
            : null,
        onTap: () => _toggle(vpn, flow, active, fromButton: true),
      ),
      const SizedBox(height: AppDesign.space24),
      _StatusLine(
        label: status,
        sentence: _isSentence(l10n, status),
        // Elapsed time only once connected: a timer counting nothing is
        // noise.
        timer: isConnected && vpn.currentConnection != null
            ? ElapsedTime(startTime: vpn.currentConnection!.startTime)
            : null,
        // While a search runs, a second line once it has run a while. A
        // tap's first try counts from the tap, so the wait for this
        // device's servers before it counts too.
        searchSince: isConnected
            ? null
            : _starting
            ? _tapAt
            : flow.searchStarted,
      ),
    ];

    // The stages of the search, from the first second of a tap, the wait
    // for this device's servers included.
    final gettingServers = _starting && _waitingForOwn && !flow.showStages;
    final checklist = (flow.showStages || gettingServers) && !isConnected
        ? PathChecklist(flow: flow, gettingServers: gettingServers)
        : null;

    final notices = <Widget>[
      // Not while the search runs: a later route, or a later stage, may
      // still connect, and the bar would name a failure the app has moved
      // on from. On 2026-10-23 it offered Nuremberg 30 seconds into a tap
      // that connected through a community server at 47 seconds.
      if (vpn.errorMessage != null && !flow.searchRunning && !_starting)
        _errorBar(l10n, vpn, flow, dedicated, serverState),

      // Every other place to get what the app needs has failed. A friend's
      // phone standing next to this one is the place left.
      if (_offerFriend(bootstrap, vpn, flow, active))
        _ErrorBar(
          tone: _Tone.info,
          icon: Icons.phonelink_ring_outlined,
          message: l10n.peerOfferBody,
          actionLabel: l10n.peerReceiveTitle,
          onAction: () => PeerReceiveScreen.open(context),
          onDismiss: () => setState(() => _friendOfferClosed = true),
        ),

      // Connected, but the phone asks its own DNS provider instead of the
      // tunnel, so filtered sites fail with "DNS address could not be
      // found" while everything else works.
      if (isConnected &&
          vpn.privateDnsHost != null &&
          vpn.privateDnsHost != _privateDnsDismissed)
        _ErrorBar(
          tone: _Tone.warning,
          icon: Icons.dns_outlined,
          message: l10n.privateDnsWarning(vpn.privateDnsHost!),
          actionLabel: l10n.openNetworkSettings,
          onAction: vpn.openNetworkSettings,
          onDismiss: () =>
              setState(() => _privateDnsDismissed = vpn.privateDnsHost),
        ),

      // How to give this SIM IPv6, on the phones and carriers the backend
      // names, and never while a connect is under way. See ApnGuide.
      if (apnGuide != null &&
          apnGuide.shows(
            connecting:
                _starting ||
                flow.isBusy ||
                vpn.isConnecting ||
                vpn.isVerifying ||
                vpn.awaitingPermission,
          ))
        ApnGuideCard(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          onShowMe: () => unawaited(
            showApnGuideSheet(
              context,
              apn: apnGuide.apn,
              openSettings: apnGuide.openApnSettings,
            ),
          ),
          onNotNow: () => unawaited(apnGuide.dismiss()),
        ),

      // One quiet offer after a working connection, when nothing else is
      // on screen. See PremiumPrompt. Drawn only while the offer is still
      // on, so a device that got Premium meanwhile never sees it.
      if (_calmCardUp && isConnected && offer(UpsellSurface.calmCard))
        PremiumOfferCard(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          title: l10n.premiumCalmTitle,
          body: l10n.premiumCalmBody,
          onGetUnlimited: () => _closeCalmCard(buy: true),
          onNotNow: () => _closeCalmCard(buy: false),
        ),

      // Send Fortiva to a friend, after good days. See _HomeInviteCard.
      if (_invite.up && isConnected) _invite.card(),
    ];

    // While the tunnel goes through the backup network, the card says so,
    // rather than naming the selection, which carries nothing. A tap on it
    // still opens the list, and a pick there dials as any pick does.
    final onBackup = vpn.onPsiphon && !dedicated.isBlocked;
    final serverCard = _ServerCard(
      server: onBackup ? Server.psiphon : active,
      backupRegion: onBackup ? vpn.psiphonRegion : null,
      ping: onBackup ? null : latency,
      // The tunnel is up and checked through what the card names, and
      // carrying data: on the backup network the card names that. A
      // stalled tunnel stays calm, as the button turns to its warning.
      connected: isConnected && !vpn.stalled && !dedicated.isBlocked,
      blockedQuota: dedicated.isBlocked ? dedicated.quota : null,
      onTap: _openServerList,
      onGetUnlimited: dedicated.isBlocked && offer(UpsellSurface.serverCard)
          ? () {
              billing?.logUpsell(UpsellSurface.serverCard, UpsellAction.tapped);
              PremiumScreen.open(context, source: PremiumSource.serverCard);
            }
          : null,
      // Invites, the free way to more data, one tap from the spent card:
      // the link opens the limit sheet, which shares from where it is.
      onInvite:
          dedicated.isBlocked &&
              (context.watch<AppConfigState?>()?.referralsEnabled ?? false) &&
              !FormFactor.isTv &&
              _limitSheetOn() &&
              !(context.watch<ReferralState?>()?.invitesAddNoMore ?? false)
          ? () {
              _logInvite(InviteSurface.serverCard, InviteAction.shown);
              unawaited(_openLimitSheet());
            }
          : null,
    );

    final nudge = billing?.upsell?.nudgeUsedPercent;
    final quota = dedicated.quota;
    final nearLimit =
        nudge != null &&
        quota != null &&
        !quota.unlimited &&
        quota.limitBytes > 0 &&
        quota.usedBytes * 100 >= quota.limitBytes * nudge;

    // Invites, the free way to more data, offered before the data runs out:
    // the limit sheet offers them only once it has, and that is too late
    // for the same day, because an invite pays only once the friend has
    // used the VPN on more than one day. The share is the backend's
    // (AppConfigState.inviteNudgePercent), and there is no link without
    // it. Never for an unmetered or Premium device, on a TV, while a
    // connect is under way or an error is on screen, once invites can add
    // no more data, or once the data is spent (the limit sheet's turn).
    final invitePercent = context.watch<AppConfigState?>()?.inviteNudgePercent;
    final invitesSpent =
        context.watch<ReferralState?>()?.invitesAddNoMore ?? false;
    final inviteNudge =
        invitePercent != null &&
        offerCalm &&
        !FormFactor.isTv &&
        !invitesSpent &&
        !(billing?.premium.active ?? false) &&
        quota != null &&
        !quota.unlimited &&
        !quota.blocked &&
        quota.limitBytes > 0 &&
        quota.usedBytes * 100 >= quota.limitBytes * invitePercent;
    final premiumNudge = nearLimit && offer(UpsellSurface.quotaLine);
    // With both, the data line takes a row more (_QuotaLine), which on a
    // short phone pushed the power button out of sight.
    final twoLinks = inviteNudge && premiumNudge && !dedicated.isBlocked;

    final footer = <Widget>[
      // Not beside the invite card, which needs the room, nor beside the
      // data line's two links. The invite link opens the invite screen,
      // which has "Have an invite code?" too.
      if (!_invite.up && !twoLinks) const _HaveCodeRow(),
      // Over the allowance the status line and the card already say so; a
      // third mention would be nagging.
      if (!dedicated.isBlocked)
        _QuotaLine(
          key: const Key('quota-line'),
          quota: quota,
          onGetUnlimited: premiumNudge
              ? () {
                  billing?.logUpsell(
                    UpsellSurface.quotaLine,
                    UpsellAction.tapped,
                  );
                  PremiumScreen.open(context, source: PremiumSource.quotaLine);
                }
              : null,
          onInvite: inviteNudge
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ReadableWidth(
                      child: InviteScreen(entry: InviteEntry.quotaLine),
                    ),
                  ),
                )
              : null,
        ),
      RenewalCard(key: const ValueKey('renewal'), calm: offerCalm),
      const _Shortcuts(),
      const _TestPointLine(),
    ];

    return Scaffold(
      backgroundColor: AppDesign.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) =>
              FormFactor.isWide(constraints.biggest)
              ? _wide(
                  topBar,
                  face,
                  button,
                  checklist,
                  notices,
                  serverCard,
                  footer,
                )
              : _narrow(
                  topBar,
                  face,
                  button,
                  checklist,
                  notices,
                  serverCard,
                  footer,
                ),
        ),
      ),
    );
  }

  /// A phone held upright: one column, the button on top.
  Widget _narrow(
    Widget topBar,
    PowerFace face,
    List<Widget> button,
    Widget? checklist,
    List<Widget> notices,
    Widget serverCard,
    List<Widget> footer,
  ) {
    return Column(
      children: [
        topBar,

        // The button owns the screen. Everything else is a footnote.
        //
        // Centred when it fits and scrolled when it does not. What sits
        // above the button varies a lot in height: the checklist grows a
        // row per door, and the error bar below grows with the sentence in
        // it, which on a short phone in a wordier language left the button
        // overflowing off the bottom.
        //
        // The chatbot button sits in the bottom end corner of this area,
        // just above the server card and anything over it, and never on
        // top of the power button or the lines under it. See
        // CornerButtonLayout.
        //
        // The light behind it follows the button's state and leaves the
        // layout as it is.
        Expanded(
          child: StateWash(
            face: face,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: CornerButtonLayout(
                    besideWidth: PowerButton.defaultSize,
                    // The view cuts what it scrolls, so on a short phone a
                    // button pressed to its top edge lost the top of its
                    // glow.
                    topRoom: _glowRoom,
                    // Draws nothing until the backend says the chat is on,
                    // and rebuilds on its own.
                    button: const ChatbotButton(),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [...button, ?checklist],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        ...notices,
        serverCard,
        ...footer,
        const SizedBox(height: 16),
      ],
    );
  }

  /// How far the halo round the power button's shield reaches past the
  /// top of the button (its picture ends about 19 above it), kept clear
  /// above it so the scroll view does not cut it.
  static const double _glowRoom = 20;

  /// Above the power button on a wide screen, where there is height to
  /// spare: room for the halo and the wave of light that grows out of the
  /// shield when the tunnel comes up (about 40 above the button at its
  /// widest). Below it the status line is in the column, and at the sides
  /// the view is as wide as its half, so the wave needs room only at the
  /// top.
  static const double _heroRoom = 40;

  /// Where the button sits in its half on a wide screen, for the light
  /// behind it: the column is centred, and the button is its top part, so
  /// on a 960x540 TV its centre is about a tenth of the half's height above
  /// the middle. The phone's hero box puts it higher (StateWash.center).
  static const Alignment _wideWashCenter = Alignment(0, -0.2);

  /// A TV, or any screen wider than it is tall: the button on one side,
  /// everything about the connection on the other. A TV is 540 pixels
  /// high, and the phone's column of button, card and warnings does not
  /// fit in that. Side by side, a remote's left and right also move
  /// between the button and the server card.
  Widget _wide(
    Widget topBar,
    PowerFace face,
    List<Widget> button,
    Widget? checklist,
    List<Widget> notices,
    Widget serverCard,
    List<Widget> footer,
  ) {
    return Column(
      children: [
        topBar,
        Expanded(
          child: Row(
            children: [
              // The light behind the button fills its whole half, out to
              // the screen's edges, so the box does not cut it short.
              Expanded(
                child: StateWash(
                  face: face,
                  alignment: _wideWashCenter,
                  child: Padding(
                    // Clear of the edges, which some TVs still crop.
                    padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 0, 24),
                    // The view is as wide and as tall as its half, and the
                    // column keeps room above the button while the view
                    // has it to spare, so the view does not cut its glow or
                    // its ring. With less to spare the column moves up by
                    // what there is and never past the view's bottom: a
                    // fixed 40 above and below pushed the status line out
                    // of a short window, such as a tablet in split screen.
                    // The layout's corner button draws nothing here; the
                    // chatbot button is at the end of the other column.
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                            minHeight: constraints.maxHeight,
                          ),
                          child: CornerButtonLayout(
                            besideWidth: PowerButton.defaultSize,
                            topRoom: _heroRoom,
                            button: const SizedBox.shrink(),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: button,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(0, 8, 24, 24),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (checklist != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: checklist,
                            ),
                          ...notices,
                          serverCard,
                          ...footer,
                          const Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                              20,
                              16,
                              20,
                              0,
                            ),
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: ChatbotButton(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The line under the power button that says what is going on, and the
/// timer under it once the tunnel is up.
///
/// Both stop growing at [maxTextScale]: past that, a sentence in a large
/// font pushes the power button off a phone's screen. The rest of the
/// screen follows the phone's text size as it is. The timer slot is as
/// tall as the timer's own line at that size, so the line does not jump
/// when the timer appears.
///
/// A long sentence wraps at [measure], a little wider than the power
/// button, and is as wide as its longest line. A block that narrow reads
/// as one piece with the button, and it leaves the chatbot button room
/// beside it (CornerButtonLayout), where a full width line would push that
/// button under the column, out of view on a small phone. Nothing is cut
/// off: the failure sentences say what to do, so every line shows.
///
/// A state in a few words is a title. A [sentence] (what went wrong and
/// what to do) is body text, a step smaller and not bold, so a long one is
/// about half as tall and does not compete with the button above it.
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.label,
    required this.timer,
    this.sentence = false,
    this.searchSince,
  });

  final String label;
  final bool sentence;

  /// Null draws an empty slot of the same height.
  final Widget? timer;

  /// When the search under way started, while one runs. Past
  /// [HomeScreen.slowSearchHint] a second line says it can take a while
  /// and that the button stops it ([_SearchHint]).
  final DateTime? searchSince;

  static const double maxTextScale = 1.3;

  /// The widest the line may be.
  static const double measure = PowerButton.defaultSize + 40;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxTextScale,
      child: Builder(
        builder: (context) {
          // The style ElapsedTime draws in.
          final timerStyle = ElapsedTime.style;
          final timerHeight =
              MediaQuery.textScalerOf(
                context,
              ).scale(timerStyle.fontSize ?? 14) *
              (timerStyle.height ?? 1.2);
          final since = searchSince;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: measure),
                // Polite: a screen reader says the new words when the line
                // changes, and only then.
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    textWidthBasis: TextWidthBasis.longestLine,
                    style:
                        (sentence
                                ? AppDesign.textTheme.bodyLarge
                                : AppDesign.textTheme.titleLarge)
                            ?.copyWith(color: AppDesign.textPrimary),
                  ),
                ),
              ),
              const SizedBox(height: AppDesign.space8),
              if (timer == null && since != null)
                _SearchHint(since: since, minHeight: timerHeight)
              else
                SizedBox(height: timerHeight, child: timer),
            ],
          );
        },
      ),
    );
  }
}

/// The second line under the status while a search runs: once it has run
/// for [HomeScreen.slowSearchHint], it says the search can take a minute
/// or two and that a tap on the button stops it. Until then an empty slot
/// of [minHeight], so the line under the status does not jump.
///
/// It stays for the rest of the search. A new search ([since] changes)
/// starts the wait again.
class _SearchHint extends StatefulWidget {
  const _SearchHint({required this.since, required this.minHeight});

  final DateTime since;
  final double minHeight;

  @override
  State<_SearchHint> createState() => _SearchHintState();
}

class _SearchHintState extends State<_SearchHint> {
  Timer? _wait;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(_SearchHint old) {
    super.didUpdateWidget(old);
    if (old.since != widget.since) _arm();
  }

  void _arm() {
    _wait?.cancel();
    final left =
        HomeScreen.slowSearchHint - DateTime.now().difference(widget.since);
    _shown = left <= Duration.zero;
    _wait = _shown
        ? null
        : Timer(left, () {
            if (mounted) setState(() => _shown = true);
          });
  }

  @override
  void dispose() {
    _wait?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shown) return SizedBox(height: widget.minHeight);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: _StatusLine.measure,
        minHeight: widget.minHeight,
      ),
      child: Semantics(
        liveRegion: true,
        child: Text(
          S.of(context)!.searchSlowHint,
          key: const ValueKey('search hint'),
          textAlign: TextAlign.center,
          textWidthBasis: TextWidthBasis.longestLine,
          style: AppDesign.textTheme.bodySmall?.copyWith(
            color: AppDesign.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// The Premium chip at the start and the settings button at the end.
///
/// No mark and no wordmark. The power button under the bar is the shield
/// itself, and a small one up here only repeated it, so it went when the
/// button became the shield (2026-10-24). A heading would compete with the
/// button for no gain.
///
/// [chip] is the Premium pill, which draws nothing unless Premium is on or
/// offered. It starts 20dp from the screen's side, on the edge of the
/// server card, and the glyph of the last button sits about as far from
/// the other side: the glyph keeps a little clear space inside its box, so
/// the box sits closer to the side than that.
///
/// The bar is [height] tall whatever is in it, so a taller chip or a larger
/// font never takes room from the power button.
class _TopBar extends StatelessWidget {
  final VoidCallback onSettings;
  final Widget chip;

  const _TopBar({required this.onSettings, required this.chip});

  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return SizedBox(
      height: height,
      child: Padding(
        // At the start, the chip's pill on the server card's 20dp edge. At
        // the end, a 48dp button leaves 12dp around its 24dp glyph, and the
        // glyph has its own clear space too.
        padding: const EdgeInsetsDirectional.only(
          start: AppDesign.space20,
          end: AppDesign.space4,
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: AppDesign.space4,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: chip,
                ),
              ),
            ),
            // Sits in the header, not only in Settings. Someone who opens
            // the app in a language they cannot read must be able to fix
            // that from the first screen rather than navigate through it.
            LanguageButton(localeState: context.watch<LocaleState>()),
            // The pill fills its tap target from side to side, while the
            // icon buttons keep 12dp around their glyphs. Without this the
            // pill sat half as far from the bell as the bell from Settings.
            const SizedBox(width: AppDesign.space8),
            const MessageBell(),
            IconButton(
              onPressed: onSettings,
              tooltip: l10n.settings,
              iconSize: 24,
              icon: const Icon(
                Icons.tune_rounded,
                color: AppDesign.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The server this device is about to use, and the way to change it.
///
/// The heading and the caption are the point of the card. A dedicated
/// server looks identical to a shared one from the outside: same
/// protocol, same location list. If the screen does not say which one
/// is in use and what that means, the distinction may as well not exist.
///
/// It is calm on purpose: a tonal card with a hairline edge, the same while
/// idle and connecting. Only a working tunnel through it turns the edge and
/// the heading protected, and only a spent allowance turns them red, each
/// with words that say so.
class _ServerCard extends StatelessWidget {
  final Server? server;
  final int? ping;

  /// The tunnel is up and checked through the server the card names, and
  /// is not stalled.
  final bool connected;

  /// Set while the allowance is spent. The card then stands in for the
  /// server it cannot offer: it names the limit and when it refills, and
  /// leads to the screen where the limit can be raised.
  final QuotaStatus? blockedQuota;
  final VoidCallback onTap;

  /// Opens the Premium screen from the spent card. Null hides the button.
  final VoidCallback? onGetUnlimited;

  /// Opens the limit sheet from the spent card, beside the reset time.
  /// Null hides the link.
  final VoidCallback? onInvite;

  /// On the backup network, the region its traffic leaves from once the
  /// tunnel has said, as two capital letters.
  final String? backupRegion;

  const _ServerCard({
    required this.server,
    required this.ping,
    required this.connected,
    required this.onTap,
    this.blockedQuota,
    this.onGetUnlimited,
    this.onInvite,
    this.backupRegion,
  });

  bool get _blocked => blockedQuota != null;

  bool get _isCommunity => server?.isCommunity ?? false;

  bool get _isBackup => server?.isPsiphon ?? false;

  /// Before provisioning lands there is nothing to call shared: what is
  /// being set up is this device's own server. The same holds over the
  /// allowance, which is a property of this device's server.
  bool get _isOwn => server?.isDedicated ?? true;

  /// The country [backupRegion] names, when the app knows its name.
  String? get _backupCountry {
    final region = backupRegion;
    if (region == null) return null;
    final name = Server.countryName(region);
    return name == region ? null : name;
  }

  /// Which of the kinds of server this is, since from the outside they look
  /// the same: ours, a community link, this device's own, or the backup
  /// network.
  String _heading(S l10n) {
    if (_isBackup) return l10n.backupNetwork;
    if (_isOwn) return l10n.yourServer;
    return _isCommunity ? l10n.communityServer : l10n.ourServer;
  }

  IconData get _headingIcon {
    if (_isOwn) return Icons.verified_user_rounded;
    if (_isBackup) return Icons.alt_route_rounded;
    return _isCommunity ? Icons.people_outline : Icons.public_rounded;
  }

  String _place(BuildContext context, S l10n) {
    if (_blocked) return l10n.quotaLimitReached;
    final s = server;
    if (s == null) return l10n.homePreparing;
    if (_isBackup) return _backupCountry ?? l10n.backupNetworkPlace;
    final city = s.city.trim();
    final country = s.country.trim();
    if (city.isNotEmpty && country.isNotEmpty) return '$city, $country';
    if (country.isNotEmpty) return country;
    if (city.isNotEmpty) return city;
    return serverTitle(context, s);
  }

  String _caption(S l10n) {
    final quota = blockedQuota;
    if (quota != null) {
      final refill = QuotaCard.resetLabel(l10n, quota);
      return refill.isEmpty ? l10n.myServersBlockedWait : refill;
    }
    if (_isBackup) return l10n.backupNetworkCaption;
    if (_isOwn) return l10n.yourServerCaption;
    return _isCommunity ? l10n.communityServerCaption : l10n.ourServerCaption;
  }

  /// The flag on the card: on the backup network, its country's once the
  /// app knows the country. Empty while there is no country. FlagDisc
  /// draws its steel globe for that, and for the globe a server with no
  /// country stores, as History does, rather than a full-color picture.
  String get _flag {
    if (_isBackup) {
      final region = backupRegion;
      return region != null && _backupCountry != null
          ? Server.flagFor(region)
          : '';
    }
    return server?.flagEmoji ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final up = connected && !_blocked;
    final accent = _blocked
        ? AppDesign.error
        : up
        ? AppDesign.protected
        : AppDesign.textTertiary;
    final edge = _blocked
        ? AppDesign.error.withValues(alpha: 0.35)
        : up
        ? AppDesign.protected.withValues(alpha: 0.35)
        : AppDesign.hairline;
    final ping = this.ping;
    final text = AppDesign.textTheme;
    // The right to left type scale has taller lines (titleMedium 1.6,
    // bodySmall 1.65), and their leading already holds the air the gaps
    // below give a Latin card: with no gap, the place and the caption sit
    // as far apart as in English. The card is part of the home screen's
    // height budget (invite_layout tests), so the gaps go there.
    final tallLines = AppDesign.isRtlLocale(AppDesign.activeLocale);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDesign.space20),
      child: Pressable(
        onTap: onTap,
        borderRadius: AppDesign.borderRadiusLarge,
        border: BorderSide(color: edge),
        // 12 above and below, not 16: the card sits in the home screen's
        // height budget (invite_layout tests), and Persian lines are taller.
        // The chevron's glyph has its own air on the end side.
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppDesign.space16,
          AppDesign.space12,
          AppDesign.space12,
          AppDesign.space12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FlagDisc(flag: _flag, spent: _blocked),
                const SizedBox(width: AppDesign.space12),
                Expanded(
                  child: _CardLines(
                    lineGap: tallLines ? 0 : AppDesign.space2,
                    heading: Row(
                      children: [
                        Icon(_headingIcon, size: 14, color: accent),
                        const SizedBox(width: AppDesign.space6),
                        Flexible(
                          child: Text(
                            _heading(l10n),
                            style: text.labelSmall?.copyWith(
                              color: accent,
                              letterSpacing: AppDesign.ls(0.6),
                              // Persian, Arabic and Urdu secondary text is
                              // no smaller than bodySmall (12.5sp).
                              fontSize: tallLines
                                  ? text.bodySmall?.fontSize
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // One Text, "City, Country".
                    place: Text(
                      _place(context, l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(
                        color: AppDesign.textPrimary,
                      ),
                    ),
                    // Shrinks rather than overflows where it has less room
                    // than it needs, as a long timeout word can.
                    chip: ping == null
                        ? null
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: LatencyChip(
                              ms: ping,
                              timeoutLabel: l10n.timeout,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: AppDesign.space4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppDesign.textTertiary,
                  size: 20,
                ),
              ],
            ),
            SizedBox(height: tallLines ? 0 : AppDesign.space6),
            // From the card's start, under the disc, not lined up with the
            // text beside the disc: the extra 52dp of width keeps a long
            // caption to fewer lines, and the card is in the height budget.
            if (_blocked && onInvite != null)
              // The link goes under the reset time where a long language
              // has no room beside it.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppDesign.space8,
                children: [
                  Text(
                    _caption(l10n),
                    style: text.bodySmall?.copyWith(
                      color: AppDesign.textTertiary,
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('server-card-invite'),
                    onPressed: onInvite,
                    icon: const Icon(Icons.card_giftcard_outlined, size: 16),
                    label: Text(l10n.inviteTitle),
                    style: TextButton.styleFrom(
                      foregroundColor: AppDesign.brandBright,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDesign.space8,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                _caption(l10n),
                style: text.bodySmall?.copyWith(color: AppDesign.textTertiary),
              ),
            if (_blocked && onGetUnlimited != null) ...[
              const SizedBox(height: AppDesign.space12),
              UpsellShown(
                surface: UpsellSurface.serverCard,
                child: FilledButton.icon(
                  onPressed: onGetUnlimited,
                  icon: const Icon(Icons.all_inclusive_rounded, size: 18),
                  label: Text(l10n.premiumGetUnlimited),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppDesign.brand,
                    foregroundColor: AppDesign.onBrand,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The card's heading and place, and the reply time on whichever of the
/// two lines has room for it.
///
/// The reply time goes at the end of the heading's line when the heading
/// and it fit there side by side, so the place under them has the whole
/// width: "City, Country" then shows in full on most phones. Otherwise it
/// goes at the end of the place's line, and the heading keeps the whole
/// width. The heading is never cut, and wraps if it must: it says whose
/// server this is. The place is cut with an ellipsis when it is longer than
/// its line, as it was before the redesign.
///
/// The reply time takes at most [chipShare] of the width, so a long
/// timeout word (German "Zeitüberschreitung") cannot take the place's
/// room. On the heading's line it is centred on that line and adds no
/// height of its own: the card is part of the home screen's height budget.
class _CardLines extends MultiChildRenderObjectWidget {
  _CardLines({
    required Widget heading,
    required Widget place,
    required Widget? chip,
    required this.lineGap,
  }) : super(children: [heading, place, ?chip]);

  /// Between the heading's line and the place's.
  final double lineGap;

  static const double chipShare = 0.5;

  /// Between the reply time and the text beside it.
  static const double chipGap = AppDesign.space8;

  @override
  _RenderCardLines createRenderObject(BuildContext context) => _RenderCardLines(
    textDirection: Directionality.of(context),
    lineGap: lineGap,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderCardLines renderObject) {
    renderObject
      ..textDirection = Directionality.of(context)
      ..lineGap = lineGap;
  }
}

class _CardLinesParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderCardLines extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CardLinesParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CardLinesParentData> {
  _RenderCardLines({
    required TextDirection textDirection,
    required double lineGap,
  }) : _textDirection = textDirection,
       _lineGap = lineGap;

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  double _lineGap;
  set lineGap(double value) {
    if (value == _lineGap) return;
    _lineGap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CardLinesParentData) {
      child.parentData = _CardLinesParentData();
    }
  }

  RenderBox get _heading => firstChild!;
  RenderBox get _place => childAfter(_heading)!;
  RenderBox? get _chip => childAfter(_place);

  /// Lays the children out with [layoutChild] in [width], and returns the
  /// height and where each child goes: heading, place, chip.
  (double, List<Offset>) _arrange(double width, ChildLayouter layoutChild) {
    final chip = _chip;
    final chipSize = chip == null
        ? Size.zero
        : layoutChild(
            chip,
            BoxConstraints(maxWidth: width * _CardLines.chipShare),
          );
    final beside = chip == null
        ? width
        : math.max(0.0, width - _CardLines.chipGap - chipSize.width);
    final onHeading =
        chip != null &&
        _heading.getMaxIntrinsicWidth(double.infinity) <= beside;
    final onPlace = chip != null && !onHeading;
    final headingSize = layoutChild(
      _heading,
      BoxConstraints.tightFor(width: onHeading ? beside : width),
    );
    final placeSize = layoutChild(
      _place,
      BoxConstraints.tightFor(width: onPlace ? beside : width),
    );
    final placeTop = headingSize.height + _lineGap;
    final placeLine = onPlace
        ? math.max(placeSize.height, chipSize.height)
        : placeSize.height;
    final rtl = _textDirection == TextDirection.rtl;
    // The text at the start, the reply time at the end.
    double startX(double childWidth) => rtl ? width - childWidth : 0;
    final chipX = rtl ? 0.0 : width - chipSize.width;
    final chipY = onHeading
        ? (headingSize.height - chipSize.height) / 2
        : placeTop + (placeLine - chipSize.height) / 2;
    return (
      placeTop + placeLine,
      [
        Offset(startX(headingSize.width), 0),
        Offset(
          startX(placeSize.width),
          placeTop + (placeLine - placeSize.height) / 2,
        ),
        Offset(chipX, chipY),
      ],
    );
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final (height, offsets) = _arrange(width, ChildLayoutHelper.layoutChild);
    var child = firstChild;
    var i = 0;
    while (child != null) {
      (child.parentData! as _CardLinesParentData).offset = offsets[i++];
      child = childAfter(child);
    }
    size = constraints.constrain(Size(width, height));
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final (height, _) = _arrange(
      constraints.maxWidth,
      ChildLayoutHelper.dryLayoutChild,
    );
    return constraints.constrain(Size(constraints.maxWidth, height));
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _heading.getMinIntrinsicWidth(height),
    _place.getMinIntrinsicWidth(height) +
        (_chip == null
            ? 0
            : _CardLines.chipGap + _chip!.getMinIntrinsicWidth(height)),
  );

  @override
  double computeMaxIntrinsicWidth(double height) => math.max(
    _heading.getMaxIntrinsicWidth(height),
    _place.getMaxIntrinsicWidth(height) +
        (_chip == null
            ? 0
            : _CardLines.chipGap + _chip!.getMaxIntrinsicWidth(height)),
  );

  @override
  double computeMinIntrinsicHeight(double width) =>
      _arrange(width, ChildLayoutHelper.dryLayoutChild).$1;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _arrange(width, ChildLayoutHelper.dryLayoutChild).$1;

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// Remaining allowance, as one quiet line, with a small link after it once
/// the backend's share of the allowance is used: "Invite friends for more
/// data" ([onInvite]) and "Get unlimited" ([onGetUnlimited]), each while it
/// is on. With both, the invite link comes first, as on the limit sheet:
/// the free way to more data, then Premium.
class _QuotaLine extends StatelessWidget {
  final QuotaStatus? quota;
  final VoidCallback? onGetUnlimited;
  final VoidCallback? onInvite;

  const _QuotaLine({
    super.key,
    required this.quota,
    this.onGetUnlimited,
    this.onInvite,
  });

  /// The invite link and the Premium link, for tests.
  static const inviteKey = Key('quota-line-invite');
  static const unlimitedKey = Key('quota-line-unlimited');

  @override
  Widget build(BuildContext context) {
    final quota = this.quota;
    if (quota == null || quota.unlimited) {
      return const SizedBox(height: AppDesign.space12);
    }
    final l10n = S.of(context)!;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // In the language's own digits and decimal mark, and each amount
    // isolated with its unit: in a right to left line the number and "GB"
    // of a bare "5.0 GB" can land on either side of the words between them.
    String amount(int bytes) {
      final shown = QuotaCard.localizedBytes(bytes, context);
      return rtl ? '\u2068$shown\u2069' : shown;
    }

    final blocked = quota.blocked;
    final words = blocked
        ? l10n.quotaUsedUp
        : l10n.quotaUsedToday(
            amount(quota.usedBytes),
            amount(quota.limitBytes),
          );
    final style = AppDesign.textTheme.bodySmall?.copyWith(
      color: blocked ? AppDesign.error : AppDesign.textSecondary,
    );
    // One line, shrunk a little where a long translation at a large text
    // size would not fit: a second line would take its height from the
    // power button.
    final line = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(words, maxLines: 1, style: style),
    );
    final onGetUnlimited = this.onGetUnlimited;
    final onInvite = this.onInvite;
    if (blocked || (onGetUnlimited == null && onInvite == null)) {
      // 8 above: the line's own leading adds to it, and the footer sits in
      // the home screen's height budget.
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDesign.space20,
          AppDesign.space8,
          AppDesign.space20,
          0,
        ),
        child: line,
      );
    }
    final linkStyle = AppDesign.textTheme.bodySmall?.copyWith(
      color: AppDesign.brandBright,
      fontWeight: FontWeight.w600,
    );
    // The free way first, as on the limit sheet.
    final links = <_QuotaLink>[
      if (onInvite != null)
        _QuotaLink(inviteKey, l10n.premiumLimitInvite, onInvite),
      if (onGetUnlimited != null)
        _QuotaLink(unlimitedKey, l10n.premiumGetUnlimited, onGetUnlimited),
    ];
    // Each amount kept whole, so a line never ends between the number and
    // its unit.
    final wrapped = l10n.quotaUsedToday(
      amount(quota.usedBytes).replaceAll(' ', '\u00A0'),
      amount(quota.limitBytes).replaceAll(' ', '\u00A0'),
    );
    final body = links.length == 1
        ? _oneLink(links.single, line, words, wrapped, style, linkStyle)
        : _twoLinks(links, line, linkStyle);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDesign.space20),
      // Only the Premium link is an offer the backend counts as shown.
      child: onGetUnlimited == null
          ? body
          : UpsellShown(surface: UpsellSurface.quotaLine, child: body),
    );
  }

  /// [link] as a tap target the line's full 48dp height, padded around the
  /// link's words alone, on lines no wider than [wrapWidth].
  static Widget _target(
    _QuotaLink link,
    TextStyle? linkStyle, {
    double? wrapWidth,
  }) => Pressable(
    key: link.key,
    onTap: link.onTap,
    color: Colors.transparent,
    padding: const EdgeInsets.symmetric(horizontal: AppDesign.space8),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: kMinInteractiveDimension,
        maxWidth: wrapWidth ?? double.infinity,
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(link.words, textAlign: TextAlign.center, style: linkStyle),
      ),
    ),
  );

  /// The amounts with one link, which goes beside them wherever it can.
  ///
  /// Only the link opens anything, as before the redesign: the amounts are
  /// words, not a button.
  ///
  /// The link goes beside the amounts wherever it can, because there its
  /// target is the line's full 48dp height, padded around the link alone.
  /// The first choice is one line, with the amounts shrunk by at most a
  /// tenth. Where that does not fit (a narrow phone at a large text size,
  /// or a long translation), the amounts take two lines, and then the
  /// link takes two lines as well. Two lines are used only where they are
  /// no taller than the amounts and the link one under the other, so the
  /// power button never has less room because of them.
  ///
  /// Only where nothing fits beside the amounts does the link go under
  /// them. Its target is then only as tall as the room the two lines
  /// already take, because a 48dp row of its own there came out of the
  /// power button's room. The line's own air stands in for the gap above
  /// it.
  Widget _oneLink(
    _QuotaLink link,
    Widget line,
    String words,
    String wrapped,
    TextStyle? style,
    TextStyle? linkStyle,
  ) {
    final linkWords = link.words;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final linkPadding = 2 * AppDesign.space8;
        final amountsOne = _measure(context, words, style);
        final linkOne = _measure(context, linkWords, linkStyle);
        if (amountsOne.width * _besideScale + linkOne.width + linkPadding <=
            width) {
          return Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: line),
                _target(link, linkStyle),
              ],
            ),
          );
        }

        // How tall the two lines are one under the other, the amounts
        // shrunk to the width as the line does.
        final fit = math.min(
          1.0,
          (width - linkPadding) / math.max(amountsOne.width, 1),
        );
        final underHeight = math.max(
          kMinInteractiveDimension,
          amountsOne.height * fit + linkOne.height + 2 * AppDesign.space2,
        );
        // Two lines as even as the words allow. They may shrink by the
        // same tenth as the one line.
        final amountsWidth = _twoLineWidth(context, wrapped, style);
        if (amountsWidth != null) {
          final amountsLines = _measure(
            context,
            wrapped,
            style,
            maxLines: 2,
            maxWidth: amountsWidth,
          );
          // The link on one line, then on two.
          for (final linkWidth in [
            null,
            ?_twoLineWidth(context, linkWords, linkStyle),
          ]) {
            final linkLines = linkWidth == null
                ? linkOne
                : _measure(
                    context,
                    linkWords,
                    linkStyle,
                    maxLines: 2,
                    maxWidth: linkWidth,
                  );
            final room = width - (linkWidth ?? linkOne.width) - linkPadding;
            final shrink = math.min(1.0, room / amountsWidth);
            final height = math.max(
              kMinInteractiveDimension,
              math.max(amountsLines.height * shrink, linkLines.height),
            );
            if (shrink >= _besideScale &&
                amountsLines.fits &&
                linkLines.fits &&
                height <= underHeight + 0.5) {
              return Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: amountsWidth,
                          child: Text(
                            wrapped,
                            textAlign: TextAlign.center,
                            style: style,
                          ),
                        ),
                      ),
                    ),
                    _target(link, linkStyle, wrapWidth: linkWidth),
                  ],
                ),
              );
            }
          }
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDesign.space8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  line,
                  Pressable(
                    key: link.key,
                    onTap: link.onTap,
                    color: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDesign.space8,
                      vertical: AppDesign.space2,
                    ),
                    child: Text(
                      linkWords,
                      textAlign: TextAlign.center,
                      style: linkStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The amounts with both links on a row under them, the invite link
  /// first, each a target the full 48dp tall and padded around its own
  /// words, so the amounts are in neither. The row takes the least room
  /// that holds both: each link on one line, then the longer on two (the
  /// invite link runs long in most languages), then both on two. Only where
  /// none of that fits, at a large text size on a narrow phone, does each
  /// link get a row of its own; the column above scrolls there already.
  ///
  /// Nothing goes beside the amounts here: the two links and the amounts
  /// never fit on one line, even on a wide phone in English. The amounts
  /// keep the 8 above that the line has without a link.
  Widget _twoLinks(List<_QuotaLink> links, Widget line, TextStyle? linkStyle) {
    final dotStyle = AppDesign.textTheme.bodySmall?.copyWith(
      color: AppDesign.textTertiary,
    );
    // A quiet dot between them, so two links in the same color do not read
    // as one phrase. Words for neither eye nor screen reader.
    const dotWords = '\u00B7';
    final dot = ExcludeSemantics(child: Text(dotWords, style: dotStyle));
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final linkPadding = 2 * AppDesign.space8;
        final dotWidth = _measure(context, dotWords, dotStyle).width;
        // Each link on one line, and on its most even two lines.
        final one = [
          for (final link in links) _measure(context, link.words, linkStyle),
        ];
        final two = [
          for (final link in links)
            _twoLineWidth(context, link.words, linkStyle),
        ];
        bool twoFit(int i) {
          final w = two[i];
          if (w == null) return false;
          final lines = _measure(
            context,
            links[i].words,
            linkStyle,
            maxLines: 2,
            maxWidth: w,
          );
          return lines.fits;
        }

        // Which link takes two lines, least room first: none, the longer,
        // the other one, both.
        final longer = one[0].width >= one[1].width ? 0 : 1;
        final choices = <Set<int>>[
          {},
          {longer},
          {1 - longer},
          {0, 1},
        ];
        for (final wrap in choices) {
          if (!wrap.every(twoFit)) continue;
          final used =
              2 * linkPadding +
              dotWidth +
              (wrap.contains(0) ? two[0]! : one[0].width) +
              (wrap.contains(1) ? two[1]! : one[1].width);
          if (used > width) continue;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppDesign.space8),
                  child: line,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _target(
                      links[0],
                      linkStyle,
                      wrapWidth: wrap.contains(0) ? two[0] : null,
                    ),
                    dot,
                    _target(
                      links[1],
                      linkStyle,
                      wrapWidth: wrap.contains(1) ? two[1] : null,
                    ),
                  ],
                ),
              ],
            ),
          );
        }
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppDesign.space8),
                child: line,
              ),
              for (final link in links) _target(link, linkStyle),
            ],
          ),
        );
      },
    );
  }

  /// How far the amounts may shrink to keep a link beside them, on one line
  /// or two, as the line already shrinks a little for a long translation.
  static const double _besideScale = 0.9;

  /// [words] in [style] as Text draws them, on up to [maxLines] lines no
  /// wider than [maxWidth]: their size, and whether they fit there with no
  /// word broken.
  static ({double width, double height, bool fits}) _measure(
    BuildContext context,
    String words,
    TextStyle? style, {
    int maxLines = 1,
    double maxWidth = double.infinity,
  }) {
    var drawn = DefaultTextStyle.of(context).style.merge(style);
    if (MediaQuery.boldTextOf(context)) {
      drawn = drawn.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    final painter = TextPainter(
      text: TextSpan(text: words, style: drawn),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: maxLines,
    )..layout(maxWidth: math.max(maxWidth, 0));
    final result = (
      width: painter.width,
      height: painter.height,
      fits: !painter.didExceedMaxLines && painter.minIntrinsicWidth <= maxWidth,
    );
    painter.dispose();
    return result;
  }

  /// The narrowest width [words] take on two lines, broken between words,
  /// rounded up to a whole pixel. Null for a single word.
  static double? _twoLineWidth(
    BuildContext context,
    String words,
    TextStyle? style,
  ) {
    final parts = words.split(' ');
    double? narrowest;
    for (var i = 1; i < parts.length; i++) {
      final wider = math.max(
        _measure(context, parts.take(i).join(' '), style).width,
        _measure(context, parts.skip(i).join(' '), style).width,
      );
      if (narrowest == null || wider < narrowest) narrowest = wider;
    }
    return narrowest?.ceilToDouble();
  }
}

/// One link on the data line: its key, its words and what a tap does.
class _QuotaLink {
  const _QuotaLink(this.key, this.words, this.onTap);

  final Key key;
  final String words;
  final VoidCallback onTap;
}

/// The speed test and the invite screen, one tap from the home screen
/// rather than two from Settings, where they also stay. Invite is drawn
/// only once the backend says the program is live, as in Settings.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    // Null in tests of the screen built without the app config.
    final invites = context.watch<AppConfigState?>()?.referralsEnabled ?? false;
    void open(Widget page) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReadableWidth(child: page)),
    );
    // 8 above: the data line over them has its own leading, and the footer
    // sits in the home screen's height budget.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDesign.space20,
        AppDesign.space8,
        AppDesign.space20,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: _Shortcut(
              icon: Icons.speed_rounded,
              label: l10n.speedTest,
              onTap: () => open(const SpeedTestScreen()),
            ),
          ),
          if (invites) ...[
            const SizedBox(width: AppDesign.space12),
            Expanded(
              child: _Shortcut(
                icon: Icons.card_giftcard_outlined,
                label: l10n.inviteTitle,
                onTap: () =>
                    open(const InviteScreen(entry: InviteEntry.homeButton)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One tonal button. It is [height] tall at any text size, so a larger
/// font never takes room from the power button; a long label shrinks to
/// fit instead.
class _Shortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  static const double height = 52;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      // The server card's hairline edge, so the card and the shortcuts
      // under it read as one set on the canvas.
      border: const BorderSide(color: AppDesign.hairline),
      padding: const EdgeInsets.symmetric(horizontal: AppDesign.space12),
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppDesign.steelLight),
            const SizedBox(width: AppDesign.space8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppDesign.textTheme.labelLarge?.copyWith(
                    color: AppDesign.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// On a phone the team keeps inside Iran as a test point: that it is
/// running, when it last checked, and how many doors were open. Nothing on
/// any other phone.
class _TestPointLine extends StatelessWidget {
  const _TestPointLine();

  @override
  Widget build(BuildContext context) {
    final runner = context.watch<TestPointRunner?>();
    if (runner == null || !runner.active) return const SizedBox.shrink();
    final l10n = S.of(context)!;
    final last = runner.lastCheck;
    final time = last == null
        ? '...'
        : '${last.hour.toString().padLeft(2, '0')}:'
              '${last.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        NumberLocalizer.localize(
          l10n.testPointStatus(time, runner.openDoors, runner.totalDoors),
          context,
        ),
        style: AppDesign.textTheme.bodySmall?.copyWith(
          color: AppDesign.textTertiary,
        ),
      ),
    );
  }
}

/// The kinds of notice [_ErrorBar] shows: the color of its icon and
/// actions, and the tonal fill that color reads on.
enum _Tone {
  /// A failed connection.
  error(AppDesign.error, AppDesign.errorContainer),

  /// A setting of the phone's own that gets in the way while connected.
  warning(AppDesign.warning, AppDesign.warningContainer),

  /// A way forward, not a fault.
  info(AppDesign.info, AppDesign.infoContainer);

  const _Tone(this.color, this.container);

  final Color color;
  final Color container;
}

class _ErrorBar extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  /// The kind of notice. A failure by default; a warning about the phone's
  /// own settings while connected, and the friend offer, use their own.
  final _Tone tone;
  final IconData icon;
  // Some failures cannot be fixed from inside the app; when that is the case
  // the bar carries the way out instead of only naming the problem.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// The checks behind [message], for the people who will screenshot this
  /// to us. Folded away by default: it is the sentence above that the
  /// user is meant to act on, and this is evidence, not advice.
  final Map<String, dynamic>? details;

  /// Whether to offer the support chat under the advice. Only for a failed
  /// connection, and only once the backend says the chat is on.
  final bool askSupport;

  const _ErrorBar({
    required this.message,
    required this.onDismiss,
    this.actionLabel,
    this.onAction,
    this.details,
    this.askSupport = false,
    this.tone = _Tone.error,
    this.icon = Icons.error_outline,
  });

  @override
  State<_ErrorBar> createState() => _ErrorBarState();
}

class _ErrorBarState extends State<_ErrorBar> {
  bool _showDetails = false;

  static const double _iconSize = 20;

  /// Above the icon and the message's first line: centres them on the
  /// close button's 48dp square in the top end corner. A line of advice
  /// with nothing to tap has the same air, so it is as tall as a button.
  static const double _lineTop = (kMinInteractiveDimension - _iconSize) / 2;

  /// From the bar's start edge to the message, past the icon: where the
  /// lines under the message start too.
  static const double _textStart =
      AppDesign.space16 + _iconSize + AppDesign.space12;

  /// The room a text button leaves before its words.
  static const double _buttonInset = AppDesign.space8;

  /// The diagnosis as one line per check, longest keys last so the
  /// interesting ones are readable without scrolling.
  ///
  /// The core log is left out: it runs to thousands of characters and is
  /// already on the event this failure sent.
  String _detailText(Map<String, dynamic> diag) {
    final entries =
        diag.entries
            .where((e) => e.key != 'core_log' && e.value != null)
            .map((e) => '${e.key}: ${e.value}')
            .toList()
          ..sort();
    return entries.join('\n');
  }

  /// Whether "Ask support" shows under the advice: asked for, and the chat
  /// is on (AskSupportLink draws nothing while it is off). Read here only to
  /// leave room under the link. Never throws: a broken chat must not take
  /// the bar with it.
  bool _chatLink(BuildContext context) {
    if (!widget.askSupport) return false;
    try {
      return context.watch<SupportState?>()?.enabled ?? false;
    } catch (e) {
      debugPrint('HomeScreen: chat link not shown ($e)');
      return false;
    }
  }

  ButtonStyle _buttonStyle(Color color) => TextButton.styleFrom(
    foregroundColor: color,
    minimumSize: const Size(48, 48),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: _buttonInset),
    textStyle: AppDesign.textTheme.titleSmall,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final tone = widget.tone;
    final message = widget.message;
    final actionLabel = widget.actionLabel;
    final onAction = widget.onAction;
    final details = widget.details;
    final hasDetails = details != null && details.isNotEmpty;
    final hasActions = actionLabel != null || hasDetails;
    final chatLink = _chatLink(context);
    final more = hasActions || chatLink;

    final actions = <Widget>[
      if (actionLabel != null)
        onAction == null
            // Some advice has nothing to tap: no screen in this app fixes
            // the phone's own connection. It is still the sentence the user
            // needs, so it is shown as a line rather than dropped for want
            // of a destination, and it does not pretend to be a button.
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _buttonInset,
                  vertical: _lineTop,
                ),
                child: Text(
                  actionLabel,
                  style: AppDesign.textTheme.bodyMedium?.copyWith(
                    color: AppDesign.textSecondary,
                  ),
                ),
              )
            : TextButton(
                onPressed: onAction,
                style: _buttonStyle(tone.color),
                child: Text(actionLabel),
              ),
      if (hasDetails)
        TextButton(
          onPressed: () => setState(() => _showDetails = !_showDetails),
          style: _buttonStyle(AppDesign.textSecondary),
          child: Text(_showDetails ? l10n.diagDetailsHide : l10n.diagDetails),
        ),
    ];

    // A Container: the chatbot button's layout test finds the bar as the
    // Container around "Ask support".
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDesign.space20,
        0,
        AppDesign.space20,
        AppDesign.space12,
      ),
      // Under Ask support the air is inside its 48dp tap target, which
      // centres the words, so the bar adds none there.
      padding: EdgeInsetsDirectional.only(
        start: AppDesign.space16,
        bottom: more && !chatLink ? AppDesign.space4 : 0,
      ),
      decoration: BoxDecoration(
        color: tone.container,
        borderRadius: AppDesign.borderRadiusLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The close button's 48dp square sits in the top end corner, and
          // the icon and the first line of the message are centred on it.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: _lineTop),
                child: Icon(widget.icon, color: tone.color, size: _iconSize),
              ),
              const SizedBox(width: AppDesign.space12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: _lineTop,
                    bottom: more ? AppDesign.space2 : _lineTop,
                  ),
                  child: Text(
                    message,
                    style: AppDesign.textTheme.bodyMedium?.copyWith(
                      color: AppDesign.textPrimary,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.onDismiss,
                tooltip: l10n.close,
                iconSize: 20,
                color: AppDesign.textSecondary,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (actions.isNotEmpty)
            Padding(
              // Outside the buttons, so a TV remote's focus ring goes round
              // the words and not the indent before them.
              padding: const EdgeInsetsDirectional.only(
                start: _textStart - AppDesign.space16 - _buttonInset,
                end: AppDesign.space12,
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              ),
            ),
          if (hasDetails && _showDetails)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: _textStart - AppDesign.space16,
                end: AppDesign.space16,
                bottom: AppDesign.space8,
              ),
              child: SelectableText(
                _detailText(details),
                style: AppDesign.textTheme.bodySmall?.copyWith(
                  color: AppDesign.textTertiary,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
          if (chatLink)
            // AskSupportLink indents itself by 28; this lines it up with
            // the message. It keeps the air under it inside its own tap
            // target.
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: _textStart - AppDesign.space16 - 28,
              ),
              child: AskSupportLink(color: tone.color),
            ),
        ],
      ),
    );
  }
}
