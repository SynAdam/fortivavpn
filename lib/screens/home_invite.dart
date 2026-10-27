part of 'home_screen.dart';

/// The invite card on the home screen, and when it may show. See
/// InvitePrompt for the record and the backend's numbers.
///
/// It shows at two moments, with one count of shows between them:
///
/// * While the tunnel is up (InviteSurface.afterConnect). It waits for a
///   calm screen with a checked tunnel that has been up the backend's
///   min_session_minutes, as the rating card and the Premium card do. When
///   the app comes to the front with the tunnel up that long already, the
///   wait is short ([resumeSettle]), because most people connect and leave
///   the app and come back to it only for a moment.
/// * Right after the user ends a good session with the power button
///   (InviteSurface.afterDisconnect), when the backend's block says
///   after_disconnect: the session was checked, lasted the backend's
///   min_session_minutes, and had no failure or drop in it. Never after a
///   drop, a failure, a stop from the notification or the quick settings
///   tile, or a stop while the app is away. It goes when the user taps the
///   button again, when a page or a sheet opens, and when the app is
///   hidden.
///
/// It gives way at both moments to the rating card, the Premium card and
/// the question about notifications when any of them is due, and to the
/// introduction to the invite tree while it may still open by itself in
/// this run (_HomeTreeIntro.pending): the rating card first, the Premium
/// card second, this one last. One card or popup per run, shared with the
/// update dialog, message popups, the notification question, the limit
/// sheet and the introduction to the invite tree, which takes this card's
/// turn in a run where it opens. The limit sheet always keeps priority,
/// because it is the only sign that the daily allowance is spent. The
/// power button comes before all of it: where the card would push the
/// button out of sight, the card gives way and is not counted. The card is
/// tried first without moving anything on screen ([trial]). Once it may
/// show, it grows into its place and fades in, so the button above glides
/// up instead of jumping, and it shrinks out of its place when it goes.
/// Its buttons take taps only after [armAfter], because the server card
/// under it moves as it comes in, and a tap meant for the server card must
/// not share.
///
/// Every provider is read nullable, and a missing one means no card, so the
/// home screen built without them (as in its own tests) shows none.
class _HomeInviteCard {
  _HomeInviteCard({
    required this.host,
    required this.prompt,
    required this.onChanged,
  });

  /// The screen, for its gates.
  final _HomeScreenState host;

  /// Null when there is no InvitePrompt above the screen.
  final InvitePrompt? prompt;
  final VoidCallback onChanged;

  /// How long the screen must have been calm before the card shows while
  /// the tunnel is up. Longer than the rating card's and the Premium card's
  /// waits, so both go first when they are due. UI timing, not a rule of
  /// the service.
  static const shareCardSettle = Duration(seconds: 20);

  /// The wait in place of [shareCardSettle] when the app came to the front,
  /// or the screen was first built, with the tunnel already up for the
  /// backend's min_session_minutes. Shorter than the waits of the message
  /// popup, the rating card and the Premium card, so the card asks each
  /// that goes first whether it is due, and gives way. UI timing.
  static const resumeSettle = Duration(seconds: 4);

  /// How long the screen must stay at rest after the user's stop before the
  /// card shows: long enough to see the button go off, and short enough to
  /// come before most people leave the app. UI timing.
  static const afterStopSettle = Duration(milliseconds: 1500);

  /// How long the card takes to grow into its place, or to shrink out of
  /// it, and the code row under the server card to make way. UI timing.
  static const slideIn = Duration(milliseconds: 250);

  /// How long the card takes to fade in once drawn. UI timing.
  static const fadeIn = Duration(milliseconds: 200);

  /// How long after it is drawn the card takes taps. Longer than
  /// [slideIn], so a tap aimed at the server card while it moves down
  /// lands on nothing. UI timing.
  static const armAfter = Duration(milliseconds: 600);

  /// The card is on screen, or being tried ([trial]).
  bool up = false;

