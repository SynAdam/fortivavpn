import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

import { browserLanguage, formatBytes, LANGUAGES, NAMES, pickLanguage, resetText, t } from '../src/i18n.js';
import { STRINGS } from '../src/strings.gen.js';
import { build, FROM_APP } from '../tool/strings.mjs';

test('the extension has the app\'s 18 languages, each with every string', () => {
  assert.equal(LANGUAGES.length, 18);
  assert.deepEqual(Object.keys(NAMES).sort(), [...LANGUAGES].sort());
  const keys = Object.keys(STRINGS.en);
  for (const lang of LANGUAGES) assert.deepEqual(Object.keys(STRINGS[lang]), keys, lang);
  // The generated file is what the tool makes from today's sources.
  assert.deepEqual(build(), STRINGS);
});

test('the app\'s own words are used where the app has them', () => {
  const fa = JSON.parse(readFileSync(new URL('../../lib/l10n/app_fa.arb', import.meta.url), 'utf8'));
  for (const key of FROM_APP) assert.equal(STRINGS.fa[key], fa[key], key);
});

test('no string names a number the backend owns', () => {
  // As test/no_policy_numbers_test.dart holds for the app: amounts, hours
  // and days come from the backend and reach a string through a
  // placeholder.
  for (const lang of LANGUAGES) {
    for (const [key, value] of Object.entries(STRINGS[lang])) {
      assert.doesNotMatch(value.replace(/\{\w+\}/g, ''), /[0-9۰-۹٠-٩]/, `${lang} ${key}`);
    }
  }
});

test('the language follows the person, then the browser, then English', () => {
  assert.equal(browserLanguage('pt-BR'), 'pt');
  assert.equal(browserLanguage('zh_CN'), 'zh');
  assert.equal(browserLanguage('fa'), 'fa');
  assert.equal(browserLanguage('it'), 'en');
  assert.equal(pickLanguage('', 'de'), 'de');
  assert.equal(pickLanguage('ur', 'de'), 'ur');
  assert.equal(pickLanguage('xx', 'de'), 'de');
});

test('amounts are written as the app writes them', () => {
  assert.equal(formatBytes(20 * 2 ** 30, 'en'), '20.0 GB');
  assert.equal(formatBytes(1.5 * 2 ** 30, 'fa'), '۱٫۵ GB');
  assert.equal(formatBytes(300 * 2 ** 20, 'ar'), '٣٠٠ MB');
  assert.equal(t('en', 'quotaLeftOf', { left: '1.0 GB', limit: '20 GB' }), '1.0 GB of 20 GB left');
});

test('the reset reads in hours, minutes or shortly', () => {
  const now = Date.parse('2026-11-11T12:00:00Z');
  assert.equal(resetText('2026-11-11T17:30:00Z', 'en', now), 'Resets in 5h');
  assert.equal(resetText('2026-11-11T12:20:00Z', 'en', now), 'Resets in 20m');
  assert.equal(resetText('2026-11-11T12:00:30Z', 'en', now), 'Resets shortly');
  assert.equal(resetText(null, 'en', now), '');
  assert.match(resetText('2026-11-11T17:30:00Z', 'fa', now), /۵/);
});
