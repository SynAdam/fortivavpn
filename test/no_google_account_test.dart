import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app has no Google sign-in and no linked Google account. No text in
/// any of the 18 languages may say it has one: not "Google account", not
/// "sign in with Google", not "linked Google account". Google Play stays,
/// because payments, ratings and updates go through it.
void main() {
  final arbs = {
    for (final f in Directory('lib/l10n').listSync().whereType<File>())
      if (RegExp(r'app_(\w+)\.arb$').firstMatch(f.path) case final m?)
        m[1]!: jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
  };

  /// Each language's words for a Google account, for signing in or going
  /// on with Google, for a Google email address and for a Google account
  /// linked to the app. A Google Play account counts too.
  final accountWords = <String, RegExp>{
    'en': RegExp(
      r'Google( Play)? accounts?'
      r'|(sign|log)(s|ged|ging)?[ -]?(in|on) (with|to|through|using) Google'
      r'|Google (sign|log)[ -]?(in|on)'
      r'|(link|linked|connect|connected) (your |a |the )?Google'
      r'|continue (with|using) Google(?![ -]Play)'
      r'|Gmail|Google (e-?mail|address)',
      caseSensitive: false,
    ),
    'fa': RegExp(
      '(حساب|اکانت)(‌های| های|ها)?( کاربری)? (گوگل|Google)'
      '|(گوگل|Google) ?اکانت'
      '|(ورود|وارد شدن)( اختیاری)? (با|از طریق) (حساب( کاربری)? |اکانت )?'
      '(گوگل|Google)'
      '|با (حساب( کاربری)? |اکانت )?(گوگل|Google) وارد'
      '|ادامه (با|از طریق) (حساب |اکانت )?(گوگل|Google)(?! ?پلی| Play)'
      '|ج[یي]م[یي]ل',
    ),
    'ar': RegExp(
      'حساب(ك|ات|اتك)?( في| على| لدى)? (Google|جوجل|غوغل)'
      '|(تسجيل|سجّ?لوا|سجّ?ل) (ال)?دخول.{0,20}(Google|جوجل|غوغل)'
      '|(المتابعة|متابعة|تابع|استمر|الاستمرار) (باستخدام|مع|عبر) '
      '(Google|جوجل|غوغل)(?! Play| بلاي)'
      '|(Google|جوجل|غوغل) مرتبط|جي ?ميل',
    ),
    'de': RegExp(
      'Google[- ](Play[- ])?(Konto|Konten|Account)|Konto bei Google'
      '|(mit|über) (deinem |Ihrem |dem )?Google(-Konto|-Account)? '
      '(anmelden|einloggen|fortfahren)'
      '|weiter mit Google(?![ -]Play)'
      '|Google[- ](Anmeldung|Login)|Anmeldung (mit|über) Google'
      '|verknüpfte[ns]? Google',
      caseSensitive: false,
    ),
    'es': RegExp(
      'cuentas? (de )?Google|(sesión|acceso|accede|entra|inicia) (con|en) Google'
      '|con Google(?![ -]Play)',
      caseSensitive: false,
    ),
    'fr': RegExp(
      'comptes? Google|(connexion|connecter|connectez)( avec| à| via)? Google'
      '|(identifier|identifiez)( avec| via)? Google'
      '|(continuer|continuez) (avec|via) Google(?![ -]Play)'
      '|Google associé',
      caseSensitive: false,
    ),
    'pt': RegExp(
      'contas? (do )?Google|(entrar|entre|login|sessão|acesso) com (o )?Google'
      '|com (o )?Google(?![ -]Play)',
      caseSensitive: false,
    ),
    'ru': RegExp(
      '(аккаунт|учётн[а-яё]* запис|учетн[а-яё]* запис)[а-яё]* (Google|гугл)'
      '|(Google|гугл)[- ]?аккаунт'
      '|в(ход|ойти|ойдите)[а-яё]* (через|с помощью|с) (Google|гугл)'
      '|продолж[а-яё]* (с|через|с помощью) (Google|гугл)(?![ -]Play| плей)'
      '|привязанн?[а-яё]* (аккаунт|учётн|учетн)',
      caseSensitive: false,
    ),
    'uk': RegExp(
      "(обліков[а-яіїєґ'’ʼ]* запис|акаунт)[а-яіїєґ]* (Google|гугл)"
      '|(Google|гугл)[- ]?акаунт'
      '|(вхід|входу|увійти|увійдіть) (через|за допомогою|з) (Google|гугл)'
      '|продовж[а-яіїєґ]* (з|через|за допомогою) (Google|гугл)'
      '(?![ -]Play| плей)'
      '|прив.язан[а-яіїєґ]* (обліков|акаунт)',
      caseSensitive: false,
    ),
    'tr': RegExp(
      'Google( Play)? hesab|Google ile (giriş|oturum|devam|bağlan)'
      '|Google giriş|bağlı Google',
      caseSensitive: false,
    ),
    'id': RegExp(
      'akun Google'
      '|(masuk|login) (dengan|pakai|lewat|melalui|menggunakan) Google'
      '|lanjut(kan)? (dengan|pakai|lewat|melalui|menggunakan) Google'
      '(?![ -]Play)'
      '|Google yang tertaut',
      caseSensitive: false,
    ),
    'vi': RegExp(
      'tài khoản Google|đăng nhập (bằng|với|qua) Google'
      '|tiếp tục (với|bằng|qua) Google(?![ -]Play)'
      '|Google đã liên kết',
      caseSensitive: false,
    ),
    'uz': RegExp(
      'Google( Play)? (hisob|akkaunt)|Google (orqali|bilan) (kir|davom)'
      "|bog[ʻ'‘’`]?langan Google",
      caseSensitive: false,
    ),
    'hi': RegExp(
      '(Google|गूगल)( Play| प्ले)? (खात|अकाउंट|एकाउंट|अकाउन्ट)'
      '|(Google|गूगल) (से |के साथ |द्वारा )?(साइन|लॉग) ?इन'
      '|(Google|गूगल) (से|के साथ) जारी'
      '|जुड़ा हुआ .{0,15}(Google|गूगल)|जीमेल',
    ),
    'ur': RegExp(
      '(Google|گوگل)( Play| پلے)? (اکاؤنٹ|اکاونٹ|کھات)'
      '|(Google|گوگل) (سے |کے ساتھ |کے ذریعے )?(سائن|لاگ) ?ان'
      '|(Google|گوگل) (سے|کے ساتھ) جاری'
      '|منسلک (Google|گوگل)|جی ?میل',
    ),
    'ja': RegExp(
      r'(Google|グーグル)\s*(Play\s*)?アカウント'
      r'|(Google|グーグル)\s*(で|に|を使って|を使用して)?\s*(ログイン|サインイン)'
      r'|(Google|グーグル)\s*(で|を使って|を使用して)\s*続(ける|行)'
      r'|リンクされた\s*(Google|グーグル)',
    ),
    'ko': RegExp(
      r'(Google|구글)\s*(Play\s*)?계정|(Google|구글)\s*(으로|로)?\s*로그인'
      r'|(Google|구글)\s*(으로|로)\s*계속'
      r'|연결된\s*(Google|구글)|지메일',
    ),
    'zh': RegExp(
      r'(Google|谷歌)\s*(Play\s*)?(账户|帐户|账号|帐号|帳戶|帳號)'
      r'|(Google|谷歌)\s*(登录|登錄|登入|邮箱|郵箱)'
      r'|(使用|通过|通過|透过|透過|用)\s*(Google|谷歌)\s*(继续|繼續)'
      r'|(关联|關聯|绑定|綁定)的\s*(Google|谷歌)',
    ),
  };

  /// Made-up texts that mention a Google account, Google sign-in or a
  /// Google email address, in the ways each language writes them. None is
  /// a text the app ever had. Each must match its language's words, so the
  /// checks below are known to catch them.
  const samples = <String, List<String>>{
    'en': [
      'Your Google account stays with your plan.',
      'Sign in with Google',
      'Log in using Google to keep your servers.',
      'Continue with Google',
      'Enter your Gmail address.',
      'We send the code to your Google email.',
      'Link your Google account to this phone.',
      'Google login is optional.',
    ],
    'fa': [
      'با اکانت گوگل وارد شوید',
      'حساب‌های گوگل',
      'حساب Google شما',
      'ورود با Google',
      'اکانت گوگل شما متصل است.',
      'نشانی جیمیل خود را وارد کنید.',
      'ادامه با گوگل',
      'حساب کاربری گوگل شما حذف می‌شود.',
    ],
    'ar': [
      'سجّل الدخول باستخدام Google',
      'سجل الدخول عبر جوجل',
      'تسجيل الدخول بحساب Google',
      'حسابك على Google',
      'حسابك في Google',
      'المتابعة باستخدام Google',
      'أدخل عنوان جيميل الخاص بك.',
    ],
    'de': [
      'Mit deinem Google-Account anmelden',
      'Google-Konten',
      'Mit Google fortfahren',
      'Weiter mit Google',
      'Dein Google-Login bleibt gespeichert.',
      'Dein Google Konto bleibt verbunden.',
    ],
    'es': [
      'Continuar con Google',
      'Tus cuentas de Google',
      'Inicia sesión con Google para guardar tu plan.',
      'Tu cuenta de Google sigue vinculada.',
    ],
    'fr': [
      'Continuer avec Google',
      'Vos comptes Google',
      'Se connecter avec Google',
      "S'identifier avec Google",
    ],
    'pt': [
      'Continuar com o Google',
      'Continuar com Google',
      'Suas contas do Google',
      'Entrar com o Google para guardar o plano.',
    ],
    'ru': [
      'Войти через Гугл',
      'гугл-аккаунт',
      'Ваш аккаунт Гугл',
      'Аккаунт Google сохранит ваш тариф.',
      'Продолжить с Google',
      'Войдите с помощью Google.',
    ],
    'uk': [
      'акаунт Гугл',
      'Увійти через Гугл',
      'Продовжити з Google',
      'Ваш обліковий запис Google',
      'гугл-акаунт',
    ],
    'tr': [
      'Google ile devam et',
      'Google hesabınızla giriş yapın.',
      'Google ile oturum açın.',
    ],
    'id': [
      'Lanjutkan dengan Google',
      'Masuk dengan Google',
      'Akun Google Anda tetap tersimpan.',
    ],
    'vi': [
      'Tiếp tục với Google',
      'Đăng nhập bằng Google',
      'Tài khoản Google của bạn',
    ],
    'uz': [
      'Google akkaunti',
      'Google hisobingiz saqlanadi.',
      'Google orqali kiring',
      'Google bilan davom etish',
      "bog'langan Google hisobi",
    ],
    'hi': [
      'Google अकाउंट',
      'Google एकाउंट',
      'Google से साइन इन करें',
      'Google के साथ जारी रखें',
      'आपका गूगल खाता',
      'अपना जीमेल पता डालें।',
    ],
    'ur': [
      'گوگل اکاؤنٹ',
      'Google سے سائن ان کریں',
      'Google کے ساتھ جاری رکھیں',
      'اپنا جی میل پتہ لکھیں۔',
    ],
    'ja': ['Googleアカウント', 'グーグルアカウント', 'Googleでログイン', 'Googleで続ける'],
    'ko': ['Google로 계속하기', '구글 계정', 'Google로 로그인', '지메일 주소'],
    'zh': ['谷歌帐号', 'Google 账户', 'Google 帳戶', '使用 Google 继续', '通过 Google 登录'],
  };

  /// The words that [text] in [lang] matches: its own language's and the
  /// English ones, in case English was left untranslated.
  bool mentionsAccount(String lang, String text) =>
      accountWords[lang]!.hasMatch(text) || accountWords['en']!.hasMatch(text);

  /// Every text in [arb]: each value, and each @ entry's description.
  Iterable<(String, String)> textsOf(Map<String, dynamic> arb) sync* {
    for (final e in arb.entries) {
      final v = e.value;
      if (v is String) yield (e.key, v);
      if (v is Map && v['description'] is String) {
        yield (e.key, v['description'] as String);
      }
    }
  }

  test('every language is checked', () {
    expect(accountWords.keys.toSet(), arbs.keys.toSet());
    expect(samples.keys.toSet(), arbs.keys.toSet());
  });

  for (final lang in samples.keys) {
    test('[$lang] the words catch each way of writing it', () {
      final missed = [
        for (final text in samples[lang]!)
          if (!accountWords[lang]!.hasMatch(text)) text,
      ];
      expect(missed, isEmpty);
    });
  }

  for (final lang in accountWords.keys) {
    test('[$lang] no text mentions a Google account or Google sign-in', () {
      final hits = [
        for (final (key, text) in textsOf(arbs[lang]!))
          if (mentionsAccount(lang, text)) '$key: $text',
      ];
      expect(hits, isEmpty);
    });
  }

  test('the restore message names Google Play in every language', () {
    for (final lang in arbs.keys) {
      final text = arbs[lang]!['premiumRestoreNone'] as String;
      expect(
        text.contains('Google Play') || text.contains('گوگل پلی'),
        isTrue,
        reason: '$lang: $text',
      );
    }
  });

  test('no store screenshot caption mentions a Google account', () {
    final captions = Directory('tool/store_screenshots/captions')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    expect(captions, isNotEmpty);
    final hits = <String>[];
    for (final f in captions) {
      final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final lang = json['lang'] as String;
      expect(accountWords.keys, contains(lang), reason: f.path);
      for (final frame in json['frames'] as List) {
        for (final text in (frame as Map).values.whereType<String>()) {
          if (mentionsAccount(lang, text)) hits.add('$lang: $text');
        }
      }
    }
    expect(hits, isEmpty);
  });

  test('no store listing text mentions a Google account', () {
    const listing = [
      'title.txt',
      'short_description.txt',
      'full_description.txt',
    ];
    String name(FileSystemEntity e) =>
        e.path.split(Platform.pathSeparator).last;
    final hits = <String>[];
    var read = 0;

    // Each main listing is read with its own language's words. The
    // folder is named for its locale, such as fa-IR or es-419.
    for (final dir in Directory(
      'android/fastlane/metadata/android',
    ).listSync().whereType<Directory>()) {
      final lang = name(dir).split('-').first;
      expect(accountWords.keys, contains(lang), reason: dir.path);
      for (final file in listing) {
        final f = File('${dir.path}/$file');
        if (!f.existsSync()) continue;
        read++;
        if (mentionsAccount(lang, f.readAsStringSync())) hits.add(f.path);
      }
    }

    // A custom listing can be in any language, so each one is read with
    // every language's words.
    for (final dir in Directory(
      'android/fastlane/metadata/custom',
    ).listSync().whereType<Directory>()) {
      for (final file in listing) {
        final f = File('${dir.path}/$file');
        if (!f.existsSync()) continue;
        read++;
        final text = f.readAsStringSync();
        if (accountWords.values.any((w) => w.hasMatch(text))) hits.add(f.path);
      }
    }

    expect(read, greaterThan(0));
    expect(hits, isEmpty);
  });
}
