import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Fortiva design system: "Forged Steel".
///
/// The colors come from the app icon, so the app and its icon read as one
/// thing: blue-black neutrals from the shield's outline, steel greys from
/// the shield, and the red-orange of the crest as the one brand color.
/// Brand marks actions, offers and Premium buying, never a connection
/// state. Protected green means the tunnel is up and working. The steps
/// between surfaces are tonal: a raised thing is a lighter surface rather
/// than a border, which keeps the dark screens calm.
///
/// Many old names (accentAmber, accentTeal, surfaceDark and others) are
/// kept as aliases of the new roles, so code that still uses one compiles
/// and gets the new color. In the app only accentTeal (the Premium pill,
/// which a test reads by name) and surfaceLight are still read. New code
/// uses the new names.
class AppDesign {
  AppDesign._();

  /// Whether the given locale uses a right-to-left script.
  static bool isRtlLocale(Locale? locale) {
    final code = locale?.languageCode ?? 'en';
    return code == 'ar' || code == 'fa' || code == 'ur';
  }

  /// Returns 0 for RTL locales to preserve Arabic cursive joining.
  static double adjustedLetterSpacing(double spacing, Locale? locale) {
    return isRtlLocale(locale) ? 0 : spacing;
  }

  /// The language the app is drawn in. The app root sets it from the locale
  /// it builds MaterialApp with, before the theme is built, so [textTheme]
  /// and [ls] follow the app's language at every call site without each one
  /// passing a locale. Tests that never set it get English.
  ///
  /// It is a plain static, so writing it rebuilds nothing. After a language
  /// switch a widget picks up the new font, line heights and spacing only
  /// when it rebuilds. Widgets that read S.of, Theme.of or NumberLocalizer
  /// depend on Localizations or the theme and rebuild on a switch; a widget
  /// that reads [textTheme] or [ls] and none of those keeps the old style
  /// until something else rebuilds it.
  ///
  /// Before the user has chosen a language, the app root works this out
  /// once from the phone's languages. If the phone's language changes
  /// while the app runs, MaterialApp follows it but this does not. The
  /// language is asked on first run, so that window is short.
  static Locale activeLocale = const Locale('en');

  /// [value] as a letter spacing, or 0 when the app is in an RTL language:
  /// spacing letters apart breaks the joins of Arabic script. Every
  /// explicit letterSpacing goes through this.
  static double ls(double value) => isRtlLocale(activeLocale) ? 0 : value;

  /// The font features for a number that changes in place (a timer, a
  /// reply time, an amount): tabular figures in Latin script, so the digits
  /// do not jump as they change, and none in an RTL language. Vazirmatn's
  /// tabular Persian digits sit in full-width cells, so "۱۱" showed as two
  /// separate ones and the ring-shaped zero left holes in "۰۰:۱۲".
  static List<FontFeature> get numberFeatures => isRtlLocale(activeLocale)
      ? const []
      : const [FontFeature.tabularFigures()];

  // =========================================================================
  // COLORS: neutrals. The blue-black of the icon's outline.
  // =========================================================================

  static const Color canvasDeep = Color(0xFF0A0E12);
  static const Color canvas = Color(0xFF0E1318);
  static const Color surfaceLow = Color(0xFF161B21);
  static const Color surface = Color(0xFF1B2127);
  static const Color surfaceHigh = Color(0xFF232930);
  static const Color surfaceHighest = Color(0xFF2C3239);
  static const Color surfaceBright = Color(0xFF363C43);

  /// Where two equal surfaces meet. Not an input or control edge.
  static const Color hairline = Color(0xFF252B31);
  static const Color outlineVariant = Color(0xFF30363C);

  /// Input borders and control edges. 3:1 or better only on canvas and
  /// canvasDeep (3.1 to 3.2:1). On surfaceLow, the input fill, it is 2.8:1,
  /// and it falls to 1.8:1 on surfaceBright. Do not rely on it alone as a
  /// 3:1 edge on surfaceLow or anything lighter.
  static const Color outline = Color(0xFF5C636A);

