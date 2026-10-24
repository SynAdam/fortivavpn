import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../core/design_system.dart';
import '../core/haptics.dart';
import '../data/models/connection_info.dart';
import 'focus_ring.dart';
import 'power_face.dart';

/// The one control on the home screen.
///
/// A VPN has exactly one thing a user wants to do, and the previous layout
/// buried it inside the first of six stacked diagnostic panels. This is
/// deliberately enormous and centred: at a glance you should know whether
/// you are protected, and reaching the control should take no aim.
///
/// It is the app's own shield, and the helmet's eyes show the connection.
/// They are dark while it is off. While a connect runs, a steel light sweeps
/// from eye to eye, and only a working connection lights them protected
/// green, with a halo round the shield. A stalled tunnel shows amber eyes
/// and a failed one red. Green is never shown before the tunnel is known to
/// work.
///
/// The shield and its light are pictures that tool/hero_art.py draws from
/// the app icon. The button tints the light with the colour of its state.
class PowerButton extends StatefulWidget {
  final VpnStatus status;
  final bool isVerifying;
  final VoidCallback onTap;
  final double size;

  /// The button's focus, for a TV remote. The home screen holds it, to put
  /// the remote on the button when the screen opens.
  final FocusNode? focusNode;

  /// What the button shows. The home screen passes the face it works out
  /// from the same signals as the status line. Null: worked out from
  /// [status] and [isVerifying] alone (powerFaceFor).
  final PowerFace? face;

  /// Whether a connect that lands while the button is on screen gets its
  /// success moment. The home screen passes false on the first frame after
  /// the app opened or came back, and for a connection that came back by
  /// itself.
  final bool celebrate;

  /// What a screen reader says for the button: the status line's words.
  final String? semanticLabel;

  /// What a screen reader adds about what a tap does, when the button has
  /// something to say: during a search, that a tap stops it. Null says
  /// nothing more.
  final String? semanticHint;

  const PowerButton({
    super.key,
    required this.status,
    required this.isVerifying,
    required this.onTap,
    this.size = defaultSize,
    this.focusNode,
    this.face,
    this.celebrate = true,
    this.semanticLabel,
    this.semanticHint,
  });

  /// The size the home screen draws it at.
  static const double defaultSize = 220;

  /// Decodes the button's pictures at the size it draws them, so a button
  /// built once this is done has them on its first frame. The splash
  /// screen calls it while it holds.
  static Future<void> precache(
    BuildContext context, {
    double size = defaultSize,
  }) {
    return Future.wait([
      for (final image in _Art.images(context, size))
        precacheImage(image, context),
    ]);
  }

  @override
  State<PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<PowerButton>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// One sweep of the light from eye to eye and back. Steady for the whole
  /// connect: a light that sped up as the wait grew would promise an end it
  /// cannot see.
  static const Duration _sweepTime = Duration(milliseconds: 2400);

  /// How far a press pushes the button in.
  static const double _pressedScale = 0.95;

