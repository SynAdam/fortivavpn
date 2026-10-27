import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/referral_service.dart';
import '../core/design_system.dart';
import '../core/form_factor.dart';
import '../core/haptics.dart';
import '../core/page_transitions.dart';
import '../core/state/invite_events.dart';
import '../core/state/invite_prompt.dart';
import '../core/state/invite_tree_intro.dart';
import '../core/state/referral_state.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/number_localizer.dart';
import '../widgets/invite_send.dart';
import '../widgets/invite_slots.dart';
import '../widgets/readable_width.dart';
import 'invite_tree_questions_screen.dart';

/// The introduction to the invite tree, step by step: the user's code and
/// slots, how a friend takes a slot, what each pair adds, a friend who
/// stops, what happens when the slots are full, people the user did not
/// invite (only for a user who joined with a code), the user's data from
/// friends now, and a last step to share the invite.
///
/// It exists only under the tree rule (ReferralStatus.isTree). Under
/// today's rule nothing opens it, and a status that stops being a tree
/// status while it is open closes it. Every amount, day and hour on it is
/// the backend's, from the referral answer, and each has a line that names
/// no number for when the backend sent none. The drawings are built from
/// the user's own answer.
///
/// The words talk about friends, slots, pairs and data. They never talk
/// about levels or ranks, never put people under or below the user, and
/// never say anyone earns or pays.
class InviteTreeIntroScreen extends StatefulWidget {
  const InviteTreeIntroScreen({super.key});

  /// Open the story over [context]. It is noted as seen before it opens,
  /// so a story that crashes never opens by itself on every visit. Never
  /// throws.
  static Future<void> open(BuildContext context) async {
    try {
      await context.read<InviteTreeIntroRecord?>()?.markSeen();
      if (!context.mounted) return;
      context.read<InviteEvents?>()?.log(
        InviteSurface.treeIntro,
        InviteAction.shown,
      );
      final Route<dynamic> route = AppMotion.reduced(context)
          ? PageRouteBuilder<dynamic>(
              pageBuilder: (_, _, _) =>
                  const ReadableWidth(child: InviteTreeIntroScreen()),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            )
          : SlideUpFadeTransition(page: const InviteTreeIntroScreen());
      await Navigator.of(context).push<dynamic>(route);
    } catch (e) {
      debugPrint('InviteTreeIntroScreen: not opened ($e)');
    }
  }

  @override
  State<InviteTreeIntroScreen> createState() => _InviteTreeIntroScreenState();
}

/// Why the story closed, for its events.
enum _Exit { skip, done, shared, gone }

/// The steps of the story, in their order. [others] is only for a user who
/// joined with someone's code, because only their first pair can hold
/// people they did not invite.
enum _Step {
  slots(Duration(milliseconds: 1500)),
  join(Duration(milliseconds: 2400)),
  pairs(Duration(milliseconds: 1200)),
  active(Duration(milliseconds: 2400)),
  full(Duration(milliseconds: 2400)),
  others(Duration(milliseconds: 1800)),
  total(Duration(milliseconds: 1200)),
  share(Duration(milliseconds: 600));

  const _Step(this.play);

  /// How long the step's drawing plays when the step comes into view.
  final Duration play;
}

class _InviteTreeIntroScreenState extends State<InviteTreeIntroScreen>
    with TickerProviderStateMixin {
  final PageController _pages = PageController();

  /// The steps, built once from the first status the story sees and kept
  /// while it is open, so a page never moves under the user.
  List<_Step> _steps = const [];
  List<AnimationController> _drawings = const [];

  int _page = 0;
  bool _started = false;
  bool _reduced = false;
  bool _sharing = false;
  bool _leaving = false;
  _Exit? _exit;

  int get _count => _steps.length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_steps.isEmpty) {
      final status = context.read<ReferralState>().status;
      _steps = [
        _Step.slots,
        _Step.join,
        _Step.pairs,
        _Step.active,
        _Step.full,
        if (status?.hasClaimed ?? false) _Step.others,
        _Step.total,
        _Step.share,
      ];
      _drawings = [
        for (final step in _steps)
          AnimationController(vsync: this, duration: step.play),
      ];
    }
    _reduced = AppMotion.reduced(context);
    if (_reduced) {
      // Every drawing in its final frame, and nothing moves.
      for (final drawing in _drawings) {
        drawing.stop();
        drawing.value = 1;
      }
    } else if (!_started) {
      unawaited(_drawings[_page].forward(from: 0));
    }
    _started = true;
  }

  @override
  void dispose() {
    for (final drawing in _drawings) {
      drawing.dispose();
    }
    _pages.dispose();
    super.dispose();
  }

  void _log(InviteAction action) {
    try {
      context.read<InviteEvents?>()?.log(InviteSurface.treeIntro, action);
    } catch (e) {
      debugPrint('InviteTreeIntroScreen: event not kept ($e)');
    }
  }

  /// The page in view changed, by a button or a swipe: its drawing plays
  /// from the start, and the one that left goes back to its first frame.
  void _onPageChanged(int page) {
    AppHaptics.selection();
    final left = _page;
    setState(() => _page = page);
    if (_reduced) return;
    if (left != page) _drawings[left].value = 0;
    unawaited(_drawings[page].forward(from: 0));
  }

  /// What the next friend adds, as the backend says, or null when it does
  /// not say or invites add no more.
  String? _nextFriend(ReferralStatus status, bool noMore) {
    final next = status.nextInviteBytes;
    if (noMore || next == null) return null;
    return S.of(context)!.inviteTreeNext(inviteAmountText(context, next));
  }

  void _goTo(int page) {
    if (page < 0 || page >= _count) return;
    if (_reduced) {
      _pages.jumpToPage(page);
    } else {
      unawaited(
        _pages.animateToPage(
          page,
          duration: AppMotion.slow,
          curve: AppMotion.standard,
        ),
      );
    }
  }

  void _close(_Exit exit) {
    if (_exit != null) return;
    _exit = exit;
    Navigator.of(context).maybePop();
  }

  /// The story is closing, by a button or by the system's back. Skip, or
  /// back before the last page, notes that the story was left early.
  void _onPop(bool didPop, Object? result) {
    if (!didPop) return;
    final exit = _exit;
    if (exit == _Exit.skip || (exit == null && _page < _count - 1)) {
      _log(InviteAction.dismissed);
    }
  }

  Future<void> _share(ReferralStatus status) async {
    if (_sharing) return;
    _sharing = true;
    try {
      final opened = await sendInvite(context, status);
      if (!mounted || !opened) return;
      _log(InviteAction.otherApps);
      try {
        unawaited(context.read<InvitePrompt?>()?.shared());
      } catch (e) {
        debugPrint('InviteTreeIntroScreen: invite card not ended ($e)');
      }
      _close(_Exit.shared);
    } finally {
      _sharing = false;
    }
  }

  /// The drawing's height: about a third of the screen, less on a short
  /// screen or with large text ([_compact]), so the words under it keep
  /// their room.
  static double _artHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    if (_compact(context)) return 112;
    return (media.size.height * 0.30).clamp(160, 260).toDouble();
  }

  Widget _pageFor(
    int index,
    _Step step,
    ReferralStatus status,
    bool noMore,
    bool belowKept,
    double art,
  ) {
    final play = _drawings[index];
    final key = Key('invite-tree-intro-art-$index');
    return switch (step) {
      _Step.slots => _SlotsPage(
        artKey: key,
        status: status,
        play: play,
        artHeight: art,
      ),
      _Step.join => _JoinPage(
        artKey: key,
        status: status,
        play: play,
        artHeight: art,
      ),
      _Step.pairs => _PairsPage(
        artKey: key,
        status: status,
        play: play,
        artHeight: art,
      ),
      _Step.active => _ActivePage(
        artKey: key,
        status: status,
        play: play,
        artHeight: art,
      ),
      _Step.full => _FullPage(
        artKey: key,
        status: status,
        noMore: noMore,
        play: play,
        artHeight: art,
      ),
      _Step.others => _OthersPage(artKey: key, play: play, artHeight: art),
      _Step.total => _TotalPage(
        artKey: key,
        status: status,
        noMore: noMore,
        belowKept: belowKept,
        play: play,
        artHeight: art,
      ),
      _Step.share => _SharePage(
        artKey: key,
        status: status,
        nextFriend: _compact(context) ? _nextFriend(status, noMore) : null,
        play: play,
        artHeight: art,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final referrals = context.watch<ReferralState>();
    final status = referrals.status;
    if (status == null || !status.isTree) {
      // The tree rule is gone, or the status with it: nothing here is
      // true any more.
      if (!_leaving) {
        _leaving = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _close(_Exit.gone);
        });
      }
      return const Scaffold(backgroundColor: AppDesign.canvas);
    }
    final art = _artHeight(context);
    final last = _page == _count - 1;
    final noMore = referrals.invitesAddNoMore;
    final tv = FormFactor.isTv;

    final bottom = _BottomBar(
      page: _page,
      count: _count,
      // On a small screen the line goes in the page instead, so the bar
      // leaves the words of the last step their room.
      nextFriend: _compact(context) ? null : _nextFriend(status, noMore),
      onBack: () => _goTo(_page - 1),
      onNext: () => _goTo(_page + 1),
      onDone: () => _close(_Exit.done),
      onShare: () => unawaited(_share(status)),
      onQuestions: () => unawaited(InviteTreeQuestionsScreen.open(context)),
    );

    return PopScope<Object?>(
      onPopInvokedWithResult: _onPop,
      child: Scaffold(
        backgroundColor: AppDesign.canvas,
        body: SafeArea(
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: l10n.inviteTreeIntroTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopRow(
                  page: _page,
                  count: _count,
                  reduced: _reduced,
                  skipHidden: last,
                  onSkip: () => _close(_Exit.skip),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppDesign.space24,
                    end: AppDesign.space24,
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      NumberLocalizer.localize(
                        l10n.inviteTreeIntroStep(_page + 1, _count),
                        context,
                      ),
                      key: const Key('invite-tree-intro-step'),
                      style: AppDesign.textTheme.labelMedium?.copyWith(
                        color: AppDesign.textTertiary,
                        fontFeatures: AppDesign.numberFeatures,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppDesign.space12),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    onPageChanged: _onPageChanged,
                    physics: tv ? const NeverScrollableScrollPhysics() : null,
                    children: [
                      for (final (i, step) in _steps.indexed)
                        _pageFor(
                          i,
                          step,
                          status,
                          noMore,
                          referrals.nextFriendBelowKept,
                          art,
                        ),
                    ],
                  ),
                ),
                // The last step's bar is taller. It grows into place, unless
                // the phone asks for less motion: AnimatedSize with no
                // duration relays itself out during layout.
                if (_reduced)
                  bottom
                else
                  AnimatedSize(
                    duration: AppMotion.slow,
                    curve: AppMotion.standard,
                    alignment: Alignment.bottomCenter,
                    child: bottom,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The progress segments and Skip.
class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.page,
    required this.count,
    required this.reduced,
    required this.skipHidden,
    required this.onSkip,
  });

  final int page;
  final int count;
  final bool reduced;
  final bool skipHidden;
  final VoidCallback onSkip;

  static const double _barHeight = 4;
  static const double _rowHeight = 48;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _rowHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppDesign.space24,
          end: AppDesign.space8,
        ),
        child: Row(
          children: [
            Expanded(
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 0; i < count; i++) ...[
                      if (i > 0) const SizedBox(width: AppDesign.space4),
                      Expanded(
                        child: _Segment(
                          key: Key('invite-tree-intro-progress-$i'),
                          state: i < page
                              ? _SegmentState.past
                              : i == page
                              ? _SegmentState.current
                              : _SegmentState.later,
                          reduced: reduced,
                          height: _barHeight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppDesign.space12),
            Visibility(
              visible: !skipHidden,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: TextButton(
                key: const Key('invite-tree-intro-skip'),
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: AppDesign.textSecondary,
                  minimumSize: const Size(48, 48),
                ),
                child: Text(
                  l10n.inviteTreeIntroSkip,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SegmentState { past, current, later }

/// One step of the progress: full for a step already seen, empty for one
/// still to come, and filling from the start for the step in view.
class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.state,
    required this.reduced,
    required this.height,
  });

  final _SegmentState state;
  final bool reduced;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDesign.radiusFull);
    Widget fill(double share) => FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: share,
      heightFactor: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppDesign.steelLight,
          borderRadius: radius,
        ),
      ),
    );
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppDesign.steelDark,
          borderRadius: radius,
        ),
        child: switch (state) {
          _SegmentState.past => fill(1),
          _SegmentState.later => const SizedBox.expand(),
          _SegmentState.current => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: reduced ? Duration.zero : AppMotion.slow,
            curve: AppMotion.emphasizedDecelerate,
            builder: (_, share, _) => fill(share),
          ),
        },
      ),
    );
  }
}

