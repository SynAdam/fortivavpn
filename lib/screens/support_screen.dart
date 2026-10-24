import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/design_system.dart';
import '../core/haptics.dart';
import '../core/state/app_config_state.dart';
import '../core/state/support_state.dart';
import '../data/models/support_chat.dart';
import '../data/models/version_info.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/number_localizer.dart';
import '../widgets/chatbot_glyph.dart';
import '../widgets/focus_ring.dart';
import '../widgets/message_dialog.dart';
import '../widgets/outside_link.dart';
import '../widgets/support_thinking.dart';
import '../widgets/tappable.dart';
import '../widgets/typed_text.dart';
import '../widgets/ui/pressable.dart';

/// Limits a text field to a number of Unicode code points.
///
/// Flutter's own maxLength counts grapheme clusters, so an emoji built from
/// five code points counts once there and five times on the backend, which
/// counts code points. Text an input method is still composing is let
/// through, because cutting a word in the middle of composing breaks it;
/// the send button stays off until the text fits again.
///
/// An edit that does not fit loses the end of what it put in, never any of
/// the text that was already there, so a paste into the middle of a long
/// message keeps the message whole.
class RuneLimitFormatter extends TextInputFormatter {
  const RuneLimitFormatter(this.maxRunes);

  final int maxRunes;

  static int count(String text) => text.runes.length;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final length = count(newValue.text);
    if (length <= maxRunes) return newValue;
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    final before = oldValue.text.runes.toList();
    final after = newValue.text.runes.toList();
    // A deletion from text that is already too long has to go through, or
    // the user could never get back under the limit.
    if (after.length <= before.length) return newValue;
    // The edit is what lies between the start and the end the old and the
    // new text share.
    var start = 0;
    while (start < before.length &&
        start < after.length &&
        before[start] == after[start]) {
      start++;
    }
    var end = 0;
    while (end < before.length - start &&
        end < after.length - start &&
        before[before.length - 1 - end] == after[after.length - 1 - end]) {
      end++;
    }
    final replaced = before.length - start - end;
    final room = maxRunes - (before.length - replaced);
    if (room <= 0) return oldValue;
    final head = String.fromCharCodes([
      ...after.sublist(0, start),
      ...after.sublist(start, after.length - end).take(room),
    ]);
    return TextEditingValue(
      text: head + String.fromCharCodes(after.sublist(after.length - end)),
      selection: TextSelection.collapsed(offset: head.length),
    );
  }
}

/// The support chat: questions to the assistant, replies from our team,
/// and what the user may still ask today.
///
/// Answers are written by an automatic assistant from what we know about
/// using the app, so a line at the top says they can be wrong. While a
/// question waits, the assistant's side of the chat shows it thinking. An
/// answer that arrives while the chat is open is typed out word by word;
/// it is whole on the phone by then, after the backend's checks, so the
/// typing is only how it appears. What was there when the chat opened
/// shows at once.
///
/// When a limit is reached, a card says which one and until when, and the
/// input box is off until then with the same words in it. Nothing on the
/// card is a way around the limit. A message goes to our team only while
/// automatic answers are off for everyone, or, once the day's questions
/// are used up, in a conversation the assistant handed to our team, so the
/// user can still answer them. Every refusal is shown as a short line in
/// the app's language; the backend only sends its code.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, this.open});

  /// Opens a link outside the app. Passed in by tests.
  final Future<void> Function(Uri url)? open;

  /// The Telegram channel offered while the chat is off: the one the
  /// backend names (AppConfigState.channelUrl), or the official channel
  /// where the app's config is not provided.
  static Uri telegram(BuildContext context) =>
      context.read<AppConfigState?>()?.channelUrl ??
      Uri.parse(PlatformVersion.defaultChannelUrl);

  /// The line for one of the backend's codes, or null for a code this
  /// build does not know.
  static String? codeText(S l10n, String? code) => switch (code) {
    'too_long' => l10n.supportCodeTooLong(SupportState.maxRunes),
    'empty' => l10n.supportCodeEmpty,
    'wait_reply' => l10n.supportCodeWaitReply,
    'slow_down' => l10n.supportCodeSlowDown,
    // An older backend also limits a conversation. To the user it is the
    // same: no more questions until the time on the card.
    'quota_day' || 'quota_conversation' => l10n.supportCodeQuotaDay,
    'paused' => l10n.supportCodePaused,
    'busy' => l10n.supportCodeBusy,
    'off' => l10n.supportUnavailable,
    'greeting' => l10n.supportCodeGreeting,
    'gibberish' => l10n.supportCodeGibberish,
    'redacted' => l10n.supportCodeRedacted,
    'redacted_empty' => l10n.supportCodeRedactedEmpty,
    // Saying it was taken for an attack helps nobody who was not attacking.
    'injection' || 'off_topic' => l10n.supportCodeOffTopic,
    'abuse' => l10n.supportCodeAbuse,
    'ai_unavailable' => l10n.supportCodeAiUnavailable,
    'to_staff' => l10n.supportCodeToStaff,
    'ticket_opened' => l10n.supportCodeTicketOpened,
    SupportState.notSent => l10n.supportCodeNotSent,
    'error' => l10n.supportGenericError,
    _ => null,
  };

  /// When the user may ask again, as a sentence, or null when the backend
  /// did not say. Rounded up to the minute, so it never reads zero while
  /// the user still has to wait, and a whole number of hours has no
  /// minutes after it.
  static String? waitText(S l10n, DateTime? until, DateTime now) {
    if (until == null) return null;
    final seconds = until.difference(now).inSeconds;
    final minutes = math.max(1, (seconds / 60).ceil());
    final time = minutes < 60
        ? l10n.supportDurationMinutes(minutes)
        : minutes % 60 == 0
        ? l10n.supportDurationWholeHours(minutes ~/ 60)
        : l10n.supportDurationHours(minutes ~/ 60, minutes % 60);
    return l10n.supportWaitIn(time);
  }

  /// The words in the input box while [limit] holds: when the user may ask
  /// again, or, with no time to give, what the limit is. A busy assistant
  /// gives a time of its own, but a minute counted down there would read
  /// as a promise, so it says to try again soon instead.
  static String limitHint(S l10n, SupportLimit limit, DateTime now) {
    if (limit.code == 'busy') return l10n.supportTryAgainSoon;
    return waitText(l10n, limit.until, now) ??
        codeText(l10n, limit.code) ??
        l10n.supportGenericError;
  }

  /// The questions offered on an empty chat. Tapping one asks it, and it
  /// counts like any other question.
  static List<String> suggestions(S l10n) => [
    l10n.supportSuggestConnect,
    l10n.supportSuggestData,
    l10n.supportSuggestSlow,
  ];

  /// The language to lay [text] out in: the app's own when the text starts
  /// in the app's script, else a stand-in for the script it starts in. So
  /// Persian typed in an English app reads right to left, and English in a
  /// Persian app left to right.
  static String layoutLanguage(String text, String appLanguage) {
    final appRtl = MessageText.isRtl(appLanguage);
    for (final rune in text.runes) {
      if (_isArabicScript(rune)) return appRtl ? appLanguage : 'fa';
      if (_isLatinLetter(rune)) return appRtl ? 'en' : appLanguage;
    }
    return appLanguage;
  }

  static bool _isArabicScript(int rune) =>
      (rune >= 0x0600 && rune <= 0x06FF) ||
      (rune >= 0x0750 && rune <= 0x077F) ||
      (rune >= 0x08A0 && rune <= 0x08FF) ||
      (rune >= 0xFB50 && rune <= 0xFDFF) ||
      (rune >= 0xFE70 && rune <= 0xFEFF);

  static bool _isLatinLetter(int rune) =>
      (rune >= 0x41 && rune <= 0x5A) ||
      (rune >= 0x61 && rune <= 0x7A) ||
      (rune >= 0xC0 && rune <= 0x024F && rune != 0xD7 && rune != 0xF7);

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

