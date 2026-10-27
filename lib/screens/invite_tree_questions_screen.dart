import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/referral_service.dart';
import '../core/design_system.dart';
import '../core/form_factor.dart';
import '../core/page_transitions.dart';
import '../core/state/referral_state.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/number_localizer.dart';
import '../widgets/invite_slots.dart';
import '../widgets/readable_width.dart';
import 'invite_tree_intro_screen.dart';

/// Questions and answers about the invite tree: what people ask once they
/// have read the introduction. Each answer is built from the user's own
/// referral answer, and every number in it is the backend's, with a line
/// that names no number when the backend sent none.
///
/// It exists only under the tree rule, like the introduction: a status
/// that stops being a tree status while it is open closes it. The words
/// talk about friends, slots, pairs and data, never about levels or ranks,
/// never put people under or below the user, and never say anyone earns
/// or pays.
class InviteTreeQuestionsScreen extends StatefulWidget {
  const InviteTreeQuestionsScreen({super.key});

  /// Open the questions over [context]. Never throws.
  static Future<void> open(BuildContext context) async {
    try {
      final Route<dynamic> route = AppMotion.reduced(context)
          ? PageRouteBuilder<dynamic>(
              pageBuilder: (_, _, _) =>
                  const ReadableWidth(child: InviteTreeQuestionsScreen()),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            )
          : SlideUpFadeTransition(page: const InviteTreeQuestionsScreen());
      await Navigator.of(context).push<dynamic>(route);
    } catch (e) {
      debugPrint('InviteTreeQuestionsScreen: not opened ($e)');
    }
  }

  @override
  State<InviteTreeQuestionsScreen> createState() =>
      _InviteTreeQuestionsScreenState();
}

/// One question: its id for the row's key, the question, and the answer
/// as paragraphs.
typedef InviteTreeQuestion = ({
  String id,
  String question,
  List<String> answer,
});