  /// The release: a quick spring with a small overshoot, so the button
  /// feels like it springs back rather than slides.
  static final SpringDescription _springBack =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 800, ratio: 0.6);

  /// The shield's pop on a working connection, and the share of the
  /// success moment it takes (400ms of 700ms).
  static const double _popScale = 1.04;
  static const double _popShare = 400 / 700;

  /// Colors from one face to the next.
  late final AnimationController _look;
  late final CurvedAnimation _lookCurve;

  /// The busy light's sweep. Runs only while busy and on screen.
  late final AnimationController _sweep;

  /// The success moment: the eyes' flash, the ripple and the pop.
  late final AnimationController _success;
  late final CurvedAnimation _popCurve;
  late final Animation<double> _pop;

  /// The press dip. Unbounded, because the spring overshoots 1.
  late final AnimationController _press;

  final _ArtImages _art = _ArtImages();

  late PowerFace _shown;
  late _Look _from;
  late _Look _to;

  bool _tickersOn = true;
  bool _reduced = false;

  /// Set while the app is in the background, and until the first frame
  /// after it comes back. Frames stop in the background, so a connect that
  /// landed there is handled in that first frame, and the user did not
  /// watch it land.
  bool _away = false;

  /// Counts trips to the background, so a clear left waiting from an
  /// earlier return does not clear a newer trip.
  int _trips = 0;

  /// The running press dip, while a finger or a remote holds the button.
  TickerFuture? _pressIn;

  /// Counts presses, so a release left waiting for an old dip does not
  /// spring the button back out from under a new press.
  int _pressCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _away = _isAway(WidgetsBinding.instance.lifecycleState);
    _shown = _face;
    _from = _to = _Look.of(_shown);
    _look = AnimationController(vsync: this, duration: AppMotion.slow, value: 1)
      ..addStatusListener(_lookStatus);
    _lookCurve = CurvedAnimation(
      parent: _look,
      curve: AppMotion.emphasizedDecelerate,
    );
    _sweep = AnimationController(vsync: this, duration: _sweepTime);
    _success = AnimationController(vsync: this, duration: AppMotion.hero);
    _popCurve = CurvedAnimation(
      parent: _success,
      curve: const Interval(0, _popShare),
    );
    _pop = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: _popScale,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: _popScale,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
      ),
    ]).animate(_popCurve);
    _press = AnimationController.unbounded(vsync: this, value: 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickersOn = TickerMode.of(context);
    _reduced = AppMotion.reduced(context);
    if (_reduced) {
      // Whatever is moving when the user asks for less motion ends now.
      if (_look.isAnimating) _look.value = 1;
      if (_success.isAnimating) _success.value = 0;
    }
    _syncSweep();
    _art.resolve(context, widget.size, _artArrived);
  }

  @override
  void didUpdateWidget(PowerButton old) {
    super.didUpdateWidget(old);
    if (widget.size != old.size) {
      _art.resolve(context, widget.size, _artArrived);
    }
    final face = _face;
    if (face != _shown) {
      final was = _shown;
      _shown = face;
      // From wherever the colors are now, so a change in the middle of a
      // change carries on smoothly.
      _from = _Look.lerp(_from, _to, _lookCurve.value);
      _to = _Look.of(face);
      if (_reduced) {
        _look.value = 1;
      } else {
        _look.forward(from: 0);
      }
      if (_celebrates(was, face)) {
        _success.forward(from: 0);
        AppHaptics.success();
      }
    }
    // A press held while the tunnel starts coming down gets no tap up: the
    // gesture handlers are gone. Let the button out.
    if (!_tappable && _pressIn != null) _releasePress();
    _syncSweep();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isAway(state)) {
      _away = true;
      _trips++;
    } else if (state == AppLifecycleState.resumed && _away) {
      // Back in front. The next frame still handles what changed while
      // the app was away, so clear the flag only after it.
      final trip = _trips;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (trip == _trips) _away = false;
      });
    }
  }

  static bool _isAway(AppLifecycleState? state) => switch (state) {
    AppLifecycleState.hidden ||
    AppLifecycleState.paused ||
    AppLifecycleState.detached => true,
    _ => false,
  };

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _art.dispose();
    _lookCurve.dispose();
    _popCurve.dispose();
    _look.dispose();
    _sweep.dispose();
    _success.dispose();
    _press.dispose();
    super.dispose();
  }

  /// A picture finished decoding after the button was built.
  void _artArrived() {
    if (mounted) setState(() {});
  }

  PowerFace get _face =>
      widget.face ??
      powerFaceFor(widget.status, isVerifying: widget.isVerifying);

  bool get _busy => _isBusy(_shown);

  static bool _isBusy(PowerFace face) => switch (face) {
    PowerFace.connecting ||
    PowerFace.verifying ||
    PowerFace.disconnecting => true,
    _ => false,
  };

  /// Taps reach [PowerButton.onTap] in every state except one. A tap while
  /// connecting or checking is how the user stops, so it must land. Until
  /// 2026-10-07 the button ignored every tap while busy, and a user on
  /// "Checking connection" could only wait. Taps are ignored only while the
  /// tunnel is coming down, so a double tap cannot start a connect over a
  /// stop.
  bool get _tappable => widget.status != VpnStatus.disconnecting;

  /// The success moment plays for a connect the user watched land: from
  /// connecting or checking to connected, while the button is on screen
  /// and the app is in front. Never on the first build, so an app opened
  /// already connected stays calm, never when the connection came back by
  /// itself ([PowerButton.celebrate]), and never for a connect that landed
  /// while the app was in the background.
  bool _celebrates(PowerFace was, PowerFace now) {
    if (now != PowerFace.connected) return false;
    if (was != PowerFace.connecting && was != PowerFace.verifying) {
      return false;
    }
    if (!widget.celebrate || _reduced || !_tickersOn || _away) return false;
    final life = WidgetsBinding.instance.lifecycleState;
    return life == null || life == AppLifecycleState.resumed;
  }

  void _lookStatus(AnimationStatus status) {
    // The light keeps sweeping while it fades out; stop it once it has.
    if (status == AnimationStatus.completed) _syncSweep();
  }

  /// Runs the sweep only while it is seen: busy, or fading out after busy,
  /// with tickers on and full motion. Idle and connected schedule nothing.
  void _syncSweep() {
    final fading = _look.isAnimating && _from.sweep > 0;
    final run = (_busy || fading) && _tickersOn && !_reduced;
    if (run && !_sweep.isAnimating) {
      _sweep.repeat();
    } else if (!run && _sweep.isAnimating) {
      _sweep.stop();
    }
  }

  void _pressDown() {
    _pressCount++;
    _pressIn = _press.animateTo(
      _pressedScale,
      duration: AppMotion.instant,
      curve: AppMotion.standard,
    );
  }

  /// Springs the button back out once the dip has reached the bottom, so
  /// even the quickest tap shows its press.
  void _releasePress() {
    final dip = _pressIn;
    _pressIn = null;
    final count = _pressCount;
    void out() {
      if (!mounted || count != _pressCount) return;
      if (_reduced) {
        _press.animateTo(
          1,
          duration: AppMotion.fast,
          curve: AppMotion.standard,
        );
      } else {
        _press.animateWith(
          SpringSimulation(_springBack, _press.value, 1, _press.velocity),
        );
      }
    }

    if (dip != null && _press.isAnimating) {
      dip.whenCompleteOrCancel(out);
    } else {
      out();
    }
  }

  void _tapUp() {
    _releasePress();
    AppHaptics.tap();
    widget.onTap();
  }

  /// A press from a TV remote's centre button: the same as a tap, with the
  /// same dip, since the remote gives no tap down and up to animate.
  void _activate() {
    if (!_tappable) return;
    _pressDown();
    _tapUp();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    // Focusable while the tunnel comes down too, when presses are ignored:
    // a control that stops being focusable loses the remote's focus, and
    // the remote is left pointing at nothing.
    return FocusRingCircle(
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: Semantics(
          button: true,
          enabled: _tappable,
          label: widget.semanticLabel,
          hint: widget.semanticHint,
          child: GestureDetector(
            // The whole square takes the tap, the corners beside the
            // shield included: reaching the control should take no aim.
            behavior: HitTestBehavior.opaque,
            onTapDown: _tappable ? (_) => _pressDown() : null,
            onTapUp: _tappable ? (_) => _tapUp() : null,
            onTapCancel: _tappable ? _releasePress : null,
            child: ScaleTransition(
              scale: _press,
              child: SizedBox.square(
                dimension: size,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Two layers of their own. The light sweeps sixty times
                    // a second while connecting; the shield under it and
                    // the rest of the screen are not drawn again with it.
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: _ShieldPainter(
                          art: _art.snapshot,
                          look: _lookCurve,
                          from: _from,
                          to: _to,
                          success: _success,
                          pop: _pop,
                        ),
                      ),
                    ),
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: _SweepPainter(
                          art: _art.snapshot,
                          look: _lookCurve,
                          from: _from,
                          to: _to,
                          sweep: _sweep,
                          still: _reduced,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where things are on the pictures that tool/hero_art.py draws. All four
/// share one canvas: the shield's box in the app icon, with room round it
/// for the halo. Places are in the icon's pixels, on that canvas.
///
/// The tool prints the canvas, the shield's height, the left eye's outer
/// end and the middle when it runs. Tests check the files' shape and where
/// the eyes are drawn.
abstract final class _Art {
  static const String shield = 'assets/hero/shield.webp';
  static const String eyes = 'assets/hero/eyes.png';
  static const String glow = 'assets/hero/glow.png';
  static const String halo = 'assets/hero/halo.png';

  static const double width = 912;
  static const double height = 1128;

  /// The shield's height. It is centred on the canvas.
  static const double shieldHeight = 908;

  /// How much of the button's side the shield's height takes.
  static const double shieldShare = 0.94;

  /// The line the busy light follows: from the left eye's outer end,
  /// along the eye and down to the middle under the nose guard, and up the
  /// right eye, which mirrors the left. The eyes slope 15 degrees.
  static const Offset _outerEnd = Offset(313.7, 558.1);
  static const double _middle = 455.5;
  static const double _slope = 0.2679;

  /// The busy light's reach, most of an eye.
  static const double spotRadius = 88;

  /// Logical pixels per canvas pixel in a button [side] wide.
  static double scale(double side) => side * shieldShare / shieldHeight;

  /// The canvas in a button of [size], centred.
  static Rect box(Size size) {
    final k = scale(size.shortestSide);
    return Rect.fromCenter(
      center: size.center(Offset.zero),
      width: width * k,
      height: height * k,
    );
  }

  /// The point on the light's line [t] of the way from the left eye's
  /// outer end (0) to the right eye's (1), on the canvas. Physical: a
  /// right to left language sweeps the same way.
  static Offset along(double t) {
    final half = _middle - _outerEnd.dx;
    final x = _outerEnd.dx + t * 2 * half;
    return Offset(x, _outerEnd.dy + (half - (x - _middle).abs()) * _slope);
  }

  /// Both eyes, with room for the light round them, on the canvas.
  static Rect get eyesBox => Rect.fromLTRB(
    _outerEnd.dx - spotRadius,
    _outerEnd.dy - spotRadius,
    2 * _middle - _outerEnd.dx + spotRadius,
    along(0.5).dy + spotRadius,
  );

  /// The pictures, in the order [_ArtImages] keeps them. The sharp ones
  /// are decoded at the size a button [side] wide draws them on the screen
  /// of [context], and never larger than the file; the soft ones are small
  /// files, drawn larger. The splash screen's [PowerButton.precache] and
  /// the button ask with the same sizes, so the button finds them cached.
  static List<ImageProvider> images(BuildContext context, double side) {
    final pixels = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final drawn = (width * scale(side) * pixels).ceil();
    return [
      ResizeImage(const AssetImage(shield), width: drawn),
      ResizeImage(const AssetImage(eyes), width: drawn),
      const AssetImage(glow),
      const AssetImage(halo),
    ];
  }
}

/// The button's pictures, as they come from the image cache. Each is null
/// until it has decoded, and the painters draw only what they have, so a
/// button built before the splash screen's [PowerButton.precache] finished
/// shows the shield a frame or two late rather than not at all.
class _ArtImages {
  final List<ImageStream?> _streams = List.filled(4, null);
  final List<ImageStreamListener?> _listeners = List.filled(4, null);
  final List<ui.Image?> _images = List.filled(4, null);

  _ArtSnapshot get snapshot => (
    shield: _images[0],
    eyes: _images[1],
    glow: _images[2],
    halo: _images[3],
  );

  void resolve(BuildContext context, double side, VoidCallback arrived) {
    final config = createLocalImageConfiguration(context);
    final providers = _Art.images(context, side);
    for (var i = 0; i < providers.length; i++) {
      final stream = providers[i].resolve(config);
      if (stream.key == _streams[i]?.key) continue;
      final listener = ImageStreamListener((info, synchronous) {
        // The listener owns the image it is handed.
        _images[i]?.dispose();
        _images[i] = info.image;
        // A cached picture comes while the button builds, which draws it.
        if (!synchronous) arrived();
      });
      final old = _listeners[i];
      if (old != null) _streams[i]?.removeListener(old);
      _streams[i] = stream;
      _listeners[i] = listener;
      stream.addListener(listener);
    }
  }

  void dispose() {
    for (var i = 0; i < _streams.length; i++) {
      final listener = _listeners[i];
      if (listener != null) _streams[i]?.removeListener(listener);
      _images[i]?.dispose();
      _images[i] = null;
    }
  }
}

typedef _ArtSnapshot = ({
  ui.Image? shield,
  ui.Image? eyes,
  ui.Image? glow,
  ui.Image? halo,
});

/// How the pictures are sampled: smoothly, without mipmaps. The shield is
/// decoded at the size it is drawn and the light is soft, so neither needs
/// them, and with them Android's renderer drew a thin line of the light's
/// color along the picture's edges (seen on the emulator, 2026-10-24).
const FilterQuality _sampling = FilterQuality.low;

/// Draws [image] over [box], with its opacity as the opacity of [color].
/// The light pictures are white; this tints them.
void _drawTinted(
  Canvas canvas,
  ui.Image? image,
  Rect box,
  Color color, {
  BlendMode blend = BlendMode.srcOver,
}) {
  if (image == null || color.a == 0) return;
  canvas.drawImageRect(
    image,
    Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
    box,
    Paint()
      ..filterQuality = _sampling
      ..blendMode = blend
      ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn),
  );
}

/// The colors of one face of the button. Each is tweened on its own, so a
/// change of face is one smooth crossfade of halo, light and eyes.
@immutable
class _Look {
  const _Look({
    required this.halo,
    required this.glow,
    required this.eyes,
    required this.sweep,
    required this.muted,
  });

  /// The light round the shield. Fully transparent for none.
  final Color halo;

  /// The eyes' light, added over the inside of the visor and the steel
  /// round it, as light adds. Its opacity is its strength.
  final Color glow;

  /// The eyes themselves.
  final Color eyes;

  /// How strongly the busy light sweeps, 0 to 1.
  final double sweep;

  /// How far the shield is greyed and dimmed, 0 to 1.
  final double muted;

  /// None, in the steel hue, so a fade to none never passes through grey.
  static final Color _none = AppDesign.steelLight.withValues(alpha: 0);

  /// The heart of a lit eye: its color, most of the way to white.
  static Color _hot(Color color) => Color.lerp(color, Colors.white, 0.72)!;

  static _Look of(PowerFace face) {
    switch (face) {
      case PowerFace.off:
        return _Look(halo: _none, glow: _none, eyes: _none, sweep: 0, muted: 0);
      case PowerFace.connecting:
      case PowerFace.verifying:
      case PowerFace.disconnecting:
        // Steel, half asleep: the light that sweeps over them is what says
        // the button is at work.
        return _Look(
          halo: AppDesign.steelLight.withValues(alpha: 0.06),
          glow: AppDesign.steelHighlight.withValues(alpha: 0.24),
          eyes: AppDesign.steelHighlight.withValues(alpha: 0.42),
          sweep: 1,
          muted: 0,
        );
      case PowerFace.stalled:
        return _Look(
          halo: AppDesign.warning.withValues(alpha: 0.14),
          glow: AppDesign.warning.withValues(alpha: 0.6),
          eyes: _hot(AppDesign.warning).withValues(alpha: 0.9),
          sweep: 0,
          muted: 0,
        );
      case PowerFace.failed:
        return _Look(
          halo: AppDesign.error.withValues(alpha: 0.14),
          glow: AppDesign.error.withValues(alpha: 0.6),
          eyes: _hot(AppDesign.error).withValues(alpha: 0.9),
          sweep: 0,
          muted: 0,
        );
      case PowerFace.spent:
        // Greyed, but plain to see: the button still takes taps here (each
        // one opens the limit sheet).
        return _Look(halo: _none, glow: _none, eyes: _none, sweep: 0, muted: 1);
      case PowerFace.connected:
        return _Look(
          halo: AppDesign.protected.withValues(alpha: 0.42),
          glow: AppDesign.protected,
          eyes: _hot(AppDesign.protected),
          sweep: 0,
          muted: 0,
        );
    }
  }

  static _Look lerp(_Look a, _Look b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    Color c(Color x, Color y) => Color.lerp(x, y, t)!;
    return _Look(
      halo: c(a.halo, b.halo),
      glow: c(a.glow, b.glow),
      eyes: c(a.eyes, b.eyes),
      sweep: a.sweep + (b.sweep - a.sweep) * t,
      muted: a.muted + (b.muted - a.muted) * t,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _Look &&
      other.halo == halo &&
      other.glow == glow &&
      other.eyes == eyes &&
      other.sweep == sweep &&
      other.muted == muted;

  @override
  int get hashCode => Object.hash(halo, glow, eyes, sweep, muted);
}

/// Paints the shield and everything on it that holds still: the halo, the
/// shield, the eyes and their light, and the success moment. Repaints only
/// while the colors change or the success moment plays.
///
/// Every soft light is a picture drawn ahead by tool/hero_art.py and only
/// tinted here; nothing is blurred on the phone, for low-end phones. The
/// halo and the ripple reach outside the button's box, which only paints
/// there: the box, the hit area and the focus ring stay the button's size.
class _ShieldPainter extends CustomPainter {
  _ShieldPainter({
    required this.art,
    required this.look,
    required this.from,
    required this.to,
    required this.success,
    required this.pop,
  }) : super(repaint: Listenable.merge([look, success]));

  final _ArtSnapshot art;
  final Animation<double> look;
  final _Look from;
  final _Look to;
  final Animation<double> success;
  final Animation<double> pop;

  /// How far the ripple grows past the halo.
  static const double _rippleGrowth = 0.22;

  @override
  void paint(Canvas canvas, Size size) {
    final shield = art.shield;
    if (shield == null) return;
    final l = _Look.lerp(from, to, look.value);
    final box = _Art.box(size);
    final s = success.value;
    final celebrating = s > 0 && s < 1;

    _drawTinted(canvas, art.halo, box, l.halo);
    if (celebrating) _paintRipple(canvas, box, s);

    canvas.save();
    final c = box.center;
    canvas
      ..translate(c.dx, c.dy)
      ..scale(pop.value)
      ..translate(-c.dx, -c.dy);
    canvas.drawImageRect(
      shield,
      Offset.zero & Size(shield.width.toDouble(), shield.height.toDouble()),
      box,
      Paint()
        ..filterQuality = _sampling
        ..colorFilter = l.muted > 0 ? _mutedFilter(l.muted) : null,
    );
    _drawTinted(canvas, art.glow, box, l.glow, blend: BlendMode.plus);
    _drawTinted(canvas, art.eyes, box, l.eyes);
    if (celebrating) _paintFlash(canvas, box, s);
    canvas.restore();
  }

  /// A wave of green light that leaves the shield's edge and fades as it
  /// grows.
  void _paintRipple(Canvas canvas, Rect box, double t) {
    final grown = 1 + _rippleGrowth * Curves.easeOutCubic.transform(t);
    final alpha = 0.6 * (1 - Curves.easeIn.transform(t));
    _drawTinted(
      canvas,
      art.halo,
      Rect.fromCenter(
        center: box.center,
        width: box.width * grown,
        height: box.height * grown,
      ),
      AppDesign.protected.withValues(alpha: alpha),
      blend: BlendMode.plus,
    );
  }

  /// The eyes coming on: they flash white and their light flares, then
  /// both settle into their green.
  void _paintFlash(Canvas canvas, Rect box, double t) {
    final f = 1 - Curves.easeOut.transform(t);
    _drawTinted(
      canvas,
      art.glow,
      box,
      AppDesign.protectedBright.withValues(alpha: 0.9 * f),
      blend: BlendMode.plus,
    );
    _drawTinted(canvas, art.eyes, box, Colors.white.withValues(alpha: f));
  }

  /// Grey by [m], and a third darker at full.
  static ColorFilter _mutedFilter(double m) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final keep = 1 - m;
    final dim = 1 - 0.35 * m;
    return ColorFilter.matrix(<double>[
      (r * m + keep) * dim, g * m * dim, b * m * dim, 0, 0, //
      r * m * dim, (g * m + keep) * dim, b * m * dim, 0, 0, //
      r * m * dim, g * m * dim, (b * m + keep) * dim, 0, 0, //
      0, 0, 0, 1, 0,
    ]);
  }

  @override
  bool shouldRepaint(_ShieldPainter old) =>
      old.art != art ||
      old.from != from ||
      old.to != to ||
      old.look != look ||
      old.success != success ||
      old.pop != pop;
}

/// Paints the busy light: a steel glow that sweeps from eye to eye and
/// back, lighting each eye as it passes and the inside of the visor round
/// it. The only thing that moves while connecting.
class _SweepPainter extends CustomPainter {
  _SweepPainter({
    required this.art,
    required this.look,
    required this.from,
    required this.to,
    required this.sweep,
    required this.still,
  }) : super(repaint: Listenable.merge([look, sweep]));

  final _ArtSnapshot art;
  final Animation<double> look;
  final _Look from;
  final _Look to;
  final Animation<double> sweep;

  /// Reduce motion: no sweep, both eyes evenly lit instead.
  final bool still;

  /// The light is drawing only. Taps pass through it to the button.
  @override
  bool? hitTest(Offset position) => false;

  @override
  void paint(Canvas canvas, Size size) {
    final strength = _Look.lerp(from, to, look.value).sweep;
    final glow = art.glow;
    final eyes = art.eyes;
    if (strength <= 0 || glow == null || eyes == null) return;
    final box = _Art.box(size);
    final k = box.width / _Art.width;
    Offset onScreen(Offset p) => box.topLeft + p * k;

    // The light, kept to where the eyes and their glow are, and added over
    // what is under it.
    final Rect area;
    final Paint mask;
    if (still) {
      final b = _Art.eyesBox;
      area = Rect.fromPoints(onScreen(b.topLeft), onScreen(b.bottomRight));
      mask = Paint()
        ..blendMode = BlendMode.dstIn
        ..color = Colors.white.withValues(alpha: 0.5 * strength);
    } else {
      // Slow at each end and quickest between the eyes, like a look from
      // side to side.
      final t = (1 - math.cos(2 * math.pi * sweep.value)) / 2;
      area = Rect.fromCircle(
        center: onScreen(_Art.along(t)),
        radius: _Art.spotRadius * k,
      );
      mask = Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: strength),
            Colors.white.withValues(alpha: 0.8 * strength),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(area);
    }
    // The light is cut to the area, and the mask reaches a little past the
    // cut: a mask cut at the same edge left a faint box round the light,
    // where the edge pixels kept part of the light unmasked.
    final bounds = area.inflate(2);
    canvas
      ..saveLayer(bounds, Paint()..blendMode = BlendMode.plus)
      ..save()
      ..clipRect(area);
    _drawTinted(canvas, glow, box, AppDesign.steelHighlight);
    _drawTinted(canvas, eyes, box, Colors.white);
    canvas
      ..restore()
      ..drawRect(bounds, mask)
      ..restore();
  }

  @override
  bool shouldRepaint(_SweepPainter old) =>
      old.art != art ||
      old.from != from ||
      old.to != to ||
      old.still != still ||
      old.look != look ||
      old.sweep != sweep;
}