/// Back and Next, or on the last page the next friend's line, Share, Back
/// and Done. It never scrolls away.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.page,
    required this.count,
    required this.nextFriend,
    required this.onBack,
    required this.onNext,
    required this.onDone,
    required this.onShare,
    required this.onQuestions,
  });

  final int page;
  final int count;
  final String? nextFriend;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onDone;
  final VoidCallback onShare;

  /// Opens the questions, from the last step. It sits in the bar, so it
  /// never scrolls away.
  final VoidCallback onQuestions;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final last = page == count - 1;
    final back = Visibility(
      visible: page > 0,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: TextButton(
        key: const Key('invite-tree-intro-back'),
        onPressed: onBack,
        style: TextButton.styleFrom(
          foregroundColor: AppDesign.textSecondary,
          minimumSize: const Size(48, 48),
        ),
        child: Text(
          l10n.inviteTreeIntroBack,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDesign.space24,
        AppDesign.space12,
        AppDesign.space24,
        AppDesign.space16,
      ),
      child: last
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (nextFriend case final line?) ...[
                  Text(
                    line,
                    key: const Key('invite-tree-intro-next-friend'),
                    textAlign: TextAlign.center,
                    style: AppDesign.textTheme.bodyMedium?.copyWith(
                      color: AppDesign.textSecondary,
                      fontFeatures: AppDesign.numberFeatures,
                    ),
                  ),
                  const SizedBox(height: AppDesign.space12),
                ],
                FilledButton.icon(
                  key: const Key('invite-tree-intro-share'),
                  onPressed: onShare,
                  autofocus: FormFactor.isTv,
                  icon: const Icon(Icons.share_rounded, size: 20),
                  label: Text(
                    l10n.inviteShareAction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppDesign.brand,
                    foregroundColor: AppDesign.onBrand,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: AppDesign.space4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: back),
                    const SizedBox(width: AppDesign.space4),
                    Expanded(
                      flex: 2,
                      child: TextButton(
                        key: const Key('invite-tree-intro-questions'),
                        onPressed: onQuestions,
                        style: TextButton.styleFrom(
                          foregroundColor: AppDesign.brandBright,
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDesign.space8,
                          ),
                        ),
                        child: Text(
                          l10n.inviteTreeQaTitle,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDesign.space4),
                    Flexible(
                      child: TextButton(
                        key: const Key('invite-tree-intro-done'),
                        onPressed: onDone,
                        style: TextButton.styleFrom(
                          foregroundColor: AppDesign.textPrimary,
                          minimumSize: const Size(48, 48),
                        ),
                        child: Text(
                          l10n.inviteTreeIntroDone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: back),
                const SizedBox(width: AppDesign.space12),
                Flexible(
                  flex: 2,
                  // Tonal: Share on the last step stays the one solid button.
                  child: FilledButton(
                    key: const Key('invite-tree-intro-next'),
                    onPressed: onNext,
                    autofocus: FormFactor.isTv,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppDesign.brand.withValues(alpha: 0.15),
                      foregroundColor: AppDesign.brandBright,
                      minimumSize: const Size(120, 52),
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppDesign.space24,
                        0,
                        AppDesign.space16,
                        0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            l10n.inviteTreeIntroNext,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppDesign.space8),
                        const Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// One step: the drawing, the title, the words as paragraphs, and the
/// notes under them. Every page scrolls.
/// While more of it is below the fold, a scroll bar shows and the bottom
/// edge fades into the canvas, so the page never looks finished when it
/// is not.
class _Page extends StatefulWidget {
  const _Page({
    required this.art,
    required this.title,
    required this.body,
    this.notes = const [],
  });

  final Widget art;
  final String title;
  final List<String> body;
  final List<(IconData, String, Key)> notes;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  final ScrollController _scroll = ScrollController();

  /// Whether the page is longer than its room, and whether more of it is
  /// below what shows.
  bool _scrollable = false;
  bool _more = false;

  /// The height of the fade at the bottom edge.
  static const double _fade = 24;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_look);
    WidgetsBinding.instance.addPostFrameCallback((_) => _look());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _look() {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (!position.hasContentDimensions) return;
    final scrollable = position.maxScrollExtent > 0.5;
    final more = position.extentAfter > 0.5;
    if (scrollable != _scrollable || more != _more) {
      setState(() {
        _scrollable = scrollable;
        _more = more;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = AppDesign.textTheme.bodyLarge?.copyWith(
      color: AppDesign.textSecondary,
      fontFeatures: AppDesign.numberFeatures,
    );
    final page = SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        AppDesign.space24,
        0,
        AppDesign.space24,
        AppDesign.space16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          widget.art,
          const SizedBox(height: AppDesign.space24),
          Semantics(
            header: true,
            child: Text(
              widget.title,
              style: AppDesign.textTheme.headlineSmall?.copyWith(
                color: AppDesign.textPrimary,
              ),
            ),
          ),
          for (final (i, paragraph) in widget.body.indexed) ...[
            const SizedBox(height: AppDesign.space8),
            Text(
              paragraph,
              key: i == 0 ? const Key('invite-tree-intro-body') : null,
              style: style,
            ),
          ],
          for (final (i, (icon, text, key)) in widget.notes.indexed) ...[
            SizedBox(height: i == 0 ? AppDesign.space16 : AppDesign.space12),
            Row(
              key: key,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon, size: 18, color: AppDesign.steelLight),
                ),
                const SizedBox(width: AppDesign.space12),
                Expanded(
                  child: Text(
                    text,
                    style: AppDesign.textTheme.bodySmall?.copyWith(
                      color: AppDesign.textTertiary,
                      fontFeatures: AppDesign.numberFeatures,
                    ),
                  ),
                ),
              ],
            ),
          ],
          // Room for the fade, so the last line can scroll clear of it.
          const SizedBox(height: _fade / 2),
        ],
      ),
    );
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _look());
        return false;
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: _scrollable,
              child: page,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _fade,
            child: IgnorePointer(
              child: AnimatedOpacity(
                key: const Key('invite-tree-intro-fade'),
                opacity: _more ? 1 : 0,
                duration: AppMotion.reduced(context)
                    ? Duration.zero
                    : AppMotion.quick,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppDesign.canvas.withValues(alpha: 0),
                        AppDesign.canvas,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The card a drawing sits on, with a soft glow behind its focal point.
/// [focus] is that point as a share of the card's width and height, from
/// the start side. The glow does not move; its color carries any fade.
class _ArtCard extends StatelessWidget {
  const _ArtCard({
    super.key,
    required this.height,
    required this.child,
    this.glow,
    this.focus = const Offset(0.5, 0.5),
    this.grows = false,
  });

  final double height;
  final Widget child;
  final Color? glow;
  final Offset focus;

  /// The card is at least [height] tall and grows with what it holds,
  /// for a card of words rather than a drawing.
  final bool grows;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final glow = this.glow;
    final x = rtl ? 1 - 2 * focus.dx : 2 * focus.dx - 1;
    final card = DecoratedBox(
      decoration: const BoxDecoration(color: AppDesign.surfaceLow),
      child: Stack(
        children: [
          if (glow != null)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(x, 2 * focus.dy - 1),
                    radius: 0.9,
                    colors: [
                      glow,
                      glow.withValues(alpha: glow.a * 0.35),
                      glow.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ),
          if (grows) child else Positioned.fill(child: child),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: AppDesign.borderRadiusXLarge,
      child: grows
          ? ConstrainedBox(
              constraints: BoxConstraints(minHeight: height),
              child: card,
            )
          : SizedBox(height: height, child: card),
    );
  }
}

/// A drawing for screen readers: one label for what it shows, and nothing
/// read from inside it.
class _Drawing extends StatelessWidget {
  const _Drawing({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: label,
      child: ExcludeSemantics(child: child),
    );
  }
}

/// The user, as on the invite screen: a gift in an ember disc.
class _YouDisc extends StatelessWidget {
  const _YouDisc({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppDesign.brandContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.card_giftcard_rounded,
        size: size / 2,
        color: AppDesign.brandBright,
      ),
    );
  }
}

/// The plus on the user's disc once data comes in: a small protected disc
/// at the disc's end corner. [show] fades and grows it in.
class _PlusBadge extends StatelessWidget {
  const _PlusBadge({required this.size, required this.show});

  final double size;
  final double show;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.6 + 0.4 * show,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppDesign.protected.withValues(alpha: show),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppDesign.surfaceLow.withValues(alpha: show),
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.add_rounded,
          size: size * 0.75,
          color: AppDesign.onProtected.withValues(alpha: show),
        ),
      ),
    );
  }
}

/// The user's disc with the plus badge at its end corner, shown by
/// [badge], from 0 (none) to 1.
class _YouWithBadge extends StatelessWidget {
  const _YouWithBadge({
    required this.size,
    required this.badgeSize,
    required this.badge,
  });

  final double size;
  final double badgeSize;
  final double badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _YouDisc(size: size),
          if (badge > 0)
            PositionedDirectional(
              end: -badgeSize / 4,
              bottom: -badgeSize / 4,
              child: _PlusBadge(size: badgeSize, show: badge),
            ),
        ],
      ),
    );
  }
}

/// The share of [t] that falls inside [from] to [to], from 0 to 1, eased.
double _part(double t, double from, double to, [Curve curve = Curves.linear]) {
  if (to <= from) return t >= to ? 1 : 0;
  return curve.transform(((t - from) / (to - from)).clamp(0.0, 1.0));
}

/// Mirror [x] across a box [width] wide when the text runs right to left.
double _mirror(double x, double width, bool rtl) => rtl ? width - x : x;

/// [look] with every color at [alpha] of its own alpha.
SlotLook _fade(SlotLook look, double alpha) => SlotLook(
  fill: look.fill.withValues(alpha: look.fill.a * alpha),
  edge: look.edge.withValues(alpha: look.edge.a * alpha),
  icon: look.icon,
  iconColor: look.iconColor.withValues(alpha: look.iconColor.a * alpha),
);

/// How strongly a pair further away shows: its colors mixed with the card.
const double _faint = 0.55;

