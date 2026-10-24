import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/billing_service.dart';
import '../core/design_system.dart';
import '../core/state/billing_state.dart';
import '../data/models/billing.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/invite_code.dart';
import '../utils/number_localizer.dart';
import 'quota_card.dart';

/// Ask for a code and redeem it: a Premium key (K7QD-3MWX-9TZB-H2CF) or a
/// promo code.
///
/// Separate from the invite dialog on purpose. Invite codes are short and
/// go to /referral/claim, which answers any success with the invite text;
/// these go to /billing/redeem, which tries the code as a key and then as
/// a promo code, and says which it was.
///
/// The field takes 4 to 32 characters of letters, digits, dashes and
/// spaces, so a key can be typed in groups or pasted as shown. Digits
/// typed on a Persian or Arabic keyboard become Latin ones. The backend
/// normalises the rest.
///
/// On success BillingState hands the new allowance to DedicatedState and
/// refreshes it, so the quota card shows Unlimited at once. The dialog
/// closes and says what the code did. Returns the result, or null when the
/// user closed the dialog.
Future<RedeemResult?> showRedeemCodeDialog(BuildContext context) =>
    showDialog<RedeemResult>(
      context: context,
      builder: (_) => const _RedeemCodeDialog(),
    );

/// The fewest letters and digits worth sending.
const _shortestCode = 4;

/// What to tell the user when a code was refused, for every reason the
/// backend sends and for the failures that are not about the code.
String redeemFailureText(S l10n, BillingException e) {
  if (e.statusCode == 429) return l10n.redeemRateLimited;
  return switch (e.reason) {
    'invalid_code' => l10n.redeemInvalid,
    'unknown_code' => l10n.redeemUnknown,
    'expired' => l10n.redeemExpired,
    'revoked' => l10n.redeemRevoked,
    'moved_too_often' => l10n.redeemMovedTooOften,
    'exhausted' => l10n.redeemExhausted,
    'already_redeemed' => l10n.redeemAlreadyUsed,
    'unmetered' => l10n.redeemUnmetered,
    BillingException.notAvailable => l10n.premiumNotAvailable,
    BillingException.rateLimited => l10n.redeemRateLimited,
    BillingException.unavailable => l10n.redeemUnavailable,
    BillingException.server => l10n.redeemUnavailable,
    BillingException.network => l10n.redeemNetwork,
    _ => l10n.redeemFailed,
  };
}

/// What to tell the user once a code worked.
String redeemSuccessText(BuildContext context, RedeemResult result) {
  final l10n = S.of(context)!;
  if (result.isPremium) {
    return result.moved ? l10n.redeemMoved : l10n.premiumNowOn;
  }
  final bytes = result.bonusBytes;
  if (bytes == null) return l10n.redeemPromoNoAmount;
  // The amount's decimal sign as the quota card writes it ("۱٫۵ GB").
  return NumberLocalizer.localizeAmount(
    l10n.redeemPromo(QuotaCard.formatAllowance(bytes)),
    context,
  );
}

/// The most characters the field takes.
const _longestCode = 32;

/// Persian and Arabic-Indic digits to Latin ones.
String _latinDigits(String text) => String.fromCharCodes([
  for (final c in text.runes)
    if (c >= 0x06F0 && c <= 0x06F9)
      c - 0x06F0 + 0x30
    else if (c >= 0x0660 && c <= 0x0669)
      c - 0x0660 + 0x30
    else
      c,
]);

/// Persian and Arabic-Indic digits to Latin ones, then upper case.
String _folded(String text) => _latinDigits(text).toUpperCase();

final _codeFormatter = TextInputFormatter.withFunction(
  (_, next) => next.copyWith(text: _folded(next.text)),
);

/// Groups of letters and digits joined by dashes, as a key is written.
final _codeRun = RegExp(r'[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*');

/// The code in [text], such as a message a key was pasted from, with
/// digits folded to Latin and letters in capitals, or null when no run of
/// letters and digits is long enough to send. Used by the Paste button,
/// which fills the field and sends nothing.
///
/// A run with a digit or a dash looks most like a code, then a run written
/// all in capitals, then any other; the longest wins within the first kind
/// found. So "your code is WELCOME" gives WELCOME, not the longest word.
String? redeemCodeIn(String text) {
  int kind(String run) {
    if (run.contains(RegExp(r'[0-9-]'))) return 0;
    if (run == run.toUpperCase()) return 1;
    return 2;
  }

  String? best;
  var bestKind = 3;
  for (final match in _codeRun.allMatches(_latinDigits(text))) {
    final run = match.group(0)!;
    if (run.replaceAll('-', '').length < _shortestCode) continue;
    final k = kind(run);
    if (k < bestKind || (k == bestKind && run.length > best!.length)) {
      best = run;
      bestKind = k;
    }
  }
  if (best == null) return null;
  final code = best.toUpperCase();
  return code.length <= _longestCode ? code : code.substring(0, _longestCode);
}