  /// The card is drawn: up and past its trial.
  bool get showing => up && !trial;

  /// The moment the card is up for, for its events and for when it goes.
  InviteSurface surface = InviteSurface.afterConnect;

  /// A button waiting for the referral status.
  InviteTarget? busy;

  /// The card is laid out for one frame, offstage and taking no room, to
  /// measure it. Nothing on screen moves for it. See [_buttonFits].
  bool trial = false;

  /// The card as laid out in its [trial].
  final trialKey = GlobalKey(debugLabel: 'invite card trial');

  /// Whether the card's buttons take taps. See [armAfter].
  bool armed = false;
  Timer? _armTimer;

  VpnService? _vpn;
  ConnectFlow? _flow;
  DeviceState? _device;
  AppConfigState? _config;
  BillingState? _billing;
  Timer? _timer;

  /// When the app last came to the front, or the screen was first built.
  DateTime? _cameBack;

  /// How many times the app came back to the front in this run.
  int _visit = 0;

  /// The connection, and the visit, the checks last said no for. Nothing
  /// that decides changes within a visit, so the card is not asked again
  /// until the next connection or the next time the app comes to the
  /// front. The backend's waits in hours and days may have ended by then.
  DateTime? _refusedFor;
  int? _refusedInVisit;

  /// The connection the card did not fit beside the power button in. The
  /// screen does not change within a connection, so the card is not tried
  /// again until the next one.
  DateTime? _noRoomFor;

  /// The good session the user just ended with the power button, while its
  /// card may still come. Null once it has been asked for, and once the
  /// screen did anything but come to rest with the tunnel down.
  ({DateTime upSince, DateTime endedAt})? _stop;
  Timer? _stopTimer;

  /// Listen for the moment to show the card. Read here, not in build, so
  /// the screen never rebuilds for it and works the same without it.
  void watch(BuildContext context) {
    if (prompt == null) return;
    _cameBack = DateTime.now();
    try {
      final vpn = context.read<VpnService>();
      final flow = context.read<ConnectFlow>();
      final device = context.read<DeviceState?>();
      final config = context.read<AppConfigState?>();
      // For the payments' first answer. See [_paymentsPending].
      final billing = context.read<BillingState?>();
      vpn.addListener(check);
      flow.addListener(check);
      device?.addListener(check);
      config?.addListener(check);
      billing?.addListener(check);
      _vpn = vpn;
      _flow = flow;
      _device = device;
      _config = config;
      _billing = billing;
      check();
    } catch (e) {
      debugPrint('HomeScreen: invite card not watched ($e)');
    }
  }

  /// The app came back to the front. See [resumeSettle].
  void resumed() {
    _cameBack = DateTime.now();
    _visit++;
  }

  /// The power button is ending the session. Noted, before the stop and
  /// while the session is still there, when it is a good one so far: the
  /// app in front, the tunnel up and checked, nothing in progress, and no
  /// warning. How long it lasted and whether it had a failure are asked
  /// once the tunnel is down. Never throws.
  void sessionEnded(VpnService vpn, ConnectFlow flow) {
    _forgetStop();
    try {
      final p = prompt;
      if (p == null || p.shownThisRun || !host.mounted) return;
      if (!_inFront() || host._starting) return;
      if (flow.isBusy || flow.showChecklist) return;
      if (vpn.status != VpnStatus.connected || vpn.isVerifying) return;
      if (vpn.verifiedAt == null || vpn.stalled) return;
      if (vpn.errorMessage != null) return;
      final upSince = vpn.currentConnection?.startTime;
      if (upSince == null) return;
      if (!(_device?.device?.invitePrompt?.afterDisconnect ?? false)) return;
      _stop = (upSince: upSince, endedAt: DateTime.now());
    } catch (e) {
      debugPrint('HomeScreen: invite card stop not noted ($e)');
    }
  }

  /// The power button is connecting. The moment after the last stop is
  /// over, and its card goes.
  void connectTapped() {
    _forgetStop();
    if (up && surface == InviteSurface.afterDisconnect) _takeAway();
  }

