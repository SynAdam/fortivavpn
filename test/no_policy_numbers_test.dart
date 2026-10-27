// The rule this test enforces
//
// The phone app never hard-codes a number that describes what the service
// gives or requires: data amounts, bonuses, caps, claim windows in hours,
// qualifying days, retention days, device limits and prices. The team set this
// rule on 2026-10-07, after the invite screen named 250 MB per friend on
// every installed phone while the backend was moving to another amount. A
// number written into the app stays wrong until each phone installs the
// next release.
//
// The backend sends the number and the app reads it. When the backend
// sends none, the app shows text that names no number. Changing such a
// number must never need an app release. UI timing, protocol defaults,
// licence terms and copyright years are not covered.
//
// What this test checks:
//
// 1. No value in lib/l10n/*.arb has a digit in any script (0-9, Persian,
//    Arabic-Indic, Devanagari, full-width), except the keys listed in
//    allowedArbDigits. Placeholders such as {amount} are not digits.
// 2. No value in lib/l10n/*.arb has a number written as a word, or a word
//    such as "a few" or "a single", next to a unit the service sets:
//    hours, days, weeks, GB, MB, devices, phones, friends, invites. The
//    word lists for each of the 18 languages are in this file.
// 3. No Dart file under lib/ does byte-size math (1024 * 1024, << 20,
//    << 30), holds a literal of a million or more (262144000, 1073741824),
//    writes a Duration of hours or days as a literal, keeps a number in a
//    constant, field, getter or default whose name says it is a service
//    rule (confirmDays = 2, deviceLimit = 3), falls back to a number after
//    ?? on such a name (claimWindowHours ?? 72), or passes a literal to a
//    message whose placeholder is {days} or {hours}
//    (deleteAccountConfirmRetention(30)), except the hits listed in
//    allowedCode. String literals under lib/ may not name a number with a
//    unit either, because user text belongs in the .arb files.
// 4. android/app/src/main/res/values*/strings.xml has no digit.
//
// CI runs this file in the flutter test step of .github/workflows/ci.yml,
// and tool/release.sh runs the tests again before every build.
//
// How to show a number the right way:
//
// 1. The backend sends it as a field that reads a backend setting.
//    claim_window_hours on GET /api/v1/devices/{id}/referral is an example.
// 2. The app parses it as optional: null when it is missing, zero,
//    negative or not a whole number. See ReferralStatus.fromJson.
// 3. Add the string with a placeholder ({hours}) and a second string that
//    names no number, in all 18 .arb files, then run flutter gen-l10n.
//    The screen shows the second string when the field is null. See
//    inviteHaveCodeSubtitle and inviteHaveCodeSubtitleNoHours.
// 4. Pass the text through NumberLocalizer so fa, ar and ur show their own
//    digits.
//
// The allowlists below are not the way to add a service number. They are
// for text that is not a service rule at all, such as a copyright year, a
// DNS default or a licence version, and for app-side timing that users
// never see. Every entry needs a reason. An entry that no longer matches
// anything fails the test, so the lists cannot grow stale.
//
// The generated files in lib/l10n/generated are not scanned. flutter pub
// get rebuilds them from the .arb files (generate: true in pubspec.yaml).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The 18 languages the app ships.
const languages = [
  'ar',
  'de',
  'en',
  'es',
  'fa',
  'fr',
  'hi',
  'id',
  'ja',
  'ko',
  'pt',
  'ru',
  'tr',
  'uk',
  'ur',
  'uz',
  'vi',
  'zh',
];

// Allowlists. Read the header before adding to these.

/// .arb keys whose values may hold digits: the exact numbers allowed, and
/// why each one is not a service rule.
const allowedArbDigits = <String, ({Set<String> numbers, String reason})>{
  'copyright': (numbers: {'2026'}, reason: 'The copyright year.'),
  'primaryDnsHint': (
    numbers: {'1.1.1.1'},
    reason:
        'The default resolver in the custom DNS setting. A protocol '
        'default, not something the service gives.',
  ),
  'secondaryDnsHint': (
    numbers: {'8.8.8.8'},
    reason:
        'The default resolver in the custom DNS setting. A protocol '
        'default, not something the service gives.',
  ),
  'sourceOfferBody': (
    numbers: {'3'},
    reason:
        'The GPL source offer names "GNU General Public License v3". '
        'A licence version.',
  ),
  'apnGuideBody': (
    numbers: {'6'},
    reason:
        'The APN guide names IPv6, the internet protocol. A protocol '
        'name, not something the service gives.',
  ),
  'apnGuideSheetTitle': (
    numbers: {'6'},
    reason:
        'The APN guide names IPv6, the internet protocol. A protocol '
        'name, not something the service gives.',
  ),
  'apnGuideStepProtocol': (
    numbers: {'4', '6'},
    reason:
        'The APN guide names IPv4/IPv6, the value to pick in the phone\'s '
        'APN protocol setting. A protocol name.',
  ),
  'apnGuideUndo': (
    numbers: {'4'},
    reason:
        'The APN guide names IPv4, the APN protocol to go back to. A '
        'protocol name.',
  ),
};

/// .arb keys whose values may hold a number written as words, with the
/// exact phrases allowed.
const allowedArbWords = <String, ({Set<String> phrases, String reason})>{
  'sourceOfferBody': (
    phrases: {
      'three years', 'سه سال', 'drei jahre', 'trois ans', 'três anos', //
      'три года', 'üç yıl', 'ثلاث سنوات', 'تین سال', 'तीन साल',
      'tres años', 'tiga tahun', 'ba năm', 'три роки', 'uch yil', '三年',
    },
    reason:
        'GPLv3 section 6(b) sets how long the written offer for the '
        'source stays valid. A licence term. Japanese and Korean write it '
        'with the digit 3, which allowedArbDigits allows for this key.',
  ),
};

/// Dart files under lib/ that may hold byte math, large literals or long
/// Durations: every hit the file is allowed to have, and why. The list of
/// hits is exact. A new hit in the same file fails the test, and so does
/// a listed hit that is gone.
const allowedCode = <String, ({List<String> hits, String reason})>{
  'lib/widgets/quota_card.dart': (
    hits: ['1 << 30', '1 << 30', '1 << 30', '1 << 30', '1 << 20', '1 << 20'],
    reason:
        'formatBytes and formatAllowance divide by these to print a '
        'size the backend sent. They state no amount.',
  ),
  'lib/widgets/update_dialog.dart': (
    hits: ['16 * 1024', 'movingBytes = 16 * 1024'],
    reason:
        'How much tunnel traffic counts as a working tunnel during an '
        'update check. App-side tuning, never shown.',
  ),
  'lib/services/vpn_service.dart': (
    hits: [
      '1000000',
      'throughputBytes = 1000000',
      'throughputBytesMetered = 256000',
      'throughputCap = Duration(seconds: 10)',
    ],
    reason:
        'Size and time cap of the throughput sample download. A '
        'measurement, not a policy.',
  ),
  'lib/services/vpn_event_reporter.dart': (
    hits: ['Duration(hours: 12)', 'probeUploadBytes = 1000'],
    reason:
        'How long a door check that found every door closed waits on the '
        'phone for a route to the backend, and the most one door-check '
        'upload carries. Report delivery tuning, never shown.',
  ),
  'lib/services/tunnel_pipe.dart': (
    hits: ['4 << 20'],
    reason:
        'The most a reply from the Windows tunnel service may hold before '
        'the read gives up: a guard against a runaway pipe. Not a size the '
        'service grants.',
  ),
  'lib/services/speed_test_service.dart': (
    hits: ['1000000', '1000000', '1000000'],
    reason:
        'Bits per megabit, and the size of the upload sample. A '
        'measurement, not a policy.',
  ),
  'lib/core/state/review_prompt.dart': (
    hits: [
      'minDays = 3',
      'Duration(hours: 24)',
      'Duration(days: 90)',
      'Duration(hours: 3, minutes: 30)',
    ],
    reason:
        'When the app asks for a Play rating, and the Tehran clock '
        'offset. App-side timing that users never see.',
  ),
  'lib/api/bootstrap.dart': (
    hits: [
      'nonceBytes = 12',
      'tagBytes = 16',
      'grace = Duration(seconds: 2)',
      'maxBytes = 256 * 1024',
      '256 * 1024',
      'Duration(days: 14)',
      'Duration(hours: 12)',
    ],
    reason:
        'The AES-GCM nonce and tag sizes of the fallback file\'s format, how '
        'long the other hosts get once one answered, the most read as a '
        'file, how old a kept file may be to hand to another phone, and how '
        'old it may get before the app asks the backend for a newer one. '
        'Format, connection tuning and local cache ages, never shown.',
  ),
  'lib/api/notices_file.dart': (
    hits: ['maxBytes = 512 * 1024', '512 * 1024'],
    reason:
        'The most read from a host as the notices file. A guard against a '
        'host that sends something huge, never shown.',
  ),
  'lib/api/api_client.dart': (
    hits: ['fileMaxBytes = 16 * 1024 * 1024', '16 * 1024 * 1024'],
    reason:
        'The most read as a file download (getBytes), the same as the '
        'backend\'s own limit for the backup network\'s server list. A '
        'guard against a route that sends something huge, never shown.',
  ),
  'lib/services/psiphon_entries.dart': (
    hits: ['Duration(hours: 1)'],
    reason:
        'How long the backup network\'s server list waits before a failed '
        'download is tried again. App-side timing that users never see.',
  ),
  'lib/core/state/notice_permission_prompt.dart': (
    hits: ['Duration(days: 3)'],
    reason:
        'How long the app waits before it asks a second time to allow '
        'notifications. App-side timing that users never see.',
  ),
  'lib/widgets/background_card.dart': (
    hits: ['Duration(days: 1)', 'Duration(days: 7)'],
    reason:
        'How long without a background check counts as the phone stopping '
        'them, and how long a closed card stays away. App-side timing that '
        'users never see.',
  ),
  'lib/widgets/notices_switch.dart': (
    hits: ['Duration(days: 7)'],
    reason:
        'How long Not now keeps the notifications card away. App-side '
        'timing that users never see.',
  ),
  'lib/core/state/server_state.dart': (
    hits: ['Duration(hours: 1)'],
    reason:
        'How long a public list the backend sent stays ahead of the '
        'fallback file on the phone. A local cache age.',
  ),
  'lib/core/state/dedicated_state.dart': (
    hits: ['Duration(days: 30)'],
    reason:
        'How long the kept answer with this device\'s servers is used on '
        'the phone. A local cache age.',
  ),
  'lib/data/repositories/server_repository.dart': (
    hits: ['Duration(days: 30)'],
    reason:
        'How long the saved community list is kept on the phone. A '
        'local cache age.',
  ),
  'lib/core/state/connect_flow.dart': (
    hits: ['sharedFallbackLimit = 6'],
    reason: 'How many shared links one fallback checks. Connection tuning.',
  ),
  'lib/services/door_sweep.dart': (
    hits: ['Duration(hours: 6)'],
    reason: 'How often the app re-checks doors in the background.',
  ),
  'lib/services/candidate_prober.dart': (
    hits: ['Duration(hours: 6)'],
    reason: 'How often the app probes candidate servers in the background.',
  ),
  'lib/services/path_memory.dart': (
    hits: ['Duration(hours: 24)', 'maxFailsPerDay = 3'],
    reason:
        'How long a remembered door result stays fresh on the phone, '
        'and how many failures skip it. Connection tuning.',
  ),
  'lib/services/session_tracker.dart': (
    hits: ['Duration(days: 7)'],
    reason: 'The local usage history the analytics screen shows.',
  ),
  'lib/screens/analytics_screen.dart': (
    hits: ['Duration(days: 1)'],
    reason: 'Finds yesterday for the "Yesterday at" label.',
  ),
  'lib/core/state/support_state.dart': (
    hits: ['Duration(hours: 6)', 'Duration(hours: 24)'],
    reason:
        'How often the phone asks again whether the support chat is on, '
        'and how long the phone keeps trying to send a message that has '
        'not reached the backend. App-side timing. The not-sent line '
        'names no number.',
  ),
  'lib/core/state/apn_guide.dart': (
    hits: ['Duration(days: 14)'],
    reason:
        'How long "Not now" keeps the APN guide card off the home screen. '
        'App-side timing of a hint. The card names no number.',
  ),
};