/// Who a line of the conversation is from. Lines from one author in a row
/// sit close together, and a change of author gets more room, so the
/// conversation reads as turns rather than as a column of boxes.
enum _Author { user, assistant, staff, system, divider }

/// One line of the conversation as the list draws it.
class _Entry {
  const _Entry(this.key, this.child, {required this.first, required this.last});

  /// Stays the same while a message goes from waiting on the phone to
  /// stored, so its place in the list, and its animations, stay too.
  final String key;
  final Widget child;

  /// Who the line starts and ends with. Only a greeting differs: the
  /// user's hello with the app's own answer under it.
  final _Author first;
  final _Author last;
}

class _SupportScreenState extends State<SupportScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  /// The New conversation and Send buttons' focus, so each can stay on
  /// while a TV remote has it focused.
  final _newChatFocus = FocusNode(debugLabel: 'support new conversation');
  final _sendFocus = FocusNode(debugLabel: 'support send');

  /// The state this screen told it is open, so it can say it closed.
  SupportState? _attached;

  /// How many fetches the state had made when the screen opened, and the
  /// time then on the server's clock. Null until the first frame.
  int? _openFetches;
  DateTime? _openedAt;

  /// The newest message id after the first fetch since the screen opened.
  /// Everything up to it is history and shows at once; only what comes
  /// later is typed out and slides in. Null until that fetch is back.
  int? _historyUpTo;

  /// Replies that have been typed out, or tapped to show whole.
  final _revealed = <int>{};

  /// Lines that have had their entrance, so a rebuild or a scroll back to
  /// them never runs it again.
  final _entered = <String>{};

  /// What a screen reader has been told about: new replies by id, limits
  /// and refusals. Each is a live region for the frame it first shows in
  /// and never again, so a reply scrolled back to, or a card whose minutes
  /// tick down, is not read out a second time.
  final _announced = <Object>{};

  /// Wakes the screen when the limit on screen runs out, so the input box
  /// comes back on without waiting for the next fetch.
  Timer? _limitTimer;
  DateTime? _limitUntil;

  /// A message waiting on the phone counts as new when it was written
  /// after the screen opened, give or take the gap between the clocks.
  static const _clockSlack = Duration(seconds: 2);

  /// The room between two lines from the same author, and between lines
  /// from different ones.
  static const double _sameAuthorGap = 4;
  static const double _newAuthorGap = 14;

  /// The least a finger can hit reliably.
  static const double _tapHeight = 48;

  @override
  void initState() {
    super.initState();
    _input.addListener(_inputChanged);
    _newChatFocus.addListener(_inputChanged);
    _sendFocus.addListener(_inputChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final state = context.read<SupportState?>();
        if (state == null) return;
        _openFetches = state.fetches;
        _openedAt = state.serverNow();
        _attached = state..attach();
      } catch (e) {
        debugPrint('SupportScreen: could not open the chat ($e)');
      }
    });
  }

  @override
  void dispose() {
    try {
      _attached?.detach();
    } catch (e) {
      debugPrint('SupportScreen: could not close the chat ($e)');
    }
    _limitTimer?.cancel();
    _input.removeListener(_inputChanged);
    _input.dispose();
    _focus.dispose();
    _newChatFocus.removeListener(_inputChanged);
    _newChatFocus.dispose();
    _sendFocus.removeListener(_inputChanged);
    _sendFocus.dispose();
    super.dispose();
  }

  /// The counter and the send button follow the text, and the two
  /// buttons that turn off follow their focus.
  void _inputChanged() {
    if (mounted) setState(() {});
  }

  /// Whether a question is on its way or waits for its answer. A new
  /// conversation started then would leave it behind in the old one, so
  /// a quick second tap could lose the question.
  static bool _waiting(SupportState state) =>
      state.pending || state.outbox.any((o) => o.sending || !o.failed);

  Future<void> _send(SupportState state) async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    AppHaptics.light();
    _input.clear();
    final result = await state.send(text);
    if (!mounted || result.accepted || _input.text.isNotEmpty) return;
    // Refused: the text goes back, so nothing the user wrote is lost.
    _input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Ask one of the suggested questions. Whatever the user has typed in
  /// the box stays there. Only when the question is refused and the box is
  /// empty does the question go into it, as a refused message would.
  Future<void> _ask(SupportState state, String question) async {
    AppHaptics.light();
    final result = await state.send(question);
    if (!mounted || result.accepted || _input.text.isNotEmpty) return;
    _input.value = TextEditingValue(
      text: question,
      selection: TextSelection.collapsed(offset: question.length),
    );
  }

  Future<void> _newConversation(SupportState state) async {
    // Checked again at the tap: the button stays on while a remote has it
    // focused, see build.
    if (_waiting(state)) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = S.of(context)!;
    final started = await state.startNewConversation();
    if (!started && mounted) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.supportGenericError)));
    }
  }

  Future<void> _rate(
    SupportState state,
    SupportMessage message,
    bool up,
  ) async {
    final id = message.id;
    if (id == null) return;
    AppHaptics.selection();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = S.of(context)!;
    final rated = await state.rate(id, up: up);
    if (rated && !up && mounted) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.supportRatedDown)));
    }
  }

  Future<void> _openTelegram() async {
    try {
      final channel = SupportScreen.telegram(context);
      final open = widget.open;
      if (open != null) {
        await open(channel);
      } else {
        await openOutside(channel);
      }
    } catch (e) {
      debugPrint('SupportScreen: could not open Telegram ($e)');
    }
  }

  /// Once the first fetch since the screen opened is back, everything it
  /// left in the conversation is history.
  void _takeHistory(SupportState state) {
    final since = _openFetches;
    if (_historyUpTo != null || since == null || state.fetches <= since) {
      return;
    }
    var newest = 0;
    for (final m in state.messages) {
      final id = m.id ?? 0;
      if (id > newest) newest = id;
    }
    _historyUpTo = newest;
  }

  bool _isNew(SupportMessage m) {
    final id = m.id;
    if (id != null) {
      final upTo = _historyUpTo;
      return upTo != null && id > upTo;
    }
    return _writtenSinceOpen(m.createdAt);
  }

  bool _writtenSinceOpen(DateTime at) {
    final opened = _openedAt;
    return opened != null && !at.isBefore(opened.subtract(_clockSlack));
  }

  void _markRevealed(int id) {
    if (!mounted || _revealed.contains(id)) return;
    setState(() => _revealed.add(id));
  }

  /// Whether [key] is shown for the first time, so a screen reader should
  /// read it out now. From the next frame on it is not.
  bool _firstTime(Object key) {
    if (_announced.contains(key)) return false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _announced.add(key));
    return true;
  }

  /// Whether [m] is a reply that came while the chat was open and that a
  /// screen reader has not read out yet.
  bool _announce(SupportMessage m) {
    final id = m.id;
    return id != null && _isNew(m) && _firstTime(('reply', id));
  }

  /// Whether [m] is a reply that will be typed out word by word.
  ///
  /// A new reply shown whole because motion is off counts as revealed, so
  /// it is not typed out again from the first word when motion comes back.
  /// Flutter on Android turns accessible navigation on whenever any
  /// accessibility service reads the screen, and off when it stops.
  bool _typed(SupportMessage m, bool motion) {
    final id = m.id;
    if (id == null ||
        (m.role != 'assistant' && m.role != 'staff') ||
        !_isNew(m) ||
        _revealed.contains(id)) {
      return false;
    }
    if (!motion) {
      // This build shows it whole already, so no setState.
      _revealed.add(id);
      return false;
    }
    return true;
  }

  void _watchLimit(SupportState state, DateTime? until) {
    if (until == _limitUntil) return;
    _limitUntil = until;
    _limitTimer?.cancel();
    _limitTimer = null;
    if (until == null) return;
    final wait = until.difference(state.serverNow());
    if (wait.isNegative) return;
    _limitTimer = Timer(wait + const Duration(milliseconds: 100), () {
      _limitTimer = null;
      if (!mounted) return;
      setState(() {});
      // What is left now comes from the backend, not from the count that
      // ran out.
      unawaited(state.poll());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    SupportState? state;
    try {
      state = context.watch<SupportState?>();
    } catch (e) {
      debugPrint('SupportScreen: could not read the chat ($e)');
    }
    final on = state?.enabled ?? false;
    final waiting = state != null && _waiting(state);
    final team = state?.writesToTeam ?? false;
    return Scaffold(
      backgroundColor: AppDesign.canvas,
      appBar: AppBar(
        // The page's own color with no shadow or tint under it, even with
        // the conversation scrolled under: the header is part of the page.
        backgroundColor: AppDesign.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: _Header(
          title: l10n.supportTitle,
          team: team,
          subtitle: team
              ? l10n.supportTeamLabel
              : l10n.supportAssistantSubtitle,
        ),
        actions: [
          // Starts again without what was said before. It gives no
          // questions back, so it is never offered on a limit.
          //
          // Off while a question waits, so a second tap cannot leave the
          // question behind. Not while a TV remote has it focused, though:
          // a control that turns off loses the focus and leaves the remote
          // pointing at nothing. Then it stays on but looks off, and a
          // press does nothing until the answer is in.
          if (on)
            IconButton(
              focusNode: _newChatFocus,
              onPressed: waiting && !_newChatFocus.hasFocus
                  ? null
                  : () => _newConversation(state!),
              // A round bubble with a plus, like the rounded bubbles on the
              // starters, rather than the square, sharp-cornered one.
              icon: Icon(
                Icons.maps_ugc_outlined,
                color: waiting ? AppDesign.textDisabled : null,
              ),
              tooltip: l10n.supportNewConversation,
              style: IconButton.styleFrom(
                foregroundColor: AppDesign.textSecondary,
                disabledForegroundColor: AppDesign.textDisabled,
              ),
            ),
          // As far from the edge as the back button on the other side.
          const SizedBox(width: AppDesign.space4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: state == null
            ? _Unavailable(onTelegram: _openTelegram, centered: true)
            : _chat(context, l10n, state),
      ),
    );
  }

  Widget _chat(BuildContext context, S l10n, SupportState state) {
    _takeHistory(state);
    final appLanguage = Localizations.localeOf(context).languageCode;
    final now = state.serverNow();
    final team = state.writesToTeam;
    // Writing to our team, the assistant's limits do not apply; only the
    // backend's cap on messages to them does.
    final block = team ? state.teamLimit : state.limit;
    final notice = state.notice;
    final quota = state.quota;
    // A refusal whose wait is over says nothing any more, and one the card
    // already says is not said twice.
    final retryAt = notice?.retryAt;
    final over = retryAt != null && !retryAt.isAfter(now);
    final noticeText = notice == null || over || notice.code == block?.code
        ? null
        : SupportScreen.codeText(l10n, notice.code) ?? l10n.supportGenericError;
    _watchLimit(state, state.enabled ? block?.until : null);
    final canAsk = state.enabled && block == null && !state.pending;
    // With the chat off and nothing said yet, the way to reach us takes
    // the middle of the page instead of a hello that cannot be answered.
    final offAndEmpty =
        !state.enabled && state.messages.isEmpty && state.outbox.isEmpty;
    return Column(
      children: [
        _TopLine(
          text: state.teamOnly
              ? l10n.supportStaffNotice
              : l10n.supportAutomaticNotice,
        ),
        Expanded(
          child: offAndEmpty
              ? _Unavailable(onTelegram: _openTelegram, centered: true)
              : _conversation(context, l10n, state, appLanguage, canAsk),
        ),
        if (!state.enabled) ...[
          if (!offAndEmpty) _Unavailable(onTelegram: _openTelegram),
        ] else ...[
          if (block != null)
            _LimitCard(
              limit: block,
              now: now,
              announce: _firstTime(('limit', block.code, block.until)),
            ),
          if (team && !state.teamOnly)
            _Pill(
              l10n.supportWithTeam,
              key: const ValueKey('support-with-team'),
            ),
          if (noticeText != null)
            _Line(
              noticeText,
              color: AppDesign.warning,
              announce: _firstTime(notice!),
            ),
          // None left with no limit on screen means the day has just
          // turned over and the fetch with the new count is on its way.
          if (!state.teamOnly &&
              !team &&
              quota != null &&
              quota.remaining > 0 &&
              block == null)
            _Line(l10n.supportQuotaLeft(quota.remaining, quota.limit)),
          _composer(l10n, state, appLanguage, block: block, now: now),
        ],
      ],
    );
  }

  Widget _conversation(
    BuildContext context,
    S l10n,
    SupportState state,
    String appLanguage,
    bool canAsk,
  ) {
    final motion =
        !MediaQuery.disableAnimationsOf(context) &&
        !MediaQuery.accessibleNavigationOf(context);
    final entries = _entries(l10n, state, appLanguage, motion);
    if (entries.isEmpty) {
      // No suggested questions while one cannot be asked: under a limit
      // they would offer what the card under them says is not possible.
      return _EmptyChat(
        greeting: l10n.supportCodeGreeting,
        team: state.writesToTeam,
        suggestions: state.teamOnly || !canAsk
            ? const []
            : SupportScreen.suggestions(l10n),
        onAsk: canAsk ? (question) => _ask(state, question) : null,
      );
    }
    final index = <String, int>{
      for (var i = 0; i < entries.length; i++)
        entries[entries.length - 1 - i].key: i,
    };
    // Reversed, so the list starts at the newest line and stays there as
    // lines arrive, and as a reply grows while it is typed out.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: entries.length,
      findChildIndexCallback: (key) =>
          key is ValueKey<String> ? index[key.value] : null,
      itemBuilder: (context, i) {
        final at = entries.length - 1 - i;
        final entry = entries[at];
        final gap = at == 0
            ? 0.0
            : entries[at - 1].last == entry.first
            ? _sameAuthorGap
            : _newAuthorGap;
        return KeyedSubtree(
          key: ValueKey(entry.key),
          child: Padding(
            padding: EdgeInsets.only(top: gap),
            child: entry.child,
          ),
        );
      },
    );
  }

  static _Author _authorOf(String role) => switch (role) {
    'user' => _Author.user,
    'assistant' => _Author.assistant,
    'staff' => _Author.staff,
    SupportMessage.divider => _Author.divider,
    _ => _Author.system,
  };

  List<_Entry> _entries(
    S l10n,
    SupportState state,
    String appLanguage,
    bool motion,
  ) {
    final out = <_Entry>[];
    final used = <String>{};
    void add(
      String key,
      bool isNew,
      Widget child, {
      required _Author first,
      _Author? last,
    }) {
      var unique = key;
      for (var n = 2; !used.add(unique); n++) {
        unique = '$key#$n';
      }
      final enter = motion && isNew && !_entered.contains(unique);
      _entered.add(unique);
      out.add(
        _Entry(
          unique,
          _Entrance(animate: enter, child: child),
          first: first,
          last: last ?? first,
        ),
      );
    }

    final messages = state.messages;
    final told = _toldLater(messages);
    for (final m in messages) {
      final child = _message(
        l10n,
        state,
        m,
        told.contains(m),
        appLanguage,
        motion,
      );
      if (child == null) continue;
      final id = m.id;
      final key =
          m.clientId ??
          (id != null
              ? 'id:$id'
              : '${m.role}:${m.createdAt.toIso8601String()}');
      final author = _authorOf(m.role);
      // A reply that is typed out has that as its entrance. It takes the
      // place of the thinking bubble as it is, so the face beside it stays
      // put rather than fading in again.
      add(
        key,
        _isNew(m) && !_typed(m, motion),
        child,
        first: author,
        // A greeting ends with the app's own answer under it.
        last: author == _Author.user && m.code == 'greeting'
            ? _Author.assistant
            : author,
      );
    }
    for (final o in state.outbox) {
      add(
        o.clientId,
        _writtenSinceOpen(o.createdAt),
        _outgoing(l10n, state, o, appLanguage),
        first: _Author.user,
      );
    }
    final since = state.pendingSince;
    if (since != null && !state.teamOnly) {
      add(
        'thinking:${since.toIso8601String()}',
        true,
        _FromAssistant(
          child: ThinkingBubble(since: since, now: state.serverNow),
        ),
        first: _Author.assistant,
      );
    }
    return out;
  }

  /// The questions whose outcome a later line from us already states: a
  /// notice or an answer that carries the question's code. The line under
  /// such a question would say the same thing twice. Each such line is
  /// paired with the nearest question before it that has its code.
  static Set<SupportMessage> _toldLater(List<SupportMessage> messages) {
    final told = Set<SupportMessage>.identity();
    final open = <SupportMessage>[];
    for (final m in messages) {
      final code = m.code;
      if (code == null) continue;
      if (m.role == 'user') {
        open.add(m);
      } else if (m.role == 'system' || m.role == 'assistant') {
        final i = open.lastIndexWhere((q) => q.code == code);
        if (i >= 0) told.add(open.removeAt(i));
      }
    }
    return told;
  }

  Widget? _message(
    S l10n,
    SupportState state,
    SupportMessage m,
    bool told,
    String appLanguage,
    bool motion,
  ) {
    switch (m.role) {
      case SupportMessage.divider:
        return _Divider(label: l10n.supportNewConversation);
      case 'user':
        // A greeting gets the app's own friendly answer, in the app's
        // language, rather than a call to the assistant.
        final greeting = m.code == 'greeting';
        final line = greeting || told ? null : _userLine(l10n, m);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Mine(
              child: _Bubble(
                text: m.text,
                mine: true,
                appLanguage: appLanguage,
              ),
            ),
            if (line != null)
              _Line(line, alignment: AlignmentDirectional.centerEnd),
            if (greeting) ...[
              const SizedBox(height: _newAuthorGap),
              _FromAssistant(
                child: _Bubble(
                  text: l10n.supportCodeGreeting,
                  mine: false,
                  appLanguage: appLanguage,
                ),
              ),
            ],
          ],
        );
      case 'assistant':
        final id = m.id;
        final reveal = _typed(m, motion);
        return _FromAssistant(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Reply(
                announce: _announce(m),
                child: _Bubble(
                  text: m.text,
                  mine: false,
                  appLanguage: appLanguage,
                  onRevealed: reveal ? () => _markRevealed(id!) : null,
                ),
              ),
              // The thumbs come once the whole answer is there to judge.
              // Their room is kept while it is typed, so nothing moves
              // when they come.
              if (id != null)
                reveal
                    ? const SizedBox(height: _Rating.height)
                    : _Rating(
                        rating: m.rating,
                        upLabel: l10n.supportRateUp,
                        downLabel: l10n.supportRateDown,
                        onRate: (up) => _rate(state, m, up),
                      ),
            ],
          ),
        );
      case 'staff':
        final id = m.id;
        final reveal = _typed(m, motion);
        return _FromAssistant(
          avatar: const _TeamAvatar(size: _FromAssistant.avatarSize),
          child: _Reply(
            announce: _announce(m),
            child: _Bubble(
              text: m.text,
              mine: false,
              appLanguage: appLanguage,
              label: l10n.supportTeamLabel,
              onRevealed: reveal ? () => _markRevealed(id!) : null,
            ),
          ),
        );
      case 'system':
        final text = SupportScreen.codeText(l10n, m.code) ?? m.text.trim();
        if (text.isEmpty) return null;
        return _Pill(text);
    }
    return null;
  }

  /// What became of a question, under it, or null when nothing needs
  /// saying.
  String? _userLine(S l10n, SupportMessage m) {
    final code = m.code;
    if (code != null) {
      return SupportScreen.codeText(l10n, code) ?? l10n.supportGenericError;
    }
    if (m.redacted) return l10n.supportCodeRedacted;
    if (m.status == 'to_staff') return l10n.supportCodeToStaff;
    if (m.status == 'failed' || m.status == 'refused') {
      return l10n.supportGenericError;
    }
    return null;
  }

  Widget _outgoing(
    S l10n,
    SupportState state,
    SupportOutgoing o,
    String appLanguage,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // At full strength: what the user wrote is not in doubt, only
        // whether it has arrived, and the line under it says that.
        _Mine(
          child: _Bubble(text: o.text, mine: true, appLanguage: appLanguage),
        ),
        if (o.failed && !o.sending)
          Tappable(
            onTap: () => unawaited(state.flushOutbox()),
            behavior: HitTestBehavior.opaque,
            // A small line, in a tap area a finger can hit. In the error
            // color: the message did not leave the phone, and the user has
            // to act on it.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _tapHeight),
              child: _Line(
                l10n.supportNotSent,
                alignment: AlignmentDirectional.centerEnd,
                color: AppDesign.error,
                icon: Icons.error_outline_rounded,
              ),
            ),
          )
        else
          _Line(
            l10n.supportSending,
            alignment: AlignmentDirectional.centerEnd,
            icon: Icons.schedule_rounded,
          ),
      ],
    );
  }

  Widget _composer(
    S l10n,
    SupportState state,
    String appLanguage, {
    required SupportLimit? block,
    required DateTime now,
  }) {
    final text = _input.text;
    final count = RuneLimitFormatter.count(text);
    final team = state.writesToTeam;
    final held = block != null || (!team && state.pending);
    final canSend =
        text.trim().isNotEmpty && count <= SupportState.maxRunes && !held;
    final language = SupportScreen.layoutLanguage(text, appLanguage);
    final locale = Locale(language);
    final hint = block != null
        ? NumberLocalizer.localize(
            SupportScreen.limitHint(l10n, block, now),
            context,
          )
        : team
        ? l10n.supportInputHintTeam
        : l10n.supportInputHint;
    final type = Theme.of(context).textTheme;
    // The line height follows the app language, whatever script is typed,
    // so the box keeps its height when the first letter is in another
    // script. No letter spacing, so Persian typed into an English app
    // keeps its joins.
    final fieldStyle = type.bodyLarge?.copyWith(
      color: AppDesign.textPrimary,
      letterSpacing: AppDesign.ls(0),
      fontFamily: AppDesign.fontFamilyForLocale(locale),
      fontFamilyFallback: AppDesign.fontFallbackForLocale(locale),
    );
    // The hint at the size of the text, so the box keeps its height when
    // the user starts typing.
    final hintStyle = type.bodyLarge?.copyWith(
      color: AppDesign.textTertiary,
      letterSpacing: AppDesign.ls(0),
    );
    // A one-line box as tall as the send button in every script: Persian
    // lines are taller than English ones, so a fixed padding made the box
    // 52 high in Persian, no longer a true pill, with the disc off its
    // middle. Larger text still makes it taller, never tighter than 8.
    final line =
        MediaQuery.textScalerOf(context).scale(fieldStyle?.fontSize ?? 16) *
        (hintStyle?.height ?? 1.5);
    final fieldPadding = math.max(
      AppDesign.space8,
      (_SendButton.size - line) / 2,
    );
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
          borderSide: BorderSide(color: color, width: width),
        );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppDesign.canvas,
        border: Border(top: BorderSide(color: AppDesign.hairline)),
      ),
      child: Padding(
        // The end inset puts the send disc's edge as far from the screen's
        // edge as the box's start, inside the button's larger tap area.
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (count >= SupportState.counterFrom)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  // Over the end of the text in the box.
                  padding: const EdgeInsetsDirectional.only(
                    end: _SendButton.size + _sendGap + AppDesign.space16,
                    bottom: AppDesign.space4,
                  ),
                  child: Text(
                    NumberLocalizer.localize(
                      '$count/${SupportState.maxRunes}',
                      context,
                    ),
                    key: const ValueKey('support-counter'),
                    textDirection: TextDirection.ltr,
                    style: type.labelSmall?.copyWith(
                      fontFeatures: AppDesign.numberFeatures,
                      color: count > SupportState.maxRunes
                          ? AppDesign.error
                          : count == SupportState.maxRunes
                          ? AppDesign.warning
                          : AppDesign.textTertiary,
                    ),
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    focusNode: _focus,
                    enabled: block == null,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: const [
                      RuneLimitFormatter(SupportState.maxRunes),
                    ],
                    textDirection: MessageText.isRtl(language)
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    style: fieldStyle,
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: hintStyle,
                      hintMaxLines: 2,
                      isDense: true,
                      filled: true,
                      // Off under a limit: the page's own color, so the box
                      // reads as closed rather than as empty.
                      fillColor: block == null
                          ? AppDesign.surfaceLow
                          : AppDesign.canvas,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppDesign.space16,
                        vertical: fieldPadding,
                      ),
                      border: border(AppDesign.outlineVariant),
                      enabledBorder: border(AppDesign.outlineVariant),
                      disabledBorder: border(AppDesign.hairline),
                      focusedBorder: border(AppDesign.steelLight, 1.5),
                    ),
                  ),
                ),
                const SizedBox(width: _sendGap),
                _SendButton(
                  focusNode: _sendFocus,
                  active: canSend,
                  // Off with nothing to send. Not while a TV remote has
                  // it focused, as it has right after a send: a control
                  // that turns off loses the focus. Then it stays on, looks
                  // off, and a press does nothing.
                  onPressed: canSend
                      ? () => _send(state)
                      : _sendFocus.hasFocus
                      ? () {}
                      : null,
                  tooltip: l10n.supportSend,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Half the height of a one-line box, so it is a pill.
  static const double _fieldRadius = 24;

  /// Between the box and the send button's tap area. The tap area adds 2
  /// on each side of the disc, so the box and the disc are 8 apart.
  static const double _sendGap = 6;
}

