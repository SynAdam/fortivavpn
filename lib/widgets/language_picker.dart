import 'package:flutter/material.dart';

import '../core/design_system.dart';
import '../core/form_factor.dart';
import '../core/haptics.dart';
import '../core/state/locale_state.dart';
import '../l10n/generated/app_localizations.dart';
import 'ui/pressable.dart';
import 'ui/sheet_handle.dart';

/// The list of languages, shown as a bottom sheet.
///
/// One implementation for every place that offers a language: the header
/// button on the home screen and the Settings row. Each name is written
/// in its own language, because a picker that lists "Persian" in English
/// is useless to the person who needs it most.
Future<void> showLanguagePicker(BuildContext context, LocaleState localeState) {
  final height = MediaQuery.sizeOf(context).height;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Taller than the default nine sixteenths, so most of the list shows
    // at once, and still short of the top so the sheet reads as a sheet.
    // These replace Material's own limits, so its 640 wide cap is set
    // again here: without it the sheet spans a whole TV or tablet.
    constraints: BoxConstraints(maxWidth: 640, maxHeight: height * 0.85),
    builder: (sheetContext) => _LanguageSheet(
      selected: localeState.locale?.languageCode,
      onPick: (code) {
        AppHaptics.selection();
        localeState.setLocale(Locale(code));
        Navigator.pop(sheetContext);
      },
    ),
  );
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet({required this.selected, required this.onPick});

  final String? selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final title = S.of(context)?.language;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          if (title != null) ...[
            Padding(
              // On the rows' start edge.
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 12),
              child: Semantics(
                header: true,
                child: Text(title, style: AppDesign.textTheme.titleLarge),
              ),
            ),
            // A clear edge under the title for the rows to scroll under,
            // in place of a row cut flat with nothing above it.
            const Divider(height: 1, thickness: 1, color: AppDesign.hairline),
          ],
          Flexible(
            child: LanguageList(
              selected: selected,
              onPick: onPick,
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// Every language the app speaks, one [LanguageOption] each, with the
/// [selected] one scrolled into view when the list first shows.
///
/// A column in a scroll view rather than a lazy list: the list is short,
/// and every row has to exist for the selected one to be scrolled to.
class LanguageList extends StatefulWidget {
  const LanguageList({
    super.key,
    required this.selected,
    required this.onPick,
    this.padding = EdgeInsets.zero,
  });

  /// The language code shown as chosen, or null for none.
  final String? selected;
  final ValueChanged<String> onPick;
  final EdgeInsetsGeometry padding;

  @override
  State<LanguageList> createState() => _LanguageListState();
}

class _LanguageListState extends State<LanguageList> {
  /// On the row selected when the list first showed, and kept there when
  /// the choice moves. A key that moved with the choice would move a row's
  /// element to the row just tapped, and the ripple of that tap would be
  /// dropped with the element it ran on.
  final _firstKey = GlobalKey();
  late final String? _first = widget.selected;

  @override
  void initState() {
    super.initState();
    // After the first layout, so the row has a place to scroll to. Once
    // only: a later tap must not pull the list away from the user's thumb.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _firstKey.currentContext;
      if (!mounted || row == null) return;
      Scrollable.ensureVisible(row, alignment: 0.5);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in LocaleState.supportedLanguages.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDesign.space4),
              child: LanguageOption(
                key: entry.key == _first ? _firstKey : null,
                code: entry.key,
                name: entry.value,
                isSelected: entry.key == widget.selected,
                onTap: () => widget.onPick(entry.key),
              ),
            ),
        ],
      ),
    );
  }
}

/// One language: its name in its own script and type, at the start edge of
/// the row whatever the app's direction, so the list reads as one column.
/// The rows are a flat list on the sheet, with no fill of their own: only
/// the chosen one is raised a tone, with an ember edge and a check.
class LanguageOption extends StatelessWidget {
  const LanguageOption({
    super.key,
    required this.code,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  final String code;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  static const double minHeight = 56;

  @override
  Widget build(BuildContext context) {
    final own = Locale(code);
    // The name's own language's type: its font, its line height, and no
    // letter spacing for the scripts that join.
    final style = AppDesign.textThemeForLocale(own).bodyLarge?.copyWith(
      color: AppDesign.textPrimary,
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
    );
    return Semantics(
      container: true,
      selected: isSelected,
      child: Pressable(
        onTap: onTap,
        // A TV remote starts on the language already picked for the user,
        // so the centre button takes it as it is.
        autofocus: FormFactor.isTv && isSelected,
        color: isSelected ? AppDesign.surfaceHigh : Colors.transparent,
        border: isSelected
            ? const BorderSide(color: AppDesign.brandBright, width: 1.5)
            : BorderSide.none,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      name,
                      // Each name runs in its own script's direction; the
                      // Align above keeps it at the app's start edge.
                      textDirection: AppDesign.isRtlLocale(own)
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      style: style,
                    ),
                  ),
                ),
              ),
              if (isSelected)
                const Padding(
                  padding: EdgeInsetsDirectional.only(start: 12),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppDesign.brandBright,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The header control that opens the picker.
///
/// Shows the current language code rather than a globe alone, so someone
/// who cannot read the interface can still see which language is on and
/// find their way out of the wrong one.
///
/// A small pill to look at, with a 48dp target: the button pads its own
/// hit area, as Material buttons do.
class LanguageButton extends StatelessWidget {
  final LocaleState localeState;

  const LanguageButton({super.key, required this.localeState});

  static const double pillHeight = 34;

  @override
  Widget build(BuildContext context) {
    final code = localeState.currentLocaleCode;
    return OutlinedButton(
      onPressed: () => showLanguagePicker(context, localeState),
      style: OutlinedButton.styleFrom(
        backgroundColor: AppDesign.surfaceLow,
        foregroundColor: AppDesign.textSecondary,
        side: const BorderSide(color: AppDesign.hairline),
        shape: const StadiumBorder(),
        minimumSize: const Size(48, pillHeight),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        tapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
      ),
      // The language's own name for a screen reader, in place of the code.
      child: Semantics(
        label: LocaleState.supportedLanguages[code] ?? code,
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, size: 16),
            const SizedBox(width: AppDesign.space6),
            Text(
              code.toUpperCase(),
              // Always left-to-right: this is a code, not prose, and in
              // an RTL layout a bare two-letter string flips into
              // nonsense.
              textDirection: TextDirection.ltr,
              style: AppDesign.textThemeForLocale(
                const Locale('en'),
              ).labelMedium?.copyWith(color: AppDesign.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