// Word lists, one entry per language. Each entry is a regular expression.

/// Words that say how many of something, and the units the service sets.
///
/// A hit is a count followed by a unit ("a few days", "zwei Geräte"), a
/// word for one followed by a unit ("a single device"), or a whole
/// pattern from extra. Words that also mean "a" or "an" pair only with
/// [singleUnits], so "an invite code" does not hit.
class Words {
  const Words({
    this.counts = const [],
    this.ranges = const [],
    this.units = const [],
    this.ones = const [],
    this.singles = const [],
    this.singleUnits = const [],
    this.extra = const [],
    this.extraOne = const [],
    this.extraTwo = const [],
    this.bare = const [],
  });

  /// Numbers and quantity words: "two", "a few", "several".
  final List<String> counts;

  /// Words that join a range: "two or three days".
  final List<String> ranges;

  /// What the service counts: "days", "GB", "devices", "friends".
  final List<String> units;

  /// Words for exactly one, paired with every unit: "one", "a single".
  final List<String> ones;

  /// Words that also mean "a" or "an", paired only with [singleUnits].
  final List<String> singles;
  final List<String> singleUnits;

  /// Whole patterns, matched as words: ratios such as "twice", and
  /// compounds such as "zweitägig".
  final List<String> extra;

  /// Whole patterns that mean one. A plural's one or =1 branch may use
  /// them, because there the count is the placeholder's own value.
  final List<String> extraOne;

  /// Whole patterns that mean two (Arabic duals). A plural's two or =2
  /// branch may use them.
  final List<String> extraTwo;

  /// Patterns for languages written without spaces between words (ja,
  /// ko), matched as written.
  final List<String> bare;
}