/// The send button: a brand disc while there is something to send, a flat
/// grey one while there is not. The color eases between the two, so the
/// change is seen rather than missed. The disc is 44 across inside a 48
/// tap area.
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.active,
    required this.onPressed,
    required this.tooltip,
    this.focusNode,
  });

  /// The tap area.
  static const double size = 48;
  static const double _discSize = 44;
  static const double _iconSize = 20;

  /// Whether there is something to send, which is what the button shows.
  final bool active;
  final VoidCallback? onPressed;
  final String tooltip;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: active ? 1 : 0),
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      // A round button gets a round focus ring on a TV, as the chatbot
      // button does.
      builder: (context, t, _) => FocusRingCircle(
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: _discSize,
                height: _discSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(AppDesign.surfaceHigh, AppDesign.brand, t),
                ),
              ),
              // On top of the disc, with no fill of its own, so its ripple
              // shows over the disc.
              IconButton(
                onPressed: onPressed,
                focusNode: focusNode,
                tooltip: tooltip,
                icon: Icon(
                  Icons.send_rounded,
                  size: _iconSize,
                  color: Color.lerp(
                    AppDesign.textDisabled,
                    AppDesign.onBrand,
                    t,
                  ),
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  foregroundColor: AppDesign.onBrand,
                  disabledForegroundColor: AppDesign.textDisabled,
                  // The theme's 48 would win over a fixed size alone.
                  minimumSize: const Size.square(_discSize),
                  fixedSize: const Size.square(_discSize),
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The title of the chat: the face of who answers there, the name of the
/// chat, and who that is.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.team,
  });

  final String title;
  final String subtitle;

  /// Our team has the conversation, so their face is shown, not the
  /// assistant's.
  final bool team;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Two lines in a bar of fixed height. Past this size they would not
    // fit in it.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          team ? const _TeamAvatar(size: 36) : const ChatbotAvatar(size: 36),
          const SizedBox(width: AppDesign.space12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(
                    color: AppDesign.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: AppDesign.space2),
                Text(
                  subtitle,
                  key: const ValueKey('support-subtitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(
                    color: AppDesign.textTertiary,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A line from the assistant or our team: a face at the start, the line
/// beside it, so every reply starts at the same place.
class _FromAssistant extends StatelessWidget {
  const _FromAssistant({
    required this.child,
    this.avatar = const ChatbotAvatar(size: avatarSize),
  });

  static const double avatarSize = 28;
  static const double gap = 8;

  final Widget child;

  /// The assistant's face unless given. [avatarSize] across.
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: avatar),
        const SizedBox(width: gap),
        Flexible(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: child,
          ),
        ),
      ],
    );
  }
}

