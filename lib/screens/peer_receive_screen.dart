import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/bootstrap.dart';
import '../api/peer_code.dart';
import '../core/design_system.dart';
import '../core/form_factor.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/peer_pick.dart';
import '../utils/number_localizer.dart';
import '../widgets/readable_width.dart';
import 'peer_share_screen.dart';

typedef PeerPickAnswer = ({PeerPickStatus status, String? text});
typedef PeerPickCall = Future<PeerPickAnswer> Function();

/// Gets the fallback file from a friend's phone, for a phone that cannot
/// get it anywhere else: a photo of the codes the friend's phone shows
/// (PeerShareScreen), a file it sent, or text it copied. Whatever comes in
/// goes through [Bootstrap.takeFromPeer], which keeps it only when it is
/// signed by us and newer than what this phone has.
///
/// The codes read so far are kept in [PeerReceiveScreen.savedKey] for
/// [PeerReceiveScreen.keepCodesFor]: Android often stops the app while the
/// camera app is open, and the photo then comes back to a new start of the
/// app ([PeerPick.leftover], handed in as [PeerReceiveScreen.start]).
class PeerReceiveScreen extends StatefulWidget {
  const PeerReceiveScreen({
    super.key,
    this.bootstrap,
    this.photograph = PeerPick.photograph,
    this.openFile = PeerPick.openFile,
    this.paste = _clipboard,
    this.canPick,
    this.start,
    this.now = DateTime.now,
  });

  /// Null is [Bootstrap.instance]. Tests pass their own.
  final Bootstrap? bootstrap;

  /// Opens the camera app and reads the code in the photo.
  final PeerPickCall photograph;

  /// Opens the file picker and reads the file.
  final PeerPickCall openFile;

  /// What is on the clipboard.
  final Future<String?> Function() paste;

  /// Whether the camera app and the file picker can be opened. Null asks
  /// the platform ([PeerPick.supported]).
  final bool? canPick;

  /// An answer that came back after the app was restarted, to take first.
  final PeerPickAnswer? start;

  final DateTime Function() now;

  static const savedKey = _PeerReceiveScreenState.peerCodesKey;

  /// How long the codes read so far are kept.
  static const keepCodesFor = Duration(minutes: 30);

  static Future<String?> _clipboard() async =>
      (await Clipboard.getData(Clipboard.kTextPlain))?.text;

  static Future<void> open(BuildContext context, {PeerPickAnswer? start}) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReadableWidth(child: PeerReceiveScreen(start: start)),
        ),
      );

  @override
  State<PeerReceiveScreen> createState() => _PeerReceiveScreenState();
}

class _PeerReceiveScreenState extends State<PeerReceiveScreen> {
  static const peerCodesKey = 'peer_codes';

  PeerCodeReader _reader = PeerCodeReader();
  bool _busy = false;
  String? _note;
  Color _noteTone = AppDesign.error;

  Bootstrap get _bootstrap => widget.bootstrap ?? Bootstrap.instance;

