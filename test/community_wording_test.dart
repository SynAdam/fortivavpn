import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The text about community servers, the diagnostics switch and the row
/// about Android's block of connections without a VPN: in every language,
/// neutral, and with the disclosure's first sentence kept.
void main() {
  const keys = [
    'communityTabExplainer',
    'communityServerCaption',
    'shareDiagnosticsBody',
    'killSwitchTitle',
    'killSwitchSubtitle',
    'killSwitchSteps',
    'killSwitchUndo',
  ];
  Map<String, dynamic> read(String lang) =>
      jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
          as Map<String, dynamic>;
  final langs = [
    for (final f in Directory('lib/l10n').listSync().whereType<File>())
      if (RegExp(r'app_([a-z]+)\.arb$').firstMatch(f.path) case final m?)
        m.group(1)!,
  ]..sort();
  final en = read('en');

  test('there are 18 languages', () => expect(langs, hasLength(18)));

  for (final lang in langs) {
    test('[$lang] every key is there, translated, with none of the marks '
        'the app does not use', () {
      final arb = read(lang);
      for (final key in keys) {
        final value = arb[key];
        expect(value, isA<String>(), reason: key);
        if (lang != 'en') {
          expect(value, isNot(en[key]), reason: '$key is the English text');
        }
        for (final mark in [
          '\u2013',
          '\u2014',
          '\u2018',
          '\u2019',
          '\u201c',
          '\u201d',
          '\u2026',
        ]) {
          expect(
            (value as String).contains(mark),
            isFalse,
            reason: '$key has U+${mark.codeUnitAt(0).toRadixString(16)}',
          );
        }
      }
    });
  }

  test('the community text is calm and says who runs the servers', () {
    final fa = read('fa');
    for (final key in ['communityTabExplainer', 'communityServerCaption']) {
      final e = (en[key] as String).toLowerCase();
      for (final word in [
        'danger',
        'unsafe',
        'risk',
        'spy',
        'watch',
        'track',
        'steal',
        'harm',
        'see your',
        'safe',
      ]) {
        expect(e.contains(word), isFalse, reason: '$key: $word');
      }
      expect(e, contains('does not run'));
      final f = fa[key] as String;
      for (final word in [
        'خطر',
        'ناامن',
        'جاسوس',
        'ردیابی',
        'سرقت',
        'آسیب',
        'شنود',
        'می‌بینند',
      ]) {
        expect(f.contains(word), isFalse, reason: '$key: $word');
      }
      expect(f, contains('اداره'));
    }
  });

  test('the diagnostics text keeps its disclosure first and names the '
      'background tests', () {
    final body = en['shareDiagnosticsBody'] as String;
    expect(
      body,
      startsWith(
        'Sends connection reports, your carrier and country, phone model and '
        'Android version, where Google Play says you found the app, and '
        'whether you saw or tapped our messages, Premium offers and invite '
        'card.',
      ),
    );
    expect(body, contains('in the background'));
    expect(body, contains('Turning it off stops these tests'));
    final fa = read('fa')['shareDiagnosticsBody'] as String;
    expect(fa, contains('پس‌زمینه'));
    expect(fa, contains('سرورهای عمومی'));
  });

  test('the steps name the app as Android\'s VPN list shows it', () {
    // Android lists a VPN app by its label: the application's
    // android:label, which is app_name, the same in every language.
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      RegExp(
        r'<application[^>]*android:label="@string/app_name"',
      ).hasMatch(manifest),
      isTrue,
    );
    final strings = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();
    final label = RegExp(
      r'<string name="app_name"[^>]*>([^<]+)</string>',
    ).firstMatch(strings)!.group(1)!;
    expect(label, 'FortivaVPN');
    for (final lang in langs) {
      expect(read(lang)['killSwitchSteps'], contains(label), reason: lang);
    }
  });

  test('the row says in one sentence what Android can do', () {
    final sub = en['killSwitchSubtitle'] as String;
    expect(RegExp(r'[.!?]').allMatches(sub), hasLength(1));
    expect(sub, endsWith('.'));
  });
}