/// A line of the user's, at the end of the row.
class _Mine extends StatelessWidget {
  const _Mine({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Align(alignment: AlignmentDirectional.centerEnd, child: child);
}

/// The face of our team: a person with a headset on the same steel disc
/// as the assistant's face.
class _TeamAvatar extends StatelessWidget {
  const _TeamAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: ChatbotAvatar.steelDisc,
      child: Icon(
        Icons.support_agent_rounded,
        size: size * 0.58,
        color: AppDesign.steelLight,
      ),
    );
  }
}

/// A reply as one node for a screen reader, read out as it arrives when
/// [announce] is set. The node is there either way, so the reply keeps
/// its state, and its typing, when [announce] turns off.
class _Reply extends StatelessWidget {
  const _Reply({required this.announce, required this.child});

  final bool announce;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Semantics(container: true, liveRegion: announce, child: child);
}

/// Slides a new line up into place and fades it in, once.
class _Entrance extends StatefulWidget {
  const _Entrance({required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: AppMotion.quick,
    value: widget.animate ? 0 : 1,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _in,
    curve: AppMotion.emphasizedDecelerate,
  );

  /// How far below its place a line starts.
  static const double _riseOffset = 12;

  @override
  void initState() {
    super.initState();
    if (widget.animate) unawaited(_in.forward());
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _riseOffset * (1 - _curve.value)),
          child: child,
        ),
      ),
    );
  }
}