  void _forgetStop() {
    _stop = null;
    _stopTimer?.cancel();
    _stopTimer = null;
  }

  static bool _inFront() =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  /// Whether the screen is at rest with the tunnel down, as the user's stop
  /// left it: the app in front, nothing starting or in progress, and no
  /// failure on screen.
  bool _resting() {
    final vpn = _vpn;
    final flow = _flow;
    if (vpn == null || flow == null || !host.mounted) return false;
    return _inFront() &&
        vpn.status == VpnStatus.disconnected &&
        !vpn.isVerifying &&
        !vpn.awaitingPermission &&
        vpn.errorMessage == null &&
        !flow.isBusy &&
        !flow.showChecklist &&
        !host._starting;
  }

  /// Whether the home screen is on top, with no sheet over it.
  bool _onTop() =>
      (ModalRoute.of(host.context)?.isCurrent ?? false) &&
      !host._limitSheetOpen;

  /// Whether the card is drawn now: the card of the tunnel's moment while
  /// the tunnel is up and checked ([connected]), and the card after a stop
  /// while the tunnel is down and nothing starts.
  bool drawnWith(VpnService vpn, {required bool connected}) {
    if (!up) return false;
    if (surface == InviteSurface.afterDisconnect) {
      return vpn.status == VpnStatus.disconnected && !host._starting;
    }
    return connected;
  }

  /// Start the waits while the screen allows them, and stop them, or take
  /// the card away, as soon as it does not. Never throws.
  void check() {
    try {
      final p = prompt;
      if (p == null || !host.mounted) return;
      _checkAfterStop();
      _checkWhileUp(p);
    } catch (e) {
      debugPrint('HomeScreen: invite card check failed ($e)');
    }
  }

  /// The card while the tunnel is up. The wait runs until the tunnel has
  /// been up for the backend's min_session_minutes and the screen calm for
  /// [shareCardSettle], whichever is later, or [resumeSettle] when the
  /// tunnel was up that long already when the app came to the front.
  void _checkWhileUp(InvitePrompt p) {
    final mine = up && surface == InviteSurface.afterConnect;
    if (!_HomeScreenState._calmWith(_vpn, _flow)) {
      _timer?.cancel();
      _timer = null;
      if (mine) _takeAway();
      return;
    }
    if (up) {
      // Another screen or a sheet opened over the card: it is gone for
      // this run. Counted already when it was drawn.
      if (mine && !_onTop()) _takeAway();
      return;
    }
    if (p.shownThisRun || _timer != null) return;
    final upSince = _vpn?.currentConnection?.startTime;
    if (upSince == null || _refused(upSince)) return;
    final rules = _device?.device?.invitePrompt;
    if (rules == null) return;
    // The Premium card can tell whether it is due only once the payments
    // have answered, so the wait starts after that answer. At app start
    // they answer some seconds after the screen is built, and the short
    // wait would otherwise take the Premium card's turn.
    if (_paymentsPending()) return;
    final least = Duration(minutes: rules.minSessionMinutes);
    final back = _cameBack;
    final Duration wait;
    if (back != null && back.difference(upSince) >= least) {
      wait = resumeSettle;
    } else {
      final untilLongEnough = least - DateTime.now().difference(upSince);
      wait = untilLongEnough > shareCardSettle
          ? untilLongEnough
          : shareCardSettle;
    }
    _timer = Timer(wait, () => unawaited(_ask()));
  }

  /// The card after the user's stop: wait while the screen rests with the
  /// tunnel down, and take the card away, or forget the moment, as soon as
  /// it does not.
  void _checkAfterStop() {
    if (up && surface == InviteSurface.afterDisconnect) {
      if (!_resting() || !_onTop()) _takeAway();
      return;
    }
    if (_stop == null) return;
    // Still coming down from the stop, with the app in front.
    if (_vpn?.status == VpnStatus.disconnecting && _inFront()) return;
    if (!_resting()) {
      _forgetStop();
      return;
    }
    _stopTimer ??= Timer(afterStopSettle, () => unawaited(_askAfterStop()));
  }