/// The questions for [status], in their order, each with the answer for
/// this user. [noMore] is ReferralState.invitesAddNoMore, and [belowKept]
/// is ReferralState.nextFriendBelowKept.
///
/// When the tree rule is switched on, nearly everyone who reads this has
/// invited people before, so what changed and what happens to the bonus
/// they have come first.
List<InviteTreeQuestion> inviteTreeQuestions(
  BuildContext context,
  ReferralStatus status, {
  required bool noMore,
  bool belowKept = false,
}) {
  final l10n = S.of(context)!;
  String amount(int bytes) => inviteAmountText(context, bytes);
  String number(String text) => NumberLocalizer.localize(text, context);
  final kept = (status.keptBytes ?? 0) > 0 ? status.keptBytes : null;
  final most = status.maxBonusBytes;
  final total = status.maxTotalBytes;
  final next = status.nextInviteBytes;
  // A kept bonus at or above the limit: the free data and invites together
  // are then the kept bonus, so the line about the total would not hold.
  final keptAtMost = kept != null && most != null && kept >= most;
  final ownFull =
      status.pairs.isNotEmpty &&
      status.pairs.every((p) => !p.slots.contains(TreeSlot.empty));
  final keptLine = kept == null ? null : l10n.inviteTreeKept(amount(kept));
  final premiumDays = status.earns ? status.rewardPremiumDays : null;
  final premiumMax = status.premiumDaysMax;

  return [
    (
      id: 'changed',
      question: l10n.inviteTreeQaChangedQ,
      answer: [l10n.inviteTreeQaChangedA, ?keptLine],
    ),
    if (keptLine != null)
      (
        id: 'kept',
        question: l10n.inviteTreeQaKeptQ,
        answer: [
          keptLine,
          l10n.inviteTreeQaKeptMore,
          if (belowKept) l10n.inviteTreeKeptFloor,
          l10n.inviteTreeQaKeptRemoved,
        ],
      ),
    (
      id: 'count',
      question: l10n.inviteTreeQaCountQ,
      answer: [
        inviteTreeJoinCodeText(context, status.claimWindowHours),
        inviteTreeJoinQualifyText(context, status.confirmActiveDays),
        l10n.inviteTreeQaCountDay,
        l10n.inviteTreeIntroJoinWaiting,
        l10n.inviteTreeIntroJoinPlay,
        l10n.inviteTreeQaCountOther,
      ],
    ),
    (
      id: 'down',
      question: l10n.inviteTreeQaDownQ,
      answer: [
        l10n.inviteTreeQaDownA,
        inviteTreeActiveText(context, status),
        l10n.inviteTreeQaDownLater,
        l10n.inviteTreeQaDownRemoved,
        ?keptLine,
      ],
    ),
    (
      id: 'full',
      question: l10n.inviteTreeQaFullQ,
      answer: [
        l10n.inviteTreeIntroFullBody,
        l10n.inviteTreeQaFullFurther,
        l10n.inviteTreeIntroFullLess,
        if (ownFull && next != null && !noMore)
          l10n.inviteTreeNext(amount(next)),
      ],
    ),
    (
      id: 'start',
      question: l10n.inviteTreeQaStartQ,
      answer: [l10n.inviteTreeQaStartA],
    ),
    (
      id: 'cost',
      question: l10n.inviteTreeQaCostQ,
      answer: [l10n.inviteTreeQaCostA],
    ),
    (
      id: 'friends',
      question: l10n.inviteTreeQaFriendsQ,
      answer: [l10n.inviteTreeQaFriendsA],
    ),
    if (status.hasClaimed)
      (
        id: 'others',
        question: l10n.inviteTreeQaOthersQ,
        answer: [l10n.inviteTreeQaOthersA, l10n.inviteTreeIntroOthersYours],
      ),
    (
      id: 'sum',
      question: l10n.inviteTreeQaSumQ,
      answer: [
        l10n.inviteTreeQaSumA,
        if (kept != null) l10n.inviteTreeQaKeptMore,
      ],
    ),
    (
      id: 'slot',
      question: l10n.inviteTreeQaSlotQ,
      answer: [l10n.inviteTreeQaSlotA],
    ),
    (
      id: 'phone',
      question: l10n.inviteTreeQaPhoneQ,
      answer: [l10n.inviteTreeQaPhoneA],
    ),
    (
      id: 'privacy',
      question: l10n.inviteTreeQaPrivacyQ,
      answer: [l10n.inviteTreeQaPrivacyA],
    ),
    (
      id: 'limit',
      question: l10n.inviteTreeQaLimitQ,
      // Both limits named in one sentence, so nobody wonders which one
      // holds.
      answer: [
        if (most != null && total != null && !keptAtMost)
          l10n.inviteTreeIntroTotalUpTo(amount(most), amount(total))
        else if (most != null)
          l10n.inviteTreeHowCap(amount(most))
        else
          l10n.inviteTreeHowCapNoAmount,
        l10n.inviteTreeQaLimitMore,
        if (most == null && total != null && !keptAtMost)
          l10n.inviteTreeIntroTotalReach(amount(total)),
      ],
    ),
    if (premiumDays != null)
      (
        id: 'premium',
        question: l10n.inviteTreeQaPremiumQ,
        answer: [
          number(l10n.inviteTreePremiumEach(premiumDays)),
          if (premiumMax != null) number(l10n.inviteTreePremiumCap(premiumMax)),
          l10n.inviteTreeQaPremiumOwn,
        ],
      ),
    (
      id: 'gets',
      question: l10n.inviteTreeQaGetsQ,
      answer: [l10n.inviteTreeQaGetsA, l10n.inviteTreeQaGetsSee],
    ),
  ];
}