const wordLists = <String, Words>{
  'en': Words(
    counts: [
      'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', //
      'ten', 'eleven', 'twelve', 'fifteen', 'twenty', 'thirty', 'forty',
      'fifty', 'sixty', 'seventy', 'ninety', 'hundred', 'thousand',
      'a couple(?: of)?', 'couple of', 'a few', 'few', 'several',
      'a dozen', 'dozens of', 'a handful of', 'half an?',
    ],
    ranges: ['or', 'to', 'and'],
    units: [
      'hours?', 'days?', 'nights?', 'weeks?', 'months?', 'years?', //
      'gigabytes?', 'megabytes?', 'gigs?', 'GB', 'MB', 'GiB', 'MiB', 'TB',
      'devices?', 'phones?', 'friends?', 'people', 'persons?', 'invites?',
      'invitations?', 'referrals?',
    ],
    ones: ['one', 'a single', 'single', 'only one'],
    singles: ['a', 'an'],
    // Not "day": "{max} a day" means per day.
    singleUnits: [
      'hour', 'week', 'fortnight', 'month', 'year', 'gigabyte', 'megabyte', //
      'gig', 'GB', 'MB',
    ],
    extraOne: [r'(?:within|for|after|in|over)\s+a\s+day'],
    extra: [
      'twice', 'double', 'triple', 'fortnight', //
      r'(?:two|three|four|five|ten)\s+times',
      r'a\s+day\s+or\s+two',
    ],
  ),
  'de': Words(
    counts: [
      'zwei', 'drei', 'vier', 'fünf', 'sechs', 'sieben', 'acht', 'neun', //
      'zehn', 'elf', 'zwölf', 'fünfzehn', 'zwanzig', 'dreißig', 'vierzig',
      'fünfzig', 'sechzig', 'hundert', 'tausend', 'ein paar', 'paar',
      'einige[nmrs]?', 'wenige[nmrs]?', 'mehrere[nmrs]?', 'anderthalb',
      'eineinhalb', r'(?:ein|eine|einen|einem|einer)\s+halbe[nmrs]?',
    ],
    ranges: ['oder', 'bis', 'und'],
    units: [
      'Stunden?', 'Tagen?', 'Tage', 'Tag', 'Wochen?', 'Monaten?', 'Monate', //
      'Monat', 'Jahren?', 'Jahre', 'Jahr', 'Gigabytes?', 'Megabytes?', 'GB',
      'MB', 'Geräten?', 'Geräte', 'Gerät', 'Handys?', 'Telefonen?',
      'Freunden?', 'Freunde', 'Freundinnen', 'Personen', 'Leute',
      'Einladungen',
    ],
    ones: [
      'einzige[nmrs]?',
      r'nur\s+(?:ein|eine|einem|einen|einer)',
      r'genau\s+(?:ein|eine|einem|einen|einer)',
    ],
    singles: ['ein', 'eine', 'einen', 'einem', 'einer'],
    singleUnits: [
      'Stunde', 'Tag', 'Woche', 'Monat', 'Jahr', 'Gigabyte', 'Megabyte', //
      'GB', 'MB',
    ],
    extra: [
      r'doppelt\p{L}*', 'das Doppelte', //
      r'(?:zwei|drei|vier|fünf|zehn)(?:fach|mal)\p{L}*',
      r'(?:ein|zwei|drei|vier|fünf|sechs|sieben|acht|neun|zehn|zwölf|zwanzig|dreißig)(?:tägig|stündig|wöchig|monatig|jährig)\p{L}*',
    ],
  ),
  'fr': Words(
    counts: [
      'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf', //
      'dix', 'onze', 'douze', 'quinze', 'vingt', 'trente', 'quarante',
      'cinquante', 'soixante', 'cent', 'mille', 'quelques', 'plusieurs',
      'une dizaine de', 'une douzaine de', 'une centaine de',
      r'une?\s+demie?',
    ],
    ranges: ['ou', 'à', 'et'],
    units: [
      'heures?', 'jours?', 'journées?', 'semaines?', 'mois', 'ans', //
      'années?', 'gigaoctets?', 'mégaoctets?', 'Go', 'Mo', 'GB', 'MB',
      'appareils?', 'téléphones?', 'amis?', 'amies?', r'ami\(e\)s',
      'personnes?', 'invitations?', 'parrainages?',
    ],
    ones: ['un seul', 'une seule', 'seule?', 'un unique', 'une unique'],
    singles: ['un', 'une'],
    singleUnits: [
      'heure', 'jour', 'journée', 'semaine', 'mois', 'an', 'année', //
      'gigaoctet', 'mégaoctet', 'Go', 'Mo',
    ],
    extra: [
      r'(?:deux|trois|quatre|cinq|dix)\s+fois', 'le double', 'le triple', //
      'doublée?s?', 'triplée?s?',
    ],
  ),
  'pt': Words(
    counts: [
      'dois', 'duas', 'três', 'quatro', 'cinco', 'seis', 'sete', 'oito', //
      'nove', 'dez', 'onze', 'doze', 'quinze', 'vinte', 'trinta',
      'quarenta', 'cinquenta', 'sessenta', 'cem', 'mil', 'alguns',
      'algumas', 'vários', 'várias', 'poucos', 'poucas', 'uns', 'umas',
      'meia', 'meio', 'uma dúzia de',
    ],
    ranges: ['ou', 'a', 'e'],
    units: [
      'horas?', 'dias?', 'semanas?', 'mês', 'meses', 'anos?', //
      'gigabytes?', 'megabytes?', 'GB', 'MB', 'dispositivos?', 'aparelhos?',
      'celulares?', 'telefones?', 'amigos?', 'amigas?', 'pessoas?',
      'convites?', 'indicações', 'indicação',
    ],
    ones: [
      'um só', 'uma só', 'um único', 'uma única', 'apenas um', //
      'apenas uma', 'só um', 'só uma', 'somente um', 'somente uma',
    ],
    singles: ['um', 'uma'],
    singleUnits: [
      'hora', 'dia', 'semana', 'mês', 'ano', 'gigabyte', 'megabyte', 'GB', //
      'MB',
    ],
    extra: [
      'o dobro', 'o triplo', r'(?:duas|três|quatro|cinco|dez)\s+vezes', //
      'dobrad[oa]s?', 'triplicad[oa]s?',
    ],
  ),
  'ru': Words(
    counts: [
      'два', 'две', 'двух', 'двум', 'три', 'тр[её]х', 'тр[её]м', //
      'четыре', 'четыр[её]х', 'пять', 'пяти', 'шесть', 'шести', 'семь',
      'семи', 'восемь', 'восьми', 'девять', 'девяти', 'десять', 'десяти',
      'одиннадцать', 'двенадцать', 'пятнадцать', 'двадцать', 'двадцати',
      'тридцать', 'тридцати', 'сорок', 'пятьдесят', 'сто', r'тысяч\p{L}*',
      'пару', 'пара', 'пары', 'паре', 'несколько', 'нескольких', 'двое',
      'трое', 'четверо', 'пятеро', 'полтора', 'полторы',
    ],
    ranges: ['или', 'до'],
    units: [
      r'час\p{L}*', r'дн\p{L}*', 'день', r'сут\p{L}*', r'недел\p{L}*', //
      r'месяц\p{L}*', r'год\p{L}*', 'лет', r'гигабайт\p{L}*',
      r'мегабайт\p{L}*', r'гиг\p{L}*', 'ГБ', 'МБ', 'Гб', 'Мб',
      r'устройств\p{L}*', r'телефон\p{L}*', r'друз\p{L}*', 'друга?',
      r'человек\p{L}*', r'приглашени\p{L}*',
    ],
    ones: [
      'один', 'одна', 'одно', 'одного', 'одну', 'одном', 'одной', //
      r'единственн\p{L}*',
    ],
    extraOne: [
      // A bare noun after a preposition means one: "в течение суток",
      // "через неделю", "на месяц". "в день" and "за день" mean per day
      // and do not hit.
      r'в\s+течение\s+(?:дня|суток|недели|месяца|года|часа)',
      r'через\s+(?:день|сутки|неделю|месяц|год|час)',
      r'(?:за|на)\s+(?:неделю|месяц|год|час|сутки)',
      // "сутки" alone is one day and night, unless a number or a
      // placeholder comes before it.
      r'(?<![\p{Nd}\uFFFC][\s\u00a0]{0,3})сут(?:ки|ок)',
    ],
    extra: [
      'вдвое', 'втрое', 'вчетверо', 'вдвойне', //
      r'в\s+(?:два|три|четыре|пять|десять)\s+раза?',
      r'пол(?:часа|дня|суток|недели|месяца|года)',
    ],
  ),
  'tr': Words(
    counts: [
      'iki', 'üç', 'dört', 'beş', 'altı', 'yedi', 'sekiz', 'dokuz', 'on', //
      'yirmi', 'otuz', 'kırk', 'elli', 'yüz', 'bin', 'birkaç', 'birçok',
      'yarım',
    ],
    ranges: ['veya', 'ya da', 'ila'],
    units: [
      r'saat\p{L}*', r'gün\p{L}*', r'hafta\p{L}*', 'ay', 'aylık', 'ayda', //
      'ayı', r'yıl\p{L}*', r'sene\p{L}*', r'gigabayt\p{L}*',
      r'megabayt\p{L}*', 'GB', 'MB', r'cihaz\p{L}*', r'telefon\p{L}*',
      r'arkadaş\p{L}*', r'kişi\p{L}*', r'davet\p{L}*',
    ],
    ones: ['tek', 'yalnızca bir', 'sadece bir', 'yalnız bir'],
    singles: ['bir'],
    // Not "gün": "bir gün" also means "some day".
    singleUnits: [
      'saat', 'saatlik', 'hafta', 'haftalık', 'ay', 'aylık', 'yıl', //
      'yıllık', 'GB', 'MB', r'gigabayt\p{L}*',
    ],
    extraOne: [r'bir\s+gün\s+içinde'],
    extra: [r'(?:iki|üç|dört|beş|on)\s+kat\p{L}*', r'iki\s+misli'],
  ),
  'fa': Words(
    counts: [
      'دو', 'سه', 'چهار', 'پنج', 'شش', 'هفت', 'هشت', 'نه', 'ده', 'یازده', //
      'دوازده', 'پانزده', 'بیست', 'سی', 'چهل', 'پنجاه', 'صد', 'هزار', 'چند',
      'چندین', r'دو\s+سه', r'یکی\s+دو', 'نیم',
    ],
    ranges: ['یا', 'تا'],
    units: [
      r'ساعت\p{L}*', 'روز', 'روزه', 'روزی', 'هفته', 'ماه', 'ماهه', 'سال', //
      'ساله', 'گیگابایت', 'گیگ', 'مگابایت', 'مگ', r'دستگاه\p{L}*',
      r'گوشی\p{L}*', 'دوست', 'دوستان', 'نفر', r'دعوت\p{L}*',
    ],
    ones: [r'فقط\s+یک', r'تنها\s+یک'],
    singles: ['یک'],
    // Not "روز": "یک روز" also means "some day".
    singleUnits: [
      r'ساعت\p{L}*', 'هفته', 'ماه', 'سال', r'دستگاه\p{L}*', //
      r'گوشی\p{L}*', 'نفر', 'گیگ', 'گیگابایت', 'مگ', 'مگابایت',
    ],
    extraOne: [r'(?:ظرف|طی|در\s+عرض)\s+یک\s+روز'],
    extra: [r'(?:دو|سه|چهار|پنج|ده)[\s\u200c]*برابر'],
  ),
  'ar': Words(
    // A count may carry a joined preposition: "لبضعة أيام".
    counts: [
      '[وفبل]?(?:اثنين|اثنان|اثنتين|اثنتان|ثلاث|ثلاثة|ثلاثين|ثلاثون|'
          'أربع|أربعة|أربعين|أربعون|خمس|خمسة|خمسين|خمسون|ست|ستة|ستين|ستون|'
          'سبع|سبعة|سبعين|سبعون|ثمان|ثماني|ثمانية|ثمانين|ثمانون|تسع|تسعة|'
          'تسعين|تسعون|عشر|عشرة|عشرين|عشرون|مئة|مائة|ألف|بضع|بضعة|عدة)',
    ],
    ranges: ['أو', 'إلى'],
    // The unit may carry the article and the accusative ending: "يومًا".
    units: [
      r'(?:[وفبل]?ال)?(?:ساعة|ساعات|يوم|أيام|أسبوع|أسابيع|شهر|أشهر|شهور|'
          r'سنة|سنوات|عام|أعوام|جيجابايت|غيغابايت|ميجابايت|ميغابايت|جهاز|'
          r'أجهزة|هاتف|هواتف|صديق|أصدقاء|شخص|أشخاص|دعوة|دعوات)'
          r'(?:\p{M}*ا)?\p{M}*',
    ],
    extraOne: [
      // "يوم واحد", "جهاز واحد".
      r'(?:ساعة|يوم|أسبوع|شهر|سنة|عام|جهاز|هاتف|صديق|شخص|دعوة|جيجابايت|'
          r'غيغابايت|ميجابايت|ميغابايت)\p{M}*'
          r'\s+(?:واحد|واحدة)\p{M}*',
      // A bare noun after a preposition means one: "خلال أسبوع".
      r'(?:خلال|بعد|لمدة|مدة|طوال|قبل|غضون)\s+'
          r'(?:ساعة|يوم|أسبوع|شهر|سنة|عام)\p{M}*',
    ],
    extraTwo: [
      r'[وفبل]?(?:ال)?(?:يومين|يومان|ساعتين|ساعتان|أسبوعين|أسبوعان|شهرين|'
          r'شهران|سنتين|سنتان|عامين|عامان|جهازين|جهازان|هاتفين|صديقين)\p{M}*',
    ],
    extra: [
      'ضعف', 'ضعفي', 'ضعفين', 'أضعاف', 'مرتين', //
      r'[وفبل]?(?:ال)?(?:أيام|ساعات|أسابيع)\p{M}*\s+(?:ال)?قليلة',
    ],
  ),
  'ur': Words(
    counts: [
      'دو', 'تین', 'چار', 'پانچ', 'چھ', 'سات', 'آٹھ', 'نو', 'دس', 'گیارہ', //
      'بارہ', 'پندرہ', 'بیس', 'تیس', 'چالیس', 'پچاس', 'سو', 'ہزار', 'چند',
      'کئی', 'کچھ', r'ایک\s+دو', r'دو\s+تین', r'آدھ\p{L}*', 'ڈیڑھ', 'ڈھائی',
    ],
    ranges: ['یا', 'سے', 'تا'],
    units: [
      r'گھنٹ\p{L}*', 'دن', 'دنوں', 'روز', r'ہفت\p{L}*', r'مہین\p{L}*', //
      'ماہ', 'سال', r'جی\s+بی', r'ایم\s+بی', 'گیگابائٹ', 'میگابائٹ',
      r'ڈیوائس\p{L}*', 'آلات', r'فون\p{L}*', r'دوست\p{L}*', 'افراد',
      r'لوگ\p{L}*', r'دعوت\p{L}*',
    ],
    ones: [r'صرف\s+ایک', r'فقط\s+ایک', r'ایک\s+ہی'],
    singles: ['ایک'],
    singleUnits: [
      r'گھنٹ\p{L}*', r'ہفت\p{L}*', r'مہین\p{L}*', 'سال', //
      r'ڈیوائس\p{L}*', r'فون\p{L}*', r'جی\s+بی', 'گیگابائٹ',
    ],
    extra: [r'(?:دو|تین|چار|پانچ|دس)\s*گنا', 'دوگنا', 'دگنا'],
  ),
  'hi': Words(
    counts: [
      'दो', 'तीन', 'चार', 'पाँच', 'पांच', 'छह', 'छः', 'सात', 'आठ', 'नौ', //
      'दस', 'ग्यारह', 'बारह', 'पंद्रह', 'बीस', 'तीस', 'चालीस', 'पचास', 'सौ',
      'हज़ार', 'हजार', 'कुछ', 'कई', 'एक-दो', 'दो-तीन', 'आधा', 'आधे',
      'डेढ़', 'ढाई',
    ],
    ranges: ['या', 'से'],
    units: [
      r'घंट[\p{L}\p{M}]*', 'दिन', 'दिनों', 'सप्ताह', r'हफ़्त[\p{L}\p{M}]*', //
      r'हफ्त[\p{L}\p{M}]*', r'महीन[\p{L}\p{M}]*', 'साल', 'वर्ष', 'GB', 'MB',
      'जीबी', 'एमबी', 'गीगाबाइट', 'मेगाबाइट', 'डिवाइस', 'डिवाइसों', 'फ़ोन',
      'फोन', r'दोस्त[\p{L}\p{M}]*', r'मित्र[\p{L}\p{M}]*',
      r'लोग[\p{L}\p{M}]*', r'आमंत्रण[\p{L}\p{M}]*',
    ],
    ones: ['केवल एक', 'सिर्फ़ एक', 'सिर्फ एक', 'एक ही'],
    singles: ['एक'],
    singleUnits: [
      r'घंट[\p{L}\p{M}]*', 'सप्ताह', r'हफ़्त[\p{L}\p{M}]*', //
      r'हफ्त[\p{L}\p{M}]*', r'महीन[\p{L}\p{M}]*', 'साल', 'वर्ष', 'डिवाइस',
      'फ़ोन', 'फोन', 'GB', 'MB', 'जीबी', 'गीगाबाइट',
    ],
    extra: [
      r'(?:दो|तीन|चार|पाँच|दस)\s*गुन[\p{L}\p{M}]*',
      r'(?:दोगुन|दुगुन|दुगन|तिगुन)[\p{L}\p{M}]*',
    ],
  ),
  'ja': Words(
    bare: [
      // A numeral right before a counter: 数日, 三日間, 一台, 半年.
      r'(?:数|何|半|[一二三四五六七八九十百千両]+)\s?'
          r'(?:時間|日間|日|週間|週|か月|ヶ月|カ月|ヵ月|箇月|年間|年|台|人|名|'
          r'ギガ|メガ|GB|MB)',
      r'(?:[二三四五六七八九十数]|何)倍',
    ],
  ),
  'ko': Words(
    // No end check: Korean joins particles to the word ("두 대만").
    // 하루 alone is left out on purpose, because 하루 데이터 means per day.
    // 하루 안에 (within a day) is caught.
    bare: [
      r'(?<![\p{L}])(?:한|두|세|네|다섯|여섯|일곱|여덟|아홉|열|스무|몇)\s?'
          r'(?:시간|달|개월|주일|주간|주|명|대|기가|메가|GB|MB)',
      r'(?<![\p{L}])(?:며칠|이틀|사흘|나흘|닷새|엿새|이레|열흘|보름|일주일|이주일)',
      r'(?<![\p{L}])(?:두|세|네|다섯|열|몇)\s?배',
      r'(?<![\p{L}])몇\s?일',
      r'(?<![\p{L}])하루\s?(?:안에|만에|이내)',
    ],
  ),
  'es': Words(
    counts: [
      'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho', 'nueve', //
      'diez', 'once', 'doce', 'quince', 'veinte', 'treinta', 'cuarenta',
      'cincuenta', 'sesenta', 'cien', 'mil', 'unos', 'unas', 'algunos',
      'algunas', 'varios', 'varias', 'pocos', 'pocas', 'un par de',
      'una docena de', 'medio', 'media',
    ],
    ranges: ['o', 'a', 'y'],
    units: [
      'horas?', 'd[ií]as?', 'semanas?', 'mes', 'meses', 'a[ñn]os?', //
      'gigabytes?', 'gigas?', 'megabytes?', 'megas?', 'GB', 'MB',
      'dispositivos?', 'tel[ée]fonos?', 'celulares?', 'm[óo]viles?',
      'amigos?', 'amigas?', 'personas?', 'invitaci[óo]n', 'invitaciones',
      'referidos?',
    ],
    ones: [
      'un solo', 'una sola', 's[óo]lo un', 's[óo]lo una', 'un [úu]nico', //
      'una [úu]nica', 'solamente un', 'solamente una',
    ],
    singles: ['un', 'una'],
    // Not "día": "{max} al día" means per day.
    singleUnits: [
      'hora', 'semana', 'mes', 'a[ñn]o', 'gigabyte', 'giga', 'megabyte', //
      'mega', 'GB', 'MB',
    ],
    extraOne: [r'(?:en|durante|dentro de|por|tras)\s+un\s+d[ií]a'],
    extra: [
      'el doble', 'el triple', 'dobles?', //
      r'(?:dos|tres|cuatro|cinco|diez)\s+veces',
    ],
  ),
  'id': Words(
    counts: [
      'dua', 'tiga', 'empat', 'lima', 'enam', 'tujuh', 'delapan', //
      'sembilan', 'sepuluh', 'sebelas', 'dua belas', 'lima belas',
      'dua puluh', 'tiga puluh', 'empat puluh', 'lima puluh', 'seratus',
      'seribu', 'beberapa', 'sejumlah', 'setengah', 'selusin', 'sepasang',
      'puluhan', 'ratusan', 'ribuan',
    ],
    ranges: ['atau', 'sampai', 'hingga', 'dan'],
    units: [
      'jam', 'hari', 'minggu', 'pekan', 'bulan', 'tahun', 'gigabyte', //
      'gigabita', 'giga', 'megabyte', 'megabita', 'mega', 'GB', 'MB',
      'perangkat', 'ponsel', 'HP', 'telepon', 'teman', 'orang', 'undangan',
      'ajakan',
    ],
    // Not "salah satu" (one of).
    ones: [r'(?<!salah\s)satu', 'hanya satu', 'cuma satu', 'sebuah'],
    // "sehari" means both one day and per day, so it is left out.
    extraOne: ['sejam', 'seminggu', 'sepekan', 'sebulan', 'setahun'],
    extra: [
      r'(?:dua|tiga|empat|lima|sepuluh)\s+kali(?:\s+lipat)?', //
      'berlipat ganda',
    ],
  ),
  'vi': Words(
    counts: [
      'hai', 'ba', 'bốn', 'năm', 'sáu', 'bảy', 'tám', 'chín', 'mười', //
      'mười một', 'mười hai', 'mười lăm', 'hai mươi', 'ba mươi',
      'bốn mươi', 'năm mươi', 'trăm', 'nghìn', 'ngàn', 'vài', 'một vài',
      'một số', 'vài ba', 'đôi ba', 'dăm', 'nửa', 'chục',
    ],
    ranges: ['hoặc', 'hay', 'đến', 'tới', 'và'],
    // Not "máy" alone: "máy chủ" is a server. Not "người dùng" (users).
    units: [
      'giờ', 'tiếng', 'ngày', 'tuần', 'tháng', 'năm', 'gigabyte', 'GB', //
      'MB', 'megabyte', 'thiết bị', 'điện thoại', 'bạn bè',
      r'người(?!\s+dùng)', 'lời mời', 'lượt mời',
    ],
    ones: ['chỉ một', 'duy nhất một'],
    singles: ['một'],
    // Not "ngày": "{max} một ngày" means per day.
    singleUnits: [
      'giờ', 'tiếng', 'tuần', 'tháng', 'năm', 'gigabyte', 'GB', 'MB', //
      'thiết bị', 'điện thoại',
    ],
    extraOne: [r'trong(?:\s+vòng)?\s+một\s+ngày'],
    extra: [
      r'gấp\s+(?:đôi|hai|ba|bốn|năm|mười)(?:\s+lần)?', //
      r'(?:hai|ba|bốn|năm|mười)\s+lần',
      r'nửa\s+(?:ngày|giờ|tiếng|tháng|năm|tuần)',
    ],
  ),
  'uk': Words(
    counts: [
      'два', 'дві', 'двох', 'двом', 'три', 'трьох', 'трьом', 'чотири', //
      'чотирьох', "п'ять", "п'яти", 'шість', 'шести', 'сім', 'семи',
      'вісім', 'восьми', "дев'ять", "дев'яти", 'десять', 'десяти',
      'одинадцять', 'дванадцять', "п'ятнадцять", 'двадцять', 'двадцяти',
      'тридцять', 'тридцяти', 'сорок', "п'ятдесят", 'сто', r'тисяч\p{L}*',
      'пару', 'пара', 'пари', 'парі', 'кілька', 'кількох', 'декілька',
      'декількох', 'двоє', 'троє', 'четверо', "п'ятеро", 'півтора',
      'півтори',
    ],
    ranges: ['або', 'чи', 'до'],
    units: [
      r'годин\p{L}*', r'дн\p{L}*', 'день', 'діб', 'доба', 'доби', 'добу', //
      r'тижн\p{L}*', 'тиждень', r'місяц\p{L}*', r'рок\p{L}*', 'рік',
      r'гігабайт\p{L}*', r'мегабайт\p{L}*', r'гіг\p{L}*', 'ГБ', 'МБ',
      'Гб', 'Мб', r'пристр\p{L}*', r'телефон\p{L}*', r'друз\p{L}*',
      'друга?', 'людей', 'осіб', 'особи', r'запрошен\p{L}*',
    ],
    ones: [
      'один', 'одна', 'одне', 'одного', 'одну', 'одному', 'одній', //
      r'єдин\p{L}*',
    ],
    extraOne: [
      // A bare noun after a preposition means one: "протягом доби",
      // "через тиждень", "на місяць". "на день" means per day.
      r'протягом\s+(?:дня|доби|тижня|місяця|року|години)',
      r'через\s+(?:день|добу|тиждень|місяць|рік|годину)',
      r'(?:за|на)\s+(?:тиждень|місяць|рік|годину|добу)',
      // "доба" alone is one day and night, unless a number or a
      // placeholder comes before it.
      r'(?<![\p{Nd}\uFFFC][\s\u00a0]{0,3})доб(?:а|у)',
    ],
    extra: [
      'вдвічі', 'удвічі', 'втричі', 'утричі', 'вчетверо', 'учетверо', //
      r"у?\s*(?:два|три|чотири|п'ять|десять)\s+раз\p{L}*",
      r'пів(?:години|дня|доби|тижня|місяця|року)',
    ],
  ),
  'uz': Words(
    counts: [
      'ikki', 'uch', 'toʻrt', 'besh', 'olti', 'yetti', 'sakkiz', 'toʻqqiz', //
      'oʻn', 'oʻn bir', 'oʻn ikki', 'oʻn besh', 'yigirma', 'oʻttiz', 'qirq',
      'ellik', 'oltmish', 'yuz', 'ming', 'bir necha', 'bir nechta',
      'bir-ikki', 'ikki-uch', 'yarim', 'oʻnlab', 'yuzlab',
    ],
    ranges: ['yoki', 'yo'],
    units: [
      r'soat\p{L}*', r'kun\p{L}*', r'hafta\p{L}*', r'oy\p{L}*', //
      r'yil\p{L}*', r'gigabayt\p{L}*', r'megabayt\p{L}*', 'GB', 'MB',
      r'qurilma\p{L}*', r'telefon\p{L}*', r'doʻst\p{L}*', 'kishi',
      r'odam\p{L}*', r'taklif\p{L}*',
    ],
    ones: ['faqat bir', 'bitta', 'birgina', 'yagona'],
    singles: ['bir'],
    // Not "kun": "bir kun" also means "some day".
    singleUnits: [
      r'soat\p{L}*', r'hafta\p{L}*', 'oy', 'oylik', 'oyga', 'yil', //
      'yillik', 'GB', 'MB', r'gigabayt\p{L}*',
    ],
    extraOne: [r'bir\s+kun\s+ichida', 'bir kunda'],
    extra: [
      r'(?:ikki|uch|toʻrt|besh|oʻn)\s+(?:marta|barobar|baravar|karra)',
      'ikki barobar',
      'ikki baravar',
    ],
  ),
  'zh': Words(
    bare: [
      // A numeral right before a counter: 几天, 两小时, 一周, 三个月, 半年,
      // 一台. Not after 每 (every) or 第 (ordinal), and not 一部分 (part).
      r'(?<![每第])(?:几|数|半|[一二两三四五六七八九十百千]+)\s?'
          r'(?:个?小时|天|日|周|星期|个?月|年|台|部(?!分)|位|人|个?朋友|'
          r'个?好友|个?设备|GB|MB)',
      r'(?:两|二|三|四|五|十|几|数)倍',
    ],
  ),
};

