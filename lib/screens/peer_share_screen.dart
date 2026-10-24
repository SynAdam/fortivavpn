import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../api/bootstrap.dart';
import '../api/peer_code.dart';
import '../core/design_system.dart';
import '../core/form_factor.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/number_localizer.dart';
import '../widgets/outside_link.dart';
import '../widgets/readable_width.dart';

/// What this phone has for a friend's phone whose Fortiva cannot connect:
/// the fallback file ([Bootstrap.shareable]) as QR codes to photograph, or
/// sent or copied to them. The friend's side is PeerReceiveScreen.
///
/// No network is needed between the two phones. The codes go from screen
/// to camera, and a file goes by Quick Share, Bluetooth or any messenger
/// that still works. The other phone checks the signature itself, so this
/// phone passes on only what the backend signed.
class PeerShareScreen extends StatefulWidget {
  const PeerShareScreen({super.key, this.bootstrap, this.draw = QrModules.of});

  /// Null is [Bootstrap.instance]. Tests pass their own.
  final Bootstrap? bootstrap;

  /// Draws one code. The app asks Android; tests pass their own.
  final Future<QrModules?> Function(String text) draw;

  /// The name of the file [_send] shares.
  static const fileName = 'fortiva.txt';

  static Future<void> open(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const ReadableWidth(child: PeerShareScreen()),
    ),
  );

  @override
  State<PeerShareScreen> createState() => _PeerShareScreenState();
}

class _PeerShareScreenState extends State<PeerShareScreen> {
  bool _loading = true;

  /// The file as it is shown, fixed once loaded: codes that changed half
  /// way through would leave the friend with pieces of two files.
  String? _line;
  List<QrModules>? _codes;
  int _shown = 0;

