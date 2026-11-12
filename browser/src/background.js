// The extension's background: it gives core.js the browser's storage,
// proxy settings and network, and answers the popup.
//
// Chrome and Edge take the proxies as a PAC script and ask for the
// credentials when a proxy wants them (webRequest.onAuthRequired). Firefox
// asks the extension for every request (proxy.onRequest) and gets the
// credentials with the answer. In both, a proxy that refuses the
// credentials makes the extension check the connection at once. Listeners
// are added at the top level, so a browser that stopped the background
// starts it again for them.

import { API_BASE, Api } from './api.js';
import { Controller, Status, TICK_MINUTES } from './core.js';
import { PROBE_HOST, firefoxAnswer, pacScript, probePacScript } from './pac.js';
import { browserLanguage } from './i18n.js';

const ext = globalThis.browser ?? globalThis.chrome;
const firefox = typeof globalThis.browser !== 'undefined' && typeof browser.runtime.getBrowserInfo === 'function';
const manifest = ext.runtime.getManifest();
const TICK = 'fortiva-tick';

const store = {
  get: (keys) => ext.storage.local.get(keys),
  set: (values) => ext.storage.local.set(values),
};

// --- proxies ----------------------------------------------------------------

// Firefox's rules, kept here for proxy.onRequest: the route core.js last
// set (core.js has the shapes). null until read from storage, which happens
// again each time the background starts. Only core.js changes the route,
// through the calls below, so nothing else needs to follow storage.
let firefoxRoute = null;

async function loadFirefoxRoute() {
  const { route } = await store.get(['route']);
  // A route set while storage was read is newer than the one read.
  if (firefoxRoute === null) firefoxRoute = route && typeof route === 'object' ? route : { mode: 'off' };
}

// WebRTC can reach a STUN server over UDP, which no proxy here carries,
// and so show a page the person's own address. While the full rules are on
// it may use UDP only through a proxy; both browsers take this value.
async function webrtcThroughProxies(on) {
  try {
    const policy = ext.privacy.network.webRTCIPHandlingPolicy;
    if (on) await policy.set({ value: 'disable_non_proxied_udp' });
    else await policy.clear({});
  } catch {
    // A browser without the setting has nothing to leak through it.
  }
}

async function setPac(data) {
  await chrome.proxy.settings.set({
    value: { mode: 'pac_script', pacScript: { data, mandatory: true } },
    scope: 'regular',
  });
}

const proxy = firefox
  ? {
      async full(proxies) {
        firefoxRoute = { mode: 'full', proxies };
        await webrtcThroughProxies(true);
      },
      async probe(p) {
        firefoxRoute = { mode: 'probe', proxies: [p] };
      },
      async clear() {
        firefoxRoute = { mode: 'off' };
        await webrtcThroughProxies(false);
      },
      async controlledByOther() {
        return false;
      },
    }
  : {
      async full(proxies) {
        await setPac(pacScript(proxies));
        await webrtcThroughProxies(true);
      },
      async probe(p) {
        await setPac(probePacScript(p));
      },
      async clear() {
        await chrome.proxy.settings.clear({ scope: 'regular' });
        await webrtcThroughProxies(false);
      },
      // Only one extension can set the proxy. When another one has, ours
      // would change nothing, and the person must be told.
      async controlledByOther() {
        const got = await chrome.proxy.settings.get({});
        return got.levelOfControl === 'controlled_by_other_extensions' || got.levelOfControl === 'not_controllable';
      },
    };

// A proxy that refused the credentials it was given may mean the allowance
// ran out, so the connection is checked at once. Once in 30 seconds at
// most, since every page asks.
let verifiedAt = 0;
function checkSoon() {
  if (Date.now() - verifiedAt <= 30000) return;
  verifiedAt = Date.now();
  controller.verify({ refused: true });
}

// The edge proxy answers 403, not 407, to credentials it refuses (version 3
// on): for a page load, Chrome answers a 407 with its own box asking the
// person for a password, even when the extension cancels the request. A 403
// fails the request with no auth event, so a failed tunnel through a proxy
// of ours checks the connection at once instead, once in 30 seconds at
// most. The check goes through the full rules first, so a site that is down
// changes nothing; when it fails, the backend is asked (recover), and a
// used-up allowance shows.
// Failures while it is not connected, such as a proxy that fails its
// check during a connect, do not count toward the 30 seconds.
let tunnelCheckedAt = 0;
async function tunnelFailed() {
  if (Date.now() - tunnelCheckedAt <= 30000) return;
  const { wanted, status } = await ext.storage.local.get(['wanted', 'status']);
  if (!wanted || status !== Status.ON || Date.now() - tunnelCheckedAt <= 30000) return;
  tunnelCheckedAt = Date.now();
  controller.verify();
}

