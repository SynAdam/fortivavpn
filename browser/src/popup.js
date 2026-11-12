// The popup: one button, what the extension is doing, the allowance, a
// Premium code and the language. Everything it shows comes from the
// background (core.js snapshot), and every number from the backend.

import { LANGUAGES, NAMES, formatBytes, isRtl, pickLanguage, resetText, t } from './i18n.js';

const ext = globalThis.browser ?? globalThis.chrome;
const $ = (id) => document.getElementById(id);

let lang = 'en';
let last = null;
let polling = null;
// Clicks on the button whose answer has not come yet. The background does
// one thing at a time, so a connect can wait behind the refresh the popup
// sent when it opened.
let pending = 0;
// Whether the extension runs in private windows too. Without the person's
// leave it does not, in Chrome or in Firefox, and their requests go
// direct.
let privateWindows = true;

function send(type, extra = {}) {
  return new Promise((resolve) => {
    ext.runtime.sendMessage({ type, ...extra }, (res) => resolve(res || {}));
  });
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

// The button's state. "waiting" is a failure or a used-up allowance while
// the person still wants Fortiva on: the extension tries again by itself,
// and the button turns that off.
function stateOf(snap) {
  if (snap.status === 'on') return 'on';
  if (snap.status === 'connecting') return 'connecting';
  if (snap.wanted && (snap.status === 'failed' || snap.status === 'out_of_data')) return 'waiting';
  return 'off';
}

function render(snap) {
  if (!snap || snap.error && !snap.status) return;
  last = snap;
  lang = pickLanguage(snap.language, ext.i18n.getUILanguage());
  document.documentElement.lang = lang;
  document.documentElement.dir = isRtl(lang) ? 'rtl' : 'ltr';

  const state = stateOf(snap);
  const power = $('power');
  power.dataset.state = state;
  power.disabled = state === 'connecting';
  power.setAttribute('aria-label', t(lang, state === 'off' ? 'connectBtn' : 'disconnectBtn'));
  power.title = power.getAttribute('aria-label');

  const status = $('status');
  status.dataset.state = state;
  status.textContent = t(lang, state === 'on' ? 'statusConnected' : state === 'connecting' ? 'statusConnecting' : 'statusDisconnected');

  const location = $('location');
  location.textContent = snap.location ? `${t(lang, 'serverLocation')}: ${snap.location}` : '';
  location.hidden = !snap.location;

  const message = $('message');
  const text = snap.status === 'out_of_data' ? `${t(lang, 'quotaUsedUp')}. ${t(lang, 'myServersBlockedWait')}` : errorText(snap.error);
  message.textContent = text;
  message.hidden = !text;

  renderQuota(snap.quota);
  renderLocations(snap, state);

  $('note').textContent = t(lang, 'extOnlyBrowser');
  $('private').textContent = t(lang, 'extPrivateWindows');
  $('private').hidden = privateWindows;
  $('codeTitle').textContent = t(lang, 'redeemTitle');
  $('code').placeholder = t(lang, 'redeemHint');
  $('codeApply').textContent = t(lang, 'redeemApply');
  $('languageLabel').textContent = t(lang, 'language');
  renderLanguages(snap.language);

  if (state === 'connecting' && !polling) {
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
// answer, such a snapshot may be older than the click, so it keeps the
// state the click showed, unless it says the connect has started.
function show(snap) {
  if (!snap || snap.error && !snap.status) return;
  if (pending && last && snap.status !== 'connecting') {
    snap = { ...snap, status: last.status, wanted: last.wanted, error: last.error, location: last.location };
  }
  render(snap);
}

function renderQuota(q) {
  const box = $('quota');
  if (!q) {
    box.hidden = true;
    return;
  }
  box.hidden = false;
  const bar = $('bar');
  if (q.unlimited) {
    $('quotaLine').textContent = t(lang, 'quotaUnlimited');
    $('quotaReset').textContent = '';
    bar.hidden = true;
    return;
  }
  const left = Math.max(0, q.remaining_bytes || 0);
  $('quotaLine').textContent = left > 0
    ? t(lang, 'quotaLeftOf', { left: formatBytes(left, lang), limit: formatBytes(q.limit_bytes, lang) })
    : t(lang, 'quotaUsedUp');
  bar.hidden = !(q.limit_bytes > 0);
  $('barFill').style.width = q.limit_bytes > 0 ? `${Math.min(100, (left / q.limit_bytes) * 100)}%` : '0';
  $('quotaReset').textContent = resetText(q.resets_at, lang);
}

// The location row: "Automatic" and each location the backend offers. It
// shows only when there are at least two to choose from.
function renderLocations(snap, state) {
  const row = $('locationRow');
  const places = Array.isArray(snap.locations) ? snap.locations : [];
  row.hidden = places.length < 2;
  if (row.hidden) return;
  $('locationLabel').textContent = t(lang, 'selectServer');
  const select = $('locationSelect');
  const want = [['', t(lang, 'extAutomatic')], ...places.map((p) => [p, p])];
  const same = select.options.length === want.length
    && want.every(([value, label], i) => select.options[i].value === value && select.options[i].textContent === label);
  if (!same) {
    select.textContent = '';
    for (const [value, label] of want) {
      const o = document.createElement('option');
      o.value = value;
      o.textContent = label;
      select.appendChild(o);
    }
  }
  select.value = snap.chosenLocation || '';
  select.disabled = state === 'connecting';
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
}

$('power').addEventListener('click', async () => {
  if (!last) return;
  const on = stateOf(last) !== 'off';
  render({ ...last, status: on ? 'off' : 'connecting', wanted: !on, error: '' });
  pending++;
  const res = await send(on ? 'disconnect' : 'connect');
  pending--;
  render(res);
});

$('codeForm').addEventListener('submit', async (ev) => {
  ev.preventDefault();
  const input = $('code');
  const code = input.value.trim();
  const result = $('codeResult');
  // The app's shortest code worth sending.
  if (code.replace(/[^0-9a-z]/gi, '').length < 4) {
    result.textContent = t(lang, 'redeemInvalid');
    result.hidden = false;
    return;
  }
  $('codeApply').disabled = true;
  const res = await send('redeem', { code });
  $('codeApply').disabled = false;
  result.textContent = redeemText(res);
  result.hidden = false;
  if (res.ok) input.value = '';
  show(await send('state'));
});

$('locationSelect').addEventListener('change', async (ev) => {
  if (!last) return;
  const label = ev.target.value;
  // While on, the change connects again with that location first.
  render({ ...last, chosenLocation: label, status: last.wanted && last.status === 'on' ? 'connecting' : last.status });
  pending++;
  const res = await send('location', { label });
  pending--;
  render(res);
});

$('languageSelect').addEventListener('change', async (ev) => {
  show(await send('language', { code: ev.target.value }));
});

// The background can change the state while the popup is open, after a
// check or when the allowance runs out.
ext.storage.onChanged.addListener((changes, area) => {
  if (area === 'local' && ('status' in changes || 'quota' in changes)) send('state').then(show);
});

try {
  privateWindows = (await ext.extension.isAllowedIncognitoAccess()) === true;
} catch {
  // A browser that cannot say gets no note.
}
show(await send('state'));
show(await send('refresh'));
