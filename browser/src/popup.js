// The popup: the shield that connects, what the extension is doing, the
// location, the allowance, a Premium code and the language. Everything it
// shows comes from the background (core.js snapshot), and every number
// from the backend.

import { LANGUAGES, NAMES, formatBytes, isRtl, pickLanguage, resetText, t } from './i18n.js';
import { cleanCode, clickConnects, codeReady, faceOf, flagOf, labelParts, leftShare, placeName } from './view.js';

const ext = globalThis.browser ?? globalThis.chrome;
const firefox = typeof globalThis.browser !== 'undefined' && typeof browser.runtime.getBrowserInfo === 'function';
const $ = (id) => document.getElementById(id);
const SVG = 'http://www.w3.org/2000/svg';

let lang = 'en';
let last = null;
let polling = null;
// Clicks whose answer has not come yet. The background does one thing at a
// time, so a connect can wait behind the refresh the popup sent when it
// opened.
let pending = 0;
// The latest click. The answer to an earlier one is not drawn: a stop
// clicked during a connect is answered after the connect it stopped.
let clicks = 0;
// Whether the extension runs in private windows too. Without the person's
// leave it does not, in Chrome or in Firefox, and their requests go
// direct.
let privateWindows = true;
// True until the refresh sent on opening is answered. A new install has
// nothing to show before it, so the allowance and the location show
// placeholders meanwhile.
let loading = true;
// The face drawn last: the success moment plays for a connect the person
// watched land, never for a popup opened already connected.
let shownFace = null;

function send(type, extra = {}) {
  return Promise.resolve()
    .then(() => ext.runtime.sendMessage({ type, ...extra }))
    .then((res) => res || {}, () => ({}));
}

const reducedMotion = () => globalThis.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true;

// Whether this system draws flags. Windows draws the two letters of a
// regional indicator pair instead, so the popup shows the country's code
// there.
const flagsDrawn = (() => {
  try {
    const canvas = document.createElement('canvas');
    canvas.width = canvas.height = 24;
    const g = canvas.getContext('2d', { willReadFrequently: true });
    g.font = '20px sans-serif';
    g.textBaseline = 'top';
    g.fillText(flagOf('FI'), 0, 0);
    const d = g.getImageData(0, 0, 24, 24).data;
    for (let i = 0; i < d.length; i += 4) {
      if (d[i + 3] > 0 && (Math.abs(d[i] - d[i + 2]) > 30 || Math.abs(d[i + 1] - d[i + 2]) > 30)) return true;
    }
  } catch {
    // No canvas: the codes.
  }
  return false;
})();

function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function icon(paths, className) {
  const svg = document.createElementNS(SVG, 'svg');
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.setAttribute('aria-hidden', 'true');
  if (className) svg.setAttribute('class', className);
  for (const d of paths) {
    const path = document.createElementNS(SVG, 'path');
    path.setAttribute('d', d);
    svg.appendChild(path);
  }
  return svg;
}

const PIN = ['M12 21s-6.5-6.2-6.5-11.2a6.5 6.5 0 0 1 13 0C18.5 14.8 12 21 12 21z', 'M12 7.5a2.3 2.3 0 1 1 0 4.6 2.3 2.3 0 0 1 0-4.6z'];
const BOLT = ['M13 3 5.5 13.5h6L10.5 21 18.5 10.5h-6L13 3z'];
const CHECK = ['m5 12.5 4.5 4.5L19 7.5'];

// The round badge of a location: its flag, or its country's code where the
// system draws no flags, or a pin for a label with no country.
function badge(target, label) {
  target.textContent = '';
  const { region } = labelParts(label);
  if (region && flagsDrawn) target.append(el('span', 'flag', flagOf(region)));
  else if (region) target.append(el('span', 'code', region));
  else target.append(icon(PIN));
}

function skeleton(width) {
  const s = el('span', 'skeleton');
  s.style.width = `${width}px`;
  return s;
}

// An amount kept whole in a right to left line: without the isolate, the
// number and "GB" can land on either side of the words between them.
function amount(bytes) {
  const shown = formatBytes(bytes, lang);
  return isRtl(lang) ? `⁨${shown}⁩` : shown;
}

// What the extension says about a failure, in the person's language.
function errorText(error) {
  switch (error) {
    case 'network': return t(lang, 'redeemNetwork');
    case 'no_servers': return t(lang, 'extNoServers');
    case 'other_controls': return t(lang, 'extOtherControls');
    case '': return '';
    default: return t(lang, 'errorConnectionFailed');
  }
}

