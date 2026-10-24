import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/design_system.dart';
import 'message_dialog.dart';

/// A reply shown word by word, the way [MessageText] would show it whole.
///
/// The reply is already whole on the phone. The backend sends it only after
/// its checks, so nothing here streams from anywhere: this is how an answer
/// that arrived while the chat was open appears.
///
/// The whole text is laid out from the first frame, with the words not yet
/// shown drawn in a clear colour. So the bubble around it has its final
/// size at once, and no line breaks or moves while the words come. The
/// first word is there from the start and each next one fades in.
///
/// The text is cut only between words, so a Persian or Arabic word is never
/// shown with half its letters, and a zero width non-joiner inside a word
/// stays in it. The direction comes from the whole reply, not from the part
/// on screen, so a reply that starts with a Latin word does not flip sides
/// as it grows. A screen reader gets the whole text once, from the start.
class TypedText extends StatefulWidget {
  const TypedText(
    this.text, {
    super.key,
    required this.language,
    this.style,
    this.onDone,
  });

  final String text;

  /// The language the text is laid out in. See [MessageText].
  final String language;
  final TextStyle? style;

  /// Called once, when the last word is on screen.
  final VoidCallback? onDone;

  /// How long each word takes, and the shortest and the longest a reply
  /// takes in all.
  static const perWord = Duration(milliseconds: 45);
  static const shortest = Duration(milliseconds: 600);
  static const longest = Duration(milliseconds: 2500);

  /// How long [words] words take to appear.
  static Duration durationFor(int words) {
    final ms = (perWord.inMilliseconds * words).clamp(
      shortest.inMilliseconds,
      longest.inMilliseconds,
    );
    return Duration(milliseconds: ms);
  }

  static final _word = RegExp(r'^\s*\S+\s*|\S+\s*');

  /// [text] cut into words, each with the spaces and line breaks after it,
  /// the first with any before it too. Joined, they are [text] again. A
  /// zero width non-joiner is not a space, so it never cuts a word.
  static List<String> words(String text) => [
    for (final m in _word.allMatches(text)) m.group(0)!,
  ];

  @override
  State<TypedText> createState() => _TypedTextState();
}

class _TypedTextState extends State<TypedText>
    with SingleTickerProviderStateMixin {
  late final List<String> _words = TypedText.words(widget.text);
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: TypedText.durationFor(_words.length),
  );
  bool _done = false;

  /// How many words are on screen, and the text before the newest of them,
  /// the newest, and the rest. Cut again only when the count changes, so
  /// the text is laid out again only then. In between, only the newest
  /// word's colour changes, which repaints it and nothing else.
  int _shown = 0;
  String _before = '';
  String _newest = '';
  String _rest = '';

  @override
  void initState() {
    super.initState();
    _reveal.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
    if (_words.length <= 1) {
      _reveal.value = 1;
    } else {
      unawaited(_reveal.forward());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Asked for less motion: the whole reply at once.
    if (MediaQuery.disableAnimationsOf(context) && !_reveal.isCompleted) {
      _reveal.value = 1;
    }
  }

  void _finish() {
    if (_done) return;
    _done = true;
    // After this frame, so the owner can rebuild with the reply whole.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDone?.call();
    });
  }

  void _cut(int shown) {
    if (shown == _shown) return;
    _shown = shown;
    _before = _words.take(shown - 1).join();
    _newest = _words[shown - 1];
    _rest = _words.skip(shown).join();
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Locale(widget.language);
    final style = (widget.style ?? const TextStyle()).copyWith(
      fontFamily: AppDesign.fontFamilyForLocale(locale),
      fontFamilyFallback: AppDesign.fontFallbackForLocale(locale),
    );
    final color =
        style.color ??
        DefaultTextStyle.of(context).style.color ??
        AppDesign.textPrimary;
    final count = _words.length;
    return Semantics(
      label: widget.text,
      excludeSemantics: true,
      child: Directionality(
        textDirection: MessageText.isRtl(widget.language)
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: count == 0
            ? Text(widget.text, style: style)
            : AnimatedBuilder(
                animation: _reveal,
                builder: (context, _) {
                  // In words: 1 with the first word on screen, [count] with
                  // all of them.
                  final at = 1 + _reveal.value * (count - 1);
                  final shown = math.min(count, math.max(1, at.ceil()));
                  _cut(shown);
                  final fade = shown == 1
                      ? 1.0
                      : (at - (shown - 1)).clamp(0.0, 1.0);
                  return Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: _before),
                        TextSpan(
                          text: _newest,
                          style: TextStyle(
                            color: color.withValues(alpha: color.a * fade),
                          ),
                        ),
                        TextSpan(
                          text: _rest,
                          style: TextStyle(color: color.withValues(alpha: 0)),
                        ),
                      ],
                    ),
                    style: style,
                  );
                },
              ),
      ),
    );
  }
}