  /// Whether the payments have not answered yet in this run: no load has
  /// ended, well or badly. Until then the Premium card, which comes before
  /// this one, cannot tell whether it is due. Their answer calls [check].
  bool _paymentsPending() {
    final billing = _billing;
    return billing != null && !billing.hasLoaded && !billing.loadFailed;
  }

  bool _refused(DateTime upSince) =>
      upSince == _noRoomFor ||
      (upSince == _refusedFor && _visit == _refusedInVisit);

  void _refuse(DateTime? upSince) {
    _refusedFor = upSince;
    _refusedInVisit = _visit;
  }

  /// Everything the screen must allow before the card shows at [moment],
  /// apart from the records, which take a moment to read.
  bool _mayShow(InviteSurface moment) {
    final p = prompt;
    final vpn = _vpn;
    if (p == null || vpn == null || !host.mounted || p.shownThisRun) {
      return false;
    }
    if (FormFactor.isTv) return false;
    final context = host.context;
    if (!(context.read<AppConfigState?>()?.referralsEnabled ?? false)) {
      return false;
    }
    final rules = context.read<DeviceState?>()?.device?.invitePrompt;
    if (rules == null) return false;
    final billing = context.read<BillingState?>();
    if (billing == null) return false;
    // The Premium card goes first and cannot tell yet whether it is due.
    if (!billing.hasLoaded && !billing.loadFailed) return false;
    if (moment == InviteSurface.afterDisconnect) {
      if (!rules.afterDisconnect || !_resting()) return false;
    } else if (!_HomeScreenState._calmWith(vpn, _flow)) {
      return false;
    }
    if (!host._runAllowsCard(vpn)) return false;
    // The introduction to the invite tree goes first while it may still
    // open in this run, and once it has opened it is the run's popup.
    if (host._treeIntro.pending) return false;
    if (host._review?.askedThisRun ?? false) return false;
    if (host._limitSheetShownThisRun || host._limitSheetOpen) return false;
    if (host._calmCardUp) return false;
    // The APN guide is a card of its own, and it matters more.
    if (host._apnGuide?.shows(connecting: false) ?? false) return false;
    // The renewal reminder in the footer would show beside the card.
    if (billing.renewal?.reminderDue(billing.premium, DateTime.now()) ??
        false) {
      return false;
    }
    return true;
  }

  /// Whether a card or question that goes before this one is due, so this
  /// one gives way: the rating card, the Premium card, or the question
  /// about notifications where the screen asks it. The rating card waits
  /// for a long enough connection of its own, so it is asked whether it
  /// would be due on one. Never throws.
  Future<bool> _othersFirst() async {
    try {
      final context = host.context;
      final review = host._review;
      final ratingOn =
          context.read<AppConfigState?>()?.flags.reviewPrompt ?? false;
      final billing = context.read<BillingState?>();
      final premium = host._premiumPrompt;
      if (review != null &&
          await review.due(
            enabled: ratingOn,
            upSince: DateTime.now().subtract(ReviewPrompt.minSession),
          )) {
        return true;
      }
      if (billing != null &&
          billing.upsellOn(UpsellSurface.calmCard) &&
          (await premium?.due(billing) ?? false)) {
        return true;
      }
      if (host._noticeVpn != null &&
          await NoticePermissionPrompt.instance.due()) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('HomeScreen: invite card order not read ($e)');
      return true;
    }
  }