// The app's redeemFailureText, with "this browser" where the app says
// "this phone".
function redeemText(res) {
  if (res.ok) return res.kind === 'premium' ? t(lang, res.moved ? 'extRedeemMoved' : 'premiumNowOn') : t(lang, 'redeemPromoNoAmount');
  if (res.status === 429) return t(lang, 'redeemRateLimited');
  return t(lang, {
    invalid_code: 'redeemInvalid',
    unknown_code: 'redeemUnknown',
    expired: 'redeemExpired',
    revoked: 'redeemRevoked',
    moved_too_often: 'extRedeemMovedTooOften',
    exhausted: 'redeemExhausted',
    already_redeemed: 'extRedeemAlreadyUsed',
    unmetered: 'extRedeemUnmetered',
    not_available: 'extPremiumNotAvailable',
    rate_limited: 'redeemRateLimited',
    unavailable: 'redeemUnavailable',
    server: 'redeemUnavailable',
    network: 'redeemNetwork',
  }[res.reason] || 'redeemFailed');
}

// What the tests and the README call the button's state. "waiting" is a
// failure or a used-up allowance while the person still wants Fortiva on:
// the extension tries again by itself, and the button turns that off.
function stateOf(snap) {
  if (snap.status === 'on') return 'on';
  if (snap.status === 'connecting') return 'connecting';
  if (snap.wanted && (snap.status === 'failed' || snap.status === 'out_of_data')) return 'waiting';
  return 'off';
}

function celebrate(power) {
  power.classList.remove('celebrate');
  // Read the layout, so the animation starts again from its beginning.
  void power.offsetWidth;
  power.classList.add('celebrate');
  setTimeout(() => power.classList.remove('celebrate'), 800);
}

function render(snap) {
  if (!snap || snap.error && !snap.status) return;
  last = snap;
  lang = pickLanguage(snap.language, ext.i18n.getUILanguage());
  document.documentElement.lang = lang;
  document.documentElement.dir = isRtl(lang) ? 'rtl' : 'ltr';

  const face = faceOf(snap);
  const power = $('power');
  power.dataset.state = stateOf(snap);
  power.dataset.face = face;
  power.setAttribute('aria-label', t(lang, clickConnects(snap) ? 'connectBtn' : 'disconnectBtn'));
  power.title = power.getAttribute('aria-label');
  if (shownFace === 'connecting' && face === 'on' && !reducedMotion()) celebrate(power);
  shownFace = face;

  const status = $('status');
  status.dataset.face = face;
  status.textContent = t(lang, face === 'on' ? 'statusConnected' : face === 'connecting' ? 'statusConnecting' : 'statusDisconnected');

  const where = $('location');
  where.textContent = '';
  where.hidden = !snap.location;
  if (snap.location) {
    const { region } = labelParts(snap.location);
    // Read out as "Location: Helsinki, Finland"; seen as the flag and the place.
    where.append(el('span', 'sr', `${t(lang, 'serverLocation')}: `));
    if (region && flagsDrawn) {
      const flag = el('span', 'flag', flagOf(region));
      flag.setAttribute('aria-hidden', 'true');
      where.append(flag);
    }
    where.append(el('span', '', placeName(snap.location, lang)));
  }

  const message = $('message');
  const text = snap.status === 'out_of_data' ? `${t(lang, 'quotaUsedUp')}. ${t(lang, 'myServersBlockedWait')}` : errorText(snap.error);
  message.textContent = text;
  message.hidden = !text;
  message.dataset.tone = face === 'waiting' ? 'warning' : face === 'failed' || face === 'spent' ? 'error' : '';

  renderPlaces(snap, face);
  renderQuota(snap.quota);

  $('codeRowTitle').textContent = t(lang, 'redeemTitle');
  $('codeRowSub').textContent = t(lang, 'redeemSubtitle');
  $('privateText').textContent = t(lang, 'extPrivateWindows');
  $('private').hidden = privateWindows;
  // Chrome opens its page for this extension; Firefox lets no extension
  // open about:addons, so there the note only says where to go.
  $('private').disabled = firefox;
  if (!firefox) $('private').title = t(lang, 'settings');
  $('note').textContent = t(lang, 'extOnlyBrowser');
  renderLanguages(snap.language);

  if (face === 'connecting' && !polling) {
    polling = setInterval(async () => {
      const next = await send('state');
      show(next);
      if (!pending && next.status !== 'connecting') {
        clearInterval(polling);
        polling = null;
      }
    }, 1000);
  }
}

// show renders a snapshot that was not the answer to a click: the poll's,
// or the answer to the refresh or a code. While a click waits for its
// answer, such a snapshot may be older than the click, so the state the
// click showed stays.
function show(snap) {
  if (!snap || snap.error && !snap.status) return;
  if (pending && last) {
    snap = { ...snap, status: last.status, wanted: last.wanted, error: last.error, location: last.location, chosenLocation: last.chosenLocation };
  }
  render(snap);
}

