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

/// The introduction to the invite tree, in four steps: friends fill the
/// user's slots in pairs, a pair adds the most when both friends in it are
/// active, friends further away still add data, and what the user's data
/// from friends is now.
///
/// It exists only under the tree rule (ReferralStatus.isTree). Under
/// today's rule nothing opens it, and a status that stops being a tree
/// status while it is open closes it. Every amount and day count on it is
/// the backend's, from the referral answer, and each has a line that names
/// no number for when the backend sent none. The drawings are built from
/// the user's own answer: their number of pairs and what their first pair
/// adds.
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

class _InviteTreeIntroScreenState extends State<InviteTreeIntroScreen>
    with TickerProviderStateMixin {
  /// The steps of the story. The screen's own page count, not a number the
  /// service sets.
  static const int _pageCount = 4;

  /// How long each page's drawing plays when the page comes into view.
  static const List<Duration> _plays = [
    Duration(milliseconds: 1500),
    Duration(milliseconds: 2000),
    Duration(milliseconds: 2400),
    Duration(milliseconds: 1200),
  ];

  final PageController _pages = PageController();
  late final List<AnimationController> _drawings = [
    for (final play in _plays) AnimationController(vsync: this, duration: play),
  ];

  int _page = 0;
  bool _started = false;
  bool _reduced = false;
  bool _sharing = false;
  bool _leaving = false;
  _Exit? _exit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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

  void _goTo(int page) {
    if (page < 0 || page >= _pageCount) return;
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
    if (exit == _Exit.skip || (exit == null && _page < _pageCount - 1)) {
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
  /// screen or with large text, so the words under it keep their room.
  static double _artHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    final large = media.textScaler.scale(10) >= 13;
    if (media.size.height < 600 || large) return 140;
    return (media.size.height * 0.30).clamp(160, 260).toDouble();
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
    final last = _page == _pageCount - 1;
    final noMore = referrals.invitesAddNoMore;
    final tv = FormFactor.isTv;

    final bottom = _BottomBar(
      page: _page,
      count: _pageCount,
      nextFriend: noMore || status.nextInviteBytes == null
          ? null
          : l10n.inviteTreeNext(
              inviteAmountText(context, status.nextInviteBytes!),
            ),
      onBack: () => _goTo(_page - 1),
      onNext: () => _goTo(_page + 1),
      onDone: () => _close(_Exit.done),
      onShare: () => unawaited(_share(status)),
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
                  count: _pageCount,
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
                        l10n.inviteTreeIntroStep(_page + 1, _pageCount),
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
                      _SlotsPage(
                        status: status,
                        play: _drawings[0],
                        artHeight: art,
                      ),
                      _PairPage(
                        status: status,
                        play: _drawings[1],
                        artHeight: art,
                      ),
                      _FurtherPage(play: _drawings[2], artHeight: art),
                      _TotalPage(
                        status: status,
                        noMore: noMore,
                        play: _drawings[3],
                        artHeight: art,
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
  });

  final int page;
  final int count;
  final String? nextFriend;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onDone;
  final VoidCallback onShare;

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
                    const SizedBox(width: AppDesign.space12),
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
                  child: FilledButton(
                    key: const Key('invite-tree-intro-next'),
                    onPressed: onNext,
                    autofocus: FormFactor.isTv,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppDesign.surfaceHighest,
                      foregroundColor: AppDesign.textPrimary,
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

/// One step: the drawing, the title, the words and the notes under them.
class _Page extends StatelessWidget {
  const _Page({
    required this.art,
    required this.title,
    required this.body,
    this.notes = const [],
  });

  final Widget art;
  final String title;
  final String body;
  final List<(IconData, String, Key)> notes;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDesign.space24,
        0,
        AppDesign.space24,
        AppDesign.space16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          art,
          const SizedBox(height: AppDesign.space24),
          Semantics(
            header: true,
            child: Text(
              title,
              style: AppDesign.textTheme.headlineSmall?.copyWith(
                color: AppDesign.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppDesign.space8),
          Text(
            body,
            key: const Key('invite-tree-intro-body'),
            style: AppDesign.textTheme.bodyLarge?.copyWith(
              color: AppDesign.textSecondary,
              fontFeatures: AppDesign.numberFeatures,
            ),
          ),
          for (final (i, (icon, text, key)) in notes.indexed) ...[
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

/// The share of [t] that falls inside [from] to [to], from 0 to 1, eased.
double _part(double t, double from, double to, [Curve curve = Curves.linear]) {
  if (to <= from) return t >= to ? 1 : 0;
  return curve.transform(((t - from) / (to - from)).clamp(0.0, 1.0));
}

/// Mirror [x] across a box [width] wide when the text runs right to left.
double _mirror(double x, double width, bool rtl) => rtl ? width - x : x;

/// One connecting line, laid out from the start side: where it starts and
/// ends, and its stroke.
class _Link {
  const _Link(this.from, this.to, this.stroke);

  final Offset from;
  final Offset to;
  final double stroke;
}

/// A dot travelling along links back toward the user: through [route], a
/// list of link indexes each walked from its end to its start, [along]
/// of the way, drawn [radius] wide.
class _Dot {
  const _Dot(this.route, this.along, this.radius);

  final List<int> route;
  final double along;
  final double radius;
}

/// The lines between the user and their slots, drawn in from the user's
/// side, and the dots of data travelling back along them. Laid out from
/// the start side; mirrored here for right to left.
class _LinkPainter extends CustomPainter {
  _LinkPainter({
    required this.links,
    required this.drawn,
    required this.direction,
    this.dots = const [],
    this.curved = true,
  });

  final List<_Link> links;

  /// How much of each line is drawn, from 0 to 1.
  final double drawn;
  final TextDirection direction;
  final List<_Dot> dots;
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
    final metrics = <PathMetric>[
      for (final link in links) _path(link, size.width).computeMetrics().first,
    ];
    for (final (i, link) in links.indexed) {
      final metric = metrics[i];
      final paint = Paint()
        ..color = AppDesign.outlineVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = link.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(metric.extractPath(0, metric.length * drawn), paint);
    }
    for (final dot in dots) {
      if (dot.along <= 0 || dot.along >= 1) continue;
      final route = [for (final i in dot.route) metrics[i]];
      final total = route.fold<double>(0, (n, m) => n + m.length);
      var left = total * dot.along;
      for (final metric in route) {
        if (left <= metric.length) {
          // Walked from the line's end back to its start.
          final tangent = metric.getTangentForOffset(metric.length - left);
          if (tangent != null) {
            // A soft ring under the dot, so a dot of a few points still
            // reads against the card.
            canvas.drawCircle(
              tangent.position,
              dot.radius,
              Paint()
                ..color = AppDesign.protectedBright.withValues(alpha: 0.22),
            );
            canvas.drawCircle(
              tangent.position,
              dot.radius / 2,
              Paint()..color = AppDesign.protectedBright,
            );
          }
          break;
        }
        left -= metric.length;
      }
    }
  }

  @override
  bool shouldRepaint(_LinkPainter old) =>
      old.drawn != drawn ||
      old.direction != direction ||
      old.dots.length != dots.length ||
      [
        for (final (i, d) in dots.indexed)
          d.along != old.dots[i].along || d.radius != old.dots[i].radius,
      ].any((changed) => changed) ||
      old.links.length != links.length;
}

/// Step 1: the user's slots, in pairs, filling as friends join.
class _SlotsPage extends StatelessWidget {
  const _SlotsPage({
    required this.status,
    required this.play,
    required this.artHeight,
  });

  final ReferralStatus status;
  final Animation<double> play;
  final double artHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final slots = status.treeSlots;
    return _Page(
      art: Semantics(
        image: true,
        label: l10n.inviteTreeIntroSlotsArt,
        child: ExcludeSemantics(
          child: _ArtCard(
            key: const Key('invite-tree-intro-art-0'),
            height: artHeight,
            glow: AppDesign.brand.withValues(alpha: 0.10),
            focus: const Offset(0.18, 0.5),
            child: _SlotsArt(
              pairs: status.pairs,
              play: play,
              height: artHeight,
            ),
          ),
        ),
      ),
      title: l10n.inviteTreeIntroSlotsTitle,
      body: slots > 0
          ? NumberLocalizer.localize(l10n.inviteTreeHowSlots(slots), context)
          : l10n.inviteTreeHowSlotsNoNumber,
      notes: [
        (
          Icons.group_add_outlined,
          l10n.inviteTreeIntroSlotsWhen,
          const Key('invite-tree-intro-note-slots'),
        ),
      ],
    );
  }
}

class _SlotsArt extends StatelessWidget {
  const _SlotsArt({
    required this.pairs,
    required this.play,
    required this.height,
  });

  final List<TreePair> pairs;
  final Animation<double> play;
  final double height;

  static const double _youSize = 56;
  static const double _capsulePadding = 6;
  static const double _capsuleGap = 12;
  static const double _discGap = 4;

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
        // sent none. As many as fit the card with a readable disc.
        final wanted = math.max(1, pairs.length);
        var n = wanted;
        double discFor(int n) =>
            math.min(32, (h - 24 - (n - 1) * _capsuleGap) / n - 12);
        while (n > 1 && discFor(n) < 14) {
          n--;
        }
        final disc = discFor(n);
        final capsuleWidth = 2 * disc + _discGap + 2 * _capsulePadding;
        final capsuleHeight = disc + 2 * _capsulePadding;
        final stack = n * capsuleHeight + (n - 1) * _capsuleGap;
        final top = (h - stack) / 2;
        final capsuleLeft = w * 0.66 - capsuleWidth / 2;

        final labelStyle = AppDesign.textTheme.labelMedium?.copyWith(
          color: AppDesign.textSecondary,
        );
        final labelHeight =
            (labelStyle?.fontSize ?? 12) * (labelStyle?.height ?? 1.4);
        final you = Offset(w * 0.18, h / 2 - (6 + labelHeight) / 2);
        final links = [
          for (var i = 0; i < n; i++)
            _Link(
              Offset(you.dx + _youSize / 2, you.dy),
              Offset(
                capsuleLeft,
                top + i * (capsuleHeight + _capsuleGap) + capsuleHeight / 2,
              ),
              1.5,
            ),
        ];
        return AnimatedBuilder(
          animation: play,
          builder: (context, _) {
            final t = play.value;
            Widget disc0(int pair, int index) {
              final k = pair * 2 + index;
              final from = math.min(0.30 + 0.08 * k, 0.83);
              final grown = _part(
                t,
                from,
                math.min(1, from + 0.17),
                AppMotion.emphasizedDecelerate,
              );
              return Transform.scale(
                scale: 0.6 + 0.4 * grown,
                child: SlotDisc(
                  look: SlotLook.lerp(
                    SlotLook.of(TreeSlot.empty),
                    SlotLook.of(TreeSlot.joined),
                    grown,
                  ),
                  size: disc,
                ),
              );
            }

            return Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _LinkPainter(
                        links: links,
                        drawn: _part(
                          t,
                          0,
                          0.30,
                          AppMotion.emphasizedDecelerate,
                        ),
                        direction: direction,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _mirror(you.dx, w, rtl) - _youSize / 2,
                  top: you.dy - _youSize / 2,
                  child: const _YouDisc(
                    key: Key('invite-tree-intro-you'),
                    size: _youSize,
                  ),
                ),
                Positioned(
                  left: _mirror(you.dx, w, rtl) - 45,
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
                for (var i = 0; i < n; i++)
                  Positioned(
                    left: rtl ? w - capsuleLeft - capsuleWidth : capsuleLeft,
                    top: top + i * (capsuleHeight + _capsuleGap),
                    child: PairCapsule(
                      key: Key('invite-tree-intro-pair-$i'),
                      slots: const [TreeSlot.empty, TreeSlot.empty],
                      discSize: disc,
                      gap: _discGap,
                      padding: _capsulePadding,
                      labelled: false,
                      discBuilder: (index, _) => disc0(i, index),
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

/// Step 2: one pair, which adds the most once both friends in it are
/// active. The amounts are the first pair's, as the backend sent them.
class _PairPage extends StatelessWidget {
  const _PairPage({
    required this.status,
    required this.play,
    required this.artHeight,
  });

  final ReferralStatus status;
  final Animation<double> play;
  final double artHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final first = status.pairs.isEmpty ? null : status.pairs.first;
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
    final firstFull = full;
    final later = status.pairs.skip(1).toList();
    final othersLess =
        firstFull != null &&
        later.isNotEmpty &&
        later.every((p) => p.fullBytes != null && p.fullBytes! < firstFull);
    final days = status.activeDays;
    final window = status.activeWindowDays;
    final active = days != null && window != null
        ? NumberLocalizer.localize(
            l10n.inviteTreeHowActive(days, window),
            context,
          )
        : l10n.inviteTreeHowActiveNoNumber;
    return _Page(
      art: Semantics(
        image: true,
        label: l10n.inviteTreeIntroPairArt,
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: play,
            builder: (context, child) {
              final both = _part(play.value, 0.55, 0.70);
              return _ArtCard(
                key: const Key('invite-tree-intro-art-1'),
                height: artHeight,
                glow: AppDesign.protected.withValues(alpha: 0.12 * both),
                child: child!,
              );
            },
            child: _PairArt(
              play: play,
              full: fullText,
              one: oneText,
              oneIsNothing: one == 0,
            ),
          ),
        ),
      ),
      title: l10n.inviteTreeIntroPairTitle,
      body: body,
      notes: [
        if (othersLess)
          (
            Icons.people_outline_rounded,
            l10n.inviteTreeIntroPairOthersLess,
            const Key('invite-tree-intro-note-others'),
          ),
        (
          Icons.event_repeat_outlined,
          active,
          const Key('invite-tree-intro-note-active'),
        ),
      ],
    );
  }
}

class _PairArt extends StatelessWidget {
  const _PairArt({
    required this.play,
    required this.full,
    required this.one,
    required this.oneIsNothing,
  });

  final Animation<double> play;

  /// The amounts, ready to show, or null when the backend did not say.
  final String? full;
  final String? one;

  /// The backend said one active friend alone adds nothing.
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
              final firstOn = _part(t, 0.20, 0.35, AppMotion.standard);
              final secondOn = _part(t, 0.55, 0.70, AppMotion.standard);
              final chipIn = _part(t, 0.20, 0.35);
              final bothPhase = t >= 0.55;

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

              // What the chip says now. The number switches at once, half
              // way through; it is never counted up.
              final (
                String? chipText,
                Color chipInk,
                Color chipFill,
              ) = bothPhase
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
                      l10n.inviteTreeNothingYet,
                      AppDesign.textTertiary,
                      AppDesign.surfaceHighest,
                    )
                  : (null, AppDesign.textPrimary, AppDesign.surfaceHighest);
              final chipAlpha = full == null ? 0.0 : chipIn;

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
                        color: chipFill.withValues(
                          alpha: chipText == null ? 0 : chipAlpha,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppDesign.radiusFull,
                        ),
                      ),
                      child: Text(
                        // A space keeps the chip's height while it is empty.
                        chipText ?? ' ',
                        key: const Key('invite-tree-intro-chip'),
                        maxLines: 1,
                        style: AppDesign.textTheme.labelLarge?.copyWith(
                          color: chipInk.withValues(
                            alpha: chipText == null ? 0 : chipAlpha,
                          ),
                          fontFeatures: AppDesign.numberFeatures,
                        ),
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
                        secondOn,
                      )!.withValues(alpha: appear),
                      edge: AppDesign.protected.withValues(
                        alpha: secondOn * appear,
                      ),
                      labelled: false,
                      discBuilder: (index, _) => SlotDisc(
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

/// Step 3: a friend's first pair adds data for the friend and for the
/// user, and a pair further away adds less.
class _FurtherPage extends StatelessWidget {
  const _FurtherPage({required this.play, required this.artHeight});

  final Animation<double> play;
  final double artHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return _Page(
      art: Semantics(
        image: true,
        label: l10n.inviteTreeIntroFurtherArt,
        child: ExcludeSemantics(
          child: _ArtCard(
            key: const Key('invite-tree-intro-art-2'),
            height: artHeight,
            glow: AppDesign.brand.withValues(alpha: 0.10),
            focus: const Offset(0.12, 0.5),
            child: _FurtherArt(play: play),
          ),
        ),
      ),
      title: l10n.inviteTreeIntroFurtherTitle,
      body: l10n.inviteTreeHowFriendsSlots,
      notes: [
        (
          Icons.people_outline_rounded,
          l10n.inviteTreeIntroFirstPairOnly,
          const Key('invite-tree-intro-note-first-pair'),
        ),
      ],
    );
  }
}

class _FurtherArt extends StatelessWidget {
  const _FurtherArt({required this.play});

  final Animation<double> play;

  static const double _youSize = 48;
  static const double _peerDisc = 32;
  static const double _pairDisc = 24;
  static const double _furtherDisc = 18;
  static const double _captionWidth = 76;
  static const double _badgeSize = 16;

  /// How strongly the further pair shows: its colors mixed with the card.
  static const double _faint = 0.55;

  static SlotLook _faded(SlotLook look) => SlotLook(
    fill: Color.lerp(AppDesign.surfaceLow, look.fill, _faint)!,
    edge: Color.lerp(AppDesign.surfaceLow, look.edge, _faint)!,
    icon: look.icon,
    iconColor: Color.lerp(AppDesign.surfaceLow, look.iconColor, _faint)!,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final direction = Directionality.of(context);
    final rtl = direction == TextDirection.rtl;
    final large = MediaQuery.textScalerOf(context).scale(10) >= 13;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final captions = w >= 340 && !large;
        final y = h / 2 - (captions ? 14 : 0);
        final you = Offset(w * 0.12, y);
        final friend = Offset(w * 0.38, y);
        final pair = Offset(w * 0.64, y);
        final further = Offset(w * 0.88, y);
        const pairWidth = 2 * _pairDisc + 4 + 2 * 6;
        const pairHeight = _pairDisc + 2 * 6;
        const furtherWidth = 2 * _furtherDisc + 4 + 2 * 4;
        const furtherHeight = _furtherDisc + 2 * 4;
        final links = [
          _Link(you, friend, 1.5),
          _Link(friend, pair, 1.25),
          _Link(pair, further, 1),
        ];
        double left(Offset centre, double width) =>
            _mirror(centre.dx, w, rtl) - width / 2;
        final captionStyle = AppDesign.textTheme.labelMedium?.copyWith(
          color: AppDesign.textTertiary,
        );

        Widget caption(Offset centre, double below, String text, Key key) =>
            Positioned(
              left: left(centre, _captionWidth),
              width: _captionWidth,
              top: centre.dy + below / 2 + 8,
              child: Text(
                text,
                key: key,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: captionStyle,
              ),
            );

        return AnimatedBuilder(
          animation: play,
          builder: (context, _) {
            final t = play.value;
            final drawn = _part(t, 0, 0.20, AppMotion.emphasizedDecelerate);
            final first = _part(t, 0.20, 0.40, AppMotion.emphasizedDecelerate);
            final second = _part(t, 0.40, 0.60, AppMotion.emphasizedDecelerate);
            final far = _part(t, 0.45, 0.85, AppMotion.emphasizedDecelerate);
            final badge = _part(t, 0.80, 1, AppMotion.emphasizedDecelerate);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _LinkPainter(
                        links: links,
                        drawn: drawn,
                        direction: direction,
                        curved: false,
                        dots: [
                          _Dot(const [1], first, 6),
                          _Dot(const [0], second, 4),
                          _Dot(const [2, 1, 0], far, 4 - 2 * far),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: left(you, _youSize),
                  top: you.dy - _youSize / 2,
                  width: _youSize,
                  height: _youSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const _YouDisc(
                        key: Key('invite-tree-intro-you-3'),
                        size: _youSize,
                      ),
                      if (badge > 0)
                        PositionedDirectional(
                          end: -_badgeSize / 4,
                          bottom: -_badgeSize / 4,
                          child: _PlusBadge(size: _badgeSize, show: badge),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: left(friend, _peerDisc),
                  top: friend.dy - _peerDisc / 2,
                  child: const SlotMark(
                    key: Key('invite-tree-intro-friend'),
                    slot: TreeSlot.active,
                    size: _peerDisc,
                    labelled: false,
                  ),
                ),
                Positioned(
                  left: left(pair, pairWidth),
                  top: pair.dy - pairHeight / 2,
                  child: const PairCapsule(
                    slots: [TreeSlot.active, TreeSlot.active],
                    discSize: _pairDisc,
                    labelled: false,
                  ),
                ),
                Positioned(
                  left: left(further, furtherWidth),
                  top: further.dy - furtherHeight / 2,
                  child: PairCapsule(
                    slots: const [TreeSlot.active, TreeSlot.joined],
                    discSize: _furtherDisc,
                    padding: 4,
                    fill: Color.lerp(
                      AppDesign.surfaceLow,
                      AppDesign.surfaceHigh,
                      _faint,
                    )!,
                    labelled: false,
                    discBuilder: (_, slot) => SlotDisc(
                      look: _faded(SlotLook.of(slot)),
                      size: _furtherDisc,
                    ),
                  ),
                ),
                if (captions) ...[
                  caption(
                    friend,
                    _peerDisc,
                    l10n.inviteTreeIntroYourFriend,
                    const Key('invite-tree-intro-caption-friend'),
                  ),
                  caption(
                    pair,
                    pairHeight,
                    l10n.inviteTreeIntroTheirPair,
                    const Key('invite-tree-intro-caption-pair'),
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

/// Step 4: the user's data from friends now, against the most invites can
/// add, and what was kept from earlier invites. Every number here is from
/// the referral answer.
class _TotalPage extends StatelessWidget {
  const _TotalPage({
    required this.status,
    required this.noMore,
    required this.play,
    required this.artHeight,
  });

  final ReferralStatus status;
  final bool noMore;
  final Animation<double> play;
  final double artHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final bonus = status.bonusBytes;
    final most = status.maxBonusBytes;
    final kept = (status.keptBytes ?? 0) > 0 ? status.keptBytes : null;
    final total = status.maxTotalBytes;
    final body = noMore
        ? l10n.premiumLimitInvitesFull
        : total != null
        ? l10n.inviteTreeIntroTotalReach(inviteAmountText(context, total))
        : most != null
        ? l10n.inviteTreeHowCap(inviteAmountText(context, most))
        : l10n.inviteTreeHowCapNoAmount;
    return _Page(
      art: _ArtCard(
        key: const Key('invite-tree-intro-art-3'),
        height: artHeight,
        grows: true,
        glow: AppDesign.brand.withValues(alpha: 0.10),
        focus: const Offset(0.2, 0.2),
        child: _TotalArt(play: play, bonus: bonus, most: most, kept: kept),
      ),
      title: l10n.inviteTreeIntroTotalTitle,
      body: body,
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

    Widget legend(
      Color swatch,
      Color? edge,
      String label,
      String value,
      double show,
      Key key,
    ) => MergeSemantics(
      key: key,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: Container(
              width: _swatchSize,
              height: _swatchSize,
              decoration: BoxDecoration(
                color: swatch.withValues(alpha: swatch.a * show),
                borderRadius: BorderRadius.circular(3),
                border: edge == null
                    ? null
                    : Border.all(color: edge.withValues(alpha: show)),
              ),
            ),
          ),
          const SizedBox(width: AppDesign.space8),
          Expanded(
            child: Text(
              label,
              style: AppDesign.textTheme.bodyMedium?.copyWith(
                color: AppDesign.textSecondary.withValues(alpha: show),
              ),
            ),
          ),
          const SizedBox(width: AppDesign.space8),
          Text(
            value,
            style: AppDesign.textTheme.titleSmall?.copyWith(
              color: AppDesign.textPrimary.withValues(alpha: show),
              fontFeatures: AppDesign.numberFeatures,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(AppDesign.space16),
      child: AnimatedBuilder(
        animation: play,
        builder: (context, _) {
          final t = play.value;
          final grown = _part(t, 0, 0.60, AppMotion.emphasizedDecelerate);
          final shown = _part(t, 0.50, 0.90);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.inviteTreeIntroTotalNow,
                style: AppDesign.textTheme.labelMedium?.copyWith(
                  color: AppDesign.textTertiary,
                ),
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
                const SizedBox(height: AppDesign.space12),
                legend(
                  AppDesign.surfaceHighest,
                  AppDesign.outlineVariant,
                  l10n.inviteTreeIntroTotalMost,
                  l10n.inviteTreeIntroPerDay(inviteAmountText(context, most)),
                  shown,
                  const Key('invite-tree-intro-most-row'),
                ),
                if (tick) ...[
                  const SizedBox(height: AppDesign.space8),
                  legend(
                    AppDesign.textTertiary,
                    null,
                    l10n.inviteTreeIntroTotalKept,
                    l10n.inviteTreeIntroPerDay(inviteAmountText(context, kept)),
                    shown,
                    const Key('invite-tree-intro-kept-row'),
                  ),
                ],
              ] else ...[
                const SizedBox(height: AppDesign.space16),
                ExcludeSemantics(
                  child: SizedBox(
                    width: _youSize,
                    height: _youSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const _YouDisc(size: _youSize),
                        PositionedDirectional(
                          end: -_badgeSize / 4,
                          bottom: -_badgeSize / 4,
                          child: const _PlusBadge(size: _badgeSize, show: 1),
                        ),
                      ],
                    ),
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