class _RedeemCodeDialog extends StatefulWidget {
  const _RedeemCodeDialog();

  @override
  State<_RedeemCodeDialog> createState() => _RedeemCodeDialogState();
}

class _RedeemCodeDialogState extends State<_RedeemCodeDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Letters and digits typed so far, without the dashes and spaces.
  int get _length =>
      _controller.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length;

  /// Read the clipboard, only on this tap, and put the code found in it
  /// in the field. Nothing is sent until Apply.
  Future<void> _paste() async {
    if (_busy) return;
    final l10n = S.of(context)!;
    String? text;
    try {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (e) {
      debugPrint('RedeemCodeDialog: clipboard unreadable ($e)');
    }
    if (!mounted) return;
    final code = text == null ? null : redeemCodeIn(text);
    if (code == null) {
      setState(() => _error = l10n.redeemInvalid);
      return;
    }
    _controller.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    setState(() => _error = null);
  }

  Future<void> _submit() async {
    if (_busy || _length < _shortestCode) return;
    final l10n = S.of(context)!;
    final billing = context.read<BillingState>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await billing.redeem(_controller.text.trim());
      if (!mounted) return;
      final text = redeemSuccessText(context, result);
      navigator.pop(result);
      // The theme's snackbar colors: light text on the bar.
      messenger.showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } on BillingException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = redeemFailureText(l10n, e);
      });
    } catch (e) {
      debugPrint('RedeemCodeDialog: redeem failed ($e)');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.redeemFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    // Apply waits for a code long enough to send. It is not disabled while
    // the code is sent, nor are the other buttons, because a disabled
    // button loses a TV remote's focus: a tap then is ignored.
    final ready = _length >= _shortestCode;
    return AlertDialog(
      title: Text(l10n.redeemTitle),
      // The lines and the field under the title scroll, and the buttons
      // stay below them, so a small phone with large text or with the
      // keyboard up keeps Apply in view instead of overflowing. Not
      // AlertDialog.scrollable: that asks the content for its height, which
      // the field's LayoutBuilder cannot give.
      content: SingleChildScrollView(
        // As wide as the dialog may be, in every language, so this dialog
        // and the invite code dialog come up the same width. Shrink wrapped,
        // each took the width of its own longest line.
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.redeemSubtitle,
                style: AppDesign.textTheme.bodyMedium?.copyWith(
                  color: AppDesign.textSecondary,
                ),
              ),
              const SizedBox(height: AppDesign.space16),
              LayoutBuilder(
                builder: (context, constraints) => TextField(
                  controller: _controller,
                  autofocus: true,
                  // Read only while the code is sent, not disabled, so the
                  // field keeps focus.
                  readOnly: _busy,
                  autocorrect: false,
                  enableSuggestions: false,
                  // A code is Latin letters and digits, so it is typed left to
                  // right in every language, in the middle of the field. The
                  // label and the error follow the app's language.
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  inputFormatters: [
                    _codeFormatter,
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9\- ]')),
                    LengthLimitingTextInputFormatter(_longestCode),
                  ],
                  style: codeFieldStyle,
                  decoration: codeFieldDecoration(
                    context,
                    width: constraints.maxWidth,
                    label: l10n.redeemHint,
                    error: _error,
                    pasteKey: const Key('redeem-paste'),
                    onPaste: _paste,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (!_busy) Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(foregroundColor: AppDesign.textSecondary),
          child: Text(l10n.redeemCancel),
        ),
        FilledButton(
          onPressed: ready ? _submit : null,
          style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
          child: _busy ? const CodeSendingSpinner() : Text(l10n.redeemApply),
        ),
      ],
      actionsPadding: codeDialogActionsPadding,
    );
  }
}

/// Around the action row of the two code dialogs: the same 24 as the
/// content, so the buttons end on the code field's edges. The theme's 20
/// is for the message dialog, whose long button labels need the width.
/// With it, the row here stuck out 4 past the field on each side.
const EdgeInsets codeDialogActionsPadding = EdgeInsets.fromLTRB(24, 0, 24, 24);

/// The space between the letters of a code typed into a code field.
///
/// A code is Latin letters and digits in every language, so it keeps this
/// spacing in Persian, Arabic and Urdu too: AppDesign.ls is for text that
/// may be in a joined script, and a code never is.
const double _codeFieldLetterSpacing = 2;