function renderQuota(q) {
  const box = $('quota');
  const line = $('quotaLine');
  const reset = $('quotaReset');
  const bar = $('bar');
  delete box.dataset.spent;
  if (!q) {
    // Placeholders while the first answer is on its way, and nothing once
    // the backend could not be reached.
    box.hidden = !loading;
    line.replaceChildren(...(loading ? [skeleton(150)] : []));
    reset.replaceChildren(...(loading ? [skeleton(70)] : []));
    bar.hidden = true;
    return;
  }
  box.hidden = false;
  if (q.unlimited) {
    line.textContent = t(lang, 'quotaUnlimited');
    reset.textContent = '';
    bar.hidden = true;
    return;
  }
  const left = Math.max(0, q.remaining_bytes || 0);
  if (left > 0) {
    line.textContent = t(lang, 'quotaLeftOf', { left: amount(left), limit: amount(q.limit_bytes) });
  } else {
    line.textContent = t(lang, 'quotaUsedUp');
    box.dataset.spent = '';
  }
  reset.textContent = resetText(q.resets_at, lang);
  bar.hidden = !(q.limit_bytes > 0);
  $('barFill').style.width = `${leftShare(q)}%`;
}

// The location row: what the browser connects to, and the way to choose.
// With one location it only names it; with none known yet it shows a
// placeholder while the first answer is on its way.
function renderPlaces(snap, face) {
  const row = $('placeRow');
  const places = Array.isArray(snap.locations) ? snap.locations : [];
  const value = $('placeValue');
  $('placeLabel').textContent = t(lang, 'serverLocation');
  if (!places.length) {
    row.hidden = !loading;
    badge($('placeIcon'), '');
    value.replaceChildren(...(loading ? [skeleton(90)] : []));
    row.setAttribute('aria-disabled', 'true');
    row.querySelector('.chev').toggleAttribute('hidden', true);
    return;
  }
  row.hidden = false;
  const choosable = places.length > 1;
  const chosen = snap.chosenLocation || '';
  const shown = chosen || (choosable ? '' : places[0]);
  value.textContent = shown ? placeName(shown, lang) : t(lang, 'extAutomatic');
  if (shown) badge($('placeIcon'), shown);
  else $('placeIcon').replaceChildren(icon(BOLT));
  row.querySelector('.chev').toggleAttribute('hidden', !choosable);
  row.setAttribute('aria-disabled', String(!choosable));
  // No new choice while a connect runs; the choice connects again.
  row.disabled = choosable && face === 'connecting';
}

function renderLanguages(choice) {
  const select = $('languageSelect');
  const want = [['', t(lang, 'extLanguageAuto')], ...LANGUAGES.map((code) => [code, NAMES[code]])];
  if (select.options.length !== want.length || select.options[0].textContent !== want[0][1]) {
    select.textContent = '';
    for (const [value, label] of want) {
      const o = document.createElement('option');
      o.value = value;
      o.textContent = label;
      if (value) o.lang = value;
      select.appendChild(o);
    }
  }
  select.value = choice || '';
  select.setAttribute('aria-label', t(lang, 'language'));
  $('languageName').textContent = NAMES[lang] || lang;
  $('languageName').lang = lang;
}

let toastTimer = null;
function toast(text, ms = 2500) {
  const box = $('toast');
  box.textContent = text;
  box.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => {
    box.hidden = true;
  }, ms);
}

// --- the button ---------------------------------------------------------------

$('power').addEventListener('click', async (ev) => {
  if (!last) return;
  // A double click is one click, not a connect and its stop: the second
  // click of a double click (detail 2) is left out.
  if (ev.detail > 1) return;
  const connect = clickConnects(last);
  const mine = ++clicks;
  render({ ...last, status: connect ? 'connecting' : 'off', wanted: connect, error: '', location: '' });
  pending++;
  const res = await send(connect ? 'connect' : 'disconnect');
  pending--;
  if (mine === clicks) render(res);
});

// --- the sheets -----------------------------------------------------------------

function openSheet(sheet) {
  for (const button of sheet.querySelectorAll('.x')) button.setAttribute('aria-label', t(lang, 'close'));
  sheet.showModal();
}

for (const sheet of document.querySelectorAll('dialog')) {
  // A click on the dim backdrop closes the sheet; the sheet's content
  // fills the dialog, so a click inside never lands on the dialog itself.
  sheet.addEventListener('click', (ev) => {
    if (ev.target === sheet) sheet.close();
  });
  for (const button of sheet.querySelectorAll('[data-close]')) button.addEventListener('click', () => sheet.close());
}