/// [look] as a slot further away draws it: mixed with the card.
SlotLook _faded(SlotLook look) => SlotLook(
  fill: Color.lerp(AppDesign.surfaceLow, look.fill, _faint)!,
  edge: Color.lerp(AppDesign.surfaceLow, look.edge, _faint)!,
  icon: look.icon,
  iconColor: Color.lerp(AppDesign.surfaceLow, look.iconColor, _faint)!,
);

/// The capsule fill of a pair further away.
final Color _fadedFill = Color.lerp(
  AppDesign.surfaceLow,
  AppDesign.surfaceHigh,
  _faint,
)!;

/// Whether the story is drawn small: a short screen, or text at 1.3 times
/// its size or more. The drawings are then shorter, and their captions go
/// under them.
bool _compact(BuildContext context) {
  final media = MediaQuery.of(context);
  return media.size.height < 600 || media.textScaler.scale(10) >= 13;
}

/// Whether a drawing has room for its captions inside it: a card at least
/// 280 wide, drawn at full size. Otherwise they go under the card
/// ([_CaptionKey]), so no drawing is ever left without its words.
bool _captionsFit(BuildContext context, double width) =>
    width >= 280 && !_compact(context);

/// A drawing's captions when they do not fit inside it: each one after a
/// small mark like the point it names, in the drawing's order, under the
/// card. The words wrap; nothing is cut.
class _CaptionKey extends StatelessWidget {
  const _CaptionKey({required this.items});

  final List<(Widget, String, Key)> items;

  @override
  Widget build(BuildContext context) {
    final style = AppDesign.textTheme.labelMedium?.copyWith(
      color: AppDesign.textTertiary,
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppDesign.space8),
      child: Wrap(
        spacing: AppDesign.space16,
        runSpacing: AppDesign.space4,
        children: [
          for (final (mark, text, key) in items)
            Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppDesign.space4,
                      ),
                      child: mark,
                    ),
                  ),
                  TextSpan(text: text),
                ],
              ),
              key: key,
              style: style,
            ),
        ],
      ),
    );
  }
}

/// A drawing on its card with its captions: inside the drawing where they
/// fit, else under the card. [art] gets whether they fit inside.
class _ArtWithCaptions extends StatelessWidget {
  const _ArtWithCaptions({required this.art, required this.captions});

  final Widget Function(bool inside) art;
  final List<(Widget, String, Key)> captions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inside = _captionsFit(context, constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            art(inside),
            if (!inside && captions.isNotEmpty) _CaptionKey(items: captions),
          ],
        );
      },
    );
  }
}

/// A small disc in [look], as a mark in a [_CaptionKey].
Widget _markDisc(SlotLook look) => SlotDisc(look: look, size: 14);

/// A small round mark with [icon], as a mark in a [_CaptionKey].
Widget _markIcon(IconData icon) => Container(
  width: 16,
  height: 16,
  decoration: BoxDecoration(
    color: AppDesign.surfaceHighest,
    shape: BoxShape.circle,
    border: Border.all(color: AppDesign.outlineVariant),
  ),
  child: Icon(icon, size: 10, color: AppDesign.textSecondary),
);

/// A caption under a point of a drawing: centred on [x] (already mirrored),
/// at most two lines.
Widget _caption({
  required double x,
  required double top,
  required double width,
  required String text,
  Key? key,
}) => Positioned(
  left: x - width / 2,
  width: width,
  top: top,
  child: Text(
    text,
    key: key,
    textAlign: TextAlign.center,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: AppDesign.textTheme.labelMedium?.copyWith(
      color: AppDesign.textTertiary,
    ),
  ),
);

/// One connecting line, laid out from the start side: where it starts and
/// ends, and its stroke.
class _Link {
  const _Link(this.from, this.to, this.stroke);

  final Offset from;
  final Offset to;
  final double stroke;
}

/// The lines between the points of a drawing, drawn in from their start.
/// Laid out from the start side; mirrored here for right to left.
class _LinkPainter extends CustomPainter {
  _LinkPainter({
    required this.links,
    required this.drawn,
    required this.direction,
    this.curved = true,
  });

  final List<_Link> links;

  /// How much of each line is drawn, from 0 to 1.
  final double drawn;
  final TextDirection direction;
  final bool curved;

  Path _path(_Link link, double width) {
    final rtl = direction == TextDirection.rtl;
    final from = Offset(_mirror(link.from.dx, width, rtl), link.from.dy);
    final to = Offset(_mirror(link.to.dx, width, rtl), link.to.dy);
    final path = Path()..moveTo(from.dx, from.dy);
    if (curved) {
      final mid = (to.dx - from.dx) / 2;
      path.cubicTo(from.dx + mid, from.dy, to.dx - mid, to.dy, to.dx, to.dy);
    } else {
      path.lineTo(to.dx, to.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (drawn <= 0) return;
    for (final link in links) {
      final PathMetric metric = _path(link, size.width).computeMetrics().first;
      final paint = Paint()
        ..color = AppDesign.outlineVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = link.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(metric.extractPath(0, metric.length * drawn), paint);
    }
  }

  @override
  bool shouldRepaint(_LinkPainter old) =>
      old.drawn != drawn ||
      old.direction != direction ||
      old.curved != curved ||
      old.links.length != links.length ||
      [
        for (final (i, link) in links.indexed)
          link.from != old.links[i].from || link.to != old.links[i].to,
      ].any((changed) => changed);
}

/// The lines of a drawing in one painter layer.
Widget _links(
  List<_Link> links,
  double drawn,
  TextDirection direction, {
  bool curved = true,
}) {
  return Positioned.fill(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _LinkPainter(
          links: links,
          drawn: drawn,
          direction: direction,
          curved: curved,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Step 1: your code and your slots.

class _SlotsPage extends StatelessWidget {
  const _SlotsPage({
    required this.artKey,
    required this.status,
    required this.play,
    required this.artHeight,
  });

  final Key artKey;
  final ReferralStatus status;
  final Animation<double> play;
  final double artHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final slots = status.treeSlots;
    final states = {for (final pair in status.pairs) ...pair.slots};
    final legend = states.any((s) => s != TreeSlot.empty);
    // On a small screen the legend sits inside the card, under the slots,
    // so the words of the step keep their room.
    final inside = legend && _compact(context);
    final key = SlotLegend(
      key: const Key('invite-tree-intro-legend'),
      states: [
        for (final s in TreeSlot.values)
          if (states.contains(s)) s,
      ],
    );
    final drawing = _SlotsArt(
      pairs: status.pairs,
      code: status.code,
      play: play,
      height: artHeight,
    );
    return _Page(
      art: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Drawing(
            label: l10n.inviteTreeIntroSlotsArt,
            child: _ArtCard(
              key: artKey,
              height: artHeight,
              grows: inside,
              glow: AppDesign.brand.withValues(alpha: 0.10),
              focus: const Offset(0.18, 0.5),
              child: inside
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: artHeight, child: drawing),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppDesign.space16,
                            0,
                            AppDesign.space16,
                            AppDesign.space12,
                          ),
                          child: key,
                        ),
                      ],
                    )
                  : drawing,
            ),
          ),
          if (legend && !inside) ...[
            const SizedBox(height: AppDesign.space8),
            key,
          ],
        ],
      ),
      title: l10n.inviteTreeIntroSlotsTitle,
      body: [
        slots > 0
            ? NumberLocalizer.localize(
                l10n.inviteTreeIntroSlotsBody(slots),
                context,
              )
            : l10n.inviteTreeIntroSlotsBodyNoNumber,
      ],
    );
  }
}

class _SlotsArt extends StatelessWidget {
  const _SlotsArt({
    required this.pairs,
    required this.code,
    required this.play,
    required this.height,
  });

  final List<TreePair> pairs;
  final String code;
  final Animation<double> play;
  final double height;

  static const double _youSize = 56;
  static const double _discGap = 4;
  static const double _chipWidth = 120;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final direction = Directionality.of(context);
    final rtl = direction == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : height;
        // One capsule per pair the backend sent, or one example when it
        // sent none. As many as fit the card with a readable disc; on a
        // short card they sit closer together.
        final tight = h < 140;
        final capsulePadding = tight ? 4.0 : 6.0;
        final capsuleGap = tight ? 6.0 : 12.0;
        final margin = tight ? 12.0 : 24.0;
        final wanted = math.max(1, pairs.length);
        var n = wanted;
        double discFor(int n) => math.min(
          32,
          (h - margin - (n - 1) * capsuleGap) / n - 2 * capsulePadding,
        );
        while (n > 1 && discFor(n) < 14) {
          n--;
        }
        final disc = discFor(n);
        final capsuleWidth = 2 * disc + _discGap + 2 * capsulePadding;
        final capsuleHeight = disc + 2 * capsulePadding;
        final stack = n * capsuleHeight + (n - 1) * capsuleGap;
        final top = (h - stack) / 2;
        final capsuleLeft = w * 0.66 - capsuleWidth / 2;