/// What a code looks like as it is typed into a code field: monospace, so
/// like characters line up, with a little space between them. The same in
/// every language, so the locale and the fonts to fall back on are fixed
/// to Latin ones. Shared by the invite code dialog.
TextStyle get codeFieldStyle => const TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: <String>[],
  locale: Locale('en'),
  fontSize: 18,
  fontWeight: FontWeight.w600,
  letterSpacing: _codeFieldLetterSpacing,
  color: AppDesign.textPrimary,
);

/// The share of its size the field draws a floating label at. Material
/// scales the label to three quarters when it moves to the field's edge.
const double _floatingLabelScale = 0.75;

/// A code field's label, in the app's own font and language with no extra
/// spacing. It is drawn at three quarters of this size, so it shows at
/// 13sp, which keeps Persian above its 12.5sp floor.
TextStyle? get codeLabelStyle => AppDesign.textTheme.bodyLarge?.copyWith(
  color: AppDesign.textTertiary,
  fontSize: 13 / _floatingLabelScale,
  letterSpacing: 0,
  // The field's own style is a Latin code's, and the label is built on
  // it, so the label sets its language back to the app's.
  locale: AppDesign.activeLocale,
);

/// How a code field is decorated, in the redeem and the invite dialog.
/// [width] is the field's width.
///
/// The field is centred, so the words that say what goes in it are a label
/// on its top edge rather than a hint inside it: a centred caret drew
/// through the middle of a hint. The Paste button at the end is balanced
/// by an empty space of the same width at the start, so the caret and the
/// code sit in the middle of the whole field, not of the room left of the
/// button. On a narrow phone or with large text the space gives way
/// first: it never takes room that an invite code at its longest needs.
InputDecoration codeFieldDecoration(
  BuildContext context, {
  required double width,
  required String label,
  required String? error,
  required Key pasteKey,
  required VoidCallback onPaste,
}) {
  final paste = S.of(context)!.invitePasteAction;
  final button = _pasteWidth(context, paste);
  // The room the start space may take: what is left of the field after
  // the button, the gaps either side of the code and the code itself. At
  // its least the space is the field's own inner padding, as with no
  // space at all.
  final room = width - button - 2 * _inputGap - _codeInViewWidth(context);
  // The button is never narrower than a touch target, so wider than the
  // inset.
  final start = room.clamp(_fieldInset, button).toDouble();
  return InputDecoration(
    labelText: label,
    labelStyle: codeLabelStyle,
    floatingLabelStyle: codeLabelStyle,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    floatingLabelAlignment: FloatingLabelAlignment.center,
    errorText: error,
    errorMaxLines: 3,
    prefixIcon: SizedBox(width: start),
    prefixIconConstraints: const BoxConstraints(minHeight: 48),
    suffixIcon: TextButton(
      key: pasteKey,
      onPressed: onPaste,
      style: _pasteStyle,
      child: Text(paste),
    ),
  );
}

/// Material's gap between a field's text and the icons either side of it.
const double _inputGap = 4;

/// The theme's inner padding at a field's start, the least the start
/// space takes.
const double _fieldInset = AppDesign.space16;

/// The Paste button's side padding. Fixed, rather than Material's default
/// that shrinks as text grows, so [_pasteWidth] knows the button's width.
const double _pastePadding = 12;

/// The least width of the Paste button, a full touch target.
const double _pasteMinWidth = 48;

ButtonStyle get _pasteStyle => TextButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: _pastePadding, vertical: 8),
  minimumSize: const Size(_pasteMinWidth, 48),
  textStyle: AppDesign.textTheme.labelLarge,
);

/// How wide the Paste button is: its label in the button's text style at
/// the phone's text size, plus its side padding, and no less than a touch
/// target.
double _pasteWidth(BuildContext context, String label) {
  final width =
      _textWidth(context, label, AppDesign.textTheme.labelLarge) +
      2 * _pastePadding;
  return width < _pasteMinWidth ? _pasteMinWidth : width;
}

/// How wide an invite code at its longest is in the field, with the caret
/// after it. Every character of the monospace code is as wide as a zero.
double _codeInViewWidth(BuildContext context) =>
    _textWidth(context, '0' * InviteCode.maxTyped, codeFieldStyle) + _caret;

/// The caret's width, as TextField draws it.
const double _caret = 2;

double _textWidth(BuildContext context, String text, TextStyle? style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// The spinner in a code dialog's Apply button while the code is sent:
/// white on the ember fill, the size of the speed test's busy button.
class CodeSendingSpinner extends StatelessWidget {
  const CodeSendingSpinner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 18,
    child: CircularProgressIndicator(strokeWidth: 2, color: AppDesign.onBrand),
  );
}
