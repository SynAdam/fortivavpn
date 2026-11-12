// The extension's languages: the app's 18, chosen as the app chooses. The
// person's own choice comes first, then the browser's language, then
// English.

import { STRINGS } from './strings.gen.js';

export const LANGUAGES = Object.keys(STRINGS);

// Each language by its own name, as the app's language list writes it
// (lib/core/state/locale_state.dart).
export const NAMES = {
  en: 'English', ar: 'العربية', de: 'Deutsch', es: 'Español', fa: 'فارسی',
  fr: 'Français', hi: 'हिन्दी', id: 'Bahasa Indonesia', ja: '日本語', ko: '한국어',
  pt: 'Português', ru: 'Русский', tr: 'Türkçe', uk: 'Українська', ur: 'اردو',
  uz: 'Oʻzbekcha', vi: 'Tiếng Việt', zh: '简体中文',
};

const RTL = new Set(['ar', 'fa', 'ur']);

export function isRtl(lang) {
  return RTL.has(lang);
}

// browserLanguage maps the browser's language ("pt-BR", "zh_CN", "fa") to
// one of ours, or English.
export function browserLanguage(ui) {
  const code = String(ui || '').toLowerCase().split(/[-_]/)[0];
  return code in STRINGS ? code : 'en';
}

export function pickLanguage(choice, ui) {
  return choice && choice in STRINGS ? choice : browserLanguage(ui);
}

// t is the string key in lang, with each {name} replaced from params.
// English stands in for nothing missing: the build refuses that.
export function t(lang, key, params = {}) {
  const table = STRINGS[lang] || STRINGS.en;
  const text = table[key] ?? STRINGS.en[key] ?? key;
  return text.replace(/\{(\w+)\}/g, (m, name) => (name in params ? String(params[name]) : m));
}

// The digits of the languages that have their own, as the app writes them
// (NumberLocalizer in lib/utils/number_localizer.dart).
const DIGITS = {
  fa: '۰۱۲۳۴۵۶۷۸۹',
  ar: '٠١٢٣٤٥٦٧٨٩',
  ur: '۰۱۲۳۴۵۶۷۸۹',
};

// localizeDigits writes the digits of text in lang's own digits. For an
// amount, the decimal point between two digits becomes the momayyez as
// well, which the app uses for Persian, Arabic and Urdu.
export function localizeDigits(text, lang, amount = false) {
  const digits = DIGITS[lang];
  if (!digits) return text;
  let out = amount ? text.replace(/(?<=\d)\.(?=\d)/g, '٫') : text;
  return out.replace(/\d/g, (d) => digits[+d]);
}

// formatBytes is the app's QuotaCard.formatBytes, in lang's digits.
export function formatBytes(bytes, lang) {
  const n = Number(bytes) || 0;
  let text;
  if (n >= 2 ** 30) text = `${(n / 2 ** 30).toFixed(1)} GB`;
  else if (n >= 2 ** 20) text = `${Math.round(n / 2 ** 20)} MB`;
  else if (n >= 2 ** 10) text = `${Math.round(n / 2 ** 10)} KB`;
  else text = `${n} B`;
  return localizeDigits(text, lang, true);
}

// resetText is when the allowance resets, in the app's words; empty when
// the backend did not say.
export function resetText(resetsAt, lang, now = Date.now()) {
  const at = Date.parse(resetsAt);
  if (!at) return '';
  const minutes = Math.ceil((at - now) / 60000);
  if (minutes <= 1) return t(lang, 'quotaResetsShortly');
  if (minutes < 60) return localizeDigits(t(lang, 'quotaResetsInMinutes', { minutes }), lang);
  return localizeDigits(t(lang, 'quotaResetsInHours', { hours: Math.floor(minutes / 60) }), lang);
}
