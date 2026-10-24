import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'number_localizer.dart';

/// A date in the app's language, on the phone's calendar day.
///
/// Persian is written on the Iranian calendar, which is what people who
/// read the app in Persian use every day: 8 Nov 2026 is ۱۷ آبان ۱۴۰۵. Every
/// other language keeps the Gregorian date the locale writes
/// (DateFormat.yMMMd). Digits follow the language through NumberLocalizer.
String appDate(BuildContext context, DateTime when) {
  final local = when.toLocal();
  String language;
  try {
    language = Localizations.localeOf(context).languageCode;
  } catch (_) {
    language = 'en';
  }
  String text;
  if (language == 'fa') {
    text = jalaliText(local);
  } else {
    try {
      final locale = Localizations.localeOf(context).toLanguageTag();
      text = DateFormat.yMMMd(locale).format(local);
    } catch (_) {
      text = DateFormat('yyyy-MM-dd').format(local);
    }
  }
  return NumberLocalizer.localize(text, context);
}

/// [date]'s calendar day on the Iranian calendar, as day, month name and
/// year with Western digits, such as "17 آبان 1405".
String jalaliText(DateTime date) {
  final j = toJalali(date.year, date.month, date.day);
  return '${j.day} ${_monthNames[j.month - 1]} ${j.year}';
}

/// The Iranian calendar date of the Gregorian date [gy]-[gm]-[gd].
///
/// The year starts on Nowruz, 1 Farvardin, which falls on 20, 21 or 22
/// March. The 33-year break table ([_breaks]) gives that day for any year
/// ([_nowruz]). The date is then counted in days from the Nowruz before
/// it: the first six months have 31 days, the next five 30, and the last
/// 29, or 30 in a leap year.
({int year, int month, int day}) toJalali(int gy, int gm, int gd) {
  final date = DateTime.utc(gy, gm, gd);
  var year = gy - 621;
  var start = _nowruz(year);
  if (date.isBefore(start)) {
    year -= 1;
    start = _nowruz(year);
  }
  var left = date.difference(start).inDays;
  var month = 1;
  for (final length in _monthLengths) {
    if (left < length) break;
    left -= length;
    month++;
  }
  return (year: year, month: month, day: left + 1);
}

/// The Gregorian date of 1 Farvardin of the Iranian year [jy].
///
/// The leap years of the Iranian calendar follow its break years: between
/// two breaks, every fourth year is a leap year, counted in 33-year
/// cycles. This counts the leap years since the calendar's epoch on both
/// calendars, and the difference moves Nowruz off 20 March.
DateTime _nowruz(int jy) {
  final gy = jy + 621;
  var leapJ = -14;
  var jp = _breaks.first;
  var jump = 0;
  for (var i = 1; i < _breaks.length; i++) {
    final jm = _breaks[i];
    jump = jm - jp;
    if (jy < jm) break;
    leapJ += _div(jump, 33) * 8 + _div(_mod(jump, 33), 4);
    jp = jm;
  }
  final n = jy - jp;
  leapJ += _div(n, 33) * 8 + _div(_mod(n, 33) + 3, 4);
  if (_mod(jump, 33) == 4 && jump - n == 4) leapJ += 1;
  final leapG = _div(gy, 4) - _div((_div(gy, 100) + 1) * 3, 4) - 150;
  return DateTime.utc(gy, 3, 20 + leapJ - leapG);
}

/// Integer division and remainder that round toward zero, as the break
/// table's arithmetic expects for the years before its epoch.
int _div(int a, int b) => a ~/ b;
int _mod(int a, int b) => a - (a ~/ b) * b;

/// The Iranian years that start a new run of the leap-year rule.
const _breaks = [
  -61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210, 1635, 2060, //
  2097, 2192, 2262, 2324, 2394, 2456, 3178,
];

/// The length of each month. The last is 30 only in a leap year, which
/// the count never needs to know: it stops at the next Nowruz.
const _monthLengths = [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 30];

const _monthNames = [
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];
