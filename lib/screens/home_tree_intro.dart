part of 'home_screen.dart';

/// The introduction to the invite tree, opened by itself once per install
/// on the home screen, at the first calm moment of a run in which the app
/// knows the tree rule is on.
///
/// The app learns the rule from the app config (FeatureFlags.referralRules),
/// or from a referral answer already loaded in this run. The referral
/// answer itself is not asked for at launch: its first read mints the
/// device's invite code, and a phone that never opens the invite screen
/// should never use one. So under today's rule, or when the rule is not
/// known, nothing here asks the backend anything. Under the tree rule the
/// answer is loaded once, just before the story opens, because the story is
/// built from the user's own numbers.
///
/// The story waits for the same calm screen as a message popup, and gives
/// way to everything that comes before it: the update dialog, the limit
/// sheet and a message popup. It counts as the run's one popup, so the
/// notification question, the rating card, the calm Premium card and the
/// invite card wait for the next run once it has opened. Before it opens,
/// the invite card also gives way, at both of its moments, while the story
/// may still open in this run ([pending]). It never opens on a TV, in the
/// run that asked for the language (that run is for the first connect), or
/// while the phone has Premium, because friends' data adds nothing while
/// data is unlimited.
///
/// Every provider is read nullable. Without the record that keeps it to
/// once, the config or the referral state, the story never opens, so the
/// home screen built without them (as in its own tests) shows none.
class _HomeTreeIntro {
  _HomeTreeIntro({required this.host, required this.record});

  /// The screen, for its gates.
  final _HomeScreenState host;

  /// Null when there is no InviteTreeIntroRecord above the screen.
  final InviteTreeIntroRecord? record;

  VpnService? _vpn;
  ConnectFlow? _flow;
  AppConfigState? _config;
  ReferralState? _referrals;
  BillingState? _billing;
  DedicatedState? _dedicated;
  Timer? _timer;

  /// This run has settled the story: it opened, it was seen before, or
  /// this run found that it does not open (the referral answer could not
  /// be loaded, or it says the tree rule is not on).
  bool _settled = false;

  /// The referral answer was loaded for the story in this run. It is
  /// loaded at most once per run.
  bool _loaded = false;

  /// The last look before opening is under way.
  bool _busy = false;

  /// Whether the story opened in this run, here or anywhere else.
  bool get shownThisRun => record?.shownThisRun ?? false;

  /// Whether the story is about to open by itself, so a popup that would
  /// come before it on a quick timer waits for it. Only while it can open
  /// now: the tree rule is known, the tunnel is up and checked, and nothing
  /// that lasts the run keeps it closed. A phone that cannot connect, or a
  /// run that already had its popup, never holds the notification question
  /// back.
  bool get waiting =>
      record != null &&
      !_settled &&
      !shownThisRun &&
      _treeKnown() &&
      _calm() &&
      !_blockedForRun();

  /// Whether the story may still open by itself in this run, or has
  /// opened: the tree rule is known, this run has not settled the story,
  /// and nothing that lasts the run keeps it closed. Unlike [waiting] it
  /// does not ask for a calm screen now, because the story may open at the
  /// next calm moment of the run. The invite card gives way meanwhile, at
  /// both of its moments, so its shorter waits never take the story's turn.
  bool get pending =>
      shownThisRun ||
      (record != null && !_settled && _treeKnown() && !_blockedForRun());

  /// Whether the last look before the story opens is under way, with the
  /// referral answer it loads perhaps still on its way. Its end looks at
  /// the invite card again.
  bool get deciding => _busy;

