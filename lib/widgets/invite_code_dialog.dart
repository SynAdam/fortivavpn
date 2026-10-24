import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/referral_service.dart';
import '../core/design_system.dart';
import '../core/state/referral_state.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/invite_code.dart';
import '../utils/number_localizer.dart';
import 'redeem_code_dialog.dart'
    show
        CodeSendingSpinner,
        codeDialogActionsPadding,
        codeFieldDecoration,
        codeFieldStyle;

/// Ask for a code somebody shared, and claim it.
///
/// This is the path that works everywhere. The Play Install Referrer
/// covers Android installs that came from Google Play, but a sideloaded
/// APK reports nothing and iOS has no equivalent at all, so typing or
/// pasting the code has to stay available on every platform.
///
/// A friend usually pastes the whole message they were sent. The field
/// finds the code in it (InviteCode.find), Persian and Arabic digits
/// included, and the Paste button reads the clipboard only when tapped.
/// The dialog never loads the referral status, because the first load
/// mints an invite code for this device.
///
/// Nothing is promised to the person entering the code. App Review
/// rejects referral programs that reward the invited user, so the
/// confirmation says who benefits and when, and offers them nothing.
Future<bool> showInviteCodeDialog(BuildContext context) async {
  final claimed = await showDialog<bool>(
    context: context,
    builder: (_) => const _InviteCodeDialog(),
  );
  return claimed ?? false;
}

/// The line under "Have an invite code?": how long a new install has to
/// enter a code, as the backend sends it (claim_window_hours).
///
/// Null [hours] gives text that names no number. The app never states the
/// window on its own, because a number written into the app stays wrong
/// on every phone until the next release reaches it. It used to say 72.
String inviteHaveCodeSubtitleText(BuildContext context, int? hours) {
  final l10n = S.of(context)!;
  if (hours == null) return l10n.inviteHaveCodeSubtitleNoHours;
  return NumberLocalizer.localize(l10n.inviteHaveCodeSubtitle(hours), context);
}

/// What the person who entered a code is told: their friend earns once
/// they have used the VPN on [days] different days (confirm_active_days),
/// or text that names no number when [days] is null.
String inviteClaimAcceptedText(BuildContext context, int? days) {
  final l10n = S.of(context)!;
  if (days == null) return l10n.inviteClaimAcceptedNoDays;
  return NumberLocalizer.localize(l10n.inviteClaimAccepted(days), context);
}

class _InviteCodeDialog extends StatefulWidget {
  const _InviteCodeDialog();

  @override
  State<_InviteCodeDialog> createState() => _InviteCodeDialogState();
}

