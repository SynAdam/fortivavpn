import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/design_system.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/state_platforms.dart';
import 'tunnel_channels.dart';

/// Where an invite goes from the card.
enum InviteTarget { telegram, whatsapp, copyLink, otherApps }

/// What a share opened: a messenger, the system share sheet, or nothing.
enum InviteShareOutcome { app, sheet, none }

/// Sends an invite through a messenger or the system share sheet, with the
/// state messengers hidden.
///
/// Fortiva never uses a government platform (decided 2026-10-13). On Android
/// the native side opens the share sheet with every share activity of an
/// excluded package in EXTRA_EXCLUDE_COMPONENTS (MainActivity.kt,
/// handler/InviteShare.kt). share_plus builds its own chooser and takes no
/// such list, so it is used only on other platforms.
class InviteShare {
  InviteShare._();

  /// Hidden from every share sheet, whatever the backend sends: the state
  /// platforms' packages (StatePlatforms.packages).
  static const builtInExclude = StatePlatforms.packages;

  /// Whether the native share method is used. Android only; tests set it.
  @visibleForTesting
  static bool? nativeForTest;

  /// The Android SDK level, for [copy]. Tests set it.
  @visibleForTesting
  static Future<int> Function()? sdkIntForTest;

  static bool get _native => nativeForTest ?? Platform.isAndroid;

  /// The packages to hide: always [builtInExclude], then any others in
  /// [exclude], the backend's list. A backend list that leaves one of the
  /// state messengers out never shows it again.
  static List<String> excludeFor(List<String>? exclude) =>
      {...builtInExclude, ...?exclude}.toList();

  /// Send [text] to [target]: Telegram or WhatsApp straight away when
  /// installed, else the share sheet; [InviteTarget.otherApps] always the
  /// share sheet. Not for [InviteTarget.copyLink]: see [copy]. Never
  /// throws.
  static Future<InviteShareOutcome> send({
    required String text,
    required InviteTarget target,
    List<String>? exclude,
    String? title,
    Rect? origin,
  }) async {
    try {
      if (!_native) {
        await SharePlus.instance.share(
          ShareParams(text: text, subject: title, sharePositionOrigin: origin),
        );
        return InviteShareOutcome.sheet;
      }
      final answer = await TunnelChannels.method
          .invokeMethod<String>('shareInvite', {
            'text': text,
            'target': switch (target) {
              InviteTarget.telegram => 'telegram',
              InviteTarget.whatsapp => 'whatsapp',
              InviteTarget.copyLink || InviteTarget.otherApps => 'sheet',
            },
            'exclude': excludeFor(exclude),
            'title': title,
          });
      return switch (answer) {
        'app' => InviteShareOutcome.app,
        'sheet' => InviteShareOutcome.sheet,
        _ => InviteShareOutcome.none,
      };
    } catch (e) {
      debugPrint('InviteShare: could not share ($e)');
      return InviteShareOutcome.none;
    }
  }

  /// Copy [text] and say so, below Android 13 only: Android 13 and later
  /// show their own notice for a copy. Never throws.
  static Future<void> copy(BuildContext context, String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (e) {
      debugPrint('InviteShare: could not copy ($e)');
      return;
    }
    if (!_native) {
      if (context.mounted) _toast(context);
      return;
    }
    int sdk;
    try {
      final read = sdkIntForTest;
      sdk = read != null
          ? await read()
          : (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    } catch (_) {
      sdk = 0;
    }
    // Android 13 is SDK 33.
    if (sdk < 33 && context.mounted) _toast(context);
  }

  static void _toast(BuildContext context) {
    final l10n = S.of(context);
    if (l10n == null) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(l10n.inviteLinkCopied),
        backgroundColor: AppDesign.surfaceLight,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// The card's link: [shareUrl] with `s=card` added to its query, so the
  /// invite page counts it under the card. Built with Uri.replace, never by
  /// adding text, so a link that already has a query stays valid.
  static String cardLink(String shareUrl) {
    final uri = Uri.tryParse(shareUrl);
    if (uri == null) return shareUrl;
    return uri
        .replace(queryParameters: {...uri.queryParameters, 's': 'card'})
        .toString();
  }
}
