import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';

/// Every translation has exactly the keys of app_en.arb.
///
/// A key missing from one language shows the English text on phones set
/// to that language, and nothing fails: gen-l10n falls back quietly. On
/// 2026-10-10 ten of the twelve files were 26 keys behind, most of them on
/// the connection diagnosis screen. This test keeps the files in step, and
/// keeps the picker, the generated delegate and the files naming the same
/// languages.
void main() {
  final en =
      jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, dynamic>;
  final enKeys = en.keys.where((k) => !k.startsWith('@')).toSet();
  final files =
      Directory('lib/l10n')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.arb'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final codes = {
    for (final f in files)
      RegExp(r'app_([a-z]+)\.arb$').firstMatch(f.path)!.group(1)!,
  };

  /// The placeholders a message uses: {amount}, {days, plural, ...}. A
  /// plural branch such as =1{once} or other{...} is not a placeholder.
  Set<String> placeholders(String message) {
    final withoutBranches = message.replaceAll(
      RegExp(r'(?:=\d+|zero|one|two|few|many|other)\s*\{'),
      ' ',
    );
    return {
      for (final m in RegExp(r'\{(\w+)\s*[,}]').allMatches(withoutBranches))
        m[1]!,
    };
  }

  test('the picker, the delegate and the files name the same languages', () {
    expect(LocaleState.supportedLanguages.keys.toSet(), codes);
    expect(
      LocaleState.supportedLocales.map((l) => l.languageCode).toSet(),
      codes,
    );
    expect(S.supportedLocales.map((l) => l.languageCode).toSet(), codes);
    expect(
      LocaleState.supportedLanguages.keys.toList(),
      LocaleState.supportedLocales.map((l) => l.languageCode).toList(),
      reason: 'the two lists in LocaleState are in a different order',
    );
  });

  test('every language name is written in its own script', () {
    for (final entry in LocaleState.supportedLanguages.entries) {
      expect(entry.value, isNotEmpty, reason: entry.key);
      expect(
        entry.value,
        isNot(matches(RegExp(r'[\u2013\u2014\u2018\u2019]'))),
        reason: entry.key,
      );
    }
    // Uzbek writes oʻ with the modifier letter, never an apostrophe.
    expect(LocaleState.supportedLanguages['uz'], contains('\u02bb'));
  });

  for (final file in files) {
    final name = file.path.split('/').last;
    final code = name.substring(4, name.length - 4);
    test('$name has exactly the keys of app_en.arb', () {
      final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(arb['@@locale'], code);
      final keys = arb.keys.where((k) => !k.startsWith('@')).toSet();
      final missing = enKeys.difference(keys).toList()..sort();
      final extra = keys.difference(enKeys).toList()..sort();
      expect(missing, isEmpty, reason: '$name is missing: $missing');
      expect(extra, isEmpty, reason: '$name has keys app_en.arb lacks: $extra');
      for (final key in enKeys) {
        final value = arb[key];
        expect(value, isA<String>(), reason: '$name $key');
        expect((value as String).trim(), isNotEmpty, reason: '$name $key');
        expect(
          placeholders(value),
          placeholders(en[key] as String),
          reason: '$name $key uses other placeholders than app_en.arb',
        );
      }
    });

    test('$name loads through the generated delegate', () async {
      final l10n = await S.delegate.load(Locale(code));
      expect(l10n.localeName, code);
    });
  }
}