/// One message. The text is laid out in its own script's direction
/// whatever the app's language.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.mine,
    required this.appLanguage,
    this.label,
    this.onRevealed,
  });

  final String text;
  final bool mine;
  final String appLanguage;

  /// Above a reply from a person on our team.
  final String? label;

  /// Set while the reply is being typed out. Called when the last word is
  /// on screen, or when the user taps the bubble to see it all at once.
  final VoidCallback? onRevealed;

  @override
  Widget build(BuildContext context) {
    const corner = Radius.circular(14);
    const tail = Radius.circular(4);
    final staff = label != null;
    final width = MediaQuery.sizeOf(context).width;
    final language = SupportScreen.layoutLanguage(text, appLanguage);
    // The reading size, with the line height of the text's own script:
    // Persian needs taller lines than English, whatever the app's
    // language. The letter spacing is set here rather than taken from the
    // theme. The reply is first typed out as one Text.rich of three spans
    // and then drawn as the final text, and with the theme's fractional
    // spacing the two measured a tenth of a pixel apart, enough to move a
    // word to the next line as the typing ends.
    final style = AppDesign.textThemeForLocale(Locale(language)).bodyLarge
        ?.copyWith(
          color: AppDesign.textPrimary,
          letterSpacing: AppDesign.ls(0),
        );
    final revealed = onRevealed;
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: mine
            ? width * 0.8
            : width * 0.84 - _FromAssistant.avatarSize - _FromAssistant.gap,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        // Told apart by tone, not by outline: the user's a step lighter,
        // the assistant's close to the page. A reply from a person on our
        // team gets a fine steel edge as well as its label.
        decoration: BoxDecoration(
          color: mine ? AppDesign.surfaceHighest : AppDesign.surfaceLow,
          // The small corner points at who is speaking: up at the face of
          // the assistant or our team, and on the user's side for theirs.
          borderRadius: BorderRadiusDirectional.only(
            topStart: mine ? corner : tail,
            topEnd: mine ? tail : corner,
            bottomStart: corner,
            bottomEnd: corner,
          ),
          border: staff
              ? Border.all(color: AppDesign.steelLight.withValues(alpha: 0.3))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (staff) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.support_agent_rounded,
                    size: 14,
                    color: AppDesign.steelLight,
                  ),
                  const SizedBox(width: AppDesign.space6),
                  Flexible(
                    child: Text(
                      label!,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppDesign.steelLight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDesign.space4),
            ],
            if (revealed == null)
              MessageText(text, language: language, style: style)
            else
              TypedText(
                text,
                language: language,
                style: style,
                onDone: revealed,
              ),
          ],
        ),
      ),
    );
    if (revealed == null) return bubble;
    return Tappable(
      key: const ValueKey('support-typing'),
      onTap: revealed,
      behavior: HitTestBehavior.opaque,
      child: bubble,
    );
  }
}