$('placeRow').addEventListener('click', () => {
  if (!last) return;
  const places = Array.isArray(last.locations) ? last.locations : [];
  if (places.length < 2) return;
  const chosen = last.chosenLocation || '';
  const list = $('placeList');
  list.textContent = '';
  for (const value of ['', ...places]) {
    const option = el('button', 'place');
    option.type = 'button';
    option.dataset.value = value;
    option.setAttribute('aria-current', String(value === chosen));
    const disc = el('span', 'icon');
    disc.setAttribute('aria-hidden', 'true');
    if (value) badge(disc, value);
    else disc.append(icon(BOLT));
    option.append(disc, el('span', 'name', value ? placeName(value, lang) : t(lang, 'extAutomatic')), icon(CHECK, 'tick'));
    list.append(option);
  }
  $('placeTitle').textContent = t(lang, 'selectServer');
  openSheet($('placeSheet'));
  list.querySelector('[aria-current="true"]')?.focus();
});

$('placeList').addEventListener('click', async (ev) => {
  const option = ev.target.closest('.place');
  if (!option || !last) return;
  $('placeSheet').close();
  const label = option.dataset.value;
  if (label === (last.chosenLocation || '')) return;
  // While on or trying, the choice connects again with that location first.
  const again = last.wanted && last.status !== 'out_of_data' && last.status !== 'other_controls';
  const mine = ++clicks;
  render({ ...last, chosenLocation: label, ...(again && { status: 'connecting', error: '', location: '' }) });
  if (label) toast(t(lang, 'myServersMoved', { place: placeName(label, lang) }));
  pending++;
  const res = await send('location', { label });
  pending--;
  if (mine === clicks) render(res);
});

const code = $('code');
const apply = $('codeApply');
let redeeming = false;

function codeResult(text) {
  const result = $('codeResult');
  result.textContent = text;
  result.hidden = !text;
  result.dataset.tone = text ? 'error' : '';
  code.setAttribute('aria-invalid', String(!!text));
}

$('codeRow').addEventListener('click', () => {
  $('codeTitle').textContent = t(lang, 'redeemTitle');
  $('codeSubtitle').textContent = t(lang, 'redeemSubtitle');
  code.placeholder = t(lang, 'redeemHint');
  code.setAttribute('aria-label', t(lang, 'redeemHint'));
  $('codeCancel').textContent = t(lang, 'redeemCancel');
  apply.textContent = t(lang, 'redeemApply');
  if (!redeeming) {
    code.value = '';
    apply.disabled = true;
    codeResult('');
  }
  openSheet($('codeSheet'));
  code.focus();
});

// The field keeps what a code can hold, in capitals, as it is typed or
// pasted, and the cursor stays where it was.
code.addEventListener('input', () => {
  const at = code.selectionStart ?? code.value.length;
  const cleaned = cleanCode(code.value);
  if (cleaned !== code.value) {
    const before = cleanCode(code.value.slice(0, at)).length;
    code.value = cleaned;
    code.setSelectionRange(before, before);
  }
  apply.disabled = redeeming || !codeReady(cleaned);
  codeResult('');
});

$('codeForm').addEventListener('submit', async (ev) => {
  ev.preventDefault();
  const value = cleanCode(code.value).trim();
  if (redeeming) return;
  if (!codeReady(value)) {
    codeResult(t(lang, 'redeemInvalid'));
    return;
  }
  redeeming = true;
  apply.disabled = true;
  apply.classList.add('busy');
  code.readOnly = true;
  const res = await send('redeem', { code: value });
  redeeming = false;
  apply.classList.remove('busy');
  code.readOnly = false;
  if (res.ok) {
    $('codeSheet').close();
    code.value = '';
    toast(redeemText(res), 5000);
  } else {
    apply.disabled = !codeReady(code.value);
    codeResult(redeemText(res));
    code.focus();
  }
  show(await send('state'));
});

// --- the rest -----------------------------------------------------------------------

$('private').addEventListener('click', async () => {
  try {
    await ext.tabs.create({ url: `chrome://extensions/?id=${ext.runtime.id}` });
    window.close();
  } catch {
    // The note still says where to go.
  }
});

$('languageSelect').addEventListener('change', async (ev) => {
  show(await send('language', { code: ev.target.value }));
});

// The background can change the state while the popup is open, after a
// check or when the allowance runs out.
ext.storage.onChanged.addListener((changes, area) => {
  if (area === 'local' && ('status' in changes || 'quota' in changes || 'proxies' in changes)) send('state').then(show);
});

try {
  privateWindows = (await ext.extension.isAllowedIncognitoAccess()) === true;
} catch {
  // A browser that cannot say gets no note.
}
show(await send('state'));
const fresh = await send('refresh');
loading = false;
if (fresh.status) show(fresh);
else if (last) render(last);