        final labelStyle = AppDesign.textTheme.labelMedium?.copyWith(
          color: AppDesign.textSecondary,
        );
        final labelHeight =
            (labelStyle?.fontSize ?? 12) * (labelStyle?.height ?? 1.4);
        // The code under the user's name, where there is room for it.
        final chip = code.isNotEmpty && _captionsFit(context, w);
        final chipStyle = AppDesign.textTheme.labelMedium?.copyWith(
          color: AppDesign.textPrimary,
          letterSpacing: 1.5,
          fontFeatures: AppDesign.numberFeatures,
        );
        final chipHeight = chip
            ? AppDesign.space4 +
                  (chipStyle?.fontSize ?? 12) * (chipStyle?.height ?? 1.4) +
                  4
            : 0.0;
        final you = Offset(
          w * 0.18,
          h / 2 - (6 + labelHeight + chipHeight) / 2,
        );
        final links = [
          for (var i = 0; i < n; i++)
            _Link(
              Offset(you.dx + _youSize / 2, you.dy),
              Offset(
                capsuleLeft,
                top + i * (capsuleHeight + capsuleGap) + capsuleHeight / 2,
              ),
              1.5,
            ),
        ];
        return AnimatedBuilder(
          animation: play,
          builder: (context, _) {
            final t = play.value;
            Widget slotDisc(int pair, int index, TreeSlot slot) {
              final k = pair * 2 + index;
              final from = math.min(0.30 + 0.08 * k, 0.83);
              final grown = _part(
                t,
                from,
                math.min(1, from + 0.17),
                AppMotion.emphasizedDecelerate,
              );
              // An open slot only grows in; a taken one plays from open to
              // what the backend says it is now.
              return Transform.scale(
                scale: 0.6 + 0.4 * grown,
                child: SlotDisc(
                  look: SlotLook.lerp(
                    SlotLook.of(TreeSlot.empty),
                    SlotLook.of(slot),
                    grown,
                  ),
                  size: disc,
                ),
              );
            }

            final youX = _mirror(you.dx, w, rtl);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                _links(
                  links,
                  _part(t, 0, 0.30, AppMotion.emphasizedDecelerate),
                  direction,
                ),
                Positioned(
                  left: youX - _youSize / 2,
                  top: you.dy - _youSize / 2,
                  child: const _YouDisc(
                    key: Key('invite-tree-intro-you'),
                    size: _youSize,
                  ),
                ),
                Positioned(
                  left: youX - 45,
                  width: 90,
                  top: you.dy + _youSize / 2 + 6,
                  child: Text(
                    l10n.inviteTreeIntroYou,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ),
                if (chip)
                  Positioned(
                    left: youX - _chipWidth / 2,
                    width: _chipWidth,
                    top: you.dy + _youSize / 2 + 6 + labelHeight + 4,
                    child: Center(
                      child: Container(
                        key: const Key('invite-tree-intro-code-chip'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDesign.space8,
                          vertical: AppDesign.space2,
                        ),
                        decoration: BoxDecoration(
                          color: AppDesign.surfaceHigh,
                          borderRadius: BorderRadius.circular(
                            AppDesign.radiusFull,
                          ),
                        ),
                        // The code is Latin letters and digits in every
                        // language, so it always reads left to right.
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: chipStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
                for (var i = 0; i < n; i++)
                  Positioned(
                    left: rtl ? w - capsuleLeft - capsuleWidth : capsuleLeft,
                    top: top + i * (capsuleHeight + capsuleGap),
                    child: PairCapsule(
                      key: Key('invite-tree-intro-pair-$i'),
                      slots: i < pairs.length
                          ? pairs[i].slots
                          : const [TreeSlot.empty, TreeSlot.empty],
                      discSize: disc,
                      gap: _discGap,
                      padding: capsulePadding,
                      labelled: false,
                      discBuilder: (index, slot) => slotDisc(i, index, slot),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2: how a friend takes a slot.

class _JoinPage extends StatelessWidget {
  const _JoinPage({
    required this.artKey,
    required this.status,
    required this.play,
    required this.artHeight,
  });

  final Key artKey;
  final ReferralStatus status;
  final Animation<double> play;
  final double artHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final days = status.confirmActiveDays;
    return _Page(
      art: _ArtWithCaptions(
        captions: [
          (
            _markIcon(Icons.confirmation_number_outlined),
            l10n.inviteTreeIntroJoinStepCode,
            const Key('invite-tree-intro-caption-code'),
          ),
          (
            _markIcon(
              days != null && days >= 1 && days <= _JoinArt._circlesShownMost
                  ? Icons.radio_button_unchecked
                  : Icons.event_available_outlined,
            ),
            l10n.inviteTreeIntroJoinStepUse,
            const Key('invite-tree-intro-caption-use'),
          ),
          (
            _markDisc(SlotLook.of(TreeSlot.joined)),
            l10n.inviteTreeIntroJoinStepSlot,
            const Key('invite-tree-intro-caption-slot'),
          ),
        ],
        art: (inside) => _Drawing(
          label: l10n.inviteTreeIntroJoinArt,
          child: _ArtCard(
            key: artKey,
            height: artHeight,
            glow: AppDesign.brand.withValues(alpha: 0.08),
            focus: const Offset(0.5, 0.45),
            child: _JoinArt(status: status, play: play, captions: inside),
          ),
        ),
      ),
      title: l10n.inviteTreeIntroJoinTitle,
      body: [
        inviteTreeJoinCodeText(context, status.claimWindowHours),
        inviteTreeJoinQualifyText(context, status.confirmActiveDays),
      ],
      notes: [
        (
          Icons.shop_outlined,
          l10n.inviteTreeIntroJoinPlay,
          const Key('invite-tree-intro-note-play'),
        ),
      ],
    );
  }
}

class _JoinArt extends StatelessWidget {
  const _JoinArt({
    required this.status,
    required this.play,
    required this.captions,
  });

  final ReferralStatus status;
  final Animation<double> play;

  /// Whether the captions are drawn inside the drawing. When they are not,
  /// the page shows them under the card.
  final bool captions;

  static const double _stop = 40;
  static const double _circle = 10;
  static const double _circleGap = 5;

  /// The room around the circles inside their capsule, which is as tall
  /// as the other stops.
  static const double _circlePad = (_stop - _circle) / 2;

  /// The most circles the drawing shows in a row, one per day of use. A
  /// layout limit, so the row fits between the other stops: past it, or
  /// with no number, a calendar stands in.
  static const int _circlesShownMost = 5;
  static const double _pairDisc = 24;
  static const double _walker = 20;

  /// The widest a caption gets: a little less than the room between two
  /// stops, so captions in long languages keep to two lines.
  static const double _captionMost = 104;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final direction = Directionality.of(context);
    final rtl = direction == TextDirection.rtl;
    final days = status.confirmActiveDays;
    final circles = days != null && days >= 1 && days <= _circlesShownMost
        ? days
        : null;
    // The first of the user's pairs with an open slot, or a pair further
    // away when every own slot is taken.
    final pairIndex = status.pairs.indexWhere(
      (p) => p.slots.contains(TreeSlot.empty),
    );
    final further = pairIndex < 0;
    final slots = further
        ? const [TreeSlot.empty, TreeSlot.empty]
        : status.pairs[pairIndex].slots;
    final open = math.max(0, slots.indexOf(TreeSlot.empty));
    // The friend lands as someone in the slot, not yet shown as active:
    // whether they are active is the backend's to say, and depends on more
    // than the days that qualified them.
    const ends = TreeSlot.joined;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final captions = this.captions;
        final caption = math.min(_captionMost, w * 0.32);
        final y = h / 2 - (captions ? 14 : 0);
        final s1 = w * 0.16;
        final s2 = w * 0.50;
        final s3 = w * 0.84;
        final rowWidth = circles == null
            ? _stop
            : circles * _circle + (circles - 1) * _circleGap + 2 * _circlePad;
        final rowStart = s2 - rowWidth / 2;
        final rowEnd = s2 + rowWidth / 2;
        const pad = 6.0;
        final capsuleWidth =
            slots.length * _pairDisc + (slots.length - 1) * 4 + 2 * pad;
        const capsuleHeight = _pairDisc + 2 * pad;
        final capsuleLeft = s3 - capsuleWidth / 2;
        final openCentre = capsuleLeft + pad + open * (_pairDisc + 4) + 12;
        final links = [
          _Link(Offset(s1, y), Offset(rowStart, y), 1.5),
          _Link(Offset(rowEnd, y), Offset(capsuleLeft, y), 1.5),
        ];
        // Where the friend appears, waits while the days fill, and lands.
        final p0 = s1 + _stop / 2 + 4 + _walker / 2;
        final p1 = math.max(p0, rowStart - 6 - _walker / 2);
        final p2 = openCentre;
        double left(double x, double width) => _mirror(x, w, rtl) - width / 2;

        return AnimatedBuilder(
          animation: play,
          builder: (context, _) {
            final t = play.value;
            final drawn = _part(t, 0, 0.15, AppMotion.emphasizedDecelerate);
            final appear = _part(t, 0.15, 0.25, AppMotion.emphasizedDecelerate);
            final first = _part(t, 0.25, 0.40, AppMotion.standard);
            final filled = _part(t, 0.40, 0.70);
            final second = _part(t, 0.70, 0.85, AppMotion.standard);
            final land = _part(t, 0.85, 1, AppMotion.standard);
            final x = second > 0
                ? p1 + (p2 - p1) * second
                : p0 + (p1 - p0) * first;
            final walker = appear * (1 - land);

            SlotLook slotLook(TreeSlot slot, int index) {
              final look = index == open
                  ? SlotLook.lerp(
                      SlotLook.of(TreeSlot.empty),
                      SlotLook.of(ends),
                      land,
                    )
                  : SlotLook.of(slot);
              return further ? _faded(look) : look;
            }

            final stopStyle = BoxDecoration(
              color: AppDesign.surfaceHighest,
              shape: BoxShape.circle,
              border: Border.all(color: AppDesign.outlineVariant),
            );
            return Stack(
              clipBehavior: Clip.none,
              children: [
                _links(links, drawn, direction, curved: false),
                Positioned(
                  left: left(s1, _stop),
                  top: y - _stop / 2,
                  child: Container(
                    key: const Key('invite-tree-intro-join-code'),
                    width: _stop,
                    height: _stop,
                    decoration: stopStyle,
                    child: const Icon(
                      Icons.confirmation_number_outlined,
                      size: 20,
                      color: AppDesign.textSecondary,
                    ),
                  ),
                ),
                if (circles != null)
                  Positioned(
                    left: left(s2, rowWidth),
                    top: y - _stop / 2,
                    child: Container(
                      key: const Key('invite-tree-intro-join-days'),
                      height: _stop,
                      padding: const EdgeInsets.symmetric(
                        horizontal: _circlePad,
                      ),
                      decoration: stopStyle.copyWith(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(
                          AppDesign.radiusFull,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < circles; i++) ...[
                            if (i > 0) const SizedBox(width: _circleGap),
                            _DayCircle(
                              key: Key('invite-tree-intro-join-day-$i'),
                              size: _circle,
                              filled: _part(
                                filled,
                                i / circles,
                                (i + 1) / circles,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else
                  Positioned(
                    left: left(s2, _stop),
                    top: y - _stop / 2,
                    child: Container(
                      key: const Key('invite-tree-intro-join-calendar'),
                      width: _stop,
                      height: _stop,
                      decoration: stopStyle,
                      child: Icon(
                        Icons.event_available_outlined,
                        size: 20,
                        color: Color.lerp(
                          AppDesign.textSecondary,
                          AppDesign.protected,
                          filled,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: rtl ? w - capsuleLeft - capsuleWidth : capsuleLeft,
                  top: y - capsuleHeight / 2,
                  child: PairCapsule(
                    key: const Key('invite-tree-intro-join-pair'),
                    slots: slots,
                    discSize: _pairDisc,
                    padding: pad,
                    fill: further ? _fadedFill : AppDesign.surfaceHigh,
                    labelled: false,
                    discBuilder: (index, slot) => SlotDisc(
                      key: Key('invite-tree-intro-join-slot-$index'),
                      look: slotLook(slot, index),
                      size: _pairDisc,
                    ),
                  ),
                ),
                if (walker > 0)
                  Positioned(
                    left: left(x, _walker),
                    top: y - _walker / 2,
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * appear,
                      child: SlotDisc(
                        key: const Key('invite-tree-intro-join-friend'),
                        look: _fade(SlotLook.of(TreeSlot.joined), walker),
                        size: _walker,
                      ),
                    ),
                  ),
                if (captions) ...[
                  _caption(
                    x: _mirror(s1, w, rtl),
                    top: y + _stop / 2 + 8,
                    width: caption,
                    text: l10n.inviteTreeIntroJoinStepCode,
                    key: const Key('invite-tree-intro-caption-code'),
                  ),
                  _caption(
                    x: _mirror(s2, w, rtl),
                    top: y + _stop / 2 + 8,
                    width: caption,
                    text: l10n.inviteTreeIntroJoinStepUse,
                    key: const Key('invite-tree-intro-caption-use'),
                  ),
                  _caption(
                    x: _mirror(s3, w, rtl),
                    top: y + _stop / 2 + 8,
                    width: caption,
                    text: l10n.inviteTreeIntroJoinStepSlot,
                    key: const Key('invite-tree-intro-caption-slot'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

/// One day of use in the step 2 drawing: an empty ring that fills with
/// the protected color as [filled] goes from 0 to 1.
class _DayCircle extends StatelessWidget {
  const _DayCircle({super.key, required this.size, required this.filled});

  final double size;
  final double filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppDesign.protected.withValues(alpha: filled),
        border: Border.all(
          color: Color.lerp(AppDesign.steelMid, AppDesign.protected, filled)!,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3: what each of your pairs adds.

/// Which amount of [pair] is what it adds now, as the backend's now amount
/// says: 2 for the amount with both people active, 1 for the amount with
/// one, or 0 for neither. The app compares the backend's amounts and does
/// no math of its own.
int _highlightOf(TreePair pair) {
  final now = pair.nowBytes;
  if (now == null || now <= 0) return 0;
  if (now == pair.fullBytes) return 2;
  if (now == pair.oneBytes) return 1;
  return 0;
}

class _PairsPage extends StatelessWidget {
  const _PairsPage({
    required this.artKey,
    required this.status,
    required this.play,
    required this.artHeight,
  });

  final Key artKey;
  final ReferralStatus status;
  final Animation<double> play;
  final double artHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final pairs = status.pairs;
    final table = pairs.isNotEmpty && pairs.first.fullBytes != null;
    final active = (
      Icons.event_repeat_outlined,
      inviteTreeActiveText(context, status),
      const Key('invite-tree-intro-note-active'),
    );
    if (table) {
      final lit = pairs.any((p) => _highlightOf(p) > 0);
      // Each pair adds less than the one before it, as the backend's own
      // amounts say. The app only compares them.
      final fulls = [for (final p in pairs) p.fullBytes];
      final order =
          fulls.length > 1 &&
          fulls.every((f) => f != null) &&
          [
            for (var i = 1; i < fulls.length; i++) fulls[i]! < fulls[i - 1]!,
          ].every((less) => less);
      return _Page(
        art: Semantics(
          label: l10n.inviteTreeIntroPairsArt,
          container: true,
          child: _ArtCard(
            key: artKey,
            height: artHeight,
            grows: true,
            glow: AppDesign.protected.withValues(alpha: 0.06),
            focus: const Offset(0.2, 0.3),
            child: _PairsTable(pairs: pairs, play: play),
          ),
        ),
        title: l10n.inviteTreeIntroPairTitle,
        body: [
          l10n.inviteTreeIntroPairsBody,
          if (order) l10n.inviteTreeIntroPairsOrder,
        ],
        notes: [
          active,
          if (lit)
            (
              Icons.highlight_outlined,
              l10n.inviteTreeIntroPairNow,
              const Key('invite-tree-intro-note-now'),
            ),
        ],
      );
    }

    // No pairs, or no amounts for the first: one big pair, as an example.
    final first = pairs.isEmpty ? null : pairs.first;
    final full = first?.fullBytes;
    final one = first?.oneBytes;
    final fullText = full == null ? null : inviteAmountText(context, full);
    final oneText = one == null || one == 0
        ? null
        : inviteAmountText(context, one);
    final body = switch ((fullText, one)) {
      (final String f, final int o) when o > 0 => l10n.inviteTreeIntroPairBoth(
        f,
        oneText!,
      ),
      (final String f, 0) => l10n.inviteTreeIntroPairBothOnly(f),
      (final String f, null) => l10n.inviteTreeIntroPairNoOne(f),
      _ => l10n.inviteTreeHowPair,
    };
    final later = pairs.skip(1).toList();
    final othersLess =
        full != null &&
        later.isNotEmpty &&
        later.every((p) => p.fullBytes != null && p.fullBytes! < full);
    return _Page(
      art: _Drawing(
        label: l10n.inviteTreeIntroPairsArt,
        child: AnimatedBuilder(
          animation: play,
          builder: (context, child) {
            final both = _part(play.value, 0.55, 0.70);
            return _ArtCard(
              key: artKey,
              height: artHeight,
              glow: AppDesign.protected.withValues(alpha: 0.12 * both),
              child: child!,
            );
          },
          child: _PairArt(play: play, rises: true),
        ),
      ),
      title: l10n.inviteTreeIntroPairTitle,
      body: [body],
      notes: [
        active,
        if (othersLess)
          (
            Icons.people_outline_rounded,
            l10n.inviteTreeIntroPairOthersLess,
            const Key('invite-tree-intro-note-others'),
          ),
      ],
    );
  }
}

/// The user's pairs, one row each: the pair's slots in their real states,
/// what it adds a day with both people active, and with one. The amount
/// it adds now is highlighted.
class _PairsTable extends StatelessWidget {
  const _PairsTable({required this.pairs, required this.play});

  final List<TreePair> pairs;
  final Animation<double> play;

  static const double _disc = 24;
  static const double _pad = 6;
  static const double _leading = 2 * _disc + 4 + 2 * _pad;
  static const double _rowHeight = 40;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final head = AppDesign.textTheme.labelSmall?.copyWith(
      color: AppDesign.textTertiary,
    );

    Widget cell(
      String? text, {
      required bool lit,
      required bool quiet,
      required double show,
      required double glow,
      Key? key,
    }) {
      if (text == null) return const SizedBox.shrink();
      final ink = lit
          ? Color.lerp(AppDesign.textPrimary, AppDesign.protected, glow)!
          : quiet
          ? AppDesign.textTertiary
          : AppDesign.textPrimary;
      return Container(
        key: key,
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: AppDesign.space4,
        ),
        decoration: BoxDecoration(
          color: lit
              ? AppDesign.protectedContainer.withValues(alpha: glow * show)
              : null,
          borderRadius: BorderRadius.circular(AppDesign.radiusFull),
        ),
        // One line: an amount never breaks inside its unit. A narrow cell
        // draws it smaller instead.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            style: AppDesign.textTheme.titleSmall?.copyWith(
              color: ink.withValues(alpha: ink.a * show),
              fontFeatures: AppDesign.numberFeatures,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppDesign.space16),
      child: AnimatedBuilder(
        animation: play,
        builder: (context, _) {
          final t = play.value;
          final glow = _part(t, 0.75, 1);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Text(
                  l10n.inviteTreeIntroPairsCaption,
                  style: AppDesign.textTheme.labelMedium?.copyWith(
                    color: AppDesign.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: AppDesign.space12),
              ExcludeSemantics(
                child: Row(
                  children: [
                    const SizedBox(width: _leading),
                    const SizedBox(width: AppDesign.space8),
                    Expanded(
                      child: Text(
                        l10n.inviteTreeIntroBothActive,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: head,
                      ),
                    ),
                    const SizedBox(width: AppDesign.space8),
                    Expanded(
                      child: Text(
                        l10n.inviteTreeIntroOneActive,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: head,
                      ),
                    ),
                  ],
                ),
              ),
              for (final (i, pair) in pairs.indexed) ...[
                const SizedBox(height: AppDesign.space8),
                Builder(
                  builder: (context) {
                    final from = math.min(0.10 + 0.20 * i, 0.60);
                    final show = _part(
                      t,
                      from,
                      math.min(1, from + 0.30),
                      AppMotion.emphasizedDecelerate,
                    );
                    final lit = _highlightOf(pair);
                    final full = pair.fullBytes;
                    final one = pair.oneBytes;
                    final now = pair.nowBytes;
                    final label = [
                      if (full != null)
                        l10n.inviteTreePairFull(
                          inviteAmountText(context, full),
                        ),
                      if (now != null && now > 0)
                        l10n.inviteTreePaysNow(inviteAmountText(context, now))
                      else
                        l10n.inviteTreeNothingYet,
                    ].join('\n');
                    return MergeSemantics(
                      key: Key('invite-tree-intro-row-$i'),
                      child: Semantics(
                        label: label,
                        child: ExcludeSemantics(
                          child: Transform.translate(
                            offset: Offset((rtl ? 8 : -8) * (1 - show), 0),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: _rowHeight,
                              ),
                              child: Row(
                                children: [
                                  PairCapsule(
                                    slots: pair.slots,
                                    discSize: _disc,
                                    padding: _pad,
                                    fill: AppDesign.surfaceHigh.withValues(
                                      alpha: show,
                                    ),
                                    labelled: false,
                                    discBuilder: (_, slot) => SlotDisc(
                                      look: _fade(SlotLook.of(slot), show),
                                      size: _disc,
                                    ),
                                  ),
                                  const SizedBox(width: AppDesign.space8),
                                  Expanded(
                                    child: Center(
                                      child: cell(
                                        full == null
                                            ? null
                                            : l10n.inviteTreeIntroPlus(
                                                inviteAmountText(context, full),
                                              ),
                                        lit: lit == 2,
                                        quiet: false,
                                        show: show,
                                        glow: glow,
                                        key: Key('invite-tree-intro-both-$i'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppDesign.space8),
                                  Expanded(
                                    child: Center(
                                      child: cell(
                                        one == null
                                            ? null
                                            : one == 0
                                            ? l10n.inviteTreeIntroNothing
                                            : l10n.inviteTreeIntroPlus(
                                                inviteAmountText(context, one),
                                              ),
                                        lit: lit == 1,
                                        quiet: one == 0,
                                        show: show,
                                        glow: glow,
                                        key: Key('invite-tree-intro-one-$i'),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 4: a friend who stops.

class _ActivePage extends StatelessWidget {
  const _ActivePage({
    required this.artKey,
    required this.status,
    required this.play,
    required this.artHeight,
  });

  final Key artKey;
  final ReferralStatus status;
  final Animation<double> play;
  final double artHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final first = status.pairs.isEmpty ? null : status.pairs.first;
    final full = first?.fullBytes;
    final one = first?.oneBytes;
    return _Page(
      art: _Drawing(
        label: l10n.inviteTreeIntroActiveArt,
        child: AnimatedBuilder(
          animation: play,
          builder: (context, child) {
            final t = play.value;
            final on =
                _part(t, 0, 0.15) *
                (1 - _part(t, 0.40, 0.55, AppMotion.standard));
            return _ArtCard(
              key: artKey,
              height: artHeight,
              glow: AppDesign.protected.withValues(alpha: 0.12 * on),
              child: child!,
            );
          },
          child: _PairArt(
            play: play,
            rises: false,
            full: full == null ? null : inviteAmountText(context, full),
            one: one == null || one == 0
                ? null
                : inviteAmountText(context, one),
            oneIsNothing: one == 0,
          ),
        ),
      ),
      title: l10n.inviteTreeIntroActiveTitle,
      body: [l10n.inviteTreeIntroActiveStops],
    );
  }
}

/// One big pair. With [rises], both people turn active in turn, as an
/// example with no amounts. Without it, both start active and the second
/// stops: the chip says what the pair adds with both active, then what it
/// adds with one.
class _PairArt extends StatelessWidget {
  const _PairArt({
    required this.play,
    required this.rises,
    this.full,
    this.one,
    this.oneIsNothing = false,
  });

  final Animation<double> play;
  final bool rises;

  /// The amounts, ready to show, or null when the backend did not say.
  final String? full;
  final String? one;

  /// The backend said one active person alone adds nothing.
  final bool oneIsNothing;

  static const double _disc = 56;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final reduced = AppMotion.reduced(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDesign.space12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: AnimatedBuilder(
            animation: play,
            builder: (context, _) {
              final t = play.value;
              final appear = _part(t, 0, 0.15, AppMotion.emphasizedDecelerate);
              // How active each person is, from 0 (not active now) to 1.
              final double firstOn;
              final double secondOn;
              if (rises) {
                firstOn = _part(t, 0.20, 0.35, AppMotion.standard);
                secondOn = _part(t, 0.55, 0.70, AppMotion.standard);
              } else {
                firstOn = 1;
                secondOn = 1 - _part(t, 0.40, 0.55, AppMotion.standard);
              }

              SlotLook look(double on) {
                final base = SlotLook.lerp(
                  SlotLook.of(TreeSlot.joined),
                  SlotLook.of(TreeSlot.active),
                  on,
                );
                return SlotLook(
                  fill: base.fill.withValues(alpha: base.fill.a * appear),
                  edge: base.edge.withValues(alpha: base.edge.a * appear),
                  icon: on >= 0.5 ? Icons.person_rounded : base.icon,
                  iconColor: base.iconColor.withValues(
                    alpha: base.iconColor.a * appear,
                  ),
                );
              }

              // What the chip says now. The amount switches at once, part
              // way through; it is never counted up or down.
              final stopped = !rises && t >= 0.45;
              final (String? chipText, Color chipInk, Color chipFill) = !stopped
                  ? (
                      full == null ? null : l10n.inviteTreeIntroAdds(full!),
                      AppDesign.protected,
                      AppDesign.protectedContainer,
                    )
                  : one != null
                  ? (
                      l10n.inviteTreeIntroAdds(one!),
                      AppDesign.textPrimary,
                      AppDesign.surfaceHighest,
                    )
                  : oneIsNothing && full != null
                  ? (
                      l10n.inviteTreeIntroNothing,
                      AppDesign.textTertiary,
                      AppDesign.surfaceHighest,
                    )
                  : (null, AppDesign.textPrimary, AppDesign.surfaceHighest);
              final chipAlpha = rises || full == null ? 0.0 : appear;
              final shown = chipText == null ? 0.0 : chipAlpha;
              // Once the friend has stopped, the chip keeps what the pair
              // added before, struck through, so the drop is clear without
              // the motion. Both amounts are the backend's.
              final before = stopped && chipText != null && full != null
                  ? l10n.inviteTreeIntroPlus(full!)
                  : null;
              final quiet = AppDesign.textTertiary.withValues(alpha: shown);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: reduced ? Duration.zero : AppMotion.quick,
                    child: Container(
                      key: ValueKey(chipText),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDesign.space12,
                        vertical: AppDesign.space6,
                      ),
                      decoration: BoxDecoration(
                        color: chipFill.withValues(alpha: shown),
                        borderRadius: BorderRadius.circular(
                          AppDesign.radiusFull,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (before != null) ...[
                            Text(
                              before,
                              key: const Key('invite-tree-intro-chip-before'),
                              maxLines: 1,
                              style: AppDesign.textTheme.labelLarge?.copyWith(
                                color: quiet,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: quiet,
                                fontFeatures: AppDesign.numberFeatures,
                              ),
                            ),
                            const SizedBox(width: AppDesign.space4),
                            // Points to the end side in either direction.
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: quiet,
                            ),
                            const SizedBox(width: AppDesign.space4),
                          ],
                          Text(
                            // A space keeps the chip's height while it is
                            // empty.
                            chipText ?? ' ',
                            key: const Key('invite-tree-intro-chip'),
                            maxLines: 1,
                            style: AppDesign.textTheme.labelLarge?.copyWith(
                              color: chipInk.withValues(alpha: shown),
                              fontFeatures: AppDesign.numberFeatures,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDesign.space16),
                  Transform.scale(
                    scale: 0.9 + 0.1 * appear,
                    child: PairCapsule(
                      key: const Key('invite-tree-intro-pair-big'),
                      slots: const [TreeSlot.joined, TreeSlot.joined],
                      discSize: _disc,
                      gap: AppDesign.space8,
                      padding: AppDesign.space8,
                      fill: Color.lerp(
                        AppDesign.surfaceHigh,
                        AppDesign.protectedContainer,
                        secondOn * firstOn,
                      )!.withValues(alpha: appear),
                      edge: AppDesign.protected.withValues(
                        alpha: secondOn * firstOn * appear,
                      ),
                      labelled: false,
                      discBuilder: (index, _) => SlotDisc(
                        key: Key('invite-tree-intro-big-$index'),
                        look: look(index == 0 ? firstOn : secondOn),
                        size: _disc,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDesign.space16),
                  const SlotLegend(states: [TreeSlot.active, TreeSlot.joined]),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 5: when your slots are full.

/// Whether every one of the user's own slots is taken. False when the
/// backend sent no slots.
bool _ownSlotsFull(ReferralStatus status) =>
    status.pairs.isNotEmpty &&
    status.pairs.every((p) => !p.slots.contains(TreeSlot.empty));

class _FullPage extends StatelessWidget {
  const _FullPage({
    required this.artKey,
    required this.status,
    required this.noMore,
    required this.play,
    required this.artHeight,
  });

  final Key artKey;
  final ReferralStatus status;
  final bool noMore;
  final Animation<double> play;
  final double artHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final next = status.nextInviteBytes;
    final chip = _ownSlotsFull(status) && next != null && !noMore
        ? inviteAmountText(context, next)
        : null;
    final arrives = chip != null ? TreeSlot.active : TreeSlot.joined;
    return _Page(
      art: _ArtWithCaptions(
        captions: [
          (
            _markDisc(SlotLook.of(arrives)),
            chip != null
                ? l10n.inviteTreeIntroNextFriend
                : l10n.inviteTreeIntroLaterFriend,
            const Key('invite-tree-intro-caption-pair'),
          ),
        ],
        art: (inside) => _Drawing(
          label: l10n.inviteTreeIntroFullArt,
          child: _ArtCard(
            key: artKey,
            height: artHeight,
            glow: AppDesign.brand.withValues(alpha: 0.10),
            focus: const Offset(0.12, 0.5),
            child: _FullArt(play: play, next: chip, captions: inside),
          ),
        ),
      ),
      title: l10n.inviteTreeIntroFullTitle,
      body: [l10n.inviteTreeIntroFullBody],
      notes: [
        (
          Icons.trending_down_rounded,
          l10n.inviteTreeIntroFullLess,
          const Key('invite-tree-intro-note-less'),
        ),
        (
          Icons.people_outline_rounded,
          l10n.inviteTreeIntroActiveFar,
          const Key('invite-tree-intro-note-far'),
        ),
      ],
    );
  }
}

/// Step 5: the user with all six slots taken, and a later friend who lands
/// in an open slot in the first pair of the friend in the user's first
/// slot. A branch runs from that friend's disc to their pair.
class _FullArt extends StatelessWidget {
  const _FullArt({
    required this.play,
    required this.next,
    required this.captions,
  });

  final Animation<double> play;

  /// What the user's next friend adds a day, ready to show, when every own
  /// slot is taken and the backend sent it. Null makes the drawing an
  /// example, with no amount.
  final String? next;

  /// Whether the caption is drawn inside the drawing. When it is not, the
  /// page shows it under the card.
  final bool captions;

  /// The user's own pairs, all taken: an example of full slots.
  static const List<List<TreeSlot>> _own = [
    [TreeSlot.active, TreeSlot.active],
    [TreeSlot.active, TreeSlot.joined],
    [TreeSlot.joined, TreeSlot.active],
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final direction = Directionality.of(context);
    final rtl = direction == TextDirection.rtl;
    final next = this.next;
    // The friend who arrives is drawn active when the drawing shows the
    // backend's amount for them, which is what they add once active.
    final arrives = next != null ? TreeSlot.active : TreeSlot.joined;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final tight = h < 140;
        final disc = tight ? 18.0 : 24.0;
        final pad = tight ? 3.0 : 5.0;
        const discGap = 4.0;
        final rowGap = tight ? 6.0 : 10.0;
        final capsuleWidth = 2 * disc + discGap + 2 * pad;
        final capsuleHeight = disc + 2 * pad;
        final stack = 3 * capsuleHeight + 2 * rowGap;
        // Room above the first pair for the chip, when there is one.
        final lift = next != null && !tight ? 12.0 : 0.0;
        final top = (h - stack) / 2 + lift;
        final youSize = tight ? 40.0 : 48.0;
        final you = Offset(w * 0.12, top + stack / 2);
        final ownLeft = w * 0.42 - capsuleWidth / 2;
        double rowY(int i) =>
            top + i * (capsuleHeight + rowGap) + capsuleHeight / 2;
        // Their first pair, beside the user's first pair.
        final theirLeft = w * 0.80 - capsuleWidth / 2;
        final y1 = rowY(0);
        // The branch leaves the top of the first disc of the user's first
        // pair, arches over that pair, and comes down into theirs.
        final branchFrom = Offset(ownLeft + pad + disc / 2, y1 - disc / 2);
        final branchTo = Offset(theirLeft, y1);
        final apex = y1 - capsuleHeight / 2 - (tight ? 6 : 10);
        final arriving = Offset(
          theirLeft + pad + disc + discGap + disc / 2,
          y1,
        );
        final links = [
          for (var i = 0; i < 3; i++)
            _Link(
              Offset(you.dx + youSize / 2, you.dy),
              Offset(ownLeft, rowY(i)),
              1.5,
            ),
        ];
        double left(double x, double width) => _mirror(x, w, rtl) - width / 2;

        return AnimatedBuilder(
          animation: play,
          builder: (context, _) {
            final t = play.value;
            final drawn = _part(t, 0, 0.25, AppMotion.emphasizedDecelerate);
            final branch = _part(t, 0.25, 0.55, AppMotion.standard);
            final arrive = _part(t, 0.60, 0.80, AppMotion.emphasizedDecelerate);
            final ends = _part(t, 0.80, 1, AppMotion.emphasizedDecelerate);
            const chipWidth = 132.0;
            final chipLeft = (arriving.dx - chipWidth / 2)
                .clamp(8.0, math.max(8.0, w - 8 - chipWidth))
                .toDouble();
            return Stack(
              clipBehavior: Clip.none,
              children: [
                _links(links, drawn, direction),
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _BranchPainter(
                        from: branchFrom,
                        to: branchTo,
                        apex: apex,
                        drawn: branch,
                        direction: direction,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: left(you.dx, youSize),
                  top: you.dy - youSize / 2,
                  child: _YouDisc(
                    key: const Key('invite-tree-intro-you-full'),
                    size: youSize,
                  ),
                ),
                for (var i = 0; i < 3; i++)
                  Positioned(
                    left: rtl ? w - ownLeft - capsuleWidth : ownLeft,
                    top: rowY(i) - capsuleHeight / 2,
                    child: PairCapsule(
                      key: Key('invite-tree-intro-full-pair-$i'),
                      slots: _own[i],
                      discSize: disc,
                      gap: discGap,
                      padding: pad,
                      labelled: false,
                      discBuilder: (index, slot) => SlotDisc(
                        key: i == 0 && index == 0
                            ? const Key('invite-tree-intro-friend')
                            : null,
                        look: SlotLook.of(slot),
                        size: disc,
                      ),
                    ),
                  ),
                Positioned(
                  left: rtl ? w - theirLeft - capsuleWidth : theirLeft,
                  top: y1 - capsuleHeight / 2,
                  child: Opacity(
                    opacity: 0.25 + 0.75 * branch,
                    child: PairCapsule(
                      key: const Key('invite-tree-intro-their-pair'),
                      slots: const [TreeSlot.active, TreeSlot.empty],
                      discSize: disc,
                      gap: discGap,
                      padding: pad,
                      fill: _fadedFill,
                      labelled: false,
                      discBuilder: (index, slot) => index == 0
                          ? SlotDisc(
                              look: _faded(SlotLook.of(slot)),
                              size: disc,
                            )
                          : SizedBox.square(
                              dimension: disc,
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  SlotDisc(
                                    look: SlotLook.of(TreeSlot.empty),
                                    size: disc,
                                  ),
                                  if (arrive > 0)
                                    Transform.scale(
                                      scale: 0.6 + 0.4 * arrive,
                                      child: SlotDisc(
                                        key: const Key(
                                          'invite-tree-intro-arriving',
                                        ),
                                        look: _fade(
                                          SlotLook.of(arrives),
                                          arrive,
                                        ),
                                        size: disc,
                                      ),
                                    ),
                                  // The ring that marks where the friend
                                  // lands.
                                  if (ends > 0)
                                    Positioned(
                                      left: -4,
                                      top: -4,
                                      child: Container(
                                        key: const Key(
                                          'invite-tree-intro-arriving-ring',
                                        ),
                                        width: disc + 8,
                                        height: disc + 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppDesign.brandBright
                                                .withValues(alpha: ends),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
                if (next != null)
                  Positioned(
                    left: rtl ? w - chipLeft - chipWidth : chipLeft,
                    width: chipWidth,
                    top: tight ? y1 + capsuleHeight / 2 + 8 : null,
                    bottom: tight ? null : h - (apex - 4),
                    child: Center(
                      child: Container(
                        key: const Key('invite-tree-intro-next-chip'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDesign.space8,
                          vertical: AppDesign.space2,
                        ),
                        decoration: BoxDecoration(
                          color: AppDesign.protectedContainer.withValues(
                            alpha: ends,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppDesign.radiusFull,
                          ),
                        ),
                        child: Text(
                          l10n.inviteTreeIntroAdds(next),
                          maxLines: 1,
                          style: AppDesign.textTheme.labelMedium?.copyWith(
                            color: AppDesign.protected.withValues(alpha: ends),
                            fontFeatures: AppDesign.numberFeatures,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (captions)
                  _caption(
                    x: _mirror(arriving.dx, w, rtl),
                    top: y1 + capsuleHeight / 2 + 8,
                    width: math.min(120, w * 0.36),
                    text: next != null
                        ? l10n.inviteTreeIntroNextFriend
                        : l10n.inviteTreeIntroLaterFriend,
                    key: const Key('invite-tree-intro-caption-pair'),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// The branch in step 5: from the top of a disc in the user's first pair,
/// over that pair, and down into the pair it leads to. Laid out from the
/// start side; mirrored here for right to left.
class _BranchPainter extends CustomPainter {
  _BranchPainter({
    required this.from,
    required this.to,
    required this.apex,
    required this.drawn,
    required this.direction,
  });

  final Offset from;
  final Offset to;

  /// How high the branch arches, as a y on the card.
  final double apex;

  /// How much of it is drawn, from 0 to 1.
  final double drawn;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    if (drawn <= 0) return;
    final rtl = direction == TextDirection.rtl;
    double x(double v) => _mirror(v, size.width, rtl);
    final reach = (to.dx - from.dx) * 0.35;
    final path = Path()
      ..moveTo(x(from.dx), from.dy)
      ..cubicTo(x(from.dx), apex, x(to.dx - reach), apex, x(to.dx), to.dy);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * drawn),
      Paint()
        ..color = AppDesign.steelLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_BranchPainter old) =>
      old.from != from ||
      old.to != to ||
      old.apex != apex ||
      old.drawn != drawn ||
      old.direction != direction;
}

// ---------------------------------------------------------------------------
// Step 6: people you did not invite.

class _OthersPage extends StatelessWidget {
  const _OthersPage({
    required this.artKey,
    required this.play,
    required this.artHeight,
  });

  final Key artKey;
  final Animation<double> play;
  final double artHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return _Page(
      art: _ArtWithCaptions(
        captions: [
          (
            _markDisc(_faded(SlotLook.of(TreeSlot.active))),
            l10n.inviteTreeIntroInvitedYou,
            const Key('invite-tree-intro-caption-inviter'),
          ),
          (
            _markIcon(Icons.link_rounded),
            l10n.inviteTreeIntroNotInvited,
            const Key('invite-tree-intro-caption-others'),
          ),
        ],
        art: (inside) => _Drawing(
          label: l10n.inviteTreeIntroOthersArt,
          child: _ArtCard(
            key: artKey,
            height: artHeight,
            glow: AppDesign.brand.withValues(alpha: 0.10),
            focus: const Offset(0.22, 0.6),
            child: _OthersArt(play: play, captions: inside),
          ),
        ),
      ),
      title: l10n.inviteTreeIntroOthersTitle,
      body: [l10n.inviteTreeIntroOthersWhy],
    );
  }
}

/// A curve from [a] to [b] through two control points, laid out from the
/// start side.
class _Curve {
  const _Curve(this.a, this.c1, this.c2, this.b);

  final Offset a;
  final Offset c1;
  final Offset c2;
  final Offset b;

  /// The point [s] of the way along it.
  Offset at(double s) {
    final u = 1 - s;
    return a * (u * u * u) +
        c1 * (3 * u * u * s) +
        c2 * (3 * u * s * s) +
        b * (s * s * s);
  }
}

/// [curve] drawn in from its start, [drawn] of the way. Mirrored here for
/// right to left.
class _CurvePainter extends CustomPainter {
  _CurvePainter({
    required this.curve,
    required this.drawn,
    required this.direction,
    required this.color,
    this.stroke = 1.5,
  });

  final _Curve curve;
  final double drawn;
  final TextDirection direction;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (drawn <= 0) return;
    final rtl = direction == TextDirection.rtl;
    Offset m(Offset p) => Offset(_mirror(p.dx, size.width, rtl), p.dy);
    final a = m(curve.a);
    final c1 = m(curve.c1);
    final c2 = m(curve.c2);
    final b = m(curve.b);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, b.dx, b.dy);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * drawn),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.drawn != drawn ||
      old.direction != direction ||
      old.color != color ||
      old.curve.a != curve.a ||
      old.curve.b != curve.b ||
      old.curve.c1 != curve.c1 ||
      old.curve.c2 != curve.c2;
}

/// Step 6: the person who invited the user, in the top start corner, the
/// user in one of their slots, and the user's first pair. Someone comes
/// from the person who invited the user, along a curve, into the open
/// slot of the user's first pair.
class _OthersArt extends StatelessWidget {
  const _OthersArt({required this.play, required this.captions});

  final Animation<double> play;

  /// Whether the captions are drawn inside the drawing. When they are not,
  /// the page shows them under the card.
  final bool captions;

  static const double _gap = 8;
  static const double _linkBadge = 12;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final direction = Directionality.of(context);
    final rtl = direction == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final tight = h < 140;
        final disc = tight ? 30.0 : 40.0;
        final pad = tight ? 6.0 : 8.0;
        final youSize = tight ? 40.0 : 48.0;
        final inviterSize = tight ? 22.0 : 28.0;
        final traveller = tight ? 14.0 : 18.0;
        final y = h * (captions ? 0.60 : 0.64);
        final inviter = Offset(w * 0.09, h * (tight ? 0.20 : 0.18));
        final you = Offset(w * 0.24, y);
        final capsuleWidth = 2 * disc + _gap + 2 * pad;
        final capsuleHeight = disc + 2 * pad;
        final capsuleLeft = w * 0.64 - capsuleWidth / 2;
        final second = Offset(capsuleLeft + pad + disc + _gap + disc / 2, y);
        final toPair = _Link(
          Offset(you.dx + youSize / 2, y),
          Offset(capsuleLeft, y),
          1.5,
        );
        // The user sits in a slot of the person who invited them.
        final toYou = _Curve(
          Offset(inviter.dx, inviter.dy + inviterSize / 2),
          Offset(inviter.dx, you.dy),
          Offset(inviter.dx, you.dy),
          Offset(you.dx - youSize / 2, you.dy),
        );
        // Their next friend comes from them: up out of their disc, across
        // above everything, and down into the open slot of the user's first
        // pair. It runs above the caption beside their disc.
        final over = inviter.dy - inviterSize / 2 - 8;
        final travel = _Curve(
          Offset(inviter.dx, inviter.dy - inviterSize / 2),
          Offset(inviter.dx, over),
          Offset(second.dx, over),
          Offset(second.dx, y - disc / 2),
        );

        return AnimatedBuilder(
          animation: play,
          builder: (context, _) {
            final t = play.value;
            final drawn = _part(t, 0, 0.25, AppMotion.emphasizedDecelerate);
            final shows = _part(t, 0.25, 0.40, AppMotion.emphasizedDecelerate);
            final moving = _part(t, 0.40, 0.75, AppMotion.standard);
            final lands = _part(t, 0.75, 0.90, AppMotion.standard);
            final badges = _part(t, 0.85, 1, AppMotion.emphasizedDecelerate);
            final at = travel.at(moving);
            final outside = shows * (1 - lands);
            Widget painted(_Curve curve, double drawn, Color color) =>
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _CurvePainter(
                        curve: curve,
                        drawn: drawn,
                        direction: direction,
                        color: color,
                        stroke: 1.25,
                      ),
                    ),
                  ),
                );
            final captionStyle = AppDesign.textTheme.labelMedium?.copyWith(
              color: AppDesign.textTertiary,
            );
            return Stack(
              clipBehavior: Clip.none,
              children: [
                painted(toYou, drawn, AppDesign.outlineVariant),
                _links([toPair], drawn, direction),
                painted(travel, shows, AppDesign.steelLight),
                Positioned(
                  left: _mirror(inviter.dx, w, rtl) - inviterSize / 2,
                  top: inviter.dy - inviterSize / 2,
                  child: SlotDisc(
                    key: const Key('invite-tree-intro-inviter'),
                    look: _faded(SlotLook.of(TreeSlot.active)),
                    size: inviterSize,
                  ),
                ),
                if (captions)
                  PositionedDirectional(
                    start: inviter.dx + inviterSize / 2 + AppDesign.space8,
                    top: inviter.dy - 8,
                    width: w * 0.40,
                    child: Text(
                      l10n.inviteTreeIntroInvitedYou,
                      key: const Key('invite-tree-intro-caption-inviter'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: captionStyle,
                    ),
                  ),
                Positioned(
                  left: _mirror(you.dx, w, rtl) - youSize / 2,
                  top: y - youSize / 2,
                  child: _YouDisc(
                    key: const Key('invite-tree-intro-you-others'),
                    size: youSize,
                  ),
                ),
                Positioned(
                  left: rtl ? w - capsuleLeft - capsuleWidth : capsuleLeft,
                  top: y - capsuleHeight / 2,
                  child: PairCapsule(
                    key: const Key('invite-tree-intro-first-pair'),
                    slots: const [TreeSlot.active, TreeSlot.empty],
                    discSize: disc,
                    gap: _gap,
                    padding: pad,
                    labelled: false,
                    discBuilder: (index, slot) => index == 0
                        ? SlotDisc(look: SlotLook.of(slot), size: disc)
                        : SizedBox.square(
                            dimension: disc,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                SlotDisc(
                                  key: const Key(
                                    'invite-tree-intro-others-slot',
                                  ),
                                  look: SlotLook.lerp(
                                    SlotLook.of(TreeSlot.empty),
                                    SlotLook.of(TreeSlot.active),
                                    lands,
                                  ),
                                  size: disc,
                                ),
                                if (badges > 0)
                                  PositionedDirectional(
                                    end: -2,
                                    bottom: -2,
                                    child: Container(
                                      width: _linkBadge,
                                      height: _linkBadge,
                                      decoration: BoxDecoration(
                                        color: AppDesign.steelLight.withValues(
                                          alpha: badges,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.link_rounded,
                                        size: 9,
                                        color: AppDesign.canvas.withValues(
                                          alpha: badges,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ),
                if (outside > 0)
                  Positioned(
                    left: _mirror(at.dx, w, rtl) - traveller / 2,
                    top: at.dy - traveller / 2,
                    child: SlotDisc(
                      key: const Key('invite-tree-intro-outside'),
                      look: _fade(SlotLook.of(TreeSlot.joined), outside),
                      size: traveller,
                    ),
                  ),
                if (captions)
                  _caption(
                    x: _mirror(second.dx, w, rtl),
                    top: y + capsuleHeight / 2 + 8,
                    width: math.min(110, w * 0.34),
                    text: l10n.inviteTreeIntroNotInvited,
                    key: const Key('invite-tree-intro-caption-others'),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Step 7: your data from friends.

/// The user's data from friends now, against the most invites can add,
/// and what was kept from earlier invites. Every number here is from the
/// referral answer.
class _TotalPage extends StatelessWidget {
  const _TotalPage({
    required this.artKey,
    required this.status,
    required this.noMore,
    required this.belowKept,
    required this.play,
    required this.artHeight,
  });

  final Key artKey;
  final ReferralStatus status;
  final bool noMore;

  /// ReferralState.nextFriendBelowKept: the bonus is the part kept from
  /// earlier invites, and one more friend does not lift it.
  final bool belowKept;
  final Animation<double> play;
  final double artHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final bonus = status.bonusBytes;
    final most = status.maxBonusBytes;
    final kept = (status.keptBytes ?? 0) > 0 ? status.keptBytes : null;
    final total = status.maxTotalBytes;
    // A kept bonus at or above the limit: what friends add on top of the
    // free data is the kept bonus, so the total line would not be true.
    final keptAtMost = kept != null && most != null && kept >= most;
    // The most friends can add, then the most free data and friends' data
    // reach together, so the two limits are never side by side unnamed.
    final body = noMore
        ? l10n.premiumLimitInvitesFull
        : total != null && most != null && !keptAtMost
        ? l10n.inviteTreeIntroTotalUpTo(
            inviteAmountText(context, most),
            inviteAmountText(context, total),
          )
        : total != null && !keptAtMost
        ? l10n.inviteTreeIntroTotalReach(inviteAmountText(context, total))
        : most != null
        ? l10n.inviteTreeHowCap(inviteAmountText(context, most))
        : l10n.inviteTreeHowCapNoAmount;
    return _Page(
      art: _ArtCard(
        key: artKey,
        height: artHeight,
        grows: true,
        glow: AppDesign.brand.withValues(alpha: 0.10),
        focus: const Offset(0.2, 0.2),
        child: _TotalArt(play: play, bonus: bonus, most: most, kept: kept),
      ),
      title: l10n.inviteTreeIntroTotalTitle,
      body: [body, if (belowKept) l10n.inviteTreeKeptFloor],
      notes: [
        (
          Icons.event_repeat_outlined,
          l10n.inviteTreeLive,
          const Key('invite-tree-intro-note-live'),
        ),
        if (kept != null)
          (
            Icons.verified_outlined,
            l10n.inviteTreeKept(inviteAmountText(context, kept)),
            const Key('invite-tree-intro-note-kept'),
          ),
      ],
    );
  }
}

class _TotalArt extends StatelessWidget {
  const _TotalArt({
    required this.play,
    required this.bonus,
    required this.most,
    required this.kept,
  });

  final Animation<double> play;
  final int bonus;
  final int? most;
  final int? kept;

  static const double _barHeight = 16;
  static const double _tickHeight = 24;
  static const double _swatchSize = 10;
  static const double _youSize = 48;
  static const double _badgeSize = 16;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final direction = Directionality.of(context);
    final most = this.most;
    final kept = this.kept;
    final bar = most != null && most > 0;
    final tick = bar && kept != null && kept > 0 && kept < most;
    final amount = bonus > 0
        ? l10n.inviteTreeIntroPerDay(inviteAmountText(context, bonus))
        : l10n.inviteTreeNothingYet;

    return Padding(
      padding: const EdgeInsets.all(AppDesign.space16),
      child: AnimatedBuilder(
        animation: play,
        builder: (context, _) {
          final t = play.value;
          final grown = _part(t, 0, 0.60, AppMotion.emphasizedDecelerate);
          final shown = _part(t, 0.50, 0.90);
          final label = AppDesign.textTheme.bodyMedium?.copyWith(
            color: AppDesign.textSecondary.withValues(alpha: shown),
          );
          final value = AppDesign.textTheme.titleSmall?.copyWith(
            color: AppDesign.textPrimary.withValues(alpha: shown),
            fontFeatures: AppDesign.numberFeatures,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // The heading names the green fill of the bar, so it carries
              // the fill's swatch.
              Row(
                children: [
                  if (bar) ...[
                    ExcludeSemantics(
                      child: Container(
                        key: const Key('invite-tree-intro-now-swatch'),
                        width: _swatchSize,
                        height: _swatchSize,
                        decoration: BoxDecoration(
                          gradient: AppDesign.tealGradient,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDesign.space8),
                  ],
                  Expanded(
                    child: Text(
                      l10n.inviteTreeIntroTotalNow,
                      style: AppDesign.textTheme.labelMedium?.copyWith(
                        color: AppDesign.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDesign.space4),
              Text(
                amount,
                key: const Key('invite-tree-intro-total'),
                style: AppDesign.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: bonus > 0
                      ? AppDesign.protected
                      : AppDesign.textSecondary,
                  fontFeatures: AppDesign.numberFeatures,
                ),
              ),
              if (bar) ...[
                const SizedBox(height: AppDesign.space16),
                ExcludeSemantics(
                  child: SizedBox(
                    key: const Key('invite-tree-intro-bar'),
                    height: _tickHeight,
                    width: double.infinity,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _BarPainter(
                          share: math.min(bonus, most) / most,
                          some: bonus > 0,
                          tick: tick ? kept / most : null,
                          grown: grown,
                          shown: shown,
                          direction: direction,
                          barHeight: _barHeight,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppDesign.space4),
                // The end of the track is the most invites can add: it is
                // written there, under the end of the bar.
                MergeSemantics(
                  key: const Key('invite-tree-intro-most-row'),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: l10n.inviteTreeIntroTotalMost,
                            style: label,
                          ),
                          const TextSpan(text: '  '),
                          TextSpan(
                            text: l10n.inviteTreeIntroPerDay(
                              inviteAmountText(context, most),
                            ),
                            style: value,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ),
                if (tick) ...[
                  const SizedBox(height: AppDesign.space12),
                  MergeSemantics(
                    key: const Key('invite-tree-intro-kept-row'),
                    child: Row(
                      children: [
                        // The same thin mark as the tick on the bar.
                        ExcludeSemantics(
                          child: SizedBox(
                            width: _swatchSize,
                            child: Center(
                              child: Container(
                                width: 2,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: AppDesign.textTertiary.withValues(
                                    alpha: shown,
                                  ),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDesign.space8),
                        Expanded(
                          child: Text(
                            l10n.inviteTreeIntroTotalKept,
                            style: label,
                          ),
                        ),
                        const SizedBox(width: AppDesign.space8),
                        Text(
                          l10n.inviteTreeIntroPerDay(
                            inviteAmountText(context, kept),
                          ),
                          style: value,
                        ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                const SizedBox(height: AppDesign.space16),
                const ExcludeSemantics(
                  child: _YouWithBadge(
                    size: _youSize,
                    badgeSize: _badgeSize,
                    badge: 1,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The bar of the data from friends: the track is the most invites can
/// add, the fill is what friends add now, and the tick is the part kept
/// from earlier invites. It fills from the start side.
class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.share,
    required this.some,
    required this.tick,
    required this.grown,
    required this.shown,
    required this.direction,
    required this.barHeight,
  });

  /// The filled share of the track, from 0 to 1.
  final double share;

  /// Whether anything is filled: a fill of anything is at least a sliver.
  final bool some;

  /// Where the tick goes, as a share of the track, or null for none.
  final double? tick;

  /// How far the fill has grown, and how far the tick has faded in.
  final double grown;
  final double shown;
  final TextDirection direction;
  final double barHeight;

  static const double _sliver = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final rtl = direction == TextDirection.rtl;
    final top = (size.height - barHeight) / 2;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, top, size.width, barHeight),
      Radius.circular(barHeight / 2),
    );
    canvas.drawRRect(track, Paint()..color = AppDesign.surfaceHighest);
    canvas.drawRRect(
      track.deflate(0.5),
      Paint()
        ..color = AppDesign.outlineVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    var filled = size.width * share * grown;
    if (some && grown > 0) filled = math.max(filled, _sliver * grown);
    if (filled > 0) {
      final left = rtl ? size.width - filled : 0.0;
      final rect = Rect.fromLTWH(left, top, filled, barHeight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barHeight / 2)),
        Paint()..shader = AppDesign.tealGradient.createShader(rect),
      );
    }
    final at = tick;
    if (at != null && shown > 0) {
      final x = _mirror(size.width * at, size.width, rtl);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 1, 0, 2, size.height),
          const Radius.circular(1),
        ),
        Paint()..color = AppDesign.textTertiary.withValues(alpha: shown),
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.share != share ||
      old.some != some ||
      old.tick != tick ||
      old.grown != grown ||
      old.shown != shown ||
      old.direction != direction;
}

// ---------------------------------------------------------------------------
// Step 8: invite friends.

class _SharePage extends StatelessWidget {
  const _SharePage({
    required this.artKey,
    required this.status,
    required this.nextFriend,
    required this.play,
    required this.artHeight,
  });

  final Key artKey;
  final ReferralStatus status;

  /// What the next friend adds, shown here on a small screen, where the bar
  /// leaves it out. Null on a larger screen, or when there is none.
  final String? nextFriend;
  final Animation<double> play;
  final double artHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return _Page(
      art: _ArtCard(
        key: artKey,
        height: artHeight,
        glow: AppDesign.brand.withValues(alpha: 0.10),
        child: _CodeArt(code: status.code, play: play),
      ),
      title: l10n.inviteTreeIntroShareTitle,
      body: [l10n.inviteTreeIntroShareBody],
      notes: [
        if (nextFriend case final line?)
          (
            Icons.person_add_alt_outlined,
            line,
            const Key('invite-tree-intro-next-friend'),
          ),
      ],
    );
  }
}

/// The user's disc over their invite code, as the invite screen shows it.
class _CodeArt extends StatelessWidget {
  const _CodeArt({required this.code, required this.play});

  final String code;
  final Animation<double> play;

  static const double _youSize = 56;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final style = AppDesign.textTheme.headlineSmall;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDesign.space16),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: AnimatedBuilder(
            animation: play,
            builder: (context, _) {
              final show = _part(play.value, 0, 1, AppMotion.standard);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ExcludeSemantics(child: _YouDisc(size: _youSize)),
                  const SizedBox(height: AppDesign.space12),
                  MergeSemantics(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.inviteYourCode,
                          style: AppDesign.textTheme.labelMedium?.copyWith(
                            color: AppDesign.textTertiary,
                          ),
                        ),
                        const SizedBox(height: AppDesign.space4),
                        // Latin letters and digits in every language, read
                        // left to right, in the code box's own face.
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            code,
                            key: const Key('invite-tree-intro-code'),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontFamilyFallback: const <String>[],
                              locale: const Locale('en'),
                              fontSize: style?.fontSize ?? 24,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 4,
                              height: 1.2,
                              color: AppDesign.textPrimary.withValues(
                                alpha: show,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
