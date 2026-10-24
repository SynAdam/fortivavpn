import 'dart:async';

import 'package:flutter/material.dart';

import '../api/device_service.dart';
import '../core/design_system.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/number_localizer.dart';
import '../widgets/power_button.dart';

/// The first thing anyone sees.
///
/// Android's own launch screen is a fixed, system-drawn icon on a colour
/// (and on API 31+ its size is not ours to choose), so it can only ever be
/// a brief, plain moment. This is the screen that carries the brand: the
/// mark, the name, and the build, held just long enough to register and
/// then dissolved into the app.
///
/// It is time-boxed rather than tied to loading. Startup work is
/// fire-and-forget, so gating on it would mean a splash whose length
/// depended on network conditions, the opposite of feeling solid.
///
/// Everything here is still once the intro has played: the light behind
/// the mark is painted once, so the screen draws no frames while it holds.
class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const SplashScreen({super.key, required this.onFinished});

  /// How long the mark stays before the app fades in.
  static const Duration hold = Duration(milliseconds: 1900);

  /// How long the mark and the name take to arrive.
  static const Duration intro = Duration(milliseconds: 1100);

  /// The mark's side.
  static const double markSize = 112;

  /// The space between the wordmark's letters.
  static const double wordmarkSpacing = 6;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  String? _version;
  bool _motionChecked = false;

  late final Animation<double> _markScale;
  late final Animation<double> _markFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(vsync: this, duration: SplashScreen.intro);

    _markScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0, 0.7, curve: Curves.easeOutBack),
      ),
    );
    _markFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0, 0.45, curve: Curves.easeOut),
    );
    _textFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _intro,
            curve: const Interval(0.35, 0.9, curve: Curves.easeOutCubic),
          ),
        );

    _loadVersion();

    Future.delayed(SplashScreen.hold, () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionChecked) return;
    _motionChecked = true;
    // The home screen's power button is the shield in pictures. Decoded
    // while the mark holds, they are ready for the home screen's first
    // frame, so the button never arrives a moment after the rest.
    unawaited(PowerButton.precache(context));
    // With reduced motion the mark and the name are simply there. The hold
    // stays the same, so the app arrives at the same moment.
    if (AppMotion.reduced(context)) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  Future<void> _loadVersion() async {
    final v = await DeviceService().getAppVersion();
    if (mounted) setState(() => _version = v);
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);

    return Scaffold(
      // The same color as the native launch screen before it
      // (splashBackground in android/app/src/main/res/values/colors.xml),
      // so the hand-over from Android to Flutter shows no step.
      backgroundColor: AppDesign.canvas,
      body: Stack(
        children: [
          // A soft steel light behind the mark, so the flat dark does not
          // read cheap. Painted once; it does not move.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 0.9,
                  colors: [
                    AppDesign.steelMid.withValues(alpha: 0.12),
                    AppDesign.steelMid.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 5),
                  FadeTransition(
                    opacity: _markFade,
                    child: ScaleTransition(
                      scale: _markScale,
                      child: const _Mark(),
                    ),
                  ),
                  const SizedBox(height: AppDesign.space28),
                  FadeTransition(
                    opacity: _textFade,
                    child: SlideTransition(
                      position: _textSlide,
                      child: Column(
                        children: [
                          const _Wordmark(),
                          const SizedBox(height: AppDesign.space12),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDesign.space32,
                            ),
                            child: Text(
                              l10n?.splashTagline ??
                                  'Private access, wherever you are',
                              textAlign: TextAlign.center,
                              style: AppDesign.textTheme.bodyMedium?.copyWith(
                                color: AppDesign.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(flex: 6),
                  FadeTransition(
                    opacity: _textFade,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppDesign.space24),
                      // The version the user asked for, and the reason it
                      // is read from the build rather than written down: it
                      // used to live in the translation files and had been
                      // wrong for twenty releases.
                      child: Text(
                        _version == null
                            ? ''
                            : NumberLocalizer.localize(
                                '${l10n?.version ?? 'Version'} $_version',
                                context,
                              ),
                        style: AppDesign.textTheme.labelSmall?.copyWith(
                          color: AppDesign.textTertiary,
                          fontWeight: FontWeight.w500,
                          fontFeatures: AppDesign.numberFeatures,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The shield, straight on the dark: the mark file has no plate around it,
/// unlike the launcher icon.
class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    const size = SplashScreen.markSize;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Image.asset(
      'assets/icon/fortiva_mark.png',
      width: size,
      height: size,
      // Decoded at the size it is drawn, not the file's.
      cacheWidth: (size * dpr).round(),
      filterQuality: FilterQuality.medium,
      // The wordmark under it names the app for a screen reader.
      excludeFromSemantics: true,
      // If the asset ever goes missing, keep the space rather than show
      // Flutter's grey error box on the very first screen.
      errorBuilder: (context, error, stack) =>
          const SizedBox.square(dimension: size),
    );
  }
}

/// "FORTIVA" in spaced capitals.
///
/// It is the brand's name, written in Latin letters in every language, so
/// it keeps the Latin type and its spacing in Persian too: the rule that
/// drops letter spacing protects joined scripts, and these letters do not
/// join. It needs no padding to sit on the centre line: Flutter 3.38 puts
/// half of the spacing before each letter and half after it, so the text
/// box is already centred on its letters. A test reads the drawn pixels to
/// keep it that way.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Text(
      'FORTIVA',
      textDirection: TextDirection.ltr,
      style: AppDesign.textThemeForLocale(const Locale('en')).titleLarge
          ?.copyWith(
            color: AppDesign.textPrimary,
            fontWeight: FontWeight.w600,
            letterSpacing: SplashScreen.wordmarkSpacing,
          ),
    );
  }
}