  /// Dark text and glyphs on light fills.
  static const Color ink = Color(0xFF0A0E12);

  /// The fill of an app bar over a page that scrolls under it: the page's
  /// own color at rest, and one step above the cards (surface) once
  /// something has scrolled under it, so a card that slides under the bar
  /// is cut by a change of tone rather than by a hard edge.
  ///
  /// A screen opts in on its own AppBar. The theme keeps canvas, because
  /// on a screen with a fixed header between the bar and its list, such
  /// as a search box, only the bar would change tone.
  static final WidgetStateColor appBarColor = WidgetStateColor.resolveWith(
    (states) => states.contains(WidgetState.scrolledUnder) ? surface : canvas,
  );

  // Old names for the neutrals.
  static const Color backgroundDark = canvasDeep;
  static const Color backgroundMain = canvas;
  static const Color surfaceDark = surfaceLow;
  static const Color surfaceMain = surface;
  static const Color surfaceLight = surfaceHigh;
  static const Color surfaceElevated = surfaceHighest;
  static const Color primaryDark = ink;
  static const Color primaryMain = surface;
  static const Color primaryLight = surfaceHighest;
  static const Color borderSubtle = hairline;
  static const Color borderDefault = outlineVariant;
  static const Color borderMuted = outline;

  // =========================================================================
  // COLORS: text
  // =========================================================================

  static const Color textPrimary = Color(0xFFEDF0F3);
  static const Color textSecondary = Color(0xFFB7BFC6);

  /// 5:1 or better on canvasDeep up to surfaceHigh (5.3 to 7.0:1). On
  /// surfaceHighest it is 4.7:1 and on surfaceBright 4.0:1, so small text
  /// in this color does not go on those two.
  static const Color textTertiary = Color(0xFF949CA3);
  static const Color textDisabled = Color(0xFF5E646A);

  // =========================================================================
  // COLORS: steel, the shield
  // =========================================================================

  static const Color steelHighlight = Color(0xFFEEF0F1);
  static const Color steelLight = Color(0xFFCDD1D6);
  static const Color steelMid = Color(0xFF8A9197);
  static const Color steelDark = Color(0xFF3D444B);
  static const Color steelDeep = Color(0xFF262C32);

  // =========================================================================
  // COLORS: brand, the crest. Primary actions, offers, Premium buying and
  // brand moments. Never a connection state, a warning or an error.
  // =========================================================================

  /// Filled buttons. White text on it is 4.8:1.
  static const Color brand = Color(0xFFC8452B);
  static const Color onBrand = Color(0xFFFFFFFF);

  /// Brand as text, an icon or a border on dark surfaces: 5.4 to 6.4:1 on
  /// canvasDeep up to surface, 4.9:1 on surfaceHigh, 4.3:1 on
  /// surfaceHighest and 3.7:1 on surfaceBright, so small text in it stays
  /// off the last two. Dark [ink] on it is 6.4:1; white on it is not
  /// readable.
  static const Color brandBright = Color(0xFFF26B4A);
  static const Color brandContainer = Color(0xFF3A1D17);
  static const Color onBrandContainer = Color(0xFFFDD4C6);

  // Old names: every amber use is now the crest's ember. White text on
  // accentAmber does not pass: use onBrand on brand, or ink on brandBright.
  static const Color accentAmber = brandBright;
  static const Color accentAmberDark = brand;
  static const Color accentAmberLight = Color(0xFFFF9478);
  static const Color textAccent = brandBright;

  // =========================================================================
  // COLORS: connection and status
  // =========================================================================

  /// Connected, protected, success, Premium on.
  static const Color protected = Color(0xFF6CD5B3);
  static const Color protectedBright = Color(0xFF9AE6CC);

  /// Protected's deep end, for a gradient.
  static const Color protectedDeep = Color(0xFF2E9C7C);