/// Japanese writes "per day" with a digit: 1日の, 1 日 {amount}, 1日最大.
/// That names the window the allowance refills in, not an amount, so it
/// is taken out before the checks. Any other count of days still fails,
/// and so does 1日 in any other position (1日以内, 1日後, 1日間).
final _jaPerDay = _re(r'(?<!\p{Nd})[1１一]\s?日(?=\s*(?:の|最大|\uFFFC))');

// The checks.

/// Stands in for a placeholder such as {amount}. A number the backend
/// sends is the right way to show one, so it never counts.
const placeholder = '\uFFFC';

RegExp _re(String pattern) =>
    RegExp(pattern, unicode: true, caseSensitive: false);

/// A run of digits in any script, with its separators: 72, ۷۲, 1.1.1.1.
final _digitRun = _re(r'\p{Nd}+(?:[.,٫٬]\p{Nd}+)*');

/// The zero of each digit script the app's languages use.
const _zeros = [0x30, 0x660, 0x6F0, 0x966, 0xFF10];

/// A digit run in ASCII, so ۷۲ and 72 compare equal. A digit from a
/// script not listed in [_zeros] becomes ?, so it can never match an
/// allowlist entry and is always reported.
String fold(String run) {
  final out = StringBuffer();
  for (final rune in run.runes) {
    if (rune == 0x2C || rune == 0x66C) {
      out.write(',');
      continue;
    }
    if (rune == 0x2E || rune == 0x66B) {
      out.write('.');
      continue;
    }
    final zero = _zeros.where((z) => rune >= z && rune <= z + 9);
    out.write(
      zero.isEmpty ? '?' : String.fromCharCode(0x30 + rune - zero.first),
    );
  }
  return out.toString();
}