  /// Show the card while the tunnel is up, if everything still allows it.
  Future<void> _ask() async {
    _timer = null;
    try {
      final p = prompt;
      final vpn = _vpn;
      if (p == null || vpn == null) return;
      if (!_mayShow(InviteSurface.afterConnect)) return;
      final upSince = vpn.currentConnection?.startTime;
      final rules = host.context.read<DeviceState?>()?.device?.invitePrompt;
      final review = host._review;
      if (await _othersFirst()) {
        _refuse(upSince);
        return;
      }
      final ratingDay = await review?.lastAskDay();
      if (!await p.due(
        rules: rules,
        upSince: upSince,
        ratingAskDay: ratingDay,
      )) {
        _refuse(upSince);
        return;
      }
      // The answers took a moment. Anything that changed meanwhile wins.
      if (!_mayShow(InviteSurface.afterConnect)) return;
      if (!await _present(InviteSurface.afterConnect)) _noRoomFor = upSince;
    } catch (e) {
      debugPrint('HomeScreen: invite card failed ($e)');
    }
  }

  /// Show the card after the user's stop, if everything still allows it.
  /// Asked for once per stop.
  Future<void> _askAfterStop() async {
    _stopTimer = null;
    try {
      final p = prompt;
      final stop = _stop;
      if (p == null || stop == null) return;
      if (!_resting()) {
        _forgetStop();
        return;
      }
      // The introduction to the invite tree is taking its last look before
      // it opens, and may want the turn. Its end looks again.
      if (host._treeIntro.deciding) return;
      _stop = null;
      if (!_mayShow(InviteSurface.afterDisconnect)) return;
      final rules = host.context.read<DeviceState?>()?.device?.invitePrompt;
      final review = host._review;
      if (await _othersFirst()) return;
      final ratingDay = await review?.lastAskDay();
      if (!await p.due(
        rules: rules,
        upSince: stop.upSince,
        endedAt: stop.endedAt,
        ratingAskDay: ratingDay,
      )) {
        return;
      }
      // The answers took a moment. Anything that changed meanwhile wins.
      if (!_mayShow(InviteSurface.afterDisconnect)) return;
      await _present(InviteSurface.afterDisconnect);
    } catch (e) {
      debugPrint('HomeScreen: invite card after a stop failed ($e)');
    }
  }

  /// Put the card up for [moment]. It is laid out first for one frame,
  /// offstage, where it takes no room and nothing on screen moves: on a
  /// short screen, or with a large font, it would push the power button
  /// out of sight, and the power button always comes first. Then the card
  /// gives way, is not counted, and this returns false.
  Future<bool> _present(InviteSurface moment) async {
    final p = prompt;
    if (p == null) return true;
    surface = moment;
    up = true;
    trial = true;
    onChanged();
    await WidgetsBinding.instance.endOfFrame;
    if (!host.mounted || !up) return true;
    if (!_buttonFits()) {
      _takeAway();
      return false;
    }
    trial = false;
    armed = false;
    _armTimer?.cancel();
    _armTimer = Timer(armAfter, () {
      armed = true;
      onChanged();
    });
    onChanged();
    _log(InviteAction.shown);
    await p.shown();
    return true;
  }

  void _takeAway() {
    up = false;
    trial = false;
    armed = false;
    _armTimer?.cancel();
    _armTimer = null;
    busy = null;
    onChanged();
  }

  /// Whether the power button, and the status line under it, would stay
  /// wholly inside the area they scroll in with the card drawn, so nothing
  /// under that area cuts them off. The line says what a tap does ("Tap to
  /// connect" after a stop) or how long the tunnel has been up, and with a
  /// large font the card left the button in view but scrolled the line out
  /// of it. Read from the [trial], where the card is measured offstage: the
  /// area loses the card's height and gets back the code row's, which goes
  /// when the card shows. True when it cannot be told, as on a wide screen,
  /// where the card is beside the button and takes no room from it.
  bool _buttonFits() {
    final layout = host._buttonLayoutKey.currentContext?.findRenderObject();
    final card = trialKey.currentContext?.findRenderObject();
    if (layout is! RenderCornerButtonLayout) return true;
    if (card is! RenderBox || !card.hasSize) return true;
    double height(GlobalKey key) {
      final box = key.currentContext?.findRenderObject();
      return box is RenderBox && box.hasSize ? box.size.height : 0;
    }

    // The card's place may still hold a card on its way out.
    final grows = card.size.height - height(_slotKey);
    final line = host._statusLineKey.currentContext?.findRenderObject();
    return layout.fitsWith(
      height(host._haveCodeKey) - grows,
      through: line is RenderBox ? line : null,
    );
  }