class _InviteTreeQuestionsScreenState extends State<InviteTreeQuestionsScreen> {
  /// The ids of the questions open now. Every one starts closed, and any
  /// number can be open at once.
  final Set<String> _open = {};
  bool _leaving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final referrals = context.watch<ReferralState>();
    final status = referrals.status;
    if (status == null || !status.isTree) {
      // The tree rule is gone, or the status with it.
      if (!_leaving) {
        _leaving = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(Navigator.of(context).maybePop());
        });
      }
      return const Scaffold(backgroundColor: AppDesign.canvas);
    }
    final questions = inviteTreeQuestions(
      context,
      status,
      noMore: referrals.invitesAddNoMore,
      belowKept: referrals.nextFriendBelowKept,
    );
    return Scaffold(
      backgroundColor: AppDesign.canvas,
      appBar: AppBar(
        backgroundColor: AppDesign.canvas,
        title: Semantics(header: true, child: Text(l10n.inviteTreeQaTitle)),
      ),
      body: ListView.separated(
        padding: AppDesign.clearOfNavBar(
          context,
          const EdgeInsets.fromLTRB(16, 8, 16, 24),
        ),
        // The questions, then a way back to the story itself.
        itemCount: questions.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: AppDesign.space8),
        itemBuilder: (context, i) {
          if (i == questions.length) {
            return Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('invite-tree-questions-intro'),
                onPressed: () => unawaited(InviteTreeIntroScreen.open(context)),
                icon: const Icon(Icons.auto_stories_outlined, size: 18),
                label: Text(l10n.inviteTreeIntroOpen),
                style: TextButton.styleFrom(
                  foregroundColor: AppDesign.brandBright,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 12, 0),
                ),
              ),
            );
          }
          final q = questions[i];
          return _QuestionTile(
            rowKey: Key('invite-tree-qa-${q.id}'),
            question: q.question,
            answer: q.answer,
            open: _open.contains(q.id),
            autofocus: FormFactor.isTv && i == 0,
            onTap: () => setState(() {
              if (!_open.remove(q.id)) _open.add(q.id);
            }),
          );
        },
      ),
    );
  }
}

/// One question: the question with a chevron, and its answer under it
/// while open.
class _QuestionTile extends StatelessWidget {
  const _QuestionTile({
    required this.rowKey,
    required this.question,
    required this.answer,
    required this.open,
    required this.autofocus,
    required this.onTap,
  });

  /// The key of the row with the question, the part a tap opens and
  /// closes.
  final Key rowKey;
  final String question;
  final List<String> answer;
  final bool open;
  final bool autofocus;
  final VoidCallback onTap;

  static const double _rowHeight = 56;

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    final radius = AppDesign.borderRadiusLarge;
    final body = open
        ? Padding(
            key: const ValueKey('answer'),
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppDesign.space16,
              0,
              AppDesign.space16,
              AppDesign.space16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, paragraph) in answer.indexed) ...[
                  if (i > 0) const SizedBox(height: AppDesign.space8),
                  Text(
                    paragraph,
                    style: AppDesign.textTheme.bodyMedium?.copyWith(
                      color: AppDesign.textSecondary,
                      fontFeatures: AppDesign.numberFeatures,
                    ),
                  ),
                ],
              ],
            ),
          )
        : const SizedBox(key: ValueKey('closed'), width: double.infinity);
    return Material(
      color: AppDesign.surfaceLow,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            child: InkWell(
              key: rowKey,
              onTap: onTap,
              autofocus: autofocus,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _rowHeight),
                child: Padding(
                  padding: const EdgeInsets.all(AppDesign.space16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          question,
                          style: AppDesign.textTheme.titleSmall?.copyWith(
                            color: AppDesign.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDesign.space12),
                      ExcludeSemantics(
                        child: AnimatedRotation(
                          turns: open ? 0.5 : 0,
                          duration: reduced ? Duration.zero : AppMotion.quick,
                          child: const Icon(
                            Icons.expand_more_rounded,
                            size: 24,
                            color: AppDesign.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Under less motion the answer is swapped in at once: an
          // AnimatedSize with no duration relays itself out during layout.
          if (reduced)
            body
          else
            AnimatedSize(
              duration: AppMotion.quick,
              curve: AppMotion.standard,
              alignment: AlignmentDirectional.topStart,
              child: body,
            ),
        ],
      ),
    );
  }
}