/// One piece of an .arb message with the ICU syntax taken out.
class Piece {
  const Piece(this.text, this.selector);

  /// The text, with every placeholder replaced by [placeholder].
  final String text;

  /// The plural or select branch this text sits in ("one", "=1",
  /// "other"), or null outside any branch.
  final String? selector;

  /// "one" or "two" when the branch fixes the count at one or two.
  String? get countWord => switch (selector) {
    'one' || '=1' => 'one',
    'two' || '=2' => 'two',
    _ => null,
  };
}

/// Splits an .arb message into its plain text and the text of each plural
/// or select branch, so "{count, plural, =1{1 invite}}" is checked as the
/// text "1 invite" in the =1 branch.
List<Piece> pieces(String message) => _IcuReader(message).read();

class _IcuReader {
  _IcuReader(this.s);

  final String s;
  int i = 0;
  final List<Piece> out = [];

  List<Piece> read() {
    final top = StringBuffer();
    while (i < s.length) {
      top.write(_text());
      if (i < s.length) {
        i++; // A stray closing brace.
      }
    }
    out.insert(0, Piece(top.toString(), null));
    return out;
  }

  /// Text up to the closing brace of the current branch.
  String _text() {
    final buffer = StringBuffer();
    while (i < s.length && s[i] != '}') {
      if (s[i] == '{') {
        i++;
        _argument();
        buffer.write(' $placeholder ');
      } else {
        buffer.write(s[i]);
        i++;
      }
    }
    return buffer.toString();
  }

  /// After an opening brace: {name} or {name, plural, one{...} other{...}}.
  void _argument() {
    final close = s.indexOf('}', i);
    final comma = s.indexOf(',', i);
    if (comma < 0 || (close >= 0 && close < comma)) {
      i = close < 0 ? s.length : close + 1;
      return;
    }
    final kindEnd = s.indexOf(',', comma + 1);
    if (kindEnd < 0) {
      i = s.length;
      return;
    }
    i = kindEnd + 1;
    while (i < s.length) {
      while (i < s.length && s[i].trim().isEmpty) {
        i++;
      }
      if (i >= s.length) return;
      if (s[i] == '}') {
        i++;
        return;
      }
      final open = s.indexOf('{', i);
      if (open < 0) {
        i = s.length;
        return;
      }
      final selector = s.substring(i, open).trim();
      i = open + 1;
      out.add(Piece(_text(), selector));
      i++; // The branch's closing brace.
    }
  }
}

class _Rule {
  const _Rule(this.pattern, {this.allowedIn});
  final RegExp pattern;

  /// "one" or "two": the plural branch where this pattern is the count's
  /// own value and so is allowed.
  final String? allowedIn;
}

const _start = r'(?<![\p{L}\p{M}])';
const _end = r'(?![\p{L}\p{M}])';
const _gap = r'[\s\u00a0\u200c\-]+';

String _any(List<String> words) => words.join('|');

final Map<String, List<_Rule>> _rules = {
  for (final entry in wordLists.entries) entry.key: _rulesFor(entry.value),
};

List<_Rule> _rulesFor(Words w) {
  final rules = <_Rule>[];
  if (w.counts.isNotEmpty) {
    final range = w.ranges.isEmpty
        ? ''
        : '(?:$_gap(?:${_any(w.ranges)})$_gap\\S+)?';
    rules.add(
      _Rule(
        _re(
          '$_start(?:${_any(w.counts)})$range$_gap'
          '(?:${_any(w.units)})$_end',
        ),
      ),
    );
  }
  if (w.ones.isNotEmpty) {
    rules.add(
      _Rule(
        _re('$_start(?:${_any(w.ones)})$_gap(?:${_any(w.units)})$_end'),
        allowedIn: 'one',
      ),
    );
  }
  if (w.singles.isNotEmpty) {
    rules.add(
      _Rule(
        _re(
          '$_start(?:${_any(w.singles)})$_gap'
          '(?:${_any(w.singleUnits)})$_end',
        ),
        allowedIn: 'one',
      ),
    );
  }
  for (final p in w.extra) {
    rules.add(_Rule(_re('$_start(?:$p)$_end')));
  }
  for (final p in w.extraOne) {
    rules.add(_Rule(_re('$_start(?:$p)$_end'), allowedIn: 'one'));
  }
  for (final p in w.extraTwo) {
    rules.add(_Rule(_re('$_start(?:$p)$_end'), allowedIn: 'two'));
  }
  for (final p in w.bare) {
    rules.add(_Rule(_re(p)));
  }
  return rules;
}

/// Every number in one .arb value that is not allowed, as written.
List<String> scanArbValue(String lang, String key, String value) {
  final hits = <String>[];
  for (final piece in pieces(value)) {
    var text = piece.text;
    if (lang == 'ja') text = text.replaceAll(_jaPerDay, ' ');

    for (final m in _digitRun.allMatches(text)) {
      final number = fold(m[0]!);
      // In "=1{1 invite}" the 1 is the count itself.
      if (piece.selector == '=$number') continue;
      if (allowedArbDigits[key]?.numbers.contains(number) ?? false) continue;
      hits.add(m[0]!);
    }

    // flutter gen-l10n turns both one and =1 into Intl's one case, and in
    // Russian and Ukrainian that case also renders 21, 31, 101 and so on.
    // So no branch fixes the count at one in those two.
    final countWord = (lang == 'ru' || lang == 'uk') && piece.countWord == 'one'
        ? null
        : piece.countWord;
    for (final rule in _rules[lang] ?? const <_Rule>[]) {
      if (rule.allowedIn != null && rule.allowedIn == countWord) {
        continue;
      }
      for (final m in rule.pattern.allMatches(text)) {
        final phrase = m[0]!.toLowerCase();
        if (allowedArbWords[key]?.phrases.contains(phrase) ?? false) continue;
        hits.add(m[0]!);
      }
    }
  }
  return hits;
}

