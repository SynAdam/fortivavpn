// Writes browser/src/strings.gen.js: every string the extension shows, in
// the app's 18 languages.
//
//   node browser/tool/strings.mjs
//
// Most strings are the app's own, read from lib/l10n/app_<lang>.arb, so the
// extension says what the app says in the same words. The few that only the
// extension needs are in browser/messages/<lang>.json. The build refuses a
// language that lacks a string, or a string whose placeholders differ from
// the English one, so no language falls behind the others.

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const browser = join(here, '..');
const root = join(browser, '..');

export const LANGUAGES = [
  'en', 'ar', 'de', 'es', 'fa', 'fr', 'hi', 'id', 'ja',
  'ko', 'pt', 'ru', 'tr', 'uk', 'ur', 'uz', 'vi', 'zh',
];

// The app's strings the extension uses, by their key in the .arb files.
export const FROM_APP = [
  'statusConnected', 'statusConnecting', 'statusDisconnected',
  'connectBtn', 'disconnectBtn', 'errorConnectionFailed',
  'quotaLeftOf', 'quotaUnlimited', 'quotaUsedUp',
  'quotaResetsShortly', 'quotaResetsInHours', 'quotaResetsInMinutes',
  'myServersBlockedWait', 'serverLocation', 'language',
  'redeemTitle', 'redeemHint', 'redeemApply',
  'redeemInvalid', 'redeemUnknown', 'redeemExpired', 'redeemRevoked',
  'redeemExhausted', 'redeemRateLimited', 'redeemUnavailable',
  'redeemNetwork', 'redeemFailed', 'redeemPromoNoAmount', 'premiumNowOn',
];

const placeholders = (s) => [...s.matchAll(/\{(\w+)\}/g)].map((m) => m[1]).sort().join(',');

export function build() {
  const ownEnglish = JSON.parse(readFileSync(join(browser, 'messages', 'en.json'), 'utf8'));
  const keys = [...FROM_APP, ...Object.keys(ownEnglish)];
  const out = {};
  const problems = [];
  let english;
  for (const lang of LANGUAGES) {
    const arb = JSON.parse(readFileSync(join(root, 'lib', 'l10n', `app_${lang}.arb`), 'utf8'));
    const own = JSON.parse(readFileSync(join(browser, 'messages', `${lang}.json`), 'utf8'));
    const table = {};
    for (const key of FROM_APP) table[key] = arb[key];
    Object.assign(table, own);
    for (const key of keys) {
      const value = table[key];
      if (typeof value !== 'string' || value.trim() === '') {
        problems.push(`${lang}: no string for ${key}`);
        continue;
      }
      // Plural and select messages need ICU, which the popup does not have.
      if (/\{\w+,\s*(plural|select)/.test(value)) problems.push(`${lang}: ${key} is a plural or select message`);
      if (english && placeholders(value) !== placeholders(english[key])) {
        problems.push(`${lang}: ${key} has placeholders {${placeholders(value)}}, English has {${placeholders(english[key])}}`);
      }
    }
    for (const key of Object.keys(own)) {
      if (!(key in ownEnglish)) problems.push(`${lang}: ${key} is not in messages/en.json`);
    }
    if (lang === 'en') english = table;
    out[lang] = Object.fromEntries(keys.map((k) => [k, table[k]]));
  }
  if (problems.length) throw new Error('strings:\n  ' + problems.join('\n  '));
  return out;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const strings = build();
  const body =
    '// Written by browser/tool/strings.mjs from lib/l10n and browser/messages.\n' +
    '// Do not edit; run the tool.\n' +
    `export const STRINGS = ${JSON.stringify(strings, null, 1)};\n`;
  writeFileSync(join(browser, 'src', 'strings.gen.js'), body);
  console.log(`strings: ${Object.keys(strings.en).length} strings in ${LANGUAGES.length} languages`);
}