class _InviteCodeDialogState extends State<_InviteCodeDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _messageFor(ReferralClaimFailure? failure, S l10n) {
    return switch (failure) {
      ReferralClaimFailure.tooLate => l10n.inviteErrorTooLate,
      ReferralClaimFailure.unknownCode => l10n.inviteErrorUnknown,
      ReferralClaimFailure.ownCode => l10n.inviteErrorOwnCode,
      ReferralClaimFailure.mutual => l10n.inviteErrorMutual,
      ReferralClaimFailure.alreadyClaimed => l10n.inviteClaimAlready,
      ReferralClaimFailure.network => l10n.inviteClaimNetwork,
      ReferralClaimFailure.rejected ||
      ReferralClaimFailure.limited ||
      ReferralClaimFailure.unexpected ||
      ReferralClaimFailure.unknownDevice ||
      null => l10n.inviteClaimRejected,
    };
  }

  /// A paste of more than [InviteCode.maxTyped] characters into the field
  /// left [code] there, or nothing when it held no code. A code is claimed
  /// at once, as the Paste button does.
  void _pasted(String? code) {
    // Called from the field's formatter, which must not rebuild the
    // dialog while the field is being edited.
    Future.microtask(() {
      if (!mounted) return;
      if (code == null) {
        setState(() => _error = S.of(context)!.inviteErrorUnknown);
        return;
      }
      _submit(source: 'paste');
    });
  }

  /// Read the clipboard, only on this tap, and claim the code found in it.
  Future<void> _paste() async {
    final l10n = S.of(context)!;
    if (context.read<ReferralState>().isClaiming) return;
    String? text;
    try {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (e) {
      debugPrint('InviteCodeDialog: clipboard unreadable ($e)');
    }
    if (!mounted) return;
    final code = text == null ? null : InviteCode.find(text);
    if (code == null) {
      setState(() => _error = l10n.inviteErrorUnknown);
      return;
    }
    _controller.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    await _submit(source: 'paste');
  }

  Future<void> _submit({String source = 'manual'}) async {
    final l10n = S.of(context)!;
    final state = context.read<ReferralState>();
    // A tap while a claim runs is ignored, so the buttons can stay enabled.
    if (state.isClaiming) return;
    final typed = _controller.text.trim();
    if (typed.isEmpty) return;
    final code = InviteCode.find(typed) ?? typed;

    final result = await state.claim(code, source: source);
    if (!mounted) return;

    if (!result.claimed) {
      setState(() => _error = _messageFor(result.failure, l10n));
      return;
    }

    // The claim answer carries the number of days. A status loaded on the
    // invite screen has it too; the home row has none loaded.
    final accepted = inviteClaimAcceptedText(
      context,
      result.confirmActiveDays ?? state.status?.confirmActiveDays,
    );
    Navigator.of(context).pop(true);
    // The theme's snackbar colors: light text on the bar.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(accepted),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final referral = context.watch<ReferralState>();
    final claiming = referral.isClaiming;

    return AlertDialog(
      title: Text(l10n.inviteHaveCodeTitle),
      // The lines and the field under the title scroll, and the buttons
      // stay below them, so a small phone with large text or with the
      // keyboard up keeps Apply in view instead of overflowing. Not
      // AlertDialog.scrollable: that asks the content for its height, which
      // the field's LayoutBuilder cannot give.
      content: SingleChildScrollView(
        // As wide as the dialog may be, in every language, so this dialog
        // and the redeem dialog come up the same width. Shrink wrapped, each
        // took the width of its own longest line.
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The status is loaded whenever the dialog opens from the
              // invite screen. Opened anywhere else before it has loaded, the
              // line names no number. The dialog does not load the status
              // itself, because the first load mints an invite code for this
              // device.
              Text(
                inviteHaveCodeSubtitleText(
                  context,
                  referral.status?.claimWindowHours,
                ),
                style: AppDesign.textTheme.bodyMedium?.copyWith(
                  color: AppDesign.textPrimary,
                ),
              ),
              const SizedBox(height: AppDesign.space8),
              Text(
                l10n.invitePasteBody,
                style: AppDesign.textTheme.bodyMedium?.copyWith(
                  color: AppDesign.textSecondary,
                ),
              ),
              const SizedBox(height: AppDesign.space16),
              LayoutBuilder(
                builder: (context, constraints) => TextField(
                  key: const Key('invite-code-field'),
                  controller: _controller,
                  autofocus: true,
                  // Read only while a claim runs, not disabled: a disabled
                  // field drops the keyboard's or a TV remote's focus.
                  readOnly: claiming,
                  autocorrect: false,
                  enableSuggestions: false,
                  // A code is Latin letters and digits, typed left to right in
                  // every language, in the middle of the field. Paste stays at
                  // the end of the field in the app's direction.
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  inputFormatters: [InviteCodeFormatter(onPaste: _pasted)],
                  style: codeFieldStyle,
                  // Paste is never disabled while a claim runs, as a disabled
                  // button loses a TV remote's focus: the tap is ignored
                  // instead.
                  decoration: codeFieldDecoration(
                    context,
                    width: constraints.maxWidth,
                    label: l10n.inviteEnterCodeHint,
                    error: _error,
                    pasteKey: const Key('invite-paste'),
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
            if (!claiming) Navigator.of(context).pop(false);
          },
          style: TextButton.styleFrom(foregroundColor: AppDesign.textSecondary),
          child: Text(l10n.inviteNotNowAction),
        ),
        // Apply waits for something in the field, and follows it as it is
        // typed. It stays enabled while a claim runs, as a disabled button
        // loses a TV remote's focus: _submit ignores that tap instead.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => FilledButton(
            onPressed: value.text.trim().isEmpty ? null : _submit,
            style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
            child: claiming
                ? const CodeSendingSpinner()
                : Text(l10n.inviteApplyAction),
          ),
        ),
      ],
      actionsPadding: codeDialogActionsPadding,
    );
  }
}

/// The code field's formatter. Persian and Arabic digits become 0-9 and
/// letters upper case. The alphabet has no punctuation, so the field
/// rejects the rest rather than let the backend do it, and a typed code
/// keeps to [InviteCode.maxTyped] characters.
///
/// A change that adds more than [InviteCode.maxTyped] characters at once
/// is a paste: the field then holds only the code found in it
/// (InviteCode.find), or nothing, and [onPaste] hears which.
class InviteCodeFormatter extends TextInputFormatter {
  InviteCodeFormatter({required this.onPaste});

  final void Function(String? code) onPaste;

  static final _notAllowed = RegExp(r'[^A-Z0-9\- ]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length - oldValue.text.length > InviteCode.maxTyped) {
      final code = InviteCode.find(newValue.text);
      onPaste(code);
      final text = code ?? '';
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    var text = InviteCode.foldDigits(
      newValue.text,
    ).toUpperCase().replaceAll(_notAllowed, '');
    if (text.length > InviteCode.maxTyped) {
      text = text.substring(0, InviteCode.maxTyped);
    }
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