/// Thumbs up and down under an answer.
class _Rating extends StatelessWidget {
  const _Rating({
    required this.rating,
    required this.upLabel,
    required this.downLabel,
    required this.onRate,
  });

  /// The height of the row, and of each tap target in it.
  static const double height = 48;
  static const double _iconSize = 18;

  final String? rating;
  final String upLabel;
  final String downLabel;
  final void Function(bool up) onRate;

  @override
  Widget build(BuildContext context) {
    Widget thumb(bool up) {
      final chosen = rating == (up ? 'up' : 'down');
      return IconButton(
        onPressed: () => onRate(up),
        tooltip: up ? upLabel : downLabel,
        constraints: const BoxConstraints(minWidth: height, minHeight: height),
        iconSize: _iconSize,
        icon: Icon(
          up
              ? (chosen ? Icons.thumb_up_rounded : Icons.thumb_up_outlined)
              : (chosen ? Icons.thumb_down_rounded : Icons.thumb_down_outlined),
          // The filled glyph already says which one was chosen. Mint and
          // rose mean protected and failed everywhere else in the app, so
          // the chosen thumb is only brighter, not colored.
          color: chosen ? AppDesign.textPrimary : AppDesign.textTertiary,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [thumb(true), thumb(false)],
    );
  }
}

/// The chat before its first message: the assistant's face and a hello in
/// the middle, and a few questions to start with just above the box,
/// where the thumb already is.
class _EmptyChat extends StatelessWidget {
  const _EmptyChat({
    required this.greeting,
    required this.team,
    required this.suggestions,
    required this.onAsk,
  });

  final String greeting;

  /// Our team answers here, so their face is shown, not the assistant's.
  final bool team;
  final List<String> suggestions;

  /// Null while a question cannot be asked.
  final void Function(String question)? onAsk;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ask = onAsk;
    const padding = EdgeInsets.fromLTRB(16, 24, 16, 16);
    final hello = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Halo(
          child: team
              ? const _TeamAvatar(size: _avatarSize)
              : const ChatbotAvatar(size: _avatarSize),
        ),
        const SizedBox(height: AppDesign.space20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDesign.space8),
          child: _BalancedText(
            greeting,
            style: text.headlineSmall?.copyWith(color: AppDesign.textPrimary),
          ),
        ),
      ],
    );
    return LayoutBuilder(
      // Reversed, so with the keyboard up on a small phone the questions
      // stay in view above the box and the hello is what scrolls away.
      builder: (context, constraints) => SingleChildScrollView(
        reverse: true,
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - padding.vertical),
          ),
          // The empty first child puts the free room evenly above and
          // below the hello, so it sits in the middle of what the
          // questions leave.
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox.shrink(),
              hello,
              if (suggestions.isNotEmpty && ask != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppDesign.space24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < suggestions.length; i++) ...[
                        if (i > 0) const SizedBox(height: AppDesign.space8),
                        _Suggestion(
                          key: ValueKey('support-suggestion-$i'),
                          text: suggestions[i],
                          onTap: () => ask(suggestions[i]),
                        ),
                      ],
                    ],
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  static const double _avatarSize = 72;
}