  Bootstrap get _bootstrap => widget.bootstrap ?? Bootstrap.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // A phone whose calls to the backend work never reads the hosts by
      // itself, and may hold only the copy built into the app. It can read
      // them now, so the friend gets the newest file.
      await _bootstrap.readForSharing();
    } catch (e) {
      debugPrint('PeerShareScreen: could not read the hosts ($e)');
    }
    final line = _bootstrap.shareable?.text;
    List<QrModules>? codes;
    if (line != null) {
      final drawn = await Future.wait(PeerCode.split(line).map(widget.draw));
      // All or none: a friend cannot use some of the pieces.
      if (drawn.every((c) => c != null)) codes = drawn.cast<QrModules>();
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _line = line;
      _codes = codes;
    });
  }

  Future<void> _send(String line) async {
    // sharePositionOrigin anchors the share popover on a tablet.
    final box = context.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              utf8.encode(line),
              mimeType: 'text/plain',
              name: PeerShareScreen.fileName,
            ),
          ],
          fileNameOverrides: const [PeerShareScreen.fileName],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (e) {
      debugPrint('PeerShareScreen: could not share the file ($e)');
    }
  }

  Future<void> _copy(String line) async {
    await Clipboard.setData(ClipboardData(text: line));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(S.of(context)!.peerShareCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final line = _line;
    final codes = _codes;
    final text = AppDesign.textTheme.bodyMedium?.copyWith(
      color: AppDesign.textSecondary,
    );
    return Scaffold(
      backgroundColor: AppDesign.canvas,
      appBar: AppBar(
        title: Text(l10n.peerShareTitle),
        backgroundColor: AppDesign.canvas,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: AppDesign.clearOfNavBar(context, const EdgeInsets.all(20)),
        children: [
          Text(l10n.peerShareBody, style: text),
          const SizedBox(height: AppDesign.space24),
          if (_loading)
            Column(
              children: [
                const SizedBox(height: AppDesign.space24),
                const CircularProgressIndicator(),
                const SizedBox(height: AppDesign.space16),
                Text(
                  l10n.peerShareLoading,
                  textAlign: TextAlign.center,
                  style: text,
                ),
              ],
            )
          else if (line == null)
            Text(l10n.peerShareNothing, style: text)
          else ...[
            PeerSteps(l10n.peerShareSteps(l10n.peerReceiveTitle)),
            if (codes != null) ...[
              const SizedBox(height: AppDesign.space24),
              _Codes(
                codes: codes,
                shown: _shown,
                onShow: (i) => setState(() => _shown = i),
              ),
            ],
            // A TV has no share sheet worth the name and no clipboard
            // anyone pastes from; it shows the codes.
            if (!FormFactor.isTv) ...[
              const SizedBox(height: AppDesign.space24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copy(line),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(l10n.peerShareCopy),
                    ),
                  ),
                  const SizedBox(width: AppDesign.space12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _send(line),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: Text(l10n.peerShareSend),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// [text] cut into its sentences, to show as numbered steps, or null when
/// it does not cut into exactly [count].
///
/// The two instructions on these screens are two sentences in every
/// language the app speaks: what the friend opens, then what to do next.
/// A later translation written as one sentence, or as three, is then shown
/// whole rather than numbered wrongly. A sentence ends at a full stop or a
/// question or exclamation mark followed by a space, in the Latin, Arabic,
/// Urdu and Devanagari forms, or at the ideographic full stop, which takes
/// no space.
List<String>? peerSteps(String text, {int count = 2}) {
  final parts = text
      .split(RegExp(r'(?<=[.!?\u061F\u06D4\u0964])\s+|(?<=\u3002)'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  return parts.length == count ? parts : null;
}

/// An instruction as numbered steps (see [peerSteps]), or whole as one
/// paragraph when it does not cut into steps.
class PeerSteps extends StatelessWidget {
  const PeerSteps(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final steps = peerSteps(text);
    final style = AppDesign.textTheme.bodyMedium?.copyWith(
      color: AppDesign.textPrimary,
    );
    if (steps == null) return Text(text, style: style);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, step) in steps.indexed) ...[
          if (i > 0) const SizedBox(height: AppDesign.space12),
          PeerStep(number: i + 1, text: step, style: style),
        ],
      ],
    );
  }
}

/// One step: its number in a small disc, in the language's own digits,
/// and the step beside it.
class PeerStep extends StatelessWidget {
  const PeerStep({
    super.key,
    required this.number,
    required this.text,
    this.style,
  });

  final int number;
  final String text;
  final TextStyle? style;

  static const double discSize = 24;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: discSize,
          height: discSize,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppDesign.surfaceHigh,
            shape: BoxShape.circle,
          ),
          child: Text(
            NumberLocalizer.localize('$number', context),
            style: AppDesign.textTheme.labelMedium?.copyWith(
              color: AppDesign.textPrimary,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: AppDesign.space12),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

/// One code at a time, as big as the screen allows, on a white card, with
/// the buttons to move between them. A camera reads a big code off a
/// screen far more easily than a small one.
class _Codes extends StatelessWidget {
  const _Codes({
    required this.codes,
    required this.shown,
    required this.onShow,
  });

  final List<QrModules> codes;
  final int shown;
  final ValueChanged<int> onShow;

  /// The biggest the code is drawn, on a tablet.
  static const maxSide = 560.0;

  /// The white margin of the card around the code, outside the code's own
  /// quiet zone.
  static const cardPadding = 16.0;

  /// The share of the screen's height the code may take, so a TV's short
  /// screen shows the whole of it with the buttons under it.
  static const heightShare = 0.6;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final many = codes.length > 1;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final label = NumberLocalizer.localize(
      l10n.peerShareCodeOf(shown + 1, codes.length),
      context,
    );
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final side = math.max(
              0.0,
              [
                constraints.maxWidth - 2 * cardPadding,
                maxSide,
                screenHeight * heightShare,
              ].reduce(math.min),
            );
            return Center(
              child: Container(
                padding: const EdgeInsets.all(cardPadding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppDesign.borderRadiusLarge,
                ),
                child: Semantics(
                  image: true,
                  label: label,
                  child: QrCode(
                    key: ValueKey(shown),
                    modules: codes[shown],
                    size: side,
                    pixelRatio: MediaQuery.devicePixelRatioOf(context),
                  ),
                ),
              ),
            );
          },
        ),
        if (many) ...[
          const SizedBox(height: AppDesign.space16),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppDesign.textTheme.titleSmall?.copyWith(
              color: AppDesign.textPrimary,
              fontFeatures: AppDesign.numberFeatures,
            ),
          ),
          const SizedBox(height: AppDesign.space8),
          _Dots(count: codes.length, shown: shown),
          const SizedBox(height: AppDesign.space4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Step(
                label: l10n.peerSharePrevious,
                onPressed: shown > 0 ? () => onShow(shown - 1) : null,
              ),
              const SizedBox(width: AppDesign.space16),
              _Step(
                label: l10n.peerShareNext,
                autofocus: true,
                onPressed: shown < codes.length - 1
                    ? () => onShow(shown + 1)
                    : null,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Back or Next under the code. At the end of the codes it is disabled on
/// a phone, as before. On a TV it stays enabled, looks spent and does
/// nothing: a disabled button gives up the focus, and a remote that
/// pressed Next onto the last code would land somewhere else.
class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.onPressed,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final onPressed = this.onPressed;
    final spentOnTv = onPressed == null && FormFactor.isTv;
    return TextButton(
      autofocus: autofocus,
      onPressed: spentOnTv ? () {} : onPressed,
      style: spentOnTv
          ? TextButton.styleFrom(foregroundColor: AppDesign.textDisabled)
          : null,
      child: Text(label),
    );
  }
}

/// Which code is showing, as a row of dots. The line above says the same
/// in words, so this says nothing to a screen reader.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.shown});

  final int count;
  final int shown;

  static const double _size = 6;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppDesign.space6,
        runSpacing: AppDesign.space6,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: AppMotion.quick,
              curve: AppMotion.standard,
              width: i == shown ? _size * 3 : _size,
              height: _size,
              decoration: BoxDecoration(
                color: i == shown ? AppDesign.steelLight : AppDesign.steelDark,
                borderRadius: BorderRadius.circular(_size / 2),
              ),
            ),
        ],
      ),
    );
  }
}
