import 'package:flutter/material.dart';

import '../api/referral_service.dart';
import '../core/form_factor.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/invite_share.dart';
import 'outside_link.dart';

/// Send this device's invite through the share sheet, as the invite
/// screen's Share button does. The invite screen, the limit sheet and the
/// introduction to the invite tree share it, and each notes its own event.
///
/// A TV has no share sheet worth the name, and nothing on it to send an
/// invite through. There the link goes to the user's phone as a QR code,
/// and is shared from there, so this returns false: nothing was sent from
/// the TV. Elsewhere it returns whether the share opened something. The
/// text carries the plain share link; only the home card's adds `s=card`.
/// Never throws.
Future<bool> sendInvite(BuildContext context, ReferralStatus status) async {
  try {
    final link = Uri.tryParse(status.shareUrl);
    if (FormFactor.isTv && link != null) {
      await LinkQrDialog.show(link);
      return false;
    }
    final l10n = S.of(context)!;
    // sharePositionOrigin is what anchors the popover on a tablet; without
    // it the share sheet has nowhere to point and the platform throws.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    // The share sheet hides the state messengers: the backend's list, or
    // the app's own while the backend sent none.
    final opened = await InviteShare.send(
      text: l10n.inviteShareMessage(status.code, status.shareUrl),
      target: InviteTarget.otherApps,
      exclude: status.shareExcludePackages.isEmpty
          ? null
          : status.shareExcludePackages,
      title: l10n.inviteTitle,
      origin: origin,
    );
    return opened != InviteShareOutcome.none;
  } catch (e) {
    debugPrint('sendInvite: not sent ($e)');
    return false;
  }
}