/// A short heading, centered, with its lines about the same length, so
/// it never ends on one word alone. It is one Text, drawn in the narrowest
/// width that still takes no more lines than the whole width does.
class _BalancedText extends StatelessWidget {
  const _BalancedText(this.text, {required this.style});

  final String text;
  final TextStyle? style;

  /// The search for the width stops once it is known to within this.
  static const double _widthStep = 4;

  @override
  Widget build(BuildContext context) {
    final label = Text(text, textAlign: TextAlign.center, style: style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final full = constraints.maxWidth;
        if (!full.isFinite || text.isEmpty) return label;
        // Measured as the Text draws it: the same style, direction, text
        // size and language.
        var drawn = DefaultTextStyle.of(context).style.merge(style);
        if (MediaQuery.boldTextOf(context)) {
          drawn = drawn.merge(const TextStyle(fontWeight: FontWeight.bold));
        }
        final painter = TextPainter(
          text: TextSpan(text: text, style: drawn),
          textAlign: TextAlign.center,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
        );
        int lines(double width) {
          painter.layout(maxWidth: width);
          return painter.computeLineMetrics().length;
        }

        try {
          final count = lines(full);
          if (count < 2) return label;
          // The answer lies between an even share of the full width per
          // line and the full width. Only a width that keeps the line
          // count is ever kept, so the result never takes another line.
          var lo = full / count;
          var hi = full;
          while (hi - lo > _widthStep) {
            final mid = (lo + hi) / 2;
            if (lines(mid) > count) {
              lo = mid;
            } else {
              hi = mid;
            }
          }
          return Center(
            child: SizedBox(width: hi, child: label),
          );
        } finally {
          painter.dispose();
        }
      },
    );
  }
}

/// A soft light around the face on the empty chat. Static, painted
/// outside the face's own box, so it takes no room and runs nothing.
class _Halo extends StatelessWidget {
  const _Halo({required this.child});

