part of 'home_screen.dart';

/// The invite card on the home screen, and when it may show. See
/// InvitePrompt for the record and the backend's numbers.
///
/// It waits for a calm screen with a checked tunnel, as the rating card and
/// the Premium card do, and gives way to both: the rating card first, the
/// Premium card second, this one last. One card or popup per run, shared
/// with the update dialog, message popups, the notification question and
/// the limit sheet. The limit sheet always keeps priority, because it is
/// the only sign that the daily allowance is spent. The power button comes
/// before all of it: where the card would push the button out of sight, the
/// card gives way for that connection and is not counted.
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

  /// How long the screen must have been calm before the card shows. Longer
  /// than the rating card's and the Premium card's waits, so both go first
  /// when they are due. UI timing, not a rule of the service.
  static const shareCardSettle = Duration(seconds: 20);

  /// The card is on screen.
  bool up = false;

  /// A button waiting for the referral status.
  InviteTarget? busy;

  /// The card is laid out but not drawn, for one frame, to see whether the
  /// power button still fits above it. See [_buttonFits].
  bool trial = false;

  /// The height of the area the power button scrolls in just before the
  /// trial, or null when it cannot be told. During the trial the card takes
  /// no more room than this. A card taller than the whole area could never
  /// let the button fit, and at its full height it would push the screen's
  /// column past its bottom.
  double? trialRoom;

  VpnService? _vpn;
  ConnectFlow? _flow;
  DeviceState? _device;
  AppConfigState? _config;
  Timer? _timer;

  /// The start of the connection the checks last said no for. Nothing that
  /// decides changes during a connection, so it is not asked again until
  /// the next one.
  DateTime? _refusedFor;

  /// Listen for the moment to show the card. Read here, not in build, so
  /// the screen never rebuilds for it and works the same without it.
  void watch(BuildContext context) {
    if (prompt == null) return;
    try {
      final vpn = context.read<VpnService>();
      final flow = context.read<ConnectFlow>();
      final device = context.read<DeviceState?>();
      final config = context.read<AppConfigState?>();
      vpn.addListener(check);
      flow.addListener(check);
      device?.addListener(check);
      config?.addListener(check);
      _vpn = vpn;
      _flow = flow;
      _device = device;
      _config = config;
      check();
    } catch (e) {
      debugPrint('HomeScreen: invite card not watched ($e)');
    }
  }

  /// Start the wait while the screen is calm, and stop it, or take the card
  /// away, as soon as it is not. The wait runs until the tunnel has been up
  /// for the backend's min_session_minutes and the screen calm for
  /// [shareCardSettle], whichever is later. Never throws.
  void check() {
    try {
      final p = prompt;
      if (p == null || !host.mounted) return;
      if (!_HomeScreenState._calmWith(_vpn, _flow)) {
        _timer?.cancel();
        _timer = null;
        if (up) _takeAway();
        return;
      }
      if (up) {
        // Another screen or a sheet opened over the card: it is gone for
        // this run. Counted already when it was drawn.
        final onTop = ModalRoute.of(host.context)?.isCurrent ?? false;
        if (!onTop || host._limitSheetOpen) _takeAway();
        return;
      }
      if (p.shownThisRun || _timer != null) return;
      final upSince = _vpn?.currentConnection?.startTime;
      if (upSince == null || upSince == _refusedFor) return;
      final rules = _device?.device?.invitePrompt;
      if (rules == null) return;
      final untilLongEnough =
          Duration(minutes: rules.minSessionMinutes) -
          DateTime.now().difference(upSince);
      final wait = untilLongEnough > shareCardSettle
          ? untilLongEnough
          : shareCardSettle;
      _timer = Timer(wait, () => unawaited(_ask()));
    } catch (e) {
      debugPrint('HomeScreen: invite card check failed ($e)');
    }
  }

  /// Everything the screen must allow before the card shows, apart from the
  /// records, which take a moment to read.
  bool _mayShow() {
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
    if (context.read<DeviceState?>()?.device?.invitePrompt == null) {
      return false;
    }
    final billing = context.read<BillingState?>();
    if (billing == null) return false;
    if (!host._cardMayShow(vpn, _flow)) return false;
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

  /// Show the card if everything still allows it. The rating card goes
  /// first and the Premium card second when either is due.
  Future<void> _ask() async {
    _timer = null;
    try {
      final p = prompt;
      final vpn = _vpn;
      if (p == null || vpn == null || !_mayShow()) return;
      final upSince = vpn.currentConnection?.startTime;
      final context = host.context;
      final billing = context.read<BillingState?>();
      final rules = context.read<DeviceState?>()?.device?.invitePrompt;
      final review = host._review;
      final ratingOn = context.read<AppConfigState?>()?.flags.reviewPrompt;
      if (await review?.due(enabled: ratingOn ?? false, upSince: upSince) ??
          false) {
        _refusedFor = upSince;
        return;
      }
      if (billing != null &&
          billing.upsellOn(UpsellSurface.calmCard) &&
          (await host._premiumPrompt?.due(billing) ?? false)) {
        _refusedFor = upSince;
        return;
      }
      final ratingDay = await review?.lastAskDay();
      if (!await p.due(
        rules: rules,
        upSince: upSince,
        ratingAskDay: ratingDay,
      )) {
        _refusedFor = upSince;
        return;
      }
      // The answers took a moment. Anything that changed meanwhile wins.
      if (!_mayShow()) return;
      // Laid out first without being drawn: on a short screen, or with a
      // large font, the card would push the power button out of sight, and
      // the power button always comes first. Then the card gives way for
      // this connection and is not counted.
      up = true;
      trial = true;
      trialRoom = _scrollAreaHeight();
      onChanged();
      await WidgetsBinding.instance.endOfFrame;
      if (!host.mounted || !up) return;
      trial = false;
      trialRoom = null;
      if (!_buttonFits()) {
        _refusedFor = upSince;
        _takeAway();
        return;
      }
      onChanged();
      _log(InviteAction.shown);
      await p.shown();
    } catch (e) {
      debugPrint('HomeScreen: invite card failed ($e)');
    }
  }

  void _takeAway() {
    up = false;
    trial = false;
    trialRoom = null;
    busy = null;
    onChanged();
  }

  /// The height of the area the power button scrolls in, or null when it
  /// cannot be told.
  double? _scrollAreaHeight() {
    final button = host._powerFocus.context;
    if (button == null) return null;
    final view = Scrollable.maybeOf(button)?.context.findRenderObject();
    if (view is! RenderBox || !view.hasSize) return null;
    return view.size.height;
  }

  /// Whether the power button is wholly inside the area it scrolls in, so
  /// nothing under that area cuts it off. True when it cannot be told.
  bool _buttonFits() {
    final button = host._powerFocus.context;
    if (button == null) return true;
    final box = button.findRenderObject();
    final view = Scrollable.maybeOf(button)?.context.findRenderObject();
    if (box is! RenderBox || view is! RenderBox) return true;
    if (!box.hasSize || !view.hasSize) return true;
    final b = box.localToGlobal(Offset.zero) & box.size;
    final v = view.localToGlobal(Offset.zero) & view.size;
    return b.top >= v.top - 0.5 && b.bottom <= v.bottom + 0.5;
  }

  void _log(InviteAction action) {
    try {
      if (!host.mounted) return;
      host.context.read<InviteEvents?>()?.log(
        InviteSurface.afterConnect,
        action,
      );
    } catch (e) {
      debugPrint('HomeScreen: invite event not kept ($e)');
    }
  }

  /// A tap on one of the card's buttons. The referral status, which mints
  /// the code, loads on the first tap, with a spinner on that button. No
  /// share target opens without both the code and the link. A share or a
  /// copy ends the card for good. Never throws.
  Future<void> tap(BuildContext context, InviteTarget target) async {
    if (busy != null || !up) return;
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
    if (!up) return;
    _takeAway();
    _log(InviteAction.dismissed);
  }

  /// The card, for the screen's notices.
  Widget card() => _InviteCardView(owner: this);

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _vpn?.removeListener(check);
    _flow?.removeListener(check);
    _device?.removeListener(check);
    _config?.removeListener(check);
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
    Widget card = InviteCard(
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
    final room = owner.trialRoom;
    if (owner.trial && room != null) {
      // Laid out at its full height, but taking at most the whole scroll
      // area: the button then cannot fit either way, and the screen's
      // column stays inside the screen. Nothing of it is drawn.
      card = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: room),
        child: UnconstrainedBox(
          constrainedAxis: Axis.horizontal,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child: card,
        ),
      );
    }
    return Visibility(
      visible: !owner.trial,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: card,
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
    if (!show) return const SizedBox.shrink();
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