  bool get _canPick => widget.canPick ?? PeerPick.supported;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _run(() async {
        await _restore();
        final start = widget.start;
        if (start != null && mounted) {
          await _picked(start.status, start.text, fromPaste: false);
        }
      });
    });
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString(peerCodesKey) ?? '{}');
      final at = saved is Map ? saved['at'] : null;
      if (at is! int) return;
      final age = widget.now().difference(
        DateTime.fromMillisecondsSinceEpoch(at, isUtc: true),
      );
      if (age.isNegative || age > PeerReceiveScreen.keepCodesFor) {
        await prefs.remove(peerCodesKey);
        return;
      }
      final reader = PeerCodeReader.fromJson(saved['codes']);
      if (mounted && reader.have > 0) setState(() => _reader = reader);
    } catch (e) {
      debugPrint('PeerReceiveScreen: could not read the saved codes ($e)');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final codes = _reader.toJson();
      if (codes == null) {
        await prefs.remove(peerCodesKey);
      } else {
        await prefs.setString(
          peerCodesKey,
          jsonEncode({
            'at': widget.now().toUtc().millisecondsSinceEpoch,
            'codes': codes,
          }),
        );
      }
    } catch (e) {
      debugPrint('PeerReceiveScreen: could not save the codes ($e)');
    }
  }

  Future<void> _run(Future<void> Function() step) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _note = null;
    });
    try {
      await step();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _photograph() => _run(() async {
    final got = await widget.photograph();
    if (mounted) await _picked(got.status, got.text, fromPaste: false);
  });

  Future<void> _openFile() => _run(() async {
    final got = await widget.openFile();
    if (mounted) await _picked(got.status, got.text, fromPaste: false);
  });

  Future<void> _paste() => _run(() async {
    final nothing = S.of(context)!.peerReceiveNothingToPaste;
    final text = await widget.paste();
    if (text == null || text.trim().isEmpty) {
      _say(nothing);
      return;
    }
    if (mounted) await _add(text, fromPaste: true);
  });

  Future<void> _picked(
    PeerPickStatus status,
    String? text, {
    required bool fromPaste,
  }) async {
    final l10n = S.of(context)!;
    switch (status) {
      case PeerPickStatus.ok:
        await _add(text ?? '', fromPaste: fromPaste);
      case PeerPickStatus.cancelled:
        break;
      case PeerPickStatus.noPhoto:
        _say(l10n.peerReceiveNoPhoto(l10n.peerReceiveFile));
      case PeerPickStatus.noCode:
        _say(l10n.peerReceiveNoCode);
      case PeerPickStatus.unavailable:
        _say(l10n.peerReceiveUnavailable);
      case PeerPickStatus.unreadable:
        _say(l10n.peerReceiveRefused);
    }
  }

  /// One code, a file's text or pasted text. A piece waits for the rest;
  /// a whole file is taken.
  Future<void> _add(String text, {required bool fromPaste}) async {
    final l10n = S.of(context)!;
    final notOurs = fromPaste
        ? l10n.peerReceivePasteNotOurs
        : l10n.peerReceiveRefused;
    // Far longer than any file: not ours, and not worth searching.
    if (text.length > Bootstrap.maxBytes) {
      _say(notOurs);
      return;
    }
    switch (_reader.add(text)) {
      case PeerPiece.notOurs:
        _say(notOurs);
        return;
      case PeerPiece.again:
        _say(l10n.peerReceiveAgain, tone: AppDesign.info);
        return;
      case PeerPiece.added:
        break;
    }
    final lines = _reader.lines;
    if (lines.isEmpty) {
      setState(() {});
      await _save();
      return;
    }
    var took = PeerTake.refused;
    for (final line in lines) {
      took = await _bootstrap.takeFromPeer(line);
      if (took != PeerTake.refused) break;
    }
    _reader.reset();
    await _save();
    if (!mounted) return;
    switch (took) {
      case PeerTake.taken:
        _done(l10n.peerReceiveTaken);
      case PeerTake.notNewer:
        _say(l10n.peerReceiveNotNewer, tone: AppDesign.info);
      case PeerTake.refused:
        _say(l10n.peerReceiveRefused);
    }
  }

  /// Back to the home screen, where the connect button is a tap away, with
  /// [message] on it. Not when this screen is already leaving: a back
  /// press during a read would otherwise close the screen underneath.
  void _done(String message) {
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).popUntil((r) => r.isFirst);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _say(String note, {Color tone = AppDesign.error}) {
    if (!mounted) return;
    setState(() {
      _note = note;
      _noteTone = tone;
    });
  }

  /// What a button runs, or null to show it disabled while a read is
  /// under way. Not on a TV: a disabled button gives up the remote's
  /// focus, so there it stays enabled, and [_run] ignores the press.
  VoidCallback? _unlessBusy(VoidCallback action) =>
      _busy && !FormFactor.isTv ? null : action;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final total = _reader.total;
    final started = total != null && _reader.lines.isEmpty;
    // A TV has no camera to photograph with.
    final camera = _canPick && !FormFactor.isTv;
    final note = _note;
    final small = AppDesign.textTheme.bodySmall?.copyWith(
      color: AppDesign.textTertiary,
    );
    return Scaffold(
      backgroundColor: AppDesign.canvas,
      appBar: AppBar(
        title: Text(l10n.peerReceiveTitle),
        backgroundColor: AppDesign.canvas,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: AppDesign.clearOfNavBar(context, const EdgeInsets.all(20)),
        children: [
          PeerSteps(l10n.peerReceiveBody(l10n.peerShareTitle)),
          const SizedBox(height: AppDesign.space24),
          if (camera) ...[
            FilledButton.icon(
              onPressed: _unlessBusy(_photograph),
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: Text(
                started
                    ? l10n.peerReceivePhotographNext
                    : l10n.peerReceivePhotograph,
              ),
            ),
            if (started) ...[
              const SizedBox(height: AppDesign.space8),
              Semantics(
                liveRegion: true,
                child: Text(
                  NumberLocalizer.localize(
                    l10n.peerReceiveProgress(_reader.have, total),
                    context,
                  ),
                  textAlign: TextAlign.center,
                  style: AppDesign.textTheme.labelMedium?.copyWith(
                    color: AppDesign.textSecondary,
                    fontFeatures: AppDesign.numberFeatures,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppDesign.space12),
          ],
          if (_canPick) ...[
            OutlinedButton.icon(
              onPressed: _unlessBusy(_openFile),
              icon: const Icon(Icons.file_open_outlined, size: 18),
              label: Text(l10n.peerReceiveFile),
            ),
            const SizedBox(height: AppDesign.space6),
            Text(
              l10n.peerReceiveFileHint,
              textAlign: TextAlign.center,
              style: small,
            ),
            const SizedBox(height: AppDesign.space12),
          ],
          OutlinedButton.icon(
            onPressed: _unlessBusy(_paste),
            icon: const Icon(Icons.content_paste_rounded, size: 18),
            label: Text(l10n.peerReceivePaste),
          ),
          if (_busy) ...[
            const SizedBox(height: AppDesign.space20),
            const Center(child: CircularProgressIndicator()),
          ],
          if (note != null) ...[
            const SizedBox(height: AppDesign.space20),
            Semantics(
              liveRegion: true,
              child: _Note(text: note, tone: _noteTone),
            ),
          ],
        ],
      ),
    );
  }
}

/// What happened with the last try, on a tinted panel: the error tone
/// when it did not work, the info tone when there is nothing to fix.
class _Note extends StatelessWidget {
  const _Note({required this.text, required this.tone});

  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final error = tone == AppDesign.error;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 16, 12),
      decoration: BoxDecoration(
        color: error ? AppDesign.errorContainer : AppDesign.infoContainer,
        borderRadius: AppDesign.borderRadiusMedium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppDesign.space2),
            child: Icon(
              error ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              color: tone,
              size: 18,
            ),
          ),
          const SizedBox(width: AppDesign.space12),
          Expanded(
            child: Text(
              text,
              style: AppDesign.textTheme.bodyMedium?.copyWith(
                color: AppDesign.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