if (firefox) {
  browser.proxy.onRequest.addListener(
    async (details) => {
      if (firefoxRoute === null) await loadFirefoxRoute();
      let host = '';
      try {
        host = new URL(details.url).hostname;
      } catch {
        return { type: 'direct' };
      }
      return firefoxAnswer(host, firefoxRoute);
    },
    { urls: ['<all_urls>'] },
  );

  // Firefox sends the credentials with each request (firefoxProxies), so
  // a proxy of ours that asks for them has refused them. Left alone,
  // Firefox would ask the person for a user name and password in the page.
  // The request is cancelled instead, and the connection checked.
  browser.webRequest.onAuthRequired.addListener(
    async (details) => {
      if (!details.isProxy) return {};
      const ours = await controller.ownsProxy(details.challenger.host, details.challenger.port).catch(() => false);
      if (!ours) return {};
      checkSoon();
      return { cancel: true };
    },
    { urls: ['<all_urls>'] },
    ['blocking'],
  );

  // Firefox names the proxy of a failed request, and its error says when the
  // proxy refused it (NS_ERROR_PROXY_FORBIDDEN for a 403).
  browser.webRequest.onErrorOccurred.addListener(
    (details) => {
      const p = details.proxyInfo;
      if (!p || !/^NS_ERROR_PROXY_/.test(details.error || '')) return;
      controller.ownsProxy(p.host, p.port).then((ours) => ours && tunnelFailed()).catch(() => {});
    },
    { urls: ['<all_urls>'] },
  );
} else {
  // Chrome does not name the proxy of a failed request. A tunnel that failed
  // while the rules use our proxies is checked (controller.verify does
  // nothing unless connected).
  chrome.webRequest.onErrorOccurred.addListener(
    (details) => {
      if (details.error === 'net::ERR_TUNNEL_CONNECTION_FAILED') tunnelFailed().catch(() => {});
    },
    { urls: ['<all_urls>'] },
  );

  // Another extension took the proxy setting: the connection is checked at
  // once rather than at the next alarm.
  chrome.proxy.settings.onChange.addListener((details) => {
    if (details.levelOfControl === 'controlled_by_other_extensions') controller.verify();
  });

  // Chrome sends no credentials until a proxy asks. A proxy that asks again
  // for one request has refused the ones it was given (checkSoon). Chrome
  // may give up by itself after the second refusal; if it asks a third
  // time, the request is cancelled.
  const tries = new Map();
  chrome.webRequest.onAuthRequired.addListener(
    (details, respond) => {
      if (!details.isProxy) {
        respond({});
        return;
      }
      const n = (tries.get(details.requestId) || 0) + 1;
      tries.set(details.requestId, n);
      if (tries.size > 1000) tries.clear();
      if (n > 1) checkSoon();
      if (n > 2) {
        respond({ cancelRequest: true });
        return;
      }
      const { host, port } = details.challenger;
      controller
        .credentialsFor(host, port)
        .then(async (c) => {
          if (c) return respond({ authCredentials: c });
          // A proxy of ours that is no longer in the rules, still answering
          // a request sent through it before they changed: the request is
          // cancelled, so Chrome does not ask the person for a password.
          if (await controller.ownsProxy(host, port)) {
            checkSoon();
            return respond({ cancelRequest: true });
          }
          return respond({});
        })
        .catch(() => respond({}));
    },
    { urls: ['<all_urls>'] },
    ['asyncBlocking'],
  );
}

// --- the check ------------------------------------------------------------

// A page that answers 204 with nothing. It is not on the direct list, and
// the proxy rules have no direct fallback, so an answer can only have come
// through a proxy: through the one being checked, while only the check goes
// through it (pac.js probePacScript, firefoxAnswer).
const PROBE = `https://${PROBE_HOST}/generate_204`;