  /// Listen for the moment to open the story. Read here, not in build, so
  /// the screen never rebuilds for it and works the same without it.
  void watch(BuildContext context) {
    final record = this.record;
    if (record == null) return;
    // The first run is for the first connect.
    if (LanguageSetupScreen.shownThisRun || FormFactor.isTv) {
      _settled = true;
      return;
    }
    try {
      final config = context.read<AppConfigState?>();
      final referrals = context.read<ReferralState?>();
      if (config == null || referrals == null) {
        _settled = true;
        return;
      }
      final vpn = context.read<VpnService>();
      final flow = context.read<ConnectFlow>();
      final billing = context.read<BillingState?>();
      final dedicated = context.read<DedicatedState?>();
      for (final source in <Listenable?>[
        vpn,
        flow,
        config,
        referrals,
        billing,
        dedicated,
      ]) {
        source?.addListener(check);
      }
      _vpn = vpn;
      _flow = flow;
      _config = config;
      _referrals = referrals;
      _billing = billing;
      _dedicated = dedicated;
      // Seen on this install already: nothing more to do in this run.
      unawaited(
        record.seen().then((seen) {
          if (seen) {
            _settled = true;
            _timer?.cancel();
            _timer = null;
          }
        }),
      );
      check();
    } catch (e) {
      debugPrint('HomeScreen: invite tree introduction not watched ($e)');
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    for (final source in <Listenable?>[
      _vpn,
      _flow,
      _config,
      _referrals,
      _billing,
      _dedicated,
    ]) {
      source?.removeListener(check);
    }
  }

  /// Whether this run knows the tree rule is on: invites are on, and the
  /// config or a referral answer loaded in this run says tree.
  bool _treeKnown() {
    final config = _config;
    if (config == null || !config.referralsEnabled) return false;
    if (config.inviteTreeOn) return true;
    return _referrals?.status?.isTree ?? false;
  }

  /// The home screen is at rest: the app in front, the tunnel up and
  /// checked, nothing in progress, and no checklist, failure, warning or
  /// permission request on screen.
  bool _calm() {
    final vpn = _vpn;
    if (vpn == null || !_HomeScreenState._calmWith(vpn, _flow)) return false;
    return vpn.errorMessage == null &&
        vpn.privateDnsHost == null &&
        !vpn.awaitingPermission;
  }

  /// Something that lasts the whole run keeps the story closed: a TV,
  /// Premium, or another popup or card that has shown in this run (the
  /// update dialog, a message, the limit sheet, the notification question,
  /// the rating card, the calm Premium card or the invite card). The limit
  /// sheet goes first, and has its own way into the story.
  bool _blockedForRun() {
    if (FormFactor.isTv) return true;
    if (_billing?.premium.active ?? false) return true;
    if (UpdateDialog.shownThisRun) return true;
    if (host._messages?.poppedThisRun ?? false) return true;
    if (host._limitSheetShownThisRun) return true;
    if (NoticePermissionPrompt.instance.askedThisRun) return true;
    if (host._review?.askedThisRun ?? false) return true;
    if (host._premiumPrompt?.shownThisRun ?? false) return true;
    if (host._invite.prompt?.shownThisRun ?? false) return true;
    return false;
  }

  /// Something on the home screen now, or about to be, that the story
  /// waits for: another page, the update dialog or a message on top, a
  /// message about to pop up, the limit sheet, used up data, or a card.
  bool _busyNow() {
    if (!(ModalRoute.of(host.context)?.isCurrent ?? false)) return true;
    if (UpdateDialog.isShowing || MessageDialog.isShowing) return true;
    if (host._messages?.pendingPopup != null) return true;
    if (host._limitSheetOpen) return true;
    if (_dedicated?.isBlocked ?? false) return true;
    if (host._calmCardUp || host._invite.up) return true;
    return false;
  }

  /// This run will not open the story: stop looking, and let the
  /// notification question, which waited for it, have its turn.
  void _giveUpForRun() {
    _settled = true;
    _timer?.cancel();
    _timer = null;
    host._checkNoticePrompt();
  }

  /// Start the wait while the screen is calm under the tree rule, and stop
  /// it as soon as it is not, so it starts again from the beginning. The
  /// wait is the message popup's ([_HomeScreenState.popupSettle]). Never
  /// throws.
  void check() {
    try {
      if (_settled || _busy || !host.mounted || record == null) return;
      if (!_treeKnown() || !_calm()) {
        _timer?.cancel();
        _timer = null;
        return;
      }
      _timer ??= Timer(_HomeScreenState.popupSettle, () => unawaited(_due()));
    } catch (e) {
      debugPrint('HomeScreen: invite tree introduction check failed ($e)');
    }
  }

  /// Look again after another wait, while the screen stays calm: something
  /// else had the screen, and nothing reports when it goes.
  void _again() {
    if (_settled || !host.mounted || !_treeKnown() || !_calm()) return;
    _timer ??= Timer(_HomeScreenState.popupSettle, () => unawaited(_due()));
  }

  /// The wait is over: load the referral answer if this run has none, and
  /// open the story if everything still allows it and the answer says
  /// tree. Never throws.
  Future<void> _due() async {
    _timer = null;
    final record = this.record;
    final referrals = _referrals;
    if (_settled || _busy || !host.mounted) return;
    if (record == null || referrals == null) return;
    if (!_treeKnown() || !_calm()) return;
    if (_blockedForRun()) {
      _giveUpForRun();
      return;
    }
    if (_busyNow()) {
      _again();
      return;
    }
    _busy = true;
    var retry = false;
    try {
      if (await record.seen()) {
        _settled = true;
        return;
      }
      if (referrals.status == null) {
        if (_loaded) {
          _settled = true;
          return;
        }
        _loaded = true;
        await referrals.refresh();
      }
      final status = referrals.status;
      if (status == null || !status.isTree) {
        // The answer could not be loaded, or it says the tree rule is not
        // on. Nothing opens, the record stays unset, and the next run of
        // the app looks again.
        _settled = true;
        return;
      }
      if (!host.mounted) return;
      if (_blockedForRun()) {
        _giveUpForRun();
        return;
      }
      if (!_treeKnown() || !_calm() || _busyNow()) {
        retry = true;
        return;
      }
      _settled = true;
      _timer?.cancel();
      _timer = null;
      await InviteTreeIntroScreen.open(host.context);
    } catch (e) {
      debugPrint('HomeScreen: invite tree introduction not opened ($e)');
    } finally {
      _busy = false;
      if (retry) _again();
      // The invite card may have waited for this look (see [deciding]).
      if (host.mounted) host._invite.check();
    }
  }
}