  void _log(InviteAction action) {
    try {
      if (!host.mounted) return;
      host.context.read<InviteEvents?>()?.log(surface, action);
    } catch (e) {
      debugPrint('HomeScreen: invite event not kept ($e)');
    }
  }

  /// A tap on one of the card's buttons. The referral status, which mints
  /// the code, loads on the first tap, with a spinner on that button. No
  /// share target opens without both the code and the link. A share or a
  /// copy ends the card for good. Never throws.
  Future<void> tap(BuildContext context, InviteTarget target) async {
    if (busy != null || !showing || !armed) return;
    try {
      final referrals = context.read<ReferralState?>();
      if (referrals == null) return;
      var status = referrals.status;
      if (!_usable(status)) {
        busy = target;
        onChanged();
        await referrals.refresh();
        busy = null;
        if (!host.mounted) return;
        onChanged();
        status = referrals.status;
        if (!_usable(status)) {
          _say(S.of(host.context)!.inviteLoadFailed);
          return;
        }
      }
      if (!up || !host.mounted) return;
      final l10n = S.of(host.context)!;
      final text = l10n.inviteShareMessage(
        status!.code,
        InviteShare.cardLink(status.shareUrl),
      );
      if (target == InviteTarget.copyLink) {
        await InviteShare.copy(host.context, text);
      } else {
        final opened = await InviteShare.send(
          text: text,
          target: target,
          exclude: status.shareExcludePackages,
          title: l10n.inviteTitle,
        );
        if (opened == InviteShareOutcome.none) return;
      }
      if (!host.mounted) return;
      _takeAway();
      _log(switch (target) {
        InviteTarget.telegram => InviteAction.telegram,
        InviteTarget.whatsapp => InviteAction.whatsapp,
        InviteTarget.copyLink => InviteAction.copyLink,
        InviteTarget.otherApps => InviteAction.otherApps,
      });
      await prompt?.shared();
    } catch (e) {
      debugPrint('HomeScreen: invite share failed ($e)');
      busy = null;
      if (host.mounted) onChanged();
    }
  }

  static bool _usable(ReferralStatus? status) =>
      status != null && status.code.isNotEmpty && status.shareUrl.isNotEmpty;

  void _say(String message) {
    // The theme's snackbar colors: light text on the bar.
    ScaffoldMessenger.maybeOf(host.context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// The close icon.
  void close() {
    if (!showing || !armed) return;
    _takeAway();
    _log(InviteAction.dismissed);
  }

  /// The card's place in the screen's notices.
  final _slotKey = GlobalKey(debugLabel: 'invite card place');

  /// The card's place, for the screen's notices: always there, and as
  /// tall as the card while [drawn] ([drawnWith]), so the card grows into
  /// it and shrinks out of it.
  Widget slot({required bool drawn}) => AnimatedSize(
    key: _slotKey,
    duration: slideIn,
    curve: Curves.easeOutCubic,
    alignment: Alignment.topCenter,
    child: drawn
        ? _InviteCardView(owner: this)
        : const SizedBox(width: double.infinity),
  );

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _armTimer?.cancel();
    _armTimer = null;
    _forgetStop();
    _vpn?.removeListener(check);
    _flow?.removeListener(check);
    _device?.removeListener(check);
    _config?.removeListener(check);
    _billing?.removeListener(check);
  }
}

/// The card as the screen draws it. It depends on the route, so a page or
/// a sheet opened over the home screen rebuilds it, and the card is then
/// taken away.
class _InviteCardView extends StatelessWidget {
  const _InviteCardView({required this.owner});

  final _HomeInviteCard owner;

