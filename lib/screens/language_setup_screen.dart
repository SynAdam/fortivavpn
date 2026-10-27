import 'package:flutter/material.dart';

import '../core/design_system.dart';
import '../core/haptics.dart';
import '../core/state/locale_state.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/language_picker.dart';

/// The language question, asked once, before anything else.
///
/// Deliberately almost wordless. This is the one screen that cannot rely
/// on the user reading the interface language, because choosing it is the
/// whole point. So the only prose is the word "Language" in a handful of
/// scripts, and everything else is the list itself, each name written in
/// its own language.
///
/// One row starts selected, chosen from the phone's region and then its
/// language. Someone in Iran with an English phone lands on Persian
/// already highlighted and can continue without reading a word of
/// English.
class LanguageSetupScreen extends StatefulWidget {
  final LocaleState localeState;

  /// The language to start on, from [LocaleState.suggestedLanguage].
  final String suggested;

  /// Called once the user has settled on a language.
  final VoidCallback onDone;

  const LanguageSetupScreen({
    super.key,
    required this.localeState,
    required this.suggested,
    required this.onDone,
  });

  /// Whether this screen showed in this run of the app: the first launch.
  /// That run is for the first connect, so the home screen keeps the
  /// introduction to the invite tree for a later run.
  static bool get shownThisRun => _shownThisRun;
  static bool _shownThisRun = false;

  @visibleForTesting
  static set shownThisRunForTest(bool value) => _shownThisRun = value;

  @override
  State<LanguageSetupScreen> createState() => _LanguageSetupScreenState();
}

class _LanguageSetupScreenState extends State<LanguageSetupScreen> {
  late String _selected = widget.suggested;

  @override
  void initState() {
    super.initState();
    LanguageSetupScreen._shownThisRun = true;
  }

  /// "Language" in the scripts this app serves, so the heading means
  /// something whichever of them the reader knows.
  static const List<String> _headings = [
    'Language',
    'زبان',
    'اللغة',
    'Dil',
    'Язык',
    '言語',
  ];

  Future<void> _confirm() async {
    // Persisted even when the suggestion was accepted unchanged: taking
    // the offer is still a choice, and it has to stop this screen coming
    // back on the next launch.
    await widget.localeState.setLocale(Locale(_selected));
    widget.onDone();
  }

  void _pick(String code) {
    if (code == _selected) return;
    AppHaptics.selection();
    setState(() => _selected = code);
  }

  @override
  Widget build(BuildContext context) {
    // The arrow's name for a screen reader, in the language being chosen:
    // the one the user is reading the list in.
    final next = lookupS(Locale(_selected)).peerShareNext;

    return Scaffold(
      // The splash's color, which this screen follows on first run.
      backgroundColor: AppDesign.canvas,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: AppDesign.space32),
            const ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppDesign.surfaceLow,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: AppDesign.hairline),
                  ),
                ),
                child: SizedBox.square(
                  dimension: 64,
                  child: Icon(
                    Icons.language_rounded,
                    size: 30,
                    color: AppDesign.steelLight,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDesign.space16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Semantics(
                header: true,
                child: Text(
                  _headings.join('  ·  '),
                  textAlign: TextAlign.center,
                  // Six scripts on one line: the Latin type with the
                  // Persian one behind it for the Arabic letters, Persian's
                  // taller line so its marks are not cut, and no letter
                  // spacing, which would break the joins.
                  style: AppDesign.textThemeForLocale(const Locale('en'))
                      .bodyMedium
                      ?.copyWith(
                        color: AppDesign.textSecondary,
                        height: 1.7,
                        letterSpacing: 0,
                        fontFamilyFallback: const ['Vazirmatn'],
                      ),
                ),
              ),
            ),
            const SizedBox(height: AppDesign.space24),
            Expanded(
              child: LanguageList(
                selected: _selected,
                onPick: _pick,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDesign.space16,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _confirm,
                  // An arrow rather than a word, for the same reason the
                  // heading is six words long. It points the way the
                  // chosen language reads.
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 22,
                    semanticLabel: next,
                    textDirection: AppDesign.isRtlLocale(Locale(_selected))
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
