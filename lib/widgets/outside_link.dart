import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/design_system.dart';
import '../core/form_factor.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/tunnel_channels.dart';

/// The app's navigator, for a QR code shown by code that has no context of
/// its own, such as the update dialog's buttons. Set on the MaterialApp.
final appNavigatorKey = GlobalKey<NavigatorState>();

/// Open [url] outside the app: in Telegram, the Play Store or a browser.
///
/// On a TV the link is shown as a QR code for the user's phone instead.
/// Telegram is not on a TV, a browser seldom is, and a remote makes a poor
/// keyboard. A Play Store link still opens on the TV, which has the store,
/// and becomes a code only when nothing there opens it.
///
/// Returns whether the link was opened or shown. Never throws.
Future<bool> openOutside(Uri url) async {
  if (FormFactor.isTv && !_opensOnTv(url)) return LinkQrDialog.show(url);
  var opened = false;
  try {
    opened = await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('openOutside: could not open $url ($e)');
  }
  if (!opened && FormFactor.isTv) return LinkQrDialog.show(url);
  return opened;
}

bool _opensOnTv(Uri url) =>
    url.scheme == 'market' || url.host == 'play.google.com';

/// A link as a QR code, for a phone to open what a TV cannot.
class LinkQrDialog extends StatelessWidget {
  const LinkQrDialog({super.key, required this.url, required this.modules});

  final Uri url;
  final QrModules modules;

  /// Show [url] as a code over whatever is on screen. False when there is
  /// no code to show: the platform could not draw one, or there is no
  /// screen yet.
  static Future<bool> show(Uri url) async {
    final modules = await QrModules.of(url.toString());
    final context = appNavigatorKey.currentContext;
    if (modules == null || context == null || !context.mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (_) => LinkQrDialog(url: url, modules: modules),
    );
    return true;
  }

  /// The link the way someone would type it, under the code, for a phone
  /// whose camera does not read codes.
  @visibleForTesting
  static String readable(Uri url) {
    var text = url.toString().replaceFirst(RegExp(r'^https?://'), '');
    if (text.endsWith('/')) text = text.substring(0, text.length - 1);
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return AlertDialog(
      // Scrolls rather than overflows on a TV's short screen at large text.
      scrollable: true,
      title: Text(l10n.tvScanTitle, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.tvScanBody,
            textAlign: TextAlign.center,
            style: AppDesign.textTheme.bodyMedium?.copyWith(
              color: AppDesign.textSecondary,
            ),
          ),
          const SizedBox(height: AppDesign.space20),
          // Rounded corners on the code's own white margin. The four
          // module quiet zone is inside the code, so they cut none of it.
          ClipRRect(
            borderRadius: AppDesign.borderRadiusMedium,
            child: QrCode(modules: modules, size: 220),
          ),
          const SizedBox(height: AppDesign.space12),
          Text(
            readable(url),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppDesign.textTheme.bodySmall?.copyWith(
              color: AppDesign.textTertiary,
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

/// The modules of a QR code, from the encoder the Android app already
/// carries for share links. Row by row, nonzero for dark.
class QrModules {
  const QrModules(this.size, this.dark);

  final int size;
  final Uint8List dark;

  bool isDark(int x, int y) => dark[y * size + x] != 0;

  /// Null when the platform cannot encode [text]. Never throws.
  static Future<QrModules?> of(String text) async {
    try {
      final reply = await TunnelChannels.method
          .invokeMapMethod<String, Object?>('qrModules', {'text': text});
      final size = reply?['size'];
      final dark = reply?['modules'];
      if (size is! int || dark is! Uint8List || dark.length != size * size) {
        return null;
      }
      return QrModules(size, dark);
    } catch (e) {
      debugPrint('QrModules: no code for a link ($e)');
      return null;
    }
  }
}

/// Draws [modules] black on white, inside the quiet zone of four modules
/// that a camera needs to find the code.
class QrCode extends StatelessWidget {
  const QrCode({
    super.key,
    required this.modules,
    required this.size,
    this.pixelRatio = 1,
  });

  final QrModules modules;
  final double size;

  /// The screen's physical pixels per logical pixel. Modules are whole
  /// pixels of this size, so a code on a dense phone screen can use the
  /// space between two whole logical pixels.
  final double pixelRatio;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _QrPainter(modules, pixelRatio)),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.modules, this.pixelRatio);

  final QrModules modules;
  final double pixelRatio;

  static const int quietZone = 4;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final cells = modules.size + 2 * quietZone;
    // Whole pixels per module where there is room, so every module is the
    // same size; a camera reads unevenly sized ones less reliably.
    final exact = size.shortestSide / cells;
    final pixels = exact * pixelRatio;
    final cell = pixels >= 2 ? pixels.floorToDouble() / pixelRatio : exact;
    final origin = Offset(
      (size.width - cell * modules.size) / 2,
      (size.height - cell * modules.size) / 2,
    );
    final dark = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (var y = 0; y < modules.size; y++) {
      for (var x = 0; x < modules.size; x++) {
        if (!modules.isDark(x, y)) continue;
        canvas.drawRect(
          Rect.fromLTWH(origin.dx + x * cell, origin.dy + y * cell, cell, cell),
          dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) =>
      old.modules != modules || old.pixelRatio != pixelRatio;
}