  /// Glyphs and text on protected fills.
  static const Color onProtected = Color(0xFF05201A);
  static const Color protectedContainer = Color(0xFF0F3329);

  // Old names. A test reads accentTeal by name.
  static const Color accentTeal = protected;
  static const Color accentTealLight = protectedBright;
  static const Color accentTealDark = protectedDeep;

  /// A fill that takes white on it (5:1).
  static const Color accentTealDeep = Color(0xFF1A7D63);
  static const Color success = protected;
  static const Color successLight = protectedBright;

  /// The state between off and connected is neutral steel, so only a
  /// working tunnel is green.
  static const Color connecting = steelLight;

  /// Stalled, Private DNS, slow ping.
  static const Color warning = Color(0xFFF0BE67);
  static const Color warningLight = Color(0xFFF6D493);
  static const Color warningContainer = Color(0xFF33280F);

  /// Always shown with an icon and words, never by color alone.
  static const Color error = Color(0xFFF37287);
  static const Color errorLight = Color(0xFFF89AA9);
  static const Color onError = Color(0xFF2A1216);
  static const Color errorContainer = Color(0xFF3D1B21);
  static const Color onErrorContainer = Color(0xFFFEDADD);

  static const Color info = Color(0xFF95C4E7);
  static const Color infoContainer = Color(0xFF15283A);

  // Tunnel status.
  static const Color statusActive = protected;
  static const Color statusEstablishing = connecting;
  static const Color statusInactive = steelMid;
  static const Color statusError = error;

  // Old names, kept as aliases. Nothing in the app reads them.
  static const Color statusConnected = statusActive;
  static const Color statusConnecting = statusEstablishing;
  static const Color statusDisconnected = statusInactive;
  static const Color accentCyan = accentTeal;
  static const Color accentCyanDark = accentTealDark;

  /// The chatbot glyph, on the chat's steel avatar ([chatbotGradient]) and
  /// on the home screen's chat button, which is a tonal disc (surfaceHigh
  /// to surface) rather than a steel one.
  static const Color onChatbot = steelLight;

  // Overlays.
  static const Color overlayDark = Color(0xCC05080B);
  static const Color overlayLight = Color(0x66000000);