async function health() {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 12000);
  try {
    const res = await fetch(PROBE, { cache: 'no-store', credentials: 'omit', signal: ctrl.signal });
    return res.status === 204 || res.status === 200;
  } catch {
    return false;
  } finally {
    clearTimeout(timer);
  }
}

// --- what the backend is told about this browser ---------------------------

function describe() {
  const ua = navigator.userAgent || '';
  const pick = (re, name) => {
    const m = re.exec(ua);
    return m ? `${name} ${m[1]}` : null;
  };
  const model =
    pick(/Firefox\/(\d+)/, 'Firefox') || pick(/Edg\/(\d+)/, 'Edge') || pick(/OPR\/(\d+)/, 'Opera') ||
    pick(/Chrome\/(\d+)/, 'Chrome') || 'Browser';
  const os = /Windows/.test(ua) ? 'Windows' : /CrOS/.test(ua) ? 'ChromeOS' : /Android/.test(ua) ? 'Android'
    : /Mac OS X/.test(ua) ? 'macOS' : /Linux/.test(ua) ? 'Linux' : 'Other';
  return { model, os };
}

// Firefox asks the person at install whether the extension may send
// technical data, here the browser and its version, the system and the
// language (data_collection_permissions in build.mjs). Without a yes the
// registration carries none of them. Chrome asks nothing; its store
// listing says what is sent.
async function shareTechnical() {
  if (!firefox) return true;
  try {
    const granted = await browser.permissions.getAll();
    return Array.isArray(granted.data_collection) && granted.data_collection.includes('technicalAndInteraction');
  } catch {
    return false;
  }
}

// A backend on this computer, for tests and development, set with
// chrome.storage.local.set({apiBase: "http://127.0.0.1:8080"}). Nothing
// else is accepted, so the setting cannot send the extension's calls to
// another host.
const api = new Api({ version: manifest.version });
function useApiBase(value) {
  api.base = typeof value === 'string' && /^http:\/\/(127\.0\.0\.1|localhost):\d{1,5}$/.test(value) ? value : API_BASE;
}
store.get(['apiBase']).then((s) => useApiBase(s.apiBase));

const described = describe();
let language = 'en';
store.get(['language']).then((s) => {
  language = s.language || browserLanguage(ext.i18n.getUILanguage());
});

const controller = new Controller({
  store,
  proxy,
  api,
  health,
  info: {
    version: manifest.version,
    model: described.model,
    os: described.os,
    language: () => language,
    shareTechnical,
  },
});

// --- the toolbar icon -----------------------------------------------------

async function paintIcon() {
  const { status } = await store.get(['status']);
  const on = status === Status.ON;
  const size = (s) => ({ 16: `icons/${s}-16.png`, 32: `icons/${s}-32.png`, 48: `icons/${s}-48.png` });
  try {
    await ext.action.setIcon({ path: size(on ? 'on' : 'off') });
  } catch {
    // An icon that did not change is no reason to stop.
  }
}

ext.storage.onChanged.addListener((changes, area) => {
  if (area !== 'local') return;
  if ('status' in changes) paintIcon();
  if ('language' in changes) language = changes.language.newValue || browserLanguage(ext.i18n.getUILanguage());
  if ('apiBase' in changes) useApiBase(changes.apiBase.newValue);
});

// --- events ---------------------------------------------------------------

function startChecks() {
  ext.alarms.create(TICK, { periodInMinutes: TICK_MINUTES });
}

ext.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === TICK) controller.tick();
});

ext.runtime.onInstalled.addListener(() => {
  startChecks();
  paintIcon();
  controller.tick();
});

ext.runtime.onStartup.addListener(() => {
  startChecks();
  paintIcon();
  controller.tick();
});

ext.runtime.onMessage.addListener((msg, sender, respond) => {
  // Only this extension's own pages talk to the background.
  if (sender.id !== ext.runtime.id) return false;
  const work = {
    state: () => controller.snapshot(),
    refresh: () => controller.refreshQuota(),
    connect: () => controller.connect(),
    disconnect: () => controller.disconnect(),
    redeem: () => controller.redeem(msg.code || ''),
    language: () => controller.setLanguage(msg.code || '').then(() => controller.snapshot()),
  }[msg && msg.type];
  if (!work) return false;
  work().then(respond, (e) => respond({ error: String((e && e.message) || e) }));
  return true;
});