  @override
  Widget build(BuildContext context) {
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => owner.check());
    }
    final l10n = S.of(context)!;
    final rules = context.read<DeviceState?>()?.device?.invitePrompt;
    final card = InviteCard(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      title: l10n.inviteCardTitle,
      body: l10n.inviteCardBody,
      rewardLine: rules == null
          ? null
          : InviteCard.rewardLineFor(context, rules),
      busyTarget: owner.busy,
      onTarget: (target) => unawaited(owner.tap(context, target)),
      onClose: owner.close,
    );
    if (owner.trial) {
      // Laid out at the width it is drawn at and its full height, but
      // offstage: it takes no room, draws nothing and takes no taps.
      return SizedBox(
        width: double.infinity,
        child: Offstage(
          child: KeyedSubtree(key: owner.trialKey, child: card),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: IgnorePointer(
        ignoring: !owner.armed,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: _HomeInviteCard.fadeIn,
          builder: (context, opacity, child) =>
              Opacity(opacity: opacity, child: child),
          child: card,
        ),
      ),
    );
  }
}

/// "Have an invite code?" under the server card, for a friend who installed
/// the APK and got the code in a message. Shown after the first verified
/// connect, while this install may still claim (referral_claim_open_until
/// in the register answer), and never on a TV, beside the invite card or
/// with the renewal reminder. It never loads the referral status, so it
/// mints no code.
class _HaveCodeRow extends StatelessWidget {
  const _HaveCodeRow();

  @override
  Widget build(BuildContext context) {
    final prompt = context.watch<InvitePrompt?>();
    final referrals = context.watch<ReferralState?>();
    final device = context.watch<DeviceState?>();
    final config = context.watch<AppConfigState?>();
    final billing = context.watch<BillingState?>();
    final until = device?.device?.referralClaimOpenUntil;
    final now = DateTime.now();
    // The renewal reminder in the same footer goes first: both together
    // would push the power button out of sight on a short phone.
    final reminder =
        billing?.renewal?.reminderDue(billing.premium, now) ?? false;
    final show =
        !FormFactor.isTv &&
        !reminder &&
        (config?.referralsEnabled ?? false) &&
        (prompt?.hadGoodDay ?? false) &&
        until != null &&
        until.isAfter(now) &&
        !(referrals?.hasClaimed ?? true);
    // As wide as the row, so the place it shows in only grows and shrinks
    // in height (AnimatedSize in the screen's footer).
    if (!show) return const SizedBox(width: double.infinity);
    final l10n = S.of(context)!;
    // A tonal row with a 48dp tap target, drawn the way Pressable draws
    // one: the fill is the Material, so the ripple shows on it. It is not
    // a Pressable because its key belongs on the InkWell, under the
    // Material, and Pressable keeps its key on itself, above both. Its
    // height is padding around one line, no taller than before at large
    // text sizes: it sits under the server card, and the power button needs
    // the room above.
    //
    // The hairline edge of the server card and the shortcuts, so the three
    // blocks under the button read as one set. The edge is drawn inside
    // the shape and adds no height.
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppDesign.radiusMedium)),
      side: BorderSide(color: AppDesign.hairline),
    );
    return Padding(
      // 8 above, as over the data line and the shortcuts.
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Semantics(
        button: true,
        child: Material(
          color: AppDesign.surfaceLow,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('home-have-code'),
            onTap: () => unawaited(showInviteCodeDialog(context)),
            customBorder: shape,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Row(
                  children: [
                    // In steel at the shortcuts' size, and the words a step
                    // quieter than theirs: this row is for the few who got
                    // a code, and the brand color is for the main actions
                    // and offers.
                    const Icon(
                      Icons.redeem_outlined,
                      size: 20,
                      color: AppDesign.steelLight,
                    ),
                    const SizedBox(width: AppDesign.space12),
                    Expanded(
                      child: Text(
                        l10n.inviteHaveCodeTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppDesign.textTheme.labelLarge?.copyWith(
                          color: AppDesign.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppDesign.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
