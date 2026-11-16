import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

import { cleanCode, clickConnects, codeReady, countryName, faceOf, flagOf, labelParts, leftShare, placeName } from '../src/view.js';

const snap = (o) => ({ status: 'off', wanted: false, error: '', ...o });

test('the shield shows the faces of the app\'s button', () => {
  assert.equal(faceOf(snap({})), 'off');
  assert.equal(faceOf(snap({ status: 'connecting', wanted: true })), 'connecting');
  assert.equal(faceOf(snap({ status: 'on', wanted: true })), 'on');
  // Failed, and trying again by itself: amber.
  assert.equal(faceOf(snap({ status: 'failed', wanted: true, error: 'unreachable' })), 'waiting');
  // Out of data: the shield greyed.
  assert.equal(faceOf(snap({ status: 'out_of_data', wanted: true })), 'spent');
  // Another extension holds the proxy setting: red, and a click tries again.
  assert.equal(faceOf(snap({ status: 'other_controls', error: 'other_controls' })), 'failed');
  assert.equal(faceOf(null), 'off');
});

test('a click connects while off, and stops everything else, a connect included', () => {
  assert.equal(clickConnects(snap({})), true);
  assert.equal(clickConnects(snap({ status: 'other_controls' })), true);
  assert.equal(clickConnects(snap({ status: 'connecting', wanted: true })), false);
  assert.equal(clickConnects(snap({ status: 'on', wanted: true })), false);
  assert.equal(clickConnects(snap({ status: 'failed', wanted: true })), false);
  assert.equal(clickConnects(snap({ status: 'out_of_data', wanted: true })), false);
});

test('a label reads as the app reads it: the country, then the place', () => {
  assert.deepEqual(labelParts('Fortiva FI Helsinki'), { region: 'FI', place: 'Helsinki' });
  assert.deepEqual(labelParts('Fortiva 🇩🇪 Nuremberg'), { region: 'DE', place: 'Nuremberg' });
  assert.deepEqual(labelParts('fortiva DE Server'), { region: 'DE', place: 'Server' });
  // A two-letter word that is not in capitals is part of the place.
  assert.deepEqual(labelParts('Fortiva Ho Chi Minh City'), { region: '', place: 'Ho Chi Minh City' });
  assert.deepEqual(labelParts('Test server'), { region: '', place: 'Test server' });
  assert.deepEqual(labelParts(''), { region: '', place: '' });
});

test('a location is its city and its country in the person\'s language', () => {
  assert.equal(placeName('Fortiva FI Helsinki', 'en'), 'Helsinki, Finland');
  assert.equal(placeName('Fortiva DE Nuremberg', 'de'), 'Nuremberg, Deutschland');
  assert.equal(placeName('Test server', 'en'), 'Test server');
  assert.equal(placeName('Fortiva FI', 'en'), 'Finland');
  // Node has the browser's CLDR names; a code it does not know stays a code.
  assert.equal(countryName('FI', 'fa'), new Intl.DisplayNames(['fa'], { type: 'region' }).of('FI'));
  assert.equal(countryName('', 'en'), '');
});

test('a flag is the regional indicator pair of its code', () => {
  assert.equal(flagOf('FI'), '\u{1F1EB}\u{1F1EE}');
  assert.equal(flagOf('fi'), '');
  assert.equal(flagOf(''), '');
});

test('the code field keeps what the app\'s field keeps', () => {
  assert.equal(cleanCode('k7qd-3mwx 9tzb'), 'K7QD-3MWX 9TZB');
  // Persian and Arabic digits become Latin ones.
  assert.equal(cleanCode('abc-۱۲۳-٤٥٦'), 'ABC-123-456');
  assert.equal(cleanCode('a_b.c/d!'), 'ABCD');
  assert.equal(cleanCode('x'.repeat(40)).length, 32);
  assert.equal(codeReady('K7Q'), false);
  assert.equal(codeReady('K7-QD'), true);
  assert.equal(codeReady('- - -'), false);
});

test('the bar shows the share left', () => {
  assert.equal(leftShare({ unlimited: false, limit_bytes: 100, remaining_bytes: 25 }), 25);
  assert.equal(leftShare({ unlimited: false, limit_bytes: 100, remaining_bytes: -5 }), 0);
  assert.equal(leftShare({ unlimited: true }), 0);
  assert.equal(leftShare(null), 0);
});

test('the popup has no hidden element that a display rule shows anyway', () => {
  // Before 2026-11-16 the location row was display: flex, which outranks
  // the hidden attribute, so a new install showed an empty list.
  const css = readFileSync(new URL('../src/popup.css', import.meta.url), 'utf8');
  assert.match(css, /\[hidden\]\s*\{\s*display:\s*none\s*!important;\s*\}/);
});

test('the shield is drawn from the app\'s own pictures', () => {
  const html = readFileSync(new URL('../src/popup.html', import.meta.url), 'utf8');
  const css = readFileSync(new URL('../src/popup.css', import.meta.url), 'utf8');
  const build = readFileSync(new URL('../build.mjs', import.meta.url), 'utf8');
  for (const file of ['shield.webp', 'eyes.png', 'glow.png', 'halo.png']) {
    assert.ok(html.includes(`hero/${file}`) || css.includes(`hero/${file}`), file);
    assert.ok(build.includes(`'${file}'`), `build.mjs copies ${file}`);
  }
});