/// Problems in the .arb files under [root].
List<String> scanArbFiles(String root) {
  final problems = <String>[];
  final usedDigits = <String, Set<String>>{};
  final usedWords = <String, Set<String>>{};
  for (final lang in languages) {
    final path = 'lib/l10n/app_$lang.arb';
    final file = File('$root/$path');
    final lines = file.readAsLinesSync();
    final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    arb.forEach((key, value) {
      if (key.startsWith('@') || value is! String) return;
      final line = lines.indexWhere((l) => l.contains('"$key"')) + 1;
      for (final hit in scanArbValue(lang, key, value)) {
        problems.add('$path:$line  $key [$lang]  "$hit"');
      }
      // Remember which allowlist entries were needed.
      for (final piece in pieces(value)) {
        for (final m in _digitRun.allMatches(piece.text)) {
          final number = fold(m[0]!);
          if (allowedArbDigits[key]?.numbers.contains(number) ?? false) {
            (usedDigits[key] ??= {}).add(number);
          }
        }
        for (final phrase in allowedArbWords[key]?.phrases ?? <String>{}) {
          if (piece.text.toLowerCase().contains(phrase)) {
            (usedWords[key] ??= {}).add(phrase);
          }
        }
      }
    });
  }
  allowedArbDigits.forEach((key, entry) {
    for (final n in entry.numbers.difference(usedDigits[key] ?? {})) {
      problems.add('allowedArbDigits: $key no longer has $n. Remove it.');
    }
  });
  allowedArbWords.forEach((key, entry) {
    for (final p in entry.phrases.difference(usedWords[key] ?? {})) {
      problems.add('allowedArbWords: $key no longer has "$p". Remove it.');
    }
  });
  return problems;
}

/// Problems in the Android string resources under [root].
List<String> scanAndroidStrings(String root) {
  final problems = <String>[];
  final res = Directory('$root/android/app/src/main/res');
  if (!res.existsSync()) return problems;
  final element = RegExp(
    r'<(?:string|item)\b[^>]*>([\s\S]*?)</(?:string|item)>',
  );
  final format = RegExp(r'%(?:\d+\$)?[sdf]');
  for (final dir in res.listSync().whereType<Directory>()) {
    final file = File('${dir.path}/strings.xml');
    if (!file.existsSync()) continue;
    final rel = file.path.substring(root.length + 1);
    for (final m in element.allMatches(file.readAsStringSync())) {
      final text = m[1]!.replaceAll(format, ' ');
      final hits = [
        ..._digitRun.allMatches(text).map((d) => d[0]!),
        for (final lang in ['en', 'fa'])
          for (final rule in _rules[lang]!)
            ...rule.pattern.allMatches(text).map((w) => w[0]!),
      ];
      for (final hit in hits) {
        problems.add('$rel  "${m[1]}"  "$hit"');
      }
    }
  }
  return problems;
}

/// Dart source split into code, with comments and string text blanked, and
/// the string literals, with each interpolation replaced by [placeholder].
/// Code inside an interpolation stays in the code. Offsets are kept, so a
/// position in the code is the same position in the file.
({String code, List<({int offset, String text})> strings}) lexDart(String src) {
  final code = StringBuffer();
  final strings = <({int offset, String text})>[];
  var i = 0;

  void blank(int n) {
    for (var k = 0; k < n && i < src.length; k++, i++) {
      code.write(src[i] == '\n' ? '\n' : ' ');
    }
  }

  void keep(int n) {
    for (var k = 0; k < n && i < src.length; k++, i++) {
      code.write(src[i]);
    }
  }

  bool identChar(String c) => RegExp(r'[\w$]').hasMatch(c);

  while (i < src.length) {
    if (src.startsWith('//', i)) {
      while (i < src.length && src[i] != '\n') {
        blank(1);
      }
      continue;
    }
    if (src.startsWith('/*', i)) {
      var depth = 0;
      do {
        if (src.startsWith('/*', i)) {
          depth++;
          blank(2);
        } else if (src.startsWith('*/', i)) {
          depth--;
          blank(2);
        } else {
          blank(1);
        }
      } while (depth > 0 && i < src.length);
      continue;
    }
    final c = src[i];
    final raw =
        c == 'r' &&
        i + 1 < src.length &&
        (src[i + 1] == "'" || src[i + 1] == '"') &&
        (i == 0 || !identChar(src[i - 1]));
    if (c == "'" || c == '"' || raw) {
      final start = i;
      if (raw) keep(1);
      final quote = src[i];
      final close = src.startsWith(quote * 3, i) ? quote * 3 : quote;
      keep(close.length);
      final text = StringBuffer();
      while (i < src.length && !src.startsWith(close, i)) {
        if (!raw && src[i] == r'\') {
          text.write(src.substring(i, (i + 2).clamp(0, src.length)));
          blank(2);
          continue;
        }
        if (!raw && src.startsWith(r'${', i)) {
          blank(2);
          var depth = 1;
          while (i < src.length && depth > 0) {
            if (src[i] == '{') depth++;
            if (src[i] == '}') depth--;
            if (depth > 0) {
              keep(1);
            } else {
              blank(1);
            }
          }
          text.write(placeholder);
          continue;
        }
        if (!raw &&
            src[i] == r'$' &&
            i + 1 < src.length &&
            RegExp(r'[A-Za-z_]').hasMatch(src[i + 1])) {
          blank(1);
          while (i < src.length && RegExp(r'\w').hasMatch(src[i])) {
            blank(1);
          }
          text.write(placeholder);
          continue;
        }
        text.write(src[i]);
        blank(1);
      }
      keep(close.length);
      strings.add((offset: start, text: text.toString()));
      continue;
    }
    keep(1);
  }
  return (code: code.toString(), strings: strings);
}

/// Rules for Dart code, run on whole files so a line break does not hide
/// a hit.
final _codeRules = <String, RegExp>{
  // A shift by 20, 30 or 40, or a product with 1024 in it, read whole:
  // "250 * 1024 * 1024", "1024 * 1024 * 250", "16 * 1024", "gb << 30".
  'byte-size math': RegExp(
    r'(?<![\w.])[\w.]+\s*<<\s*(?:20|30|40)\b'
    r'|(?<![\w.])(?:[\w.]+\s*\*\s*)*1024(?:\s*\*\s*[\w.]+)+'
    r'|(?<![\w.])(?:[\w.]+\s*\*\s*)+1024\b',
  ),
  'literal of a million or more': RegExp(
    r'(?<![\w.$])\d(?:_*\d){6,}(?![\w.])'
    r'|(?<![\w.$])\d+(?:\.\d+)?[eE]\+?(?:[6-9]|\d{2,})(?![\w.])',
  ),
  'long Duration literal': RegExp(
    r'Duration\s*\([^()]*\b(?:days|hours)\s*:\s*\d[^()]*\)',
  ),
  'day or hour comparison': RegExp(
    r'\.in(?:Days|Hours)\s*(?:[<>]=?|==)\s*(?:[2-9]|\d{2,})\b'
    r'|\b(?:[2-9]|\d{2,})\s*(?:[<>]=?|==)\s*[\w.]+\.in(?:Days|Hours)\b',
  ),
};

/// Words that make a constant's name a service rule. A declaration whose
/// name has one of these words (split on camelCase and _) and whose value
/// is a number or a Duration is a hit: "confirmDays = 2",
/// "freeDailyMb = 5120", "deviceLimit = 3".
const policyNameWords = {
  'allowance', 'bonus', 'bytes', 'cap', 'claim', 'confirm', 'daily', 'day', //
  'days', 'device', 'devices', 'free', 'friend', 'friends', 'gb', 'gib',
  'gift', 'grace', 'hour', 'hours', 'invite', 'invites', 'kb', 'limit',
  'limits', 'linked', 'mb', 'mib', 'plan', 'premium', 'price', 'promo',
  'quota', 'referral', 'retention', 'reward', 'subscription', 'tb',
  'trial', 'window',
};

/// A declaration with a number or a Duration as its value.
final _numberDeclaration = RegExp(
  r'(?:\b(?:const|final|var)\s+(?:[\w<>?]+\s+)?|\b(?:int|double|num)\??\s+'
  r'|\bget\s+|\bthis\.)'
  r'([A-Za-z_]\w*)\s*=>?\s*'
  r'(?:const\s+)?'
  r'(Duration\s*\([^()]*\)|[\d_.]+(?:\s*(?:<<|>>|[*+\-/])\s*[\d_.]+)*)'
  r'\s*[;,})]',
);

/// A fallback number after ??, read with the name on its left:
/// "s.claimWindowHours ?? 72".
final _numberFallback = RegExp(
  r'([A-Za-z_]\w*)\s*\?\?\s*([1-9][\d_]*)(?![\w.])',
);

/// The policy words in a Dart name: "freeDailyMb" has free, daily and mb.
Set<String> policyWordsIn(String name) {
  final parts = name
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
      .toLowerCase()
      .split('_');
  // A layout or paging size is never a service rule: dayLabelWidth,
  // capHeight, freeSpacePadding, pageLimit.
  if (parts.any(layoutNameWords.contains)) return {};
  return parts.where(policyNameWords.contains).toSet();
}

/// Name parts that make a number a layout or paging size.
const layoutNameWords = {
  'width', 'height', 'padding', 'margin', 'spacing', 'gap', 'radius', //
  'inset', 'offset', 'elevation', 'opacity', 'font', 'label', 'page',
};

/// A value that is only zeros: a starting value such as
/// "this.bonusBytes = 0", not a rule.
final _zero = RegExp(r'^[0_.]+$');

/// Policy-named declarations and ?? fallbacks in blanked [code], as
/// "name = value" or "name ?? value".
List<({int offset, String text})> policyNamedNumbers(String code) => [
  for (final m in _numberDeclaration.allMatches(code))
    if (policyWordsIn(m[1]!).isNotEmpty && !_zero.hasMatch(m[2]!))
      (
        offset: m.start,
        text: '${m[1]} = ${m[2]}'.replaceAll(RegExp(r'\s+'), ' ').trim(),
      ),
  for (final m in _numberFallback.allMatches(code))
    if (policyWordsIn(m[1]!).isNotEmpty)
      (offset: m.start, text: '${m[1]} ?? ${m[2]}'),
];

/// One pattern for a call that passes a whole-number literal to a message
/// whose number placeholder has a policy name, such as {days} or {hours}:
/// "deleteAccountConfirmRetention(30)". The messages are read from the
/// @-metadata in [en], the parsed app_en.arb. Null when there are none.
RegExp? placeholderCallPattern(Map<String, dynamic> en) {
  final names = <String>[
    for (final e in en.entries)
      if (e.key.startsWith('@') && e.value is Map)
        if (((e.value as Map)['placeholders'] as Map?)?.entries.any(
              (p) =>
                  p.value is Map &&
                  (p.value as Map)['type'] == 'int' &&
                  policyWordsIn(p.key as String).isNotEmpty,
            ) ??
            false)
          e.key.substring(1),
  ];
  if (names.isEmpty) return null;
  // The literal may be any argument. An earlier argument may hold one
  // level of brackets: "inviteHowItWorksBody(format(x), 2)".
  return RegExp(
    '\\b(${names.join('|')})\\s*\\('
    '(?:(?:[^()]|\\([^()]*\\))*,)?\\s*([1-9][\\d_]*)\\s*[,)]',
  );
}