  final Widget child;

  /// How far the light reaches past the face.
  static const double _spreadInset = 28;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          left: -_spreadInset,
          top: -_spreadInset,
          right: -_spreadInset,
          bottom: -_spreadInset,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppDesign.steelLight.withValues(alpha: 0.08),
                  AppDesign.steelLight.withValues(alpha: 0),
                ],
                stops: const [0.55, 1],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// A question to start with: a full-width row, with room for a finger.
class _Suggestion extends StatelessWidget {
  const _Suggestion({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    final type = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      button: true,
      enabled: on,
      child: Pressable(
        onTap: onTap,
        border: const BorderSide(color: AppDesign.hairline),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
        // At least 48 high with the padding, the least a finger can hit
        // reliably.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppDesign.space24),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 18,
                color: on ? AppDesign.textTertiary : AppDesign.textDisabled,
              ),
              const SizedBox(width: AppDesign.space12),
              Expanded(
                child: Text(
                  text,
                  style: type.bodyLarge?.copyWith(
                    fontSize: 15,
                    color: on ? AppDesign.textPrimary : AppDesign.textDisabled,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A short line in the app's language: why a message was refused, what
/// became of it, how many questions are left.
class _Line extends StatelessWidget {
  const _Line(
    this.text, {
    this.alignment = AlignmentDirectional.center,
    this.color = AppDesign.textTertiary,
    this.announce = false,
    this.icon,
  });

  final String text;
  final AlignmentDirectional alignment;
  final Color color;

  /// Read out by a screen reader as it appears.
  final bool announce;

  /// A small sign before the words, in their color.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    Widget line = Text(
      NumberLocalizer.localize(text, context),
      textAlign: alignment == AlignmentDirectional.center
          ? TextAlign.center
          : alignment == AlignmentDirectional.centerEnd
          ? TextAlign.end
          : TextAlign.start,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
    );
    final icon = this.icon;
    if (icon != null) {
      line = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppDesign.space4),
          Flexible(child: line),
        ],
      );
    }
    return Align(
      alignment: alignment,
      child: Semantics(
        container: announce,
        liveRegion: announce,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: line,
        ),
      ),
    );
  }
}

/// A line from the app about the conversation itself, such as our team
/// taking it over: a quiet pill in the middle, set apart from what anyone
/// said.
class _Pill extends StatelessWidget {
  const _Pill(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesign.space16,
          vertical: AppDesign.space4,
        ),
        child: DecoratedBox(
          decoration: const ShapeDecoration(
            color: AppDesign.surfaceHigh,
            shape: StadiumBorder(),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDesign.space16,
              vertical: AppDesign.space8,
            ),
            child: Text(
              NumberLocalizer.localize(text, context),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppDesign.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

/// The line under the header that says who writes the answers. Always on
/// screen, as a quiet line rather than a band, with the header's hairline
/// under it.
class _TopLine extends StatelessWidget {
  const _TopLine({required this.text});

  final String text;

  static const double _iconSize = 14;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppDesign.textTertiary);
    // The sign beside the middle of the first line, also when the line
    // wraps.
    final line =
        MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 12) *
        (style?.height ?? 1.4);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesign.space16,
        vertical: AppDesign.space8,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppDesign.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: math.max(0, (line - _iconSize) / 2)),
            child: const Icon(
              Icons.info_outline_rounded,
              size: _iconSize,
              color: AppDesign.textTertiary,
            ),
          ),
          const SizedBox(width: AppDesign.space8),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

/// Where a new conversation starts.
class _Divider extends StatelessWidget {
  const _Divider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: AppDesign.outlineVariant, height: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDesign.space12),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppDesign.textTertiary),
          ),
        ),
        const Expanded(
          child: Divider(color: AppDesign.outlineVariant, height: 1),
        ),
      ],
    );
  }
}

/// Why the assistant cannot be asked now, and until when. Only that: a
/// limit is not something to get around, so the card offers nothing to
/// tap. A busy assistant says to try again in a few minutes.
class _LimitCard extends StatelessWidget {
  const _LimitCard({
    required this.limit,
    required this.now,
    required this.announce,
  });

  final SupportLimit limit;
  final DateTime now;

  /// Read out by a screen reader, because the box under it has just
  /// turned off and this is why.
  final bool announce;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final text = Theme.of(context).textTheme;
    final title =
        SupportScreen.codeText(l10n, limit.code) ?? l10n.supportGenericError;
    final wait = limit.code == 'busy'
        ? null
        : SupportScreen.waitText(l10n, limit.until, now);
    return Semantics(
      container: true,
      liveRegion: announce,
      child: Container(
        key: const ValueKey('support-limit'),
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.all(AppDesign.space16),
        decoration: BoxDecoration(
          color: AppDesign.warningContainer,
          borderRadius: AppDesign.borderRadiusLarge,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.hourglass_empty_rounded,
              color: AppDesign.warning,
              size: 20,
            ),
            const SizedBox(width: AppDesign.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quieter than the wait under it, in weight and color,
                  // because the wait is what the user looks for.
                  Text(
                    title,
                    style: text.bodyMedium?.copyWith(
                      color: AppDesign.textSecondary,
                    ),
                  ),
                  if (wait != null) ...[
                    const SizedBox(height: AppDesign.space4),
                    Text(
                      NumberLocalizer.localize(wait, context),
                      style: text.titleSmall?.copyWith(
                        color: AppDesign.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontFeatures: AppDesign.numberFeatures,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the chat is off. The Telegram channel is still a way to
/// reach us. [centered] fills the page with the assistant's face over it,
/// for a chat with nothing in it; otherwise it takes the input box's place
/// under what was said before.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onTelegram, this.centered = false});

  final VoidCallback onTelegram;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final text = Theme.of(context).textTheme;
    final message = Text(
      l10n.supportUnavailable,
      textAlign: TextAlign.center,
      style: text.bodyLarge?.copyWith(color: AppDesign.textSecondary),
    );
    final telegram = TextButton(
      onPressed: onTelegram,
      child: Text(l10n.supportOpenTelegram),
    );
    if (!centered) {
      return Padding(
        padding: const EdgeInsets.all(AppDesign.space20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [message, const SizedBox(height: 8), telegram],
        ),
      );
    }
    const padding = EdgeInsets.all(AppDesign.space24);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - padding.vertical),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ChatbotAvatar(size: _EmptyChat._avatarSize),
                const SizedBox(height: AppDesign.space20),
                message,
                const SizedBox(height: AppDesign.space12),
                telegram,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