  // =========================================================================
  // GRADIENTS
  // =========================================================================

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [surfaceHigh, surfaceLow],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFE0583A), brand],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient tealGradient = LinearGradient(
    colors: [protectedBright, protectedDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = tealGradient;

  /// The chat's avatar (ChatbotAvatar.steelDisc): a steel disc lit from
  /// above. The home screen's chat button draws its own tonal disc.
  static const LinearGradient chatbotGradient = LinearGradient(
    colors: [steelDark, steelDeep],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // =========================================================================
  // LATENCY. The phone's own measurement of a reply, shown as a color and
  // as signal bars. Every list and card reads these, so a ping looks the
  // same everywhere.
  // =========================================================================

  /// Below this a reply is quick: three bars, protected.
  static const int latencyGoodMs = 150;

  /// Below this a reply is usable: two bars, warning. At or above it: one
  /// bar, error.
  static const int latencyFairMs = 300;

  /// The color for a reply time of [ms]. Negative means no reply.
  static Color latencyColor(int ms) {
    if (ms < 0) return error;
    if (ms < latencyGoodMs) return protected;
    if (ms < latencyFairMs) return warning;
    return error;
  }

  /// How many of three signal bars a reply time of [ms] lights. 0 for no
  /// reply.
  static int latencyLevel(int ms) {
    if (ms < 0) return 0;
    if (ms < latencyGoodMs) return 3;
    if (ms < latencyFairMs) return 2;
    return 1;
  }

  // =========================================================================
  // FONT FAMILIES (locale-aware)
  // =========================================================================

  static String fontFamilyForLocale(Locale? locale) {
    final code = locale?.languageCode ?? 'en';
    switch (code) {
      case 'fa':
      case 'ar':
      case 'ur':
        return 'Vazirmatn';
      case 'hi':
        return 'NotoSansDevanagari';
      case 'ja':
      case 'ko':
      case 'zh':
        return '';
      default:
        return 'Inter';
    }
  }

  static List<String> fontFallbackForLocale(Locale? locale) {
    final primary = fontFamilyForLocale(locale);
    if (primary.isEmpty) return ['Inter'];
    if (primary == 'Inter') return [];
    return ['Inter'];
  }

  // =========================================================================
  // TYPOGRAPHY
  // =========================================================================

  /// Built once per language: [textTheme] is read at well over a hundred
  /// call sites on every build.
  static final Map<String, TextTheme> _textThemes = {};

  /// The type scale in the font of [locale]. Latin tracking follows Inter's
  /// own metrics, tighter as the size grows. Persian, Arabic and Urdu get
  /// no letter spacing (it breaks the joins) and taller lines, since their
  /// marks sit above and below the Latin line box.
  static TextTheme textThemeForLocale(Locale? locale) {
    final code = locale?.languageCode ?? 'en';
    return _textThemes.putIfAbsent(code, () => _buildTextTheme(locale));
  }

  static TextTheme _buildTextTheme(Locale? locale) {
    final family = fontFamilyForLocale(locale);
    final fallback = fontFallbackForLocale(locale);
    final rtl = isRtlLocale(locale);

    TextStyle style({
      required double size,
      required FontWeight weight,
      required double height,
      required double rtlHeight,
      required double tracking,
      required Color color,
    }) => TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: rtl ? rtlHeight : height,
      letterSpacing: rtl ? 0 : tracking,
    );

    return TextTheme(
      displayLarge: style(
        size: 48,
        weight: FontWeight.w600,
        height: 1.15,
        rtlHeight: 1.4,
        tracking: -1.0,
        color: textPrimary,
      ),
      displayMedium: style(
        size: 40,
        weight: FontWeight.w600,
        height: 1.15,
        rtlHeight: 1.4,
        tracking: -0.8,
        color: textPrimary,
      ),
      displaySmall: style(
        size: 34,
        weight: FontWeight.w600,
        height: 1.2,
        rtlHeight: 1.4,
        tracking: -0.6,
        color: textPrimary,
      ),
      headlineLarge: style(
        size: 30,
        weight: FontWeight.w600,
        height: 1.25,
        rtlHeight: 1.45,
        tracking: -0.6,
        color: textPrimary,
      ),
      headlineMedium: style(
        size: 26,
        weight: FontWeight.w600,
        height: 1.25,
        rtlHeight: 1.45,
        tracking: -0.5,
        color: textPrimary,
      ),
      headlineSmall: style(
        size: 22,
        weight: FontWeight.w600,
        height: 1.3,
        rtlHeight: 1.5,
        tracking: -0.35,
        color: textPrimary,
      ),
      titleLarge: style(
        size: 20,
        weight: FontWeight.w600,
        height: 1.3,
        rtlHeight: 1.5,
        tracking: -0.3,
        color: textPrimary,
      ),
      titleMedium: style(
        size: 16,
        weight: FontWeight.w600,
        height: 1.4,
        rtlHeight: 1.6,
        tracking: -0.15,
        color: textPrimary,
      ),
      titleSmall: style(
        size: 14,
        weight: FontWeight.w600,
        height: 1.4,
        rtlHeight: 1.6,
        tracking: -0.05,
        color: textSecondary,
      ),
      bodyLarge: style(
        size: 16,
        weight: FontWeight.w400,
        height: 1.5,
        rtlHeight: 1.75,
        tracking: -0.15,
        color: textPrimary,
      ),
      bodyMedium: style(
        size: 14,
        weight: FontWeight.w400,
        height: 1.45,
        rtlHeight: 1.7,
        tracking: -0.05,
        color: textSecondary,
      ),
      bodySmall: style(
        size: 12.5,
        weight: FontWeight.w400,
        height: 1.4,
        rtlHeight: 1.65,
        tracking: 0,
        color: textTertiary,
      ),
      labelLarge: style(
        size: 15,
        weight: FontWeight.w600,
        height: 1.3,
        rtlHeight: 1.5,
        tracking: -0.1,
        color: textPrimary,
      ),
      labelMedium: style(
        size: 13,
        weight: FontWeight.w600,
        height: 1.3,
        rtlHeight: 1.5,
        tracking: 0,
        color: textSecondary,
      ),
      labelSmall: style(
        size: 11.5,
        weight: FontWeight.w600,
        height: 1.25,
        rtlHeight: 1.45,
        tracking: 0.2,
        color: textTertiary,
      ),
    );
  }

  /// The type scale in the app's language ([activeLocale]).
  static TextTheme get textTheme => textThemeForLocale(activeLocale);

  // Monospace, for Latin-only machine text (codes, keys, versions). Never
  // for a translated string.
  static TextStyle get monospaceMedium => const TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.4,
  );

  static TextStyle get monospaceSmall => const TextStyle(
    fontFamily: 'monospace',
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: textTertiary,
    height: 1.3,
  );

  static TextStyle get monospaceLarge => const TextStyle(
    fontFamily: 'monospace',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: protected,
    height: 1.4,
  );

  // =========================================================================
  // SPACING: the 4dp grid. Prefer 4, 8, 12, 16, 20, 24 and 32.
  // =========================================================================

  static const double space2 = 2.0;
  static const double space4 = 4.0;

  /// Only for the gap between an icon and its text.
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space28 = 28.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space64 = 64.0;

  // =========================================================================
  // BORDER RADIUS. Cards and grouped lists radiusLarge; rows, inputs and
  // tiles radiusMedium; dialogs and sheets radiusXLarge; chips and pills
  // radiusFull.
  // =========================================================================

  static const double radiusXSmall = 6.0;
  static const double radiusSmall = 10.0;
  static const double radiusMedium = 14.0;
  static const double radiusLarge = 20.0;
  static const double radiusXLarge = 28.0;
  static const double radiusFull = 999.0;

  static BorderRadius get borderRadiusXSmall =>
      BorderRadius.circular(radiusXSmall);
  static BorderRadius get borderRadiusSmall =>
      BorderRadius.circular(radiusSmall);
  static BorderRadius get borderRadiusMedium =>
      BorderRadius.circular(radiusMedium);
  static BorderRadius get borderRadiusLarge =>
      BorderRadius.circular(radiusLarge);
  static BorderRadius get borderRadiusXLarge =>
      BorderRadius.circular(radiusXLarge);

  // =========================================================================
  // SHADOWS & ELEVATION. Elevation is tonal: a raised thing is one surface
  // step lighter. Shadows are for things that float over content.
  // =========================================================================

  static List<BoxShadow> get shadowSmall => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.24),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get shadowMedium => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.32),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get shadowLarge => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.40),
      blurRadius: 28,
      offset: const Offset(0, 12),
    ),
  ];

  /// A soft brand glow, for a brand moment.
  static List<BoxShadow> get shadowGlow => [
    BoxShadow(color: brand.withValues(alpha: 0.22), blurRadius: 24),
  ];

  /// The protected glow.
  static List<BoxShadow> get shadowGlowTeal => [
    BoxShadow(color: protected.withValues(alpha: 0.26), blurRadius: 32),
  ];

  static List<BoxShadow> get shadowGlowSuccess => shadowGlowTeal;

  /// A plain shadow with no colored glow, so a chat button never reads as
  /// a connection state. Nothing uses it now: the home chat button takes
  /// [shadowMedium] directly. Kept so the old name still builds.
  static List<BoxShadow> get shadowGlowChatbot => shadowMedium;

  // =========================================================================
  // SYSTEM BARS
  // =========================================================================

  /// The app draws edge to edge: both system bars are transparent with
  /// light icons, so the canvas runs under them. Android must not add its
  /// own scrim behind the bars, which would show as a grey strip.
  static const SystemUiOverlayStyle systemBars = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  /// [padding] with the navigation bar's height added at the bottom, for a
  /// list that scrolls to the bottom of a screen.
  ///
  /// The app draws under the navigation bar, and a Scaffold with no bottom
  /// bar leaves that height in MediaQuery. A ListView adds it on its own
  /// only when it is given no padding at all, so a list with its own
  /// padding needs this, or its last row ends behind the bar where it
  /// cannot be tapped. The value is 0 while the keyboard is up, because the
  /// keyboard covers the bar.
  static EdgeInsets clearOfNavBar(BuildContext context, EdgeInsets padding) =>
      padding.copyWith(
        bottom: padding.bottom + MediaQuery.paddingOf(context).bottom,
      );

  // =========================================================================
  // THEME DATA
  // =========================================================================

  static ThemeData darkThemeForLocale(Locale? locale) {
    final text = textThemeForLocale(locale);
    final rtl = isRtlLocale(locale);

    // Every role is set, so nothing falls back to Material's own purple or
    // to white outlines.
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: brand,
      onPrimary: onBrand,
      primaryContainer: brandContainer,
      onPrimaryContainer: onBrandContainer,
      secondary: steelLight,
      onSecondary: ink,
      secondaryContainer: surfaceHighest,
      onSecondaryContainer: textPrimary,
      tertiary: protected,
      onTertiary: onProtected,
      tertiaryContainer: protectedContainer,
      onTertiaryContainer: protectedBright,
      error: error,
      onError: onError,
      errorContainer: errorContainer,
      onErrorContainer: onErrorContainer,
      surface: canvas,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      surfaceDim: canvasDeep,
      surfaceBright: surfaceBright,
      surfaceContainerLowest: canvasDeep,
      surfaceContainerLow: surfaceLow,
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHighest,
      outline: outline,
      outlineVariant: outlineVariant,
      inverseSurface: textPrimary,
      onInverseSurface: ink,
      inversePrimary: brandBright,
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );

    final buttonText = text.labelLarge;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMedium + 2),
    );
    const buttonSize = Size(64, 52);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 14);
    // A disabled fill a step above the dialog's surfaceHigh, so a button
    // that waits for input still reads as a button in a dialog as well as
    // on the canvas.
    final filled = FilledButton.styleFrom(
      backgroundColor: brand,
      foregroundColor: onBrand,
      disabledBackgroundColor: surfaceBright,
      disabledForegroundColor: textDisabled,
      elevation: 0,
      minimumSize: buttonSize,
      padding: buttonPadding,
      shape: buttonShape,
      textStyle: buttonText,
    );

    final inputShape = BorderRadius.circular(radiusMedium);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,

      // A plain ripple, not Material's sparkle, and no grey highlight
      // under it.
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.white.withValues(alpha: 0.08),
      hoverColor: Colors.white.withValues(alpha: 0.04),
      focusColor: Colors.white.withValues(alpha: 0.10),

      cardTheme: CardThemeData(
        color: surfaceLow,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: borderRadiusLarge),
      ),

      appBarTheme: AppBarThemeData(
        backgroundColor: canvas,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: text.titleLarge?.copyWith(
          fontSize: 18,
          letterSpacing: rtl ? 0 : -0.2,
        ),
        iconTheme: const IconThemeData(color: textPrimary, size: 24),
        actionsIconTheme: const IconThemeData(color: textPrimary, size: 24),
        systemOverlayStyle: systemBars,
      ),

      filledButtonTheme: FilledButtonThemeData(style: filled),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: onBrand,
          disabledBackgroundColor: surfaceBright,
          disabledForegroundColor: textDisabled,
          elevation: 0,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          disabledForegroundColor: textDisabled,
          side: const BorderSide(color: outline, width: 1),
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brandBright,
          disabledForegroundColor: textDisabled,
          minimumSize: const Size(48, 48),
          textStyle: buttonText,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textSecondary,
          minimumSize: const Size(48, 48),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: borderRadiusXLarge),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(fontSize: 15),
        // 20, not the content's 24: the 8 it would take from the buttons'
        // width moves a long Arabic button label onto another line at 2.0
        // text, and the message dialog then no longer fits a 320 by 568
        // phone (message_widgets_test).
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusXLarge),
          ),
        ),
        dragHandleColor: steelDark,
        dragHandleSize: Size(36, 4),
        showDragHandle: false,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          final on = states.contains(WidgetState.selected);
          final color = on ? onBrand : steelMid;
          return states.contains(WidgetState.disabled)
              ? color.withValues(alpha: 0.5)
              : color;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          final on = states.contains(WidgetState.selected);
          final color = on ? brand : surfaceHighest;
          return states.contains(WidgetState.disabled)
              ? color.withValues(alpha: 0.5)
              : color;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : outline,
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        minVerticalPadding: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        side: const BorderSide(color: hairline),
        shape: const StadiumBorder(),
        labelStyle: text.labelMedium?.copyWith(color: textPrimary),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: steelLight,
        linearTrackColor: surfaceHighest,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 6,
        borderRadius: BorderRadius.circular(3),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: brand,
        thumbColor: brand,
        inactiveTrackColor: surfaceHighest,
        overlayColor: brand.withValues(alpha: 0.12),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceBright,
          borderRadius: borderRadiusSmall,
        ),
        textStyle: text.bodyMedium?.copyWith(fontSize: 13, color: textPrimary),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium + 2),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: hairline,
        thickness: 1,
        space: 1,
      ),

      // Without this a snackbar drew its text in the dark-on-light colour
      // Material picks for its own light background, while the call sites
      // give it a dark one, so "Premium is on" and the other messages were
      // dark text on a dark bar.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceBright,
        contentTextStyle: text.bodyMedium?.copyWith(color: textPrimary),
        actionTextColor: brandBright,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: borderRadiusMedium),
        insetPadding: const EdgeInsets.all(16),
      ),

      scrollbarTheme: const ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(steelDark),
        radius: Radius.circular(4),
        thickness: WidgetStatePropertyAll(4),
      ),

      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: surfaceLow,
        border: OutlineInputBorder(
          borderRadius: inputShape,
          borderSide: const BorderSide(color: outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputShape,
          borderSide: const BorderSide(color: outlineVariant, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputShape,
          borderSide: const BorderSide(color: steelLight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: inputShape,
          borderSide: const BorderSide(color: error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: inputShape,
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: inputShape,
          borderSide: const BorderSide(color: hairline, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: space16,
          vertical: 14,
        ),
        hintStyle: text.bodyMedium?.copyWith(fontSize: 15, color: textTertiary),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? brand
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(onBrand),
        side: const BorderSide(color: outline, width: 1.5),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? brand : textSecondary,
        ),
      ),

      textTheme: text,

      iconTheme: const IconThemeData(color: textPrimary, size: 24),
    );
  }

  static ThemeData get darkTheme => darkThemeForLocale(const Locale('en'));
}

/// Motion tokens. Durations step from a quick press to the hero's success
/// moment; the curves are Material 3's.
abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration quick = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration emphasized = Duration(milliseconds: 450);
  static const Duration hero = Duration(milliseconds: 700);

  static const Curve standard = Easing.standard;
  static const Curve emphasizedDecelerate = Easing.emphasizedDecelerate;
  static const Curve emphasizedAccelerate = Easing.emphasizedAccelerate;

  /// Whether the user asked the phone for less motion. False where no
  /// MediaQuery is above [context].
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