/// The calls in blanked [code] that [call] finds, as "name(value)".
List<({int offset, String text})> literalPlaceholderArgs(
  RegExp? call,
  String code,
) => [
  if (call != null)
    for (final m in call.allMatches(code))
      (offset: m.start, text: '${m[1]}(${m[2]})'),
];

/// A number with a unit inside a Dart string literal: '250 MB', '3 days'.
final _numberWithUnit = _re(
  r'\p{Nd}+(?:[.,]\p{Nd}+)?\s?'
  r'(?:GB|MB|KB|TB|GiB|MiB|gigabytes?|megabytes?|hours?|hrs?|days?|weeks?|'
  r'months?|years?|devices?|phones?|friends?|invites?|ساعت|روز|'
  r'گیگ\p{L}*|مگ\p{L}*|دستگاه|دوست)'
  r'(?![\p{L}])',
);

/// Problems in the Dart files under [root]/lib.
List<String> scanDart(String root) {
  final problems = <String>[];
  final seen = <String, List<String>>{};
  final files =
      Directory('$root/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.dart') &&
                !f.path.contains('/l10n/generated/'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final call = placeholderCallPattern(
    jsonDecode(File('$root/lib/l10n/app_en.arb').readAsStringSync())
        as Map<String, dynamic>,
  );

  for (final file in files) {
    final rel = file.path.substring(root.length + 1);
    final src = file.readAsStringSync();
    final lexed = lexDart(src);
    int lineOf(int offset) =>
        '\n'.allMatches(src.substring(0, offset)).length + 1;

    final hits = <({int offset, String rule, String text})>[];
    _codeRules.forEach((rule, pattern) {
      for (final m in pattern.allMatches(lexed.code)) {
        final text = m[0]!.replaceAll(RegExp(r'\s+'), ' ').trim();
        hits.add((offset: m.start, rule: rule, text: text));
      }
    });
    for (final d in policyNamedNumbers(lexed.code)) {
      hits.add((offset: d.offset, rule: 'policy-named number', text: d.text));
    }
    for (final d in literalPlaceholderArgs(call, lexed.code)) {
      hits.add((offset: d.offset, rule: 'literal placeholder', text: d.text));
    }
    hits.sort((a, b) => a.offset.compareTo(b.offset));

    final allowed = allowedCode[rel];
    final left = [...?allowed?.hits];
    for (final hit in hits) {
      final index = left.indexOf(hit.text);
      if (index >= 0) {
        left.removeAt(index);
        (seen[rel] ??= []).add(hit.text);
        continue;
      }
      problems.add('$rel:${lineOf(hit.offset)}  ${hit.rule}  "${hit.text}"');
    }
    for (final stale in left) {
      problems.add(
        'allowedCode: $rel no longer has "$stale". Remove it from the list.',
      );
    }

    for (final literal in lexed.strings) {
      final found = [
        ..._numberWithUnit.allMatches(literal.text).map((m) => m[0]!),
        for (final rule in _rules['en']!)
          ...rule.pattern.allMatches(literal.text).map((m) => m[0]!),
      ];
      for (final hit in found) {
        problems.add(
          '$rel:${lineOf(literal.offset)}  string literal  "$hit" in '
          '"${literal.text}"',
        );
      }
    }
  }

  for (final rel in allowedCode.keys) {
    if (!File('$root/$rel').existsSync()) {
      problems.add('allowedCode: $rel does not exist. Remove it.');
    }
  }
  return problems;
}

const _howToFix =
    'A number that describes what the service gives or requires must come '
    'from the backend. Add a field to the backend response, parse it as '
    'optional, show it through a placeholder, and add a second string '
    'that names no number for when the field is missing. See the header '
    'of test/no_policy_numbers_test.dart. Only text that is not a service '
    'rule at all (a copyright year, a DNS default, a licence version, '
    'app-side timing) belongs on an allowlist, with a reason.';

void main() {
  // flutter test runs from the package root.
  final root = Directory.current.path;

  group('the patterns still catch what they are for', () {
    // Each of these must be reported. If a pattern is weakened so that
    // one passes, this group fails before the real scan can pass quietly.
    const mustCatch = <List<String>>[
      ['en', 'Enter it in your first 72 hours'],
      ['en', 'uses the VPN for a couple of days'],
      ['en', 'for a couple days'],
      ['en', 'in a day or two'],
      ['en', 'half a day'],
      ['en', 'within a week'],
      ['en', 'for an hour'],
      ['en', 'up to three devices'],
      ['en', 'on one device'],
      ['en', 'on a single device'],
      ['en', 'a two-day wait'],
      ['en', 'twice the data'],
      ['en', 'four times the data'],
      ['en', '250 MB'],
      ['en', 'up to 10 GB a day'],
      ['en', '７２ hours'],
      ['de', 'ein paar Tage'],
      ['de', 'nur ein Gerät'],
      ['de', 'ein einziges Gerät'],
      ['de', 'eine Woche'],
      ['de', 'ein zweitägiger Test'],
      ['de', 'doppelt so viele Daten'],
      ['fr', 'quelques jours'],
      ['fr', 'un seul appareil'],
      ['fr', 'deux fois plus'],
      ['fr', 'une semaine'],
      ['pt', 'alguns dias'],
      ['pt', 'um único aparelho'],
      ['pt', 'apenas um dispositivo'],
      ['pt', 'o dobro de dados'],
      ['ru', 'пару дней'],
      ['ru', 'три устройства'],
      ['ru', 'одно устройство'],
      ['ru', 'трое суток'],
      ['ru', 'в течение суток'],
      ['ru', 'сутки'],
      ['ru', 'через неделю'],
      ['ru', 'в два раза больше'],
      ['tr', 'birkaç gün'],
      ['tr', 'tek cihaz'],
      ['tr', 'bir hafta'],
      ['tr', 'iki kat veri'],
      ['tr', '10 GB'],
      ['fa', 'آن را در ۷۲ ساعت اول وارد کنید'],
      ['fa', 'چند روز'],
      ['fa', 'سه‌روزه'],
      ['fa', 'یک دستگاه'],
      ['fa', 'نیم ساعت'],
      ['fa', 'دو برابر'],
      ['fa', '۲۵۰ مگابایت'],
      ['ar', 'أدخله خلال أول ٧٢ ساعة'],
      ['ar', 'لبضعة أيام'],
      ['ar', 'يومين'],
      ['ar', 'جهاز واحد'],
      ['ar', 'خلال أسبوع'],
      ['ar', 'خلال ساعة'],
      ['ar', 'ثلاثة أيام'],
      ['ar', 'ضعف البيانات'],
      ['ur', 'اسے پہلے ۷۲ گھنٹوں میں درج کریں'],
      ['ur', 'چند دن'],
      ['ur', 'ایک ڈیوائس'],
      ['ur', 'دوگنا ڈیٹا'],
      ['hi', 'इसे पहले 72 घंटों में डालें'],
      ['hi', 'कुछ दिन'],
      ['hi', '१० जीबी'],
      ['hi', 'एक डिवाइस'],
      ['hi', 'दोगुना डेटा'],
      ['ja', 'インストールから72時間以内'],
      ['ja', '数日'],
      ['ja', '３日間'],
      ['ja', '1日間'],
      ['ja', '1日以内'],
      ['ja', '一日以内'],
      ['ja', '1日後'],
      ['ja', '一台だけ'],
      ['ja', '二倍'],
      ['ko', '설치 후 72시간 안에'],
      ['ko', '며칠간'],
      ['ko', '두 시간'],
      ['ko', '한 달'],
      ['ko', '한 시간'],
      ['ko', '일주일'],
      ['ko', '기기 한 대'],
      ['ko', '두 배'],
      ['es', 'Ingrésalo en tus primeras 72 horas'],
      ['es', 'unos días'],
      ['es', 'dos días'],
      ['es', 'un solo dispositivo'],
      ['es', 'una semana'],
      ['es', 'el doble de datos'],
      ['es', 'tres veces más'],
      ['es', 'durante un día'],
      ['id', 'Masukkan dalam 72 jam pertama'],
      ['id', 'beberapa hari'],
      ['id', 'dua perangkat'],
      ['id', 'satu hari'],
      ['id', 'seminggu'],
      ['id', 'dua kali lipat'],
      ['vi', 'Nhập trong 72 giờ đầu'],
      ['vi', 'vài ngày'],
      ['vi', 'hai thiết bị'],
      ['vi', 'một tuần'],
      ['vi', 'gấp đôi dữ liệu'],
      ['vi', 'trong vòng một ngày'],
      ['uk', 'Введіть його протягом перших 72 годин'],
      ['uk', 'кілька днів'],
      ['uk', "п'ять годин"],
      ['uk', 'один пристрій'],
      ['uk', 'протягом доби'],
      ['uk', 'через тиждень'],
      ['uk', 'вдвічі більше'],
      ['uk', 'доба'],
      ['uz', 'Dastlabki 72 soat ichida kiriting'],
      ['uz', 'bir necha kun'],
      ['uz', 'ikki qurilma'],
      ['uz', 'bir hafta'],
      ['uz', 'ikki barobar'],
      ['uz', 'bir kun ichida'],
      ['zh', '安装后 72 小时内输入'],
      ['zh', '两天'],
      ['zh', '几个小时'],
      ['zh', '一周'],
      ['zh', '半年'],
      ['zh', '三台设备'],
      ['zh', '两倍流量'],
      // A word for one next to a size: the reward is one GB per friend.
      ['en', 'Get a gigabyte for each friend'],
      ['en', 'Get a GB for each friend'],
      ['de', 'ein Gigabyte pro Freund'],
      ['fr', 'un gigaoctet par ami'],
      ['pt', 'um gigabyte por amigo'],
      ['tr', 'bir GB'],
      ['fa', 'یک گیگ هدیه بگیرید'],
      ['fa', 'یک گیگابایت به ازای هر دوست'],
      ['ar', 'غيغابايت واحد لكل صديق'],
      ['ur', 'ایک جی بی'],
      ['hi', 'एक GB'],
      ['ko', '한 기가'],
      ['es', 'un gigabyte por amigo'],
      ['id', 'satu GB'],
      ['vi', 'một GB'],
      ['uk', 'один гігабайт'],
      ['uz', 'bir GB'],
      ['zh', '一 GB'],
      // "A few days" and "within a day" in more forms.
      ['ur', 'کچھ دن وی پی این استعمال کرے'],
      ['ar', 'لأيام قليلة'],
      ['ar', 'أيام قليلة'],
      ['ko', '몇 일'],
      ['ko', '몇일'],
      ['ko', '하루 안에'],
      ['fa', 'ظرف یک روز'],
      ['tr', 'bir gün içinde'],
      // In Russian and Ukrainian the one and =1 branches also render 21
      // and 31.
      [
        'ru',
        '{days, plural, one{в течение суток} other{в течение {days} дней}}',
      ],
      [
        'ru',
        '{days, plural, =1{в течение суток} other{в течение {days} дней}}',
      ],
      ['uk', '{days, plural, one{протягом доби} other{протягом {days} днів}}'],
      // A number in the other branch of a plural is still a number.
      ['en', '{count, plural, =1{one invite} other{{count} invites, 3 days}}'],
    ];
    for (final c in mustCatch) {
      test('[${c[0]}] ${c[1]}', () {
        expect(scanArbValue(c[0], 'selfTest', c[1]), isNotEmpty);
      });
    }

    // Each of these must pass: per-day words, words that only look like
    // numbers, and a count that is the placeholder's own value.
    const mustPass = <List<String>>[
      ['en', 'Daily data'],
      ['en', '{amount} every day'],
      ['en', 'Get {amount} per day'],
      ['en', 'You can earn up to {max} a day from invites.'],
      ['en', 'Have an invite code?'],
      ['en', 'one tap'],
      ['en', 'uses the VPN for a while'],
      [
        'en',
        'cleared within {days, plural, one{{days} day} other{{days} days}}',
      ],
      ['en', '{count, plural, =0{} =1{1 invite} other{{count} invites}}'],
      ['en', '{count, plural, =1{one invite} other{{count} invites}}'],
      ['de', 'pro Tag'],
      ['de', 'das VPN eine Weile nutzt'],
      ['fr', 'chaque jour'],
      ['fr', 'une fois que vous aurez utilisé le VPN'],
      ['pt', 'por um tempo'],
      ['ru', 'в день'],
      ['ru', 'какое-то время'],
      ['ru', 'в течение {days, plural, one{{days} дня} other{{days} суток}}'],
      ['tr', 'her gün'],
      ['tr', 'günlük veri'],
      ['tr', 'bir süre'],
      ['fa', 'داده‌های روزانه'],
      ['fa', 'دوباره امتحان کنید'],
      ['fa', 'دوستان خود را دعوت کنید'],
      ['fa', 'مدتی از وی‌پی‌ان استفاده کند'],
      ['ar', 'استخدام الشبكة'],
      ['ar', 'ستحصل على بيانات'],
      ['ar', 'لفترة'],
      [
        'ar',
        'خلال {days, plural, one{يوم واحد} two{يومين} other{{days} يومًا}}',
      ],
      ['ar', '{count, plural, =1{دعوة واحدة} other{{count} دعوات}}'],
      ['ur', 'دوبارہ کوشش کریں'],
      ['ur', 'کچھ عرصہ'],
      ['hi', 'हर दिन'],
      ['hi', 'कुछ समय'],
      ['ja', '1 日 {amount} にする'],
      ['ja', '1日の上限'],
      ['ja', '1日最大 {max}'],
      ['ja', 'しばらく VPN を使う'],
      ['ja', '毎日'],
      ['ko', '열기'],
      ['ko', '하루 데이터'],
      ['ko', '한동안'],
      ['es', 'cada día'],
      ['es', 'datos diarios'],
      ['es', '{amount} al día'],
      ['es', 'por un tiempo'],
      ['es', 'un código de invitación'],
      ['id', 'setiap hari'],
      ['id', 'data harian'],
      ['id', 'salah satu server'],
      ['id', 'untuk sementara'],
      ['vi', 'mỗi ngày'],
      ['vi', 'dữ liệu hằng ngày'],
      ['vi', 'một số người dùng'],
      ['vi', 'một lúc'],
      ['uk', 'щодня'],
      ['uk', 'на день'],
      ['uk', 'деякий час'],
      ['uk', 'протягом {days, plural, one{{days} дня} other{{days} днів}}'],
      ['uz', 'har kuni'],
      ['uz', 'kunlik trafik'],
      ['uz', 'bir oz'],
      ['uz', 'bir muddat'],
      ['zh', '每天'],
      ['zh', '每日流量'],
      ['zh', '一键连接'],
      ['zh', '一部分'],
      ['zh', '一些'],
    ];
    for (final c in mustPass) {
      test('passes [${c[0]}] ${c[1]}', () {
        expect(scanArbValue(c[0], 'selfTest', c[1]), isEmpty);
      });
    }

    // Each line must be caught on its own.
    const plantedCode = [
      'const a = 250 * 1024 * 1024;',
      'const b = 1024 * 1024 * 250;',
      'const c = 5 << 30;',
      'final d = gb << 30;',
      'const e = 262144000;',
      'const f = 1073741824;',
      'const g = 1e9;',
      'const h = Duration(\n  hours: 72,\n);',
      'const i = Duration(days: 2);',
      'final j = x.inDays >= 2;',
      'final k = 3 < age.inHours;',
    ];
    for (final line in plantedCode) {
      test('the Dart rules catch $line', () {
        final code = lexDart(line).code;
        expect(_codeRules.values.any((r) => r.hasMatch(code)), isTrue);
      });
    }

    // A service rule kept in a named constant, with no byte math in it.
    const plantedNames = [
      'static const confirmDays = 2;',
      'static const int freeDailyMb = 5120;',
      'const deviceLimit = 3;',
      'const freeTierHours = 24;',
      'static const claimWindow = Duration(hours: 72);',
      'static int maxDevices = 3;',
      'int confirmDays = 2;',
      'static int get confirmDaysGetter => 2;',
      'const Limits({this.maxDevices = 3});',
      'final h = s.claimWindowHours ?? 72;',
      'final t = l10n.inviteClaimAccepted(s.confirmActiveDays ?? 2);',
      'final d = config.deletedDataRetentionDays ?? 30;',
    ];
    for (final line in plantedNames) {
      test('the name rule catches $line', () {
        expect(policyNamedNumbers(lexDart(line).code), isNotEmpty);
      });
    }

    test('the name rule leaves values read at run time alone', () {
      const src =
          'final bonus = status.bonusBytes > 0;\n'
          'final limit = quota.limitBytes;\n'
          'static const maxAsks = 3;\n'
          'const Status({this.bonusBytes = 0});\n'
          'final hours = s.claimWindowHours ?? 0;\n';
      expect(policyNamedNumbers(lexDart(src).code), isEmpty);
    });

    test('the name rule leaves layout and paging sizes alone', () {
      const src =
          'static const double dayLabelWidth = 40.0;\n'
          'const capHeight = 12.0;\n'
          'final freeSpacePadding = 8.0;\n'
          'static const pageLimit = 20;\n';
      expect(policyNamedNumbers(lexDart(src).code), isEmpty);
    });

    test('a literal passed to a {days} or {hours} message is caught', () {
      final call = placeholderCallPattern(
        jsonDecode(File('$root/lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>,
      );
      const planted = [
        'S.of(context)!.deleteAccountConfirmRetention(30);',
        'l10n.inviteHaveCodeSubtitle(72);',
        'l10n.inviteHowItWorksBody(format(bytes), 2);',
        'l10n.inviteClaimAccepted(\n  2,\n);',
      ];
      for (final line in planted) {
        expect(
          literalPlaceholderArgs(call, lexDart(line).code),
          isNotEmpty,
          reason: line,
        );
      }
      const fine =
          'l10n.deleteAccountConfirmRetention(days);\n'
          'l10n.inviteHowItWorksBody(amount, days);\n';
      expect(literalPlaceholderArgs(call, lexDart(fine).code), isEmpty);
    });

    test('comments and string text are not code', () {
      const src = "// 250 * 1024 * 1024\nconst id = '1073741824';\n";
      final code = lexDart(src).code;
      for (final rule in _codeRules.values) {
        expect(rule.hasMatch(code), isFalse);
      }
    });

    test('a number with a unit in a Dart string is caught', () {
      final strings = lexDart(
        "const a = 'Up to 3 phones';\nconst b = '5 گیگابایت';\n"
        r"const c = '${x} GB';",
      ).strings;
      expect(_numberWithUnit.hasMatch(strings[0].text), isTrue);
      expect(_numberWithUnit.hasMatch(strings[1].text), isTrue);
      expect(_numberWithUnit.hasMatch(strings[2].text), isFalse);
    });
  });

  test('no .arb value names a service number', () {
    final problems = scanArbFiles(root);
    expect(problems, isEmpty, reason: '${problems.join('\n')}\n\n$_howToFix');
  });

  test('no Android string names a service number', () {
    final problems = scanAndroidStrings(root);
    expect(problems, isEmpty, reason: '${problems.join('\n')}\n\n$_howToFix');
  });

  test('no Dart code under lib/ writes a service number', () {
    final problems = scanDart(root);
    expect(problems, isEmpty, reason: '${problems.join('\n')}\n\n$_howToFix');
  });

  test('every allowlist entry has a reason', () {
    final reasons = [
      ...allowedArbDigits.values.map((e) => e.reason),
      ...allowedArbWords.values.map((e) => e.reason),
      ...allowedCode.values.map((e) => e.reason),
    ];
    expect(reasons.where((r) => r.trim().length < 10), isEmpty);
  });
}
